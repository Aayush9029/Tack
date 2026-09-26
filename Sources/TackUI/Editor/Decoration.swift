import AppKit

/// Stored as an attribute on the whole paragraph. Equality lets attribute runs coalesce.
final class Decoration: NSObject {
    enum Kind: Equatable {
        case bullet(dash: Int)
        case task(isDone: Bool, box: NSRange)
        case quote
        case codeTop
        case code
        case codeBottom
        case rule
        case media(URL, height: CGFloat)
    }

    let kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? Decoration)?.kind == kind
    }

    override var hash: Int {
        switch kind {
        case let .bullet(dash): dash
        case let .task(isDone, box): box.location &* 31 &+ (isDone ? 1 : 0)
        case .quote: 2
        case .codeTop: 3
        case .code: 4
        case .codeBottom: 5
        case .rule: 7
        case let .media(url, height): url.hashValue ^ Int(height)
        }
    }
}
