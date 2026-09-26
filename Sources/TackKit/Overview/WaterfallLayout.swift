/// Cards in columns, each card placed in the shortest column so far, so a grid of
/// uneven notes stays level at the bottom.
public enum WaterfallLayout {
    public static func columns(_ cards: [NoteCard], count: Int) -> [[NoteCard]] {
        let count = max(1, count)
        var columns = Array(repeating: [NoteCard](), count: count)
        var heights = Array(repeating: 0, count: count)
        for card in cards {
            let shortest = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            columns[shortest].append(card)
            heights[shortest] += card.weight
        }
        return columns
    }
}
