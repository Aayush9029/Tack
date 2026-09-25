import AppKit
import SwiftUI
import TackKit

struct NoteEditor: NSViewRepresentable {
    let model: NoteWindowModel
    let configuration: EditorConfiguration
    let proxy: EditorProxy
    let onEscape: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NoteTextView.make()
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.documentView = textView

        let coordinator = context.coordinator
        coordinator.textView = textView
        textView.delegate = coordinator
        textView.textStorage?.delegate = coordinator.styler
        textView.onEscape = onEscape
        textView.onRestyle = { [weak coordinator] storage in coordinator?.styler.restylePending(in: storage) }
        textView.onColumnWidthChange = { [weak coordinator] width in coordinator?.columnWidthChanged(width) }
        proxy.textView = textView
        coordinator.apply(configuration)
        coordinator.load()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.textView?.onEscape = onEscape
        coordinator.apply(configuration)
        if coordinator.revision != model.revision {
            coordinator.load()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: NoteWindowModel
        let styler = MarkdownStyler(theme: EditorTheme(family: .system, size: 15, isFocusMode: false))
        weak var textView: NoteTextView?
        var revision = -1
        private var configuration: EditorConfiguration?
        private var mediaObserver: (any NSObjectProtocol)?

        isolated deinit {
            if let mediaObserver { NotificationCenter.default.removeObserver(mediaObserver) }
        }

        init(model: NoteWindowModel) {
            self.model = model
            super.init()
            mediaObserver = NotificationCenter.default.addObserver(forName: MediaCache.didLoad, object: nil, queue: .main) { [weak self] notification in
                let url = notification.object as? URL
                MainActor.assumeIsolated { self?.mediaLoaded(url) }
            }
        }

        func load() {
            guard let textView, let storage = textView.textStorage else { return }
            let state = Log.signposter.beginInterval("Load note")
            defer { Log.signposter.endInterval("Load note", state) }
            revision = model.revision
            textView.typingAttributes = styler.baseAttributes
            storage.setAttributedString(NSAttributedString(string: model.body, attributes: styler.baseAttributes))
            styler.styleAll(storage)
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: (model.body as NSString).length, length: 0))
            textView.enclosingScrollView?.contentView.scroll(to: .zero)
            textView.setNeedsRefresh([.layout, .focus, .center])
        }

        func apply(_ configuration: EditorConfiguration) {
            guard configuration != self.configuration, let textView, let storage = textView.textStorage else { return }
            let previous = self.configuration
            self.configuration = configuration
            textView.isContinuousSpellCheckingEnabled = configuration.checksSpelling
            textView.isTypewriter = configuration.isTypewriter
            let family = configuration.family
            let size = configuration.pointSize
            guard !styler.theme.matches(family: family, size: size, isFocusMode: configuration.isFocusMode) || previous == nil else {
                textView.dimsParagraphs = configuration.dimsParagraphs
                textView.setNeedsRefresh(.layout)
                return
            }
            let theme = EditorTheme(family: family, size: size, isFocusMode: configuration.isFocusMode)
            styler.theme = theme
            styler.maxMediaHeight = configuration.isFocusMode ? 420 : 240
            textView.font = theme.bodyFont
            textView.hang = theme.hang
            textView.typingAttributes = styler.baseAttributes
            textView.isFocusMode = configuration.isFocusMode
            textView.dimsParagraphs = configuration.dimsParagraphs
            styler.styleAll(storage)
            textView.setNeedsRefresh([.layout, .focus, .center])
        }

        func columnWidthChanged(_ width: CGFloat) {
            guard abs(styler.columnWidth - width) > 1, let storage = textView?.textStorage else { return }
            styler.columnWidth = width
            styler.restyleMedia(in: storage)
        }

        private func mediaLoaded(_ url: URL?) {
            guard let storage = textView?.textStorage, let url else { return }
            styler.restyleMedia(in: storage, matching: url)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            model.textChanged(textView.string)
        }

        /// Code, links and media sources are not prose: no spelling marks on them.
        func textView(
            _ view: NSTextView,
            didCheckTextIn range: NSRange,
            types checkingTypes: NSTextCheckingTypes,
            options: [NSSpellChecker.OptionKey: Any] = [:],
            results: [NSTextCheckingResult],
            orthography: NSOrthography,
            wordCount: Int
        ) -> [NSTextCheckingResult] {
            guard let storage = view.textStorage else { return results }
            return results.filter { result in
                guard result.resultType == .spelling || result.resultType == .grammar,
                      result.range.location < storage.length
                else { return true }
                let attributes = storage.attributes(at: result.range.location, effectiveRange: nil)
                let isCode = (attributes[.font] as? NSFont)?.isFixedPitch == true
                return !isCode && attributes[.tackLink] == nil
            }
        }

        func textView(_ textView: NSTextView, shouldChangeTypingAttributes oldTypingAttributes: [String: Any], toAttributes newTypingAttributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
            styler.baseAttributes
        }
    }
}
