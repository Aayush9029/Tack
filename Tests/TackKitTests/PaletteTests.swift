import CasePaths
import Dependencies
import DependenciesTestSupport
import Foundation
import Testing
@testable import TackKit

@MainActor
@Suite(.dependencies { try $0.bootstrapInMemoryDatabase() })
struct PaletteTests {
    private let context = PaletteContext(noteID: Note.ID(UUID(0)))

    @Test func disabledItemsAreSkipped() {
        let palette = PaletteModel(context: context)
        #expect(palette.highlighted == "item:newNote")
        palette.moveHighlight(-1)
        #expect(palette.highlighted == "item:settings")
        palette.queryChanged("go")
        #expect(palette.rows.map(\.id).prefix(2) == ["item:goBack", "item:goForward"])
        #expect(palette.highlighted != "item:goBack")
    }

    @Test func prefixMatchesRankFirst() {
        let palette = PaletteModel(context: context)
        palette.queryChanged("dup")
        #expect(palette.rows.first?.id == "item:duplicate")
    }

    @Test func subpageAndBack() {
        var committed: [NoteCommand] = []
        let palette = PaletteModel(context: context)
        palette.onCommit = { committed.append($0) }
        palette.queryChanged("copy note")
        palette.returnKeyPressed()
        #expect(palette.page == .copyAs)
        palette.queryChanged("plain")
        palette.returnKeyPressed()
        #expect(committed == [.copyAs(.plainText)])
        palette.escapeKeyPressed()
        palette.escapeKeyPressed()
        #expect(palette.page == .root)
    }

    @Test(.dependencies { $0.continuousClock = ImmediateClock() })
    func searchFindsNotes() async throws {
        @Dependency(\.defaultDatabase) var database
        try await database.write { db in
            try Note.insert {
                Note(id: Note.ID(UUID(1)), body: "Groceries\n- [ ] oat milk\n- [x] bread")
                Note(id: Note.ID(UUID(2)), body: "Trip plan")
            }
            .execute(db)
        }
        let palette = PaletteModel(page: .notes, context: context)
        palette.queryChanged("oat")
        await palette.searchNotes()
        let hits = palette.rows.compactMap { $0[case: \.note] }
        #expect(hits.map(\.displayTitle) == ["Groceries"])
        #expect(hits.first?.doneTasks == 1)
        #expect(hits.first?.openTasks == 1)
    }
}
