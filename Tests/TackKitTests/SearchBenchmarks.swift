import Dependencies
import DependenciesTestSupport
import Foundation
import Testing
@testable import TackKit

/// Gated: `TACK_BENCH=1 swift test --filter Benchmarks`.
@Suite(
    .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["TACK_BENCH"] != nil),
    .dependencies { try $0.bootstrapInMemoryDatabase() }
)
struct SearchBenchmarks {
    @Test func searchingFiveThousandNotes() async throws {
        @Dependency(\.defaultDatabase) var database
        let words = ["plan", "milk", "launch", "notarize", "review", "trip", "budget", "design", "glass", "swift", "tack", "focus"]
        try await database.write { db in
            for index in 0..<5000 {
                let body = (0..<40).map { words[($0 * 7 + index) % words.count] }.joined(separator: " ")
                try Note.insert { Note(id: Note.ID(UUID()), body: "Note \(index)\n- [ ] \(body)") }.execute(db)
            }
        }
        let clock = ContinuousClock()
        for query in ["plan", "notar", "glass swift", "zzz"] {
            let elapsed = try await clock.measure {
                _ = try await database.read { db in try NoteSearch.hits(matching: query, limit: 40).fetchAll(db) }
            }
            print("BENCH search \(query): \(elapsed)")
        }
        let recent = try await clock.measure {
            _ = try await database.read { db in try NoteSearch.recent(limit: 40).fetchAll(db) }
        }
        print("BENCH recent 40 of 5000: \(recent)")
        let id = try await database.read { db in try Note.limit(1).fetchOne(db)!.id }
        let saves = try await clock.measure {
            for index in 0..<100 {
                try await database.write { db in try Note.find(id).update { $0.body = "edited \(index) plan milk" }.execute(db) }
            }
        }
        print("BENCH save among 5000: \(saves / 100)")
    }
}
