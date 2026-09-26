import AppKit
import Quartz
import TackKit

final class NoteTextView: NSTextView {
    let fragmentContext = FragmentContext()
    private let caret = CaretView()
    private var layoutDelegate: NoteLayoutDelegate?
    private var quickLookURL: URL?

    var isFocusMode = false {
        didSet { if oldValue != isFocusMode { setNeedsRefresh([.layout, .focus, .center]) } }
    }
    var isTypewriter = true
    var dimsParagraphs = true {
        didSet { if oldValue != dimsParagraphs { setNeedsRefresh(.focus) } }
    }
    var hang: CGFloat = 0
    var onEscape: () -> Void = {}
    var onRestyle: (NSTextStorage) -> Void = { _ in }
    var onColumnWidthChange: (CGFloat) -> Void = { _ in }

    /// Work that resizes, relays out or scrolls. It waits for the end of the current
    /// event, because doing it inside an edit or a layout pass re-enters AppKit's
    /// layout and throws.
    struct Refresh: OptionSet {
        let rawValue: Int
        static let layout = Refresh(rawValue: 1 << 0)
        static let focus = Refresh(rawValue: 1 << 1)
        static let caret = Refresh(rawValue: 1 << 2)
        static let center = Refresh(rawValue: 1 << 3)
        static let animatedCenter = Refresh(rawValue: 1 << 4)
        static let style = Refresh(rawValue: 1 << 5)
    }

    private var pendingRefresh: Refresh = []
    private var focusedAtLastRefresh: NSRange?

    func setNeedsRefresh(_ refresh: Refresh) {
        let isScheduled = !pendingRefresh.isEmpty
        pendingRefresh.formUnion(refresh)
        guard !isScheduled else { return }
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.performRefresh() }
        }
    }

    private func performRefresh() {
        let refresh = pendingRefresh
        pendingRefresh = []
        // Styled after the edit settles, with the selection held: an attribute-only
        // edit makes TextKit 2 remap the insertion point through the restyled range.
        if refresh.contains(.style), let textStorage {
            preservingSelection { onRestyle(textStorage) }
        }
        if refresh.contains(.layout) { layoutForMode() }
        if refresh.contains(.focus) { updateFocusedParagraph(force: refresh.contains(.layout) && isFocusMode && dimsParagraphs) }
        if isFocusMode, isTypewriter, !refresh.isDisjoint(with: [.center, .animatedCenter]) {
            centerCaret(animated: refresh.contains(.animatedCenter) && !refresh.contains(.layout))
        }
        updateCaret()
    }

    static func make() -> NoteTextView {
        let textView = NoteTextView(usingTextLayoutManager: true)
        textView.configure()
        return textView
    }

    private func configure() {
        let delegate = NoteLayoutDelegate(context: fragmentContext)
        layoutDelegate = delegate
        textLayoutManager?.delegate = delegate
        fragmentContext.textLayoutManager = textLayoutManager

        isRichText = false
        importsGraphics = false
        allowsUndo = true
        drawsBackground = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false
        smartInsertDeleteEnabled = false
        isGrammarCheckingEnabled = false
        insertionPointColor = .clear
        selectedTextAttributes = [.backgroundColor: EditorTheme.selection]
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
        registerForDraggedTypes([.fileURL, .png, .tiff])

        caret.isHidden = true
        addSubview(caret)
        NotificationCenter.default.addObserver(self, selector: #selector(windowKeyChanged), name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowKeyChanged), name: NSWindow.didResignKeyNotification, object: nil)
    }

    // MARK: Layout

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard let clip = enclosingScrollView?.contentView else { return }
        clip.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(viewportDidResize), name: NSView.frameDidChangeNotification, object: clip)
    }

    @objc private func viewportDidResize(_ notification: Notification) {
        setNeedsRefresh([.layout, .center])
    }

    /// Insets for the mode: the note's margins, or a centred column with room above
    /// and below for the caret line to sit in the middle of the screen.
    private func layoutForMode() {
        guard let scrollView = enclosingScrollView else { return }
        let viewport = scrollView.contentView.bounds.size
        let inset: NSSize
        if isFocusMode {
            let character = ("n" as NSString).size(withAttributes: [.font: font ?? .systemFont(ofSize: 18)]).width
            let column = min(viewport.width - 96, max(420, character * 68))
            let vertical = isTypewriter ? max(80, viewport.height / 2 - 20) : 96
            inset = NSSize(width: max(24, ((viewport.width - column) / 2).rounded() - hang), height: vertical.rounded())
        } else {
            inset = NSSize(width: 20, height: 6)
        }
        if textContainerInset != inset, let manager = textLayoutManager {
            preservingSelection {
                textContainerInset = inset
                // TextKit 2 leaves laid-out fragments where the old inset put them.
                manager.invalidateLayout(for: manager.documentRange)
                manager.textViewportLayoutController.layoutViewport()
            }
        }
        onColumnWidthChange(max(120, viewport.width - inset.width * 2 - hang))
        // The first layout can run while SwiftUI still has the editor at a smaller size;
        // without this the lines that come into view on growing stay undrawn.
        textLayoutManager?.textViewportLayoutController.layoutViewport()
    }

    // MARK: Caret

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        setNeedsRefresh(stillSelecting ? [.caret, .focus] : [.caret, .focus, .animatedCenter])
    }

    override func didChangeText() {
        super.didChangeText()
        setNeedsRefresh([.style, .caret, .focus, .center])
    }

    override func becomeFirstResponder() -> Bool {
        defer { setNeedsRefresh(.caret) }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        defer { setNeedsRefresh(.caret) }
        return super.resignFirstResponder()
    }

    @objc private func windowKeyChanged(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        setNeedsRefresh(.caret)
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {}

    private func updateCaret() {
        let isActive = window?.isKeyWindow == true && window?.firstResponder === self
        guard isActive, selectedRange().length == 0, let rect = caretRect() else {
            caret.isHidden = true
            return
        }
        caret.isHidden = false
        caret.place(at: rect)
    }

    /// Focus mode's caret is a little wider and taller, like iA Writer's.
    private func caretRect() -> CGRect? {
        guard let manager = textLayoutManager else { return nil }
        let offset = selectedRange().location
        let font = (typingAttributes[.font] as? NSFont) ?? self.font ?? .systemFont(ofSize: 15)
        let width: CGFloat = isFocusMode ? 3 : 2
        let height = (font.ascender - font.descender + (isFocusMode ? 6 : 3)).rounded()
        guard let location = manager.location(manager.documentRange.location, offsetBy: offset) else { return nil }
        var segment: CGRect?
        manager.enumerateTextSegments(in: NSTextRange(location: location), type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            segment = frame
            return false
        }
        let origin = textContainerOrigin
        guard let frame = segment, frame.height > 0 else {
            return CGRect(x: origin.x + hang - 1, y: origin.y, width: width, height: height)
        }
        let y = frame.maxY - height - max(0, (frame.height - height) * 0.12)
        return CGRect(x: (origin.x + frame.minX - width / 2).rounded(), y: (origin.y + y).rounded(), width: width, height: height)
    }

    /// Typewriter scrolling: the line being written stays at the middle of the screen.
    private func centerCaret(animated: Bool) {
        guard let rect = caretRect(), let scrollView = enclosingScrollView else { return }
        let clip = scrollView.contentView
        let target = NSPoint(x: clip.bounds.origin.x, y: max(0, (rect.midY - clip.bounds.height / 2).rounded()))
        guard abs(target.y - clip.bounds.origin.y) > 0.5 else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                clip.animator().setBoundsOrigin(clip.constrainBoundsRect(NSRect(origin: target, size: clip.bounds.size)).origin)
            } completionHandler: {
                MainActor.assumeIsolated { scrollView.reflectScrolledClipView(clip) }
            }
        } else {
            clip.scroll(to: target)
            scrollView.reflectScrolledClipView(clip)
        }
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        if isFocusMode, isTypewriter {
            setNeedsRefresh(.center)
        } else {
            super.scrollRangeToVisible(range)
        }
    }

    // MARK: Focus

    private func updateFocusedParagraph(force: Bool) {
        let focused: NSRange? = isFocusMode && dimsParagraphs
            ? (string as NSString).paragraphRange(for: NSRange(location: selectedRange().location, length: 0))
            : nil
        let previous = fragmentContext.focusedParagraph
        fragmentContext.focusedParagraph = focused
        // Typing changes the paragraph's length, not which paragraph is bright.
        guard force || focused?.location != previous?.location || (focused == nil) != (previous == nil) else { return }
        guard let manager = textLayoutManager else { return }
        preservingSelection {
            if force || previous == nil || focused == nil {
                manager.invalidateLayout(for: manager.documentRange)
            } else {
                for range in [previous, focused].compactMap({ $0 }) { invalidate(range) }
            }
            manager.textViewportLayoutController.layoutViewport()
        }
    }

    /// Invalidating TextKit 2 layout can move the selection; nothing here should.
    private func preservingSelection(_ work: () -> Void) {
        let selection = selectedRanges
        work()
        if selectedRanges != selection { selectedRanges = selection }
    }

    private func invalidate(_ range: NSRange) {
        guard let manager = textLayoutManager,
              let start = manager.location(manager.documentRange.location, offsetBy: min(range.location, (string as NSString).length)),
              let end = manager.location(start, offsetBy: max(0, min(range.length, (string as NSString).length - range.location))),
              let textRange = NSTextRange(location: start, end: end)
        else { return }
        manager.invalidateLayout(for: textRange)
    }

    // MARK: Keys

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }

    override func complete(_ sender: Any?) {
        onEscape()
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if handleClick(at: point, event: event) { return }
        super.mouseDown(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        if let (fragment, local) = fragment(at: point),
           fragment.checkboxRect?.insetBy(dx: -4, dy: -4).contains(local) == true || fragment.mediaRect?.contains(local) == true {
            NSCursor.pointingHand.set()
        }
    }

    private func fragment(at point: NSPoint) -> (NoteLayoutFragment, CGPoint)? {
        let container = CGPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        guard let fragment = textLayoutManager?.textLayoutFragment(for: container) as? NoteLayoutFragment else { return nil }
        let frame = fragment.layoutFragmentFrame
        return (fragment, CGPoint(x: container.x - frame.minX, y: container.y - frame.minY))
    }

    private func handleClick(at point: NSPoint, event: NSEvent) -> Bool {
        if let (fragment, local) = fragment(at: point) {
            if let box = fragment.checkboxRect, box.insetBy(dx: -4, dy: -4).contains(local), let manager = textLayoutManager {
                let start = manager.offset(from: manager.documentRange.location, to: fragment.rangeInElement.location)
                toggleTask(atParagraph: start)
                return true
            }
            if let media = fragment.mediaRect, media.contains(local), let url = fragment.mediaURL {
                if event.clickCount >= 2 {
                    NSWorkspace.shared.open(url)
                } else {
                    showQuickLook(url)
                }
                return true
            }
        }
        if event.modifierFlags.contains(.command) {
            let index = characterIndexForInsertion(at: point)
            if index < (string as NSString).length,
               let destination = textStorage?.attribute(.tackLink, at: index, effectiveRange: nil) as? String {
                open(link: destination)
                return true
            }
        }
        return false
    }

    private func open(link destination: String) {
        if let url = MediaSource.url(for: destination), url.isFileURL {
            NSWorkspace.shared.open(url)
            return
        }
        let text = destination.contains("://") || destination.hasPrefix("mailto:") ? destination : "https://\(destination)"
        guard let url = URL(string: text) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Editing helpers

    func replace(_ range: NSRange, with text: String, selecting selection: NSRange? = nil) {
        guard shouldChangeText(in: range, replacementString: text), let textStorage else { return }
        textStorage.replaceCharacters(in: range, with: text)
        didChangeText()
        if let selection { setSelectedRange(selection) }
    }

    func toggleTask(atParagraph start: Int) {
        let nsString = string as NSString
        let paragraph = nsString.paragraphRange(for: NSRange(location: start, length: 0))
        let line = nsString.substring(with: paragraph).trimmingCharacters(in: .newlines)
        guard case let .task(_, isDone, _, box) = MarkdownParser.parse(line, startsInCode: false).block else { return }
        let selection = selectedRange()
        replace(NSRange(location: paragraph.location + box.location + 1, length: 1), with: isDone ? " " : "x", selecting: selection)
        undoManager?.setActionName(isDone ? "Uncheck" : "Check")
    }
}

extension NoteTextView: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func showQuickLook(_ url: URL) {
        quickLookURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // Quick Look calls these on the main thread, through an informal protocol the
    // compiler cannot see is main-actor.
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        MainActor.assumeIsolated { quickLookURL != nil }
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel?.dataSource = self
            panel?.delegate = self
        }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel?.dataSource = nil
            panel?.delegate = nil
            quickLookURL = nil
        }
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        1
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated { quickLookURL as NSURL? }
    }
}
