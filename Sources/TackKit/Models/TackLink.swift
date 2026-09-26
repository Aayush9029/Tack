import CasePaths
import Foundation

/// `tack://` links, so other apps, Shortcuts and Raycast scripts can drive Tack.
@CasePathable
public enum TackLink: Equatable, Sendable {
    /// `tack://new?text=…&style=classic&tint=pink`
    case new(text: String, style: NoteStyle?, tint: NoteTint?)
    /// `tack://open?note=<id, id prefix or title>`
    case open(note: String)
    /// `tack://append?note=<reference>&text=…`
    case append(note: String, text: String)
    /// `tack://all?q=…`, the grid, optionally searched
    case all(query: String)

    public init?(_ url: URL) {
        guard url.scheme?.lowercased() == "tack",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let items = Dictionary((components.queryItems ?? []).map { ($0.name.lowercased(), $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        switch (components.host ?? components.path).lowercased() {
        case "new":
            self = .new(text: items["text"] ?? "", style: items["style"].flatMap(NoteStyle.init), tint: items["tint"].flatMap(NoteTint.init))
        case "open":
            guard let note = items["note"] ?? items["id"], !note.isEmpty else { return nil }
            self = .open(note: note)
        case "append":
            guard let note = items["note"] ?? items["id"], let text = items["text"], !note.isEmpty else { return nil }
            self = .append(note: note, text: text)
        case "all", "grid", "search":
            self = .all(query: items["q"] ?? items["query"] ?? "")
        default:
            return nil
        }
    }
}
