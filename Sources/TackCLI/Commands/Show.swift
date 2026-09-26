import ArgumentParser
import TackKit

struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print a note's Markdown.")
    @Argument(help: "The note.") var note: String
    @OptionGroup var output: JSONFlag

    func run() throws {
        let note = try NoteStore().resolve(note)
        if output.json { return try Output.json(NoteJSON(note, includesBody: true)) }
        print(note.body)
    }
}
