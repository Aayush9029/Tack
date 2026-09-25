import Testing
@testable import TackKit

@Suite struct SwipeGestureTests {
    @Test func farEnoughCommits() {
        var gesture = SwipeGesture()
        #expect(gesture.handle(.began, canSwipe: { _ in true }) == .passThrough)
        for _ in 0..<10 { _ = gesture.handle(.changed, dx: -10, canSwipe: { _ in true }) }
        #expect(gesture.offset == -100)
        #expect(gesture.handle(.ended, canSwipe: { _ in true }) == .commit(.next))
    }

    @Test func shortSwipeSpringsBack() {
        var gesture = SwipeGesture()
        _ = gesture.handle(.began, canSwipe: { _ in true })
        for _ in 0..<4 { _ = gesture.handle(.changed, dx: 8, canSwipe: { _ in true }) }
        #expect(gesture.handle(.ended, canSwipe: { _ in true }) == .springBack)
    }

    @Test func flickCommitsEarly() {
        var gesture = SwipeGesture()
        _ = gesture.handle(.began, canSwipe: { _ in true })
        for dx in [6.0, 12, 24] { _ = gesture.handle(.changed, dx: dx, canSwipe: { _ in true }) }
        #expect(gesture.handle(.ended, canSwipe: { _ in true }) == .commit(.previous))
    }

    @Test func resistsWhereThereIsNoNote() {
        var gesture = SwipeGesture()
        _ = gesture.handle(.began, canSwipe: { _ in false })
        var outcome = SwipeGesture.Outcome.passThrough
        for _ in 0..<10 { outcome = gesture.handle(.changed, dx: 10, canSwipe: { _ in false }) }
        #expect(outcome == .tracking(offset: 18, toward: nil))
        #expect(gesture.handle(.ended, canSwipe: { _ in false }) == .springBack)
    }

    @Test func verticalScrollPassesThrough() {
        var gesture = SwipeGesture()
        _ = gesture.handle(.began, canSwipe: { _ in true })
        #expect(gesture.handle(.changed, dx: 2, dy: 14, canSwipe: { _ in true }) == .passThrough)
        #expect(gesture.handle(.changed, dx: 30, dy: 0, canSwipe: { _ in true }) == .passThrough)
        #expect(!gesture.swallowsMomentum)
    }
}
