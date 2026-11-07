import XCTest
@testable import Ardane

/// Audit 24.C-P1: amounts of money are hidden while the iPhone is locked (`privacySensitive`), and no
/// notification carries an amount. Calories and sport stay readable.
@MainActor
final class Audit24PrivacySensitiveTests: XCTestCase {
    private let now = DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))!

    private func tile(_ kind: WidgetKind) -> Tile {
        let design = WidgetDesign(kind: kind)
        let family = kind.families.first ?? .systemSmall
        let context = RenderContext(design: design, style: ResolvedStyle(design: design), family: family, date: now,
                                    payload: SamplePayload.make(for: kind, now: now), isInteractive: false)
        return TileFactory.make(context)
    }

    func testTheMoneyWidgetsAreMarkedSensitive() {
        for kind in [WidgetKind.budgetLeft, .savingsGoal, .billsUpcoming, .portfolio, .revenueGoal, .mrr, .companySnapshot, .moneyDashboard] {
            XCTAssertTrue(tile(kind).isSensitive, "\(kind) shows money")
        }
        for kind in WidgetKind.allCases where [.finance, .business, .markets].contains(kind.category) {
            XCTAssertTrue(tile(kind).isSensitive, "\(kind) is a money widget")
        }
    }

    func testNutritionFitnessAndPlanningWidgetsAreNotSensitive() {
        let others: [WidgetCategory] = [.nutrition, .fitness, .wellbeing, .student, .travel, .time]
        for kind in WidgetKind.allCases where others.contains(kind.category) {
            XCTAssertFalse(tile(kind).isSensitive, "\(kind) is not about money")
        }
    }

    func testABillReminderCarriesNoAmount() {
        let calendar = DateMath.calendar
        var budget = BudgetState()
        let due = calendar.date(from: DateComponents(year: 2026, month: 10, day: 10))!
        budget.bills = [Bill(name: "Loyer", amount: 1_250, anchorDate: due)]
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 9))!
        let plan = SmartReminders.plan(fitness: FitnessState(), nutrition: NutritionState(), budget: budget, settings: AppSettings(), now: start)
        let bills = plan.filter { $0.id.hasPrefix(SmartReminders.prefix + "bill") }
        XCTAssertEqual(bills.count, 1)
        XCTAssertTrue(bills.first?.title.contains("Loyer") == true, "The bill's name stays")
        for text in bills.compactMap({ [$0.title, $0.body] }).joined() {
            XCTAssertFalse(text.contains("1250") || text.contains("1 250") || text.contains("1,250"), "No amount in « \(text) »")
        }
        let body = bills.first?.body ?? ""
        XCTAssertFalse(body.contains("1"), "No digit in the body: « \(body) »")
        XCTAssertFalse(body.contains("$") || body.contains("€"), "No currency in the body: « \(body) »")
    }
}
