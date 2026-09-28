import XCTest
@testable import Tessera

final class CoreLogicTests: XCTestCase {
    private var cal: Calendar { DateMath.calendar }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testDaysBetweenIgnoresTimeOfDay() {
        XCTAssertEqual(DateMath.daysBetween(date(2026, 1, 1, 23), date(2026, 1, 2, 1)), 1)
        XCTAssertEqual(DateMath.daysBetween(date(2026, 3, 10), date(2026, 3, 1)), -9)
    }

    func testMonthGridStartsOnMonday() {
        // 1 September 2026 is a Tuesday: one empty cell before it.
        let grid = DateMath.monthGrid(for: date(2026, 9, 15))
        XCTAssertNil(grid[0])
        XCTAssertEqual(cal.component(.day, from: grid[1]!), 1)
        XCTAssertEqual(grid.count % 7, 0)
    }

    func testYearProgressIsBounded() {
        let start = DateMath.progress(of: .year, at: date(2026, 1, 1, 0))
        let end = DateMath.progress(of: .year, at: date(2026, 12, 31, 23))
        XCTAssertEqual(start, 0, accuracy: 0.001)
        XCTAssertGreaterThan(end, 0.99)
        XCTAssertLessThanOrEqual(end, 1)
    }

    func testCountdownUntilAndSince() {
        var options = DesignOptions()
        options.countdownDate = date(2026, 10, 10)
        options.countdownMode = .until
        let until = CountdownInfo(options: options, now: date(2026, 10, 1))
        XCTAssertEqual(until.days, 9)
        XCTAssertFalse(until.isPast)

        options.countdownMode = .since
        let since = CountdownInfo(options: options, now: date(2026, 10, 20))
        XCTAssertEqual(since.days, 10)
    }

    func testHabitStreakCountsConsecutiveDays() {
        var habit = Habit(name: "Lire", symbol: "book.fill", colorHex: "2F8F7A")
        let today = date(2026, 5, 20)
        for offset in 0..<4 {
            habit.toggle(on: cal.date(byAdding: .day, value: -offset, to: today)!)
        }
        XCTAssertEqual(habit.streak(asOf: today), 4)
        habit.toggle(on: today)
        // Today not done yet: the streak still counts up to yesterday.
        XCTAssertEqual(habit.streak(asOf: today), 3)
    }

    func testHydrationNeverGoesNegative() {
        var state = HydrationState()
        let now = date(2026, 5, 20)
        state.add(-3, on: now)
        XCTAssertEqual(state.glasses(on: now), 0)
        state.add(2, on: now)
        XCTAssertEqual(state.glasses(on: now), 2)
    }

    func testMoneyAccrual() {
        let start = date(2026, 4, 1, 0)
        let state = MoneyState(items: [
            MoneyItem(name: "Salaire", amount: 3_000, period: .month, isIncome: true),
            MoneyItem(name: "Loyer", amount: 1_000, period: .month, isIncome: false),
        ], startDate: start)
        let summary = MoneyMath.summary(state, at: date(2026, 4, 11, 0))
        let perDay = 3_000 / (365.0 / 12.0)
        XCTAssertEqual(summary.perDayIncome, perDay, accuracy: 0.001)
        XCTAssertEqual(summary.totalIncome, perDay * 10, accuracy: 0.01)
        XCTAssertEqual(summary.totalNet, (perDay - 1_000 / (365.0 / 12.0)) * 10, accuracy: 0.01)
    }

    func testFreeDesignIsNotDowngraded() {
        let design = WidgetDesign(kind: .clock)
        XCTAssertFalse(design.usesPremiumFeatures)
        XCTAssertEqual(design.downgradedForFree(), design)
    }

    func testPremiumStylingIsDowngradedForFreeUsers() {
        let design = WidgetDesign(kind: .clock, themeID: .aurora, accentHex: "123456", background: .gradient, font: .serif)
        let free = design.downgradedForFree()
        XCTAssertEqual(free.themeID, .minimal)
        XCTAssertEqual(free.background, .theme)
        XCTAssertEqual(free.font, .theme)
        XCTAssertEqual(free.accentHex, Palette.defaultAccent)
    }

    func testDesignDecodingToleratesMissingFields() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"countdown"}"#
        let decoder = JSONDecoder()
        let design = try decoder.decode(WidgetDesign.self, from: Data(json.utf8))
        XCTAssertEqual(design.kind, .countdown)
        XCTAssertEqual(design.themeID, .minimal)
        XCTAssertEqual(design.name, WidgetKind.countdown.title)
    }

    func testDeepLinkRoundTrip() {
        let id = UUID()
        XCTAssertEqual(DeepLink(url: DeepLink.design(id).url), .design(id))
        XCTAssertEqual(DeepLink(url: DeepLink.premium.url), .premium)
        XCTAssertNil(DeepLink(url: URL(string: "https://example.com")!))
    }

    func testTemplatesAreConsistent() {
        let ids = TemplateCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Template identifiers must be unique")
        for template in TemplateCatalog.all {
            XCTAssertFalse(template.kind.families.isEmpty)
        }
    }
}
