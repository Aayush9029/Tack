import FoundationModels

@Generable
struct SuggestedTitle {
    @Guide(description: "Two to five words, in title case, with no quotes and no final period.")
    var title: String
}
