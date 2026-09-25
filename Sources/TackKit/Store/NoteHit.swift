import Tagged
import Foundation
import SQLiteData

@Selection
public struct NoteHit: Identifiable, Equatable, Sendable {
    public let id: Note.ID
    public let title: String
    public let inferredTitle: String
    /// The first few hundred characters of the body, enough to name and preview the note.
    public let head: String
    /// The matching words in context. Empty when listing without a query.
    public let snippet: String
    public let tint: NoteTint
    public let doneTasks: Int
    public let openTasks: Int
    public let updatedAt: Date

    public init(
        id: Note.ID,
        title: String = "",
        inferredTitle: String = "",
        head: String = "",
        snippet: String = "",
        tint: NoteTint = .none,
        doneTasks: Int = 0,
        openTasks: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.inferredTitle = inferredTitle
        self.head = head
        self.snippet = snippet
        self.tint = tint
        self.doneTasks = doneTasks
        self.openTasks = openTasks
        self.updatedAt = updatedAt
    }

    public var displayTitle: String {
        NoteText.displayTitle(custom: title, body: head, inferred: inferredTitle)
    }

    public var subtitle: String {
        snippet.isEmpty ? NoteText.preview(from: head) : snippet
    }

    public var totalTasks: Int { doneTasks + openTasks }
}
