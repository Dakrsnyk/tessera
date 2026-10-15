import SwiftUI
import UIKit
import WidgetKit

// The widgets of « Photos et citations », drawn edge to edge (no margin, no card): the same views on the
// Home Screen and in every preview of the app.

/// One to four photos, each framed in its cell as the person chose; more than four take turns every hour.
struct PhotoCollageView: View {
    let photos: [PhotoSlot]
    let family: WidgetFamily
    let date: Date
    /// In the app, while choosing: a cell can be touched to frame its photo.
    var onSelect: ((PhotoSlot) -> Void)?

    var body: some View {
        let shown = PhotoLayout.visible(photos, at: date)
        GeometryReader { geo in
            if shown.isEmpty {
                PhotoPlaceholder(symbol: "photo.on.rectangle.angled", text: tr("Choisis tes photos dans Ardane"))
            } else {
                let cells = PhotoLayout.cells(count: shown.count, family: family)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(zip(shown, cells).enumerated()), id: \.offset) { _, pair in
                        let slot = pair.0
                        let cell = pair.1
                        let gap: CGFloat = shown.count > 1 ? 1.5 : 0
                        let size = CGSize(width: cell.width * geo.size.width - gap * 2, height: cell.height * geo.size.height - gap * 2)
                        PhotoCell(slot: slot, size: size)
                            .frame(width: max(1, size.width), height: max(1, size.height))
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { onSelect?(slot) }
                            .offset(x: cell.minX * geo.size.width + gap, y: cell.minY * geo.size.height + gap)
                    }
                }
            }
        }
        .background(Color.black)
    }
}

/// A photo in its cell at its framing, or what replaces it when its file is gone.
struct PhotoCell: View {
    let slot: PhotoSlot
    let size: CGSize

    var body: some View {
        if let image = PhotoCell.image(slot.file, for: size, zoom: slot.zoom) {
            let frame = PhotoLayout.frame(image: image.size, cell: size, slot: slot)
            Image(uiImage: image)
                .resizable()
                .frame(width: frame.size.width, height: frame.size.height)
                .offset(x: frame.offset.x, y: frame.offset.y)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
        } else {
            PhotoPlaceholder(symbol: "photo.badge.exclamationmark", text: tr("Photo indisponible"))
        }
    }

    /// The photo at the size it is drawn (sharp on the screen, light in the widget's memory).
    static func image(_ file: String, for size: CGSize, zoom: Double) -> UIImage? {
        guard !file.isEmpty, let image = ImageStore.image(named: file) else { return nil }
        let longest = max(size.width, size.height) * 3 * max(1, zoom)
        guard longest > 0, max(image.size.width, image.size.height) > longest else { return image }
        let ratio = longest / max(image.size.width, image.size.height)
        let target = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        return image.preparingThumbnail(of: target) ?? image
    }
}

private struct PhotoPlaceholder: View {
    let symbol: String
    let text: String

    var body: some View {
        ZStack {
            Color(white: 0.16)
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                Text(text)
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.white.opacity(0.75))
            .padding(10)
        }
    }
}

/// A quote with its author, in its typography, on its colors.
struct QuoteWidgetView: View {
    let quote: QuoteContent
    let family: WidgetFamily

    private var size: CGFloat {
        let length = quote.text.count
        switch family {
        case .systemSmall: return length > 90 ? 13 : (length > 50 ? 15 : 18)
        case .systemMedium: return length > 140 ? 15 : (length > 70 ? 18 : 21)
        default: return length > 260 ? 18 : (length > 120 ? 22 : 26)
        }
    }

    private var design: Font.Design {
        switch quote.font {
        case .serif: .serif
        case .rounded: .rounded
        case .standard: .default
        case .mono: .monospaced
        }
    }

    var body: some View {
        let ink = Color(hex: quote.textHex)
        let alignment: HorizontalAlignment = quote.isCentered ? .center : .leading
        ZStack {
            Color(hex: quote.backgroundHex)
            VStack(alignment: alignment, spacing: family == .systemSmall ? 6 : 10) {
                if quote.showsMarks {
                    Text("“")
                        .font(.system(size: size * 2.2, weight: .bold, design: design))
                        .foregroundStyle(ink.opacity(0.35))
                        .frame(height: size * 1.1, alignment: .top)
                        .accessibilityHidden(true)
                }
                Text(quote.text.trimmed.isEmpty ? tr("Ta citation ici") : quote.text)
                    .font(.system(size: size, weight: quote.font == .serif ? .regular : .semibold, design: design))
                    .italic(quote.font == .serif)
                    .foregroundStyle(ink)
                    .multilineTextAlignment(quote.isCentered ? .center : .leading)
                    .minimumScaleFactor(0.6)
                if !quote.author.trimmed.isEmpty {
                    Text("— \(quote.author.trimmed)")
                        .font(.system(size: max(10, size * 0.62), weight: .medium, design: design))
                        .foregroundStyle(ink.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: quote.isCentered ? .center : .leading)
            .padding(family == .systemSmall ? 14 : 20)
        }
    }
}
