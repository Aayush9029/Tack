import AppKit
import SwiftUI
import TackKit

/// The ⌘K palette in a child window of its note, so it can hang past the note's
/// edges the way a menu does.
@MainActor
final class PaletteController: NSObject, NSWindowDelegate {
    let model: PaletteModel
    private let panel: PalettePanel
    private weak var parent: NSWindow?
    private var height: CGFloat = 320

    init(model: PaletteModel, parent: NSWindow) {
        self.model = model
        self.parent = parent
        panel = PalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.paletteWidth, height: height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.appearance = parent.appearance
        panel.level = parent.level
        panel.delegate = self
        panel.onCancel = { [weak model] in model?.escapeKeyPressed() }

        height = PaletteMetrics.height(of: Array(model.rows))
        let hosting = NSHostingView(rootView: PaletteView(model: model))
        hosting.sizingOptions = []
        panel.contentView = GlassHost.make(content: hosting, cornerRadius: Metrics.paletteRadius, size: NSSize(width: Metrics.paletteWidth, height: height))
    }

    private var observer: Task<Void, Never>?

    func present() {
        observer = Task { [weak self, model] in
            for await rows in Observations({ Array(model.rows) }) {
                self?.resize(to: PaletteMetrics.height(of: rows))
            }
        }
        guard let parent else { return }
        panel.appearance = parent.appearance
        panel.setFrame(frame(height: height, in: parent), display: false)
        panel.alphaValue = 0
        parent.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        observer?.cancel()
        panel.delegate = nil
        parent?.removeChildWindow(panel)
        let panel = panel
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
        if parent?.isVisible == true { parent?.makeKey() }
    }

    private func resize(to height: CGFloat) {
        guard abs(height - self.height) > 0.5, let parent else { return }
        self.height = height
        panel.setFrame(frame(height: height, in: parent), display: true)
    }

    /// Centred on the note, just under its title, and kept on screen.
    private func frame(height: CGFloat, in parent: NSWindow) -> NSRect {
        let parentFrame = parent.frame
        let top = parentFrame.maxY - Metrics.titleBarHeight - 2
        var frame = NSRect(x: (parentFrame.midX - Metrics.paletteWidth / 2).rounded(), y: top - height, width: Metrics.paletteWidth, height: height)
        if let visible = (parent.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX + 8), visible.maxX - frame.width - 8)
            frame.origin.y = max(frame.minY, visible.minY + 8)
            if frame.maxY > visible.maxY - 8 { frame.origin.y = visible.maxY - 8 - frame.height }
        }
        return frame
    }

    func windowDidResignKey(_ notification: Notification) {
        model.onDismiss()
    }
}
