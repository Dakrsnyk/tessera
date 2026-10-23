import XCTest
@testable import Tessera

/// The budget of Finances follows the chosen day: what is left of the month's budget at the end of that day
/// (the spending from the 1st to that day), the days it has to cover, and the same figures for today.
final class FinancesDayBudgetTests: XCTestCase {
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// A 2 000 budget with 80 on the 3rd, 120 on the 10th and 300 on the 20th of September.
    private func september() -> BudgetState {
        var state = BudgetState()
        state.monthlyBudget = 2_000
        state.expenses = [
            Expense(amount: 80, categoryID: BudgetState.fixedID(1), date: date(9, 3)),
            Expense(amount: 120, categoryID: BudgetState.fixedID(2), date: date(9, 10)),
            Expense(amount: 300, categoryID: BudgetState.fixedID(1), date: date(9, 20)),
        ]
        return state
    }

    func testAPastDayStopsTheSpendingAtItsEnd() {
        let state = september()
        let now = date(9, 25)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 2), now: now), 2_000, accuracy: 0.001, "Nothing spent before the 3rd")
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 3, 8), now: now), 1_920, accuracy: 0.001, "The day's own spending counts, whatever the hour")
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 10, 0), now: now), 1_800, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 19), now: now), 1_800, accuracy: 0.001, "The 20th is not counted yet")
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 20), now: now), 1_500, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.spentThisMonth(state, throughDay: date(9, 10), now: now), 200, accuracy: 0.001)
    }

    func testTodayKeepsTheCurrentValue() {
        var state = september()
        // Something noted for a later day of the month still counts today, as before.
        state.expenses.append(Expense(amount: 50, categoryID: nil, date: date(9, 28)))
        let now = date(9, 25)
        let current = BudgetMath.remaining(state, at: now)
        XCTAssertEqual(current, 1_450, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: now, now: now), current, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 25, 7), now: now), current, accuracy: 0.001, "Another hour of today")
        XCTAssertEqual(BudgetMath.spentThisMonth(state, throughDay: now, now: now), BudgetMath.spentThisMonth(state, at: now), accuracy: 0.001)
        XCTAssertEqual(BudgetMath.perDayLeft(state, throughDay: now, now: now), BudgetMath.perDayLeft(state, at: now), accuracy: 0.001)
        XCTAssertEqual(BudgetMath.daysToCover(throughDay: now, now: now), BudgetMath.daysLeftInMonth(now))
    }

    func testAnotherMonthUsesItsOwnSpending() {
        var state = september()
        state.expenses.append(Expense(amount: 400, categoryID: nil, date: date(8, 5)))
        state.expenses.append(Expense(amount: 250, categoryID: nil, date: date(8, 25)))
        let now = date(9, 25)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(8, 15), now: now), 1_600, accuracy: 0.001, "August only, up to the 15th")
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(8, 31), now: now), 1_350, accuracy: 0.001, "August to the end")
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 1), now: now), 2_000, accuracy: 0.001, "September starts again from the budget")
    }

    func testNoSpendingLeavesTheWholeBudget() {
        var state = BudgetState()
        state.monthlyBudget = 1_200
        let now = date(9, 25)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 12), now: now), 1_200, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: now, now: now), 1_200, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.perDayLeft(state, throughDay: date(9, 15), now: now), 1_200.0 / 15, accuracy: 0.001)
    }

    func testPerDayLeftSpreadsWhatIsLeftOverTheDaysAfterThatDay() {
        let state = september()
        let now = date(9, 25)
        // Left on the evening of the 10th: 1 800, over the 20 days from the 11th to the 30th.
        XCTAssertEqual(BudgetMath.daysToCover(throughDay: date(9, 10), now: now), 20)
        XCTAssertEqual(BudgetMath.perDayLeft(state, throughDay: date(9, 10), now: now), 90, accuracy: 0.001)
        // Today: 1 500 over the 6 days from the 25th to the 30th, as the screen showed before.
        XCTAssertEqual(BudgetMath.perDayLeft(state, throughDay: now, now: now), 250, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.perDayLeft(state, at: now), 250, accuracy: 0.001)
        // Over the budget, nothing is left to spend per day.
        var over = state
        over.monthlyBudget = 100
        XCTAssertEqual(BudgetMath.perDayLeft(over, throughDay: date(9, 10), now: now), 0, accuracy: 0.001)
    }

    func testAFixedBillCountsFromItsDate() {
        var state = BudgetState()
        state.monthlyBudget = 2_000
        state.bills = [Bill(name: "Loyer", amount: 100, anchorDate: date(9, 5, 0))]
        let now = date(9, 25)
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 4), now: now), 2_000, accuracy: 0.001, "Not paid yet")
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: date(9, 5), now: now), 1_900, accuracy: 0.001, "Paid on the 5th")
        XCTAssertEqual(BudgetMath.remaining(state, throughDay: now, now: now), BudgetMath.remaining(state, at: now), accuracy: 0.001)
    }

    func testTheOtherMonthFiguresFollowTheDayToo() {
        var state = september()
        state.incomes = [
            IncomeEntry(amount: 1_500, label: "Salaire", date: date(9, 1)),
            IncomeEntry(amount: 200, label: "Remboursement", date: date(9, 15)),
        ]
        let now = date(9, 25)
        XCTAssertEqual(BudgetMath.earned(state, throughDay: date(9, 10), now: now), 1_500, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.earned(state, throughDay: date(9, 15), now: now), 1_700, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.earned(state, throughDay: now, now: now), BudgetMath.earned(state, in: BudgetMath.monthInterval(now), now: now), accuracy: 0.001)

        let groceries = BudgetState.fixedID(1)
        let past = BudgetMath.categoryStatus(state, throughDay: date(9, 10), now: now)
        XCTAssertEqual(past.first { $0.category.id == groceries }?.spent ?? -1, 80, accuracy: 0.001, "The 20th's 300 is not in yet")
        let today = BudgetMath.categoryStatus(state, throughDay: now, now: now)
        XCTAssertEqual(today.first { $0.category.id == groceries }?.spent ?? -1, 380, accuracy: 0.001)
        XCTAssertEqual(today.map(\.category.id), BudgetMath.categoryStatus(state, at: now).map(\.category.id))
    }
}
