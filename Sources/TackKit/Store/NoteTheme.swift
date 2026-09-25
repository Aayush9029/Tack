public struct NoteTheme: Equatable, Hashable, Codable, Sendable {
    public var style: NoteStyle
    public var tint: NoteTint
    public var appearance: NoteAppearance

    public init(style: NoteStyle = .glass, tint: NoteTint = .none, appearance: NoteAppearance = .system) {
        self.style = style
        self.tint = tint
        self.appearance = appearance
    }
}
