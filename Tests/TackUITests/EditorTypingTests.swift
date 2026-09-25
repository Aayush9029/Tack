import AppKit
import Testing
@testable import TackKit
@testable import TackUI

/// Types into the real editor, off screen, the way a keyboard does, and checks
/// the text, where the insertion point ends up, and what the styler drew.
@MainActor
@Suite(.serialized)
struct EditorTypingTests {
    @MainActor
    private final class Harness {
        let window: NSWindow
        let textView: NoteTextView
        let styler: MarkdownStyler

        init(focus: Bool) {
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.borderless], backing: .buffered, defer: false)
            textView = NoteTextView.make()
            styler = MarkdownStyler(theme: EditorTheme(family: focus ? .duo : .system, size: 15, isFocusMode: focus))
            let scrollView = NSScrollView(frame: window.contentView!.bounds)
            scrollView.documentView = textView
            textView.frame = scrollView.contentView.bounds
            window.contentView = scrollView
            textView.textStorage?.delegate = styler
            let styler = styler
            textView.onRestyle = { styler.restylePending(in: $0) }
            textView.typingAttributes = styler.baseAttributes
            textView.hang = styler.theme.hang
            textView.isFocusMode = focus
            window.makeFirstResponder(textView)
        }

        func type(_ text: String) async {
            for character in text {
                if character == "\n" {
                    textView.insertNewline(nil)
                } else {
                    textView.insertText(String(character), replacementRange: textView.selectedRange())
                }
                await settle()
            }
        }

        func key(_ selector: Selector) async {
            textView.doCommand(by: selector)
            await settle()
        }

        func settle() async {
            try? await Task.sleep(for: .milliseconds(2))
        }

        var text: String { textView.string }
        var caret: Int { textView.selectedRange().location }

        func font(at index: Int) -> NSFont? {
            textView.textStorage?.attribute(.font, at: index, effectiveRange: nil) as? NSFont
        }
    }

    @Test(arguments: [false, true])
    func typingKeepsOrderAndCaret(focus: Bool) async {
        let editor = Harness(focus: focus)
        await editor.type("abc\n# Title\nbody")
        #expect(editor.text == "abc\n# Title\nbody")
        #expect(editor.caret == (editor.text as NSString).length)
    }

    @Test(arguments: [false, true])
    func editingHeadingsInPlace(focus: Bool) async {
        let editor = Harness(focus: focus)
        await editor.type("# Focus heading\nBody under it\n## Second")
        await editor.key(#selector(NSResponder.moveLeft(_:)))
        await editor.key(#selector(NSResponder.moveLeft(_:)))
        await editor.key(#selector(NSResponder.deleteBackward(_:)))
        await editor.type("x")
        await editor.key(#selector(NSResponder.moveToBeginningOfDocument(_:)))
        await editor.type("### ")
        #expect(editor.text == "### # Focus heading\nBody under it\n## Secxnd")
        #expect(editor.caret == 4)
        #expect(editor.font(at: 6)?.fontDescriptor.symbolicTraits.contains(.bold) == true)
        #expect(editor.font(at: 22)?.fontDescriptor.symbolicTraits.contains(.bold) == false)
    }

    @Test func listsContinueAndEnd() async {
        let editor = Harness(focus: false)
        await editor.type("- [ ] milk\neggs\n\nafter")
        #expect(editor.text == "- [ ] milk\n- [ ] eggs\nafter")
    }

    @Test func codeFenceStylesFollowingLines() async {
        let editor = Harness(focus: false)
        await editor.type("```\n# not a heading\n```\n# heading")
        let code = editor.font(at: 6)
        let heading = editor.font(at: (editor.text as NSString).length - 1)
        #expect(code?.isFixedPitch == true)
        #expect(heading?.fontDescriptor.symbolicTraits.contains(.bold) == true)
    }

    @Test func checkboxToggleIsUndoable() async {
        let editor = Harness(focus: false)
        await editor.type("- [ ] milk")
        editor.textView.toggleTask(atParagraph: 0)
        #expect(editor.text == "- [x] milk")
        editor.textView.undoManager?.undo()
        #expect(editor.text == "- [ ] milk")
    }
}
