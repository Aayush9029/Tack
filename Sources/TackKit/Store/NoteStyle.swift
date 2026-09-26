import SQLiteData

public enum NoteStyle: String, CaseIterable, Codable, Identifiable, QueryBindable, Sendable {
    case glass
    case clear
    case classic

    public var id: Self { self }

    public var title: String {
        switch self {
        case .glass: "Glass"
        case .clear: "Clear"
        case .classic: "Classic"
        }
    }

    public var symbol: String {
        switch self {
        case .glass: "drop"
        case .clear: "drop.halffull"
        case .classic: "note"
        }
    }
}
