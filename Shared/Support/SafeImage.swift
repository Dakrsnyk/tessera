import Foundation
import ImageIO
import UIKit

/// Decodes a picture the person chose without trusting it: the size is read from the header (nothing is
/// decoded), a picture with too many pixels or an unreadable one is refused, and the rest is decoded as a
/// bounded thumbnail, with its orientation applied. A booby-trapped or gigantic file can't exhaust the memory.
enum SafeImage {
    /// 64 megapixels: above any phone camera (48) and the usual panoramas, below what could bring the app down
    /// (a PNG is decoded whole before it is scaled: about 4 bytes a pixel).
    static let maxPixels = 64_000_000
    /// The long side kept by default: enough for a dish or a timetable to stay readable.
    static let defaultMaxDimension = 4_096

    /// The size in pixels read from the header, without decoding. Nil if the data isn't a readable picture.
    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        return pixelSize(of: source)
    }

    /// True when the picture has readable, non-zero dimensions and no more than `maxPixels` pixels.
    static func isAcceptable(_ data: Data, maxPixels: Int = SafeImage.maxPixels) -> Bool {
        guard let size = pixelSize(of: data) else { return false }
        return fits(size, maxPixels)
    }

    /// Without a product that could overflow on a forged header.
    private static func fits(_ size: (width: Int, height: Int), _ maxPixels: Int) -> Bool {
        size.width <= maxPixels / size.height
    }

    /// The picture as a thumbnail whose long side is at most `maxDimension` (never enlarged), or nil if it
    /// is refused (unreadable, empty dimensions or over `maxPixels`).
    static func decode(_ data: Data, maxDimension: Int = SafeImage.defaultMaxDimension, maxPixels: Int = SafeImage.maxPixels) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let size = pixelSize(of: source), fits(size, maxPixels) else { return nil }
        let side = max(1, min(maxDimension, max(size.width, size.height)))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func pixelSize(of source: CGImageSource) -> (width: Int, height: Int)? {
        guard CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0 else { return nil }
        return (width, height)
    }
}
