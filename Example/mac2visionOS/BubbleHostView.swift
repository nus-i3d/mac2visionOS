#if os(visionOS)
import SwiftUI
import Mac2VisionOS

struct BubbleHostView: View {
    @StateObject private var model = BubbleHostModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Bubble") {
                    TextField("4-character key", text: $model.groupKey)
                        .textInputAutocapitalization(.characters)
                    Text(model.status)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Start Hosting") {
                            model.start()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Stop") {
                            model.stop()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section("Connected MacBooks") {
                    if model.clients.isEmpty {
                        Text("No controllers connected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.clients) { client in
                            VStack(alignment: .leading) {
                                Text(client.displayName)
                                    .font(.headline)
                                Text(client.state)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Commands") {
                    if model.receivedCommands.isEmpty {
                        Text("No commands received")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.receivedCommands.indices, id: \.self) { index in
                            Text(model.receivedCommands[index])
                        }
                    }
                }

                Section("Diagnostics") {
                    if model.diagnostics.isEmpty {
                        Text("No diagnostics")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.diagnostics.indices, id: \.self) { index in
                            Text(model.diagnostics[index])
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Vision Bubble Host")
            .task {
                model.applyLaunchAutomationIfNeeded()
            }
        }
    }
}
#endif
