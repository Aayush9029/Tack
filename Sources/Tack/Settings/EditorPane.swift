import Sharing
import SwiftUI
import TackKit

struct EditorPane: View {
    @Bindable var preferences: Preferences

    var body: some View {
        SettingsForm {
            Section("Font") {
                fontCards(selection: preferences.noteFont) { font in
                    preferences.$noteFont.withLock { $0 = font }
                }
                FontSizeSlider(preferences: preferences)
                    .padding(.vertical, 4)
            }

            Section("Focus Mode") {
                fontCards(selection: preferences.focusFont) { font in
                    preferences.$focusFont.withLock { $0 = font }
                }
                Toggle("Typewriter scrolling", isOn: Binding(preferences.$typewriterScrolling))
                Text("The line you are writing stays in the middle of the screen.")
                    .settingFootnote()
                Toggle("Dim other paragraphs", isOn: Binding(preferences.$dimsOtherParagraphs))
                Text("Press ⌘↩ in a note for focus mode, and again or Esc to leave.")
                    .settingFootnote()
            }

            Section("Writing") {
                Toggle("Check spelling while typing", isOn: Binding(preferences.$checksSpelling))
            }
        }
    }

    private func fontCards(selection: EditorFont, choose: @escaping (EditorFont) -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(EditorFont.allCases) { font in
                ToggleCard(
                    title: font.title,
                    description: font.description,
                    isOn: selection == font,
                    aspectRatio: 1.5,
                    action: { choose(font) }
                ) {
                    FontIllustration(font: font)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }
}
