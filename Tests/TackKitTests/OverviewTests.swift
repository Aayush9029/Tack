import Dependencies
import DependenciesTestSupport
import Foundation
import Testing
@testable import TackKit

@MainActor
@Suite(.dependencies {
    try $0.bootstrapInMemoryDatabase()
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    $0.continuousClock = ImmediateClock()
})
struct OverviewTests {
    @Test func previewReadsMarkdown() {
        let lines = PreviewLine.lines(from: "# Trip\n\n- [x] passport\n- tickets\n> pack light\n![](a.png)\nKeep it *small*.")
        #expect(lines == [
            .heading("Trip"),
            .task("passport", isDone: true),
            .bullet("tickets"),
            .quote("pack light"),
            .text("Keep it small."),
        ])
    }

    @Test func cardsDoNotRepeatTheTitle() {
        let card = NoteCard(Note(id: Note.ID(UUID(0)), body: "# Trip\n- [ ] passport"))
        #expect(card.title == "Trip")
        #expect(card.lines == [.task("passport", isDone: false)])
        #expect(card.totalTasks == 1)
    }

    @Test func waterfallFillsTheShortestColumn() {
        let tall = NoteCard(Note(id: Note.ID(UUID(1)), body: (1...8).map { "line \($0)" }.joined(separator: "\n")))
        let short = (2...4).map { NoteCard(Note(id: Note.ID(UUID($0)), body: "note \($0)")) }
        let columns = WaterfallLayout.columns([tall] + short, count: 2)
        #expect(columns[0].map(\.id) == [tall.id])
        #expect(columns[1].map(\.id) == short.map(\.id))
    }

    @Test func searchNarrowsTheCards() async throws {
        let store = NoteStore()
        try store.add(body: "Groceries\n- [ ] oat milk", theme: NoteTheme())
        try store.add(body: "Trip plan", theme: NoteTheme())
        let model = OverviewModel()
        await model.load()
        #expect(model.cards.count == 2)
        model.queryChanged("oat")
        await model.load()
        #expect(model.cards.map(\.title) == ["Groceries"])
        model.queryChanged("!!")
        await model.load()
        #expect(model.cards.isEmpty)
        model.escapeKeyPressed()
        #expect(model.query.isEmpty)
    }

    @Test func deleteWaitsForConfirmation() async throws {
        let store = NoteStore()
        try store.add(body: "Keep", theme: NoteTheme())
        let model = OverviewModel()
        var deleted: [Note.ID] = []
        model.onDelete = { deleted.append($0) }
        await model.load()
        let card = try #require(model.cards.first)
        model.deleteMenuItemTapped(card)
        model.deletionCancelled()
        #expect(deleted.isEmpty)
        model.deleteMenuItemTapped(card)
        model.deletionConfirmed()
        #expect(deleted == [card.id])
        #expect(model.cards.isEmpty)
    }
}
