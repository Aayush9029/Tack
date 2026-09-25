import SwiftUI
import TackKit

/// What sits over the window's glass. Liquid Glass alone is too clear to read over
/// a busy desktop, so glass styles get a scrim; Classic is an opaque sticky note.
struct NoteBackground: View {
    let theme: NoteTheme
    let isFocusMode: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .top) {
            fill
            if theme.style == .classic, !isFocusMode {
                Rectangle()
                    .fill(Color(nsColor: theme.tint.classicHeader))
                    .frame(height: Metrics.titleBarHeight)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: theme)
        .animation(.easeInOut(duration: 0.3), value: isFocusMode)
    }

    @ViewBuilder
    private var fill: some View {
        switch theme.style {
        case .classic:
            Color(nsColor: theme.tint.classicBody)
        case .glass, .clear:
            // The glass takes the tint too, but a scrim over it would wash it out alone.
            scrim.overlay {
                if let accent = theme.tint.accent, !isFocusMode {
                    Color(nsColor: accent).opacity(theme.style == .clear ? 0.12 : 0.16)
                }
            }
        }
    }

    private var scrim: Color {
        let isDark = colorScheme == .dark
        if isFocusMode {
            return isDark ? Color(red: 0.1, green: 0.1, blue: 0.11).opacity(0.94) : Color(red: 0.98, green: 0.976, blue: 0.965).opacity(0.95)
        }
        return switch theme.style {
        case .clear: isDark ? .black.opacity(0.42) : .white.opacity(0.5)
        default: isDark ? .black.opacity(0.24) : .white.opacity(0.34)
        }
    }
}
