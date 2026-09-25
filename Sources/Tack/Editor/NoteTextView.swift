import AppKit
import Quartz
import TackKit

final class NoteTextView: NSTextView {
    let fragmentContext = FragmentContext()
    private let caret = CaretView()
    private var layoutDelegate: NoteLayoutDelegate?
    var quickLookURL: URL?

    var isFocusMode = false {
        didSet { if oldValue != isFocusMode { layoutForMode() } }
    }
    var isTypewriter = true
    var dimsParagraphs = true {
        didSet { if oldValue != dimsParagraphs { updateFocusedParagraph(force: true) } }
    }
    var hang: CGFloat = 0
    var onEscape: () -> Void = {}
    var onColumnWidthChange: (CGFloat) -> Void = { _ in }

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
        layoutForMode()
        guard isFocusMode, isTypewriter else { return }
        centerCaret(animated: false)
    }

    func layoutForMode() {
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
            textContainerInset = inset
            // TextKit 2 leaves laid-out fragments where the old inset put them.
            manager.invalidateLayout(for: manager.documentRange)
            manager.textViewportLayoutController.layoutViewport()
        }
        onColumnWidthChange(max(120, viewport.width - inset.width * 2 - hang))
        updateCaret()
    }

    // MARK: Caret

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        updateCaret()
        updateFocusedParagraph()
        if !stillSelecting, isFocusMode, isTypewriter { centerCaret(animated: true) }
    }

    override func didChangeText() {
        super.didChangeText()
        updateCaret()
        updateFocusedParagraph()
        if isFocusMode, isTypewriter { centerCaret(animated: false) }
    }

    override func becomeFirstResponder() -> Bool {
        defer { updateCaret() }
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        defer { updateCaret() }
        return super.resignFirstResponder()
    }

    @objc private func windowKeyChanged(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        updateCaret()
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {}

    func updateCaret() {
        let isActive = window?.isKeyWindow == true && window?.firstResponder === self
        guard isActive, selectedRange().length == 0, let rect = caretRect() else {
            caret.isHidden = true
            return
        }
        caret.isHidden = false
        caret.place(at: rect)
    }

    func caretRect() -> CGRect? {
        guard let manager = textLayoutManager else { return nil }
        let offset = selectedRange().location
        let font = (typingAttributes[.font] as? NSFont) ?? self.font ?? .systemFont(ofSize: 15)
        let height = (font.ascender - font.descender + 3).rounded()
        guard let location = manager.location(manager.documentRange.location, offsetBy: offset) else { return nil }
        var segment: CGRect?
        manager.enumerateTextSegments(in: NSTextRange(location: location), type: .standard, options: [.rangeNotRequired]) { _, frame, _, _ in
            segment = frame
            return false
        }
        let origin = textContainerOrigin
        guard let frame = segment, frame.height > 0 else {
            return CGRect(x: origin.x + hang - 1, y: origin.y, width: 2, height: height)
        }
        let y = frame.maxY - height - max(0, (frame.height - height) * 0.12)
        return CGRect(x: (origin.x + frame.minX - 1).rounded(), y: (origin.y + y).rounded(), width: 2, height: height)
    }

    /// Typewriter scrolling: the line being written stays at the middle of the screen.
    func centerCaret(animated: Bool) {
        guard let manager = textLayoutManager, let scrollView = enclosingScrollView else { return }
        // The view's own height lags an inset change, so the content height comes from TextKit.
        manager.ensureLayout(for: manager.documentRange)
        let contentHeight = manager.usageBoundsForTextContainer.height + textContainerInset.height * 2
        if frame.height < contentHeight {
            setFrameSize(NSSize(width: frame.width, height: contentHeight))
        }
        guard let rect = caretRect() else { return }
        let clip = scrollView.contentView
        let maxY = max(0, max(frame.height, contentHeight) - clip.bounds.height)
        let target = NSPoint(x: clip.bounds.origin.x, y: min(max(0, (rect.midY - clip.bounds.height / 2).rounded()), maxY))
        guard abs(target.y - clip.bounds.origin.y) > 0.5 else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                clip.animator().setBoundsOrigin(target)
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
            centerCaret(animated: false)
        } else {
            super.scrollRangeToVisible(range)
        }
    }

    // MARK: Focus

    func updateFocusedParagraph(force: Bool = false) {
        let focused: NSRange? = isFocusMode && dimsParagraphs
            ? (string as NSString).paragraphRange(for: NSRange(location: selectedRange().location, length: 0))
            : nil
        guard force || focused != fragmentContext.focusedParagraph else { return }
        let previous = fragmentContext.focusedParagraph
        fragmentContext.focusedParagraph = focused
        guard let manager = textLayoutManager else { return }
        if force || previous == nil || focused == nil {
            manager.invalidateLayout(for: manager.documentRange)
        } else {
            for range in [previous, focused].compactMap({ $0 }) { invalidate(range) }
        }
        manager.textViewportLayoutController.layoutViewport()
        needsDisplay = true
    }

    private func invalidate(_ range: NSRange) {
        guard let manager = textLayoutManager,
              let start = manager.location(manager.documentRange.location, offsetBy: range.location),
              let end = manager.location(start, offsetBy: max(range.length, 0)),
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
