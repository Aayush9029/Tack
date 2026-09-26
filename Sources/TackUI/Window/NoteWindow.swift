import AppKit

/// A borderless window, so the glass reaches every edge with no title bar, frame
/// or hairline of the system's around it.
final class NoteWindow: NSWindow {
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Sticky notes are desktop furniture, not documents. Switchers such as Raycast
    /// build window lists from Accessibility and leave floating windows out.
    override func accessibilitySubrole() -> NSAccessibility.Subrole? {
        .floatingWindow
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    // Borderless windows have no close button, so the standard close would only beep.
    override func performClose(_ sender: Any?) {
        guard delegate?.windowShouldClose?(self) ?? true else { return }
        close()
    }

    override func performMiniaturize(_ sender: Any?) {
        miniaturize(sender)
    }
}
