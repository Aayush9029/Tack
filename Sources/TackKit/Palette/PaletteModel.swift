import Dependencies
import Foundation
import IdentifiedCollections
import IssueReporting
import Observation
import SQLiteData

@MainActor
@Observable
public final class PaletteModel: Identifiable {
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database
    @ObservationIgnored @Dependency(\.continuousClock) private var clock

    public private(set) var page: PalettePage
    public private(set) var query = ""
    public private(set) var rows: IdentifiedArrayOf<PaletteRow> = []
    public private(set) var highlighted: PaletteRow.ID?
    public let context: PaletteContext

    @ObservationIgnored private var noteHits: [NoteHit] = []
    @ObservationIgnored public var onCommit: (NoteCommand) -> Void = { _ in }
    @ObservationIgnored public var onDismiss: () -> Void = {}

    public init(page: PalettePage = .root, context: PaletteContext) {
        self.page = page
        self.context = context
        rebuild()
    }

    public var hasSearchableNotes: Bool {
        page == .notes || (page == .root && !query.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    public func queryChanged(_ query: String) {
        self.query = query
        rebuild(resetsHighlight: true)
    }

    /// Called from the view's `.task(id: query)`, so a newer keystroke cancels the older search.
    public func searchNotes() async {
        guard hasSearchableNotes else {
            if !noteHits.isEmpty {
                noteHits = []
                rebuild()
            }
            return
        }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tuning = SearchTuning.current
        let limit = page == .notes ? tuning.resultLimit : 8
        if !text.isEmpty {
            do { try await clock.sleep(for: tuning.debounce) } catch { return }
        }
        let state = Log.signposter.beginInterval("Search notes")
        defer { Log.signposter.endInterval("Search notes", state) }
        let hits = await withErrorReporting {
            try await database.read { db in
                text.isEmpty
                    ? try NoteSearch.recent(limit: limit).fetchAll(db)
                    : try NoteSearch.hits(matching: text, limit: limit, matchLimit: tuning.matchLimit).fetchAll(db)
            }
        } ?? []
        guard !Task.isCancelled else { return }
        noteHits = page == .notes ? hits : hits.filter { $0.id != context.noteID }
        rebuild()
    }

    public func moveHighlight(_ offset: Int) {
        let enabled = rows.filter(\.isEnabled)
        guard !enabled.isEmpty else {
            highlighted = nil
            return
        }
        let current = highlighted.flatMap { id in enabled.firstIndex { $0.id == id } } ?? (offset > 0 ? -1 : 0)
        let next = (current + offset + enabled.count) % enabled.count
        highlighted = enabled[next].id
    }

    public func hover(_ id: PaletteRow.ID) {
        guard rows[id: id]?.isEnabled == true else { return }
        highlighted = id
    }

    public func returnKeyPressed() {
        guard let highlighted else { return }
        rowTapped(highlighted)
    }

    public func rowTapped(_ id: PaletteRow.ID) {
        guard let row = rows[id: id], row.isEnabled else { return }
        switch row {
        case let .item(item):
            if case let .page(page) = item.command {
                open(page)
            } else {
                onCommit(item.command)
            }
        case let .note(hit):
            onCommit(.open(hit.id))
        }
    }

    /// Escape and Delete on an empty field step back to the root page before closing.
    public func escapeKeyPressed() {
        if page != .root && page != .notes {
            open(.root)
        } else if !query.isEmpty {
            queryChanged("")
        } else {
            onDismiss()
        }
    }

    public func deleteOnEmptyField() {
        guard query.isEmpty, page != .root else { return }
        open(.root)
    }

    private func open(_ page: PalettePage) {
        self.page = page
        query = ""
        noteHits = []
        highlighted = nil
        rebuild(resetsHighlight: true)
    }

    private func rebuild(resetsHighlight: Bool = false) {
        let items = PaletteCatalog.items(on: page, in: context)
        let matched: [PaletteItem]
        if query.isEmpty {
            matched = items
        } else {
            let scored: [(item: PaletteItem, score: Int, offset: Int)] = items.enumerated().compactMap { offset, item in
                guard let score = PaletteCatalog.score(item, query: query) else { return nil }
                return (item, score, offset)
            }
            matched = scored
                .sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
                .map { entry in
                    var item = entry.item
                    item.group = 0
                    return item
                }
        }
        var rows = IdentifiedArrayOf<PaletteRow>(uniqueElements: matched.map(PaletteRow.item))
        for hit in noteHits { rows.updateOrAppend(.note(hit)) }
        self.rows = rows
        if resetsHighlight || highlighted.flatMap({ rows[id: $0] })?.isEnabled != true {
            highlighted = rows.first(where: \.isEnabled)?.id
        }
    }
}
