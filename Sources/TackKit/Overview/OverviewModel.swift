import Tagged
import Dependencies
import Foundation
import IssueReporting
import Observation
import SQLiteData

/// Every note as a card, newest first, narrowed by what is typed in the search field.
@MainActor
@Observable
public final class OverviewModel {
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database
    @ObservationIgnored @Dependency(\.continuousClock) private var clock

    public private(set) var cards: [NoteCard] = []
    public private(set) var query = ""
    public private(set) var isLoaded = false

    @ObservationIgnored public var onOpen: (Note.ID) -> Void = { _ in }
    @ObservationIgnored public var onNewNote: () -> Void = {}
    @ObservationIgnored public var onDismiss: () -> Void = {}

    public init() {}

    public func queryChanged(_ query: String) {
        self.query = query
    }

    /// Called from the view's `.task(id: query)`, so a newer keystroke cancels the older search.
    public func load() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            do { try await clock.sleep(for: .milliseconds(80)) } catch { return }
        }
        let state = Log.signposter.beginInterval("Load overview")
        defer { Log.signposter.endInterval("Load overview", state) }
        let notes = await withErrorReporting {
            try await database.read { db -> [Note] in
                guard !text.isEmpty else {
                    return try Note.order { $0.updatedAt.desc() }.limit(500).fetchAll(db)
                }
                guard NoteSearch.ftsQuery(text) != nil else { return [] }
                let hits = try NoteSearch.hits(matching: text, limit: 200).fetchAll(db)
                let byID = Dictionary(uniqueKeysWithValues: try Note.where { $0.id.in(hits.map(\.id)) }.fetchAll(db).map { ($0.id, $0) })
                return hits.compactMap { byID[$0.id] }
            }
        } ?? []
        guard !Task.isCancelled else { return }
        cards = notes.map(NoteCard.init)
        isLoaded = true
    }

    public func cardTapped(_ id: Note.ID) {
        onOpen(id)
    }

    public func returnKeyPressed() {
        guard let first = cards.first else { return }
        onOpen(first.id)
    }

    public func newNoteButtonTapped() {
        onNewNote()
    }

    public func escapeKeyPressed() {
        if query.isEmpty {
            onDismiss()
        } else {
            query = ""
        }
    }
}
