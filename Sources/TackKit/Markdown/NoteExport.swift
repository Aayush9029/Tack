import Foundation
import Markdown

public enum CopyFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case plainText
    case richText
    case html

    public var id: Self { self }

    public var title: String {
        switch self {
        case .markdown: "Markdown"
        case .plainText: "Plain Text"
        case .richText: "Rich Text"
        case .html: "HTML"
        }
    }

    public var symbol: String {
        switch self {
        case .markdown: "number"
        case .plainText: "text.alignleft"
        case .richText: "textformat"
        case .html: "chevron.left.forwardslash.chevron.right"
        }
    }
}

public enum NoteExport {
    public static func html(_ markdown: String) -> String {
        HTMLFormatter.format(Document(parsing: markdown, options: [.parseBlockDirectives]))
    }

    public static func plainText(_ markdown: String) -> String {
        var walker = PlainTextWalker()
        walker.visit(Document(parsing: markdown))
        return walker.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PlainTextWalker: MarkupWalker {
    var text = ""

    mutating func visitText(_ text: Text) { self.text += text.string }
    mutating func visitInlineCode(_ inlineCode: InlineCode) { text += inlineCode.code }
    mutating func visitSoftBreak(_ softBreak: SoftBreak) { text += " " }
    mutating func visitLineBreak(_ lineBreak: LineBreak) { text += "\n" }
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) { text += codeBlock.code + "\n" }
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) { text += "\n" }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        descendInto(paragraph)
        text += "\n"
    }

    mutating func visitHeading(_ heading: Heading) {
        descendInto(heading)
        text += "\n"
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let depth = sequence(first: listItem.parent, next: { $0?.parent }).filter { $0 is ListItem }.count
        text += String(repeating: "  ", count: depth)
        if let checkbox = listItem.checkbox {
            text += checkbox == .checked ? "☑ " : "☐ "
        } else if let list = listItem.parent as? OrderedList {
            text += "\(Int(list.startIndex) + listItem.indexInParent). "
        } else {
            text += "• "
        }
        descendInto(listItem)
    }
}
