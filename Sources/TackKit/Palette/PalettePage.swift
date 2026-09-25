public enum PalettePage: Hashable, Sendable {
    case root
    case copyAs
    case theme
    case notes

    public var placeholder: String {
        switch self {
        case .root: "Search for actions or notes…"
        case .copyAs: "Copy note as…"
        case .theme: "Style, tint, appearance…"
        case .notes: "Search notes…"
        }
    }
}
