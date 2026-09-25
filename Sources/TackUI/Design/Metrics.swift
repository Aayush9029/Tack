import CoreGraphics

/// One radius for the window and one inset for the controls in its corners, so
/// every control sits concentric with the corner it lives in.
enum Metrics {
    static let windowRadius: CGFloat = 20
    static let cornerInset: CGFloat = 6
    static let controlSize: CGFloat = (windowRadius - cornerInset) * 2
    static let titleBarHeight: CGFloat = controlSize + cornerInset * 2
    static let paletteRadius: CGFloat = 16
    static let paletteWidth: CGFloat = 340
}
