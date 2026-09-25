import AppKit
import Dependencies
import TackKit
import UniformTypeIdentifiers

extension NoteTextView {
    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty, urls.allSatisfy(MediaSource.isMedia) {
            insertMedia(urls)
            return
        }
        let hasText = pasteboard.availableType(from: [.string]) != nil
        if !hasText, let image = pasteboard.data(forType: .png) ?? pngData(pasteboard.data(forType: .tiff)) {
            @Dependency(\.attachmentClient) var attachments
            if let url = try? attachments.save(image, "png") {
                insertMedia([url])
                return
            }
        }
        pasteAsPlainText(sender)
    }

    /// A plain-text view disables Paste when the clipboard holds only an image.
    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(paste(_:)), NSPasteboard.general.availableType(from: [.png, .tiff, .fileURL]) != nil {
            return isEditable
        }
        return super.validateUserInterfaceItem(item)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty, urls.allSatisfy(MediaSource.isMedia)
        else { return super.performDragOperation(sender) }
        let point = convert(sender.draggingLocation, from: nil)
        setSelectedRange(NSRange(location: characterIndexForInsertion(at: point), length: 0))
        window?.makeFirstResponder(self)
        insertMedia(urls)
        return true
    }

    func insertMedia(_ urls: [URL]) {
        let nsString = string as NSString
        let selection = selectedRange()
        let atLineStart = selection.location == 0 || nsString.character(at: selection.location - 1) == 0x0A
        let lines = urls.map { "![](\(MediaSource.source(for: $0)))" }.joined(separator: "\n")
        let text = (atLineStart ? "" : "\n") + lines + "\n"
        replace(selection, with: text, selecting: NSRange(location: selection.location + (text as NSString).length, length: 0))
    }

    private func pngData(_ tiff: Data?) -> Data? {
        guard let tiff, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
