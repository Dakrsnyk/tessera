import XCTest
@testable import Ardane

/// Graphite is the default color and the only free one since 2026-11-27 (Saphir before); the others are Premium.
@MainActor
final class AppThemePremiumTests: XCTestCase {
    func testGraphiteIsTheDefault() throws {
        XCTAssertEqual(AppSettings().appStyle, .slate)
        XCTAssertEqual(AppStyleID.free, .slate)
        let empty = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(empty.appStyle, .slate)
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"nope"}"#.utf8))
        XCTAssertEqual(unknown.appStyle, .slate)
    }

    func testAnOldSavedSettingKeepsItsValue() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"jade","currencyCode":"EUR"}"#.utf8))
        XCTAssertEqual(old.appStyle, .jade, "The saved choice is not rewritten")
        XCTAssertEqual(old.currencyCode, "EUR")
        let former = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"tessera"}"#.utf8))
        XCTAssertEqual(former.appStyle, .jade)
    }

    func testOnlyGraphiteIsFree() {
        XCTAssertFalse(AppStyleID.slate.isPremium)
        XCTAssertEqual(AppStyleID.allCases.filter(\.isPremium).count, AppStyleID.allCases.count - 1)
    }

    func testFreePlanOnJadeShowsGraphite() {
        XCTAssertEqual(AppStyleID.jade.effective(isPremium: false), .slate)
        XCTAssertEqual(AppStyle.style(.jade, isPremium: false).id, .slate)
        for id in AppStyleID.allCases {
            XCTAssertEqual(id.effective(isPremium: false), .slate, "\(id)")
        }
    }

    func testFreePlanSavedOnSaphirNowShowsGraphite() {
        XCTAssertTrue(AppStyleID.sapphire.isPremium)
        XCTAssertEqual(AppStyleID.sapphire.effective(isPremium: false), .slate)
        XCTAssertEqual(AppStyleID.sapphire.effective(isPremium: true), .sapphire)
    }

    func testPremiumKeepsItsColor() {
        for id in AppStyleID.allCases {
            XCTAssertEqual(id.effective(isPremium: true), id, "\(id)")
        }
        XCTAssertEqual(AppStyle.style(.jade, isPremium: true).id, .jade)
    }

    func testGraphiteIsAlwaysAvailable() {
        XCTAssertEqual(AppStyleID.slate.effective(isPremium: false), .slate)
        XCTAssertEqual(AppStyleID.slate.effective(isPremium: true), .slate)
    }

    func testEndOfPremiumKeepsTheSavedChoice() {
        var settings = AppSettings()
        settings.appStyle = .ruby
        XCTAssertEqual(settings.appStyle.effective(isPremium: false), .slate)
        XCTAssertEqual(settings.appStyle, .ruby, "Only the display changes: the choice comes back with Premium")
        XCTAssertEqual(settings.appStyle.effective(isPremium: true), .ruby)
    }
}
