import AppKit
import SwiftUI
import TackKit

/// Windows Sticky Notes' palette for Classic, and a stronger accent of each for
/// glass tints, swatches and the header strip in dark mode.
extension NoteTint {
    var accent: NSColor? {
        switch self {
        case .none: nil
        case .yellow: NSColor(srgbRed: 0.98, green: 0.80, blue: 0.24, alpha: 1)
        case .green: NSColor(srgbRed: 0.42, green: 0.80, blue: 0.40, alpha: 1)
        case .pink: NSColor(srgbRed: 0.96, green: 0.52, blue: 0.72, alpha: 1)
        case .purple: NSColor(srgbRed: 0.70, green: 0.54, blue: 0.96, alpha: 1)
        case .blue: NSColor(srgbRed: 0.36, green: 0.64, blue: 0.97, alpha: 1)
        case .gray: NSColor(srgbRed: 0.62, green: 0.62, blue: 0.64, alpha: 1)
        }
    }

    /// Classic without a tint is the yellow note everyone pictures.
    private var classic: NoteTint { self == .none ? .yellow : self }

    var classicBody: NSColor {
        NSColor(name: "tack.classic.body.\(rawValue)") { appearance in
            guard !appearance.isDark else { return NSColor(srgbRed: 0.15, green: 0.15, blue: 0.16, alpha: 1) }
            return switch classic {
            case .yellow, .none: NSColor(srgbRed: 1.0, green: 0.969, blue: 0.82, alpha: 1)
            case .green: NSColor(srgbRed: 0.894, green: 0.976, blue: 0.878, alpha: 1)
            case .pink: NSColor(srgbRed: 1.0, green: 0.894, blue: 0.945, alpha: 1)
            case .purple: NSColor(srgbRed: 0.949, green: 0.902, blue: 1.0, alpha: 1)
            case .blue: NSColor(srgbRed: 0.886, green: 0.945, blue: 1.0, alpha: 1)
            case .gray: NSColor(srgbRed: 0.953, green: 0.949, blue: 0.945, alpha: 1)
            }
        }
    }

    var classicHeader: NSColor {
        NSColor(name: "tack.classic.header.\(rawValue)") { appearance in
            if appearance.isDark {
                return (classic.accent ?? .systemYellow).withAlphaComponent(0.85)
            }
            return switch classic {
            case .yellow, .none: NSColor(srgbRed: 1.0, green: 0.945, blue: 0.64, alpha: 1)
            case .green: NSColor(srgbRed: 0.79, green: 0.94, blue: 0.76, alpha: 1)
            case .pink: NSColor(srgbRed: 1.0, green: 0.80, blue: 0.898, alpha: 1)
            case .purple: NSColor(srgbRed: 0.906, green: 0.812, blue: 1.0, alpha: 1)
            case .blue: NSColor(srgbRed: 0.804, green: 0.914, blue: 1.0, alpha: 1)
            case .gray: NSColor(srgbRed: 0.878, green: 0.878, blue: 0.878, alpha: 1)
            }
        }
    }

    var swatch: Color {
        accent.map(Color.init(nsColor:)) ?? Color(nsColor: .secondaryLabelColor)
    }

    /// A colour dot for menus, drawn as a non-template image so the menu keeps its colour.
    var menuImage: NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5))
            if let accent {
                accent.setFill()
                path.fill()
            } else {
                NSColor.secondaryLabelColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
