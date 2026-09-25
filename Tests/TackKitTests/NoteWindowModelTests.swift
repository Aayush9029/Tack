import DebugSnapshots
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing
@testable import TackKit

@MainActor
@Suite(
    .dependencies {
        try $0.bootstrapInMemoryDatabase()
        $0.uuid = .incrementing
        $0.date.now = Date(timeIntervalSince1970: 1_000_000)
        $0.continuousClock = ImmediateClock()
    }
)
struct NoteWindowModelTests {
    @Dependency(\.defaultDatabase) var database

    private func insert(_ id: Int, _ body: String, createdAt: TimeInterval) throws -> Note {
        let note = Note(id: Note.ID(UUID(id + 100)), body: body, createdAt: Date(timeIntervalSince1970: createdAt))
        try database.write { db in try Note.insert { note }.execute(db) }
        return note
    }

    @Test func typingSavesAndRenamesFromTheFirstLine() async throws {
        let note = try insert(1, "", createdAt: 1)
        let model = NoteWindowModel(id: UUID(), note: note)
        model.textChanged("# Plan\n- [ ] call")
        #expect(model.displayTitle == "Plan")
        await model.save()
        let stored = try await database.read { db in try Note.find(note.id).fetchOne(db) }
        #expect(stored?.body == "# Plan\n- [ ] call")
    }

    @Test func swipeOrderAndHistory() async throws {
        let old = try insert(1, "old", createdAt: 1)
        let middle = try insert(2, "middle", createdAt: 2)
        _ = try insert(3, "new", createdAt: 3)
        let model = NoteWindowModel(id: UUID(), note: middle)
        await model.task()
        #expect(model.hasPrevious)
        #expect(model.hasNext)

        model.nextNoteRequested()
        #expect(model.noteID == old.id)
        #expect(model.direction == .forward)
        model.backButtonTapped()
        #expect(model.noteID == middle.id)
        #expect(model.canGoForward)
        model.previousNoteRequested()
        #expect(model.displayTitle == "new")
        #expect(!model.canGoForward)
    }

    @Test func leavingAnEmptyNoteDeletesIt() async throws {
        let kept = try insert(1, "kept", createdAt: 1)
        let model = NoteWindowModel(id: UUID(), note: kept)
        model.newNoteButtonTapped(theme: NoteTheme(style: .classic, tint: .pink))
        let empty = model.noteID
        #expect(model.theme.style == .classic)
        model.backButtonTapped()
        #expect(model.noteID == kept.id)
        let count = try await database.read { db in try Note.where { $0.id.eq(empty) }.fetchCount(db) }
        #expect(count == 0)
    }

    @Test func deleteShowsANeighbor() async throws {
        let first = try insert(1, "first", createdAt: 1)
        let second = try insert(2, "second", createdAt: 2)
        let model = NoteWindowModel(id: UUID(), note: second)
        #expect(model.deleteButtonTapped(fallbackTheme: NoteTheme()))
        #expect(model.noteID == first.id)
        let remaining = try await database.read { db in try Note.fetchCount(db) }
        #expect(remaining == 1)
    }

    @Test(.dependencies { $0.titleClient.suggest = { _ in "Rate Limit Fixes" } })
    func longFirstLineGetsAnInferredTitle() async throws {
        let note = try insert(1, "", createdAt: 1)
        let model = NoteWindowModel(id: UUID(), note: note)
        model.textChanged("fix 1, 3 (do 200) and also increase rate limits for that specific endpoint by a lot")
        await model.save()
        #expect(model.displayTitle == "Rate Limit Fixes")
        let stored = try await database.read { db in try Note.find(note.id).fetchOne(db) }
        #expect(stored?.inferredTitle == "Rate Limit Fixes")
        model.textChanged("# Heading wins\nfix 1, 3 (do 200) and also increase rate limits")
        #expect(model.displayTitle == "Heading wins")
    }

    @Test func renameOverridesTheDerivedTitle() async throws {
        let note = try insert(1, "derived", createdAt: 1)
        let model = NoteWindowModel(id: UUID(), note: note)
        model.renameCommitted("Custom")
        #expect(model.displayTitle == "Custom")
        model.textChanged("changed body")
        #expect(model.displayTitle == "Custom")
        model.renameCommitted("")
        #expect(model.displayTitle == "changed body")
    }

    @Test func pinAndFocusChangeNothingElse() throws {
        let note = try insert(1, "x", createdAt: 1)
        let model = NoteWindowModel(id: UUID(0), note: note)
        expect(model) {
            model.pinButtonTapped()
            model.focusModeToggled()
        } changes: {
            $0.isPinned = true
            $0.isFocusMode = true
        }
    }

    @Test func themeChangesPersist() async throws {
        let note = try insert(1, "x", createdAt: 1)
        let model = NoteWindowModel(id: UUID(), note: note)
        model.styleSelected(.clear)
        model.tintSelected(.blue)
        model.appearanceSelected(.dark)
        let stored = try await database.read { db in try Note.find(note.id).fetchOne(db) }
        #expect(stored?.theme == NoteTheme(style: .clear, tint: .blue, appearance: .dark))
    }
}
