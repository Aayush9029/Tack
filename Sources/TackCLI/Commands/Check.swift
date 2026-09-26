import ArgumentParser
import TackKit

struct Check: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check off a checklist item.")
    @Argument(help: "The note.") var note: String
    @Argument(help: "The item's number, from tack tasks.") var number: Int

    func run() throws {
        print(Output.taskLine(try NoteStore().setTask(note, number, done: true)))
    }
}
