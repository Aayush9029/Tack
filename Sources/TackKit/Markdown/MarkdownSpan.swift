import Foundation

public struct MarkdownSpan: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case bold
        case italic
        case strikethrough
        case highlight
        case code
        case link(String)
        /// Punctuation that makes the Markdown: asterisks, backticks, brackets, the URL of a link.
        case syntax
    }

    public var kind: Kind
    public var range: NSRange

    public init(_ kind: Kind, _ range: NSRange) {
        self.kind = kind
        self.range = range
    }
}
