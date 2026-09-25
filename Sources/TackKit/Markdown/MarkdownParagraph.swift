import Foundation

public struct MarkdownParagraph: Equatable, Sendable {
    public var block: MarkdownBlock
    public var spans: [MarkdownSpan]
    /// Whether a code fence is still open after this paragraph.
    public var endsInCode: Bool

    public init(block: MarkdownBlock, spans: [MarkdownSpan] = [], endsInCode: Bool = false) {
        self.block = block
        self.spans = spans
        self.endsInCode = endsInCode
    }
}
