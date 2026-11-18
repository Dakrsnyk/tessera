import XCTest
@testable import Ardane

/// The figures of the hybrid Business page (direction 5, 2026-11-17): the share of the goal reached by the revenue
/// the screen shows, and what is left to sell each day to reach it (the rule of the « Objectif du mois » widget).
final class BusinessHybridTests: XCTestCase {
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    func testTheGoalShareFollowsTheRevenueShown() {
        XCTAssertEqual(BusinessMath.goalShare(revenue: 4_859, goal: 12_000), 4_859.0 / 12_000, accuracy: 0.0001)
        XCTAssertEqual(BusinessMath.goalShare(revenue: 0, goal: 12_000), 0, accuracy: 0.0001)
        XCTAssertEqual(BusinessMath.goalShare(revenue: 15_000, goal: 12_000), 1.25, accuracy: 0.0001, "Past the goal, the share goes over 100 %")
    }

    func testNoGoalMeansNoShare() {
        XCTAssertEqual(BusinessMath.goalShare(revenue: 500, goal: 0), 0)
        XCTAssertNil(BusinessMath.neededPerDay(goal: 0, revenue: 500, at: date(11, 12)))
    }

    func testWhatIsLeftIsSpreadOverTheDaysLeftInTheMonth() throws {
        let now = date(11, 12)
        let perDay = try XCTUnwrap(BusinessMath.neededPerDay(goal: 12_000, revenue: 4_859, at: now))
        XCTAssertEqual(perDay, (12_000 - 4_859) / Double(BudgetMath.daysLeftInMonth(now)), accuracy: 0.0001)
        XCTAssertGreaterThan(perDay, 0)
        // Later in the month, the same gap weighs more each day.
        let later = try XCTUnwrap(BusinessMath.neededPerDay(goal: 12_000, revenue: 4_859, at: date(11, 25)))
        XCTAssertGreaterThan(later, perDay)
    }

    func testAGoalReachedLeavesNothingToSell() {
        XCTAssertNil(BusinessMath.neededPerDay(goal: 12_000, revenue: 12_000, at: date(11, 12)))
        XCTAssertNil(BusinessMath.neededPerDay(goal: 12_000, revenue: 13_500, at: date(11, 12)))
    }
}
