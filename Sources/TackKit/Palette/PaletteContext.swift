/// What the palette needs to know about the window that opened it.
public struct PaletteContext: Equatable, Sendable {
    public var noteID: Note.ID
    public var hasPrevious: Bool
    public var hasNext: Bool
    public var isPinned: Bool
    public var isFocusMode: Bool
    public var theme: NoteTheme

    public init(
        noteID: Note.ID,
        hasPrevious: Bool = false,
        hasNext: Bool = false,
        isPinned: Bool = false,
        isFocusMode: Bool = false,
        theme: NoteTheme = NoteTheme()
    ) {
        self.noteID = noteID
        self.hasPrevious = hasPrevious
        self.hasNext = hasNext
        self.isPinned = isPinned
        self.isFocusMode = isFocusMode
        self.theme = theme
    }
}
