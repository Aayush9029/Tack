import Dependencies
import Foundation
import SQLiteData

public extension DependencyValues {
    mutating func bootstrapDatabase() throws {
        let directory = URL.applicationSupportDirectory.appending(path: "Tack", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // An explicit path: the library default is a Mac-wide SQLiteData.db that any
        // other SQLiteData app shares and that DEBUG's erase-on-schema-change wipes.
        let database = try SQLiteData.defaultDatabase(
            path: directory.appending(path: "notes.db").path(percentEncoded: false)
        )
        try Self.migrate(database)
        defaultDatabase = database
    }

    mutating func bootstrapInMemoryDatabase() throws {
        let database = try DatabaseQueue()
        try Self.migrate(database)
        defaultDatabase = database
    }

    private static func migrate(_ database: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("Create notes") { db in
            try #sql(
                """
                CREATE TABLE "notes" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "title" TEXT NOT NULL DEFAULT '',
                  "body" TEXT NOT NULL DEFAULT '',
                  "style" TEXT NOT NULL DEFAULT 'glass',
                  "tint" TEXT NOT NULL DEFAULT 'none',
                  "appearance" TEXT NOT NULL DEFAULT 'system',
                  "createdAt" TEXT NOT NULL,
                  "updatedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)

            try #sql(#"CREATE INDEX "notes_createdAt" ON "notes"("createdAt")"#).execute(db)
            try #sql(#"CREATE INDEX "notes_updatedAt" ON "notes"("updatedAt")"#).execute(db)
        }

        // Not porter: it indexes stems, so a prefix query ("notariz") misses its stem ("notar").
        migrator.registerMigration("Full-text search over notes") { db in
            try #sql(
                """
                CREATE VIRTUAL TABLE "noteSearch" USING fts5(
                  "noteID" UNINDEXED,
                  "title",
                  "body",
                  tokenize = 'unicode61 remove_diacritics 2'
                )
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TRIGGER "noteSearch_insert" AFTER INSERT ON "notes" BEGIN
                  INSERT INTO "noteSearch" ("noteID", "title", "body")
                  VALUES (new."id", new."title", new."body");
                END
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TRIGGER "noteSearch_delete" AFTER DELETE ON "notes" BEGIN
                  DELETE FROM "noteSearch" WHERE "noteID" = old."id";
                END
                """
            )
            .execute(db)

            try #sql(
                """
                CREATE TRIGGER "noteSearch_update" AFTER UPDATE OF "title", "body" ON "notes" BEGIN
                  DELETE FROM "noteSearch" WHERE "noteID" = old."id";
                  INSERT INTO "noteSearch" ("noteID", "title", "body")
                  VALUES (new."id", new."title", new."body");
                END
                """
            )
            .execute(db)
        }

        migrator.registerMigration("Inferred titles") { db in
            try #sql(
                """
                ALTER TABLE "notes" ADD COLUMN "inferredTitle" TEXT NOT NULL DEFAULT ''
                """
            )
            .execute(db)
        }

        try migrator.migrate(database)
    }
}
