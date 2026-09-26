import CasePaths
import Foundation
import Observation

/// Settings' Raycast import: a chosen export, its password, and how the import went.
@MainActor
@Observable
public final class RaycastImportModel {
    @CasePathable
    public enum Status: Equatable {
        case idle
        case importing
        case finished(RaycastImport.Result, total: Int)
        case failed(String)
    }

    public private(set) var file: URL?
    public var password = ""
    public private(set) var status = Status.idle

    public init() {}

    public var canImport: Bool { file != nil && !password.isEmpty && status != .importing }

    public func fileChosen(_ url: URL) {
        file = url
        status = .idle
    }

    public func importButtonTapped(theme: NoteTheme) async {
        guard let file, canImport else { return }
        status = .importing
        let password = password
        do {
            let notes = try await Self.read(file, password: password)
            let result = try RaycastImport().run(notes, theme: theme)
            status = .finished(result, total: notes.count)
            self.password = ""
        } catch let failure as RaycastExport.Failure {
            status = .failed(failure.description)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// scrypt and AES-GCM over a few megabytes: off the main actor.
    @concurrent
    private static func read(_ url: URL, password: String) async throws -> [RaycastExport.Note] {
        try RaycastExport.notes(in: Data(contentsOf: url), password: password)
    }
}
