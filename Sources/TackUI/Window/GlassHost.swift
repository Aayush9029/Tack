import AppKit

enum GlassHost {
    /// Liquid Glass behind content, clipped to one continuous radius. The glass
    /// view needs its own radius and mask, or a square plate shows at the corners.
    @MainActor
    static func make(content: NSView, cornerRadius: CGFloat, size: NSSize) -> NSGlassEffectView {
        content.frame = NSRect(origin: .zero, size: size)
        content.autoresizingMask = [.width, .height]
        content.wantsLayer = true
        content.layer?.cornerRadius = cornerRadius
        content.layer?.cornerCurve = .continuous
        content.layer?.masksToBounds = true

        let glass = NSGlassEffectView(frame: NSRect(origin: .zero, size: size))
        glass.autoresizingMask = [.width, .height]
        glass.contentView = content
        glass.cornerRadius = cornerRadius
        glass.wantsLayer = true
        glass.layer?.cornerRadius = cornerRadius
        glass.layer?.cornerCurve = .continuous
        glass.layer?.masksToBounds = true
        return glass
    }

    @MainActor
    static func setCornerRadius(_ radius: CGFloat, of glass: NSGlassEffectView) {
        glass.cornerRadius = radius
        glass.layer?.cornerRadius = radius
        glass.contentView?.layer?.cornerRadius = radius
    }
}
