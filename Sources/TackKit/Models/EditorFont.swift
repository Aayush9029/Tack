public enum EditorFont: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case duo
    case quattro
    case mono

    public var id: Self { self }

    public var title: String {
        switch self {
        case .system: "System"
        case .duo: "Duo"
        case .quattro: "Quattro"
        case .mono: "Mono"
        }
    }

    /// PostScript family prefix of the bundled iA Writer fonts.
    public var postScriptPrefix: String? {
        switch self {
        case .system: nil
        case .duo: "iAWriterDuoS"
        case .quattro: "iAWriterQuattroS"
        case .mono: "iAWriterMonoS"
        }
    }
}
