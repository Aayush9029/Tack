import Foundation

/// The `tack` command inside the app, linked into ~/.local/bin so the link follows
/// the app through updates.
enum CommandLineTool {
    static var bundled: URL {
        Bundle.main.bundleURL.appending(path: "Contents/Helpers/tack")
    }

    static var link: URL {
        URL.homeDirectory.appending(path: ".local/bin/tack")
    }

    static var isInstalled: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: link.path(percentEncoded: false))) == bundled.path(percentEncoded: false)
    }

    static func install() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? manager.attributesOfItem(atPath: link.path(percentEncoded: false))) != nil {
            try manager.removeItem(at: link)
        }
        try manager.createSymbolicLink(at: link, withDestinationURL: bundled)
    }
}
