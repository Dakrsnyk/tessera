import XCTest
@testable import Tessera

/// The Finances and Business mini-apps: money in and out that adds up month by month, categories
/// against their limits, savings goals, and indicators compared fairly with the previous period.
final class FinancesBusinessTests: XCTestCase {
    /// Wednesday 30 September 2026 at the given hour.
    private func september(_ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    private func august(_ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour))!
    }

    // MARK: Finances

    func testMonthsAddUpWhatCameInAndWentOut() {
        var state = BudgetState()
        state.addIncome(IncomeEntry(amount: 1_500, label: "Salaire", date: september(1)))
        state.addIncome(IncomeEntry(amount: 1_500, label: "Salaire", date: september(15)))
        state.addIncome(IncomeEntry(amount: 1_500, label: "Salaire", date: august(15)))
        state.add(Expense(amount: 80, categoryID: BudgetState.fixedID(1), date: september(3)))
        state.add(Expense(amount: 45, categoryID: BudgetState.fixedID(2), date: september(20)))
        state.add(Expense(amount: 200, categoryID: BudgetState.fixedID(1), date: august(10)))
        let months = BudgetMath.months(state, count: 3, at: september(30))
        XCTAssertEqual(months.count, 3)
        XCTAssertEqual(months.last?.earned, 3_000)
        XCTAssertEqual(months.last?.spent, 125)
        XCTAssertEqual(months.last?.balance, 2_875)
        XCTAssertEqual(months[1].spent, 200)
        XCTAssertEqual(months[0].spent, 0, "July: nothing noted")

        // This month so far against last month up to the same day.
        let comparison = BudgetMath.monthToDate(state, at: september(12))
        XCTAssertEqual(comparison.current, 80)
        XCTAssertEqual(comparison.previous, 200)
    }

    func testCategoriesComparedWithTheirLimits() {
        var state = BudgetState()
        state.categories[0].monthlyLimit = 100
        state.add(Expense(amount: 130, categoryID: state.categories[0].id, date: september(5)))
        state.add(Expense(amount: 20, categoryID: state.categories[1].id, date: september(6)))
        let status = BudgetMath.categoryStatus(state, at: september(10))
        XCTAssertEqual(status.first?.category.id, state.categories[0].id, "The biggest spending first")
        XCTAssertTrue(status[0].isOver)
        XCTAssertEqual(status[0].ratio ?? 0, 1.3, accuracy: 0.001)
        XCTAssertFalse(status.contains { $0.category.name == "Autre" }, "Without a limit or spending, a category is not listed")
    }

    func testEditingAndSavingsGoals() {
        var state = BudgetState()
        var expense = Expense(amount: 12, categoryID: nil, date: september(2))
        state.save(expense)
        expense.amount = 15
        state.save(expense)
        XCTAssertEqual(state.expenses.count, 1)
        XCTAssertEqual(state.expenses[0].amount, 15)

        let goal = SavingsGoal(name: "Voyage", target: 3_000, saved: 600, deadline: DateMath.calendar.date(from: DateComponents(year: 2027, month: 3, day: 31)))
        state.goals = [goal]
        state.deposit(400, toGoal: goal.id)
        XCTAssertEqual(state.goals[0].saved, 1_000)
        // 2 000 left over six months.
        XCTAssertEqual(BudgetMath.monthlyToReach(state.goals[0], at: september(30))!, 2_000 / 6, accuracy: 0.01)
        XCTAssertNil(BudgetMath.monthlyToReach(SavingsGoal(name: "Sans date", target: 100, saved: 0, deadline: nil), at: september(30)))
    }

    func testOlderBudgetsOpenWithoutIncomes() throws {
        let json = #"{"monthlyBudget":1800,"expenses":[]}"#
        let state = try JSONDecoder().decode(BudgetState.self, from: Data(json.utf8))
        XCTAssertEqual(state.monthlyBudget, 1_800)
        XCTAssertTrue(state.incomes.isEmpty)
        XCTAssertEqual(state.categories.count, BudgetState.defaultCategories.count)
    }

    // MARK: Business

    func testIndicatorsComparePeriodsFairly() {
        var state = BusinessState()
        // September until the 10th: 3 sales; August until the 10th: 2 sales (a later one does not count).
        state.sales = [
            SalesEntry(date: september(2), amount: 300, orders: 3, newCustomers: 1, visitors: 100),
            SalesEntry(date: september(5), amount: 200, orders: 2, visitors: 50),
            SalesEntry(date: september(9), amount: 100, orders: 1),
            SalesEntry(date: august(3), amount: 250, orders: 5),
            SalesEntry(date: august(8), amount: 150, orders: 3),
            SalesEntry(date: august(25), amount: 900, orders: 9),
        ]
        state.expenses = [BusinessExpense(date: september(4), amount: 120, label: "Pub")]
        let now = september(10)
        let revenue = BusinessMath.compare(.revenue, state, .month, at: now)
        XCTAssertEqual(revenue.current, 600)
        XCTAssertEqual(revenue.previous, 400)
        XCTAssertEqual(revenue.change ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(BusinessMath.compare(.profit, state, .month, at: now).current, 480)
        XCTAssertEqual(BusinessMath.compare(.margin, state, .month, at: now).current ?? 0, 0.8, accuracy: 0.0001)
        XCTAssertEqual(BusinessMath.compare(.averageBasket, state, .month, at: now).current ?? 0, 100, accuracy: 0.0001)
        XCTAssertEqual(BusinessMath.compare(.conversion, state, .month, at: now).current ?? 0, 6.0 / 150, accuracy: 0.0001)
        XCTAssertNil(BusinessMath.compare(.conversion, state, .month, at: now).previous, "No visitors noted in August")
        XCTAssertNil(BusinessMath.compare(.mrr, state, .month, at: now).current, "No recurring revenue entered")

        let points = BusinessMath.cumulative(state, .month, at: now)
        XCTAssertEqual(points.count, 30)
        XCTAssertEqual(points[9].current, 600)
        XCTAssertNil(points[10].current, "Days to come have no value yet")
        XCTAssertEqual(points.last?.previous, 1_300)
    }

    func testChosenIndicatorsAndMetricsFollowedByHand() throws {
        var state = BusinessState()
        XCTAssertEqual(state.pinnedKPIs, BusinessState.defaultKPIs)
        state.togglePinned(.conversion)
        state.togglePinned(.orders)
        XCTAssertTrue(state.pinnedKPIs.contains(.conversion))
        XCTAssertFalse(state.pinnedKPIs.contains(.orders))

        var metric = CustomMetric(name: "Abonnés", target: 1_000)
        metric.record(400, at: september(1))
        metric.record(450, at: september(8, 9))
        metric.record(480, at: september(8, 18))
        XCTAssertEqual(metric.values.count, 2, "One value a day")
        XCTAssertEqual(metric.latest?.value, 480)
        XCTAssertEqual(metric.change ?? 0, 0.2, accuracy: 0.0001)
        state.metrics = [metric]

        let back = try JSONDecoder().decode(BusinessState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(back.metrics.first?.latest?.value, 480)
        XCTAssertTrue(back.pinnedKPIs.contains(.conversion))
        let old = try JSONDecoder().decode(BusinessState.self, from: Data(#"{"name":"Atelier","monthlyGoal":5000}"#.utf8))
        XCTAssertEqual(old.pinnedKPIs, BusinessState.defaultKPIs)
        XCTAssertTrue(old.metrics.isEmpty)
    }
}
