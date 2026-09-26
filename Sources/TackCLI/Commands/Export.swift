import ArgumentParser
import Foundation
import TackKit

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
