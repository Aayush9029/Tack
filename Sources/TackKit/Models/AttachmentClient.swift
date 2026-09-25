import Dependencies
import DependenciesMacros
import Foundation

/// Pasted and dropped media, copied into Application Support so a note keeps
/// working after the original file moves.
@DependencyClient
public struct AttachmentClient: Sendable {
    public var save: @Sendable (_ data: Data, _ fileExtension: String) throws -> URL
    public var importFile: @Sendable (_ url: URL) throws -> URL
}

extension AttachmentClient: DependencyKey {
    public static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "Tack/Attachments", directoryHint: .isDirectory)
    }

    public static let liveValue = AttachmentClient(
        save: { data, fileExtension in
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: "\(UUID().uuidString.prefix(8).lowercased()).\(fileExtension)")
            try data.write(to: url, options: .atomic)
            return url
        },
        importFile: { source in
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = "\(UUID().uuidString.prefix(8).lowercased())-\(source.lastPathComponent)"
            let url = directory.appending(path: name)
            try FileManager.default.copyItem(at: source, to: url)
            return url
        }
    )

    public static let testValue = AttachmentClient()
}

public extension DependencyValues {
    var attachmentClient: AttachmentClient {
        get { self[AttachmentClient.self] }
        set { self[AttachmentClient.self] = newValue }
    }
}
