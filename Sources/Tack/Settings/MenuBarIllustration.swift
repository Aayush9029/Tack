import SwiftUI

/// A desktop in miniature with the pin sitting in its menu bar.
struct MenuBarIllustration: View {
    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.size
            let menuBar = screen.height * 0.16
            ZStack(alignment: .topTrailing) {
                DesktopWallpaper.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: screen.width, height: screen.height)
                    .clipped()
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: menuBar)
                HStack(spacing: menuBar * 0.45) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: menuBar * 0.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Capsule().fill(.primary.opacity(0.45)).frame(width: menuBar * 0.7, height: menuBar * 0.28)
                    Circle().fill(.primary.opacity(0.45)).frame(width: menuBar * 0.32, height: menuBar * 0.32)
                    Capsule().fill(.primary.opacity(0.45)).frame(width: menuBar * 1.1, height: menuBar * 0.28)
                }
                .frame(height: menuBar)
                .padding(.trailing, screen.width * 0.05)
            }
        }
    }
}
