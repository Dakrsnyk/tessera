import XCTest
@testable import Ardane

/// Saphir is the default color and the only free one; the eleven others are Premium.
@MainActor
final class AppThemePremiumTests: XCTestCase {
    func testSaphirIsTheDefault() throws {
        XCTAssertEqual(AppSettings().appStyle, .sapphire)
        XCTAssertEqual(AppStyleID.free, .sapphire)
        let empty = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(empty.appStyle, .sapphire)
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"nope"}"#.utf8))
        XCTAssertEqual(unknown.appStyle, .sapphire)
    }

    func testAnOldSavedSettingKeepsItsValue() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"jade","currencyCode":"EUR"}"#.utf8))
        XCTAssertEqual(old.appStyle, .jade, "The saved choice is not rewritten")
        XCTAssertEqual(old.currencyCode, "EUR")
        let former = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"tessera"}"#.utf8))
        XCTAssertEqual(former.appStyle, .jade)
    }

    func testOnlySaphirIsFree() {
        XCTAssertFalse(AppStyleID.sapphire.isPremium)
        XCTAssertEqual(AppStyleID.allCases.filter(\.isPremium).count, AppStyleID.allCases.count - 1)
    }

    func testFreePlanOnJadeShowsSaphir() {
        XCTAssertEqual(AppStyleID.jade.effective(isPremium: false), .sapphire)
        XCTAssertEqual(AppStyle.style(.jade, isPremium: false).id, .sapphire)
        for id in AppStyleID.allCases {
            XCTAssertEqual(id.effective(isPremium: false), .sapphire, "\(id)")
        }
    }

    func testPremiumKeepsItsColor() {
        for id in AppStyleID.allCases {
            XCTAssertEqual(id.effective(isPremium: true), id, "\(id)")
        }
        XCTAssertEqual(AppStyle.style(.jade, isPremium: true).id, .jade)
    }

    func testSaphirIsAlwaysAvailable() {
        XCTAssertEqual(AppStyleID.sapphire.effective(isPremium: false), .sapphire)
        XCTAssertEqual(AppStyleID.sapphire.effective(isPremium: true), .sapphire)
    }

    func testEndOfPremiumKeepsTheSavedChoice() {
        var settings = AppSettings()
        settings.appStyle = .ruby
        XCTAssertEqual(settings.appStyle.effective(isPremium: false), .sapphire)
        XCTAssertEqual(settings.appStyle, .ruby, "Only the display changes: the choice comes back with Premium")
        XCTAssertEqual(settings.appStyle.effective(isPremium: true), .ruby)
    }
}
