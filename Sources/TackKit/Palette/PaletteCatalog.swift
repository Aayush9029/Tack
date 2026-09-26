public enum PaletteCatalog {
    public static func items(on page: PalettePage, in context: PaletteContext) -> [PaletteItem] {
        switch page {
        case .root: root(context)
        case .copyAs: CopyFormat.allCases.map { PaletteItem(.copyAs($0), $0.title, symbol: $0.symbol) }
        case .theme: theme(context)
        case .notes: []
        }
    }

    private static func root(_ context: PaletteContext) -> [PaletteItem] {
        [
            PaletteItem(.newNote, "New Note", symbol: "plus", shortcut: ["⌘", "N"], keywords: ["create", "add"]),
            PaletteItem(.newWindow, "New Note in Window", symbol: "macwindow.badge.plus", shortcut: ["⌥", "⌘", "N"], keywords: ["open"]),
            PaletteItem(.duplicate, "Duplicate Note", symbol: "plus.square.on.square", shortcut: ["⌘", "D"], keywords: ["clone"]),
            PaletteItem(.overview, "All Notes", symbol: "square.grid.2x2", shortcut: ["⇧", "⌘", "O"], keywords: ["grid", "overview", "everything"]),
            PaletteItem(.browse, "Browse Notes", symbol: "rectangle.on.rectangle.angled", shortcut: ["⌘", "P"], keywords: ["search", "open", "all"]),
            PaletteItem(.previousNote, "Previous Note", symbol: "chevron.backward", shortcut: ["⌥", "⌘", "←"], keywords: ["swipe", "newer"], isEnabled: context.hasPrevious, group: 1),
            PaletteItem(.nextNote, "Next Note", symbol: "chevron.forward", shortcut: ["⌥", "⌘", "→"], keywords: ["swipe", "older"], isEnabled: context.hasNext, group: 1),
            PaletteItem(.find, "Find in Note", symbol: "text.magnifyingglass", shortcut: ["⌘", "F"], keywords: ["search", "replace"], group: 2),
            PaletteItem(.page(.copyAs), "Copy Note As…", symbol: "doc.on.clipboard", shortcut: ["⇧", "⌘", "C"], keywords: ["markdown", "plain", "html", "rich"], group: 2),
            PaletteItem(.export, "Export…", symbol: "square.and.arrow.up", shortcut: ["⇧", "⌘", "E"], keywords: ["save", "file", "markdown"], group: 2),
            PaletteItem(.togglePin, context.isPinned ? "Unpin from Top" : "Pin on Top", symbol: context.isPinned ? "pin.slash" : "pin", shortcut: ["⇧", "⌘", "P"], keywords: ["float", "above", "stay"], group: 3),
            PaletteItem(.toggleFocus, context.isFocusMode ? "Exit Focus Mode" : "Focus Mode", symbol: context.isFocusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right", shortcut: ["⌘", "↩"], keywords: ["full screen", "writer", "zen"], group: 3),
            PaletteItem(.page(.theme), "Change Look…", symbol: "paintpalette", keywords: ["theme", "style", "tint", "color", "glass", "classic", "dark", "light"], group: 3),
            PaletteItem(.rename, "Rename Note…", symbol: "character.cursor.ibeam", keywords: ["title"], group: 4),
            PaletteItem(.delete, "Delete Note…", symbol: "trash", keywords: ["remove"], group: 4),
            PaletteItem(.settings, "Settings…", symbol: "gearshape", shortcut: ["⌘", ","], keywords: ["preferences"], group: 4),
        ]
    }

    private static func theme(_ context: PaletteContext) -> [PaletteItem] {
        let styles = NoteStyle.allCases.map { style in
            PaletteItem(.setStyle(style), style.title, symbol: style.symbol, keywords: ["style"], isChecked: context.theme.style == style)
        }
        let tints = NoteTint.allCases.map { tint in
            PaletteItem(.setTint(tint), tint.title, symbol: "circle", keywords: ["tint", "color"], isChecked: context.theme.tint == tint, group: 1, swatch: tint)
        }
        let appearances = NoteAppearance.allCases.map { appearance in
            PaletteItem(.setAppearance(appearance), appearance.title, symbol: appearance.symbol, keywords: ["appearance", "mode"], isEnabled: context.theme.style != .classic, isChecked: context.theme.appearance == appearance, group: 2)
        }
        return styles + tints + appearances
    }

    /// Prefix beats word start beats substring beats scattered letters; nil is no match.
    public static func score(_ item: PaletteItem, query: String) -> Int? {
        let query = query.lowercased()
        guard !query.isEmpty else { return 0 }
        let title = item.title.lowercased()
        if title.hasPrefix(query) { return 400 }
        if title.split(separator: " ").contains(where: { $0.hasPrefix(query) }) { return 300 }
        if title.contains(query) { return 200 }
        if item.keywords.contains(where: { $0.hasPrefix(query) }) { return 150 }
        return isSubsequence(query, of: title) ? 100 : nil
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var index = haystack.startIndex
        for character in needle where character != " " {
            guard let found = haystack[index...].firstIndex(of: character) else { return false }
            index = haystack.index(after: found)
        }
        return true
    }
}
