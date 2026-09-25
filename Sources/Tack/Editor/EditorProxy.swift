import AppKit

/// Lets the window reach the editor for commands that need the live text.
@MainActor
final class EditorProxy {
    weak var textView: NoteTextView?

    var text: String { textView?.string ?? "" }

    func focus() {
        guard let textView, let window = textView.window else { return }
        window.makeFirstResponder(textView)
    }

    /// After the window finishes resizing, lay the text out for its final size.
    func settleLayout() {
        guard let textView else { return }
        textView.layoutForMode()
        if textView.isFocusMode, textView.isTypewriter { textView.centerCaret(animated: false) }
        textView.updateCaret()
    }

    func showFind() {
        focus()
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        textView?.performTextFinderAction(item)
    }

    func selectAllAndFocus() {
        focus()
        textView?.setSelectedRange(NSRange(location: textView?.string.utf16.count ?? 0, length: 0))
    }
}
