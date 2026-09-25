import SwiftUI
import TackKit

struct PaletteItemRow: View {
    let item: PaletteItem
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 20)
            Text(item.title)
                .font(.system(size: 14))
                .lineLimit(1)
            Spacer(minLength: 8)
            if item.isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            if !item.shortcut.isEmpty {
                KeyCaps(keys: item.shortcut)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: PaletteMetrics.itemHeight)
        .opacity(item.isEnabled ? 1 : 0.38)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var icon: some View {
        if let swatch = item.swatch {
            Circle()
                .fill(swatch == .none ? AnyShapeStyle(.clear) : AnyShapeStyle(swatch.swatch))
                .overlay { Circle().strokeBorder(.secondary.opacity(swatch == .none ? 0.8 : 0.2), lineWidth: 1) }
                .frame(width: 13, height: 13)
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
