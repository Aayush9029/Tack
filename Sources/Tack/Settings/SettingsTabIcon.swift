import SwiftUI

struct SettingsTabIcon: View {
    let tab: SettingsTab
    var isSelected = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tab.tint.gradient)
                .opacity(isSelected ? 1 : 0.7)
            Image(systemName: tab.symbol)
                .symbolVariant(.fill)
                .foregroundStyle(.white)
                .font(.system(size: 10.4, weight: .semibold))
        }
        .frame(width: 24, height: 24)
    }
}
