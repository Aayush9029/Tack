import AppKit
import SwiftUI
import Testing
@testable import TackUI

@MainActor
@Suite struct GlowRenderProbe {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TACK_RENDER_DIR"] != nil))
    func renderGlow() throws {
        let directory = URL(filePath: ProcessInfo.processInfo.environment["TACK_RENDER_DIR"]!)
        for (name, offset) in [("half", -50.0), ("full", -120.0), ("blocked", 40.0)] {
            let view = ZStack {
                Color(red: 0.12, green: 0.12, blue: 0.14)
                SwipeGlow(offset: offset, isAllowed: name != "blocked", flash: nil)
            }
            .frame(width: 360, height: 300)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.nsImage)
            let data = try #require(NSBitmapImageRep(data: image.tiffRepresentation!)?.representation(using: .png, properties: [:]))
            try data.write(to: directory.appending(path: "glow-\(name).png"))
        }
    }
}
