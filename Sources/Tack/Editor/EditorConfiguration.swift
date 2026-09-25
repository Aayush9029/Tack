import CoreGraphics
import TackKit

struct EditorConfiguration: Equatable {
    var noteFont: EditorFont
    var focusFont: EditorFont
    var size: Int
    var isFocusMode: Bool
    var isTypewriter: Bool
    var dimsParagraphs: Bool
    var checksSpelling: Bool
}

extension EditorConfiguration {
    var family: EditorFont { isFocusMode ? focusFont : noteFont }
    var pointSize: CGFloat { CGFloat(isFocusMode ? size + 3 : size) }
}
