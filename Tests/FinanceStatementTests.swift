import XCTest
@testable import Tessera

/// The account statement opened from the balance: every movement newest first, the balance after
/// each, the « Solde de départ » first, and a last balance equal to the one the chart shows.
final class FinanceStatementTests: XCTestCase {
    private func september(_ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    private func august(_ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    func testNewestFirstWithTheRunningBalance() {
        var state = BudgetState()
        state.addIncome(IncomeEntry(amount: 1_500, label: "Salaire", date: september(1)))
        state.add(Expense(amount: 80, categoryID: BudgetState.fixedID(1), date: september(3)))
        state.add(Expense(amount: 45, categoryID: BudgetState.fixedID(2), date: september(3, 18)))
        state.add(Expense(amount: 200, categoryID: BudgetState.fixedID(1), date: august(10)))
        let lines = BudgetMath.statement(state, from: september(1), now: september(10))
        XCTAssertEqual(lines.count, 3, "August is before the start")
        XCTAssertEqual(lines.map(\.amount), [-45, -80, 1_500], "Newest first, expenses negative")
        XCTAssertEqual(lines.map(\.balance), [1_375, 1_420, 1_500], "The balance after each line (−80 at noon, then −45 at 18:00)")
        XCTAssertEqual(lines.first?.balance, BudgetMath.balanceHistory(state, from: september(1), now: september(10)).last?.balance)
        XCTAssertTrue(lines.allSatisfy { $0.kind != .opening })
        XCTAssertTrue(BudgetMath.statement(state, from: september(12), now: september(10)).isEmpty)
    }

    func testTheOpeningBalanceComesFirst() {
        var state = BudgetState()
        state.addIncome(IncomeEntry(amount: 1_500, label: "Salaire", date: september(1)))
        state.add(Expense(amount: 125, categoryID: BudgetState.fixedID(1), date: september(3)))
        state.add(Expense(amount: 50, categoryID: BudgetState.fixedID(2), date: september(5)))
        state.openingBalance = 1_000
        state.openingDate = september(5, 0)
        let lines = BudgetMath.statement(state, from: september(1), now: september(10))
        XCTAssertEqual(lines.count, 2, "What came before the opening day is already in it")
        XCTAssertEqual(lines.last?.kind, BudgetMath.StatementLine.Kind.opening)
        XCTAssertEqual(lines.last?.balance, 1_000)
        XCTAssertEqual(lines.first?.balance, 950, "The 5th's expense comes after the opening balance")
        XCTAssertEqual(lines.first?.balance, BudgetMath.balanceHistory(state, from: september(1), now: september(10)).last?.balance)

        // An opening balance before the chart's period: the statement starts from it all the same.
        state.openingDate = august(20, 0)
        let longer = BudgetMath.statement(state, from: september(1), now: september(10))
        XCTAssertEqual(longer.last?.kind, BudgetMath.StatementLine.Kind.opening)
        XCTAssertEqual(longer.first?.balance, 2_325)
        XCTAssertEqual(longer.first?.balance, BudgetMath.balanceHistory(state, from: september(1), now: september(10)).last?.balance)
    }

    func testFixedAmountsAndBillsOnTheirDates() {
        var state = BudgetState()
        state.fixedFlows = [
            MoneyItem(name: "Loyer", amount: 900, period: .month, isIncome: false, date: august(1)),
            MoneyItem(name: "Paie", amount: 2_000, period: .month, isIncome: true, date: august(15)),
        ]
        state.bills = [Bill(name: "Netflix", amount: 20, anchorDate: august(5), isSubscription: true)]
        state.add(Expense(amount: 30, categoryID: BudgetState.fixedID(1), note: "Épicerie", date: september(10)))
        let lines = BudgetMath.statement(state, from: september(1), now: september(20))
        XCTAssertEqual(lines.count, 4, "Rent on the 1st, Netflix on the 5th, groceries on the 10th, pay on the 15th")
        XCTAssertEqual(lines.map(\.amount), [2_000, -30, -20, -900])
        XCTAssertEqual(lines.map(\.balance), [1_050, -950, -920, -900])
        if case let .income(income) = lines[0].kind {
            XCTAssertNotNil(income.fixedID)
            XCTAssertEqual(income.label, "Paie")
        } else {
            XCTFail("The pay is an income")
        }
        if case let .expense(expense) = lines[2].kind {
            XCTAssertEqual(expense.fixedID, state.bills[0].id)
        } else {
            XCTFail("Netflix is an expense")
        }
        XCTAssertEqual(lines.first?.balance, BudgetMath.balanceHistory(state, from: september(1), now: september(20)).last?.balance)
        XCTAssertEqual(BudgetMath.fixedExpensesMonthly(state), 900, accuracy: 0.001)
    }
}
