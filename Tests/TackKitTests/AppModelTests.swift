import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing
@testable import TackKit

@MainActor
@Suite(.dependencies {
    try $0.bootstrapInMemoryDatabase()
    $0.uuid = .incrementing
    $0.date.now = Date(timeIntervalSince1970: 1_000_000)
    $0.defaultFileStorage = .inMemory
    $0.defaultAppStorage = UserDefaults(suiteName: "tack-tests-\(UUID().uuidString)")!
})
struct AppModelTests {
    @Dependency(\.defaultDatabase) var database

    @Test func closingOneOfTwoWindowsOnAnEmptyNoteKeepsIt() throws {
        let app = AppModel()
        let first = try #require(app.newWindowButtonTapped())
        let second = try #require(app.newWindowButtonTapped())
        second.noteSelected(first.noteID)
        app.windowClosed(first.id)
        let count = try database.read { db in try Note.where { $0.id.eq(first.noteID) }.fetchCount(db) }
        #expect(count == 1)
    }

    @Test func settingsLookReachesOpenWindows() throws {
        let app = AppModel()
        let window = try #require(app.newWindowButtonTapped())
        app.lookChanged(style: .classic, tint: .green)
        #expect(window.theme.style == .classic)
        #expect(window.theme.tint == .green)
        let styles = try database.read { db in try Note.select(\.style).fetchAll(db) }
        #expect(styles.allSatisfy { $0 == .classic })
    }
}
