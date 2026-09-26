import AppKit

/// iA Writer's caret: a blue bar a little wider than the system's. It holds still
/// while typing and blinks only when the writer pauses.
final class CaretView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = EditorTheme.caret.cgColor
        layer?.cornerRadius = 1
        layer?.actions = ["position": NSNull(), "bounds": NSNull(), "opacity": NSNull()]
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func place(at rect: CGRect) {
        frame = rect
        restartBlink()
    }

    func restartBlink() {
        guard let layer else { return }
        layer.removeAnimation(forKey: "blink")
        layer.opacity = 1
        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = [1, 1, 0, 0, 1]
        blink.keyTimes = [0, 0.45, 0.55, 0.9, 1]
        blink.duration = 1.1
        blink.repeatCount = .infinity
        blink.beginTime = CACurrentMediaTime() + 0.6
        layer.add(blink, forKey: "blink")
    }
}
