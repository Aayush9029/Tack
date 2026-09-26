import AppKit
import SwiftUI
import TackKit
import UniformTypeIdentifiers

@MainActor
final class NoteWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    let model: NoteWindowModel
    private let app: AppModel
    private let state = WindowState()
    private let proxy = EditorProxy()
    private let glass: NSGlassEffectView
    private var swipe: SwipeTracker?
    private var palette: PaletteController?
    private var observers: [Task<Void, Never>] = []
    private var frameBeforeFocus: NSRect?

    var onClose: (NoteWindowController) -> Void = { _ in }
    var onOpenSettings: () -> Void = {}
    var onNewWindow: () -> Void = {}
    var onShowWindow: (UUID) -> Void = { _ in }
    var onShowOverview: () -> Void = {}
    var onBecomeKey: (UUID) -> Void = { _ in }

    static let defaultSize = NSSize(width: 360, height: 320)

    init(model: NoteWindowModel, app: AppModel, frame: NSRect) {
        self.model = model
        self.app = app
        let window = NoteWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 240, height: 160)
        window.animationBehavior = .documentWindow
        window.tabbingMode = .disallowed
        window.title = model.displayTitle

        let proxy = self.proxy
        let state = self.state
        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        // The window sizes the content. Without this the hosting view re-derives its
        // minimum, maximum and intrinsic sizes on every update.
        hosting.sizingOptions = []
        glass = GlassHost.make(content: hosting, cornerRadius: Metrics.windowRadius, size: frame.size)
        window.contentView = glass
        super.init(window: window)

        let actions = NoteWindowActions(
            close: { [weak window] in window?.performClose(nil) },
            escape: { [weak self] in self?.escapePressed() }
        )
        hosting.rootView = AnyView(
            NoteRootView(model: model, preferences: app.preferences, window: state, proxy: proxy, actions: actions)
        )
        window.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(settle), name: NSApplication.didResignActiveNotification, object: nil)
        window.onCancel = { [weak self] in self?.escapePressed() }

        let swipe = SwipeTracker(window: window, state: state)
        swipe.canSwipe = { [weak model] direction in
            guard let model else { return false }
            return direction == .previous ? model.hasPrevious : model.hasNext
        }
        swipe.onCommit = { [weak model] direction in
            direction == .previous ? model?.previousNoteRequested() : model?.nextNoteRequested()
        }
        swipe.install()
        self.swipe = swipe

        observers = [
            .observing { model.isPinned } apply: { [weak self] in self?.applyPinned($0) },
            .observing { model.theme } apply: { [weak self] in self?.applyTheme($0) },
            .observing { model.isFocusMode } apply: { [weak self] in self?.applyFocusMode($0) },
            .observing { model.palette.map(ObjectIdentifier.init) } apply: { [weak self] _ in self?.applyPalette() },
            .observing { model.displayTitle } apply: { [weak window] in window?.title = $0 },
        ]
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        proxy.focus()
    }

    // MARK: Model to window

    /// Desktop widgets: an unpinned note sits on the desktop, under every window, so
    /// no window can bury it and Show Desktop always shows it. While Tack is in use the
    /// note rises above other windows, and it settles back when another app takes over.
    private static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    private var isLifted = false

    private func applyPinned(_ isPinned: Bool) {
        guard let window else { return }
        applyLevel()
        window.collectionBehavior = isPinned
            ? [.transient, .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            : [.stationary, .canJoinAllSpaces, .ignoresCycle]
        app.syncRecords()
    }

    private func applyLevel() {
        window?.level = model.isPinned || model.isFocusMode || isLifted ? .floating : Self.desktopLevel
    }

    /// Above other windows until Tack stops being the active app.
    func lift() {
        guard !isLifted else { return }
        isLifted = true
        applyLevel()
    }

    @objc private func settle() {
        guard isLifted else { return }
        isLifted = false
        applyLevel()
    }

    private func applyTheme(_ theme: NoteTheme) {
        guard let window else { return }
        let appearance: NSAppearance? = switch theme.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        // Classic is paper, so its ink is always dark.
        window.appearance = theme.style == .classic ? NSAppearance(named: .aqua) : appearance
        glass.style = theme.style == .clear ? .clear : .regular
        glass.tintColor = theme.style == .classic ? nil : theme.tint.accent?.withAlphaComponent(theme.style == .clear ? 0.22 : 0.32)
        window.invalidateShadow()
    }

    private func applyPalette() {
        palette?.dismiss()
        palette = nil
        guard let model = model.palette, let window else { return }
        model.onCommit = { [weak self] command in self?.perform(command) }
        model.onDismiss = { [weak self] in self?.model.dismissPalette() }
        let controller = PaletteController(model: model, parent: window)
        palette = controller
        controller.present()
    }

    private func applyFocusMode(_ isFocusMode: Bool) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        if isFocusMode {
            guard frameBeforeFocus == nil else { return }
            frameBeforeFocus = window.frame
            NSApp.activate()
            NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
            GlassHost.setCornerRadius(0, of: glass)
            window.isMovable = false
            window.level = .floating
            window.setFrame(screen.frame, display: true, animate: true)
        } else {
            guard let frame = frameBeforeFocus else { return }
            frameBeforeFocus = nil
            NSApp.presentationOptions = []
            window.setFrame(frame, display: true, animate: true)
            GlassHost.setCornerRadius(Metrics.windowRadius, of: glass)
            window.isMovable = true
            applyPinned(model.isPinned)
        }
        window.invalidateShadow()
        proxy.focus()
        proxy.settleLayout()
    }

    // MARK: Commands

    private func perform(_ command: NoteCommand) {
        model.dismissPalette()
        switch command {
        case .newNote:
            model.newNoteButtonTapped(theme: app.preferences.defaultTheme)
            proxy.focus()
        case .newWindow:
            onNewWindow()
        case .duplicate:
            model.duplicateButtonTapped()
        case .browse:
            model.browseButtonTapped()
        case .previousNote:
            model.previousNoteRequested()
        case .nextNote:
            model.nextNoteRequested()
        case .find:
            proxy.showFind()
        case let .copyAs(format):
            copy(as: format)
        case .export:
            export()
        case .togglePin:
            model.pinButtonTapped()
        case .toggleFocus:
            model.focusModeToggled()
        case let .setStyle(style):
            model.styleSelected(style)
        case let .setTint(tint):
            model.tintSelected(tint)
        case let .setAppearance(appearance):
            model.appearanceSelected(appearance)
        case .rename:
            if model.isFocusMode { model.focusModeExited() }
            model.renameButtonTapped()
        case .delete:
            deleteNote()
        case .overview:
            onShowOverview()
        case .settings:
            onOpenSettings()
        case let .open(id):
            if let other = app.window(showing: id), other !== model {
                onShowWindow(other.id)
            } else {
                model.noteSelected(id)
                proxy.focus()
            }
        case .page:
            break
        }
    }

    private func escapePressed() {
        if model.palette != nil {
            model.dismissPalette()
        } else if model.isRenaming {
            model.renameCancelled()
        } else if model.isFocusMode {
            model.focusModeExited()
        }
    }

    private func copy(as format: CopyFormat) {
        model.flush()
        let markdown = proxy.text
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch format {
        case .markdown:
            pasteboard.setString(markdown, forType: .string)
        case .plainText:
            pasteboard.setString(NoteExport.plainText(markdown), forType: .string)
        case .html:
            let html = NoteExport.html(markdown)
            pasteboard.setString(html, forType: .html)
            pasteboard.setString(html, forType: .string)
        case .richText:
            let html = NoteExport.html(markdown)
            if let data = html.data(using: .utf8),
               let rich = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil),
               let rtf = rich.rtf(from: NSRange(location: 0, length: rich.length)) {
                pasteboard.setData(rtf, forType: .rtf)
            }
            pasteboard.setString(NoteExport.plainText(markdown), forType: .string)
        }
    }

    private func export() {
        model.flush()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = model.displayTitle.replacingOccurrences(of: "/", with: "-") + ".md"
        panel.canCreateDirectories = true
        let text = proxy.text
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func deleteNote() {
        if !model.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Delete “\(model.displayTitle)”?"
            alert.informativeText = "You can’t undo this."
            alert.addButton(withTitle: "Delete").hasDestructiveAction = true
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        model.deleteButtonTapped(fallbackTheme: app.preferences.defaultTheme)
        proxy.focus()
    }

    // MARK: Menu actions

    @objc func newNote(_ sender: Any?) { perform(.newNote) }
    @objc func duplicateNote(_ sender: Any?) { perform(.duplicate) }
    @objc func browseNotes(_ sender: Any?) { model.browseButtonTapped() }
    @objc func showCommandPalette(_ sender: Any?) { model.commandKeyTapped() }
    @objc func showCopyAsPalette(_ sender: Any?) { model.copyAsButtonTapped() }
    @objc func exportNote(_ sender: Any?) { perform(.export) }
    @objc func deleteNote(_ sender: Any?) { perform(.delete) }
    @objc func previousNote(_ sender: Any?) { perform(.previousNote) }
    @objc func nextNote(_ sender: Any?) { perform(.nextNote) }
    @objc func togglePin(_ sender: Any?) { perform(.togglePin) }
    @objc func toggleFocusMode(_ sender: Any?) { perform(.toggleFocus) }
    @objc func renameNote(_ sender: Any?) { perform(.rename) }

    @objc func setNoteStyle(_ sender: NSMenuItem) {
        guard NoteStyle.allCases.indices.contains(sender.tag) else { return }
        perform(.setStyle(NoteStyle.allCases[sender.tag]))
    }

    @objc func setNoteTint(_ sender: NSMenuItem) {
        guard NoteTint.allCases.indices.contains(sender.tag) else { return }
        perform(.setTint(NoteTint.allCases[sender.tag]))
    }

    @objc func setNoteAppearance(_ sender: NSMenuItem) {
        guard NoteAppearance.allCases.indices.contains(sender.tag) else { return }
        perform(.setAppearance(NoteAppearance.allCases[sender.tag]))
    }

    @objc func makeTextBigger(_ sender: Any?) { stepFontSize(1) }
    @objc func makeTextSmaller(_ sender: Any?) { stepFontSize(-1) }

    private func stepFontSize(_ step: Int) {
        let sizes = Preferences.fontSizes
        let preferences = app.preferences
        let current = sizes.firstIndex(of: preferences.noteFontSize) ?? 2
        let next = min(max(current + step, 0), sizes.count - 1)
        preferences.$noteFontSize.withLock { $0 = sizes[next] }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(previousNote(_:)): return model.hasPrevious
        case #selector(nextNote(_:)): return model.hasNext
        case #selector(togglePin(_:)):
            menuItem.title = model.isPinned ? "Unpin from Top" : "Pin on Top"
        case #selector(toggleFocusMode(_:)):
            menuItem.title = model.isFocusMode ? "Exit Focus Mode" : "Focus Mode"
        case #selector(setNoteStyle(_:)):
            menuItem.state = NoteStyle.allCases.firstIndex(of: model.theme.style) == menuItem.tag ? .on : .off
        case #selector(setNoteTint(_:)):
            menuItem.state = NoteTint.allCases.firstIndex(of: model.theme.tint) == menuItem.tag ? .on : .off
        case #selector(setNoteAppearance(_:)):
            menuItem.state = NoteAppearance.allCases.firstIndex(of: model.theme.appearance) == menuItem.tag ? .on : .off
            // Classic is always paper; its appearance would change nothing.
            return model.theme.style != .classic
        case #selector(makeTextBigger(_:)):
            return app.preferences.noteFontSize < (Preferences.fontSizes.last ?? 20)
        case #selector(makeTextSmaller(_:)):
            return app.preferences.noteFontSize > (Preferences.fontSizes.first ?? 13)
        default:
            break
        }
        return true
    }

    // MARK: Window delegate

    func windowDidBecomeKey(_ notification: Notification) {
        state.isKey = true
        lift()
        onBecomeKey(model.id)
    }

    func windowDidResignKey(_ notification: Notification) {
        state.isKey = false
        model.flush()
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveFrame()
        window?.invalidateShadow()
    }

    private func saveFrame() {
        guard let window, !model.isFocusMode else { return }
        app.windowMoved(model.id, frame: window.frame)
    }

    func windowWillClose(_ notification: Notification) {
        if model.isFocusMode {
            NSApp.presentationOptions = []
        }
        palette?.dismiss()
        palette = nil
        swipe?.uninstall()
        observers.forEach { $0.cancel() }
        observers.removeAll()
        app.windowClosed(model.id)
        onClose(self)
    }
}
