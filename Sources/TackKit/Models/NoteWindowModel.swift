import Tagged
import DebugSnapshots
import Dependencies
import Foundation
import IssueReporting
import Observation
import Sharing
import SQLiteData

@DebugSnapshot
@MainActor
@Observable
public final class NoteWindowModel: Identifiable {
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database
    @ObservationIgnored @Dependency(\.continuousClock) private var clock
    @ObservationIgnored @Dependency(\.date.now) private var now
    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Dependency(\.titleClient) private var titleClient
    @ObservationIgnored @Shared(.infersTitles) private var infersTitles

    public nonisolated let id: UUID
    public private(set) var noteID: Note.ID
    public private(set) var theme: NoteTheme
    public private(set) var customTitle: String
    public private(set) var displayTitle: String
    public private(set) var inferredTitle: String
    /// Bumped whenever the editor must reload the body from the model.
    public private(set) var revision = 0
    public private(set) var direction = NavigationDirection.none
    public private(set) var hasPrevious = false
    public private(set) var hasNext = false
    public var isPinned: Bool
    public private(set) var isFocusMode = false
    @DebugSnapshotIgnored public var palette: PaletteModel?
    public var isRenaming = false

    /// The editor owns the live text. SwiftUI must not re-render on each keystroke.
    @ObservationIgnored public private(set) var body: String
    @ObservationIgnored private var createdAt: Date
    /// The body the store last had. Typing is unsaved while `body` differs, until a save writes it.
    @ObservationIgnored private var savedBody: String
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// The start of the body the inferred title came from. A new title is asked only when it changes.
    @ObservationIgnored private var inferredFrom = ""
    @ObservationIgnored private var titleGeneration = 0

    @ObservationIgnored public var otherOpenNoteIDs: () -> Set<Note.ID> = { [] }
    @ObservationIgnored public var onNoteDeleted: (Note.ID) -> Void = { _ in }
    @ObservationIgnored public var onNoteChanged: () -> Void = {}

    public init(id: UUID, note: Note, isPinned: Bool = false) {
        self.id = id
        noteID = note.id
        theme = note.theme
        customTitle = note.title
        displayTitle = note.displayTitle
        inferredTitle = note.inferredTitle
        body = note.body
        savedBody = note.body
        createdAt = note.createdAt
        self.isPinned = isPinned
        inferredFrom = note.inferredTitle.isEmpty ? "" : Self.inferenceKey(note.body)
    }

    private var isDirty: Bool { body != savedBody }

    public var isEmpty: Bool {
        customTitle.isEmpty && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var paletteContext: PaletteContext {
        PaletteContext(
            noteID: noteID,
            hasPrevious: hasPrevious,
            hasNext: hasNext,
            isPinned: isPinned,
            isFocusMode: isFocusMode,
            theme: theme
        )
    }

    public func task() async {
        await refreshNeighbors()
    }

    // MARK: Editing

    public func textChanged(_ text: String) {
        body = text
        refreshDisplayTitle()
        saveTask?.cancel()
        saveTask = Task { [weak self, clock] in
            do { try await clock.sleep(for: .milliseconds(400)) } catch { return }
            await self?.save()
        }
    }

    public func save() async {
        guard isDirty else { return }
        logIfShrinking()
        let state = Log.signposter.beginInterval("Save note")
        defer { Log.signposter.endInterval("Save note", state) }
        let (id, body, now) = (noteID, body, now)
        let saved = await withErrorReporting {
            try await database.write { db in
                try Note.find(id).update {
                    $0.body = body
                    $0.updatedAt = now
                }
                .execute(db)
            }
            return true
        } ?? false
        guard saved, id == noteID else { return }
        savedBody = body
        onNoteChanged()
        await inferTitleIfNeeded(id: id, body: body)
    }

    /// Logs a save that drops most of a note, for when data goes missing.
    private func logIfShrinking() {
        let (before, after) = (savedBody.utf16.count, body.utf16.count)
        guard before > 80, after < before * 3 / 4 else { return }
        Log.database.notice("Saving \(self.noteID.rawValue, privacy: .public) shrinks it from \(before) to \(after) characters")
    }

    private static func inferenceKey(_ body: String) -> String {
        String(body.prefix(160))
    }

    private func refreshDisplayTitle() {
        let title = NoteText.displayTitle(custom: customTitle, body: body, inferred: inferredTitle)
        if title != displayTitle { displayTitle = title }
    }

    /// Asks the on-device model for a title after typing pauses, only when the first
    /// line makes a poor title and changed since the last ask.
    private func inferTitleIfNeeded(id: Note.ID, body: String) async {
        guard infersTitles, customTitle.isEmpty, NoteText.wantsInferredTitle(body) else { return }
        let sample = String(body.prefix(1200))
        let key = Self.inferenceKey(body)
        guard key != inferredFrom, sample.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 else { return }
        inferredFrom = key
        titleGeneration += 1
        let generation = titleGeneration
        let state = Log.signposter.beginInterval("Infer title")
        let suggestion = (try? await titleClient.suggest(sample)) ?? nil
        Log.signposter.endInterval("Infer title", state)
        Log.titles.debug("Inferred \(suggestion ?? "no title", privacy: .private) for \(id.rawValue, privacy: .public)")
        // A newer ask, or another note in the window, makes this answer stale.
        guard let suggestion, generation == titleGeneration, id == noteID, suggestion != inferredTitle else { return }
        inferredTitle = suggestion
        refreshDisplayTitle()
        await withErrorReporting {
            try await database.write { db in
                try Note.find(id).update { $0.inferredTitle = suggestion }.execute(db)
            }
        }
        onNoteChanged()
    }

    /// Writes unsaved text now: before a switch of notes, a close, or a quit.
    public func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty else { return }
        logIfShrinking()
        let (id, body, now) = (noteID, body, now)
        let saved = withErrorReporting {
            try database.write { db in
                try Note.find(id).update {
                    $0.body = body
                    $0.updatedAt = now
                }
                .execute(db)
            }
            return true
        } ?? false
        guard saved else { return }
        savedBody = body
        onNoteChanged()
    }

    /// Picks up a change made outside this window: Settings, the command line, another app.
    /// Unsaved typing wins over the store.
    public func reloadFromStore(fallbackTheme: NoteTheme = NoteTheme()) {
        guard let note = fetch(noteID) else {
            noteDeletedElsewhere(noteID, fallbackTheme: fallbackTheme)
            return
        }
        if note.theme != theme { theme = note.theme }
        customTitle = note.title
        inferredTitle = note.inferredTitle
        Task { await refreshNeighbors() }
        guard !isDirty, note.body != body else {
            refreshDisplayTitle()
            return
        }
        body = note.body
        savedBody = note.body
        refreshDisplayTitle()
        direction = .none
        revision += 1
    }

    // MARK: Look

    public func styleSelected(_ style: NoteStyle) {
        updateTheme { $0.style = style }
    }

    public func tintSelected(_ tint: NoteTint) {
        updateTheme { $0.tint = tint }
    }

    public func appearanceSelected(_ appearance: NoteAppearance) {
        updateTheme { $0.appearance = appearance }
    }

    private func updateTheme(_ change: (inout NoteTheme) -> Void) {
        var theme = theme
        change(&theme)
        guard theme != self.theme else { return }
        self.theme = theme
        let id = noteID
        withErrorReporting {
            try database.write { db in
                try Note.find(id).update {
                    $0.style = theme.style
                    $0.tint = theme.tint
                    $0.appearance = theme.appearance
                }
                .execute(db)
            }
        }
    }

    public func renameButtonTapped() {
        isRenaming = true
    }

    public func renameCommitted(_ title: String) {
        isRenaming = false
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let derived = NoteText.displayTitle(custom: "", body: body, inferred: inferredTitle)
        let custom = title == derived ? "" : title
        guard custom != customTitle else { return }
        customTitle = custom
        refreshDisplayTitle()
        let id = noteID
        withErrorReporting {
            try database.write { db in
                try Note.find(id).update { $0.title = custom }.execute(db)
            }
        }
        onNoteChanged()
    }

    public func renameCancelled() {
        isRenaming = false
    }

    // MARK: Window

    public func pinButtonTapped() {
        isPinned.toggle()
    }

    public func focusModeToggled() {
        isFocusMode.toggle()
    }

    public func focusModeExited() {
        isFocusMode = false
    }

    // MARK: Palette

    public func commandKeyTapped() {
        palette == nil ? presentPalette(.root) : dismissPalette()
    }

    public func browseButtonTapped() {
        if palette?.page == .notes {
            dismissPalette()
        } else {
            presentPalette(.notes)
        }
    }

    public func copyAsButtonTapped() {
        presentPalette(.copyAs)
    }

    private func presentPalette(_ page: PalettePage) {
        palette = PaletteModel(page: page, context: paletteContext)
    }

    public func dismissPalette() {
        palette = nil
    }

    // MARK: Notes

    public func newNoteButtonTapped(theme: NoteTheme) {
        let note = Note(id: Note.ID(uuid()), style: theme.style, tint: theme.tint, appearance: theme.appearance, createdAt: now, updatedAt: now)
        guard insert(note) else { return }
        show(note, direction: .forward)
    }

    public func duplicateButtonTapped() {
        flush()
        let note = Note(
            id: Note.ID(uuid()),
            title: customTitle,
            body: body,
            inferredTitle: inferredTitle,
            style: theme.style,
            tint: theme.tint,
            appearance: theme.appearance,
            createdAt: now,
            updatedAt: now
        )
        guard insert(note) else { return }
        show(note, direction: .forward)
    }

    /// Returns false when no note is left to show, so the window can close.
    @discardableResult
    public func deleteButtonTapped(fallbackTheme: NoteTheme) -> Bool {
        saveTask?.cancel()
        let deleted = noteID
        let neighbor = fetchNeighbor(.forward) ?? fetchNeighbor(.backward)
        withErrorReporting {
            try database.write { db in
                try Note.find(deleted).delete().execute(db)
            }
        }
        body = ""
        savedBody = ""
        onNoteDeleted(deleted)
        if let neighbor {
            show(neighbor, direction: .forward)
        } else {
            let note = Note(id: Note.ID(uuid()), style: fallbackTheme.style, tint: fallbackTheme.tint, appearance: fallbackTheme.appearance, createdAt: now, updatedAt: now)
            guard insert(note) else { return false }
            show(note, direction: .forward)
        }
        return true
    }

    public func noteSelected(_ id: Note.ID) {
        guard id != noteID, let note = fetch(id) else { return }
        show(note, direction: .forward)
    }

    /// Swiping and ⌥⌘← → walk the notes newest to oldest.
    public func previousNoteRequested() {
        guard let note = fetchNeighbor(.backward) else { return }
        show(note, direction: .backward)
    }

    public func nextNoteRequested() {
        guard let note = fetchNeighbor(.forward) else { return }
        show(note, direction: .forward)
    }

    /// Another window deleted the note this one shows.
    public func noteDeletedElsewhere(_ id: Note.ID, fallbackTheme: NoteTheme) {
        guard id == noteID else { return }
        saveTask?.cancel()
        body = ""
        savedBody = ""
        if let neighbor = fetchNeighbor(.forward) ?? fetchNeighbor(.backward) {
            show(neighbor, direction: .forward)
        } else {
            newNoteButtonTapped(theme: fallbackTheme)
        }
    }

    private func refreshNeighbors() async {
        let (id, createdAt, excluded) = (noteID, createdAt, otherOpenNoteIDs().union([noteID]))
        let result = await withErrorReporting {
            try await database.read { db in
                let newer = try Note.where { Self.isNewer($0, than: createdAt, id) && !$0.id.in(excluded) }.fetchCount(db)
                let older = try Note.where { Self.isOlder($0, than: createdAt, id) && !$0.id.in(excluded) }.fetchCount(db)
                return (newer > 0, older > 0)
            }
        }
        guard let (newer, older) = result, id == noteID else { return }
        hasPrevious = newer
        hasNext = older
    }

    /// Notes are ordered by when they were made, then by id, so notes made in the
    /// same instant (an import) are each still reachable.
    private nonisolated static func isNewer(_ note: Note.TableColumns, than createdAt: Date, _ id: Note.ID) -> some QueryExpression<Bool> {
        #sql("(\(note.createdAt) > \(bind: createdAt) OR (\(note.createdAt) = \(bind: createdAt) AND \(note.id) > \(bind: id)))", as: Bool.self)
    }

    private nonisolated static func isOlder(_ note: Note.TableColumns, than createdAt: Date, _ id: Note.ID) -> some QueryExpression<Bool> {
        #sql("(\(note.createdAt) < \(bind: createdAt) OR (\(note.createdAt) = \(bind: createdAt) AND \(note.id) < \(bind: id)))", as: Bool.self)
    }

    private func show(_ note: Note, direction: NavigationDirection) {
        flush()
        let leaving = noteID
        if isEmpty, leaving != note.id, !otherOpenNoteIDs().contains(leaving) {
            withErrorReporting {
                try database.write { db in try Note.find(leaving).delete().execute(db) }
            }
        }
        noteID = note.id
        theme = note.theme
        customTitle = note.title
        inferredTitle = note.inferredTitle
        displayTitle = note.displayTitle
        body = note.body
        savedBody = note.body
        createdAt = note.createdAt
        inferredFrom = note.inferredTitle.isEmpty ? "" : Self.inferenceKey(note.body)
        titleGeneration += 1
        self.direction = direction
        revision += 1
        Task { await refreshNeighbors() }
        onNoteChanged()
    }

    private func insert(_ note: Note) -> Bool {
        flush()
        return withErrorReporting {
            try database.write { db in try Note.insert { note }.execute(db) }
            return true
        } ?? false
    }

    private func fetch(_ id: Note.ID) -> Note? {
        withErrorReporting {
            try database.read { db in try Note.find(id).fetchOne(db) }
        } ?? nil
    }

    private func fetchNeighbor(_ direction: NavigationDirection) -> Note? {
        let (id, createdAt, excluded) = (noteID, createdAt, otherOpenNoteIDs().union([noteID]))
        return withErrorReporting {
            try database.read { db in
                switch direction {
                case .backward:
                    try Note.where { Self.isNewer($0, than: createdAt, id) && !$0.id.in(excluded) }
                        .order { ($0.createdAt.asc(), $0.id.asc()) }
                        .limit(1)
                        .fetchOne(db)
                case .forward, .none:
                    try Note.where { Self.isOlder($0, than: createdAt, id) && !$0.id.in(excluded) }
                        .order { ($0.createdAt.desc(), $0.id.desc()) }
                        .limit(1)
                        .fetchOne(db)
                }
            }
        } ?? nil
    }
}
