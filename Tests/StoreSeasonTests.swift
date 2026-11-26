import XCTest
@testable import Ardane

/// The themed packs, the style of the week and the seasons' collections.
@MainActor
final class StoreSeasonTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testTheSeasonsFollowTheCalendar() {
        XCTAssertEqual(StoreSeason.current(date(2026, 10, 9)), .halloween)
        XCTAssertEqual(StoreSeason.current(date(2026, 12, 2)), .christmas)
        XCTAssertNil(StoreSeason.current(date(2026, 11, 15)))
        XCTAssertNil(StoreSeason.current(date(2027, 3, 1)))
    }

    func testSeasonalAndThemedPacksStayApartFromThePacksOfAllYear() {
        let halloween = PackCatalog.seasonal(.halloween)
        let christmas = PackCatalog.seasonal(.christmas)
        XCTAssertGreaterThanOrEqual(halloween.count, 4)
        XCTAssertGreaterThanOrEqual(christmas.count, 2)
        let everyday = Set(PackCatalog.everyday.map(\.id))
        XCTAssertTrue((halloween + christmas + PackCatalog.themed).allSatisfy { !everyday.contains($0.id) })
        XCTAssertEqual(PackCatalog.themed.map(\.themeID), [.space, .mars, .nature, .botanical, .ocean])
        // Each themed or seasonal pack has a premium style of its own.
        let styles = (halloween + christmas + PackCatalog.themed).map(\.themeID)
        XCTAssertEqual(Set(styles).count, styles.count)
        XCTAssertTrue(styles.allSatisfy { ThemeCatalog.theme($0).isPremium })
    }

    func testTheStyleOfTheWeekIsPremiumAndChangesEachWeek() {
        let monday = StoreEdition.style(now: date(2026, 10, 5))
        XCTAssertTrue(monday.isPremium)
        XCTAssertEqual(StoreEdition.style(now: date(2026, 10, 11)).id, monday.id)
        XCTAssertNotEqual(StoreEdition.style(now: date(2026, 10, 12)).id, monday.id)
        XCTAssertNotNil(StyleCatalog.look(monday.id))
        // The weekly step of 37 goes through every Premium style only if it shares no divisor with their count.
        var (x, y) = (37, StyleCatalog.premiumCount)
        while y != 0 { (x, y) = (y, x % y) }
        XCTAssertEqual(x, 1, "Le pas de 37 doit être premier avec le nombre de styles Premium")
    }

    func testThemedWorldsHaveTheirHomeScreens() {
        XCTAssertEqual(HomeSetupCatalog.themed.count, PackCatalog.themed.count)
    }

    /// The new motifs draw something.
    func testTheNewMotifsDraw() {
        for kind in [TextureKind.stars, .snow, .waves, .web, .leaves] {
            XCTAssertFalse(TexturePattern(kind: kind).path(in: CGRect(x: 0, y: 0, width: 170, height: 170)).isEmpty, "\(kind)")
        }
    }
}
