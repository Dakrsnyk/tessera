import XCTest
@testable import Ardane

@MainActor
final class AppAccentTests: XCTestCase {
    func testTenAccentsWithExactHexInOrder() {
        let expected: [(AppAccentID, String, String)] = [
            (.red, "FF3B30", "FF453A"), (.orange, "FF9500", "FF9F0A"), (.yellow, "FFCC00", "FFD60A"),
            (.green, "34C759", "30D158"), (.teal, "30B0C7", "40C8E0"), (.blue, "007AFF", "0A84FF"),
            (.indigo, "5856D6", "5E5CE6"), (.purple, "AF52DE", "BF5AF2"), (.pink, "FF2D55", "FF375F"),
            (.gray, "8E8E93", "98989D"),
        ]
        XCTAssertEqual(AppAccentID.allCases, expected.map(\.0))
        for (accent, light, dark) in expected {
            XCTAssertEqual(accent.lightHex, light)
            XCTAssertEqual(accent.darkHex, dark)
        }
    }

    func testTitlesAreUnique() {
        let titles = AppAccentID.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
        XCTAssertFalse(titles.contains(""))
    }

    func testYellowHasDarkInkOthersWhite() {
        for accent in AppAccentID.allCases {
            XCTAssertEqual(accent.inkHex, accent == .yellow ? "1A1408" : "FFFFFF")
        }
    }

    func testMigrationFromOldStyles() {
        let expected: [AppStyleID: AppAccentID] = [
            .tessera: .teal, .ocean: .blue, .coral: .red, .lavender: .purple, .sand: .orange,
            .graphite: .gray, .forest: .green, .rose: .pink, .midnight: .indigo, .neon: .teal,
        ]
        XCTAssertEqual(expected.count, AppStyleID.allCases.count)
        for style in AppStyleID.allCases {
            XCTAssertEqual(AppAccentID.migrated(from: style), expected[style])
        }
    }

    func testOldSettingsWithoutAccentAreMigrated() throws {
        let json = #"{"appStyle":"ocean","currencyCode":"EUR","appearance":"dark","profileName":"Léa"}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.accent, .blue)
        XCTAssertEqual(settings.appStyle, .ocean)
        XCTAssertEqual(settings.currencyCode, "EUR")
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertEqual(settings.profileName, "Léa")
    }

    func testUnreadableAccentFallsBackToMigration() throws {
        let json = #"{"appStyle":"forest","accent":"nope"}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.accent, .green)
    }

    func testDefaultAccentIsTeal() {
        XCTAssertEqual(AppSettings().accent, .teal)
    }

    func testAccentRoundTrip() throws {
        for accent in AppAccentID.allCases {
            var settings = AppSettings()
            settings.appStyle = .midnight
            settings.accent = accent
            let data = try JSONEncoder().encode(settings)
            let back = try JSONDecoder().decode(AppSettings.self, from: data)
            XCTAssertEqual(back.accent, accent)
            XCTAssertEqual(back.appStyle, .midnight)
        }
    }

    func testBackgroundsDoNotDependOnAccent() {
        var a = AppSettings()
        a.appStyle = .coral
        a.accent = .red
        var b = a
        b.accent = .blue
        let styleA = AppStyle.style(a), styleB = AppStyle.style(b)
        XCTAssertEqual(styleA.chosenAccent, .red)
        XCTAssertEqual(styleB.chosenAccent, .blue)
        XCTAssertEqual(styleA.screenLight, styleB.screenLight)
        XCTAssertEqual(styleA.screenDark, styleB.screenDark)
        XCTAssertEqual(styleA.cardDark, styleB.cardDark)
        XCTAssertEqual(styleA.accentLight, styleB.accentLight)
        XCTAssertEqual(styleA.accentDark, styleB.accentDark)
        XCTAssertEqual(styleA.screen.hexString, styleB.screen.hexString)
        XCTAssertEqual(styleA.card.hexString, styleB.card.hexString)
        // The background gradient (AppFill.depth) reads only the fields compared above.
    }
}
