import AppKit
import SwiftUI
import Testing
@testable import TackKit
@testable import TackUI

@MainActor
@Suite struct RaycastSectionRender {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TACK_RENDER_DIR"] != nil))
    func render() async throws {
        let view = Form { RaycastSection(theme: NoteTheme()) }
            .formStyle(.grouped)
            .frame(width: 520, height: 220)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 520, height: 220)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(200))
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(filePath: ProcessInfo.processInfo.environment["TACK_RENDER_DIR"]!).appending(path: "raycast.png"))
        #expect(RaycastSection.isRaycastInstalled)
    }
}
