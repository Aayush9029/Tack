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
    public private(set) var backStack: [Note.ID] = []
    public private(set) var forwardStack: [Note.ID] = []
    public private(set) var hasPrevious = false
    public private(set) var hasNext = false
    public var isPinned: Bool
    public private(set) var isFocusMode = false
    @DebugSnapshotIgnored public var palette: PaletteModel?
    public var isRenaming = false

    /// Kept out of observation: the editor owns the live text, and nothing in SwiftUI
    /// should re-render per keystroke.
    @ObservationIgnored public private(set) var body: String
    @ObservationIgnored private var createdAt: Date
    @ObservationIgnored private var isDirty = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// The start of the body the inferred title was made from, so it is only redone when that changes.
    @ObservationIgnored private var inferredFrom = ""

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
        createdAt = note.createdAt
        self.isPinned = isPinned
    }

    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }

    public var isEmpty: Bool {
        customTitle.isEmpty && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var paletteContext: PaletteContext {
        PaletteContext(
            noteID: noteID,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
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
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self, clock] in
            do { try await clock.sleep(for: .milliseconds(400)) } catch { return }
            await self?.save()
        }
    }

    public func save() async {
        guard isDirty else { return }
        isDirty = false
        let (id, body, now) = (noteID, body, now)
        await withErrorReporting {
            try await database.write { db in
                try Note.find(id).update {
                    $0.body = body
                    $0.updatedAt = now
                }
                .execute(db)
            }
        }
        onNoteChanged()
        await inferTitleIfNeeded()
    }

    private func refreshDisplayTitle() {
        let title = NoteText.displayTitle(custom: customTitle, body: body, inferred: inferredTitle)
        if title != displayTitle { displayTitle = title }
    }

    /// Asks the on-device model for a title once typing has paused, and only when
    /// the first line would make a poor one and has changed since the last ask.
    public func inferTitleIfNeeded() async {
        guard infersTitles, customTitle.isEmpty, NoteText.wantsInferredTitle(body) else { return }
        let sample = String(body.prefix(1200))
        let key = String(sample.prefix(160))
        guard key != inferredFrom, sample.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 else { return }
        inferredFrom = key
        let id = noteID
        let suggestion = await withErrorReporting { try await titleClient.suggest(sample) } ?? nil
        guard let suggestion, id == noteID, suggestion != inferredTitle else { return }
        inferredTitle = suggestion
        refreshDisplayTitle()
        await withErrorReporting {
            try await database.write { db in
                try Note.find(id).update { $0.inferredTitle = suggestion }.execute(db)
            }
        }
        onNoteChanged()
    }

    /// Writes pending text now: before switching notes, closing, or quitting.
    public func flush() {
        saveTask?.cancel()
        saveTask = nil
        guard isDirty else { return }
        isDirty = false
        let (id, body, now) = (noteID, body, now)
        withErrorReporting {
            try database.write { db in
                try Note.find(id).update {
                    $0.body = body
                    $0.updatedAt = now
                }
                .execute(db)
            }
        }
        onNoteChanged()
    }

    /// Picks up a change made outside this window: Settings, the command line, another app.
    /// Unsaved typing wins over the store.
    public func reloadFromStore(fallbackTheme: NoteTheme = NoteTheme()) {
        guard let note = fetch(noteID) else {
            noteDeletedElsewhere(noteID, fallbackTheme: fallbackTheme)
            return
        }
        theme = note.theme
        customTitle = note.title
        inferredTitle = note.inferredTitle
        guard !isDirty, note.body != body else {
            refreshDisplayTitle()
            Task { await refreshNeighbors() }
            return
        }
        body = note.body
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
        show(note, direction: .forward, recordsHistory: true)
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
        show(note, direction: .forward, recordsHistory: true)
    }

    /// Returns false when no note is left to show, so the window can close.
    @discardableResult
    public func deleteButtonTapped(fallbackTheme: NoteTheme) -> Bool {
        saveTask?.cancel()
        isDirty = false
        let deleted = noteID
        let neighbor = fetchNeighbor(.forward) ?? fetchNeighbor(.backward)
        withErrorReporting {
            try database.write { db in
                try Note.find(deleted).delete().execute(db)
            }
        }
        backStack.removeAll { $0 == deleted }
        forwardStack.removeAll { $0 == deleted }
        onNoteDeleted(deleted)
        if let neighbor {
            show(neighbor, direction: .forward, recordsHistory: false)
        } else {
            let note = Note(id: Note.ID(uuid()), style: fallbackTheme.style, tint: fallbackTheme.tint, appearance: fallbackTheme.appearance, createdAt: now, updatedAt: now)
            guard insert(note) else { return false }
            show(note, direction: .forward, recordsHistory: false)
        }
        return true
    }

    public func noteSelected(_ id: Note.ID) {
        guard id != noteID, let note = fetch(id) else { return }
        show(note, direction: .forward, recordsHistory: true)
    }

    public func backButtonTapped() {
        while let id = backStack.popLast() {
            guard let note = fetch(id) else { continue }
            forwardStack.append(noteID)
            show(note, direction: .backward, recordsHistory: false)
            return
        }
    }

    public func forwardButtonTapped() {
        while let id = forwardStack.popLast() {
            guard let note = fetch(id) else { continue }
            backStack.append(noteID)
            show(note, direction: .forward, recordsHistory: false)
            return
        }
    }

    /// Swiping and ⌥⌘← → walk the notes newest to oldest.
    public func previousNoteRequested() {
        guard let note = fetchNeighbor(.backward) else { return }
        show(note, direction: .backward, recordsHistory: true)
    }

    public func nextNoteRequested() {
        guard let note = fetchNeighbor(.forward) else { return }
        show(note, direction: .forward, recordsHistory: true)
    }

    /// Another window deleted the note this one shows.
    public func noteDeletedElsewhere(_ id: Note.ID, fallbackTheme: NoteTheme) {
        backStack.removeAll { $0 == id }
        forwardStack.removeAll { $0 == id }
        guard id == noteID else { return }
        isDirty = false
        saveTask?.cancel()
        if let neighbor = fetchNeighbor(.forward) ?? fetchNeighbor(.backward) {
            show(neighbor, direction: .forward, recordsHistory: false)
        } else {
            newNoteButtonTapped(theme: fallbackTheme)
        }
    }

    public func refreshNeighbors() async {
        let (createdAt, excluded) = (createdAt, otherOpenNoteIDs().union([noteID]))
        let result = await withErrorReporting {
            try await database.read { db in
                let newer = try Note.where { $0.createdAt > createdAt && !$0.id.in(excluded) }.fetchCount(db)
                let older = try Note.where { $0.createdAt < createdAt && !$0.id.in(excluded) }.fetchCount(db)
                return (newer > 0, older > 0)
            }
        }
        guard let (newer, older) = result else { return }
        hasPrevious = newer
        hasNext = older
    }

    private func show(_ note: Note, direction: NavigationDirection, recordsHistory: Bool) {
        flush()
        let leaving = noteID
        let discardsLeaving = isEmpty && leaving != note.id
        if recordsHistory, !discardsLeaving, leaving != note.id {
            backStack.append(leaving)
            forwardStack.removeAll()
        }
        if discardsLeaving {
            withErrorReporting {
                try database.write { db in try Note.find(leaving).delete().execute(db) }
            }
            backStack.removeAll { $0 == leaving }
            forwardStack.removeAll { $0 == leaving }
        }
        noteID = note.id
        theme = note.theme
        customTitle = note.title
        inferredTitle = note.inferredTitle
        displayTitle = note.displayTitle
        body = note.body
        createdAt = note.createdAt
        inferredFrom = ""
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
        let (createdAt, excluded) = (createdAt, otherOpenNoteIDs().union([noteID]))
        return withErrorReporting {
            try database.read { db in
                switch direction {
                case .backward:
                    try Note.where { $0.createdAt > createdAt && !$0.id.in(excluded) }
                        .order { $0.createdAt.asc() }
                        .limit(1)
                        .fetchOne(db)
                case .forward, .none:
                    try Note.where { $0.createdAt < createdAt && !$0.id.in(excluded) }
                        .order { $0.createdAt.desc() }
                        .limit(1)
                        .fetchOne(db)
                }
            }
        } ?? nil
    }
}

public enum NavigationDirection: Equatable, Sendable {
    case none
    case forward
    case backward
}
