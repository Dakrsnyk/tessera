import XCTest
@testable import Tessera

/// Finances in step: fixed expenses in their category and on their dates, operations at their
/// dates, deletions that follow everywhere.
@MainActor
final class FinancesSyncTests: XCTestCase {
    private func day(_ month: Int, _ day: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    private func temporaryModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(store: SharedStore(directory: directory))
    }

    func testAFixedExpenseFindsItsCategory() {
        XCTAssertEqual(FixedExpenseNature.of("Loyer"), .housing)
        XCTAssertEqual(FixedExpenseNature.of("Assurance habitation"), .insurance)
        XCTAssertEqual(FixedExpenseNature.of("Forfait cellulaire"), .telecom)
        XCTAssertEqual(FixedExpenseNature.of("Netflix"), .subscription)
        XCTAssertNil(FixedExpenseNature.of("Bureau"), "A word that only contains a keyword doesn't count")
        var state = BudgetState()
        XCTAssertEqual(state.categoryID(forFixed: "Loyer"), BudgetState.fixedID(5))
        let insurance = state.categoryID(forFixed: "Assurance auto")
        XCTAssertEqual(state.category(insurance)?.name, "Assurances")
        // The same kind again: the same category, not a second one.
        XCTAssertEqual(state.categoryID(forFixed: "Mutuelle"), insurance)
        XCTAssertEqual(state.categories.filter { $0.name == "Assurances" }.count, 1)
    }

    func testABillCountsOnItsDatesInItsCategory() {
        var state = BudgetState()
        state.bills = [Bill(name: "Loyer", amount: 1_200, anchorDate: day(9, 1))]
        let now = day(10, 15)
        let october = BudgetMath.monthInterval(now)
        XCTAssertEqual(BudgetMath.spent(state, in: october, now: now), 1_200)
        XCTAssertEqual(BudgetMath.spent(state, in: BudgetMath.monthInterval(day(9, 15)), now: now), 1_200)
        // Not before its first date, not after today.
        XCTAssertEqual(BudgetMath.spent(state, in: BudgetMath.monthInterval(day(8, 15)), now: now), 0)
        XCTAssertEqual(BudgetMath.spent(state, in: BudgetMath.monthInterval(day(11, 15)), now: now), 0)
        XCTAssertEqual(BudgetMath.categoryStatus(state, at: now).first { $0.category.id == BudgetState.fixedID(5) }?.spent, 1_200)
        XCTAssertEqual(BudgetMath.expenses(state, in: october, now: now).first.map { DateMath.isSameDay($0.date, day(10, 1)) }, true)
        // Noted by hand as well: counted once.
        state.add(Expense(amount: 1_200, categoryID: BudgetState.fixedID(5), note: "loyer", date: day(10, 2)))
        XCTAssertEqual(BudgetMath.spent(state, in: october, now: now), 1_200)
    }

    func testFixedIncomesAndExpensesCountInFinances() {
        let model = temporaryModel()
        model.updateContent { content in
            content.money.items = [
                MoneyItem(name: "Salaire", amount: 3_000, period: .month, isIncome: true, date: DateMath.startOfDay(day(10, 5))),
                MoneyItem(name: "Assurance auto", amount: 90, period: .month, isIncome: false, date: DateMath.startOfDay(day(10, 3))),
            ]
        }
        let state = model.budget
        XCTAssertEqual(state.fixedFlows.count, 2)
        let now = day(10, 15)
        let october = BudgetMath.monthInterval(now)
        XCTAssertEqual(BudgetMath.earned(state, in: october, now: now), 3_000)
        let spent = BudgetMath.expenses(state, in: october, now: now)
        XCTAssertEqual(spent.map(\.amount), [90])
        XCTAssertEqual(state.category(spent.first?.categoryID)?.name, "Assurances", "The category is created and used")
    }

    func testOperationsKeepTheirDates() {
        var state = BudgetState()
        state.save(Expense(amount: 40, categoryID: BudgetState.fixedID(1), date: day(9, 20)))
        state.save(IncomeEntry(amount: 500, label: "Remboursement", date: day(9, 25)))
        let months = BudgetMath.months(state, count: 2, at: day(10, 15))
        XCTAssertEqual(months.map(\.spent), [40, 0])
        XCTAssertEqual(months.map(\.earned), [500, 0])
    }

    func testDeletingAnAccountUpdatesTheNetWorth() {
        var state = BudgetState()
        let checking = Account(name: "Chèques", balance: 1_000)
        let loan = Account(name: "Prêt", balance: 300, isLiability: true)
        state.accounts = [checking, loan]
        state.snapshotNetWorth(at: day(10, 1))
        state.removeAccount(loan.id, at: day(10, 2))
        XCTAssertEqual(BudgetMath.netWorth(state), 1_000)
        XCTAssertEqual(state.netWorthHistory.last?.value, 1_000)
        state.removeAccount(checking.id, at: day(10, 3))
        XCTAssertTrue(state.accounts.isEmpty)
        XCTAssertTrue(state.netWorthHistory.isEmpty)
    }
}
