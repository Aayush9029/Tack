import ArgumentParser
import TackKit

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List notes, most recently changed first.")
    @Option(help: "How many notes to list.") var limit = 50
    @OptionGroup var output: JSONFlag

    func run() throws {
        let notes = try NoteStore().all(limit: limit)
        if output.json { return try Output.json(notes.map { NoteJSON($0, includesBody: false) }) }
        notes.forEach { print(Output.row($0)) }
    }
}
