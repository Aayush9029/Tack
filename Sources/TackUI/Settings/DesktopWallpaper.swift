import AppKit
import SwiftUI

/// A small wallpaper thumbnail behind the panel miniatures, the same in both
/// appearances. Photo from Unsplash, scaled down to the size it is drawn at.
enum DesktopWallpaper {
    static let image: Image = {
        guard let url = Bundle.main.url(forResource: "desktop", withExtension: "jpg"),
              let nsImage = NSImage(contentsOf: url)
        else { return Image(systemName: "photo") }
        return Image(nsImage: nsImage)
    }()
}
