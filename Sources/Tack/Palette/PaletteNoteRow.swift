import SwiftUI
import TackKit

struct PaletteNoteRow: View {
    let hit: NoteHit
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(hit.tint == .none ? AnyShapeStyle(.tertiary) : AnyShapeStyle(hit.tint.swatch))
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(hit.displayTitle)
                    .font(.system(size: 13.5, weight: .medium))
                    .lineLimit(1)
                if !hit.subtitle.isEmpty {
                    Text(hit.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if hit.totalTasks > 0 {
                    Label("\(hit.doneTasks)/\(hit.totalTasks)", systemImage: hit.openTasks == 0 ? "checkmark.circle.fill" : "checklist")
                        .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(hit.openTasks == 0 ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                        .labelStyle(.titleAndIcon)
                }
                Text(hit.updatedAt, format: .relative(presentation: .numeric))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: PaletteMetrics.noteHeight)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHighlighted ? [.isButton, .isSelected] : .isButton)
    }
}
