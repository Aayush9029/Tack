import AppKit
import Testing
@testable import TackKit
@testable import TackUI

/// Gated: `TACK_BENCH=1 swift test --filter Benchmarks`. Prints timings for the
/// work a keystroke and an opened note cost.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["TACK_BENCH"] != nil))
struct EditorBenchmarks {
    private static func longNote(lines: Int) -> String {
        let kinds = [
            "## Section heading",
            "Plain text with **bold**, *italic*, `code` and a [link](https://example.com) in it.",
            "- [ ] a task that still needs doing",
            "- [x] a task that is done",
            "1. an ordered item",
            "> a quoted line",
            "Another ordinary paragraph that is long enough to wrap once or twice in a narrow sticky note window.",
        ]
        return (0..<lines).map { kinds[$0 % kinds.count] }.joined(separator: "\n")
    }

    private func makeEditor(_ text: String) -> (NSWindow, NoteTextView, MarkdownStyler) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        let textView = NoteTextView.make()
        let styler = MarkdownStyler(theme: EditorTheme(family: .system, size: 15, isFocusMode: false))
        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.documentView = textView
        textView.frame = scrollView.contentView.bounds
        window.contentView = scrollView
        textView.textStorage?.delegate = styler
        textView.onRestyle = { styler.restylePending(in: $0) }
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: styler.baseAttributes))
        window.makeFirstResponder(textView)
        return (window, textView, styler)
    }

    @Test(arguments: [200, 2000])
    func openingANote(lines: Int) {
        let text = Self.longNote(lines: lines)
        let (window, textView, styler) = makeEditor(text)
        let clock = ContinuousClock()
        let styling = clock.measure { styler.styleAll(textView.textStorage!) }
        let layout = clock.measure { textView.textLayoutManager?.textViewportLayoutController.layoutViewport() }
        print("BENCH open \(lines) lines: style \(styling), first viewport layout \(layout)")
        withExtendedLifetime(window) {}
    }

    @Test(arguments: [200, 2000])
    func typingInTheMiddle(lines: Int) async {
        let (window, textView, styler) = makeEditor(Self.longNote(lines: lines))
        styler.styleAll(textView.textStorage!)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length / 2, length: 0))
        textView.scrollRangeToVisible(textView.selectedRange())
        textView.textLayoutManager?.textViewportLayoutController.layoutViewport()
        let clock = ContinuousClock()
        var insert = Duration.zero, restyle = Duration.zero, layout = Duration.zero
        let keys = 200
        for index in 0..<keys {
            insert += clock.measure { textView.insertText(index % 20 == 19 ? " " : "a", replacementRange: textView.selectedRange()) }
            restyle += clock.measure { styler.restylePending(in: textView.textStorage!) }
            layout += clock.measure { textView.textLayoutManager?.textViewportLayoutController.layoutViewport() }
            await Task.yield()
        }
        let manager = textView.textLayoutManager!
        let viewport = manager.textViewportLayoutController.viewportRange.map { manager.offset(from: $0.location, to: $0.endLocation) } ?? -1
        print("BENCH viewport \(viewport) of \((textView.string as NSString).length) characters, visible \(textView.visibleRect)")
        withExtendedLifetime(window) {}
        print("BENCH typing in \(lines) lines, a keystroke: insert \(insert / keys), restyle \(restyle / keys), viewport layout \(layout / keys)")
    }

    @Test func parsingLines() {
        let lines = Self.longNote(lines: 10_000).components(separatedBy: "\n")
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            var inCode = false
            for line in lines { inCode = MarkdownParser.parse(line, startsInCode: inCode).endsInCode }
        }
        print("BENCH parse 10000 lines: \(elapsed), \(elapsed / 10_000) a line")
    }
}
