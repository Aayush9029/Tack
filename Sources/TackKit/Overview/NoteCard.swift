import Tagged
import Foundation

public struct NoteCard: Identifiable, Equatable, Sendable {
    public let id: Note.ID
    public let title: String
    public let lines: [PreviewLine]
    public let theme: NoteTheme
    public let doneTasks: Int
    public let totalTasks: Int
    public let updatedAt: Date

    public init(_ note: Note) {
        id = note.id
        title = note.displayTitle
        let lines = PreviewLine.lines(from: note.body)
        // The title is usually the first line; the card shows it once.
        if case let .heading(text)? = lines.first, text == note.displayTitle {
            self.lines = Array(lines.dropFirst())
        } else if case let .text(text)? = lines.first, text == note.displayTitle {
            self.lines = Array(lines.dropFirst())
        } else {
            self.lines = lines
        }
        theme = note.theme
        let tasks = NoteStore.tasks(in: note.body)
        doneTasks = tasks.filter(\.isDone).count
        totalTasks = tasks.count
        updatedAt = note.updatedAt
    }

    /// Roughly how tall the card draws, in lines, for placing it in the shortest column.
    public var weight: Int { 3 + lines.count + (totalTasks > 0 ? 1 : 0) }
}
