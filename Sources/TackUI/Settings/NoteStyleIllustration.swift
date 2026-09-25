import SwiftUI
import TackKit

/// A desktop in miniature with a sticky note in the chosen style on it.
struct NoteStyleIllustration: View {
    let style: NoteStyle
    let tint: NoteTint

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.size
            let note = CGSize(width: screen.width * 0.56, height: screen.height * 0.62)
            let radius = note.height * 0.14
            ZStack {
                DesktopWallpaper.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.width, height: screen.height)
                    .clipped()
                VStack(alignment: .leading, spacing: note.height * 0.07) {
                    header(note)
                    line(width: 0.8, note)
                    line(width: 0.62, note)
                    HStack(spacing: note.width * 0.04) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(.secondary, lineWidth: 1)
                            .frame(width: note.height * 0.1, height: note.height * 0.1)
                        line(width: 0.45, note)
                    }
                    Spacer(minLength: 0)
                }
                .padding(note.width * 0.08)
                .frame(width: note.width, height: note.height, alignment: .topLeading)
                .environment(\.colorScheme, style == .classic ? .light : colorScheme)
                .background { background(radius: radius) }
                .clipShape(.rect(cornerRadius: radius, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
    }

    private func header(_ note: CGSize) -> some View {
        Capsule()
            .fill(.primary.opacity(0.55))
            .frame(width: note.width * 0.4, height: note.height * 0.07)
    }

    private func line(width: CGFloat, _ note: CGSize) -> some View {
        Capsule()
            .fill(.primary.opacity(0.3))
            .frame(width: note.width * width * 0.84, height: note.height * 0.05)
    }

    @ViewBuilder
    private func background(radius: CGFloat) -> some View {
        switch style {
        case .classic:
            ZStack(alignment: .top) {
                Color(nsColor: tint.classicBody)
                Color(nsColor: tint.classicHeader).frame(height: radius * 1.4)
            }
        case .glass:
            Rectangle().fill(.regularMaterial)
                .overlay { (tint.accent.map { Color(nsColor: $0) } ?? .clear).opacity(0.25) }
        case .clear:
            Rectangle().fill(.ultraThinMaterial.opacity(0.35))
                .overlay { Color.black.opacity(0.12) }
                .overlay { (tint.accent.map { Color(nsColor: $0) } ?? .clear).opacity(0.18) }
        }
    }
}
