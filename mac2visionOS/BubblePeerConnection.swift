import Foundation
@preconcurrency import Network

@MainActor
final class BubblePeerConnection {
    let id = UUID()
    let connection: NWConnection

    var onMessage: ((BubbleMessage) -> Void)?
    var onStateChange: ((NWConnection.State) -> Void)?

    private var pendingData = Data()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(connection: NWConnection) {
        self.connection = connection
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
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
                onMessage?(message)
            } catch {
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
