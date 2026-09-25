import Foundation
import SQLiteData
import Tagged

@Table
public struct Note: Identifiable, Equatable, Sendable {
    public typealias ID = Tagged<Self, UUID>

    public let id: ID
    /// Set only by Rename. Empty means the first line of the body names the note.
    public var title = ""
    public var body = ""
    public var style = NoteStyle.glass
    public var tint = NoteTint.none
    public var appearance = NoteAppearance.system
    public var createdAt = Date()
    public var updatedAt = Date()

    public init(
        id: ID,
        title: String = "",
        body: String = "",
        style: NoteStyle = .glass,
        tint: NoteTint = .none,
        appearance: NoteAppearance = .system,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.style = style
        self.tint = tint
        self.appearance = appearance
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var theme: NoteTheme {
        get { NoteTheme(style: style, tint: tint, appearance: appearance) }
        set {
            style = newValue.style
            tint = newValue.tint
            appearance = newValue.appearance
        }
    }

    public var displayTitle: String {
        title.isEmpty ? NoteText.title(from: body) : title
    }
}
