import ArgumentParser
import TackKit

struct Edit: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Change a note.",
        discussion: "With no --body, --append or --prepend, piped standard input replaces the Markdown."
    )
    @Argument(help: "The note.") var note: String
    @Option(parsing: .unconditional, help: "Replace the Markdown.") var body: String?
    @Option(parsing: .unconditional, help: "Add a line at the end.") var append: String?
    @Option(parsing: .unconditional, help: "Add a line at the start.") var prepend: String?
    @Option(help: "Set the title. An empty title names the note from its first line.") var title: String?
    @Option var style: NoteStyle?
    @Option var tint: NoteTint?
    @Option var appearance: NoteAppearance?
    @OptionGroup var output: JSONFlag

    func run() throws {
        let store = NoteStore()
        let note = try store.resolve(note)
        // Piped text replaces the body only when nothing else was asked for, so a
        // script that changes the tint cannot blank a note by accident.
        let asksForSomethingElse = append != nil || prepend != nil || title != nil || style != nil || tint != nil || appearance != nil
        let piped = body == nil && !asksForSomethingElse ? Output.standardInput()?.trimmingTrailingNewline : nil
        let updated = try store.modify(note.id) { current in
            if let replacement = body ?? piped { current.body = replacement }
            if let append { current.body = current.body.isEmpty ? append : current.body + "\n" + append }
            if let prepend { current.body = current.body.isEmpty ? prepend : prepend + "\n" + current.body }
            if let title { current.title = title }
            if let style { current.style = style }
            if let tint { current.tint = tint }
            if let appearance { current.appearance = appearance }
        }
        if output.json { return try Output.json(NoteJSON(updated, includesBody: true)) }
        print(Output.row(updated))
    }
}
