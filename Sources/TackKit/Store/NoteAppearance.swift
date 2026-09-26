import SQLiteData

public enum NoteAppearance: String, CaseIterable, Codable, Identifiable, QueryBindable, Sendable {
    case system
    case light
    case dark

    public var id: Self { self }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    public var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}
