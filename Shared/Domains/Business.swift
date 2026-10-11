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

/// The indicators Ardane computes from the sales, costs and recurring revenue; the person picks
/// the ones shown on the dashboard.
enum BusinessKPI: String, Codable, CaseIterable, Identifiable {
    case revenue, costs, profit, margin, orders, averageBasket, newCustomers, visitors, conversion, mrr, subscribers
    var id: String { rawValue }

    var title: String {
        switch self {
        case .revenue: tr("Chiffre d'affaires")
        case .costs: tr("Dépenses")
        case .profit: tr("Bénéfice")
        case .margin: tr("Marge")
        case .orders: tr("Commandes")
        case .averageBasket: tr("Panier moyen")
        case .newCustomers: tr("Nouveaux clients")
        case .visitors: tr("Visiteurs")
        case .conversion: tr("Conversion")
        case .mrr: tr("MRR")
        case .subscribers: tr("Abonnés")
        }
    }

    var symbol: String {
        switch self {
        case .revenue: "chart.bar.fill"
        case .costs: "minus.circle.fill"
        case .profit: "banknote.fill"
        case .margin: "percent"
        case .orders: "shippingbox.fill"
        case .averageBasket: "cart.fill"
        case .newCustomers: "person.badge.plus"
        case .visitors: "eye.fill"
        case .conversion: "arrow.triangle.turn.up.right.diamond.fill"
        case .mrr: "arrow.triangle.2.circlepath"
        case .subscribers: "person.3.fill"
        }
    }

    enum Unit { case money, percent, count }

    var unit: Unit {
        switch self {
        case .revenue, .costs, .profit, .averageBasket, .mrr: .money
        case .margin, .conversion: .percent
        case .orders, .newCustomers, .visitors, .subscribers: .count
        }
    }

    /// Up is good, except for costs.
    var higherIsBetter: Bool { self != .costs }

    /// Read from the latest monthly snapshot, not summed over a period.
    var isSnapshot: Bool { self == .mrr || self == .subscribers }
}

/// An indicator the person follows by hand (followers, NPS, quotes sent…).
struct CustomMetric: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var unit: String = ""
    var target: Double?
    var higherIsBetter = true
    var values: [ValuePoint] = []

    var sortedValues: [ValuePoint] { values.sorted { $0.date < $1.date } }
    var latest: ValuePoint? { values.max { $0.date < $1.date } }

    /// One value a day: a new one the same day replaces it.
    mutating func record(_ value: Double, at date: Date = Date()) {
        values.removeAll { DateMath.isSameDay($0.date, date) }
        values.append(ValuePoint(date: date, value: value))
        values.sort { $0.date < $1.date }
        if values.count > 400 { values.removeFirst(values.count - 400) }
    }

    /// The change since the value before the latest one.
    var change: Double? {
        let sorted = sortedValues
        guard sorted.count >= 2 else { return nil }
        return Stats.change(from: sorted[sorted.count - 2].value, to: sorted[sorted.count - 1].value)
    }
}

struct BusinessState: Codable, Hashable {
    var name = tr("Mon entreprise")
    var monthlyGoal: Double = 10_000
    var sales: [SalesEntry] = []
    var expenses: [BusinessExpense] = []
    var subscriptions: [SubscriptionSnapshot] = []
    var pinnedKPIs: [BusinessKPI] = BusinessState.defaultKPIs
    var metrics: [CustomMetric] = []

    static let defaultKPIs: [BusinessKPI] = [.revenue, .profit, .orders, .averageBasket]

    enum CodingKeys: String, CodingKey { case name, monthlyGoal, sales, expenses, subscriptions, pinnedKPIs, metrics }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.value(.name, tr("Mon entreprise"))
        monthlyGoal = c.value(.monthlyGoal, 10_000)
        sales = c.value(.sales, [])
        expenses = c.value(.expenses, [])
        subscriptions = c.value(.subscriptions, [])
        pinnedKPIs = c.value(.pinnedKPIs, BusinessState.defaultKPIs)
        metrics = c.value(.metrics, [])
    }

    mutating func togglePinned(_ kpi: BusinessKPI) {
        if let index = pinnedKPIs.firstIndex(of: kpi) { pinnedKPIs.remove(at: index) } else { pinnedKPIs.append(kpi) }
    }

    mutating func save(_ sale: SalesEntry) {
        if let index = sales.firstIndex(where: { $0.id == sale.id }) { sales[index] = sale } else { sales.append(sale) }
    }

    mutating func save(_ cost: BusinessExpense) {
        if let index = expenses.firstIndex(where: { $0.id == cost.id }) { expenses[index] = cost } else { expenses.append(cost) }
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

    // MARK: Mini-app

    /// The value of an indicator over a period; nil when the data to compute it is missing (a margin
    /// without revenue, a conversion without visitors, a MRR never entered).
    static func value(_ kpi: BusinessKPI, _ state: BusinessState, in interval: DateInterval) -> Double? {
        let entries = sales(state, in: interval)
        let revenue = entries.reduce(0) { $0 + $1.amount }
        let orders = entries.reduce(0) { $0 + $1.orders }
        switch kpi {
        case .revenue: return revenue
        case .costs: return costs(state, in: interval)
        case .profit: return revenue - costs(state, in: interval)
        case .margin: return revenue > 0 ? (revenue - costs(state, in: interval)) / revenue : nil
        case .orders: return Double(orders)
        case .averageBasket: return orders > 0 ? revenue / Double(orders) : nil
        case .newCustomers: return Double(entries.reduce(0) { $0 + $1.newCustomers })
        case .visitors:
            let visitors = entries.reduce(0) { $0 + $1.visitors }
            return visitors > 0 ? Double(visitors) : nil
        case .conversion:
            let visitors = entries.reduce(0) { $0 + $1.visitors }
            return visitors > 0 ? Double(orders) / Double(visitors) : nil
        case .mrr, .subscribers:
            let snapshots = state.subscriptions.filter { $0.month < interval.end }.sorted { $0.month < $1.month }
            guard let latest = snapshots.last else { return nil }
            return kpi == .mrr ? latest.mrr : Double(latest.subscribers)
        }
    }

    /// An indicator for this period so far, against the previous period up to the same point.
    struct Comparison: Hashable {
        let current: Double?
        let previous: Double?
        var change: Double? {
            guard let current, let previous else { return nil }
            return Stats.change(from: previous, to: current)
        }
    }

    static func compare(_ kpi: BusinessKPI, _ state: BusinessState, _ period: Period, at date: Date) -> Comparison {
        let start = interval(period, containing: date).start
        let soFar = DateInterval(start: start, duration: max(1, date.timeIntervalSince(start)))
        let previous = previousInterval(period, containing: date)
        if kpi.isSnapshot {
            // A monthly figure: this month against the month before.
            let before = DateMath.calendar.date(byAdding: .month, value: -1, to: date) ?? date
            return Comparison(current: value(kpi, state, in: soFar), previous: value(kpi, state, in: DateInterval(start: .distantPast, end: interval(.month, containing: before).end)))
        }
        return Comparison(current: value(kpi, state, in: soFar), previous: value(kpi, state, in: previous))
    }

    /// Revenue added up day by day (months for a year) for this period and the previous one, to
    /// draw them one over the other.
    struct CumulativePoint: Hashable, Identifiable {
        let index: Int
        let current: Double?
        let previous: Double
        var id: Int { index }
    }

    static func cumulative(_ state: BusinessState, _ period: Period, at date: Date) -> [CumulativePoint] {
        let calendar = DateMath.calendar
        let current = interval(period, containing: date)
        let component: Calendar.Component
        let step: Calendar.Component
        switch period {
        case .day, .week: component = .weekOfYear; step = .day
        case .month: component = .month; step = .day
        case .year: component = .year; step = .month
        }
        let base = period == .day ? interval(.week, containing: date) : current
        guard let previousStart = calendar.date(byAdding: component, value: -1, to: base.start) else { return [] }
        let count = period == .year ? 12 : (calendar.dateComponents([.day], from: base.start, to: base.end).day ?? 7)
        var points: [CumulativePoint] = []
        var runningCurrent = 0.0
        var runningPrevious = 0.0
        for index in 0..<count {
            guard let slotStart = calendar.date(byAdding: step, value: index, to: base.start),
                  let slotEnd = calendar.date(byAdding: step, value: index + 1, to: base.start),
                  let previousSlotStart = calendar.date(byAdding: step, value: index, to: previousStart),
                  let previousSlotEnd = calendar.date(byAdding: step, value: index + 1, to: previousStart) else { continue }
            runningPrevious += revenue(state, in: DateInterval(start: previousSlotStart, end: previousSlotEnd))
            if slotStart <= date {
                runningCurrent += revenue(state, in: DateInterval(start: slotStart, end: slotEnd))
                points.append(CumulativePoint(index: index + 1, current: runningCurrent, previous: runningPrevious))
            } else {
                points.append(CumulativePoint(index: index + 1, current: nil, previous: runningPrevious))
            }
        }
        return points
    }

    /// Revenue, costs and profit of the last months, oldest first.
    struct MonthResult: Hashable, Identifiable {
        let start: Date
        let revenue: Double
        let costs: Double
        var id: Date { start }
        var profit: Double { revenue - costs }
    }

    static func months(_ state: BusinessState, count: Int, at date: Date) -> [MonthResult] {
        let current = interval(.month, containing: date).start
        return (0..<count).reversed().compactMap { back in
            guard let start = DateMath.calendar.date(byAdding: .month, value: -back, to: current) else { return nil }
            let month = interval(.month, containing: start)
            return MonthResult(start: start, revenue: revenue(state, in: month), costs: costs(state, in: month))
        }
    }
}
