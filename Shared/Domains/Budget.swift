import Foundation

struct BudgetCategory: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var symbol: String
    var colorHex: String
    var monthlyLimit: Double = 0
}

struct Expense: Codable, Hashable, Identifiable {
    var id = UUID()
    var amount: Double
    var categoryID: UUID?
    var note: String = ""
    var date = Date()
}

/// A one-tap expense (coffee, bus ticket…) offered by the "Dépense rapide" widget.
struct QuickExpense: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var amount: Double
    var categoryID: UUID?
    var symbol: String = "cart"
}

enum BillPeriod: String, Codable, CaseIterable, Identifiable {
    case monthly, yearly
    var id: String { rawValue }
    var title: String { self == .monthly ? "Mensuel" : "Annuel" }
}

struct Bill: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var amount: Double
    /// Any past or future date that falls on the billing day.
    var anchorDate: Date
    var period: BillPeriod = .monthly
    var isSubscription = false
    var symbol: String = "doc.text"

    var monthlyCost: Double { period == .monthly ? amount : amount / 12 }

    func nextDue(after date: Date) -> Date {
        let cal = DateMath.calendar
        let today = DateMath.startOfDay(date)
        var due = DateMath.startOfDay(anchorDate)
        let step: Calendar.Component = period == .monthly ? .month : .year
        var guardCount = 0
        while due < today, guardCount < 600 {
            due = cal.date(byAdding: step, value: 1, to: due) ?? today
            guardCount += 1
        }
        while guardCount < 600, let previous = cal.date(byAdding: step, value: -1, to: due), previous >= today {
            due = previous
            guardCount += 1
        }
        return due
    }
}

struct SavingsGoal: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var target: Double
    var saved: Double
    var deadline: Date?

    var progress: Double { target > 0 ? min(1, saved / target) : 0 }
}

struct Account: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var balance: Double
    var isLiability = false
}

struct ValuePoint: Codable, Hashable {
    var date: Date
    var value: Double
}

struct BudgetState: Codable, Hashable {
    var monthlyBudget: Double = 2_000
    var categories: [BudgetCategory] = BudgetState.defaultCategories
    var expenses: [Expense] = []
    var quickExpenses: [QuickExpense] = []
    var bills: [Bill] = []
    var goals: [SavingsGoal] = []
    var accounts: [Account] = []
    var netWorthHistory: [ValuePoint] = []

    enum CodingKeys: String, CodingKey {
        case monthlyBudget, categories, expenses, quickExpenses, bills, goals, accounts, netWorthHistory
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        monthlyBudget = c.value(.monthlyBudget, 2_000)
        categories = c.value(.categories, BudgetState.defaultCategories)
        expenses = c.value(.expenses, [])
        quickExpenses = c.value(.quickExpenses, [])
        bills = c.value(.bills, [])
        goals = c.value(.goals, [])
        accounts = c.value(.accounts, [])
        netWorthHistory = c.value(.netWorthHistory, [])
    }

    static let defaultCategories: [BudgetCategory] = [
        BudgetCategory(id: BudgetState.fixedID(1), name: "Épicerie", symbol: "cart", colorHex: "1E9E75", monthlyLimit: 500),
        BudgetCategory(id: BudgetState.fixedID(2), name: "Restos", symbol: "fork.knife", colorHex: "F06A3C", monthlyLimit: 200),
        BudgetCategory(id: BudgetState.fixedID(3), name: "Transport", symbol: "bus", colorHex: "3366FF", monthlyLimit: 150),
        BudgetCategory(id: BudgetState.fixedID(4), name: "Sorties", symbol: "ticket", colorHex: "8C6CFF", monthlyLimit: 150),
        BudgetCategory(id: BudgetState.fixedID(5), name: "Maison", symbol: "house", colorHex: "B7791F", monthlyLimit: 150),
        BudgetCategory(id: BudgetState.fixedID(6), name: "Autre", symbol: "square.grid.2x2", colorHex: "64748B", monthlyLimit: 0),
    ]

    /// Stable identifiers for the default categories, identical in the app and the widgets.
    static func fixedID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID()
    }

    func category(_ id: UUID?) -> BudgetCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    mutating func add(_ expense: Expense) {
        expenses.append(expense)
        let cutoff = expense.date.addingTimeInterval(-400 * 86_400)
        expenses.removeAll { $0.date < cutoff }
    }

    /// Records today's net worth so the widget can draw its trend (one point per day).
    mutating func snapshotNetWorth(at date: Date = Date()) {
        let value = BudgetMath.netWorth(self)
        netWorthHistory.removeAll { DateMath.isSameDay($0.date, date) }
        netWorthHistory.append(ValuePoint(date: date, value: value))
        netWorthHistory.sort { $0.date < $1.date }
        if netWorthHistory.count > 400 { netWorthHistory.removeFirst(netWorthHistory.count - 400) }
    }
}

enum BudgetMath {
    static func monthInterval(_ date: Date) -> DateInterval {
        DateMath.calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 1)
    }

    static func expenses(_ state: BudgetState, in interval: DateInterval) -> [Expense] {
        state.expenses.filter { interval.contains($0.date) }
    }

    static func spentThisMonth(_ state: BudgetState, at date: Date) -> Double {
        expenses(state, in: monthInterval(date)).reduce(0) { $0 + $1.amount }
    }

    static func remaining(_ state: BudgetState, at date: Date) -> Double {
        state.monthlyBudget - spentThisMonth(state, at: date)
    }

    static func daysLeftInMonth(_ date: Date) -> Int {
        let end = monthInterval(date).end
        return max(1, DateMath.daysBetween(date, end))
    }

    static func perDayLeft(_ state: BudgetState, at date: Date) -> Double {
        max(0, remaining(state, at: date)) / Double(daysLeftInMonth(date))
    }

    static func spentToday(_ state: BudgetState, at date: Date) -> Double {
        state.expenses.filter { DateMath.isSameDay($0.date, date) }.reduce(0) { $0 + $1.amount }
    }

    struct CategorySpend: Hashable {
        let category: BudgetCategory?
        let amount: Double
        var name: String { category?.name ?? "Sans catégorie" }
        var colorHex: String { category?.colorHex ?? "64748B" }
    }

    static func byCategory(_ state: BudgetState, in interval: DateInterval) -> [CategorySpend] {
        var totals: [UUID?: Double] = [:]
        for expense in expenses(state, in: interval) {
            totals[expense.categoryID, default: 0] += expense.amount
        }
        return totals.map { CategorySpend(category: state.category($0.key), amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    struct UpcomingBill: Hashable {
        let bill: Bill
        let due: Date
        let days: Int
    }

    static func upcomingBills(_ state: BudgetState, at date: Date, within days: Int = 31) -> [UpcomingBill] {
        state.bills.map { bill in
            let due = bill.nextDue(after: date)
            return UpcomingBill(bill: bill, due: due, days: DateMath.daysBetween(date, due))
        }
        .filter { $0.days <= days }
        .sorted { $0.due < $1.due }
    }

    static func subscriptionsMonthly(_ state: BudgetState) -> Double {
        state.bills.filter(\.isSubscription).reduce(0) { $0 + $1.monthlyCost }
    }

    static func netWorth(_ state: BudgetState) -> Double {
        state.accounts.reduce(0) { $0 + ($1.isLiability ? -$1.balance : $1.balance) }
    }

    /// Spending of this week so far versus the same days of last week, per category.
    static func weekComparison(_ state: BudgetState, at date: Date) -> [(name: String, current: Double, previous: Double)] {
        let cal = DateMath.calendar
        guard let week = cal.dateInterval(of: .weekOfYear, for: date),
              let lastStart = cal.date(byAdding: .weekOfYear, value: -1, to: week.start) else { return [] }
        let elapsed = date.timeIntervalSince(week.start)
        let current = DateInterval(start: week.start, duration: max(1, elapsed))
        let previous = DateInterval(start: lastStart, duration: max(1, elapsed))
        let now = byCategory(state, in: current)
        let before = byCategory(state, in: previous)
        let names = Set(now.map(\.name) + before.map(\.name))
        return names.map { name -> (name: String, current: Double, previous: Double) in
            (name, now.first { $0.name == name }?.amount ?? 0, before.first { $0.name == name }?.amount ?? 0)
        }
    }
}
