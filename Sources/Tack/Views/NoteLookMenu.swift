import SwiftUI
import TackKit

/// The title's context menu: how this note looks.
struct NoteLookMenu: View {
    let model: NoteWindowModel

    var body: some View {
        Picker("Style", selection: Binding(get: { model.theme.style }, set: model.styleSelected)) {
            ForEach(NoteStyle.allCases) { style in
                Label(style.title, systemImage: style.symbol).tag(style)
            }
        }
        .pickerStyle(.inline)

        Picker("Tint", selection: Binding(get: { model.theme.tint }, set: model.tintSelected)) {
            ForEach(NoteTint.allCases) { tint in
                Label { Text(tint.title) } icon: { Image(nsImage: tint.menuImage) }.tag(tint)
            }
        }
        .pickerStyle(.menu)

        Picker("Appearance", selection: Binding(get: { model.theme.appearance }, set: model.appearanceSelected)) {
            ForEach(NoteAppearance.allCases) { appearance in
                Text(appearance.title).tag(appearance)
            }
        }
        .pickerStyle(.menu)

        Divider()
        Button("Rename…", action: model.renameButtonTapped)
        Button(model.isPinned ? "Unpin from Top" : "Pin on Top", action: model.pinButtonTapped)
        Button(model.isFocusMode ? "Exit Focus Mode" : "Focus Mode", action: model.focusModeToggled)
    }
}
