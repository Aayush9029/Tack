import Sharing
import SwiftUI
import TackKit

struct NotesPane: View {
    let app: AppModel

    private var preferences: Preferences { app.preferences }

    var body: some View {
        SettingsForm {
            Section("Style") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(NoteStyle.allCases) { style in
                        ToggleCard(
                            title: style.title,
                            isOn: preferences.defaultStyle == style,
                            aspectRatio: 1.45,
                            action: { app.lookChanged(style: style) }
                        ) {
                            NoteStyleIllustration(style: style, tint: preferences.defaultTint)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                Text("Changes every note. Right-click a note's title to change just that one.")
                    .settingFootnote()
            }

            Section("Tint") {
                FlowLayout(spacing: 8) {
                    ForEach(NoteTint.allCases) { tint in
                        TintChip(tint: tint, isOn: preferences.defaultTint == tint) {
                            app.lookChanged(tint: tint)
                        }
                    }
                }
                .padding(.vertical, 4)
                Text("Glass takes a wash of the color. Classic without a tint is yellow.")
                    .settingFootnote()
            }

            Section("Appearance") {
                Picker("Notes", selection: Binding(get: { preferences.defaultAppearance }, set: { app.lookChanged(appearance: $0) })) {
                    ForEach(NoteAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                Text("Classic notes are always paper-colored.")
                    .settingFootnote()
            }
        }
    }
}
