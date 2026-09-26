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
        textView.setNeedsRefresh([.layout, .focus, .center])
    }

    func showFind() {
        focus()
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        textView?.performTextFinderAction(item)
    }
}
