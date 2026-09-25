import ArgumentParser
import Foundation
import Dependencies
import Sharing
import TackKit

struct JSONFlag: ParsableArguments {
    @Flag(name: .long, help: "Print JSON.") var json = false
}

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

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Find notes by the words in them.")
    @Argument(help: "Words to find. Each matches as a prefix.") var words: [String]
    @Option(help: "How many notes to return.") var limit = 20
    @OptionGroup var output: JSONFlag

    func run() throws {
        let store = NoteStore()
        let hits = try store.search(words.joined(separator: " "), limit: limit)
        let notes = try hits.map { try store.resolve($0.id.rawValue.uuidString) }
        if output.json { return try Output.json(notes.map { NoteJSON($0, includesBody: false) }) }
        for (note, hit) in zip(notes, hits) {
            print(Output.row(note))
            let snippet = hit.snippet.split(whereSeparator: \.isNewline).joined(separator: " ")
            if !snippet.isEmpty { print("          \(snippet)") }
        }
    }
}

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
        let body = text.isEmpty ? (Output.standardInput() ?? "") : text.joined(separator: " ")
        @SharedReader(.defaultStyle) var defaultStyle
        @SharedReader(.defaultTint) var defaultTint
        @SharedReader(.defaultAppearance) var defaultAppearance
        let theme = NoteTheme(style: style ?? defaultStyle, tint: tint ?? defaultTint, appearance: defaultAppearance)
        let note = try NoteStore().add(body: body.trimmingTrailingNewline, title: title ?? "", theme: theme)
        if output.json { return try Output.json(NoteJSON(note, includesBody: false)) }
        print(Output.row(note))
    }
}

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
        var text = body ?? ((append ?? prepend) == nil ? Output.standardInput()?.trimmingTrailingNewline : nil) ?? note.body
        if let append { text = text.isEmpty ? append : text + "\n" + append }
        if let prepend { text = text.isEmpty ? prepend : prepend + "\n" + text }
        var theme = note.theme
        if let style { theme.style = style }
        if let tint { theme.tint = tint }
        if let appearance { theme.appearance = appearance }
        let updated = try store.update(note, body: text, title: title, theme: theme)
        if output.json { return try Output.json(NoteJSON(updated, includesBody: true)) }
        print(Output.row(updated))
    }
}

struct Tasks: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List a note's checklist items, numbered for check and uncheck.")
    @Argument(help: "The note.") var note: String
    @OptionGroup var output: JSONFlag

    func run() throws {
        let tasks = NoteStore.tasks(in: try NoteStore().resolve(note).body)
        if output.json { return try Output.json(tasks) }
        tasks.forEach { print("\($0.number). [\($0.isDone ? "x" : " ")] \($0.text)") }
    }
}

struct Check: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Check off a checklist item.")
    @Argument(help: "The note.") var note: String
    @Argument(help: "The item's number, from tack tasks.") var number: Int

    func run() throws { try setTask(note, number, done: true) }
}

struct Uncheck: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Uncheck a checklist item.")
    @Argument(help: "The note.") var note: String
    @Argument(help: "The item's number, from tack tasks.") var number: Int

    func run() throws { try setTask(note, number, done: false) }
}

private func setTask(_ reference: String, _ number: Int, done: Bool) throws {
    let store = NoteStore()
    let note = try store.resolve(reference)
    try store.update(note, body: NoteStore.setting(task: number, done: done, in: note.body))
    let task = NoteStore.tasks(in: try store.resolve(note.id.rawValue.uuidString).body)[number - 1]
    print("\(task.number). [\(task.isDone ? "x" : " ")] \(task.text)")
}

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
            guard readLine()?.lowercased().hasPrefix("y") == true else { return }
        }
        try store.delete(note)
        print("Deleted \(Output.row(note))")
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Write every note to a folder as Markdown files.")
    @Argument(help: "The folder. It is created if needed.") var folder: String

    func run() throws {
        let directory = URL(filePath: (folder as NSString).expandingTildeInPath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let notes = try NoteStore().all(limit: 100_000)
        for note in notes {
            let url = directory.appending(path: NoteStore.fileName(for: note))
            try note.body.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.modificationDate: note.updatedAt], ofItemAtPath: url.path(percentEncoded: false))
        }
        print("Wrote \(notes.count) notes to \(directory.path(percentEncoded: false))")
    }
}

struct Import: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Add Markdown files as notes.")
    @Argument(help: "Markdown or text files.") var files: [String]

    func run() throws {
        @SharedReader(.defaultStyle) var defaultStyle
        @SharedReader(.defaultTint) var defaultTint
        @SharedReader(.defaultAppearance) var defaultAppearance
        let theme = NoteTheme(style: defaultStyle, tint: defaultTint, appearance: defaultAppearance)
        let store = NoteStore()
        for file in files {
            let body = try String(contentsOfFile: (file as NSString).expandingTildeInPath, encoding: .utf8)
            print(Output.row(try store.add(body: body.trimmingTrailingNewline, theme: theme)))
        }
    }
}

struct Where: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print where the notes are stored.")

    func run() throws {
        print(try DependencyValues.databaseURL().path(percentEncoded: false))
    }
}

extension String {
    var trimmingTrailingNewline: String {
        hasSuffix("\n") ? String(dropLast()) : self
    }
}
