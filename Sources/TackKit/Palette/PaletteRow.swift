import CasePaths

@CasePathable
public enum PaletteRow: Identifiable, Equatable, Sendable {
    case item(PaletteItem)
    case note(NoteHit)

    public var id: String {
        switch self {
        case let .item(item): "item:\(item.id)"
        case let .note(hit): "note:\(hit.id)"
        }
    }

    public var isEnabled: Bool {
        switch self {
        case let .item(item): item.isEnabled
        case .note: true
        }
    }

    public var group: Int {
        switch self {
        case let .item(item): item.group
        case .note: 100
        }
    }
}
