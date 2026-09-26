import AppKit
import Testing
@testable import TackUI

@MainActor
@Suite struct ViewportTests {
    @Test func aShortNoteIsLaidOutToItsLastLine() async throws {
        let body = "# Saturday\nFarmers market first, then errands.\n\n- [x] Pick up dry cleaning\n- [x] Call mom back\n- [ ] Oat milk, eggs, basil\n- [ ] Book the dentist for next week\n\nDinner at **Nora's** at 7:30. Bring the *good* wine.\n\n> Charger in the bag this time."
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 320), styleMask: [.borderless], backing: .buffered, defer: false)
        let textView = NoteTextView.make()
        let styler = MarkdownStyler(theme: EditorTheme(family: .system, size: 15, isFocusMode: false))
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.documentView = textView
        textView.frame = scrollView.contentView.bounds
        window.contentView = scrollView
        textView.textStorage?.delegate = styler
        textView.onRestyle = { styler.restylePending(in: $0) }
        textView.textStorage?.setAttributedString(NSAttributedString(string: body, attributes: styler.baseAttributes))
        styler.styleAll(textView.textStorage!)
        textView.setNeedsRefresh([.layout, .focus, .center])
        try await Task.sleep(for: .milliseconds(50))
        window.displayIfNeeded()
        let manager = try #require(textView.textLayoutManager)
        var fragments: [CGRect] = []
        manager.enumerateTextLayoutFragments(from: manager.documentRange.location, options: [.ensuresLayout]) { fragment in
            fragments.append(fragment.layoutFragmentFrame)
            return true
        }
        let viewport = try #require(manager.textViewportLayoutController.viewportRange)
        #expect(manager.offset(from: viewport.location, to: viewport.endLocation) == (body as NSString).length)
        #expect((fragments.last?.maxY ?? .infinity) + textView.textContainerInset.height <= textView.frame.height)
        #expect(scrollView.contentInsets.bottom == Metrics.titleBarHeight)
        withExtendedLifetime(window) {}
    }
}
