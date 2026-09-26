import AppKit
import SwiftUI
import TackKit

/// All notes, full screen over everything, like focus mode for the whole collection.
@MainActor
final class OverviewController: NSObject, NSWindowDelegate {
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
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.collectionBehavior = [.transient, .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.delegate = self
        window.onCancel = { [weak model] in model?.escapeKeyPressed() }
        let hosting = NSHostingView(rootView: OverviewView(model: model))
        hosting.sizingOptions = []
        window.contentView = GlassHost.make(content: hosting, cornerRadius: 0, size: screen.frame.size)
    }

    func present() {
        NSApp.presentationOptions = [.autoHideDock, .autoHideMenuBar]
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
    }

    func dismiss() {
        window.delegate = nil
        NSApp.presentationOptions = []
        let window = window
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { window.orderOut(nil) }
        }
        onClose()
    }

    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }
}
