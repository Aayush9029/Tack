import AppKit

final class NoteLayoutDelegate: NSObject, NSTextLayoutManagerDelegate {
    let context: FragmentContext

    init(context: FragmentContext) {
        self.context = context
    }

    func textLayoutManager(
        _ textLayoutManager: NSTextLayoutManager,
        textLayoutFragmentFor location: any NSTextLocation,
        in textElement: NSTextElement
    ) -> NSTextLayoutFragment {
        let fragment = NoteLayoutFragment(textElement: textElement, range: textElement.elementRange)
        fragment.context = context
        return fragment
    }
}
