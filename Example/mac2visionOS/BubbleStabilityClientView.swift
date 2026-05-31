#if os(macOS)
import SwiftUI
import Mac2VisionOS

struct BubbleStabilityClientView: View {
    @StateObject private var model: BubbleStabilityClientModel

    init(groupKey: String) {
        _model = StateObject(wrappedValue: BubbleStabilityClientModel(groupKey: groupKey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bubble Stability Client")
                .font(.title.bold())
            Text(model.status)
                .foregroundStyle(.secondary)

            List(model.events.indices, id: \.self) { index in
                Text(model.events[index])
                    .font(.caption)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
        .task {
            model.start()
        }
    }
}
#endif
