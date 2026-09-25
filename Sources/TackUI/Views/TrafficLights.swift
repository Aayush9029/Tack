import SwiftUI

/// The window buttons, drawn because the note window has no title bar of its own.
/// Green is focus mode rather than a zoom.
struct TrafficLights: View {
    let isKey: Bool
    let close: () -> Void
    let minimize: () -> Void
    let focus: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            light(Color(red: 1.0, green: 0.37, blue: 0.34), glyph: "xmark", action: close, label: "Close")
            light(Color(red: 1.0, green: 0.74, blue: 0.18), glyph: "minus", action: minimize, label: "Minimize")
            light(Color(red: 0.16, green: 0.78, blue: 0.25), glyph: "arrow.up.left.and.arrow.down.right", action: focus, label: "Focus Mode")
        }
        .onHover { isHovering = $0 }
    }

    private func light(_ color: Color, glyph: String, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Circle()
                .fill(isKey || isHovering ? color : Color.primary.opacity(0.18))
                .overlay {
                    Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
                }
                .overlay {
                    Image(systemName: glyph)
                        .font(.system(size: glyph == "minus" ? 8 : 6.5, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.55))
                        .opacity(isHovering ? 1 : 0)
                }
                .frame(width: 12, height: 12)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
