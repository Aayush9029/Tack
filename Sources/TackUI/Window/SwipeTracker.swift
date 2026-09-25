import AppKit
import SwiftUI
import TackKit

/// Feeds trackpad scroll events to `SwipeGesture` and moves the note with it.
@MainActor
final class SwipeTracker {
    private weak var window: NSWindow?
    private let state: WindowState
    private var monitor: Any?
    private var gesture = SwipeGesture()

    var canSwipe: (SwipeGesture.Direction) -> Bool = { _ in false }
    var onCommit: (SwipeGesture.Direction) -> Void = { _ in }

    init(window: NSWindow, state: WindowState) {
        self.window = window
        self.state = state
    }

    func install() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    func uninstall() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window, event.hasPreciseScrollingDeltas else { return event }
        if event.momentumPhase != [] {
            return gesture.swallowsMomentum ? nil : event
        }
        let phase: SwipeGesture.Phase
        switch event.phase {
        case .began, .mayBegin: phase = .began
        case .changed: phase = .changed
        case .ended: phase = .ended
        case .cancelled: phase = .cancelled
        default: return event
        }
        let dx = event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
        let outcome = gesture.handle(phase, dx: dx, dy: event.scrollingDeltaY, canSwipe: canSwipe)
        switch outcome {
        case .passThrough:
            return event
        case let .tracking(offset, toward):
            state.swipeOffset = offset
            state.swipeEdge = toward.map { $0 == .previous ? .previous : .next }
        case let .commit(direction):
            state.swipeEdge = nil
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                state.swipeOffset = 0
                state.swipeFlash = direction == .previous ? .previous : .next
            }
            onCommit(direction)
            let state = state
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.5)) { state.swipeFlash = nil }
            }
        case .springBack:
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                state.swipeOffset = 0
                state.swipeEdge = nil
            }
        }
        return nil
    }
}
