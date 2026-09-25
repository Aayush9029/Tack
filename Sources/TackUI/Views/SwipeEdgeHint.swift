import SwiftUI
import TackKit

/// The chevron that grows at the edge a swipe is heading for, and turns solid
/// once letting go would change the note.
struct SwipeEdgeHint: View {
    let edge: SwipeEdge?
    let offset: CGFloat

    private var progress: CGFloat { min(abs(offset) / SwipeGesture.commitDistance, 1) }

    var body: some View {
        HStack {
            if offset > 0 { chevron("chevron.backward") }
            Spacer(minLength: 0)
            if offset < 0 { chevron("chevron.forward") }
        }
        .padding(.horizontal, 14)
        .allowsHitTesting(false)
        .opacity(edge == nil ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: edge == nil)
    }

    private func chevron(_ symbol: String) -> some View {
        Image(systemName: edge == .blocked ? "nosign" : symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(progress >= 1 ? .primary : .secondary)
            .frame(width: 34, height: 34)
            .glassEffect(.regular, in: .circle)
            .scaleEffect(0.6 + 0.4 * progress)
            .opacity(Double(progress))
    }
}
