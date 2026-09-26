import ArgumentParser
import Sharing
import TackKit

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a note.",
        discussion: """
        The Markdown comes from the arguments, or from standard input when nothing is \
        given. Put -- before text that starts with a dash: tack add -- "- [ ] milk".
        """
    )
    @Argument(help: "The note's Markdown.") var text: [String] = []
    @Option(help: "A title, in place of the first line.") var title: String?
    @Option(help: "glass, clear or classic. The default is the one in Settings.") var style: NoteStyle?
    @Option(help: "none, yellow, green, pink, purple, blue or gray.") var tint: NoteTint?
    @OptionGroup var output: JSONFlag

    func run() throws {
        guard let body = text.isEmpty ? Output.standardInput() : text.joined(separator: " ") else {
            throw ValidationError("Give the note's Markdown as arguments or pipe it in.")
        }
        @SharedReader(.defaultStyle) var defaultStyle
        @SharedReader(.defaultTint) var defaultTint
        @SharedReader(.defaultAppearance) var defaultAppearance
        let theme = NoteTheme(style: style ?? defaultStyle, tint: tint ?? defaultTint, appearance: defaultAppearance)
        let note = try NoteStore().add(body: body.trimmingTrailingNewline, title: title ?? "", theme: theme)
        if output.json { return try Output.json(NoteJSON(note, includesBody: false)) }
        print(Output.row(note))
    }
}
