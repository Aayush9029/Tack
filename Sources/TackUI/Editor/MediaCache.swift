import AppKit
import AVFoundation
import ImageIO
import TackKit

/// Decoded thumbnails for images and video posters. Decoding runs off the main
/// actor at display size; a finished load posts `didLoad` so editors restyle the
/// paragraphs that show it.
@MainActor
final class MediaCache {
    static let shared = MediaCache()
    static let didLoad = Notification.Name("tack.media.didLoad")

    struct Media: Sendable {
        let image: CGImage
        let pixelSize: CGSize
        let isVideo: Bool

        var aspect: CGFloat { pixelSize.height > 0 ? pixelSize.width / pixelSize.height : 4.0 / 3.0 }
    }

    /// Decoded thumbnails, up to about 200 MB; the rest decode again when shown.
    private let media: NSCache<NSURL, Box> = {
        let cache = NSCache<NSURL, Box>()
        cache.totalCostLimit = 200 * 1024 * 1024
        return cache
    }()

    private final class Box {
        let media: Media
        init(_ media: Media) { self.media = media }
    }
    private var failed: Set<URL> = []
    private var loading: Set<URL> = []

    func cached(_ url: URL) -> Media? {
        media.object(forKey: url as NSURL)?.media
    }

    func hasFailed(_ url: URL) -> Bool {
        failed.contains(url)
    }

    func load(_ url: URL) {
        guard cached(url) == nil, !failed.contains(url), !loading.contains(url) else { return }
        loading.insert(url)
        Task {
            let result = await Self.decode(url)
            loading.remove(url)
            if let result {
                media.setObject(Box(result), forKey: url as NSURL, cost: result.image.bytesPerRow * result.image.height)
            } else {
                failed.insert(url)
                Log.editor.notice("Could not load media at \(url.path(percentEncoded: false), privacy: .private)")
            }
            NotificationCenter.default.post(name: Self.didLoad, object: url)
        }
    }

    @concurrent
    private static func decode(_ url: URL) async -> Media? {
        if MediaSource.isVideo(url) {
            return await poster(url)
        }
        let data: Data?
        if url.isFileURL {
            data = try? Data(contentsOf: url, options: .mappedIfSafe)
        } else {
            data = try? await URLSession.shared.data(from: url).0
        }
        guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
        let orientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1400,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let rotated = (5...8).contains(orientation)
        let size = rotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        return Media(
            image: thumbnail,
            pixelSize: size.width > 0 ? size : CGSize(width: thumbnail.width, height: thumbnail.height),
            isVideo: false
        )
    }

    @concurrent
    private static func poster(_ url: URL) async -> Media? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1400, height: 1400)
        guard let (image, _) = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)) else { return nil }
        return Media(
            image: image,
            pixelSize: CGSize(width: image.width, height: image.height),
            isVideo: true
        )
    }
}
