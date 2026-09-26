import ArgumentParser
import Foundation
import TackKit

struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Delete a note. This cannot be undone.")
    @Argument(help: "The note.") var note: String
    @Flag(help: "Delete without asking; required when not run in a terminal.") var force = false

    func run() throws {
        let store = NoteStore()
        let note = try store.resolve(note)
        if !force {
            guard isatty(FileHandle.standardInput.fileDescriptor) != 0 else {
                throw ValidationError("Pass --force to delete without a terminal.")
            }
            print("Delete “\(note.displayTitle)”? [y/N] ", terminator: "")
            guard readLine()?.lowercased().hasPrefix("y") == true else {
                print("Kept it.")
                return
            }
        }
        try store.delete(note)
        print("Deleted \(Output.row(note))")
    }
}
