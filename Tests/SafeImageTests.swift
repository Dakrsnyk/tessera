import UIKit
import XCTest
@testable import Ardane

/// Pictures chosen by the person are measured from their header and decoded as bounded thumbnails.
final class SafeImageTests: XCTestCase {
    private func png(width: Int, height: Int) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try XCTUnwrap(image.pngData())
    }

    func testAnOrdinaryPictureIsAcceptedAndKeptAtItsSize() throws {
        let data = try png(width: 300, height: 200)
        let image = try XCTUnwrap(SafeImage.decode(data))
        XCTAssertEqual(Int(image.size.width), 300)
        XCTAssertEqual(Int(image.size.height), 200)
    }

    func testALargePictureIsBoundedWithoutBeingEnlarged() throws {
        let data = try png(width: 1_000, height: 500)
        let bounded = try XCTUnwrap(SafeImage.decode(data, maxDimension: 400))
        XCTAssertEqual(Int(max(bounded.size.width, bounded.size.height)), 400)
        let small = try XCTUnwrap(SafeImage.decode(data, maxDimension: 5_000))
        XCTAssertEqual(Int(small.size.width), 1_000, "a picture is never enlarged")
    }

    func testTheSizeIsReadFromTheHeader() throws {
        let size = try XCTUnwrap(SafeImage.pixelSize(of: try png(width: 120, height: 80)))
        XCTAssertEqual(size.width, 120)
        XCTAssertEqual(size.height, 80)
    }

    func testInvalidDataIsRefused() {
        XCTAssertNil(SafeImage.pixelSize(of: Data()))
        XCTAssertNil(SafeImage.decode(Data("pas une image".utf8)))
        XCTAssertFalse(SafeImage.isAcceptable(Data(repeating: 0xFF, count: 64)))
    }

    /// The limit is a parameter so that no huge file is needed: 100 × 100 pixels against a 5 000-pixel limit.
    func testAPictureOverTheLimitIsRefused() throws {
        let data = try png(width: 100, height: 100)
        XCTAssertTrue(SafeImage.isAcceptable(data, maxPixels: 10_000))
        XCTAssertFalse(SafeImage.isAcceptable(data, maxPixels: 5_000))
        XCTAssertNil(SafeImage.decode(data, maxPixels: 5_000))
        XCTAssertEqual(SafeImage.maxPixels, 64_000_000)
    }
}
