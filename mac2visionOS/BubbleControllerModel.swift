#if os(macOS)
import AppKit
import Combine
import Foundation
@preconcurrency import Network

struct DiscoveredBubbleHost: Identifiable, Equatable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

@MainActor
final class BubbleControllerModel: ObservableObject {
    @Published var groupKey = "AVP1" {
        didSet {
            groupKey = BubbleProtocol.normalizedKey(groupKey)
        }
    }
    @Published var status = "Idle"
    @Published var discoveredHosts: [DiscoveredBubbleHost] = []
    @Published var selectedHostID: String?
    @Published var log: [String] = []

    private let peerID = UUID()
    private var browser: NWBrowser?
    private var connection: BubblePeerConnection?

    var isConnected: Bool {
        status == "Connected"
    }

    func browse() {
        disconnect()
        discoveredHosts.removeAll()
        selectedHostID = nil

        guard BubbleProtocol.isValidKey(groupKey) else {
            status = "Enter a 4-character key"
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
        browser.start(queue: .global(qos: .userInitiated))
    }

    func connect(to host: DiscoveredBubbleHost) {
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
        peer.start()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        browser?.cancel()
        browser = nil
        status = "Idle"
    }

    func send(_ action: BubbleAction) {
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
            sendHello()
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
    }
}
#endif
