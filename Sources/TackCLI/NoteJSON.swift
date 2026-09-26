import Foundation
import TackKit

struct NoteJSON: Encodable {
    let id: String
    let title: String
    let style: String
    let tint: String
    let appearance: String
    let createdAt: Date
    let updatedAt: Date
    let tasks: TaskCount
    let body: String?

    struct TaskCount: Encodable {
        let done: Int
        let open: Int
    }

    init(_ note: Note, includesBody: Bool) {
        let tasks = NoteStore.tasks(in: note.body)
        id = note.id.rawValue.uuidString.lowercased()
        title = note.displayTitle
        style = note.style.rawValue
        tint = note.tint.rawValue
        appearance = note.appearance.rawValue
        createdAt = note.createdAt
        updatedAt = note.updatedAt
        self.tasks = TaskCount(done: tasks.filter(\.isDone).count, open: tasks.filter { !$0.isDone }.count)
        body = includesBody ? note.body : nil
    }
}
