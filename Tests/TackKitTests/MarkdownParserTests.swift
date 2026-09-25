import CustomDump
import Foundation
import Testing
@testable import TackKit

@Suite struct MarkdownParserTests {
    @Test func heading() {
        let paragraph = MarkdownParser.parse("## Plan", startsInCode: false)
        #expect(paragraph.block == .heading(level: 2, marker: NSRange(location: 0, length: 3)))
    }

    @Test func hashWithoutSpaceIsNotAHeading() {
        #expect(MarkdownParser.parse("#tag", startsInCode: false).block == .body)
    }

    @Test func tasks() {
        let open = MarkdownParser.parse("- [ ] milk", startsInCode: false)
        #expect(open.block == .task(indent: 0, isDone: false, marker: NSRange(location: 0, length: 2), box: NSRange(location: 2, length: 3)))
        let done = MarkdownParser.parse("  * [x] eggs", startsInCode: false)
        #expect(done.block == .task(indent: 2, isDone: true, marker: NSRange(location: 2, length: 2), box: NSRange(location: 4, length: 3)))
    }

    @Test func listsAndQuotes() {
        #expect(MarkdownParser.parse("- item", startsInCode: false).block == .bullet(indent: 0, marker: NSRange(location: 0, length: 2)))
        #expect(MarkdownParser.parse("12. item", startsInCode: false).block == .ordered(indent: 0, marker: NSRange(location: 0, length: 4)))
        #expect(MarkdownParser.parse("> said", startsInCode: false).block == .quote(marker: NSRange(location: 0, length: 2)))
        #expect(MarkdownParser.parse("---", startsInCode: false).block == .rule)
    }

    @Test func fencesCarryStateAcrossLines() {
        let open = MarkdownParser.parse("```swift", startsInCode: false)
        #expect(open.block == .fence)
        #expect(open.endsInCode)
        let inside = MarkdownParser.parse("# not a heading", startsInCode: true)
        #expect(inside.block == .code)
        #expect(inside.endsInCode)
        let close = MarkdownParser.parse("```", startsInCode: true)
        #expect(close.block == .fence)
        #expect(!close.endsInCode)
    }

    @Test func standaloneImage() {
        #expect(MarkdownParser.parse("![](attachments/a.png)", startsInCode: false).block == .image(source: "attachments/a.png"))
        #expect(MarkdownParser.parse("see ![](a.png)", startsInCode: false).block == .body)
    }

    @Test func inlineSpans() {
        let spans = MarkdownParser.parse("a **b** *c* `d` [e](https://x.y)", startsInCode: false).spans
        let kinds = spans.filter { $0.kind != .syntax }
        expectNoDifference(kinds, [
            MarkdownSpan(.code, NSRange(location: 12, length: 3)),
            MarkdownSpan(.link("https://x.y"), NSRange(location: 17, length: 1)),
            MarkdownSpan(.bold, NSRange(location: 2, length: 5)),
            MarkdownSpan(.italic, NSRange(location: 8, length: 3)),
        ])
    }

    @Test func codeSpanHidesEmphasis() {
        let spans = MarkdownParser.parse("`**not bold**`", startsInCode: false).spans
        #expect(!spans.contains { $0.kind == .bold })
    }

    @Test func autolink() {
        let spans = MarkdownParser.parse("go to https://apple.com.", startsInCode: false).spans
        #expect(spans == [MarkdownSpan(.link("https://apple.com"), NSRange(location: 6, length: 17))])
    }
}
