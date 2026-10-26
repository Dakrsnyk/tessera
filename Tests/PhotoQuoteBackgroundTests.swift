import UIKit
import WidgetKit
import XCTest
@testable import Ardane

/// A photo behind a quote (request of 2026-10-15): kept as the widget's only photo, read back unchanged,
/// older quotes read as before, light text on the darkened photo, and the quote's own colors when the
/// photo's file is gone.
@MainActor
final class PhotoQuoteBackgroundTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        AppModel(store: SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)))
    }

    private func quote(behind file: String) -> WidgetDesign {
        var design = WidgetDesign(kind: .quote, format: .medium)
        design.options.quote = QuoteContent(text: "Courage", author: "Moi")
        design.options.photos = [PhotoSlot(file: file, centerX: 0.3, centerY: 0.6, zoom: 1.5)]
        return design
    }

    private func savedPhoto() throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        return try XCTUnwrap(ImageStore.save(image, maxDimension: 1_200))
    }

    func testAQuoteKeepsItsBackgroundPhotoWhenSavedAndRead() throws {
        var design = quote(behind: "\(UUID().uuidString).jpg")
        design.options.quote?.photoVeil = 0.55
        let read = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(design))
        XCTAssertEqual(read.quoteBackground, design.quoteBackground)
        XCTAssertEqual(read.quoteBackground?.zoom, 1.5)
        XCTAssertEqual(read.options.quote, design.options.quote)
        XCTAssertEqual(read.options.quote?.photoVeil, 0.55)
    }

    func testAQuoteSavedBeforeBackgroundPhotosReadsAsBefore() throws {
        let saved = #"{"text":"Courage","author":"Moi","font":"rounded","backgroundHex":"15171F","textHex":"F2EEE6","isCentered":false,"showsMarks":false}"#
        let quote = try JSONDecoder().decode(QuoteContent.self, from: Data(saved.utf8))
        XCTAssertEqual(quote.text, "Courage")
        XCTAssertEqual(quote.author, "Moi")
        XCTAssertEqual(quote.font, .rounded)
        XCTAssertEqual(quote.backgroundHex, "15171F")
        XCTAssertEqual(quote.textHex, "F2EEE6")
        XCTAssertFalse(quote.isCentered)
        XCTAssertFalse(quote.showsMarks)
        XCTAssertEqual(quote.photoVeil, QuoteContent().photoVeil)
        var design = WidgetDesign(kind: .quote, format: .small)
        design.options.quote = quote
        let read = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(design))
        XCTAssertNil(read.quoteBackground)
        XCTAssertEqual(read.options.quote, quote)
    }

    func testOnlyAQuoteTakesItsFirstPhotoAsBackground() {
        var photos = WidgetDesign(kind: .photos, format: .small)
        photos.options.photos = [PhotoSlot(file: "a.jpg")]
        XCTAssertNil(photos.quoteBackground, "A photo widget's photos are never a quote's background")
        let design = quote(behind: "b.jpg")
        XCTAssertEqual(design.quoteBackground?.file, "b.jpg")
    }

    func testTextOnAPhotoStaysLight() {
        var quote = QuoteContent(text: "Courage")
        for palette in QuotePalette.all {
            quote.apply(palette)
            let rgb = ColorMath.rgb(quote.inkOnPhotoHex)
            XCTAssertGreaterThanOrEqual(ColorMath.relativeLuminance(rgb.r, rgb.g, rgb.b), 0.6, palette.id)
            if ColorMath.isLight(palette.textHex) {
                XCTAssertEqual(quote.inkOnPhotoHex, palette.textHex, "A light text color is kept: \(palette.id)")
            } else {
                XCTAssertEqual(quote.inkOnPhotoHex, "FFFFFF", "A dark text color turns white: \(palette.id)")
            }
        }
        XCTAssertTrue(QuoteContent.veilRange.contains(QuoteContent().photoVeil))
    }

    func testTheQuoteFallsBackToItsColorsWhenThePhotoIsGone() throws {
        let file = try savedPhoto()
        let design = quote(behind: file)
        let size = WidgetMetrics.size(.systemMedium)
        XCTAssertNotNil(QuoteWidgetView.backgroundImage(design.quoteBackground, size: size))
        ImageStore.delete(named: file)
        XCTAssertNil(QuoteWidgetView.backgroundImage(design.quoteBackground, size: size), "A deleted photo leaves the quote on its colors")
        XCTAssertNil(QuoteWidgetView.backgroundImage(nil, size: size))
        XCTAssertNil(QuoteWidgetView.backgroundImage(PhotoSlot(file: ""), size: size))
    }

    func testDuplicatingOrDeletingAQuoteHandlesItsBackgroundFile() throws {
        let model = temporaryModel()
        let file = try savedPhoto()
        let design = quote(behind: file)
        model.save(design)
        let copy = try XCTUnwrap(model.duplicate(design))
        let copied = try XCTUnwrap(copy.quoteBackground)
        XCTAssertNotEqual(copied.file, file, "The copy has its own photo file")
        XCTAssertEqual(copied.zoom, 1.5, "and the same framing")
        model.delete(design)
        XCTAssertNil(ImageStore.image(named: file), "Deleting the quote deletes its photo")
        XCTAssertNotNil(ImageStore.image(named: copied.file), "The copy keeps its own")
        model.delete(copy)
        XCTAssertNil(ImageStore.image(named: copied.file))
    }
}
