#if os(macOS)
import SwiftUI
import Mac2VisionOS

struct BubbleControllerView: View {
    @StateObject private var model = BubbleControllerModel()

    private let commandColumns = [
        GridItem(.fixed(96)),
        GridItem(.fixed(96)),
        GridItem(.fixed(96))
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedHostID) {
                Section("Discovered AVPs") {
                    if model.discoveredHosts.isEmpty {
                        Text("No matching hosts")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.discoveredHosts) { host in
                            Text(host.name)
                                .tag(host.id)
                        }
                    }
                }
            }
            .navigationTitle("Bubble")
        } detail: {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mac Controller")
                        .font(.largeTitle.bold())
                    Text(model.status)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("4-character key", text: $model.groupKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                    Button("Browse") {
                        model.browse()
                    }
                    Button("Connect") {
                        connectSelectedHost()
                    }
                    .disabled(selectedHost == nil)
                    Button("Disconnect") {
                        model.disconnect()
                    }
                }

                LazyVGrid(columns: commandColumns, spacing: 10) {
                    ForEach(BubbleAction.allCases) { action in
                        Button(action.title) {
                            model.send(action)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.isConnected)
                        .frame(width: 96)
                    }
                }

                HStack {
                    Button("Run 4-Client Check") {
                        model.runFourClientLocalCheck()
                    }
                    Text(model.harnessResult)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text("Log")
                    .font(.headline)
                List(model.log.indices, id: \.self) { index in
                    Text(model.log[index])
                }

                Text("Diagnostics")
                    .font(.headline)
                List(model.diagnostics.indices, id: \.self) { index in
                    Text(model.diagnostics[index])
                        .font(.caption)
                }
            }
            .padding(24)
            .frame(minWidth: 560, minHeight: 420, alignment: .topLeading)
        }
    }

    private var selectedHost: DiscoveredBubbleHost? {
        model.discoveredHosts.first { $0.id == model.selectedHostID }
    }

    private func connectSelectedHost() {
        guard let selectedHost else { return }
        model.connect(to: selectedHost)
    }
}
#endif
