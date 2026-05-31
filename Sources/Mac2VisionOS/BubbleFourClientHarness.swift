#if os(macOS)
import Foundation
@preconcurrency import Network

@MainActor
final class BubbleFourClientHarness {
    enum HarnessError: LocalizedError {
        case invalidKey
        case listenerPortUnavailable
        case timeout(acknowledgements: Int)
        case listenerFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidKey:
                "The local check needs a valid 4-character bubble key."
            case .listenerPortUnavailable:
                "The local listener did not expose a port."
            case .timeout(let acknowledgements):
                "Timed out after receiving \(acknowledgements) of 4 acknowledgements."
            case .listenerFailed(let reason):
                "Local listener failed: \(reason)"
            }
        }
    }

    private let groupKey: String
    private var listener: NWListener?
    private var serverPeers: [BubblePeerConnection] = []
    private var clientPeers: [BubblePeerConnection] = []
    private var receivedAcknowledgements = Set<UUID>()
    private var completion: ((Result<String, Error>) -> Void)?
    private var didComplete = false

    init(groupKey: String) {
        self.groupKey = groupKey
    }

    func run(completion: @escaping (Result<String, Error>) -> Void) {
        guard BubbleProtocol.isValidKey(groupKey) else {
            completion(.failure(HarnessError.invalidKey))
            return
        }

        self.completion = completion

        do {
            let listener = try NWListener(using: .tcp, on: .any)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.acceptServerConnection(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    self?.handleListenerState(state)
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
            scheduleTimeout()
        } catch {
            complete(.failure(error))
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        serverPeers.forEach { $0.cancel() }
        clientPeers.forEach { $0.cancel() }
        serverPeers.removeAll()
        clientPeers.removeAll()
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            startClients()
        case .failed(let error):
            complete(.failure(HarnessError.listenerFailed(error.localizedDescription)))
        default:
            break
        }
    }

    private func startClients() {
        guard let port = listener?.port else {
            complete(.failure(HarnessError.listenerPortUnavailable))
            return
        }

        for index in 1...4 {
            let clientID = UUID()
            let endpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: port)
            let peer = BubblePeerConnection(connection: NWConnection(to: endpoint, using: .tcp))
            clientPeers.append(peer)

            peer.onStateChange = { [weak self, weak peer] state in
                guard let self, let peer else { return }
                if case .ready = state {
                    self.sendClientMessages(peer: peer, clientID: clientID, index: index)
                }
            }
            peer.onMessage = { [weak self] message in
                self?.handleClientMessage(message)
            }
            peer.start()
        }
    }

    private func acceptServerConnection(_ connection: NWConnection) {
        let peer = BubblePeerConnection(connection: connection)
        serverPeers.append(peer)

        peer.onMessage = { [weak self, weak peer] message in
            guard let self, let peer else { return }
            self.handleServerMessage(message, peer: peer)
        }
        peer.start()
    }

    private func sendClientMessages(peer: BubblePeerConnection, clientID: UUID, index: Int) {
        peer.send(.hello(BubblePeerHello(
            id: clientID,
            displayName: "Harness Mac \(index)",
            groupKey: groupKey,
            role: .macController
        )))
        peer.send(.command(BubbleCommand(
            id: UUID(),
            senderID: clientID,
            groupKey: groupKey,
            action: .ping,
            sentAt: Date()
        )))
    }

    private func handleServerMessage(_ message: BubbleMessage, peer: BubblePeerConnection) {
        guard case .command(let command) = message else {
            return
        }

        peer.send(.acknowledgement(BubbleAcknowledgement(
            id: UUID(),
            messageID: command.id,
            accepted: command.groupKey == groupKey,
            detail: "Harness accepted \(command.action.title)",
            sentAt: Date()
        )))
    }

    private func handleClientMessage(_ message: BubbleMessage) {
        guard case .acknowledgement(let acknowledgement) = message else {
            return
        }

        receivedAcknowledgements.insert(acknowledgement.messageID)
        if receivedAcknowledgements.count == 4 {
            complete(.success("4-client local check passed"))
        }
    }

    private func scheduleTimeout() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self, !self.didComplete else { return }
            self.complete(.failure(HarnessError.timeout(acknowledgements: self.receivedAcknowledgements.count)))
        }
    }

    private func complete(_ result: Result<String, Error>) {
        guard !didComplete else { return }
        didComplete = true
        let completion = completion
        self.completion = nil
        stop()
        completion?(result)
    }
}
#endif

