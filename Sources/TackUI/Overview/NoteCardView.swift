import SwiftUI
import TackKit

/// A note in the overview, dressed in its own style and tint.
struct NoteCardView: View {
    let card: NoteCard
    let open: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var systemScheme

    private let radius: CGFloat = 18

    private var scheme: ColorScheme {
        switch (card.theme.style, card.theme.appearance) {
        case (.classic, _), (_, .light): .light
        case (_, .dark): .dark
        case (_, .system): systemScheme
        }
    }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                    PreviewLineView(line: line)
                }
                footer
                    .padding(.top, 4)
            }
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { background }
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.primary.opacity(isHovering ? 0.18 : 0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isHovering ? 0.28 : 0.16), radius: isHovering ? 16 : 8, y: isHovering ? 8 : 3)
            .scaleEffect(isHovering ? 1.02 : 1)
            .contentShape(.rect(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .environment(\.colorScheme, scheme)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.2), value: isHovering)
        .accessibilityLabel(card.title)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if card.totalTasks > 0 {
                Label("\(card.doneTasks)/\(card.totalTasks)", systemImage: card.doneTasks == card.totalTasks ? "checkmark.circle.fill" : "checklist")
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Text(card.updatedAt, format: .relative(presentation: .named))
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private var background: some View {
        switch card.theme.style {
        case .classic:
            VStack(spacing: 0) {
                Color(nsColor: card.theme.tint.classicHeader).frame(height: 6)
                Color(nsColor: card.theme.tint.classicBody)
            }
        case .glass, .clear:
            Rectangle()
                .fill(card.theme.style == .clear ? .ultraThinMaterial : .regularMaterial)
                .overlay { card.theme.tint.accent.map { Color(nsColor: $0).opacity(0.18) } }
        }
    }
}
