import Foundation

/// What Return does at the end of a list item or quote.
public enum ListContinuation: Equatable, Sendable {
    case continueWith(String)
    /// The item was empty: remove its marker and end the list.
    case endList
    case none

    public static func after(_ line: String) -> Self {
        let paragraph = MarkdownParser.parse(line, startsInCode: false)
        let nsLine = line as NSString
        let indent = nsLine.substring(to: leadingCount(nsLine))
        switch paragraph.block {
        case let .task(_, _, marker, box):
            let bullet = nsLine.substring(with: marker)
            return isEmpty(nsLine, after: NSMaxRange(box)) ? .endList : .continueWith("\(indent)\(bullet)[ ] ")
        case let .bullet(_, marker):
            let bullet = nsLine.substring(with: marker)
            return isEmpty(nsLine, after: NSMaxRange(marker)) ? .endList : .continueWith("\(indent)\(bullet)")
        case let .ordered(_, marker):
            guard !isEmpty(nsLine, after: NSMaxRange(marker)) else { return .endList }
            let text = nsLine.substring(with: marker)
            let digits = text.prefix { $0.isNumber }
            let punctuation = text.dropFirst(digits.count).prefix(1)
            let next = (Int(digits) ?? 0) + 1
            return .continueWith("\(indent)\(next)\(punctuation) ")
        case let .quote(marker):
            return isEmpty(nsLine, after: NSMaxRange(marker)) ? .endList : .continueWith(nsLine.substring(with: marker))
        default:
            return .none
        }
    }

    private static func leadingCount(_ line: NSString) -> Int {
        var index = 0
        while index < line.length, line.character(at: index) == 0x20 || line.character(at: index) == 0x09 { index += 1 }
        return index
    }

    private static func isEmpty(_ line: NSString, after index: Int) -> Bool {
        guard index < line.length else { return true }
        return line.substring(from: index).trimmingCharacters(in: .whitespaces).isEmpty
    }
}
