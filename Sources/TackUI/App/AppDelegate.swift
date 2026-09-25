import AppKit
import KeyboardShortcuts
import SwiftUI
import TackKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let app = AppModel()

    override public init() {
        super.init()
    }
    private var controllers: [UUID: NoteWindowController] = [:]
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var observers: [Task<Void, Never>] = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        setUpStatusItem()
        observe { [app] in app.preferences.showsDockIcon } apply: { showsDock in
            NSApp.setActivationPolicy(showsDock ? .regular : .accessory)
        }
        observe { [app] in app.preferences.showsMenuBarIcon } apply: { [weak self] in
            self?.statusItem?.isVisible = $0
        }

        for model in app.launch() {
            open(model)
        }
        NSApp.activate()

        KeyboardShortcuts.onKeyDown(for: .newNote) { [weak self] in
            Task { @MainActor in
                NSApp.activate()
                self?.newNoteInWindow(nil)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .showNotes) { [weak self] in
            Task { @MainActor in self?.toggleNotes() }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        app.applicationWillTerminate()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { showAllNotes(nil) }
        return true
    }

    private func observe<Value: Equatable & Sendable>(
        _ value: @escaping @MainActor @Sendable () -> Value,
        apply: @escaping @MainActor (Value) -> Void
    ) {
        observers.append(Task { @MainActor in
            for await current in Observations(value) { apply(current) }
        })
    }

    // MARK: Windows

    private func open(_ model: NoteWindowModel) {
        let frame = app.frame(for: model.id).flatMap(onScreen) ?? cascadedFrame()
        let controller = NoteWindowController(model: model, app: app, frame: frame)
        controller.onClose = { [weak self] controller in
            self?.controllers[controller.model.id] = nil
        }
        controller.onOpenSettings = { [weak self] in self?.showSettings(nil) }
        controller.onNewWindow = { [weak self] in self?.newNoteInWindow(nil) }
        controller.onShowWindow = { [weak self] id in self?.controllers[id]?.show() }
        controllers[model.id] = controller
        controller.show()
    }

    private func onScreen(_ frame: CGRect) -> NSRect? {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) } ? frame : nil
    }

    /// New notes step down and right from the key note, like cascading windows.
    private func cascadedFrame() -> NSRect {
        let size = NoteWindowController.defaultSize
        if let key = NSApp.keyWindow as? NoteWindow, let screen = key.screen {
            var origin = NSPoint(x: key.frame.minX + 28, y: key.frame.maxY - 28 - size.height)
            let visible = screen.visibleFrame
            if origin.x + size.width > visible.maxX || origin.y < visible.minY {
                origin = NSPoint(x: visible.minX + 60, y: visible.maxY - 60 - size.height)
            }
            return NSRect(origin: origin, size: size)
        }
        let visible = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        return NSRect(x: visible.maxX - size.width - 64, y: visible.maxY - size.height - 64, width: size.width, height: size.height)
    }

    private var noteWindows: [NoteWindowController] {
        Array(controllers.values)
    }

    private func toggleNotes() {
        if NSApp.isActive, noteWindows.contains(where: { $0.window?.isVisible == true }) {
            NSApp.hide(nil)
        } else {
            showAllNotes(nil)
        }
    }

    // MARK: Actions

    @objc func newNote(_ sender: Any?) {
        newNoteInWindow(sender)
    }

    @objc func newNoteInWindow(_ sender: Any?) {
        guard let model = app.newWindowButtonTapped() else { return }
        open(model)
    }

    @objc func browseNotes(_ sender: Any?) {
        if let controller = (NSApp.keyWindow?.delegate as? NoteWindowController) ?? noteWindows.first {
            controller.show()
            controller.model.browseButtonTapped()
        } else if let model = app.launch().first {
            open(model)
            model.browseButtonTapped()
        }
    }

    @objc func showAllNotes(_ sender: Any?) {
        NSApp.activate()
        if noteWindows.isEmpty {
            app.launch().forEach(open)
        } else {
            noteWindows.forEach { $0.window?.orderFront(nil) }
            noteWindows.first?.window?.makeKey()
        }
    }

    @objc func showAbout(_ sender: Any?) {
        showSettings(tab: .about)
    }

    @objc func showSettings(_ sender: Any?) {
        showSettings(tab: nil)
    }

    private func showSettings(tab: SettingsTab?) {
        let view = SettingsView(app: app, initialTab: tab ?? .general)
        if let settingsWindow {
            if tab != nil { settingsWindow.contentView = NSHostingView(rootView: view) }
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Tack Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        true
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Tack")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "New Note", action: #selector(newNoteInWindow(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Browse Notes…", action: #selector(browseNotes(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Show All Notes", action: #selector(showAllNotes(_:)), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.first?.setShortcut(for: .newNote)
        menu.items[2].setShortcut(for: .showNotes)
        item.menu = menu
        statusItem = item
    }
}
