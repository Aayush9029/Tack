import SwiftUI
import TackKit

/// Light gathering at the edge the next note comes from, in Flare's violet. It
/// grows with the swipe, stays faint where there is no note to go to, and
/// flashes once when the note changes.
struct SwipeGlow: View {
    let offset: CGFloat
    let isAllowed: Bool
    let flash: SwipeEdge?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors: [Color] = [
        Color(red: 0.66, green: 0.48, blue: 1.00),
        Color(red: 0.48, green: 0.25, blue: 0.89),
        Color(red: 0.36, green: 0.55, blue: 1.00),
        Color(red: 0.66, green: 0.48, blue: 1.00),
    ]

    private var progress: CGFloat { min(abs(offset) / SwipeGesture.commitDistance, 1) }

    var body: some View {
        HStack(spacing: 0) {
            edge(isActive: offset > 0 || flash == .previous, strength: flash == .previous ? 1 : (offset > 0 ? progress : 0))
            Spacer(minLength: 0)
            edge(isActive: offset < 0 || flash == .next, strength: flash == .next ? 1 : (offset < 0 ? progress : 0))
                .scaleEffect(x: -1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func edge(isActive: Bool, strength: CGFloat) -> some View {
        TimelineView(.animation(paused: !isActive || reduceMotion)) { timeline in
            let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
            let gradient = LinearGradient(
                colors: Self.colors,
                startPoint: UnitPoint(x: 0.5, y: phase - 0.5),
                endPoint: UnitPoint(x: 0.5, y: phase + 1)
            )
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(gradient)
                    .frame(width: 10 + 26 * strength)
                    .blur(radius: 16)
                    .opacity(Double(strength) * (isAllowed ? 0.9 : 0.3))
                Capsule()
                    .fill(gradient)
                    .frame(width: 2.5)
                    .padding(.vertical, 18)
                    .padding(.leading, 3)
                    .opacity(Double(strength) * (isAllowed ? 1 : 0.35))
            }
            .drawingGroup()
        }
        .frame(maxHeight: .infinity)
        .opacity(isActive ? 1 : 0)
    }
}
