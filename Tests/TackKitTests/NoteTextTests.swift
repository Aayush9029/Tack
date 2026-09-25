import Testing
@testable import TackKit

@Suite struct NoteTextTests {
    @Test func titleIsTheFirstLineWithoutMarkdown() {
        #expect(NoteText.title(from: "\n\n# **Plan** for `Monday`\nmore") == "Plan for Monday")
        #expect(NoteText.title(from: "- [ ] buy milk") == "buy milk")
        #expect(NoteText.title(from: "  \n") == NoteText.untitled)
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
