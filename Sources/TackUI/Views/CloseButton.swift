import SwiftUI

/// The only window button a note needs, drawn because the window has no title bar.
struct CloseButton: View {
    let isKey: Bool
    let close: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: close) {
            Circle()
                .fill(isKey || isHovering ? Color(red: 1.0, green: 0.37, blue: 0.34) : Color.primary.opacity(0.18))
                .overlay { Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5) }
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 6.5, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.55))
                        .opacity(isHovering ? 1 : 0)
                }
                .frame(width: 12, height: 12)
                .contentShape(.circle.inset(by: -4))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Close")
        .accessibilityLabel("Close")
    }
}
