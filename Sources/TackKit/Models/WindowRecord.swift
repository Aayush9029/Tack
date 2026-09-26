import CoreGraphics
import Foundation

/// An open note window, restored at the next launch.
public struct WindowRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var noteID: Note.ID
    public var frame: CGRect?
    public var isPinned: Bool

    public init(id: UUID, noteID: Note.ID, frame: CGRect? = nil, isPinned: Bool = false) {
        self.id = id
        self.noteID = noteID
        self.frame = frame
        self.isPinned = isPinned
    }
}
