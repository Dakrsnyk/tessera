import XCTest
@testable import Ardane

/// The free dish analyses: 10 in total without Premium, barcodes never counted.
final class PhotoScanQuotaTests: XCTestCase {
    func testTenFreeAnalysesThenLocked() {
        XCTAssertEqual(PhotoScanQuota.freeLimit, 10)
        XCTAssertEqual(PhotoScanQuota.remaining(used: 0), 10)
        XCTAssertTrue(PhotoScanQuota.canAnalyze(used: 9, isPremium: false))
        XCTAssertEqual(PhotoScanQuota.remaining(used: 9), 1)
        XCTAssertFalse(PhotoScanQuota.canAnalyze(used: 10, isPremium: false))
        XCTAssertEqual(PhotoScanQuota.remaining(used: 25), 0)
    }

    func testPremiumIsNeverLimited() {
        XCTAssertTrue(PhotoScanQuota.canAnalyze(used: 500, isPremium: true))
    }

    func testNegativeCountDoesNotGiveMore() {
        XCTAssertEqual(PhotoScanQuota.remaining(used: -5), 10)
    }

    func testOldNutritionDataWithoutTheCounterDecodesAsZero() throws {
        let state = try JSONDecoder().decode(NutritionState.self, from: Data("{}".utf8))
        XCTAssertEqual(state.photoScansUsed, 0)
    }

    func testTheCounterSurvivesEncoding() throws {
        var state = NutritionState()
        state.photoScansUsed = 4
        let back = try JSONDecoder().decode(NutritionState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(back.photoScansUsed, 4)
    }
}
