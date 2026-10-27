import XCTest
@testable import Ardane

/// The twelve colors of the app (palette of 2026-10-27) replace the former ten styles; backgrounds follow the hue.
@MainActor
final class AppPaletteTests: XCTestCase {
    func testTwelveColorsWithTheirExactHexInOrder() {
        let expected: [(AppStyleID, String, String)] = [
            (.cobalt, "244FC1", "7094FF"), (.sapphire, "245B8F", "68B5F5"), (.iceBlue, "398FA8", "75DDF5"),
            (.aqua, "008C95", "45DDE0"), (.jade, "268577", "65D5BC"), (.pistachio, "718C42", "B8D987"),
            (.olive, "77752B", "C7C36A"), (.amber, "B86A13", "FFB454"), (.ruby, "C62845", "FF6B81"),
            (.rose, "C04472", "FF83B2"), (.orchid, "9854B8", "D5A0F5"), (.amethyst, "6841A5", "B69AFF"),
        ]
        XCTAssertEqual(AppStyle.all.count, 12)
        XCTAssertEqual(AppStyleID.allCases, expected.map(\.0))
        for (id, light, dark) in expected {
            let style = AppStyle.style(id)
            XCTAssertEqual(style.id, id)
            XCTAssertEqual(style.accentLight, light, "\(id)")
            XCTAssertEqual(style.accentDark, dark, "\(id)")
        }
    }

    func testFormerStylesDecodeToTheirClosestColor() throws {
        let former: [String: AppStyleID] = [
            "tessera": .jade, "ocean": .cobalt, "coral": .ruby, "lavender": .orchid, "sand": .amber,
            "graphite": .sapphire, "forest": .pistachio, "rose": .rose, "midnight": .amethyst, "neon": .aqua,
        ]
        for (name, style) in former {
            let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"\#(name)","currencyCode":"EUR"}"#.utf8))
            XCTAssertEqual(settings.appStyle, style, name)
            XCTAssertEqual(settings.currencyCode, "EUR")
            XCTAssertEqual(AppStyleID(named: name), style, name)
        }
        XCTAssertNil(AppStyleID(named: "nope"))
    }

    func testBackgroundsKeepTheSameCharacterWhateverTheHue() {
        for style in AppStyle.all {
            // Light screen very light, dark screen and cards very dark, as the former styles.
            XCTAssertGreaterThan(AppStyle.luminance(style.screenLight), 0.8, "\(style.id)")
            XCTAssertLessThan(AppStyle.luminance(style.screenDark), 0.03, "\(style.id)")
            XCTAssertLessThan(AppStyle.luminance(style.cardDark), 0.05, "\(style.id)")
            XCTAssertGreaterThan(AppStyle.luminance(style.cardDark), AppStyle.luminance(style.screenDark), "\(style.id)")
        }
        XCTAssertNotEqual(AppStyle.style(.ruby).screenDark, AppStyle.style(.cobalt).screenDark)
    }

    func testTextOnAPastelAccentInDarkModeIsDark() {
        // Pale accents (pistachio, olive, ice blue...) carry dark text in dark mode; deep ones carry white.
        XCTAssertNotEqual(AppStyle.style(.pistachio).inkOnDarkAccent, "FFFFFF")
        XCTAssertNotEqual(AppStyle.style(.iceBlue).inkOnDarkAccent, "FFFFFF")
        XCTAssertEqual(AppStyle.style(.cobalt).inkOnDarkAccent, "FFFFFF")
    }

    func testAutoModeIsNotTheCar() {
        // « Auto » (automatic appearance) has its own key, apart from « Auto » the car.
        XCTAssertEqual(AppearanceMode.system.title, tr("Auto", context: "mode"))
    }
}
