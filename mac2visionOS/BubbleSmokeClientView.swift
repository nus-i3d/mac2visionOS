#if os(macOS)
import SwiftUI

struct BubbleSmokeClientView: View {
    @StateObject private var model: BubbleSmokeClientModel

    init(groupKey: String) {
        _model = StateObject(wrappedValue: BubbleSmokeClientModel(groupKey: groupKey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bubble Smoke Client")
                .font(.title.bold())
            Text(model.status)
                .foregroundStyle(.secondary)

            List(model.events, id: \.self) { event in
                Text(event)
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

