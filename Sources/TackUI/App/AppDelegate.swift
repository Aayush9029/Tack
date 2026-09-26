import AppKit
import IssueReporting
import KeyboardShortcuts
import SwiftUI
import TackKit

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    let app = AppModel()
    private var controllers: [UUID: NoteWindowController] = [:]
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var overview: OverviewController?
    private var lastUsedWindow: UUID?
    private var observers: [Task<Void, Never>] = []

    override public init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        setUpStatusItem()
        observers = [
            .observing { [app] in app.preferences.showsDockIcon } apply: { showsDock in
                NSApp.setActivationPolicy(showsDock ? .regular : .accessory)
            },
            .observing { [app] in app.preferences.showsMenuBarIcon } apply: { [weak self] in
                self?.statusItem?.isVisible = $0
            },
        ]

        NoteChangeSignal.observe { [weak self] in self?.app.notesChangedOutside() }

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
        controller.onShowOverview = { [weak self] in self?.showOverview(nil) }
        controller.onBecomeKey = { [weak self] id in self?.lastUsedWindow = id }
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

    /// ⌘N when no note has the keyboard; a note window handles it itself otherwise.
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

    @objc func showOverview(_ sender: Any?) {
        if let overview {
            overview.dismiss()
            return
        }
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let model = OverviewModel()
        model.onOpen = { [weak self] id, inNewWindow in self?.overviewOpened(id, inNewWindow: inNewWindow) }
        model.onNewNote = { [weak self] in
            guard let self else { return }
            overview?.dismiss()
            if let controller = lastUsedWindow.flatMap({ controllers[$0] }) ?? controllers.values.first {
                controller.model.newNoteButtonTapped(theme: app.preferences.defaultTheme)
                controller.show()
            } else {
                newNoteInWindow(nil)
            }
        }
        model.onDismiss = { [weak self] in self?.overview?.dismiss() }
        model.onDelete = { [weak self] id in self?.deleteFromOverview(id) }
        let controller = OverviewController(model: model, screen: screen)
        controller.onClose = { [weak self] in self?.overview = nil }
        overview = controller
        controller.present()
    }

    /// A card brings its note up where it already is, or in the note window used last,
    /// so the desktop does not fill with windows. ⌘-click asks for a window of its own.
    private func overviewOpened(_ id: Note.ID, inNewWindow: Bool) {
        overview?.dismiss()
        if let window = app.window(showing: id), let controller = controllers[window.id] {
            controller.show()
        } else if !inNewWindow, let controller = lastUsedWindow.flatMap({ controllers[$0] }) ?? controllers.values.first {
            controller.model.noteSelected(id)
            controller.show()
        } else if let model = app.openButtonTapped(id) {
            open(model)
        }
    }

    /// Unsaved typing lands first; the change signal then moves any window that
    /// showed the note on to a neighbor.
    private func deleteFromOverview(_ id: Note.ID) {
        app.windows.forEach { $0.flush() }
        let store = NoteStore()
        withErrorReporting {
            try store.delete(store.resolve(id.rawValue.uuidString))
        }
    }

    @objc func showAllNotes(_ sender: Any?) {
        NSApp.activate()
        if noteWindows.isEmpty {
            app.launch().forEach(open)
        } else {
            noteWindows.forEach { controller in
                controller.lift()
                controller.window?.orderFront(nil)
            }
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

    // MARK: Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Tack")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "New Note", action: #selector(newNoteInWindow(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "All Notes", action: #selector(showOverview(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Browse Notes…", action: #selector(browseNotes(_:)), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Show All Notes", action: #selector(showAllNotes(_:)), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tack", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.first?.setShortcut(for: .newNote)
        menu.items[3].setShortcut(for: .showNotes)
        item.menu = menu
        statusItem = item
    }
}
