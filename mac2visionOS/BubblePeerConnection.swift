import Foundation
@preconcurrency import Network

@MainActor
final class BubblePeerConnection {
    let id = UUID()
    let connection: NWConnection

    var onMessage: ((BubbleMessage) -> Void)?
    var onStateChange: ((NWConnection.State) -> Void)?
    var onEvent: ((String) -> Void)?

    private var pendingData = Data()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(connection: NWConnection) {
        self.connection = connection
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func start() {
        onEvent?("Starting connection to \(connection.endpoint.debugDescription)")
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.onEvent?("Connection state: \(state.eventDescription)")
                self?.onStateChange?(state)
            }
        }
        receiveNext()
        connection.start(queue: .global(qos: .userInitiated))
    }

    func send(_ message: BubbleMessage) {
        do {
            var payload = try encoder.encode(message)
            payload.append(0x0A)
            onEvent?("Sending \(message.eventDescription)")
            connection.send(content: payload, completion: .contentProcessed { _ in })
        } catch {
            report(error)
        }
    }

    func cancel() {
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] content, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let content, !content.isEmpty {
                    self.onEvent?("Received \(content.count) bytes")
                    self.pendingData.append(content)
                    self.drainMessages()
                }

                if let error {
                    self.onStateChange?(.failed(error))
                    return
                }

                if isComplete {
                    self.onStateChange?(.cancelled)
                    return
                }

                self.receiveNext()
            }
        }
    }

    private func drainMessages() {
        while let newlineIndex = pendingData.firstIndex(of: 0x0A) {
            let frame = pendingData[..<newlineIndex]
            pendingData.removeSubrange(...newlineIndex)

            guard !frame.isEmpty else { continue }

            do {
                let message = try decoder.decode(BubbleMessage.self, from: Data(frame))
                onEvent?("Decoded \(message.eventDescription)")
                onMessage?(message)
            } catch {
                onEvent?("Decode failed: \(error.localizedDescription)")
                report(error)
            }
        }
    }

    private func report(_ error: Error) {
        if let error = error as? NWError {
            onStateChange?(.failed(error))
        } else {
            onStateChange?(.failed(.posix(.EPROTO)))
        }
    }
}

private extension BubbleMessage {
    var eventDescription: String {
        switch self {
        case .hello(let hello):
            "hello(\(hello.displayName), \(hello.groupKey))"
        case .command(let command):
            "command(\(command.action.rawValue), \(command.groupKey))"
        case .acknowledgement(let acknowledgement):
            "ack(\(acknowledgement.accepted), \(acknowledgement.detail))"
        }
    }
}

private extension NWConnection.State {
    var eventDescription: String {
        switch self {
        case .setup:
            "setup"
        case .waiting(let error):
            "waiting(\(error.localizedDescription))"
        case .preparing:
            "preparing"
        case .ready:
            "ready"
        case .failed(let error):
            "failed(\(error.localizedDescription))"
        case .cancelled:
            "cancelled"
        @unknown default:
            "unknown"
        }
    }
}
