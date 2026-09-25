import SwiftUI

struct ToggleCard<Illustration: View>: View {
    let title: String
    let description: String
    var icon: String?
    let isOn: Bool
    var aspectRatio: CGFloat = 2
    let action: () -> Void
    @ViewBuilder let illustration: Illustration

    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingDescription = false
    @State private var isHovering = false

    private let radius: CGFloat = 14

    var body: some View {
        VStack(spacing: 10) {
            Button(action: action) {
                illustration
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.black.opacity(0.05).shadow(.inner(radius: 10, y: 1)))
                    }
                    .overlay(alignment: .topTrailing) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 15, weight: .bold))
                                .symbolRenderingMode(.hierarchical)
                                .symbolVariant(.fill)
                                .foregroundStyle(isOn ? .primary : .secondary)
                                .padding(10)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                isOn ? (colorScheme == .dark ? .white : .black) : .primary.opacity(0.12),
                                lineWidth: isOn ? 3 : 1
                            )
                    }
                    .overlay(alignment: .topLeading) { infoButton }
                    .shadow(color: .black.opacity(0.25), radius: isHovering ? 9 : 5, y: isHovering ? 5 : 3)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(isOn ? .primary : .secondary)
        }
        .animation(.easeInOut(duration: 0.25), value: isOn)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .popover(isPresented: $isShowingDescription, arrowEdge: .bottom) {
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }

    private var infoButton: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 14, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .padding(10)
            .onHover { isShowingDescription = $0 }
    }
}
