import Sharing
import SwiftUI
import TackKit

/// The text size on Flare's stop slider, one stop per size.
struct FontSizeSlider: View {
    @Bindable var preferences: Preferences
    @State private var preview: Int?

    private let sizes = Preferences.fontSizes

    private var settled: Int {
        sizes.firstIndex(of: preferences.noteFontSize) ?? 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Size")
                Spacer()
                Text("\(sizes[preview ?? settled]) pt")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: preview)
            }
            StopSlider(
                count: sizes.count,
                index: settled,
                tint: [Color(red: 0.30, green: 0.62, blue: 1.0), Color(red: 0.15, green: 0.48, blue: 0.98)]
            ) { stop in
                preview = stop
            } onCommit: { stop in
                preferences.$noteFontSize.withLock { $0 = sizes[stop] }
            }
            .accessibilityElement()
            .accessibilityLabel("Text size")
            .accessibilityValue("\(preferences.noteFontSize) points")
        }
    }
}
