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
    @Published var groupKey = "AVP1" {
        didSet {
            groupKey = BubbleProtocol.normalizedKey(groupKey)
        }
    }
    @Published var status = "Stopped"
    @Published var clients: [ConnectedBubbleClient] = []
    @Published var receivedCommands: [String] = []

    private var listener: NWListener?
    private var connections: [UUID: BubblePeerConnection] = [:]
    private var clientHelloByConnectionID: [UUID: BubblePeerHello] = [:]

    func start() {
        stop()

        guard BubbleProtocol.isValidKey(groupKey) else {
            status = "Enter a 4-character key"
            return
        }

        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(
                name: BubbleProtocol.serviceName(for: groupKey),
                type: BubbleProtocol.serviceType
            )
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.updateListenerState(state)
                }
            }
            self.listener = listener
            listener.start(queue: .global(qos: .userInitiated))
        } catch {
            status = "Failed: \(error.localizedDescription)"
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
    }

    private func accept(_ connection: NWConnection) {
        let peer = BubblePeerConnection(connection: connection)
        connections[peer.id] = peer
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
        peer.start()
    }

    private func handle(_ message: BubbleMessage, from peer: BubblePeerConnection) {
        switch message {
        case .hello(let hello):
            guard hello.groupKey == groupKey, hello.role == .macController else {
                peer.cancel()
                return
            }

            clientHelloByConnectionID[peer.id] = hello
            updateClient(peerID: peer.id, displayName: hello.displayName)
            receivedCommands.insert("\(hello.displayName) joined \(hello.groupKey)", at: 0)

        case .command(let command):
            let sender = clientHelloByConnectionID[peer.id]?.displayName ?? command.senderID.uuidString
            let detail = "\(sender): \(command.action.title)"
            receivedCommands.insert(detail, at: 0)
            receivedCommands = Array(receivedCommands.prefix(40))

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
        case .failed(let error):
            status = "Failed: \(error.localizedDescription)"
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
    }

    private func updateClient(peerID: UUID, displayName: String) {
        if let index = clients.firstIndex(where: { $0.id == peerID }) {
            clients[index].displayName = displayName
        }
    }
}
#endif
