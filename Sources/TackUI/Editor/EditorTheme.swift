import AppKit
import TackKit

/// Fonts, colours and spacing for one editor configuration. Colours are dynamic, so
/// a change of appearance needs no restyle; only a font, size or mode change does.
@MainActor
final class EditorTheme {
    let family: EditorFont
    let size: CGFloat
    let isFocusMode: Bool

    private var fonts: [FontKey: NSFont] = [:]
    private var widths: [WidthKey: CGFloat] = [:]

    init(family: EditorFont, size: CGFloat, isFocusMode: Bool) {
        self.family = family
        self.size = size
        self.isFocusMode = isFocusMode
    }

    func matches(family: EditorFont, size: CGFloat, isFocusMode: Bool) -> Bool {
        self.family == family && self.size == size && self.isFocusMode == isFocusMode
    }

    // MARK: Fonts

    var bodyFont: NSFont { font(bold: false, italic: false) }

    var lineHeightMultiple: CGFloat { isFocusMode ? 1.5 : 1.22 }

    /// iA Writer keeps headings at body size; the sticky note scales them for hierarchy.
    func headingScale(_ level: Int) -> CGFloat {
        guard !isFocusMode else { return 1 }
        return switch level {
        case 1: 1.42
        case 2: 1.24
        case 3: 1.1
        default: 1
        }
    }

    func font(bold: Bool, italic: Bool, scale: CGFloat = 1) -> NSFont {
        let key = FontKey(bold: bold, italic: italic, scale: scale, code: false)
        if let font = fonts[key] { return font }
        let pointSize = (size * scale).rounded()
        let upright = NSFont.systemFont(ofSize: pointSize, weight: bold ? .semibold : .regular)
        var font = italic ? Self.italic(upright) : upright
        if let prefix = family.postScriptPrefix {
            let face = switch (bold, italic) {
            case (true, true): "BoldItalic"
            case (true, false): "Bold"
            case (false, true): "Italic"
            case (false, false): "Regular"
            }
            font = NSFont(name: "\(prefix)-\(face)", size: pointSize) ?? font
        }
        fonts[key] = font
        return font
    }

    var codeFont: NSFont {
        let key = FontKey(bold: false, italic: false, scale: 1, code: true)
        if let font = fonts[key] { return font }
        let pointSize = (size * (family == .system ? 0.9 : 0.94)).rounded()
        let font = family == .system
            ? NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
            : NSFont(name: "iAWriterMonoS-Regular", size: pointSize) ?? .monospacedSystemFont(ofSize: pointSize, weight: .regular)
        fonts[key] = font
        return font
    }

    /// List markers the layout fragment draws over, in a face where every character is one width.
    var markerFont: NSFont { monospaced(scale: 0.62) }
    var bulletFont: NSFont { monospaced(scale: 1) }
    var hiddenFont: NSFont { monospaced(scale: 0.07) }

    private func monospaced(scale: CGFloat) -> NSFont {
        let key = FontKey(bold: false, italic: false, scale: scale, code: true)
        if let font = fonts[key] { return font }
        let font = NSFont.monospacedSystemFont(ofSize: max(1, (size * scale).rounded()), weight: .regular)
        fonts[key] = font
        return font
    }

    var captionFont: NSFont {
        let key = FontKey(bold: false, italic: false, scale: 0.75, code: true)
        if let font = fonts[key] { return font }
        let font = NSFont.monospacedSystemFont(ofSize: max(10, (size * 0.72).rounded()), weight: .regular)
        fonts[key] = font
        return font
    }

    func converting(_ font: NSFont, bold: Bool? = nil, italic: Bool? = nil) -> NSFont {
        let traits = font.fontDescriptor.symbolicTraits
        let isBold = bold ?? traits.contains(.bold)
        let isItalic = italic ?? traits.contains(.italic)
        let scale = font.pointSize / size
        return self.font(bold: isBold, italic: isItalic, scale: (scale * 100).rounded() / 100)
    }

    private static func italic(_ font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    // MARK: Measurement

    /// The width of a list marker, for the hanging indent that lines wrapped text up under it.
    func width(of prefix: String, font: NSFont) -> CGFloat {
        let key = WidthKey(prefix: prefix, font: font.fontName, size: font.pointSize)
        if let width = widths[key] { return width }
        let width = ceil((prefix as NSString).size(withAttributes: [.font: font]).width)
        widths[key] = width
        return width
    }

    /// Room to the left of the text for heading marks, which iA Writer hangs in the margin.
    var hang: CGFloat {
        isFocusMode ? width(of: "### ", font: bodyFont) : 0
    }

    // MARK: Colours

    nonisolated static let caret = NSColor(srgbRed: 0.0, green: 0.6, blue: 1.0, alpha: 1)
    nonisolated static let text = NSColor.labelColor
    nonisolated static let secondary = NSColor.secondaryLabelColor
    nonisolated static let syntax = NSColor.tertiaryLabelColor
    nonisolated static let link = NSColor(name: "tack.link") { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.40, green: 0.72, blue: 1.0, alpha: 1)
            : NSColor(srgbRed: 0.0, green: 0.42, blue: 0.85, alpha: 1)
    }
    nonisolated static let codeBackground = NSColor(name: "tack.code") { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.07) : NSColor(white: 0, alpha: 0.05)
    }
    /// Orange, so a highlight still shows on yellow paper.
    nonisolated static let highlight = NSColor(srgbRed: 1.0, green: 0.62, blue: 0.1, alpha: 0.38)
    nonisolated static let selection = NSColor(srgbRed: 0.0, green: 0.6, blue: 1.0, alpha: 0.24)
}

private struct FontKey: Hashable {
    let bold: Bool
    let italic: Bool
    let scale: CGFloat
    let code: Bool
}

private struct WidthKey: Hashable {
    let prefix: String
    let font: String
    let size: CGFloat
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua, .vibrantDark, .vibrantLight]).map { $0 == .darkAqua || $0 == .vibrantDark } ?? false
    }
}
