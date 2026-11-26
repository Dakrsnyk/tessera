import XCTest
@testable import Ardane

/// The figures of the deep part of « Analyse » (Finances): each one against a computation done by hand,
/// and the empty cases (no month, no income, no division by zero).
final class BudgetAnalysisTests: XCTestCase {
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Tuesday 15 September 2026, noon: 15 days elapsed out of 30.
    private var now: Date { date(9, 15) }

    private func spend(_ amount: Double, _ month: Int, _ day: Int, _ category: Int? = nil, note: String = "") -> Expense {
        Expense(amount: amount, categoryID: category.map { BudgetState.fixedID($0) }, note: note, date: date(month, day))
    }

    // MARK: Savings rate

    func testSavingsRateIsIncomeMinusSpendingOverIncome() throws {
        var state = BudgetState()
        state.incomes = [IncomeEntry(amount: 3_000, label: "Paie", date: date(9, 5))]
        state.expenses = [spend(600, 9, 3), spend(900, 9, 10), spend(500, 9, 20)]   // the 20th is still ahead
        let savings = try XCTUnwrap(BudgetAnalysis.savings(state, at: now))
        XCTAssertEqual(savings.earned, 3_000, accuracy: 0.001)
        XCTAssertEqual(savings.spent, 1_500, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(savings.rate), 0.5, accuracy: 0.0001)
        XCTAssertEqual(savings.kept, 1_500, accuracy: 0.001)
    }

    func testSavingsRateIsNegativeWhenSpendingExceedsIncome() throws {
        var state = BudgetState()
        state.incomes = [IncomeEntry(amount: 1_000, label: "Paie", date: date(9, 1))]
        state.expenses = [spend(1_500, 9, 2)]
        XCTAssertEqual(try XCTUnwrap(try XCTUnwrap(BudgetAnalysis.savings(state, at: now)).rate), -0.5, accuracy: 0.0001)
    }

    func testSavingsRateWithoutIncomeIsNilAndEmptyMonthIsNil() throws {
        var state = BudgetState()
        XCTAssertNil(BudgetAnalysis.savings(state, at: now), "Nothing noted")
        state.expenses = [spend(80, 9, 4)]
        let savings = try XCTUnwrap(BudgetAnalysis.savings(state, at: now))
        XCTAssertNil(savings.rate, "No income: no division by zero")
        XCTAssertEqual(savings.spent, 80, accuracy: 0.001)
    }

    func testSavingsIgnoresOtherMonths() {
        var state = BudgetState()
        state.incomes = [IncomeEntry(amount: 2_000, label: "Paie", date: date(8, 28))]
        state.expenses = [spend(300, 8, 30)]
        XCTAssertNil(BudgetAnalysis.savings(state, at: now))
    }

    // MARK: Projection

    func testProjectionKeepsTheCurrentPaceAndAddsWhatIsNotedAhead() throws {
        var state = BudgetState()
        state.expenses = [spend(100, 9, 2), spend(200, 9, 14), spend(50, 9, 20)]   // 300 so far, 50 ahead
        let projection = try XCTUnwrap(BudgetAnalysis.projection(state, at: now))
        XCTAssertEqual(projection.spentToDate, 300, accuracy: 0.001)
        XCTAssertEqual(projection.daysElapsed, 15)
        XCTAssertEqual(projection.daysInMonth, 30)
        XCTAssertEqual(projection.daysLeft, 15)
        XCTAssertEqual(projection.perDay, 20, accuracy: 0.001)
        XCTAssertEqual(projection.plannedAhead, 50, accuracy: 0.001)
        XCTAssertEqual(projection.projected, 300 + 20 * 15 + 50, accuracy: 0.001)
    }

    func testProjectionOnTheLastDayIsWhatWasSpent() throws {
        var state = BudgetState()
        state.expenses = [spend(90, 9, 10)]
        let projection = try XCTUnwrap(BudgetAnalysis.projection(state, at: date(9, 30, 20)))
        XCTAssertEqual(projection.daysLeft, 0)
        XCTAssertEqual(projection.projected, 90, accuracy: 0.001)
    }

    func testProjectionOnTheFirstDayHasNoDivisionByZero() throws {
        var state = BudgetState()
        state.expenses = [spend(30, 9, 1)]
        let projection = try XCTUnwrap(BudgetAnalysis.projection(state, at: date(9, 1, 9)))
        XCTAssertEqual(projection.daysElapsed, 1)
        XCTAssertEqual(projection.projected, 30 * 30, accuracy: 0.001)
    }

    func testProjectionIsNilWithoutAnySpending() {
        XCTAssertNil(BudgetAnalysis.projection(BudgetState(), at: now))
    }

    // MARK: Categories against their average

    private func trendsState() -> BudgetState {
        var state = BudgetState()
        state.expenses = [
            spend(200, 9, 3, 1),               // this month
            spend(100, 8, 5, 1),               // last month
            spend(50, 7, 5, 1), spend(150, 6, 5, 1),
            spend(999, 5, 5, 1),               // four months back: not in the average
            spend(70, 8, 5, 2),                // another category, only last month
        ]
        return state
    }

    func testCategoryAverageIsTheMeanOfTheThreeEarlierMonthsAtTheSameDate() throws {
        let state = trendsState()
        let trends = BudgetAnalysis.categoryTrends(state, at: now)
        let name = try XCTUnwrap(state.category(BudgetState.fixedID(1))).name
        let first = try XCTUnwrap(trends.first { $0.name == name })
        XCTAssertEqual(first.current, 200, accuracy: 0.001)
        XCTAssertEqual(first.previous, 100, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(first.average), 100, accuracy: 0.001, "(100 + 50 + 150) / 3")
        XCTAssertEqual(first.averageMonths, 3)
        XCTAssertEqual(try XCTUnwrap(first.differenceFromAverage), 100, accuracy: 0.001)
        let other = try XCTUnwrap(trends.first { $0.name != name })
        XCTAssertEqual(other.current, 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(other.average), 70.0 / 3, accuracy: 0.001, "Missing months count as 0 once the month has data")
    }

    func testBiggestRisesKeepOnlyRealRisesBiggestFirst() {
        let rises = BudgetAnalysis.biggestRises(BudgetAnalysis.categoryTrends(trendsState(), at: now))
        XCTAssertEqual(rises.count, 1, "The other category fell")
        XCTAssertEqual(rises.first?.differenceFromAverage ?? 0, 100, accuracy: 0.001)
    }

    func testTrendsWithoutHistoryHaveNoAverage() {
        var state = BudgetState()
        XCTAssertTrue(BudgetAnalysis.categoryTrends(state, at: now).isEmpty)
        state.expenses = [spend(40, 9, 2, 1)]
        let trends = BudgetAnalysis.categoryTrends(state, at: now)
        XCTAssertEqual(trends.count, 1)
        XCTAssertNil(trends.first?.average)
        XCTAssertEqual(trends.first?.averageMonths, 0)
        XCTAssertTrue(BudgetAnalysis.biggestRises(trends).isEmpty)
    }

    // MARK: Recurring spending

    func testSameLabelInThreeMonthsAtARegularAmountIsRecurring() {
        var state = BudgetState()
        state.expenses = [
            spend(15.99, 7, 3, note: "Netflix"), spend(15.99, 8, 3, note: "netflix"), spend(16.10, 9, 3, note: "Netflix "),
            spend(12, 8, 8, note: "Café"), spend(40, 9, 8, note: "Café"), spend(7, 7, 8, note: "Café"),     // amounts all over
            spend(60, 8, 9, note: "Garage"), spend(60, 9, 9, note: "Garage"),                              // two months only
        ]
        let found = BudgetAnalysis.recurring(state, at: now)
        XCTAssertEqual(found.map(\.label), ["Netflix"])
        XCTAssertEqual(found.first?.months, 3)
        XCTAssertEqual(found.first?.amount ?? 0, 15.99, accuracy: 0.001)
    }

    func testTwoOccurrencesInTheSameMonthDoNotMakeARecurrence() {
        var state = BudgetState()
        state.expenses = [spend(20, 9, 1, note: "Taxi"), spend(20, 9, 2, note: "Taxi"), spend(20, 9, 3, note: "Taxi"), spend(5, 9, 4)]
        XCTAssertTrue(BudgetAnalysis.recurring(state, at: now).isEmpty, "Three times in one month is one month")
        XCTAssertTrue(BudgetAnalysis.recurring(BudgetState(), at: now).isEmpty)
    }

    // MARK: Days of the week

    private func daily() -> BudgetState {
        var state = BudgetState()
        // 10 every day from the 1st to the 15th of September 2026, plus 40 on each Monday (the 7th and the 14th).
        state.expenses = (1...15).map { spend(10, 9, $0) } + [spend(40, 9, 7), spend(40, 9, 14)]
        return state
    }

    func testWeekdayAverageIsTheTotalOverTheNumberOfThatWeekday() throws {
        let days = try XCTUnwrap(BudgetAnalysis.weekdays(daily(), at: now))
        XCTAssertEqual(days.count, 7)
        let monday = try XCTUnwrap(days.first { $0.weekday == 2 })      // Calendar numbering: 2 = Monday
        XCTAssertEqual(monday.occurrences, 2)
        XCTAssertEqual(monday.total, 100, accuracy: 0.001)
        XCTAssertEqual(monday.average, 50, accuracy: 0.001)
        let tuesday = try XCTUnwrap(days.first { $0.weekday == 3 })     // the 1st, 8th and 15th
        XCTAssertEqual(tuesday.occurrences, 3)
        XCTAssertEqual(tuesday.average, 10, accuracy: 0.001)
        XCTAssertEqual(days.reduce(0) { $0 + $1.total }, 15 * 10 + 80, accuracy: 0.001)
        XCTAssertEqual(BudgetAnalysis.priciestWeekday(days)?.weekday, 2)
    }

    func testWeekdaysNeedEnoughHistory() {
        XCTAssertNil(BudgetAnalysis.weekdays(BudgetState(), at: now))
        var few = BudgetState()
        few.expenses = (1...5).map { spend(10, 9, $0) }
        XCTAssertNil(BudgetAnalysis.weekdays(few, at: now), "Fewer than 8 expenses")
        var short = BudgetState()
        short.expenses = (8...15).map { spend(10, 9, $0) }
        XCTAssertNil(BudgetAnalysis.weekdays(short, at: now), "Less than 14 days of history")
    }

    func testPriciestWeekdayIsNilWhenNothingWasSpent() {
        XCTAssertNil(BudgetAnalysis.priciestWeekday([BudgetAnalysis.WeekdaySpend(weekday: 2, total: 0, occurrences: 0)]))
    }
}
