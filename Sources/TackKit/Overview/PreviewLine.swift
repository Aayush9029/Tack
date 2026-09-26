import Foundation

/// One line of a note as a card shows it: the Markdown read, the punctuation gone.
public enum PreviewLine: Equatable, Sendable {
    case heading(String)
    case task(String, isDone: Bool)
    case bullet(String)
    case quote(String)
    case code(String)
    case text(String)

    /// The first lines of a note worth showing on a card, blank lines and media left out.
    public static func lines(from body: String, limit: Int = 9) -> [PreviewLine] {
        var lines: [PreviewLine] = []
        var inCode = false
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            guard lines.count < limit else { break }
            let line = String(raw)
            let paragraph = MarkdownParser.parse(line, startsInCode: inCode)
            inCode = paragraph.endsInCode
            let text = { (from: Int) in NoteText.plain((line as NSString).substring(from: min(from, (line as NSString).length))) }
            switch paragraph.block {
            case let .heading(_, marker): lines.append(.heading(text(NSMaxRange(marker))))
            case let .task(_, isDone, _, box): lines.append(.task(text(NSMaxRange(box) + 1), isDone: isDone))
            case let .bullet(_, marker), let .ordered(_, marker): lines.append(.bullet(text(NSMaxRange(marker))))
            case let .quote(marker): lines.append(.quote(text(NSMaxRange(marker))))
            case .code: lines.append(.code(line))
            case .body:
                let plain = text(0)
                if !plain.isEmpty { lines.append(.text(plain)) }
            case .fence, .rule, .image:
                continue
            }
        }
        return lines
    }
}
