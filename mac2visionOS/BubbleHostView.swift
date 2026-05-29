#if os(visionOS)
import SwiftUI

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
                        Button("Stop") {
                            model.stop()
                        }
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
                        ForEach(model.receivedCommands, id: \.self) { command in
                            Text(command)
                        }
                    }
                }

                Section("Diagnostics") {
                    if model.diagnostics.isEmpty {
                        Text("No diagnostics")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.diagnostics, id: \.self) { event in
                            Text(event)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Vision Bubble Host")
        }
    }
}
#endif
