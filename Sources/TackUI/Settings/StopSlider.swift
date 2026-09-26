import SwiftUI

/// A pill track with a stop for each choice and a white knob, after ChatGPT's model
/// picker. A drag moves the knob freely; a release snaps it to the nearest stop.
struct StopSlider: View {
    let count: Int
    let index: Int
    let tint: [Color]
    var onPreview: (Int?) -> Void = { _ in }
    let onCommit: (Int) -> Void

    @State private var dragValue: Double?

    private let height: CGFloat = 44
    private let knob: CGFloat = 30

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let inset = height / 2
            let span = width - inset * 2
            let last = Double(max(count - 1, 1))
            let value = dragValue ?? Double(index)
            let knobX = inset + span * CGFloat(value / last)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.10))
                Capsule()
                    .fill(LinearGradient(colors: tint, startPoint: .leading, endPoint: .trailing))
                    .frame(width: knobX + inset)
                ForEach(0..<count, id: \.self) { stop in
                    Circle()
                        .fill(.white.opacity(Double(stop) <= value ? 0.55 : 0.35))
                        .frame(width: 6, height: 6)
                        .position(x: inset + span * CGFloat(Double(stop) / last), y: height / 2)
                }
                Circle()
                    .fill(.white)
                    .frame(width: knob, height: knob)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .position(x: knobX, y: height / 2)
            }
            .contentShape(.rect)
            // High priority: inside a form row the list would otherwise claim the drag.
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let raw = Double((gesture.location.x - inset) / span) * last
                        let clamped = min(max(raw, 0), last)
                        dragValue = clamped
                        onPreview(Int(clamped.rounded()))
                    }
                    .onEnded { gesture in
                        let raw = Double((gesture.location.x - inset) / span) * last
                        let stop = Int(min(max(raw, 0), last).rounded())
                        onCommit(stop)
                        withAnimation(.snappy(duration: 0.28)) { dragValue = nil }
                        onPreview(nil)
                    }
            )
        }
        .frame(height: height)
        .animation(.snappy(duration: 0.28), value: index)
    }
}
