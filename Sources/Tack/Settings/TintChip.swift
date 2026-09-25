import SwiftUI
import TackKit

/// A tint to choose, after Flare's tool chips.
struct TintChip: View {
    let tint: NoteTint
    let isOn: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint == .none ? AnyShapeStyle(.clear) : AnyShapeStyle(tint.swatch))
                    .overlay { Circle().strokeBorder(isOn ? onForeground.opacity(0.4) : Color.primary.opacity(0.25), lineWidth: 1) }
                    .frame(width: 11, height: 11)
                Text(tint.title)
                    .font(.callout.weight(.medium))
            }
            .foregroundStyle(isOn ? AnyShapeStyle(onForeground) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isOn ? onFill : .primary.opacity(isHovering ? 0.08 : 0.04),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .strokeBorder(isOn ? onFill : .primary.opacity(isHovering ? 0.2 : 0.12), lineWidth: 1)
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isOn)
        .accessibilityLabel(tint.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var onFill: Color { colorScheme == .dark ? .white : .black }
    private var onForeground: Color { colorScheme == .dark ? .black : .white }
}
