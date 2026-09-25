import Tagged
import Dependencies
import Foundation
import IdentifiedCollections
import IssueReporting
import Observation
import Sharing
import SQLiteData

@MainActor
@Observable
public final class AppModel {
    @ObservationIgnored @Dependency(\.defaultDatabase) private var database
    @ObservationIgnored @Dependency(\.date.now) private var now
    @ObservationIgnored @Dependency(\.uuid) private var uuid
    @ObservationIgnored @Shared(.openWindows) private var records
    @ObservationIgnored @Shared(.hasSeededWelcomeNote) private var hasSeededWelcomeNote

    public let preferences = Preferences()
    public private(set) var windows: IdentifiedArrayOf<NoteWindowModel> = []

    public init() {}

    /// The windows open at the last quit, or the newest note, or a welcome note on first run.
    public func launch() -> [NoteWindowModel] {
        seedWelcomeNoteIfNeeded()
        var restored: [NoteWindowModel] = []
        for record in records {
            guard !restored.contains(where: { $0.noteID == record.noteID }), let note = fetch(record.noteID) else { continue }
            restored.append(makeWindow(record.id, note: note, isPinned: record.isPinned))
        }
        if restored.isEmpty {
            let note = newestNote() ?? insertNote()
            if let note { restored.append(makeWindow(uuid(), note: note, isPinned: preferences.pinsNewNotes)) }
        }
        syncRecords()
        return restored
    }

    public func newWindowButtonTapped() -> NoteWindowModel? {
        guard let note = insertNote() else { return nil }
        let window = makeWindow(uuid(), note: note, isPinned: preferences.pinsNewNotes)
        syncRecords()
        return window
    }

    /// A window for a note, or nil when a window already shows it and should come forward instead.
    public func openButtonTapped(_ noteID: Note.ID) -> NoteWindowModel? {
        guard window(showing: noteID) == nil, let note = fetch(noteID) else { return nil }
        let window = makeWindow(uuid(), note: note, isPinned: preferences.pinsNewNotes)
        syncRecords()
        return window
    }

    public func window(showing noteID: Note.ID) -> NoteWindowModel? {
        windows.first { $0.noteID == noteID }
    }

    public func frame(for windowID: UUID) -> CGRect? {
        records.first { $0.id == windowID }?.frame
    }

    public func windowMoved(_ windowID: UUID, frame: CGRect) {
        $records.withLock { records in
            guard let index = records.firstIndex(where: { $0.id == windowID }) else { return }
            records[index].frame = frame
        }
    }

    public func windowClosed(_ windowID: UUID) {
        guard let window = windows.remove(id: windowID) else { return }
        window.flush()
        if window.isEmpty {
            let id = window.noteID
            withErrorReporting {
                try database.write { db in try Note.find(id).delete().execute(db) }
            }
        }
        syncRecords()
    }

    public func applicationWillTerminate() {
        windows.forEach { $0.flush() }
        syncRecords()
    }

    public func syncRecords() {
        $records.withLock { records in
            let frames = Dictionary(records.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })
            records = windows.map { window in
                WindowRecord(id: window.id, noteID: window.noteID, frame: frames[window.id] ?? nil, isPinned: window.isPinned)
            }
        }
    }

    private func makeWindow(_ id: UUID, note: Note, isPinned: Bool) -> NoteWindowModel {
        let window = NoteWindowModel(id: id, note: note, isPinned: isPinned)
        window.otherOpenNoteIDs = { [weak self, weak window] in
            guard let self else { return [] }
            return Set(windows.filter { $0 !== window }.map(\.noteID))
        }
        window.onNoteDeleted = { [weak self, weak window] deleted in
            guard let self else { return }
            for other in windows where other !== window {
                other.noteDeletedElsewhere(deleted, fallbackTheme: preferences.defaultTheme)
            }
        }
        window.onNoteChanged = { [weak self] in self?.syncRecords() }
        windows.append(window)
        return window
    }

    private func insertNote() -> Note? {
        let theme = preferences.defaultTheme
        let note = Note(id: Note.ID(uuid()), style: theme.style, tint: theme.tint, appearance: theme.appearance, createdAt: now, updatedAt: now)
        return withErrorReporting {
            try database.write { db in try Note.insert { note }.execute(db) }
            return note
        } ?? nil
    }

    private func fetch(_ id: Note.ID) -> Note? {
        withErrorReporting {
            try database.read { db in try Note.find(id).fetchOne(db) }
        } ?? nil
    }

    private func newestNote() -> Note? {
        withErrorReporting {
            try database.read { db in try Note.order { $0.updatedAt.desc() }.limit(1).fetchOne(db) }
        } ?? nil
    }

    private func seedWelcomeNoteIfNeeded() {
        guard !hasSeededWelcomeNote else { return }
        $hasSeededWelcomeNote.withLock { $0 = true }
        let theme = preferences.defaultTheme
        let note = Note(
            id: Note.ID(uuid()),
            body: WelcomeNote.body,
            style: theme.style,
            tint: theme.tint,
            appearance: theme.appearance,
            createdAt: now,
            updatedAt: now
        )
        withErrorReporting {
            try database.write { db in try Note.insert { note }.execute(db) }
        }
    }
}
