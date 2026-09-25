import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let newNote = Self("newNote", initial: .init(.n, modifiers: [.control, .option]))
    static let showNotes = Self("showNotes", initial: .init(.s, modifiers: [.control, .option]))
}
