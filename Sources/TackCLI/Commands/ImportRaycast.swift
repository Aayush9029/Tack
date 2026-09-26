import ArgumentParser
import Foundation
import Sharing
import TackKit

struct ImportRaycast: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import-raycast",
        abstract: "Add the notes from a Raycast export (.rayconfig).",
        discussion: """
        In Raycast, open Settings > Advanced > Export, include Notes, and set a password. \
        Without --password, tack asks for it. Notes already in Tack are skipped.
        """
    )
    @Argument(help: "The .rayconfig file.") var file: String
    @Option(help: "The export's password.") var password: String?

    func run() throws {
        let data = try Data(contentsOf: URL(filePath: (file as NSString).expandingTildeInPath))
        guard let password = password ?? String(validatingCString: getpass("Export password: ")), !password.isEmpty else {
            throw ValidationError("The export needs its password.")
        }
        @SharedReader(.defaultStyle) var defaultStyle
        @SharedReader(.defaultTint) var defaultTint
        @SharedReader(.defaultAppearance) var defaultAppearance
        let notes = try RaycastExport.notes(in: data, password: password)
        let result = try RaycastImport().run(notes, theme: NoteTheme(style: defaultStyle, tint: defaultTint, appearance: defaultAppearance))
        print("Imported \(result.imported) of \(notes.count) notes" + (result.skipped > 0 ? "; \(result.skipped) were already in Tack." : "."))
    }
}
