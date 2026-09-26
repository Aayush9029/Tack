import KeyboardShortcuts
import SwiftUI

struct ShortcutsPane: View {
    var body: some View {
        SettingsForm {
            Section("Global") {
                KeyboardShortcuts.Recorder("New note", name: .newNote)
                KeyboardShortcuts.Recorder("Show or hide notes", name: .showNotes)
                Text("These work from any app.")
                    .settingFootnote()
            }

            Section("In a Note") {
                LabeledContent("Commands", value: "⌘ K")
                LabeledContent("New note", value: "⌘ N")
                LabeledContent("New note in window", value: "⌥ ⌘ N")
                LabeledContent("Duplicate", value: "⌘ D")
                LabeledContent("Browse notes", value: "⌘ P")
                LabeledContent("Previous or next note", value: "⌥ ⌘ ← →, or swipe")
                LabeledContent("Pin on top", value: "⇧ ⌘ P")
                LabeledContent("Focus mode", value: "⌘ ↩")
                LabeledContent("All notes", value: "⇧ ⌘ O")
                LabeledContent("Copy as", value: "⇧ ⌘ C")
                LabeledContent("Export", value: "⇧ ⌘ E")
            }

            Section("Markdown") {
                LabeledContent("Bold, italic", value: "⌘ B, ⌘ I")
                LabeledContent("Strikethrough, highlight", value: "⇧ ⌘ X, ⇧ ⌘ H")
                LabeledContent("Inline code, code block", value: "⌥ ⌘ C, ⌥ ⇧ ⌘ C")
                LabeledContent("Link", value: "⌘ L")
                LabeledContent("Heading 1 to 3, body", value: "⌘ 1 – 3, ⌘ 0")
                LabeledContent("Bulleted, numbered list", value: "⇧ ⌘ 8, ⇧ ⌘ 7")
                LabeledContent("Checklist, toggle checkbox", value: "⇧ ⌘ L, ⇧ ⌘ U")
                LabeledContent("Quote", value: "⌘ '")
                LabeledContent("Indent a list item", value: "Tab, ⇧ Tab")
            }
        }
    }
}
