import AppKit
import SwiftUI
import TackKit

/// All notes, full screen over everything, like focus mode for the whole collection.
@MainActor
final class OverviewController: NSObject {
    let model: OverviewModel
    private let window: OverviewWindow
    var onClose: () -> Void = {}

    init(model: OverviewModel, screen: NSScreen) {
        self.model = model
        window = OverviewWindow(contentRect: screen.frame, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        // Over the menu bar and the Dock, so nothing but the notes shows.
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.transient, .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        // Closing on resigning key would close it for its own context menus and
        // confirmations; it covers the screen, so only another app can take over.
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidResignActive), name: NSApplication.didResignActiveNotification, object: nil)
        window.onCancel = { [weak model] in model?.escapeKeyPressed() }
        let hosting = NSHostingView(rootView: OverviewView(model: model, topInset: max(44, screen.safeAreaInsets.top + 24)))
        hosting.sizingOptions = []
        window.contentView = GlassHost.make(content: hosting, cornerRadius: 0, size: screen.frame.size)
    }

    func present() {
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
    }

    func dismiss() {
        NotificationCenter.default.removeObserver(self)
        let window = window
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { window.orderOut(nil) }
        }
        onClose()
    }

    @objc private func applicationDidResignActive() {
        dismiss()
    }
}
