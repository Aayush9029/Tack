import Foundation
import TackKit

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

    static func taskLine(_ task: NoteStore.Task) -> String {
        "\(task.number). [\(task.isDone ? "x" : " ")] \(task.text)"
    }

    /// Text piped in, when there is any.
    static func standardInput() -> String? {
        guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else { return nil }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return data.isEmpty ? nil : String(decoding: data, as: UTF8.self)
    }
}
