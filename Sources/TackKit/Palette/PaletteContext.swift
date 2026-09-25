import Tagged
/// What the palette needs to know about the window that opened it.
public struct PaletteContext: Equatable, Sendable {
    public var noteID: Note.ID
    public var canGoBack = false
    public var canGoForward = false
    public var hasPrevious = false
    public var hasNext = false
    public var isPinned = false
    public var isFocusMode = false
    public var theme = NoteTheme()

    public init(
        noteID: Note.ID,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        hasPrevious: Bool = false,
        hasNext: Bool = false,
        isPinned: Bool = false,
        isFocusMode: Bool = false,
        theme: NoteTheme = NoteTheme()
    ) {
        self.noteID = noteID
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.hasPrevious = hasPrevious
        self.hasNext = hasNext
        self.isPinned = isPinned
        self.isFocusMode = isFocusMode
        self.theme = theme
    }
}
