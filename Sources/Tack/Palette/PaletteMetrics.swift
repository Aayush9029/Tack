import CoreGraphics
import TackKit

/// Row heights the palette is laid out with, so its window can be sized from the
/// rows before SwiftUI draws them.
enum PaletteMetrics {
    static let fieldHeight: CGFloat = 50
    static let itemHeight: CGFloat = 34
    static let noteHeight: CGFloat = 46
    static let dividerPadding: CGFloat = 5
    static let listPadding: CGFloat = 6
    static let emptyHeight: CGFloat = 52
    static let maxHeight: CGFloat = 460

    static func height(of rows: [PaletteRow]) -> CGFloat {
        guard !rows.isEmpty else { return fieldHeight + 1 + emptyHeight + listPadding * 2 }
        var height = fieldHeight + 1 + listPadding * 2
        for (index, row) in rows.enumerated() {
            if index > 0, row.group != rows[index - 1].group { height += dividerPadding * 2 + 1 }
            if case .note = row { height += noteHeight } else { height += itemHeight }
        }
        return min(height, maxHeight)
    }
}
