import Foundation
import Sharing

public extension SharedReaderKey where Self == AppStorageKey<NoteStyle>.Default {
    static var defaultStyle: Self { Self[.appStorage("defaultStyle"), default: .glass] }
}

public extension SharedReaderKey where Self == AppStorageKey<NoteTint>.Default {
    static var defaultTint: Self { Self[.appStorage("defaultTint"), default: .none] }
}

public extension SharedReaderKey where Self == AppStorageKey<NoteAppearance>.Default {
    static var defaultAppearance: Self { Self[.appStorage("defaultAppearance"), default: .system] }
}

public extension SharedReaderKey where Self == AppStorageKey<EditorFont>.Default {
    static var noteFont: Self { Self[.appStorage("noteFont"), default: .system] }
    static var focusFont: Self { Self[.appStorage("focusFont"), default: .duo] }
}

public extension SharedReaderKey where Self == AppStorageKey<Int>.Default {
    static var noteFontSize: Self { Self[.appStorage("noteFontSize"), default: 15] }
}

public extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    static var typewriterScrolling: Self { Self[.appStorage("typewriterScrolling"), default: true] }
    static var dimsOtherParagraphs: Self { Self[.appStorage("dimsOtherParagraphs"), default: true] }
    static var checksSpelling: Self { Self[.appStorage("checksSpelling"), default: true] }
    static var showsDockIcon: Self { Self[.appStorage("showsDockIcon"), default: false] }
    static var showsMenuBarIcon: Self { Self[.appStorage("showsMenuBarIcon"), default: true] }
    static var infersTitles: Self { Self[.appStorage("infersTitles"), default: true] }
    static var pinsNewNotes: Self { Self[.appStorage("pinsNewNotes"), default: false] }
    static var hasSeededWelcomeNote: Self { Self[.appStorage("hasSeededWelcomeNote"), default: false] }
}

public extension SharedKey where Self == FileStorageKey<[WindowRecord]>.Default {
    static var openWindows: Self {
        Self[
            .fileStorage(.applicationSupportDirectory.appending(path: "Tack/windows.json")),
            default: []
        ]
    }
}
