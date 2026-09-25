import Foundation
import TackKit
import UniformTypeIdentifiers

enum MediaSource {
    /// Pasted media lives under Attachments and is written as `attachments/<name>`,
    /// so a note stays short and survives the Application Support path changing.
    static func url(for source: String) -> URL? {
        let decoded = source.removingPercentEncoding ?? source
        if decoded.hasPrefix("attachments/") {
            return AttachmentClient.directory.appending(path: String(decoded.dropFirst("attachments/".count)))
        }
        if decoded.hasPrefix("~/") {
            return URL.homeDirectory.appending(path: String(decoded.dropFirst(2)))
        }
        if decoded.hasPrefix("/") {
            return URL(filePath: decoded)
        }
        if let url = URL(string: source), let scheme = url.scheme, ["file", "http", "https"].contains(scheme) {
            return url
        }
        return nil
    }

    static func source(for url: URL) -> String {
        let directory = AttachmentClient.directory.standardizedFileURL.path(percentEncoded: false)
        let path = url.standardizedFileURL.path(percentEncoded: false)
        let written: String
        if path.hasPrefix(directory) {
            written = "attachments/" + path.dropFirst(directory.count).drop { $0 == "/" }
        } else if path.hasPrefix(URL.homeDirectory.path(percentEncoded: false)) {
            written = "~/" + path.dropFirst(URL.homeDirectory.path(percentEncoded: false).count).drop { $0 == "/" }
        } else {
            written = path
        }
        return written.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? written
    }

    static func isVideo(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video)
    }

    static func isMedia(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie) || type.conforms(to: .video)
    }
}
