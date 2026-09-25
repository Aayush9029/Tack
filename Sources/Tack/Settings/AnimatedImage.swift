import AppKit
import SwiftUI

struct AnimatedImage: NSViewRepresentable {
    let resource: String

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleAxesIndependently
        view.animates = true
        view.canDrawSubviewsIntoLayer = true
        view.image = Self.image(named: resource)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        guard view.image == nil else { return }
        view.image = Self.image(named: resource)
    }

    private static func image(named resource: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "gif") else { return nil }
        return NSImage(contentsOf: url)
    }
}
