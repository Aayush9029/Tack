import Testing
@testable import TackKit

@Suite struct ListContinuationTests {
    @Test func continuesEachKindOfList() {
        #expect(ListContinuation.after("- milk") == .continueWith("- "))
        #expect(ListContinuation.after("  * [x] eggs") == .continueWith("  * [ ] "))
        #expect(ListContinuation.after("9. nine") == .continueWith("10. "))
        #expect(ListContinuation.after("3) three") == .continueWith("4) "))
        #expect(ListContinuation.after("> quote") == .continueWith("> "))
    }

    @Test func emptyItemEndsTheList() {
        #expect(ListContinuation.after("- ") == .endList)
        #expect(ListContinuation.after("- [ ] ") == .endList)
        #expect(ListContinuation.after("2. ") == .endList)
    }

    @Test func bodyTextDoesNothing() {
        #expect(ListContinuation.after("Just text") == .none)
    }
}
