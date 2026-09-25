import Dependencies
import DependenciesTestSupport
import Foundation
import Testing
@testable import TackKit

@Suite(.dependencies {
    try $0.bootstrapInMemoryDatabase()
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 1_000_000)
})
struct NoteStoreTests {
    @Test(.dependency(\.uuid, UUIDGenerator { UUID() }))
    func resolvesByIDPrefixAndTitle() throws {
        let store = NoteStore()
        let trip = try store.add(body: "# Trip\n- [ ] passport", theme: NoteTheme())
        try store.add(body: "Trip notes old", theme: NoteTheme())
        #expect(try store.resolve("trip").id == trip.id)
        #expect(try store.resolve(String(trip.id.rawValue.uuidString.prefix(8))).id == trip.id)
        #expect(throws: NoteStore.Failure.notFound("nothing")) { try store.resolve("nothing") }
        #expect(throws: NoteStore.Failure.self) { try store.resolve("tri") }
    }

    @Test func numberedTasksSkipCode() throws {
        let body = "- [ ] one\n```\n- [ ] not a task\n```\n- [x] two"
        #expect(NoteStore.tasks(in: body).map(\.text) == ["one", "two"])
        #expect(try NoteStore.setting(task: 2, done: false, in: body).hasSuffix("- [ ] two"))
        #expect(throws: NoteStore.Failure.noTask(3, count: 2)) { try NoteStore.setting(task: 3, done: true, in: body) }
    }

    @Test func editKeepsTheID() throws {
        let store = NoteStore()
        let note = try store.add(body: "a", theme: NoteTheme())
        let updated = try store.update(note, body: "b", theme: NoteTheme(style: .classic))
        #expect(try store.resolve(note.id.rawValue.uuidString).body == "b")
        #expect(updated.style == .classic)
    }

    @Test func fileNamesAreSafe() {
        let note = Note(id: Note.ID(UUID(0)), body: "a/b: c?")
        #expect(NoteStore.fileName(for: note) == "a-b- c- (00000000).md")
    }
}
