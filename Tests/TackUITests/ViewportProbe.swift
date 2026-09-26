import AppKit
import Testing
@testable import TackUI

@MainActor
@Suite struct ViewportProbe {
    @Test func lastParagraphIsLaidOutInAShortNote() async throws {
        let body = "# Saturday\nFarmers market first, then errands.\n\n- [x] Pick up dry cleaning\n- [x] Call mom back\n- [ ] Oat milk, eggs, basil\n- [ ] Book the dentist for next week\n\nDinner at **Nora's** at 7:30. Bring the *good* wine.\n\n> Charger in the bag this time."
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 320), styleMask: [.borderless], backing: .buffered, defer: false)
        let textView = NoteTextView.make()
        let styler = MarkdownStyler(theme: EditorTheme(family: .system, size: 15, isFocusMode: false))
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
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
        let viewport = manager.textViewportLayoutController.viewportRange.map { manager.offset(from: $0.location, to: $0.endLocation) } ?? -1
        print("PROBE viewport \(viewport) of \((body as NSString).length); text view \(textView.frame); last fragment \(fragments.last ?? .zero); usage \(manager.usageBoundsForTextContainer)")
        withExtendedLifetime(window) {}
    }
}
