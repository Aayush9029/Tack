import AppKit

/// Shared between the text view and its layout fragments: which paragraph focus
/// mode keeps bright. Unchecked because TextKit only reads it while drawing on
/// the main thread.
final class FragmentContext: @unchecked Sendable {
    weak var textLayoutManager: NSTextLayoutManager?
    var focusedParagraph: NSRange?

    func isDimmed(_ range: NSTextRange) -> Bool {
        guard let focusedParagraph, let manager = textLayoutManager else { return false }
        let start = manager.offset(from: manager.documentRange.location, to: range.location)
        let end = manager.offset(from: manager.documentRange.location, to: range.endLocation)
        let span = NSRange(location: start, length: max(end - start, 1))
        return NSIntersectionRange(focusedParagraph, span).length == 0
            && !(focusedParagraph.length == 0 && NSLocationInRange(focusedParagraph.location, span))
    }
}
