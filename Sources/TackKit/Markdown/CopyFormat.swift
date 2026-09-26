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
