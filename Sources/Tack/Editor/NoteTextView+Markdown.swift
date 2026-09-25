import AppKit
import TackKit

extension NoteTextView {
    private var nsString: NSString { string as NSString }

    private func lineContent(_ paragraph: NSRange) -> NSRange {
        var content = paragraph
        if content.length > 0, nsString.character(at: NSMaxRange(content) - 1) == 0x0A { content.length -= 1 }
        return content
    }

    private func selectedParagraphs() -> [NSRange] {
        let whole = nsString.paragraphRange(for: selectedRange())
        var ranges: [NSRange] = []
        nsString.enumerateSubstrings(in: whole, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            ranges.append(range)
        }
        if ranges.isEmpty { ranges.append(NSRange(location: whole.location, length: 0)) }
        return ranges
    }

    // MARK: Return, Tab

    override func insertNewline(_ sender: Any?) {
        let selection = selectedRange()
        let paragraph = lineContent(nsString.paragraphRange(for: selection))
        guard selection.length == 0, selection.location >= paragraph.location else {
            super.insertNewline(sender)
            return
        }
        let line = nsString.substring(with: paragraph)
        let isInCode = paragraph.location > 0 && (textStorage?.attribute(.tackEndsInCode, at: paragraph.location - 1, effectiveRange: nil) as? Bool ?? false)
        if isInCode, !line.hasPrefix("```") {
            let indent = line.prefix { $0 == " " || $0 == "\t" }
            insertText("\n" + indent, replacementRange: selection)
            return
        }
        switch ListContinuation.after(line) {
        case let .continueWith(prefix):
            let prefixEnd = paragraph.location + (prefix as NSString).length
            guard selection.location >= min(prefixEnd, NSMaxRange(paragraph)) else {
                super.insertNewline(sender)
                return
            }
            insertText("\n" + prefix, replacementRange: selection)
        case .endList:
            replace(paragraph, with: "", selecting: NSRange(location: paragraph.location, length: 0))
        case .none:
            super.insertNewline(sender)
        }
    }

    override func insertTab(_ sender: Any?) {
        guard isListSelection() else {
            super.insertTab(sender)
            return
        }
        shiftSelectedLines(by: 1)
    }

    override func insertBacktab(_ sender: Any?) {
        guard isListSelection() else {
            super.insertBacktab(sender)
            return
        }
        shiftSelectedLines(by: -1)
    }

    private func isListSelection() -> Bool {
        selectedParagraphs().contains { paragraph in
            switch MarkdownParser.parse(nsString.substring(with: lineContent(paragraph)), startsInCode: false).block {
            case .bullet, .ordered, .task: true
            default: false
            }
        }
    }

    private func shiftSelectedLines(by direction: Int) {
        let selection = selectedRange()
        var delta = 0
        var firstDelta = 0
        undoManager?.beginUndoGrouping()
        for (index, paragraph) in selectedParagraphs().enumerated() {
            let range = NSRange(location: paragraph.location + delta, length: paragraph.length)
            let line = nsString.substring(with: range)
            if direction > 0 {
                replace(NSRange(location: range.location, length: 0), with: "  ")
                delta += 2
                if index == 0 { firstDelta = 2 }
            } else {
                let removable = line.hasPrefix("\t") ? 1 : min(2, line.prefix { $0 == " " }.count)
                guard removable > 0 else { continue }
                replace(NSRange(location: range.location, length: removable), with: "")
                delta -= removable
                if index == 0 { firstDelta = -removable }
            }
        }
        undoManager?.endUndoGrouping()
        let location = max(0, selection.location + firstDelta)
        setSelectedRange(NSRange(location: location, length: max(0, selection.length + delta - firstDelta)))
    }

    // MARK: Inline

    @objc func toggleBold(_ sender: Any?) { toggleWrap("**") }
    @objc func toggleItalic(_ sender: Any?) { toggleWrap("*") }
    @objc func toggleStrikethrough(_ sender: Any?) { toggleWrap("~~") }
    @objc func toggleHighlight(_ sender: Any?) { toggleWrap("==") }
    @objc func toggleInlineCode(_ sender: Any?) { toggleWrap("`") }

    private func toggleWrap(_ marker: String) {
        let selection = selectedRange()
        let length = (marker as NSString).length
        let selected = nsString.substring(with: selection)
        if selection.length >= length * 2, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            replace(selection, with: inner, selecting: NSRange(location: selection.location, length: (inner as NSString).length))
            return
        }
        let before = NSRange(location: selection.location - length, length: length)
        let after = NSRange(location: NSMaxRange(selection), length: length)
        if before.location >= 0, NSMaxRange(after) <= nsString.length,
           nsString.substring(with: before) == marker, nsString.substring(with: after) == marker {
            let outer = NSRange(location: before.location, length: selection.length + length * 2)
            replace(outer, with: selected, selecting: NSRange(location: before.location, length: selection.length))
            return
        }
        replace(selection, with: marker + selected + marker, selecting: NSRange(location: selection.location + length, length: selection.length))
    }

    @objc func insertLink(_ sender: Any?) {
        let selection = selectedRange()
        let selected = nsString.substring(with: selection)
        let pasted = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if selected.contains("://") {
            replace(selection, with: "[](\(selected))", selecting: NSRange(location: selection.location + 1, length: 0))
        } else if let pasted, pasted.hasPrefix("http"), !pasted.contains(" ") {
            let text = "[\(selected)](\(pasted))"
            replace(selection, with: text, selecting: selected.isEmpty
                ? NSRange(location: selection.location + 1, length: 0)
                : NSRange(location: selection.location + (text as NSString).length, length: 0))
        } else {
            let text = "[\(selected)]()"
            replace(selection, with: text, selecting: NSRange(location: selection.location + (text as NSString).length - 1, length: 0))
        }
    }

    // MARK: Blocks

    @objc func setHeading(_ sender: Any?) {
        let level = (sender as? NSMenuItem)?.tag ?? 0
        setLinePrefix { block, _ in
            if case .heading(level, _) = block, level > 0 { return "" }
            return level == 0 ? "" : String(repeating: "#", count: level) + " "
        }
    }

    @objc func toggleBulletList(_ sender: Any?) {
        let isAll = selectedBlocks().allSatisfy { if case .bullet = $0 { true } else { false } }
        setLinePrefix { _, _ in isAll ? "" : "- " }
    }

    @objc func toggleNumberedList(_ sender: Any?) {
        let isAll = selectedBlocks().allSatisfy { if case .ordered = $0 { true } else { false } }
        setLinePrefix { _, index in isAll ? "" : "\(index + 1). " }
    }

    @objc func toggleChecklist(_ sender: Any?) {
        let isAll = selectedBlocks().allSatisfy { if case .task = $0 { true } else { false } }
        setLinePrefix { _, _ in isAll ? "" : "- [ ] " }
    }

    @objc func toggleQuote(_ sender: Any?) {
        let isAll = selectedBlocks().allSatisfy { if case .quote = $0 { true } else { false } }
        setLinePrefix { _, _ in isAll ? "" : "> " }
    }

    @objc func toggleCheckbox(_ sender: Any?) {
        let blocks = selectedBlocks()
        guard blocks.allSatisfy({ if case .task = $0 { true } else { false } }) else {
            toggleChecklist(sender)
            return
        }
        let allDone = blocks.allSatisfy { if case .task(_, true, _, _) = $0 { true } else { false } }
        let selection = selectedRange()
        undoManager?.beginUndoGrouping()
        for paragraph in selectedParagraphs() {
            let content = lineContent(paragraph)
            guard case let .task(_, isDone, _, box) = MarkdownParser.parse(nsString.substring(with: content), startsInCode: false).block,
                  isDone == allDone
            else { continue }
            replace(NSRange(location: content.location + box.location + 1, length: 1), with: allDone ? " " : "x")
        }
        undoManager?.endUndoGrouping()
        setSelectedRange(selection)
    }

    @objc func insertCodeBlock(_ sender: Any?) {
        let selection = selectedRange()
        if selection.length == 0 {
            let atLineStart = selection.location == 0 || nsString.character(at: selection.location - 1) == 0x0A
            let lead = atLineStart ? "" : "\n"
            replace(selection, with: "\(lead)```\n\n```", selecting: NSRange(location: selection.location + (lead as NSString).length + 4, length: 0))
        } else {
            let whole = lineContent(nsString.paragraphRange(for: selection))
            let body = nsString.substring(with: whole)
            replace(whole, with: "```\n\(body)\n```", selecting: NSRange(location: whole.location + 4, length: (body as NSString).length))
        }
    }

    @objc func insertDivider(_ sender: Any?) {
        let selection = selectedRange()
        let atLineStart = selection.location == 0 || nsString.character(at: selection.location - 1) == 0x0A
        let text = (atLineStart ? "" : "\n") + "---\n"
        replace(selection, with: text, selecting: NSRange(location: selection.location + (text as NSString).length, length: 0))
    }

    private func selectedBlocks() -> [MarkdownBlock] {
        selectedParagraphs().map { MarkdownParser.parse(nsString.substring(with: lineContent($0)), startsInCode: false).block }
    }

    /// Replaces each selected line's block marker (heading, list, quote) with a new one.
    private func setLinePrefix(_ prefix: (MarkdownBlock, Int) -> String) {
        let paragraphs = selectedParagraphs()
        guard let first = paragraphs.first, let last = paragraphs.last else { return }
        let whole = NSRange(location: first.location, length: NSMaxRange(lineContent(last)) - first.location)
        var lines: [String] = []
        for (index, paragraph) in paragraphs.enumerated() {
            let line = nsString.substring(with: lineContent(paragraph))
            let block = MarkdownParser.parse(line, startsInCode: false).block
            let markerEnd: Int = switch block {
            case let .heading(_, marker): NSMaxRange(marker)
            default: block.prefixLength
            }
            let indent: String
            switch block {
            case .bullet, .ordered, .task: indent = String(line.prefix { $0 == " " || $0 == "\t" })
            default: indent = ""
            }
            let text = (line as NSString).substring(from: min(markerEnd, (line as NSString).length))
            lines.append(indent + prefix(block, index) + text)
        }
        let joined = lines.joined(separator: "\n")
        replace(whole, with: joined, selecting: NSRange(location: whole.location + (joined as NSString).length, length: 0))
    }
}
