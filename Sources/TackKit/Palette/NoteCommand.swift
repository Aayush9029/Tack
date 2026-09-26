import CasePaths

@CasePathable
public enum NoteCommand: Hashable, Sendable {
    case newNote
    case newWindow
    case duplicate
    case browse
    case previousNote
    case nextNote
    case find
    case copyAs(CopyFormat)
    case export
    case togglePin
    case toggleFocus
    case setStyle(NoteStyle)
    case setTint(NoteTint)
    case setAppearance(NoteAppearance)
    case rename
    case delete
    case settings
    case overview
    case open(Note.ID)
    case page(PalettePage)
}
