import Foundation
import SQLiteData

public enum NoteSearch {
    public static func ftsQuery(_ text: String) -> String? {
        let tokens = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    /// Ranking happens inside the match CTE and only over the top `matchLimit`, so a
    /// common word costs the same as a rare one.
    public static func hits(
        matching text: String,
        limit: Int = 40,
        matchLimit: Int = 300
    ) -> some StructuredQueriesCore.Statement<NoteHit> {
        let query = ftsQuery(text) ?? ""
        // MATERIALIZED keeps SQLite from flattening the match into the join, where
        // `snippet()` is not allowed.
        return #sql(
            """
            WITH "matches" AS MATERIALIZED (
              SELECT
                "noteID" AS "nid",
                snippet("noteSearch", 2, '', '', '…', 10) AS "snippet",
                rank AS "score"
              FROM "noteSearch"
              WHERE "noteSearch" MATCH \(bind: query)
              ORDER BY rank
              LIMIT \(bind: matchLimit)
            )
            SELECT
              n."id", n."title", n."inferredTitle", substr(n."body", 1, 300), m."snippet", n."tint",
              \(raw: taskCount("[x]")) + \(raw: taskCount("[X]")),
              \(raw: taskCount("[ ]")),
              n."updatedAt"
            FROM "matches" m
            JOIN "notes" n ON n."id" = m."nid"
            ORDER BY m."score"
            LIMIT \(bind: limit)
            """,
            as: NoteHit.self
        )
    }

    public static func recent(limit: Int = 40) -> some StructuredQueriesCore.Statement<NoteHit> {
        #sql(
            """
            SELECT
              n."id", n."title", n."inferredTitle", substr(n."body", 1, 300), '', n."tint",
              \(raw: taskCount("[x]")) + \(raw: taskCount("[X]")),
              \(raw: taskCount("[ ]")),
              n."updatedAt"
            FROM "notes" n
            ORDER BY n."updatedAt" DESC
            LIMIT \(bind: limit)
            """,
            as: NoteHit.self
        )
    }

    /// Occurrences of `- <box>` in the body, counted without leaving SQLite.
    private static func taskCount(_ box: String) -> String {
        let marker = "- \(box)"
        return #"((length(n."body") - length(replace(n."body", '\#(marker)', ''))) / \#(marker.count))"#
    }
}
