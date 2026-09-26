import Sharing
import SwiftUI
import TackKit

struct GeneralPane: View {
    @Bindable var preferences: Preferences
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        SettingsForm {
            Section {
                HStack(alignment: .top, spacing: 20) {
                    ToggleCard(
                        title: "Open at Login",
                        description: "Your notes are back on the desktop as soon as you log in.",
                        icon: "power",
                        isOn: launchAtLogin.isEnabled,
                        action: { launchAtLogin.set(!launchAtLogin.isEnabled) }
                    ) {
                        AnimatedImage(resource: "launch-at-login")
                    }

                    ToggleCard(
                        title: "Show in Dock",
                        description: "Adds a Dock icon and an entry in the ⌘Tab app switcher. Off, Tack lives in the menu bar.",
                        icon: "dock.rectangle",
                        isOn: preferences.showsDockIcon,
                        action: { preferences.$showsDockIcon.withLock { $0.toggle() } }
                    ) {
                        AnimatedImage(resource: "dock-icon")
                    }

                    ToggleCard(
                        title: "Show in Menu Bar",
                        description: "Shows a pin in the menu bar. When it is off, use the global shortcuts to show your notes.",
                        icon: "menubar.rectangle",
                        isOn: preferences.showsMenuBarIcon,
                        action: { preferences.$showsMenuBarIcon.withLock { $0.toggle() } }
                    ) {
                        MenuBarIllustration()
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

                if let failureMessage = launchAtLogin.failureMessage {
                    Label(failureMessage, systemImage: "exclamationmark.triangle.fill")
                        .settingFootnote()
                        .foregroundStyle(.orange)
                }
            }

            Section("Windows") {
                Toggle("Pin new notes on top", isOn: Binding(preferences.$pinsNewNotes))
                Text("New notes float above every window. The pin in a note's corner changes one note at a time.")
                    .settingFootnote()
            }

            CommandLineSection()

            if RaycastSection.isRaycastInstalled {
                RaycastSection(theme: preferences.defaultTheme)
            }
        }
        .task { launchAtLogin.refresh() }
    }
}
