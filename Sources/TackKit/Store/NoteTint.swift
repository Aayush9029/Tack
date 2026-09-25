import SQLiteData

public enum NoteTint: String, CaseIterable, Codable, Identifiable, QueryBindable, Sendable {
    case none
    case yellow
    case green
    case pink
    case purple
    case blue
    case gray

    public var id: Self { self }

    public var title: String {
        switch self {
        case .none: "None"
        case .yellow: "Yellow"
        case .green: "Green"
        case .pink: "Pink"
        case .purple: "Purple"
        case .blue: "Blue"
        case .gray: "Gray"
        }
    }
}
