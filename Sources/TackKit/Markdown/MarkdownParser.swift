import Foundation

/// A line-at-a-time Markdown reader for live styling. The only state that crosses a
/// line is whether a code fence is open, so an edit restyles its own paragraph and
/// continues only while that state keeps changing.
public enum MarkdownParser {
    public static func parse(_ line: String, startsInCode: Bool) -> MarkdownParagraph {
        parse(line as NSString, startsInCode: startsInCode)
    }

    public static func parse(_ line: NSString, startsInCode: Bool) -> MarkdownParagraph {
        let length = line.length
        let indentEnd = leadingWhitespace(line)

        if isFence(line, from: indentEnd) {
            return MarkdownParagraph(block: .fence, spans: [MarkdownSpan(.syntax, NSRange(location: 0, length: length))], endsInCode: !startsInCode)
        }
        if startsInCode {
            return MarkdownParagraph(block: .code, endsInCode: true)
        }
        if length == 0 {
            return MarkdownParagraph(block: .body)
        }

        let indent = indentEnd
        if let level = headingLevel(line, from: indentEnd) {
            let marker = NSRange(location: 0, length: min(indentEnd + level + 1, length))
            var spans = inlineSpans(line, from: NSMaxRange(marker))
            spans.insert(MarkdownSpan(.syntax, marker), at: 0)
            return MarkdownParagraph(block: .heading(level: level, marker: marker), spans: spans)
        }
        if isRule(line) {
            return MarkdownParagraph(block: .rule, spans: [MarkdownSpan(.syntax, NSRange(location: 0, length: length))])
        }
        if char(line, indentEnd) == ">" {
            var end = indentEnd + 1
            if char(line, end) == " " { end += 1 }
            let marker = NSRange(location: 0, length: end)
            var spans = inlineSpans(line, from: end)
            spans.insert(MarkdownSpan(.syntax, marker), at: 0)
            return MarkdownParagraph(block: .quote(marker: marker), spans: spans)
        }
        if let bulletChar = char(line, indentEnd), "-*+".contains(bulletChar), char(line, indentEnd + 1) == " " {
            let marker = NSRange(location: indentEnd, length: 2)
            let boxStart = indentEnd + 2
            if let box = char(line, boxStart + 1), char(line, boxStart) == "[", char(line, boxStart + 2) == "]",
               " xX".contains(box), boxStart + 3 == length || char(line, boxStart + 3) == " " {
                let boxRange = NSRange(location: boxStart, length: 3)
                let isDone = box != " "
                let spans = inlineSpans(line, from: min(boxStart + 4, length))
                return MarkdownParagraph(
                    block: .task(indent: indent, isDone: isDone, marker: marker, box: boxRange),
                    spans: spans
                )
            }
            return MarkdownParagraph(block: .bullet(indent: indent, marker: marker), spans: inlineSpans(line, from: boxStart))
        }
        if let markerEnd = orderedMarkerEnd(line, from: indentEnd) {
            let marker = NSRange(location: indentEnd, length: markerEnd - indentEnd)
            var spans = inlineSpans(line, from: markerEnd)
            spans.insert(MarkdownSpan(.syntax, marker), at: 0)
            return MarkdownParagraph(block: .ordered(indent: indent, marker: marker), spans: spans)
        }
        if let source = standaloneImage(line) {
            return MarkdownParagraph(block: .image(source: source), spans: [MarkdownSpan(.syntax, NSRange(location: 0, length: length))])
        }
        return MarkdownParagraph(block: .body, spans: inlineSpans(line, from: 0))
    }

    // MARK: Blocks

    private static func char(_ line: NSString, _ index: Int) -> Character? {
        guard index >= 0, index < line.length else { return nil }
        return Character(UnicodeScalar(line.character(at: index)) ?? " ")
    }

    private static func leadingWhitespace(_ line: NSString) -> Int {
        var index = 0
        while index < line.length {
            let c = line.character(at: index)
            guard c == 0x20 || c == 0x09 else { break }
            index += 1
        }
        return index
    }

    private static func isFence(_ line: NSString, from start: Int) -> Bool {
        guard line.length - start >= 3 else { return false }
        let prefix = line.substring(with: NSRange(location: start, length: 3))
        return prefix == "```" || prefix == "~~~"
    }

    private static func headingLevel(_ line: NSString, from start: Int) -> Int? {
        var level = 0
        while level < 6, char(line, start + level) == "#" { level += 1 }
        guard level > 0 else { return nil }
        let next = start + level
        return next == line.length || char(line, next) == " " ? level : nil
    }

    private static func isRule(_ line: NSString) -> Bool {
        let text = (line as String).filter { $0 != " " }
        guard text.count >= 3, let first = text.first, "-*_".contains(first) else { return false }
        return text.allSatisfy { $0 == first }
    }

    private static func orderedMarkerEnd(_ line: NSString, from start: Int) -> Int? {
        var index = start
        while index < line.length, index - start < 9, let c = char(line, index), c.isASCII, c.isNumber { index += 1 }
        guard index > start, let punctuation = char(line, index), punctuation == "." || punctuation == ")",
              char(line, index + 1) == " "
        else { return nil }
        return index + 2
    }

    private static func standaloneImage(_ line: NSString) -> String? {
        let text = (line as String).trimmingCharacters(in: .whitespaces)
        guard text.hasPrefix("!["), text.hasSuffix(")"),
              let match = Patterns.image.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)),
              match.range.length == (text as NSString).length
        else { return nil }
        return (text as NSString).substring(with: match.range(at: 2))
    }

    // MARK: Inline

    private static func inlineSpans(_ line: NSString, from start: Int) -> [MarkdownSpan] {
        guard start < line.length else { return [] }
        let whole = NSRange(location: start, length: line.length - start)
        var spans: [MarkdownSpan] = []
        var taken: [NSRange] = []

        func isFree(_ range: NSRange) -> Bool {
            !taken.contains { NSIntersectionRange($0, range).length > 0 }
        }

        for match in Patterns.code.matches(in: line as String, range: whole) {
            let range = match.range
            spans.append(MarkdownSpan(.code, range))
            spans.append(MarkdownSpan(.syntax, NSRange(location: range.location, length: 1)))
            spans.append(MarkdownSpan(.syntax, NSRange(location: NSMaxRange(range) - 1, length: 1)))
            taken.append(range)
        }

        for match in Patterns.image.matches(in: line as String, range: whole) where isFree(match.range) {
            spans.append(MarkdownSpan(.syntax, match.range))
            taken.append(match.range)
        }

        for match in Patterns.link.matches(in: line as String, range: whole) where isFree(match.range) {
            let text = match.range(at: 1)
            let url = line.substring(with: match.range(at: 2))
            spans.append(MarkdownSpan(.link(url), text))
            spans.append(MarkdownSpan(.syntax, NSRange(location: match.range.location, length: 1)))
            let tail = NSRange(location: NSMaxRange(text), length: NSMaxRange(match.range) - NSMaxRange(text))
            spans.append(MarkdownSpan(.syntax, tail))
            taken.append(match.range)
        }

        for match in Patterns.autolink.matches(in: line as String, range: whole) where isFree(match.range) {
            spans.append(MarkdownSpan(.link(line.substring(with: match.range)), match.range))
            taken.append(match.range)
        }

        let emphasis: [(NSRegularExpression, MarkdownSpan.Kind, Int)] = [
            (Patterns.bold, .bold, 2),
            (Patterns.strike, .strikethrough, 2),
            (Patterns.highlight, .highlight, 2),
            (Patterns.italicStar, .italic, 1),
            (Patterns.italicUnderscore, .italic, 1),
        ]
        for (pattern, kind, width) in emphasis {
            for match in pattern.matches(in: line as String, range: whole) {
                let range = match.range
                let open = NSRange(location: range.location, length: width)
                let close = NSRange(location: NSMaxRange(range) - width, length: width)
                guard isFree(open), isFree(close) else { continue }
                spans.append(MarkdownSpan(kind, range))
                spans.append(MarkdownSpan(.syntax, open))
                spans.append(MarkdownSpan(.syntax, close))
                taken.append(open)
                taken.append(close)
            }
        }
        return spans
    }

    private enum Patterns {
        static let code = regex(#"`[^`]+`"#)
        static let image = regex(#"!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#)
        static let link = regex(#"(?<!!)\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)"#)
        static let autolink = regex(#"\b(?:https?://|www\.)[^\s<>()]+[^\s<>().,;:!?'"*_~]"#)
        static let bold = regex(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
        static let strike = regex(#"~~(?=\S)(.+?)(?<=\S)~~"#)
        static let highlight = regex(#"==(?=\S)(.+?)(?<=\S)=="#)
        static let italicStar = regex(#"(?<![*\\])\*(?![*\s])([^*\n]+?)(?<![\s*\\])\*(?!\*)"#)
        static let italicUnderscore = regex(#"(?<![\w_])_(?![_\s])([^_\n]+?)(?<![\s_])_(?![\w_])"#)

        private static func regex(_ pattern: String) -> NSRegularExpression {
            // A literal pattern that fails to compile is a programmer error caught by the tests.
            try! NSRegularExpression(pattern: pattern)
        }
    }
}
