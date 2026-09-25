import Foundation

/// What a paragraph is. Ranges are UTF-16 offsets from the start of the paragraph.
public enum MarkdownBlock: Equatable, Sendable {
    case body
    case heading(level: Int, marker: NSRange)
    case bullet(indent: Int, marker: NSRange)
    case ordered(indent: Int, marker: NSRange)
    case task(indent: Int, isDone: Bool, marker: NSRange, box: NSRange)
    case quote(marker: NSRange)
    case fence
    case code
    case rule
    case image(source: String)

    /// The characters before the text: indentation and list marker, for hanging indents.
    public var prefixLength: Int {
        switch self {
        case let .bullet(_, marker), let .ordered(_, marker), let .quote(marker):
            NSMaxRange(marker)
        case let .task(_, _, _, box):
            NSMaxRange(box) + 1
        default:
            0
        }
    }
}
