import AppKit
import TackKit

/// Styles Markdown in place as it is typed. An edit restyles only its own
/// paragraphs, then continues forward only while it changes whether a code fence
/// is open, so a keystroke costs one paragraph however long the note is.
@MainActor
final class MarkdownStyler: NSObject, NSTextStorageDelegate {
    var theme: EditorTheme
    /// The text column's width, which sizes image and video previews.
    var columnWidth: CGFloat = 320
    var maxMediaHeight: CGFloat = 260

    init(theme: EditorTheme) {
        self.theme = theme
    }

    /// Characters edited since the last restyle. Styling inside the edit itself would
    /// widen the range TextKit 2 remaps the selection through, and the insertion
    /// point would jump to its end, so edits are only recorded here.
    private var pending: NSRange?

    nonisolated func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters) else { return }
        MainActor.assumeIsolated {
            pending = pending.map { previous in
                let shifted = NSRange(location: previous.location, length: max(0, previous.length + delta))
                return NSUnionRange(shifted, editedRange)
            } ?? editedRange
        }
    }

    /// Styles what the last edits touched, as a separate attribute-only change.
    func restylePending(in storage: NSTextStorage) {
        guard let range = pending else { return }
        pending = nil
        let clamped = NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
        let location = min(range.location, storage.length)
        let state = Log.signposter.beginInterval("Restyle edit")
        defer { Log.signposter.endInterval("Restyle edit", state) }
        storage.beginEditing()
        restyle(storage, around: clamped.length > 0 ? clamped : NSRange(location: location, length: 0))
        storage.endEditing()
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: theme.bodyFont,
            .foregroundColor: EditorTheme.text,
            .paragraphStyle: paragraphStyle(firstLine: theme.hang, head: theme.hang),
        ]
    }

    func styleAll(_ storage: NSTextStorage) {
        pending = nil
        let state = Log.signposter.beginInterval("Style note", "\(storage.length) characters")
        defer { Log.signposter.endInterval("Style note", state) }
        storage.beginEditing()
        restyle(storage, paragraphs: NSRange(location: 0, length: storage.length), stopsEarly: false)
        storage.endEditing()
    }

    /// Paragraphs that preview this file, after it finishes loading or the column resizes.
    func restyleMedia(in storage: NSTextStorage, matching url: URL? = nil) {
        var ranges: [NSRange] = []
        storage.enumerateAttribute(.tackDecoration, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let decoration = value as? Decoration, case let .media(mediaURL, _) = decoration.kind else { return }
            if url == nil || url == mediaURL { ranges.append(range) }
        }
        let string = storage.string as NSString
        guard !ranges.isEmpty || url != nil else { return }
        storage.beginEditing()
        for range in ranges {
            restyle(storage, paragraphs: string.paragraphRange(for: range), stopsEarly: true)
        }
        if let url, ranges.isEmpty {
            // Media that failed or had no decoration yet: find its source text instead.
            let source = MediaSource.source(for: url)
            var searchRange = NSRange(location: 0, length: string.length)
            while true {
                let found = string.range(of: source, range: searchRange)
                guard found.location != NSNotFound else { break }
                restyle(storage, paragraphs: string.paragraphRange(for: found), stopsEarly: true)
                searchRange = NSRange(location: NSMaxRange(found), length: string.length - NSMaxRange(found))
            }
        }
        storage.endEditing()
    }

    private func restyle(_ storage: NSTextStorage, around range: NSRange) {
        let string = storage.string as NSString
        restyle(storage, paragraphs: string.paragraphRange(for: range), stopsEarly: true)
    }

    private func restyle(_ storage: NSTextStorage, paragraphs: NSRange, stopsEarly: Bool) {
        let string = storage.string as NSString
        let length = string.length
        guard length > 0 else { return }
        var location = paragraphs.location
        let end = NSMaxRange(paragraphs)
        var inCode = location > 0 && (storage.attribute(.tackEndsInCode, at: location - 1, effectiveRange: nil) as? Bool ?? false)
        while location < length {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            let previous = storage.attribute(.tackEndsInCode, at: paragraph.location, effectiveRange: nil) as? Bool
            inCode = style(paragraph, in: storage, string: string, startsInCode: inCode)
            location = NSMaxRange(paragraph)
            if stopsEarly, location >= end, previous == inCode { break }
        }
    }

    // MARK: One paragraph

    private func style(_ paragraph: NSRange, in storage: NSTextStorage, string: NSString, startsInCode: Bool) -> Bool {
        var content = paragraph
        if content.length > 0, string.character(at: NSMaxRange(content) - 1) == 0x0A {
            content.length -= 1
        }
        let line = string.substring(with: content) as NSString
        let parsed = MarkdownParser.parse(line, startsInCode: startsInCode)

        var attributes = baseAttributes
        attributes[.tackEndsInCode] = parsed.endsInCode
        storage.setAttributes(attributes, range: paragraph)

        func absolute(_ range: NSRange) -> NSRange {
            NSRange(location: content.location + range.location, length: range.length)
        }
        func set(_ key: NSAttributedString.Key, _ value: Any, _ range: NSRange) {
            guard range.length > 0 else { return }
            storage.addAttribute(key, value: value, range: absolute(range))
        }
        func decorate(_ kind: Decoration.Kind) {
            storage.addAttribute(.tackDecoration, value: Decoration(kind), range: paragraph)
        }
        /// Wrapped lines of a list item line up under its text, measured with the fonts just set.
        func indent(prefixLength: Int) {
            let prefix = storage.attributedSubstring(from: NSRange(location: content.location, length: min(prefixLength, line.length)))
            let width = ceil(prefix.size().width)
            storage.addAttribute(.paragraphStyle, value: paragraphStyle(firstLine: theme.hang, head: theme.hang + width), range: paragraph)
        }

        switch parsed.block {
        case .body:
            break

        case let .heading(level, marker):
            let font = theme.font(bold: true, italic: false, scale: theme.headingScale(level))
            set(.font, font, NSRange(location: 0, length: line.length))
            let markerWidth = theme.width(of: line.substring(with: marker), font: font)
            let style = paragraphStyle(firstLine: max(0, theme.hang - markerWidth), head: theme.hang)
            style.paragraphSpacingBefore = theme.isFocusMode ? 0 : (theme.size * (level <= 2 ? 0.5 : 0.3)).rounded()
            storage.addAttribute(.paragraphStyle, value: style, range: paragraph)

        case let .bullet(_, marker):
            set(.font, theme.bulletFont, marker)
            set(.foregroundColor, NSColor.clear, NSRange(location: marker.location, length: 1))
            indent(prefixLength: NSMaxRange(marker))
            decorate(.bullet(dash: marker.location))

        case let .ordered(_, marker):
            set(.foregroundColor, EditorTheme.secondary, marker)
            indent(prefixLength: NSMaxRange(marker))

        case let .task(_, isDone, marker, box):
            // The dash shrinks away and the box is monospaced, so `[x]` and `[ ]` are
            // one width and every checkbox sits at the margin.
            set(.font, theme.hiddenFont, marker)
            set(.font, theme.markerFont, NSRange(location: box.location, length: min(NSMaxRange(box) + 1, line.length) - box.location))
            set(.foregroundColor, NSColor.clear, NSRange(location: marker.location, length: NSMaxRange(box) - marker.location))
            indent(prefixLength: min(NSMaxRange(box) + 1, line.length))
            decorate(.task(isDone: isDone, box: box))
            if isDone {
                let text = NSRange(location: NSMaxRange(box), length: line.length - NSMaxRange(box))
                set(.foregroundColor, EditorTheme.secondary, text)
                set(.strikethroughStyle, NSUnderlineStyle.single.rawValue, NSRange(location: min(NSMaxRange(box) + 1, line.length), length: max(0, line.length - NSMaxRange(box) - 1)))
                set(.strikethroughColor, EditorTheme.syntax, text)
            }

        case let .quote(marker):
            let chevron = line.range(of: ">")
            if chevron.location != NSNotFound { set(.foregroundColor, NSColor.clear, chevron) }
            set(.foregroundColor, EditorTheme.secondary, NSRange(location: NSMaxRange(marker), length: line.length - NSMaxRange(marker)))
            indent(prefixLength: NSMaxRange(marker))
            decorate(.quote)

        case .fence:
            set(.font, theme.codeFont, NSRange(location: 0, length: line.length))
            decorate(startsInCode ? .codeBottom : .codeTop)

        case .code:
            set(.font, theme.codeFont, NSRange(location: 0, length: line.length))
            decorate(.code)

        case .rule:
            set(.foregroundColor, NSColor.clear, NSRange(location: 0, length: line.length))
            decorate(.rule)

        case let .image(source):
            set(.font, theme.captionFont, NSRange(location: 0, length: line.length))
            if let url = MediaSource.url(for: source), !MediaCache.shared.hasFailed(url) {
                let cache = MediaCache.shared
                let media = cache.cached(url)
                if media == nil { cache.load(url) }
                let aspect = media?.aspect ?? 16.0 / 9.0
                let naturalWidth = media.map { $0.pixelSize.width / 2 } ?? columnWidth
                let width = min(columnWidth, naturalWidth)
                let height = min(maxMediaHeight, (width / aspect).rounded())
                let style = paragraphStyle(firstLine: theme.hang, head: theme.hang)
                style.paragraphSpacing = height + 12
                storage.addAttribute(.paragraphStyle, value: style, range: paragraph)
                decorate(.media(url, height: height))
            }
        }

        applySpans(parsed.spans, in: storage, absolute: absolute)
        return parsed.endsInCode
    }

    private func applySpans(
        _ spans: [MarkdownSpan],
        in storage: NSTextStorage,
        absolute: (NSRange) -> NSRange
    ) {
        var syntax: [NSRange] = []
        for span in spans where span.range.length > 0 {
            let range = absolute(span.range)
            switch span.kind {
            case .bold, .italic:
                let isBold = span.kind == .bold
                storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                    guard let font = value as? NSFont else { return }
                    let converted = isBold ? theme.converting(font, bold: true) : theme.converting(font, italic: true)
                    storage.addAttribute(.font, value: converted, range: subrange)
                }
            case .strikethrough:
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                storage.addAttribute(.foregroundColor, value: EditorTheme.secondary, range: range)
            case .highlight:
                storage.addAttribute(.backgroundColor, value: EditorTheme.highlight, range: range)
            case .code:
                storage.addAttribute(.font, value: theme.codeFont, range: range)
                storage.addAttribute(.backgroundColor, value: EditorTheme.codeBackground, range: range)
            case let .link(destination):
                storage.addAttribute(.foregroundColor, value: EditorTheme.link, range: range)
                storage.addAttribute(.tackLink, value: destination, range: range)
            case .syntax:
                syntax.append(range)
            }
        }
        for range in syntax {
            storage.enumerateAttribute(.foregroundColor, in: range) { value, subrange, _ in
                guard (value as? NSColor) != NSColor.clear else { return }
                storage.addAttribute(.foregroundColor, value: EditorTheme.syntax, range: subrange)
            }
        }
    }

    private func paragraphStyle(firstLine: CGFloat, head: CGFloat) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = theme.lineHeightMultiple
        style.firstLineHeadIndent = firstLine
        style.headIndent = head
        style.paragraphSpacing = theme.isFocusMode ? 0 : 1
        style.defaultTabInterval = theme.width(of: "    ", font: theme.bodyFont)
        style.tabStops = []
        return style
    }
}
