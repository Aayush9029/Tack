import ArgumentParser
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

enum Output {
    static func json(_ value: some Encodable) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        print(String(decoding: try encoder.encode(value), as: UTF8.self))
    }

    static func row(_ note: Note) -> String {
        let tasks = NoteStore.tasks(in: note.body)
        let progress = tasks.isEmpty ? "" : "  [\(tasks.filter(\.isDone).count)/\(tasks.count)]"
        return "\(note.id.rawValue.uuidString.prefix(8).lowercased())  \(note.displayTitle)\(progress)"
    }

    /// Text piped in, when there is any.
    static func standardInput() -> String? {
        guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else { return nil }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return data.isEmpty ? nil : String(decoding: data, as: UTF8.self)
    }
}

extension NoteStyle: ExpressibleByArgument {}
extension NoteTint: ExpressibleByArgument {}
extension NoteAppearance: ExpressibleByArgument {}
