/// What the SwiftUI chrome asks of the window it lives in.
@MainActor
struct NoteWindowActions {
    var close: () -> Void
    var minimize: () -> Void
    var toggleFocusMode: () -> Void
    var escape: () -> Void
}
