#if os(macOS)
import AppKit
import Combine
import Foundation
@preconcurrency import Network

public struct DiscoveredBubbleHost: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let endpoint: NWEndpoint
}

@MainActor
public final class BubbleControllerModel: ObservableObject {
    @Published public var groupKey = "AVP1"
    @Published public var status = "Idle"
    @Published public var discoveredHosts: [DiscoveredBubbleHost] = []
    @Published public var selectedHostID: String?
    @Published public var log: [String] = []
    @Published public var diagnostics: [String] = []
    @Published public var harnessResult = "Not run"

    private let peerID = UUID()
    private var browser: NWBrowser?
    private var connection: BubblePeerConnection?
    private var harness: BubbleFourClientHarness?

    public init() {}

    public var isConnected: Bool {
        status == "Connected"
    }

    public func browse() {
        disconnect()
        discoveredHosts.removeAll()
        selectedHostID = nil

        let key = BubbleProtocol.normalizedKey(groupKey)
        groupKey = key

        guard BubbleProtocol.isValidKey(key) else {
            status = "Enter a 4-character key"
            appendDiagnostic("Rejected browse: invalid key")
            return
        }

        let descriptor = NWBrowser.Descriptor.bonjour(type: BubbleProtocol.serviceType, domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.updateBrowseResults(results)
            }
        }
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                self?.updateBrowserState(state)
            }
        }
        self.browser = browser
        appendDiagnostic("Browsing for \(BubbleProtocol.serviceName(for: key)) \(BubbleProtocol.serviceType)")
        browser.start(queue: .global(qos: .userInitiated))
    }

    public func connect(to host: DiscoveredBubbleHost) {
        connection?.cancel()

        let peer = BubblePeerConnection(connection: NWConnection(to: host.endpoint, using: .tcp))
        connection = peer
        selectedHostID = host.id
        status = "Connecting to \(host.name)"

        peer.onMessage = { [weak self] message in
            self?.handle(message)
        }
        peer.onStateChange = { [weak self] state in
            self?.updateConnectionState(state)
        }
        peer.onEvent = { [weak self] event in
            self?.appendDiagnostic(event)
        }
        peer.start()
    }

    public func disconnect() {
        connection?.cancel()
        connection = nil
        browser?.cancel()
        browser = nil
        status = "Idle"
        appendDiagnostic("Disconnected")
    }

    public func send(_ action: BubbleAction) {
        guard let connection else {
            log.insert("No active connection", at: 0)
            return
        }

        let command = BubbleCommand(
            id: UUID(),
            senderID: peerID,
            groupKey: groupKey,
            action: action,
            sentAt: Date()
        )
        connection.send(.command(command))
        log.insert("Sent \(action.title)", at: 0)
        log = Array(log.prefix(40))
        appendDiagnostic("Sent \(action.rawValue)")
    }

    public func runFourClientLocalCheck() {
        harness?.stop()
        harnessResult = "Running..."
        appendDiagnostic("Starting local 4-client harness")

        let harness = BubbleFourClientHarness(groupKey: BubbleProtocol.normalizedKey(groupKey))
        self.harness = harness
        harness.run { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let detail):
                    self?.harnessResult = detail
                    self?.appendDiagnostic(detail)
                case .failure(let error):
                    self?.harnessResult = "Failed: \(error.localizedDescription)"
                    self?.appendDiagnostic("Harness failed: \(error.localizedDescription)")
                }
                self?.harness = nil
            }
        }
    }

    private func updateBrowseResults(_ results: Set<NWBrowser.Result>) {
        let expectedName = BubbleProtocol.serviceName(for: groupKey)
        let hosts = results.compactMap { result -> DiscoveredBubbleHost? in
            guard case let .service(name, _, _, _) = result.endpoint, name == expectedName else {
                return nil
            }
            return DiscoveredBubbleHost(id: name, name: name, endpoint: result.endpoint)
        }
        .sorted { $0.name < $1.name }

        discoveredHosts = hosts
        appendDiagnostic("Browse result count: \(hosts.count)")

        if selectedHostID == nil, let first = hosts.first {
            selectedHostID = first.id
        }
    }

    private func updateBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .setup:
            status = "Preparing browser"
        case .ready:
            status = "Browsing for \(BubbleProtocol.serviceName(for: groupKey))"
            appendDiagnostic(status)
        case .waiting(let error):
            status = "Waiting: \(error.localizedDescription)"
        case .failed(let error):
            status = "Browse failed: \(error.localizedDescription)"
        case .cancelled:
            if connection == nil {
                status = "Idle"
            }
        @unknown default:
            status = "Unknown browser state"
        }
    }

    private func updateConnectionState(_ state: NWConnection.State) {
        switch state {
        case .setup:
            status = "Setting up"
        case .waiting(let error):
            status = "Waiting: \(error.localizedDescription)"
        case .preparing:
            status = "Preparing"
        case .ready:
            status = "Connected"
            appendDiagnostic("Connected; sending hello and ping")
            sendHello()
            send(.ping)
        case .failed(let error):
            status = "Connection failed: \(error.localizedDescription)"
            connection = nil
        case .cancelled:
            status = "Disconnected"
            connection = nil
        @unknown default:
            status = "Unknown connection state"
        }
    }

    private func sendHello() {
        connection?.send(.hello(BubblePeerHello(
            id: peerID,
            displayName: Host.current().localizedName ?? "Mac Controller",
            groupKey: groupKey,
            role: .macController
        )))
    }

    private func handle(_ message: BubbleMessage) {
        guard case .acknowledgement(let acknowledgement) = message else {
            return
        }

        log.insert(acknowledgement.detail, at: 0)
        log = Array(log.prefix(40))
        appendDiagnostic("Received acknowledgement: \(acknowledgement.detail)")
    }

    private func appendDiagnostic(_ message: String) {
        diagnostics.insert(message, at: 0)
        diagnostics = Array(diagnostics.prefix(80))
    }
}
#endif
