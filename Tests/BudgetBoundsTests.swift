import XCTest
@testable import Ardane

/// Finances at the edges: nothing, zero, very large amounts, a budget of zero, an expense without a known
/// category, month limits, bills on the 31st and savings goals. Figures are never made up and never NaN.
final class BudgetBoundsTests: XCTestCase {
    private func moment(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testAnEmptyBudgetHasNothingSpentAndAllItsMonthLeft() {
        let state = BudgetState()
        let now = moment(2026, 9, 15)
        XCTAssertEqual(BudgetMath.spentThisMonth(state, at: now), 0)
        XCTAssertEqual(BudgetMath.remaining(state, at: now), state.monthlyBudget)
        XCTAssertTrue(BudgetMath.categoryStatus(state, at: now).allSatisfy { $0.limit > 0 && $0.spent == 0 })
        XCTAssertEqual(BudgetMath.months(state, count: 3, at: now).map(\.spent), [0, 0, 0])
        XCTAssertEqual(BudgetMath.netWorth(state), 0)
    }

    func testAZeroAmountChangesNothingAndStillCountsAsAnExpense() {
        var state = BudgetState()
        state.add(Expense(amount: 0, categoryID: BudgetState.fixedID(1), date: moment(2026, 9, 3)))
        XCTAssertEqual(BudgetMath.spentThisMonth(state, at: moment(2026, 9, 15)), 0)
        XCTAssertEqual(state.expenses.count, 1)
        XCTAssertEqual(BudgetMath.remaining(state, at: moment(2026, 9, 15)), 2_000)
    }

    func testAMonthlyBudgetOfZeroNeverGoesNegativePerDayOrNotANumber() {
        var state = BudgetState()
        state.monthlyBudget = 0
        state.add(Expense(amount: 40, categoryID: BudgetState.fixedID(1), date: moment(2026, 9, 3)))
        let now = moment(2026, 9, 15)
        XCTAssertEqual(BudgetMath.remaining(state, at: now), -40)
        XCTAssertEqual(BudgetMath.perDayLeft(state, at: now), 0, "Over budget: nothing left per day, not a negative figure")
        // The last day of the month and the first one: the number of days left is never zero.
        for day in [moment(2026, 9, 30, 23, 59), moment(2026, 9, 1, 0, 0)] {
            XCTAssertGreaterThanOrEqual(BudgetMath.daysLeftInMonth(day), 1)
            XCTAssertTrue(BudgetMath.perDayLeft(state, at: day).isFinite)
        }
    }

    func testVeryLargeAmountsAddUpExactlyAndSurviveSaving() throws {
        var state = BudgetState()
        state.monthlyBudget = 1_000_000_000_000
        state.add(Expense(amount: 999_999_999_999.5, categoryID: BudgetState.fixedID(1), date: moment(2026, 9, 3)))
        state.add(Expense(amount: 0.5, categoryID: BudgetState.fixedID(2), date: moment(2026, 9, 4)))
        let now = moment(2026, 9, 15)
        XCTAssertEqual(BudgetMath.spentThisMonth(state, at: now), 1_000_000_000_000)
        XCTAssertEqual(BudgetMath.remaining(state, at: now), 0)
        XCTAssertTrue(BudgetMath.perDayLeft(state, at: now).isFinite)
        let reread = try JSONDecoder().decode(BudgetState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(reread.expenses.map(\.amount), [999_999_999_999.5, 0.5])
        XCTAssertEqual(reread.monthlyBudget, 1_000_000_000_000)
    }

    func testAnExpenseWithAnUnknownCategoryIsKeptWithoutOne() {
        var state = BudgetState()
        let removed = UUID()
        state.add(Expense(amount: 25, categoryID: removed, date: moment(2026, 9, 3)))
        state.add(Expense(amount: 5, categoryID: nil, date: moment(2026, 9, 4)))
        let now = moment(2026, 9, 15)
        let totals = BudgetMath.byCategory(state, in: BudgetMath.monthInterval(now), now: now)
        XCTAssertEqual(totals.map(\.amount).reduce(0, +), 30, "Nothing is lost when the category no longer exists")
        XCTAssertTrue(totals.allSatisfy { $0.category == nil })
        XCTAssertNil(state.category(removed))
        XCTAssertEqual(BudgetMath.spentThisMonth(state, at: now), 30)
    }

    func testACategoryWithoutALimitHasNoRatioAndIsNeverOver() throws {
        var state = BudgetState()
        let other = BudgetState.fixedID(6)
        state.add(Expense(amount: 5_000, categoryID: other, date: moment(2026, 9, 3)))
        let status = try XCTUnwrap(BudgetMath.categoryStatus(state, at: moment(2026, 9, 15)).first { $0.category.id == other })
        XCTAssertEqual(status.spent, 5_000, "Spending in a category without a limit is listed")
        XCTAssertNil(status.ratio)
        XCTAssertFalse(status.isOver)
    }

    func testAnExpenseJustBeforeMidnightOfTheLastDayStaysInItsMonth() {
        var state = BudgetState()
        state.add(Expense(amount: 10, categoryID: BudgetState.fixedID(1), date: moment(2026, 9, 30, 23, 59)))
        state.add(Expense(amount: 20, categoryID: BudgetState.fixedID(1), date: moment(2026, 10, 1, 0, 1)))
        let months = BudgetMath.months(state, count: 2, at: moment(2026, 10, 15))
        XCTAssertEqual(months.map(\.spent), [10, 20])
        // February of a leap year has its 29th.
        var leap = BudgetState()
        leap.add(Expense(amount: 7, categoryID: BudgetState.fixedID(1), date: moment(2028, 2, 29, 23, 30)))
        XCTAssertEqual(BudgetMath.spentThisMonth(leap, at: moment(2028, 2, 1)), 7)
        XCTAssertEqual(BudgetMath.spentThisMonth(leap, at: moment(2028, 3, 1)), 0)
    }

    /// An expense noted for a day with no hour is saved at midnight: on the 1st it belongs to the new month only.
    func testAnExpenseAtMidnightOfTheFirstCountsInTheNewMonthOnly() {
        var state = BudgetState()
        state.add(Expense(amount: 100, categoryID: BudgetState.fixedID(1), date: moment(2026, 10, 1, 0, 0)))
        let months = BudgetMath.months(state, count: 2, at: moment(2026, 10, 15))
        XCTAssertEqual(months.map(\.spent), [0, 100], "Counted once, in October")
        XCTAssertEqual(BudgetMath.spentThisMonth(state, at: moment(2026, 9, 20)), 0)
    }

    func testAnIncomeAtMidnightOfTheFirstCountsInTheNewMonthOnly() {
        var state = BudgetState()
        state.addIncome(IncomeEntry(amount: 1_500, label: "Salaire", date: moment(2026, 10, 1, 0, 0)))
        let months = BudgetMath.months(state, count: 2, at: moment(2026, 10, 15))
        XCTAssertEqual(months.map(\.earned), [0, 1_500], "Paid once, in October")
    }

    func testABillOnThe31stFallsOnARealDayAndAYearlyOneCostsATwelfth() {
        let anchor = moment(2026, 1, 31)
        let yearly = Bill(name: "Gym", amount: 120, anchorDate: anchor, period: .yearly)
        XCTAssertEqual(yearly.monthlyCost, 10)
        let monthly = Bill(name: "Loyer", amount: 900, anchorDate: anchor, period: .monthly)
        for now in [moment(2026, 2, 15), moment(2028, 2, 15), moment(2024, 12, 31, 23, 59)] {
            let due = monthly.nextDue(after: now)
            XCTAssertGreaterThanOrEqual(due, DateMath.startOfDay(now), "The next date is never in the past")
            XCTAssertLessThan(due.timeIntervalSince(now), 32 * 86_400, "A monthly bill falls within a month")
        }
        // An anchor far in the future of the day asked: the date found is still the first one from that day.
        let asked = moment(2026, 9, 28)
        let future = Bill(name: "Assurance", amount: 50, anchorDate: moment(2030, 6, 10), period: .monthly)
        let found = future.nextDue(after: asked)
        XCTAssertGreaterThanOrEqual(found, DateMath.startOfDay(asked))
        XCTAssertLessThan(found.timeIntervalSince(asked), 32 * 86_400)
    }

    func testSavingsGoalsIgnoreAnEmptyOrNegativePaymentAndStayWithinTheirBar() {
        var state = BudgetState()
        let goal = SavingsGoal(name: "Voyage", target: 1_000, saved: 950)
        state.goals = [goal]
        state.deposit(0, toGoal: goal.id)
        state.deposit(-200, toGoal: goal.id)
        state.deposit(50, toGoal: UUID())
        XCTAssertEqual(state.goals[0].saved, 950, "Nothing changes for an empty, negative or unknown payment")
        state.deposit(200, toGoal: goal.id)
        XCTAssertEqual(state.goals[0].saved, 1_150)
        XCTAssertEqual(state.goals[0].progress, 1, "The bar stops at full")
        XCTAssertEqual(SavingsGoal(name: "Sans cible", target: 0, saved: 10).progress, 0, "No target: no division by zero")
        XCTAssertNil(BudgetMath.monthlyToReach(state.goals[0], at: moment(2026, 9, 1)), "A goal reached asks for nothing more")
    }
}
