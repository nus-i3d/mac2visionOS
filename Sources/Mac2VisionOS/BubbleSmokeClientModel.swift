#if os(macOS)
import Combine
import Darwin
import Foundation
@preconcurrency import Network

@MainActor
public final class BubbleSmokeClientModel: ObservableObject {
    @Published public var status = "Starting"
    @Published public var events: [String] = []

    private let groupKey: String
    private let peerID = UUID()
    private var browser: NWBrowser?
    private var connection: BubblePeerConnection?
    private var didFinish = false

    public init(groupKey: String) {
        self.groupKey = BubbleProtocol.normalizedKey(groupKey)
    }

    public func start() {
        guard BubbleProtocol.isValidKey(groupKey) else {
            finish(success: false, message: "Invalid smoke key: \(groupKey)")
            return
        }

        append("Smoke client browsing for \(BubbleProtocol.serviceName(for: groupKey))")
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
            try? await Task.sleep(nanoseconds: 12_000_000_000)
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
            append("Connected; sending hello and ping")
            peer.send(.hello(BubblePeerHello(
                id: peerID,
                displayName: "Smoke Mac Controller",
                groupKey: groupKey,
                role: .macController
            )))
            peer.send(.command(BubbleCommand(
                id: UUID(),
                senderID: peerID,
                groupKey: groupKey,
                action: .ping,
                sentAt: Date()
            )))
        case .failed(let error):
            finish(success: false, message: "Connection failed: \(error.localizedDescription)")
        case .waiting(let error):
            append("Connection waiting: \(error.localizedDescription)")
        default:
            break
        }
    }

    private func handle(_ message: BubbleMessage) {
        guard case .acknowledgement(let acknowledgement) = message else {
            append("Ignoring non-ack message")
            return
        }

        if acknowledgement.accepted {
            finish(success: true, message: "Smoke connection passed: \(acknowledgement.detail)")
        } else {
            finish(success: false, message: "Smoke connection rejected: \(acknowledgement.detail)")
        }
    }

    private func timeoutIfNeeded() {
        guard !didFinish else { return }
        finish(success: false, message: "Smoke connection timed out")
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
        print("[BubbleSmoke] \(message)")
        events.insert(message, at: 0)
        events = Array(events.prefix(80))
    }
}
#endif
