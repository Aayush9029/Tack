import Tagged
import Dependencies
import Foundation
import SQLiteData

/// Raycast notes into Tack, keeping their dates. A note whose text is already in Tack
/// is skipped, so importing the same export twice adds nothing.
public struct RaycastImport {
    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.uuid) private var uuid

    public struct Result: Equatable, Sendable {
        public var imported: Int
        public var skipped: Int
    }

    public init() {}

    public func run(_ notes: [RaycastExport.Note], theme: NoteTheme) throws -> Result {
        let result = try database.write { db in
            var result = Result(imported: 0, skipped: 0)
            for note in notes {
                let body = note.text.trimmingCharacters(in: .newlines)
                guard try Note.where({ $0.body.eq(body) }).fetchCount(db) == 0 else {
                    result.skipped += 1
                    continue
                }
                // Raycast titles a note by its first line; keep the title only when it says something else.
                let title = NoteText.title(from: body) == note.title.trimmingCharacters(in: .whitespaces) ? "" : note.title
                try Note.insert {
                    Note(
                        id: Note.ID(uuid()),
                        title: title,
                        body: body,
                        style: theme.style,
                        tint: theme.tint,
                        appearance: theme.appearance,
                        createdAt: note.createdAt,
                        updatedAt: note.updatedAt
                    )
                }
                .execute(db)
                result.imported += 1
            }
            return result
        }
        if result.imported > 0 { NoteChangeSignal.post() }
        return result
    }
}
