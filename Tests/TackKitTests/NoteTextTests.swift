import Testing
@testable import TackKit

@Suite struct NoteTextTests {
    @Test func titleIsTheFirstLineWithoutMarkdown() {
        #expect(NoteText.title(from: "\n\n# **Plan** for `Monday`\nmore") == "Plan for Monday")
        #expect(NoteText.title(from: "- [ ] buy milk") == "buy milk")
        #expect(NoteText.title(from: "  \n") == NoteText.untitled)
    }

    @Test func whenToInferATitle() {
        #expect(!NoteText.wantsInferredTitle("# Plan\nmore"))
        #expect(!NoteText.wantsInferredTitle("Groceries\n- milk"))
        #expect(NoteText.wantsInferredTitle("- [ ] milk\n- [ ] eggs"))
        #expect(NoteText.wantsInferredTitle("fix 1, 3 (do 200) and also increase rate limits for that endpoint"))
        #expect(NoteText.displayTitle(custom: "", body: "- [ ] milk", inferred: "Groceries") == "Groceries")
        #expect(NoteText.displayTitle(custom: "Mine", body: "- [ ] milk", inferred: "Groceries") == "Mine")
    }

    @Test func previewSkipsTheTitle() {
        #expect(NoteText.preview(from: "Title\n- one\n- two") == "one two")
        #expect(NoteText.preview(from: "Trip\n![](attachments/a.png)\nSee [the map](https://x.y)") == "See the map")
    }

    @Test func ftsQueryPrefixesEveryWord() {
        #expect(NoteSearch.ftsQuery("notar mil") == #""notar"* "mil"*"#)
        #expect(NoteSearch.ftsQuery("  !! ") == nil)
    }

    @Test func plainTextExport() {
        let text = NoteExport.plainText("# Title\n\n- [x] done\n- [ ] todo\n\n**bold** `code`")
        #expect(text == "Title\n☑ done\n☐ todo\nbold code")
    }
}
