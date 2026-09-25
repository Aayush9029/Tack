import CoreGraphics
import Observation

/// Window facts that SwiftUI draws but the model does not own.
@MainActor
@Observable
final class WindowState {
    var isKey = false
    var swipeOffset: CGFloat = 0
    var swipeEdge: SwipeEdge?
    var swipeFlash: SwipeEdge?
}

enum SwipeEdge: Equatable {
    case previous
    case next
    case blocked
}
