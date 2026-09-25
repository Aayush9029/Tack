import CoreGraphics

/// A two-finger horizontal swipe between notes, as a state machine fed with
/// scroll deltas. The note follows the fingers, resists where there is no note to
/// go to, and changes once the swipe passes a distance or leaves fast.
public struct SwipeGesture: Equatable, Sendable {
    public static let commitDistance: CGFloat = 90

    public enum Phase: Sendable {
        case began
        case changed
        case ended
        case cancelled
    }

    public enum Direction: Equatable, Sendable {
        case previous
        case next
    }

    public enum Outcome: Equatable, Sendable {
        /// Not a horizontal swipe; the text view should scroll.
        case passThrough
        case tracking(offset: CGFloat, toward: Direction?)
        case commit(Direction)
        case springBack
    }

    private enum Axis: Equatable, Sendable {
        case horizontal
        case vertical
    }

    private var axis: Axis?
    private var accumulated = CGSize.zero
    private var lastDelta: CGFloat = 0
    public private(set) var offset: CGFloat = 0

    public init() {}

    public var isTracking: Bool { axis == .horizontal }

    /// `dx` is in finger direction: positive when the fingers move right.
    public mutating func handle(_ phase: Phase, dx: CGFloat = 0, dy: CGFloat = 0, canSwipe: (Direction) -> Bool) -> Outcome {
        switch phase {
        case .began:
            self = SwipeGesture()
            return .passThrough
        case .changed:
            accumulated.width += dx
            accumulated.height += dy
            lastDelta = dx
            if axis == nil {
                if abs(accumulated.width) > 10, abs(accumulated.width) > abs(accumulated.height) * 1.5 {
                    axis = .horizontal
                } else if abs(accumulated.height) > 10 {
                    axis = .vertical
                }
            }
            guard axis == .horizontal else { return .passThrough }
            let direction: Direction = accumulated.width > 0 ? .previous : .next
            let allowed = canSwipe(direction)
            offset = allowed ? accumulated.width : accumulated.width * 0.18
            return .tracking(offset: offset, toward: allowed ? direction : nil)
        case .ended, .cancelled:
            guard axis == .horizontal else {
                self = SwipeGesture()
                return .passThrough
            }
            let direction: Direction = offset > 0 ? .previous : .next
            let isFlick = abs(lastDelta) > 14 && abs(offset) > 36 && (lastDelta > 0) == (offset > 0)
            let commits = phase == .ended && canSwipe(direction) && (abs(offset) >= Self.commitDistance || isFlick)
            axis = .horizontal
            accumulated = .zero
            offset = 0
            return commits ? .commit(direction) : .springBack
        }
    }

    /// Momentum after a horizontal swipe belongs to the swipe, not the text.
    public var swallowsMomentum: Bool { axis == .horizontal }
}
