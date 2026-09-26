import ArgumentParser
import TackKit

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Find notes by the words in them.")
    @Argument(help: "Words to find. Each matches as a prefix.") var words: [String]
    @Option(help: "How many notes to return.") var limit = 20
    @OptionGroup var output: JSONFlag

    func run() throws {
        let results = try NoteStore().search(words.joined(separator: " "), limit: limit)
        if output.json { return try Output.json(results.map { NoteJSON($0.0, includesBody: false) }) }
        for (note, hit) in results {
            print(Output.row(note))
            let snippet = hit.snippet.split(whereSeparator: \.isNewline).joined(separator: " ")
            if !snippet.isEmpty { print("          \(snippet)") }
        }
    }
}
