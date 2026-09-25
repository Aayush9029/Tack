import AppKit

/// Draws what Markdown means without hiding what it says: the characters stay in
/// the text, and the fragment paints checkboxes, bullets, code boxes, quote bars,
/// rules and media previews around them.
final class NoteLayoutFragment: NSTextLayoutFragment {
    weak var context: FragmentContext?

    private var paragraph: NSAttributedString? {
        (textElement as? NSTextParagraph)?.attributedString
    }

    private var decoration: Decoration.Kind? {
        guard let paragraph, paragraph.length > 0 else { return nil }
        return (paragraph.attribute(.tackDecoration, at: 0, effectiveRange: nil) as? Decoration)?.kind
    }

    private var containerWidth: CGFloat {
        textLayoutManager?.textContainer?.size.width ?? layoutFragmentFrame.width
    }

    override var renderingSurfaceBounds: CGRect {
        let bounds = super.renderingSurfaceBounds
        guard let decoration else { return bounds }
        switch decoration {
        case .code, .codeTop, .codeBottom, .codeSingle, .rule, .quote:
            return bounds.union(CGRect(x: -10, y: 0, width: containerWidth + 20, height: layoutFragmentFrame.height))
        case .media:
            return bounds.union(mediaRect ?? .zero).union(CGRect(x: 0, y: 0, width: containerWidth, height: layoutFragmentFrame.height))
        case .bullet, .task:
            return bounds.insetBy(dx: -4, dy: -2)
        }
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        let isDimmed = self.context?.isDimmed(rangeInElement) ?? false
        if isDimmed {
            context.saveGState()
            context.setAlpha(0.3)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        drawBackground(at: point, in: context)
        super.draw(at: point, in: context)
        drawForeground(at: point, in: context)
        if isDimmed {
            context.endTransparencyLayer()
            context.restoreGState()
        }
    }

    // MARK: Geometry

    private func font(at index: Int) -> NSFont {
        guard let paragraph, index < paragraph.length else { return .systemFont(ofSize: 15) }
        return paragraph.attribute(.font, at: index, effectiveRange: nil) as? NSFont ?? .systemFont(ofSize: 15)
    }

    /// The item's own text sizes its checkbox; the marker is set smaller than the text.
    private func textFont(after index: Int, marker: Int) -> NSFont {
        if let paragraph, index < paragraph.length { return font(at: index) }
        let markerFont = font(at: marker)
        return markerFont.withSize((markerFont.pointSize / 0.62).rounded())
    }

    private func baseline(of line: NSTextLineFragment) -> CGFloat {
        line.typographicBounds.minY + line.glyphOrigin.y
    }

    /// The checkbox over `[ ]`, in fragment coordinates. Also the hit target for a click.
    var checkboxRect: CGRect? {
        guard case let .task(_, box) = decoration, let line = textLineFragments.first else { return nil }
        let font = textFont(after: NSMaxRange(box) + 1, marker: box.location)
        let start = line.locationForCharacter(at: box.location).x
        let end = line.locationForCharacter(at: NSMaxRange(box)).x
        let side = (font.pointSize * 0.98).rounded()
        let midX = line.typographicBounds.minX + (start + end) / 2
        let midY = baseline(of: line) - font.capHeight / 2
        return CGRect(x: (midX - side / 2).rounded(), y: (midY - side / 2).rounded(), width: side, height: side)
    }

    /// The preview sits in the paragraph spacing the styler reserved under the source line.
    var mediaRect: CGRect? {
        guard case let .media(url, height) = decoration else { return nil }
        let aspect = MainActor.assumeIsolated { MediaCache.shared.cached(url)?.aspect } ?? 16.0 / 9.0
        let x = textLineFragments.first?.typographicBounds.minX ?? 0
        let width = min(containerWidth - x, (height * aspect).rounded())
        return CGRect(x: x, y: layoutFragmentFrame.height - height - 6, width: width, height: height)
    }

    var mediaURL: URL? {
        guard case let .media(url, _) = decoration else { return nil }
        return url
    }

    // MARK: Drawing

    private func drawBackground(at point: CGPoint, in context: CGContext) {
        guard let decoration else { return }
        let height = layoutFragmentFrame.height
        let radius: CGFloat = 8
        let box = CGRect(x: point.x - 10, y: point.y, width: containerWidth + 20, height: height)
        let path: CGPath
        switch decoration {
        case .codeTop:
            path = Self.roundedPath(box.insetBy(dx: 0, dy: 0).offsetBy(dx: 0, dy: 2).insetBy(dx: 0, dy: 0), top: radius, bottom: 0)
        case .codeBottom:
            path = Self.roundedPath(CGRect(x: box.minX, y: box.minY, width: box.width, height: box.height - 2), top: 0, bottom: radius)
        case .codeSingle:
            path = Self.roundedPath(box.insetBy(dx: 0, dy: 2), top: radius, bottom: radius)
        case .code:
            path = CGPath(rect: box, transform: nil)
        default:
            return
        }
        context.saveGState()
        context.addPath(path)
        context.setFillColor(EditorTheme.codeBackground.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    private func drawForeground(at point: CGPoint, in context: CGContext) {
        guard let decoration, let line = textLineFragments.first else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: point.x, y: point.y)

        switch decoration {
        case let .bullet(dash):
            let font = font(at: dash)
            let x = line.typographicBounds.minX + line.locationForCharacter(at: dash).x
            let dashWidth = ("-" as NSString).size(withAttributes: [.font: font]).width
            let diameter = max(4, (font.pointSize * 0.3).rounded())
            let center = CGPoint(x: x + dashWidth / 2, y: baseline(of: line) - font.xHeight / 2)
            context.setFillColor(EditorTheme.secondary.cgColor)
            context.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))

        case let .task(isDone, _):
            guard let rect = checkboxRect else { return }
            let path = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.28, cornerHeight: rect.width * 0.28, transform: nil)
            if isDone {
                context.addPath(path)
                context.setFillColor(EditorTheme.caret.cgColor)
                context.fillPath()
                let check = CGMutablePath()
                check.move(to: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.midY + rect.height * 0.02))
                check.addLine(to: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.7))
                check.addLine(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.3))
                context.addPath(check)
                context.setStrokeColor(NSColor.white.cgColor)
                context.setLineWidth(max(1.6, rect.width * 0.12))
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.strokePath()
            } else {
                context.addPath(CGPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerWidth: rect.width * 0.26, cornerHeight: rect.width * 0.26, transform: nil))
                context.setStrokeColor(EditorTheme.secondary.cgColor)
                context.setLineWidth(1.5)
                context.strokePath()
            }

        case .quote:
            let bar = CGRect(x: line.typographicBounds.minX + 1, y: 3, width: 3, height: layoutFragmentFrame.height - 6)
            context.addPath(CGPath(roundedRect: bar, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            context.setFillColor(EditorTheme.syntax.cgColor)
            context.fillPath()

        case .rule:
            let y = (line.typographicBounds.midY).rounded() + 0.5
            context.setStrokeColor(EditorTheme.syntax.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: containerWidth, y: y))
            context.strokePath()

        case let .media(url, _):
            guard let rect = mediaRect else { return }
            drawMedia(url, in: rect, context: context)

        case .code, .codeTop, .codeBottom, .codeSingle:
            break
        }
    }

    private func drawMedia(_ url: URL, in rect: CGRect, context: CGContext) {
        let media = MainActor.assumeIsolated { MediaCache.shared.cached(url) }
        let clip = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        context.saveGState()
        context.addPath(clip)
        context.clip()
        if let media {
            // The context is flipped; CGImage draws bottom-up.
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(media.image, in: CGRect(origin: .zero, size: rect.size))
        } else {
            context.setFillColor(EditorTheme.codeBackground.cgColor)
            context.fill(rect)
        }
        context.restoreGState()

        context.addPath(clip)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(1)
        context.strokePath()

        guard media?.isVideo == true else { return }
        let diameter: CGFloat = 44
        let circle = CGRect(x: rect.midX - diameter / 2, y: rect.midY - diameter / 2, width: diameter, height: diameter)
        context.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        context.fillEllipse(in: circle)
        let triangle = CGMutablePath()
        triangle.move(to: CGPoint(x: circle.midX - 6, y: circle.midY - 9))
        triangle.addLine(to: CGPoint(x: circle.midX + 10, y: circle.midY))
        triangle.addLine(to: CGPoint(x: circle.midX - 6, y: circle.midY + 9))
        triangle.closeSubpath()
        context.addPath(triangle)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath()
    }

    private static func roundedPath(_ rect: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + top))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + top, y: rect.minY), radius: top)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + top), radius: top)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - bottom, y: rect.maxY), radius: bottom)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bottom), radius: bottom)
        path.closeSubpath()
        return path
    }
}
