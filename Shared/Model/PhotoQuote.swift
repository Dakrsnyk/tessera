import CoreGraphics
import Foundation
import WidgetKit

// « Photos et citations »: widgets made of the person's photos (one to four at once, each framed in its
// cell) or of a quote with its own typography and colors. Both are made in their mini-app; the photos are
// copied (downscaled) into the shared container, so a photo deleted or moved in the library stays on the
// widget, and the widget never needs access to the photo library.

/// A photo of a photo widget and how it is framed in its cell.
struct PhotoSlot: Codable, Hashable, Identifiable {
    var id = UUID()
    /// File name in `ImageStore`.
    var file: String
    /// The point of the photo kept at the center of its cell (0…1 across and down).
    var centerX: Double = 0.5
    var centerY: Double = 0.5
    /// 1: the photo just fills its cell; more zooms in.
    var zoom: Double = 1

    init(file: String, centerX: Double = 0.5, centerY: Double = 0.5, zoom: Double = 1) {
        self.file = file
        self.centerX = centerX
        self.centerY = centerY
        self.zoom = zoom
    }

    enum CodingKeys: String, CodingKey { case id, file, centerX, centerY, zoom }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        file = c.value(.file, "")
        centerX = c.value(.centerX, 0.5)
        centerY = c.value(.centerY, 0.5)
        zoom = c.value(.zoom, 1)
    }

    /// Kept within the photo: the center can't leave it, the zoom stays between 1 and 4.
    var clamped: PhotoSlot {
        var copy = self
        copy.centerX = min(1, max(0, centerX))
        copy.centerY = min(1, max(0, centerY))
        copy.zoom = min(4, max(1, zoom))
        return copy
    }
}

/// The typography of a quote.
enum QuoteFont: String, Codable, CaseIterable, Identifiable {
    case serif, rounded, standard, mono
    var id: String { rawValue }

    var title: String {
        switch self {
        case .serif: tr("Serif")
        case .rounded: tr("Arrondie")
        case .standard: tr("Standard")
        case .mono: tr("Mono")
        }
    }
}

/// The colors of a quote: a few ready pairs, or the person's own.
struct QuotePalette: Identifiable, Hashable {
    let id: String
    let name: String
    let backgroundHex: String
    let textHex: String

    static let all: [QuotePalette] = [
        QuotePalette(id: "paper", name: tr("Papier"), backgroundHex: "F6F0E6", textHex: "2B2622"),
        QuotePalette(id: "night", name: tr("Nuit"), backgroundHex: "15171F", textHex: "F2EEE6"),
        QuotePalette(id: "coral", name: tr("Corail"), backgroundHex: "F26B5B", textHex: "FFF8F2"),
        QuotePalette(id: "ocean", name: tr("Océan"), backgroundHex: "1F4E79", textHex: "E8F1FA"),
        QuotePalette(id: "forest", name: tr("Forêt"), backgroundHex: "2F5D50", textHex: "EEF5EC"),
        QuotePalette(id: "rose", name: tr("Rose"), backgroundHex: "F8D7DD", textHex: "5B2333"),
        QuotePalette(id: "sand", name: tr("Sable"), backgroundHex: "E8D5B5", textHex: "3E3020"),
        QuotePalette(id: "lilac", name: tr("Lilas"), backgroundHex: "DCD3F5", textHex: "2E2350"),
    ]
}

/// What a quote widget shows and how.
struct QuoteContent: Codable, Hashable {
    var text: String = ""
    /// Optional.
    var author: String = ""
    var font: QuoteFont = .serif
    var backgroundHex = "F6F0E6"
    var textHex = "2B2622"
    var isCentered = true
    /// Large quotation marks above the text.
    var showsMarks = true
    /// With a photo behind the quote (`WidgetDesign.quoteBackground`): how much it is darkened under the text.
    var photoVeil = 0.4

    init(text: String = "", author: String = "") {
        self.text = text
        self.author = author
    }

    enum CodingKeys: String, CodingKey { case text, author, font, backgroundHex, textHex, isCentered, showsMarks, photoVeil }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = QuoteContent()
        text = c.value(.text, d.text)
        author = c.value(.author, d.author)
        font = c.value(.font, d.font)
        backgroundHex = c.value(.backgroundHex, d.backgroundHex)
        textHex = c.value(.textHex, d.textHex)
        isCentered = c.value(.isCentered, d.isCentered)
        showsMarks = c.value(.showsMarks, d.showsMarks)
        photoVeil = c.value(.photoVeil, d.photoVeil)
    }

    mutating func apply(_ palette: QuotePalette) {
        backgroundHex = palette.backgroundHex
        textHex = palette.textHex
    }

    /// The veil over a background photo: light enough to keep the photo, dark enough for light text.
    static let veilRange: ClosedRange<Double> = 0.15...0.75

    /// The text's color on a background photo, which is always darkened by its veil: the chosen color when
    /// it is light (the light text of a palette, a pastel), else white, since a dark color would vanish there.
    /// Without a photo, or when its file is gone, the quote keeps its own two colors.
    var inkOnPhotoHex: String {
        let rgb = ColorMath.rgb(textHex)
        return ColorMath.relativeLuminance(rgb.r, rgb.g, rgb.b) >= 0.6 ? textHex : "FFFFFF"
    }

    static let sample = QuoteContent(text: tr("Fais de ta vie un rêve, et d'un rêve, une réalité."), author: "Antoine de Saint-Exupéry")
}

/// Where the photos go in the widget, from their number and the widget's size.
enum PhotoLayout {
    /// Photos shown at once: four at most, whatever the size, so each one stays readable.
    static let capacity = 4
    /// Photos a widget can hold; beyond `capacity`, they take turns every hour.
    static let maxPhotos = 12

    /// The photos shown at a date: all of them when they fit, else `capacity` of them, the next ones
    /// each hour (the same ones for the whole hour, on every widget).
    static func visible(_ photos: [PhotoSlot], at date: Date) -> [PhotoSlot] {
        guard photos.count > capacity else { return photos }
        let hour = Int(date.timeIntervalSince1970 / 3_600)
        let start = (hour * capacity) % photos.count
        return (0..<capacity).map { photos[(start + $0) % photos.count] }
    }

    /// The next date the photos shown change, or nil when they never do.
    static func nextChange(_ photos: [PhotoSlot], after date: Date) -> Date? {
        guard photos.count > capacity else { return nil }
        let hour = (date.timeIntervalSince1970 / 3_600).rounded(.down)
        return Date(timeIntervalSince1970: (hour + 1) * 3_600)
    }

    /// The cells of `count` photos, in a unit square (x, y, width, height from 0 to 1), for a widget of this
    /// family: one photo fills it, two share it, three put one large beside or above two, four make a grid.
    static func cells(count: Int, family: WidgetFamily) -> [CGRect] {
        let wide = family == .systemMedium
        let tall = family == .systemLarge
        switch count {
        case ...0: return []
        case 1: return [CGRect(x: 0, y: 0, width: 1, height: 1)]
        case 2:
            return tall
                ? [CGRect(x: 0, y: 0, width: 1, height: 0.5), CGRect(x: 0, y: 0.5, width: 1, height: 0.5)]
                : [CGRect(x: 0, y: 0, width: 0.5, height: 1), CGRect(x: 0.5, y: 0, width: 0.5, height: 1)]
        case 3:
            if tall {
                return [CGRect(x: 0, y: 0, width: 1, height: 0.6),
                        CGRect(x: 0, y: 0.6, width: 0.5, height: 0.4), CGRect(x: 0.5, y: 0.6, width: 0.5, height: 0.4)]
            }
            let first = wide ? 0.5 : 0.6
            return [CGRect(x: 0, y: 0, width: first, height: 1),
                    CGRect(x: first, y: 0, width: 1 - first, height: 0.5), CGRect(x: first, y: 0.5, width: 1 - first, height: 0.5)]
        default:
            return [CGRect(x: 0, y: 0, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                    CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5), CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)]
        }
    }

    /// Where a photo of `imageSize` goes in a cell of `cellSize` to keep its chosen center in the middle,
    /// at its zoom, without ever showing an empty edge: its drawn size and its offset in the cell.
    static func frame(image imageSize: CGSize, cell cellSize: CGSize, slot: PhotoSlot) -> (size: CGSize, offset: CGPoint) {
        guard imageSize.width > 0, imageSize.height > 0, cellSize.width > 0, cellSize.height > 0 else {
            return (cellSize, .zero)
        }
        let slot = slot.clamped
        let fill = max(cellSize.width / imageSize.width, cellSize.height / imageSize.height)
        let scale = fill * slot.zoom
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = min(0, max(cellSize.width - size.width, cellSize.width / 2 - slot.centerX * size.width))
        let y = min(0, max(cellSize.height - size.height, cellSize.height / 2 - slot.centerY * size.height))
        return (size, CGPoint(x: x, y: y))
    }
}

extension WidgetDesign {
    /// The photo behind a quote widget: its first photo. It is kept in `options.photos` like a photo widget's,
    /// so deleting, duplicating or backing up the widget handles its file the same way.
    var quoteBackground: PhotoSlot? { kind == .quote ? options.photos.first : nil }
}

extension WidgetKind {
    /// Widgets made in their own mini-app (« Photos et citations »), never from the catalog.
    static let madeInTheirMiniApp: Set<WidgetKind> = [.photos, .quote]

    var isMadeInItsMiniApp: Bool { Self.madeInTheirMiniApp.contains(self) }
}
