import AppKit
import TackKit

@MainActor
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu()))
        main.addItem(submenu(fileMenu()))
        main.addItem(submenu(editMenu()))
        main.addItem(submenu(formatMenu()))
        main.addItem(submenu(noteMenu()))
        let window = windowMenu()
        main.addItem(submenu(window))
        NSApp.windowsMenu = window
        return main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func item(
        _ title: String,
        _ action: Selector?,
        _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command,
        tag: Int = 0
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.tag = tag
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Tack")
        menu.addItem(item("About Tack", #selector(AppDelegate.showAbout(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(AppDelegate.showSettings(_:)), ","))
        menu.addItem(.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        services.submenu = NSMenu(title: "Services")
        NSApp.servicesMenu = services.submenu
        menu.addItem(services)
        menu.addItem(.separator())
        menu.addItem(item("Hide Tack", #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit Tack", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(item("New Note", #selector(NoteWindowController.newNote(_:)), "n"))
        menu.addItem(item("New Note in Window", #selector(AppDelegate.newNoteInWindow(_:)), "n", [.command, .option]))
        menu.addItem(item("Duplicate Note", #selector(NoteWindowController.duplicateNote(_:)), "d"))
        menu.addItem(item("Browse Notes…", #selector(AppDelegate.browseNotes(_:)), "p"))
        menu.addItem(.separator())
        menu.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))
        menu.addItem(.separator())
        menu.addItem(item("Copy Note As…", #selector(NoteWindowController.showCopyAsPalette(_:)), "c", [.command, .shift]))
        let copyAs = NSMenu(title: "Copy As")
        for (index, format) in CopyFormat.allCases.enumerated() {
            copyAs.addItem(item(format.title, #selector(NoteWindowController.copyNoteAs(_:)), tag: index))
        }
        menu.addItem(submenu(copyAs))
        menu.addItem(item("Export…", #selector(NoteWindowController.exportNote(_:)), "e", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Delete Note…", #selector(NoteWindowController.deleteNote(_:))))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Undo", Selector(("undo:")), "z"))
        menu.addItem(item("Redo", Selector(("redo:")), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Paste and Match Style", #selector(NSTextView.pasteAsPlainText(_:)), "v", [.command, .option, .shift]))
        menu.addItem(item("Delete", #selector(NSText.delete(_:))))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        menu.addItem(.separator())

        let find = NSMenu(title: "Find")
        let actions: [(String, String, NSEvent.ModifierFlags, NSTextFinder.Action)] = [
            ("Find…", "f", .command, .showFindInterface),
            ("Find and Replace…", "f", [.command, .option], .showReplaceInterface),
            ("Find Next", "g", .command, .nextMatch),
            ("Find Previous", "g", [.command, .shift], .previousMatch),
            ("Use Selection for Find", "e", .command, .setSearchString),
        ]
        for (title, key, modifiers, action) in actions {
            find.addItem(item(title, #selector(NSTextView.performTextFinderAction(_:)), key, modifiers, tag: action.rawValue))
        }
        menu.addItem(submenu(find))

        let spelling = NSMenu(title: "Spelling and Grammar")
        spelling.addItem(item("Show Spelling and Grammar", #selector(NSText.showGuessPanel(_:)), ":"))
        spelling.addItem(item("Check Document Now", #selector(NSText.checkSpelling(_:)), ";"))
        spelling.addItem(item("Check Spelling While Typing", #selector(NSTextView.toggleContinuousSpellChecking(_:))))
        menu.addItem(submenu(spelling))
        return menu
    }

    private static func formatMenu() -> NSMenu {
        let menu = NSMenu(title: "Format")
        menu.addItem(item("Bold", #selector(NoteTextView.toggleBold(_:)), "b"))
        menu.addItem(item("Italic", #selector(NoteTextView.toggleItalic(_:)), "i"))
        menu.addItem(item("Strikethrough", #selector(NoteTextView.toggleStrikethrough(_:)), "x", [.command, .shift]))
        menu.addItem(item("Highlight", #selector(NoteTextView.toggleHighlight(_:)), "h", [.command, .shift]))
        menu.addItem(item("Inline Code", #selector(NoteTextView.toggleInlineCode(_:)), "c", [.command, .option]))
        menu.addItem(item("Link", #selector(NoteTextView.insertLink(_:)), "l"))
        menu.addItem(.separator())
        menu.addItem(item("Heading 1", #selector(NoteTextView.setHeading(_:)), "1", tag: 1))
        menu.addItem(item("Heading 2", #selector(NoteTextView.setHeading(_:)), "2", tag: 2))
        menu.addItem(item("Heading 3", #selector(NoteTextView.setHeading(_:)), "3", tag: 3))
        menu.addItem(item("Body", #selector(NoteTextView.setHeading(_:)), "0", tag: 0))
        menu.addItem(.separator())
        menu.addItem(item("Bulleted List", #selector(NoteTextView.toggleBulletList(_:)), "8", [.command, .shift]))
        menu.addItem(item("Numbered List", #selector(NoteTextView.toggleNumberedList(_:)), "7", [.command, .shift]))
        menu.addItem(item("Checklist", #selector(NoteTextView.toggleChecklist(_:)), "l", [.command, .shift]))
        menu.addItem(item("Check or Uncheck", #selector(NoteTextView.toggleCheckbox(_:)), "u", [.command, .shift]))
        menu.addItem(item("Quote", #selector(NoteTextView.toggleQuote(_:)), "'"))
        menu.addItem(item("Code Block", #selector(NoteTextView.insertCodeBlock(_:)), "c", [.command, .option, .shift]))
        menu.addItem(item("Divider", #selector(NoteTextView.insertDivider(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Bigger", #selector(NoteWindowController.makeTextBigger(_:)), "="))
        menu.addItem(item("Smaller", #selector(NoteWindowController.makeTextSmaller(_:)), "-"))
        return menu
    }

    private static func noteMenu() -> NSMenu {
        let menu = NSMenu(title: "Note")
        menu.addItem(item("Commands…", #selector(NoteWindowController.showCommandPalette(_:)), "k"))
        menu.addItem(.separator())
        menu.addItem(item("Previous Note", #selector(NoteWindowController.previousNote(_:)), String(UnicodeScalar(NSLeftArrowFunctionKey)!), [.command, .option]))
        menu.addItem(item("Next Note", #selector(NoteWindowController.nextNote(_:)), String(UnicodeScalar(NSRightArrowFunctionKey)!), [.command, .option]))
        menu.addItem(item("Go Back", #selector(NoteWindowController.goBack(_:)), "["))
        menu.addItem(item("Go Forward", #selector(NoteWindowController.goForward(_:)), "]"))
        menu.addItem(.separator())
        menu.addItem(item("Pin on Top", #selector(NoteWindowController.togglePin(_:)), "p", [.command, .shift]))
        menu.addItem(item("Focus Mode", #selector(NoteWindowController.toggleFocusMode(_:)), "\r"))
        menu.addItem(.separator())

        let style = NSMenu(title: "Style")
        for (index, value) in NoteStyle.allCases.enumerated() {
            style.addItem(item(value.title, #selector(NoteWindowController.setNoteStyle(_:)), tag: index))
        }
        menu.addItem(submenu(style))

        let tint = NSMenu(title: "Tint")
        for (index, value) in NoteTint.allCases.enumerated() {
            let entry = item(value.title, #selector(NoteWindowController.setNoteTint(_:)), tag: index)
            entry.image = value.menuImage
            tint.addItem(entry)
        }
        menu.addItem(submenu(tint))

        let appearance = NSMenu(title: "Appearance")
        for (index, value) in NoteAppearance.allCases.enumerated() {
            appearance.addItem(item(value.title, #selector(NoteWindowController.setNoteAppearance(_:)), tag: index))
        }
        menu.addItem(submenu(appearance))
        menu.addItem(.separator())
        menu.addItem(item("Rename…", #selector(NoteWindowController.renameNote(_:))))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(.separator())
        menu.addItem(item("Show All Notes", #selector(AppDelegate.showAllNotes(_:))))
        menu.addItem(item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))))
        return menu
    }
}
