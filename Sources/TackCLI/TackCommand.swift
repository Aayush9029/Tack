import ArgumentParser
import Dependencies
import Foundation
import TackKit

@main
struct TackCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tack",
        abstract: "Read and write Tack notes from the command line.",
        discussion: """
        Notes live in a SQLite database in ~/Library/Application Support/Tack. Every note \
        is Markdown. A <note> is a full id, the first characters of one, or a title. Open \
        notes in Tack update as soon as a command changes them. Add --json for output \
        a program can read.
        """,
        subcommands: [
            List.self, Search.self, Show.self, Add.self, Edit.self, Tasks.self,
            Check.self, Uncheck.self, Delete.self, Export.self, Import.self, ImportRaycast.self, Where.self,
        ]
    )

    static func main() {
        do {
            try prepareDependencies {
                try $0.bootstrapDatabase()
                // The app's defaults, so new notes get the look chosen in Settings.
                $0.defaultAppStorage = UserDefaults(suiteName: "ca.optimalapps.tack") ?? .standard
            }
        } catch {
            FileHandle.standardError.write(Data("tack: cannot open the notes database: \(error)\n".utf8))
            Foundation.exit(1)
        }
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let failure as RaycastExport.Failure {
            FileHandle.standardError.write(Data("tack: \(failure)\n".utf8))
            Foundation.exit(1)
        } catch let failure as NoteStore.Failure {
            FileHandle.standardError.write(Data("tack: \(failure)\n".utf8))
            Foundation.exit(1)
        } catch {
            exit(withError: error)
        }
    }
}
