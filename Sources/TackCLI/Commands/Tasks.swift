import ArgumentParser
import TackKit

struct Tasks: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List a note's checklist items, numbered for check and uncheck.")
    @Argument(help: "The note.") var note: String
    @OptionGroup var output: JSONFlag

    func run() throws {
        let tasks = NoteStore.tasks(in: try NoteStore().resolve(note).body)
        if output.json { return try Output.json(tasks) }
        tasks.forEach { print(Output.taskLine($0)) }
    }
}
