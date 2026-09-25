import SwiftUI

/// A round glass control that sits concentric with the window corner it lives in.
struct ChromeButton: View {
    let symbol: String
    let help: String
    var isOn = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(isHovering ? .primary : .secondary))
                .frame(width: Metrics.controlSize, height: Metrics.controlSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
