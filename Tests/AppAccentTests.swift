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

    func testTheWholeThemeFollowsTheAccent() {
        var a = AppSettings()
        a.accent = .red
        var b = a
        b.accent = .blue
        let styleA = AppStyle.style(a), styleB = AppStyle.style(b)
        XCTAssertEqual(styleA.chosenAccent, .red)
        XCTAssertEqual(styleB.chosenAccent, .blue)
        // Backgrounds change with the accent...
        XCTAssertNotEqual(styleA.screenLight, styleB.screenLight)
        XCTAssertNotEqual(styleA.screenDark, styleB.screenDark)
        XCTAssertNotEqual(styleA.cardDark, styleB.cardDark)
        // ... and are tints of its own light and dark values (the light gradient reads accentLight).
        XCTAssertEqual(styleB.accentLight, "007AFF")
        XCTAssertEqual(styleB.accentDark, "0A84FF")
        XCTAssertEqual(styleB.screenLight, AppStyle.mixHex("FFFFFF", "007AFF", 0.08))
        XCTAssertEqual(styleB.screenDark, AppStyle.mixHex("000000", "0A84FF", 0.08))
        // The same accent gives the same theme whatever the former style was.
        a.accent = .blue
        a.appStyle = .coral
        XCTAssertEqual(AppStyle.style(a).screenLight, styleB.screenLight)
        XCTAssertEqual(AppStyle.style(a).fontDesign, .default)
    }

    func testMixHexMovesTowardsTheTint() {
        XCTAssertEqual(AppStyle.mixHex("FFFFFF", "007AFF", 0.08), "EBF4FF")
        XCTAssertEqual(AppStyle.mixHex("000000", "FFFFFF", 0), "000000")
        XCTAssertEqual(AppStyle.mixHex("000000", "FFFFFF", 1), "FFFFFF")
        // Every accent gives a light screen and a dark screen that stay light and dark.
        for accent in AppAccentID.allCases {
            let style = AppStyle.themed(accent)
            XCTAssertGreaterThan(UInt64(style.screenLight, radix: 16) ?? 0, 0xE0E0E0 - 0x101010, accent.rawValue)
            XCTAssertLessThan(UInt64(style.screenDark, radix: 16) ?? .max, 0x202020, accent.rawValue)
        }
    }
}
