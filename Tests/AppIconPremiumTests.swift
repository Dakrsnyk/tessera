import XCTest
@testable import Tessera

/// Changing the app icon is Premium (2026-10-15): without it, only another icon is locked; the icon already
/// on the Home Screen is kept and the main one can always come back.
final class AppIconPremiumTests: XCTestCase {
    private var glass: AppIconChoice { AppIconChoice.all.first { $0.asset == "ArdaneIcon-GlassBlack" }! }
    private var main: AppIconChoice { AppIconChoice.all.first { $0.asset == AppIconChoice.main }! }

    func testPremiumChangesTheIconFreely() {
        for icon in AppIconChoice.all {
            XCTAssertFalse(icon.isLocked(current: AppIconChoice.main, isPremium: true))
            XCTAssertFalse(icon.isLocked(current: "ArdaneIcon-Jade", isPremium: true))
        }
    }

    func testWithoutPremiumOnlyAnotherIconIsLocked() {
        XCTAssertTrue(glass.isLocked(current: AppIconChoice.main, isPremium: false))
        for icon in AppIconChoice.all where icon.asset != AppIconChoice.main {
            XCTAssertTrue(icon.isLocked(current: AppIconChoice.main, isPremium: false), "\(icon.asset) needs Premium")
        }
        XCTAssertFalse(main.isLocked(current: AppIconChoice.main, isPremium: false))
    }

    func testAnIconAlreadyInPlaceIsKeptAndTheMainOneCanComeBack() {
        // Picked before (with Premium, or before it was Premium): still the one in place, never locked.
        XCTAssertFalse(glass.isLocked(current: glass.asset, isPremium: false))
        XCTAssertFalse(main.isLocked(current: glass.asset, isPremium: false))
        XCTAssertTrue(AppIconChoice.all.first { $0.asset == "ArdaneIcon-Jade" }!.isLocked(current: glass.asset, isPremium: false))
    }
}
