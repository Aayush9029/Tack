import Foundation
import Testing
@testable import TackKit

@Suite struct RaycastExportTests {
    private var fixture: Data {
        get throws {
            let url = try #require(Bundle.module.url(forResource: "two-notes", withExtension: "rayconfig", subdirectory: "Fixtures"))
            return try Data(contentsOf: url)
        }
    }

    @Test func scryptMatchesRFC7914() {
        let key = Scrypt.derive(password: Data("password".utf8), salt: Data("NaCl".utf8), n: 1024, r: 8, p: 16, length: 64)
        #expect(key.prefix(16).map { String(format: "%02x", $0) }.joined() == "fdbabe1c9d3472007856e7190d01e9fe")
        let empty = Scrypt.derive(password: Data(), salt: Data(), n: 16, r: 1, p: 1, length: 64)
        #expect(empty.prefix(8).map { String(format: "%02x", $0) }.joined() == "77d6576238657b20")
    }

    @Test func readsNotesFromAnExport() throws {
        let notes = try RaycastExport.notes(in: fixture, password: "test")
        #expect(notes.map(\.title) == ["Groceries", "Trip"])
        #expect(notes[0].text == "Groceries\n- [ ] oat milk\n- [x] bread")
        #expect(notes[1].createdAt == Date(timeIntervalSince1970: 1_740_816_000))
    }

    @Test func wrongPasswordAndWrongFiles() throws {
        #expect(throws: RaycastExport.Failure.wrongPassword) { try RaycastExport.notes(in: fixture, password: "nope") }
        #expect(throws: RaycastExport.Failure.notARaycastExport) { try RaycastExport.notes(in: Data("hello".utf8), password: "test") }
    }
}

import Dependencies
import DependenciesTestSupport

@Suite(.dependencies {
    try $0.bootstrapInMemoryDatabase()
    $0.uuid = .incrementing
})
struct RaycastImportTests {
    @Test func importsOnceAndKeepsDates() throws {
        let notes = [
            RaycastExport.Note(title: "Groceries", text: "Groceries\n- [ ] milk", createdAt: Date(timeIntervalSince1970: 10), updatedAt: Date(timeIntervalSince1970: 20)),
            RaycastExport.Note(title: "Named", text: "first line differs", createdAt: Date(timeIntervalSince1970: 30), updatedAt: Date(timeIntervalSince1970: 40)),
        ]
        let importer = RaycastImport()
        #expect(try importer.run(notes, theme: NoteTheme()) == .init(imported: 2, skipped: 0))
        #expect(try importer.run(notes, theme: NoteTheme()) == .init(imported: 0, skipped: 2))
        let stored = try NoteStore().all()
        #expect(Set(stored.map(\.displayTitle)) == ["Groceries", "Named"])
        #expect(stored.first { $0.displayTitle == "Groceries" }?.createdAt == Date(timeIntervalSince1970: 10))
    }
}
