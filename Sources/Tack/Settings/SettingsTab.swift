import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case notes
    case editor
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .notes: "Notes"
        case .editor: "Editor"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .notes: "note.text"
        case .editor: "character.cursor.ibeam"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .notes: .yellow
        case .editor: .indigo
        case .shortcuts: .orange
        case .about: .blue
        }
    }
}
