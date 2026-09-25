import Observation
import Sharing

@MainActor
@Observable
public final class Preferences {
    @ObservationIgnored @Shared(.defaultStyle) public var defaultStyle: NoteStyle
    @ObservationIgnored @Shared(.defaultTint) public var defaultTint: NoteTint
    @ObservationIgnored @Shared(.defaultAppearance) public var defaultAppearance: NoteAppearance
    @ObservationIgnored @Shared(.noteFont) public var noteFont: EditorFont
    @ObservationIgnored @Shared(.noteFontSize) public var noteFontSize: Int
    @ObservationIgnored @Shared(.focusFont) public var focusFont: EditorFont
    @ObservationIgnored @Shared(.typewriterScrolling) public var typewriterScrolling: Bool
    @ObservationIgnored @Shared(.dimsOtherParagraphs) public var dimsOtherParagraphs: Bool
    @ObservationIgnored @Shared(.checksSpelling) public var checksSpelling: Bool
    @ObservationIgnored @Shared(.showsDockIcon) public var showsDockIcon: Bool
    @ObservationIgnored @Shared(.showsMenuBarIcon) public var showsMenuBarIcon: Bool
    @ObservationIgnored @Shared(.pinsNewNotes) public var pinsNewNotes: Bool

    public init() {}

    public var defaultTheme: NoteTheme {
        NoteTheme(style: defaultStyle, tint: defaultTint, appearance: defaultAppearance)
    }

    public nonisolated static let fontSizes = [13, 14, 15, 16, 18, 20]
}
