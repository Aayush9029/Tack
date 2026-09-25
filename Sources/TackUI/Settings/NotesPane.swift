import Sharing
import SwiftUI
import TackKit

struct NotesPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        SettingsForm {
            Section("Style") {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(NoteStyle.allCases) { style in
                        ToggleCard(
                            title: style.title,
                            description: style.description,
                            isOn: preferences.defaultStyle == style,
                            aspectRatio: 1.45,
                            action: { preferences.$defaultStyle.withLock { $0 = style } }
                        ) {
                            NoteStyleIllustration(style: style, tint: preferences.defaultTint)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                Text("For new notes. Right-click a note's title to change that note.")
                    .settingFootnote()
            }

            Section("Tint") {
                FlowLayout(spacing: 8) {
                    ForEach(NoteTint.allCases) { tint in
                        TintChip(tint: tint, isOn: preferences.defaultTint == tint) {
                            preferences.$defaultTint.withLock { $0 = tint }
                        }
                    }
                }
                .padding(.vertical, 4)
                Text("Glass takes a wash of the colour. Classic without a tint is yellow.")
                    .settingFootnote()
            }

            Section("Appearance") {
                Picker("New notes", selection: Binding(preferences.$defaultAppearance)) {
                    ForEach(NoteAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private extension NoteStyle {
    var description: String {
        switch self {
        case .glass: "Liquid Glass with a soft scrim, readable over any desktop."
        case .clear: "Clear glass, smoked just enough for the text."
        case .classic: "The paper sticky note, in Windows Sticky Notes' colours."
        }
    }
}
