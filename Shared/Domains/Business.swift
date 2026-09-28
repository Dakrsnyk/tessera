import Foundation

struct SalesEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date = Date()
    var amount: Double
    var orders: Int = 1
    var newCustomers: Int = 0
    var visitors: Int = 0
    var note: String = ""
}

struct BusinessExpense: Codable, Hashable, Identifiable {
    var id = UUID()
    var date = Date()
    var amount: Double
    var label: String
}

struct SubscriptionSnapshot: Codable, Hashable, Identifiable {
    var id = UUID()
    /// Any date within the month this snapshot describes.
    var month: Date
    var mrr: Double
    var subscribers: Int
}

struct BusinessState: Codable, Hashable {
    var name = "Mon entreprise"
    var monthlyGoal: Double = 10_000
    var sales: [SalesEntry] = []
    var expenses: [BusinessExpense] = []
    var subscriptions: [SubscriptionSnapshot] = []

    enum CodingKeys: String, CodingKey { case name, monthlyGoal, sales, expenses, subscriptions }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.value(.name, "Mon entreprise")
        monthlyGoal = c.value(.monthlyGoal, 10_000)
        sales = c.value(.sales, [])
        expenses = c.value(.expenses, [])
        subscriptions = c.value(.subscriptions, [])
    }
}

enum BusinessMath {
    enum Period { case day, week, month, year }

    static func interval(_ period: Period, containing date: Date) -> DateInterval {
        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return DateMath.calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 1)
    }

    /// The same period one step earlier, cut at the same elapsed point (so a partial month compares fairly).
    static func previousInterval(_ period: Period, containing date: Date) -> DateInterval {
        let current = interval(period, containing: date)
        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        let start = DateMath.calendar.date(byAdding: component, value: -1, to: current.start) ?? current.start
        return DateInterval(start: start, duration: max(1, date.timeIntervalSince(current.start)))
    }

    static func sales(_ state: BusinessState, in interval: DateInterval) -> [SalesEntry] {
        state.sales.filter { interval.contains($0.date) }
    }

    static func revenue(_ state: BusinessState, in interval: DateInterval) -> Double {
        sales(state, in: interval).reduce(0) { $0 + $1.amount }
    }

    static func revenue(_ state: BusinessState, _ period: Period, at date: Date) -> Double {
        revenue(state, in: interval(period, containing: date))
    }

    static func growth(_ state: BusinessState, _ period: Period, at date: Date) -> Double? {
        let start = interval(period, containing: date).start
        let soFar = DateInterval(start: start, duration: max(1, date.timeIntervalSince(start)))
        return Stats.change(from: revenue(state, in: previousInterval(period, containing: date)), to: revenue(state, in: soFar))
    }

    static func goalProgress(_ state: BusinessState, at date: Date) -> Double {
        guard state.monthlyGoal > 0 else { return 0 }
        return revenue(state, .month, at: date) / state.monthlyGoal
    }

    static func costs(_ state: BusinessState, in interval: DateInterval) -> Double {
        state.expenses.filter { interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    struct Profit: Hashable {
        let revenue: Double
        let costs: Double
        var profit: Double { revenue - costs }
        var margin: Double? { revenue > 0 ? profit / revenue : nil }
    }

    static func profit(_ state: BusinessState, month date: Date) -> Profit {
        let month = interval(.month, containing: date)
        return Profit(revenue: revenue(state, in: month), costs: costs(state, in: month))
    }

    struct KPIs: Hashable {
        let orders: Int
        let averageBasket: Double?
        let newCustomers: Int
        let conversion: Double?
    }

    static func kpis(_ state: BusinessState, month date: Date) -> KPIs {
        let entries = sales(state, in: interval(.month, containing: date))
        let orders = entries.reduce(0) { $0 + $1.orders }
        let revenue = entries.reduce(0) { $0 + $1.amount }
        let visitors = entries.reduce(0) { $0 + $1.visitors }
        return KPIs(
            orders: orders,
            averageBasket: orders > 0 ? revenue / Double(orders) : nil,
            newCustomers: entries.reduce(0) { $0 + $1.newCustomers },
            conversion: visitors > 0 ? Double(orders) / Double(visitors) : nil
        )
    }

    /// Revenue per day for the last `days` days, oldest first.
    static func dailyRevenue(_ state: BusinessState, days: Int, until date: Date) -> [Double] {
        (0..<days).reversed().map { offset in
            let day = DateMath.calendar.date(byAdding: .day, value: -offset, to: date) ?? date
            return revenue(state, in: interval(.day, containing: day))
        }
    }

    struct Recurring: Hashable {
        let mrr: Double
        let subscribers: Int
        let growth: Double?
        var arr: Double { mrr * 12 }
    }

    static func recurring(_ state: BusinessState) -> Recurring? {
        let sorted = state.subscriptions.sorted { $0.month < $1.month }
        guard let latest = sorted.last else { return nil }
        let previous = sorted.dropLast().last
        return Recurring(mrr: latest.mrr, subscribers: latest.subscribers, growth: previous.flatMap { Stats.change(from: $0.mrr, to: latest.mrr) })
    }

    /// Today's revenue so far compared with the same weekday last week, up to the same time.
    static func todayVersusLastWeek(_ state: BusinessState, at date: Date) -> (today: Double, lastWeek: Double) {
        let lastWeekDay = DateMath.calendar.date(byAdding: .day, value: -7, to: date) ?? date
        let elapsed = max(1, date.timeIntervalSince(DateMath.startOfDay(date)))
        let today = revenue(state, in: DateInterval(start: DateMath.startOfDay(date), duration: elapsed))
        let lastWeek = revenue(state, in: DateInterval(start: DateMath.startOfDay(lastWeekDay), duration: elapsed))
        return (today, lastWeek)
    }
}
