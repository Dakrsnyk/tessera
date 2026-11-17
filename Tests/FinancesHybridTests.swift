import XCTest
@testable import Ardane

/// The figures of the hybrid Finances page (refonte du 2026-11-16) : the share of the month gone by, what the
/// bills and fixed expenses still to come will take, the list of what comes back soon, the day-by-day total of
/// the month, the categories ahead of their pace, the balance at the start of a day, the findings of « Analyse »
/// and the search of « Opérations ».
final class FinancesHybridTests: XCTestCase {
    private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Thursday 12 November 2026 at noon, the day of the mock-ups.
    private var now: Date { date(11, 12) }

    /// Internet on the 13th, the car insurance on the 17th, Netflix on the 3rd (all monthly), a phone plan as a fixed
    /// expense on the 20th and a salary as a fixed income on the 5th.
    private func november() -> BudgetState {
        var state = BudgetState()
        state.monthlyBudget = 1_000
        state.bills = [
            Bill(name: "Internet", amount: 45, anchorDate: date(10, 13)),
            Bill(name: "Assurance auto", amount: 62, anchorDate: date(10, 17)),
            Bill(name: "Netflix", amount: 16.99, anchorDate: date(10, 3), isSubscription: true),
        ]
        state.fixedFlows = [
            MoneyItem(name: "Forfait cellulaire", amount: 35, period: .month, isIncome: false, date: date(10, 20)),
            MoneyItem(name: "Salaire", amount: 1_150, period: .month, isIncome: true, date: date(10, 5)),
        ]
        state.expenses = [Expense(amount: 300, categoryID: BudgetState.fixedID(1), date: date(11, 5))]
        return state
    }

    func testTheShareOfTheMonthCountsTheChosenDay() {
        XCTAssertEqual(BudgetMath.monthFraction(throughDay: date(11, 1)), 1.0 / 30, accuracy: 0.0001)
        XCTAssertEqual(BudgetMath.monthFraction(throughDay: date(11, 12, 23)), 12.0 / 30, accuracy: 0.0001)
        XCTAssertEqual(BudgetMath.monthFraction(throughDay: date(11, 30)), 1, accuracy: 0.0001)
        XCTAssertEqual(BudgetMath.monthFraction(throughDay: date(10, 31)), 1, accuracy: 0.0001, "October has 31 days")
    }

    func testWhatIsStillDueThisMonthLeavesTheIncomesAndNextMonthOut() {
        let state = november()
        // After the 12th: Internet (13th), the insurance (17th), the phone plan (20th); Netflix is on 3 December.
        XCTAssertEqual(BudgetMath.dueRestOfMonth(state, afterDay: now), 45 + 62 + 35, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.dueRestOfMonth(state, afterDay: date(11, 17)), 35, accuracy: 0.001, "The day itself is already counted")
        XCTAssertEqual(BudgetMath.dueRestOfMonth(state, afterDay: date(11, 30)), 0, accuracy: 0.001, "Nothing after the last day")
    }

    func testAFixedExpenseNamedLikeABillIsNotDueTwice() {
        var state = november()
        state.fixedFlows.append(MoneyItem(name: "Internet", amount: 45, period: .month, isIncome: false, date: date(10, 13)))
        XCTAssertEqual(BudgetMath.dueRestOfMonth(state, afterDay: now), 45 + 62 + 35, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.upcoming(state, at: now, within: 14).filter { $0.name == "Internet" }.count, 1)
    }

    func testWhatIsLeftOnceTheBillsArePaid() {
        let state = november()
        let remaining = BudgetMath.remaining(state, throughDay: now, now: now)
        // 300 noted and Netflix on the 3rd.
        XCTAssertEqual(remaining, 1_000 - 300 - 16.99, accuracy: 0.001)
        let after = BudgetMath.leftAfterDue(state, throughDay: now, now: now)
        XCTAssertEqual(after.left, remaining - 142, accuracy: 0.001)
        XCTAssertEqual(after.perDay, after.left / Double(BudgetMath.daysToCover(throughDay: now, now: now)), accuracy: 0.001)

        var tight = state
        tight.monthlyBudget = 400
        let short = BudgetMath.leftAfterDue(tight, throughDay: now, now: now)
        XCTAssertLessThan(short.left, 0, "The bills can take more than what is left")
        XCTAssertEqual(short.perDay, 0, "Never a negative amount per day")
    }

    func testWhatComesBackSoonIsSortedAndBounded() {
        let state = november()
        let soon = BudgetMath.upcoming(state, at: now, within: 14)
        XCTAssertEqual(soon.map(\.name), ["Internet", "Assurance auto", "Forfait cellulaire"])
        XCTAssertEqual(soon.map(\.days), [1, 5, 8])
        XCTAssertFalse(soon.contains { $0.isIncome }, "The salary comes back on 5 December")

        let month = BudgetMath.upcoming(state, at: now, within: 30)
        XCTAssertEqual(month.map(\.name), ["Internet", "Assurance auto", "Forfait cellulaire", "Netflix", "Salaire"])
        XCTAssertEqual(month.last?.isIncome, true)
        XCTAssertEqual(month.first { $0.name == "Netflix" }?.isSubscription, true)
    }

    func testTheMonthAddsUpDayByDay() {
        var state = BudgetState()
        state.expenses = [Expense(amount: 100, categoryID: nil, date: date(11, 1)), Expense(amount: 50, categoryID: nil, date: date(11, 3))]
        XCTAssertEqual(BudgetMath.cumulativeSpending(state, month: now, through: date(11, 4), now: now), [100, 100, 150, 150])
        state.expenses.append(Expense(amount: 30, categoryID: nil, date: date(10, 20)))
        let october = BudgetMath.cumulativeSpending(state, month: date(10, 1), now: now)
        XCTAssertEqual(october.count, 31)
        XCTAssertEqual(october.last ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(october[18], 0, accuracy: 0.001)
        XCTAssertEqual(october[19], 30, accuracy: 0.001)
    }

    func testACategoryAheadOfItsPace() {
        let maison = BudgetCategory(name: "Maison", symbol: "house", colorHex: "B7791F", monthlyLimit: 150)
        let epicerie = BudgetCategory(name: "Épicerie", symbol: "cart", colorHex: "1E9E75", monthlyLimit: 500)
        let autre = BudgetCategory(name: "Autre", symbol: "square.grid.2x2", colorHex: "64748B", monthlyLimit: 0)
        let fraction = 0.4
        XCTAssertTrue(BudgetMath.isAheadOfPace(.init(category: maison, spent: 120), fraction: fraction), "80 % of the limit at 40 % of the month")
        XCTAssertFalse(BudgetMath.isAheadOfPace(.init(category: epicerie, spent: 295), fraction: fraction), "59 %: ahead, but not clearly")
        XCTAssertFalse(BudgetMath.isAheadOfPace(.init(category: maison, spent: 170), fraction: fraction), "Over the limit is said otherwise")
        XCTAssertFalse(BudgetMath.isAheadOfPace(.init(category: autre, spent: 75), fraction: fraction), "No limit, no pace")
    }

    func testTheBalanceAtTheStartOfADay() {
        var state = BudgetState()
        state.openingBalance = 1_000
        state.openingDate = date(11, 1, 0)
        state.expenses = [Expense(amount: 200, categoryID: nil, date: date(11, 1))]
        state.incomes = [IncomeEntry(amount: 500, label: "Salaire", date: date(11, 5))]
        XCTAssertEqual(BudgetMath.balance(atStartOf: date(11, 1), state, now: now), 1_000, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.balance(atStartOf: date(11, 2), state, now: now), 800, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.balance(atStartOf: date(11, 6), state, now: now), 1_300, accuracy: 0.001)
    }

    func testTheOnlyCategoryRisingIsFound() {
        var state = BudgetState()
        let restos = BudgetState.fixedID(2), sorties = BudgetState.fixedID(4)
        state.expenses = [
            Expense(amount: 96, categoryID: restos, date: date(10, 5)), Expense(amount: 120, categoryID: sorties, date: date(10, 5)),
            Expense(amount: 118, categoryID: restos, date: date(11, 5)), Expense(amount: 74, categoryID: sorties, date: date(11, 5)),
        ]
        let changes = BudgetMath.categoryChanges(state, at: now)
        XCTAssertEqual(changes.first?.name, BudgetState.defaultCategories[3].name, "Sorties moved the most (−46)")
        guard case let .onlyRise(name, _, _, current, previous)? = BudgetMath.insights(state, at: now).first else {
            return XCTFail("One category rises, the other falls")
        }
        XCTAssertEqual(name, BudgetState.defaultCategories[1].name)
        XCTAssertEqual(current, 118, accuracy: 0.001)
        XCTAssertEqual(previous, 96, accuracy: 0.001)
    }

    func testEverythingDownAndAHeavyDay() {
        var state = BudgetState()
        let restos = BudgetState.fixedID(2)
        state.expenses = [
            Expense(amount: 100, categoryID: restos, date: date(10, 5)),
            Expense(amount: 40, categoryID: restos, date: date(11, 1)), Expense(amount: 5, categoryID: restos, date: date(11, 3)),
            Expense(amount: 10, categoryID: restos, date: date(11, 5)), Expense(amount: 5, categoryID: restos, date: date(11, 8)),
        ]
        let found = BudgetMath.insights(state, at: now)
        XCTAssertEqual(found.first, .allDown(saved: 40))
        guard case let .heavyDay(day, share)? = found.last else { return XCTFail("The 1st weighs 2/3 of the month") }
        XCTAssertTrue(DateMath.isSameDay(day, date(11, 1)))
        XCTAssertEqual(share, 40.0 / 60, accuracy: 0.001)
        XCTAssertTrue(BudgetMath.insights(BudgetState(), at: now).isEmpty, "Nothing noted, nothing written")
    }

    func testTheSearchIgnoresAccentsAndCase() {
        let state = BudgetState()
        let coffee = Expense(amount: 14.5, categoryID: BudgetState.fixedID(2), note: "Café et sandwich", date: now, source: .applePay, merchant: "Café Myriade")
        XCTAssertTrue(BudgetMath.matches(coffee, query: "cafe SAND", state: state))
        XCTAssertTrue(BudgetMath.matches(coffee, query: "myriade", state: state), "The merchant")
        XCTAssertTrue(BudgetMath.matches(coffee, query: BudgetState.defaultCategories[1].name.lowercased(), state: state), "The category")
        XCTAssertFalse(BudgetMath.matches(coffee, query: "pizza", state: state))
        XCTAssertTrue(BudgetMath.matches(coffee, query: "  ", state: state), "An empty search keeps everything")
        XCTAssertTrue(BudgetMath.matches(IncomeEntry(amount: 1_150, label: "Salaire", date: now), query: "sal"))
    }
}
