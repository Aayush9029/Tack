import AppKit

final class PalettePanel: NSPanel {
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }

    // A focused text field swallows Escape before SwiftUI sees it.
    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}
