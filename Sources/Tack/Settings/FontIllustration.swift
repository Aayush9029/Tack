import AppKit
import SwiftUI
import TackKit

/// A card set in the font it stands for.
struct FontIllustration: View {
    let font: EditorFont

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 2) {
                Text("Aa")
                    .font(face(size: proxy.size.height * 0.32, bold: true))
                Text("Sticky notes")
                    .font(face(size: proxy.size.height * 0.13, bold: false))
                    .foregroundStyle(.secondary)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(.primary.opacity(0.04))
        }
    }

    private func face(size: CGFloat, bold: Bool) -> Font {
        guard let prefix = font.postScriptPrefix else {
            return .system(size: size, weight: bold ? .semibold : .regular)
        }
        return .custom("\(prefix)-\(bold ? "Bold" : "Regular")", size: size)
    }
}
