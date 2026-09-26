import Foundation
import Testing
@testable import TackKit

@Suite struct TackLinkTests {
    @Test func parsesEveryRoute() {
        #expect(TackLink(URL(string: "tack://new?text=Buy%20milk&style=classic&tint=pink")!) == .new(text: "Buy milk", style: .classic, tint: .pink))
        #expect(TackLink(URL(string: "tack://new")!) == .new(text: "", style: nil, tint: nil))
        #expect(TackLink(URL(string: "tack://open?note=groceries")!) == .open(note: "groceries"))
        #expect(TackLink(URL(string: "tack://append?id=1f2e&text=-%20%5B%20%5D%20eggs")!) == .append(note: "1f2e", text: "- [ ] eggs"))
        #expect(TackLink(URL(string: "tack://search?q=trip")!) == .all(query: "trip"))
    }

    @Test func rejectsWhatItCannotDo() {
        #expect(TackLink(URL(string: "tack://open")!) == nil)
        #expect(TackLink(URL(string: "tack://delete?note=a")!) == nil)
        #expect(TackLink(URL(string: "https://open?note=a")!) == nil)
    }
}
