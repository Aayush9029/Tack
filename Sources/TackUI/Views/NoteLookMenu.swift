import SwiftUI
import TackKit

/// The title's context menu: how this note looks. Toggles, not pickers: a Picker
/// inside a context menu never calls its setter on macOS.
struct NoteLookMenu: View {
    let model: NoteWindowModel

    var body: some View {
        Section("Style") {
            ForEach(NoteStyle.allCases) { style in
                Toggle(isOn: selecting(model.theme.style == style) { model.styleSelected(style) }) {
                    Label(style.title, systemImage: style.symbol)
                }
            }
        }

        Menu("Tint") {
            ForEach(NoteTint.allCases) { tint in
                Toggle(isOn: selecting(model.theme.tint == tint) { model.tintSelected(tint) }) {
                    Label { Text(tint.title) } icon: { Image(nsImage: tint.menuImage) }
                }
            }
        }

        Menu("Appearance") {
            ForEach(NoteAppearance.allCases) { appearance in
                Toggle(appearance.title, isOn: selecting(model.theme.appearance == appearance) { model.appearanceSelected(appearance) })
            }
        }

        Divider()
        Button("Rename…", action: model.renameButtonTapped)
    }

    private func selecting(_ isSelected: Bool, _ select: @escaping () -> Void) -> Binding<Bool> {
        Binding(get: { isSelected }, set: { _ in select() })
    }
}
