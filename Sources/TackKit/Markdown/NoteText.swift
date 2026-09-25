import Tagged
import Foundation

public enum NoteText {
    public static let untitled = "New Note"

    public static func title(from body: some StringProtocol) -> String {
        for line in body.split(separator: "\n", maxSplits: 12, omittingEmptySubsequences: true) {
            let text = strip(line)
            if !text.isEmpty { return String(text.prefix(80)) }
        }
        return untitled
    }

    /// Everything after the line that names the note, flattened to one line.
    public static func preview(from body: some StringProtocol) -> String {
        var parts: [String] = []
        var length = 0
        var hasSkippedTitle = false
        for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let text = strip(line)
            guard !text.isEmpty else { continue }
            guard hasSkippedTitle else {
                hasSkippedTitle = true
                continue
            }
            parts.append(text)
            length += text.count + 1
            if length >= 140 { break }
        }
        return parts.joined(separator: " ")
    }

    static func strip(_ line: some StringProtocol) -> String {
        var text = Substring(line).drop { $0 == " " || $0 == "\t" }
        for prefix in ["- [ ] ", "- [x] ", "- [X] ", "* [ ] ", "* [x] "] where text.hasPrefix(prefix) {
            text = text.dropFirst(prefix.count)
        }
        while let first = text.first, "#>".contains(first) { text = text.dropFirst() }
        if text.hasPrefix("- ") || text.hasPrefix("* ") || text.hasPrefix("+ ") { text = text.dropFirst(2) }
        if let dot = text.firstIndex(of: "."), text[..<dot].allSatisfy(\.isNumber), !text[..<dot].isEmpty {
            text = text[text.index(after: dot)...]
        }
        if text.hasPrefix("```") || text.allSatisfy({ "-*_ ".contains($0) }) { return "" }
        return text
            .replacingOccurrences(of: #"!\[[^\]]*\]\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "~~", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
