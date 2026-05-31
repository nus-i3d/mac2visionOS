#if os(macOS)
import Combine
import Darwin
import Foundation
@preconcurrency import Network

@MainActor
public final class BubbleStabilityClientModel: ObservableObject {
    @Published public var status = "Starting"
    @Published public var events: [String] = []

    private let groupKey: String
    private let peerID = UUID()
    private let requiredAcks = 5
    private let ackIntervalNanoseconds: UInt64 = 1_000_000_000
    private let timeoutNanoseconds: UInt64 = 18_000_000_000

    private var browser: NWBrowser?
    private var connection: BubblePeerConnection?
    private var didFinish = false
    private var expectedAckIDs: [UUID] = []
    private var receivedAckIDs = Set<UUID>()

    public init(groupKey: String) {
        self.groupKey = BubbleProtocol.normalizedKey(groupKey)
    }

    public func start() {
        guard BubbleProtocol.isValidKey(groupKey) else {
            finish(success: false, message: "Invalid stability key: \(groupKey)")
            return
        }

        append("Stability client browsing for \(BubbleProtocol.serviceName(for: groupKey))")
        status = "Browsing"

        let browser = NWBrowser(for: .bonjour(type: BubbleProtocol.serviceType, domain: nil), using: .tcp)
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handle(results)
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.handleBrowserState(state)
            }
        }
        browser.start(queue: .global(qos: .userInitiated))

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.timeoutNanoseconds ?? 18_000_000_000)
            self?.timeoutIfNeeded()
        }
    }

    private func handle(_ results: Set<NWBrowser.Result>) {
        let expectedName = BubbleProtocol.serviceName(for: groupKey)
        append("Browse result count: \(results.count)")

        guard connection == nil else { return }
        guard let result = results.first(where: {
            guard case let .service(name, _, _, _) = $0.endpoint else { return false }
            return name == expectedName
        }) else {
            return
        }

        append("Found \(expectedName); connecting")
        connect(to: result.endpoint)
    }

    private func connect(to endpoint: NWEndpoint) {
        status = "Connecting"
        let peer = BubblePeerConnection(connection: NWConnection(to: endpoint, using: .tcp))
        connection = peer

        peer.onEvent = { [weak self] event in
            self?.append(event)
        }
        peer.onStateChange = { [weak self, weak peer] state in
            guard let self, let peer else { return }
            self.handleConnectionState(state, peer: peer)
        }
        peer.onMessage = { [weak self] message in
            self?.handle(message)
        }
        peer.start()
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            append("Browser ready")
        case .failed(let error):
            finish(success: false, message: "Browser failed: \(error.localizedDescription)")
        case .waiting(let error):
            append("Browser waiting: \(error.localizedDescription)")
        default:
            break
        }
    }

    private func handleConnectionState(_ state: NWConnection.State, peer: BubblePeerConnection) {
        switch state {
        case .ready:
            status = "Connected"
            append("Connected; sending hello and starting stability sequence")
            peer.send(.hello(BubblePeerHello(
                id: peerID,
                displayName: "Stability Mac Controller",
                groupKey: groupKey,
                role: .macController
            )))
            scheduleNextPing(after: 0)
        case .failed(let error):
            finish(success: false, message: "Connection failed: \(error.localizedDescription)")
        case .waiting(let error):
            append("Connection waiting: \(error.localizedDescription)")
        default:
            break
        }
    }

    private func scheduleNextPing(after delayNanoseconds: UInt64) {
        guard !didFinish else { return }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            self?.sendNextPingIfNeeded()
        }
    }

    private func sendNextPingIfNeeded() {
        guard !didFinish else { return }
        guard let connection else {
            finish(success: false, message: "Connection unavailable during stability check")
            return
        }

        let nextIndex = expectedAckIDs.count + 1
        guard nextIndex <= requiredAcks else {
            finish(success: true, message: "Stable connection passed: \(receivedAckIDs.count)/\(requiredAcks) acknowledgements")
            return
        }

        let commandID = UUID()
        expectedAckIDs.append(commandID)
        append("Sending ping \(nextIndex)/\(requiredAcks)")
        connection.send(.command(BubbleCommand(
            id: commandID,
            senderID: peerID,
            groupKey: groupKey,
            action: .ping,
            sentAt: Date()
        )))
    }

    private func handle(_ message: BubbleMessage) {
        guard case .acknowledgement(let acknowledgement) = message else {
            append("Ignoring non-ack message")
            return
        }

        guard expectedAckIDs.contains(acknowledgement.messageID) else {
            append("Ignoring unexpected acknowledgement")
            return
        }

        guard acknowledgement.accepted else {
            finish(success: false, message: "Stable connection rejected: \(acknowledgement.detail)")
            return
        }

        let inserted = receivedAckIDs.insert(acknowledgement.messageID).inserted
        if inserted {
            append("Received acknowledgement \(receivedAckIDs.count)/\(requiredAcks)")
        }

        if receivedAckIDs.count == requiredAcks {
            finish(success: true, message: "Stable connection passed: \(receivedAckIDs.count)/\(requiredAcks) acknowledgements")
        } else {
            scheduleNextPing(after: ackIntervalNanoseconds)
        }
    }

    private func timeoutIfNeeded() {
        guard !didFinish else { return }
        finish(success: false, message: "Stable connection timed out after \(receivedAckIDs.count)/\(requiredAcks) acknowledgements")
    }

    private func finish(success: Bool, message: String) {
        guard !didFinish else { return }
        didFinish = true
        status = message
        append(message)
        browser?.cancel()
        connection?.cancel()

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            exit(success ? 0 : 1)
        }
    }

    private func append(_ message: String) {
        print("[BubbleStability] \(message)")
        events.insert(message, at: 0)
        events = Array(events.prefix(120))
    }
}
#endif
