public struct PaletteItem: Identifiable, Equatable, Sendable {
    public var command: NoteCommand
    public var title: String
    public var symbol: String
    public var shortcut: [String]
    public var keywords: [String]
    public var isEnabled: Bool
    public var isChecked: Bool
    /// Items in different groups are separated by a rule.
    public var group: Int
    /// A tint swatch drawn in place of the symbol.
    public var swatch: NoteTint?

    public init(
        _ command: NoteCommand,
        _ title: String,
        symbol: String,
        shortcut: [String] = [],
        keywords: [String] = [],
        isEnabled: Bool = true,
        isChecked: Bool = false,
        group: Int = 0,
        swatch: NoteTint? = nil
    ) {
        self.command = command
        self.title = title
        self.symbol = symbol
        self.shortcut = shortcut
        self.keywords = keywords
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.group = group
        self.swatch = swatch
    }

    public var id: String { "\(command)" }
}
