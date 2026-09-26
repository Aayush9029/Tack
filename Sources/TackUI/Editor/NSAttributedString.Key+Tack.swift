import AppKit

extension NSAttributedString.Key {
    /// What the layout fragment draws for a paragraph: checkbox, bullet, code box, quote bar, rule, media.
    static let tackDecoration = NSAttributedString.Key("tack.decoration")
    /// Whether a code fence is still open after the paragraph, carried across edits.
    static let tackEndsInCode = NSAttributedString.Key("tack.endsInCode")
    /// A link's destination, opened with Command-click.
    static let tackLink = NSAttributedString.Key("tack.link")
}
