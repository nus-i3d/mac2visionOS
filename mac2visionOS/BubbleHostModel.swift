#if os(visionOS)
import Combine
import Foundation
@preconcurrency import Network

struct ConnectedBubbleClient: Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var endpoint: String
    var state: String
}

@MainActor
final class BubbleHostModel: ObservableObject {
    @Published var groupKey = "AVP1"
    @Published var status = "Stopped"
    @Published var clients: [ConnectedBubbleClient] = []
    @Published var receivedCommands: [String] = []
    @Published var diagnostics: [String] = []

    private var listener: NWListener?
    private var connections: [UUID: BubblePeerConnection] = [:]
    private var clientHelloByConnectionID: [UUID: BubblePeerHello] = [:]
    private var didApplyLaunchAutomation = false

    func applyLaunchAutomationIfNeeded() {
        guard !didApplyLaunchAutomation else { return }
        didApplyLaunchAutomation = true

        guard let key = BubbleLaunchArguments.value(after: BubbleLaunchArguments.smokeHostFlag) else {
            return
        }

        groupKey = key
        appendDiagnostic("Launch automation: starting smoke host for \(key)")
        start()
    }

    func start() {
        stop()

        let key = BubbleProtocol.normalizedKey(groupKey)
        groupKey = key

        guard BubbleProtocol.isValidKey(key) else {
            status = "Enter a 4-character key"
            appendDiagnostic("Rejected host start: invalid key")
            return
        }

        do {
            let listener = try NWListener(using: .tcp)
            let serviceName = BubbleProtocol.serviceName(for: key)
            listener.service = NWListener.Service(
                name: serviceName,
                type: BubbleProtocol.serviceType
            )
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.accept(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.updateListenerState(state)
                }
            }
            self.listener = listener
            appendDiagnostic("Starting listener \(serviceName) \(BubbleProtocol.serviceType)")
            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            status = "Failed: \(error.localizedDescription)"
            appendDiagnostic("Listener start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        clientHelloByConnectionID.removeAll()
        clients.removeAll()
        status = "Stopped"
        appendDiagnostic("Stopped host")
    }

    private func accept(_ connection: NWConnection) {
        let peer = BubblePeerConnection(connection: connection)
        connections[peer.id] = peer
        appendDiagnostic("Accepted pending connection \(peer.id) from \(connection.endpoint.debugDescription)")
        clients.append(ConnectedBubbleClient(
            id: peer.id,
            displayName: "Connecting...",
            endpoint: connection.endpoint.debugDescription,
            state: "Preparing"
        ))

        peer.onMessage = { [weak self, weak peer] message in
            guard let peer else { return }
            self?.handle(message, from: peer)
        }
        peer.onStateChange = { [weak self, weak peer] state in
            guard let peer else { return }
            self?.update(peer: peer, state: state)
        }
        peer.onEvent = { [weak self] event in
            self?.appendDiagnostic(event)
        }
        peer.start()
    }

    private func handle(_ message: BubbleMessage, from peer: BubblePeerConnection) {
        switch message {
        case .hello(let hello):
            guard hello.groupKey == groupKey, hello.role == .macController else {
                appendDiagnostic("Rejected hello from \(hello.displayName): key=\(hello.groupKey), role=\(hello.role.rawValue)")
                peer.cancel()
                return
            }

            clientHelloByConnectionID[peer.id] = hello
            updateClient(peerID: peer.id, displayName: hello.displayName)
            receivedCommands.insert("\(hello.displayName) joined \(hello.groupKey)", at: 0)
            appendDiagnostic("Registered controller \(hello.displayName) for \(hello.groupKey)")

        case .command(let command):
            let sender = clientHelloByConnectionID[peer.id]?.displayName ?? command.senderID.uuidString
            let detail = "\(sender): \(command.action.title)"
            receivedCommands.insert(detail, at: 0)
            receivedCommands = Array(receivedCommands.prefix(40))
            appendDiagnostic("Received \(command.action.rawValue) from \(sender)")

            peer.send(.acknowledgement(BubbleAcknowledgement(
                id: UUID(),
                messageID: command.id,
                accepted: command.groupKey == groupKey,
                detail: command.groupKey == groupKey ? "Accepted \(command.action.title)" : "Rejected: wrong bubble",
                sentAt: Date()
            )))

        case .acknowledgement:
            break
        }
    }

    private func updateListenerState(_ state: NWListener.State) {
        switch state {
        case .setup:
            status = "Setting up"
        case .waiting(let error):
            status = "Waiting: \(error.localizedDescription)"
        case .ready:
            status = "Hosting \(BubbleProtocol.serviceName(for: groupKey))"
            appendDiagnostic(status)
        case .failed(let error):
            status = "Failed: \(error.localizedDescription)"
            appendDiagnostic(status)
        case .cancelled:
            status = "Stopped"
        @unknown default:
            status = "Unknown"
        }
    }

    private func update(peer: BubblePeerConnection, state: NWConnection.State) {
        let stateText: String
        switch state {
        case .setup:
            stateText = "Setup"
        case .waiting(let error):
            stateText = "Waiting: \(error.localizedDescription)"
        case .preparing:
            stateText = "Preparing"
        case .ready:
            stateText = "Connected"
        case .failed(let error):
            stateText = "Failed: \(error.localizedDescription)"
            connections.removeValue(forKey: peer.id)
            clientHelloByConnectionID.removeValue(forKey: peer.id)
        case .cancelled:
            stateText = "Disconnected"
            connections.removeValue(forKey: peer.id)
            clientHelloByConnectionID.removeValue(forKey: peer.id)
        @unknown default:
            stateText = "Unknown"
        }

        if let index = clients.firstIndex(where: { $0.id == peer.id }) {
            clients[index].state = stateText
        }
        appendDiagnostic("Peer \(peer.id): \(stateText)")
    }

    private func updateClient(peerID: UUID, displayName: String) {
        if let index = clients.firstIndex(where: { $0.id == peerID }) {
            clients[index].displayName = displayName
        }
    }

    private func appendDiagnostic(_ message: String) {
        print("[BubbleHost] \(message)")
        diagnostics.insert(message, at: 0)
        diagnostics = Array(diagnostics.prefix(80))
    }
}
#endif
