import ArgumentParser
import Foundation
import Sharing
import TackKit

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
