import Dependencies
import Foundation
import SQLiteData

/// Note operations for the command line tool, over the same database the app uses.
public struct NoteStore {
    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.date.now) private var now
    @Dependency(\.uuid) private var uuid

    public init() {}

    public enum Failure: Error, CustomStringConvertible, Equatable {
        case notFound(String)
        case ambiguous(String, [String])
        case noTask(Int, count: Int)

        public var description: String {
            switch self {
            case let .notFound(reference): "No note matches “\(reference)”."
            case let .ambiguous(reference, titles): "“\(reference)” matches \(titles.count) notes: \(titles.joined(separator: ", ")). Use more of the id."
            case let .noTask(number, count): "Task \(number) does not exist; the note has \(count)."
            }
        }
    }

    public struct Task: Equatable, Sendable, Codable {
        public var number: Int
        public var text: String
        public var isDone: Bool
    }

    public func all(limit: Int = 500) throws -> [Note] {
        try database.read { db in try Note.order { $0.updatedAt.desc() }.limit(limit).fetchAll(db) }
    }

    public func search(_ query: String, limit: Int = 40) throws -> [NoteHit] {
        try database.read { db in try NoteSearch.hits(matching: query, limit: limit).fetchAll(db) }
    }

    /// A full id, a unique id prefix, or a title (exact first, then a unique substring).
    public func resolve(_ reference: String) throws -> Note {
        let notes = try all(limit: 100_000)
        let lowered = reference.lowercased()
        if let exact = notes.first(where: { $0.id.rawValue.uuidString.lowercased() == lowered }) { return exact }
        let byID = notes.filter { $0.id.rawValue.uuidString.lowercased().hasPrefix(lowered) }
        if lowered.count >= 4, byID.count == 1 { return byID[0] }
        let byTitle = notes.filter { $0.displayTitle.lowercased() == lowered }
        if byTitle.count == 1 { return byTitle[0] }
        let partial = notes.filter { $0.displayTitle.lowercased().contains(lowered) }
        if partial.count == 1 { return partial[0] }
        let candidates = byTitle.count > 1 ? byTitle : (partial.isEmpty ? byID : partial)
        guard candidates.isEmpty else { throw Failure.ambiguous(reference, candidates.prefix(5).map(\.displayTitle)) }
        throw Failure.notFound(reference)
    }

    @discardableResult
    public func add(body: String, title: String = "", theme: NoteTheme) throws -> Note {
        let note = Note(id: Note.ID(uuid()), title: title, body: body, style: theme.style, tint: theme.tint, appearance: theme.appearance, createdAt: now, updatedAt: now)
        try database.write { db in try Note.insert { note }.execute(db) }
        NoteChangeSignal.post()
        return note
    }

    @discardableResult
    public func update(_ note: Note, body: String? = nil, title: String? = nil, theme: NoteTheme? = nil) throws -> Note {
        var updated = note
        if let body { updated.body = body }
        if let title { updated.title = title }
        if let theme { updated.theme = theme }
        updated.updatedAt = now
        try database.write { db in try Note.update(updated).execute(db) }
        NoteChangeSignal.post()
        return updated
    }

    public func delete(_ note: Note) throws {
        try database.write { db in try Note.find(note.id).delete().execute(db) }
        NoteChangeSignal.post()
    }

    public static func tasks(in body: String) -> [Task] {
        var tasks: [Task] = []
        var inCode = false
        for line in body.components(separatedBy: "\n") {
            let paragraph = MarkdownParser.parse(line, startsInCode: inCode)
            inCode = paragraph.endsInCode
            guard case let .task(_, isDone, _, box) = paragraph.block else { continue }
            let text = (line as NSString).substring(from: min(NSMaxRange(box) + 1, (line as NSString).length))
            tasks.append(Task(number: tasks.count + 1, text: text, isDone: isDone))
        }
        return tasks
    }

    /// The body with task `number` (from 1) checked or unchecked.
    public static func setting(task number: Int, done: Bool, in body: String) throws -> String {
        var lines = body.components(separatedBy: "\n")
        var count = 0
        var inCode = false
        for index in lines.indices {
            let paragraph = MarkdownParser.parse(lines[index], startsInCode: inCode)
            inCode = paragraph.endsInCode
            guard case let .task(_, _, _, box) = paragraph.block else { continue }
            count += 1
            guard count == number else { continue }
            lines[index] = (lines[index] as NSString).replacingCharacters(in: NSRange(location: box.location + 1, length: 1), with: done ? "x" : " ")
            return lines.joined(separator: "\n")
        }
        throw Failure.noTask(number, count: count)
    }

    /// A file name from the note's title, safe on every file system.
    public static func fileName(for note: Note) -> String {
        let title = note.displayTitle
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|\n")).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return "\(title.isEmpty ? NoteText.untitled : String(title.prefix(80))) (\(note.id.rawValue.uuidString.prefix(8).lowercased())).md"
    }
}
