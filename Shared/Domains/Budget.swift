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
    /// Set on an expense that comes from a fixed expense (a bill, a fixed cost): computed on its
    /// date, never saved, so it is counted once and follows any change to the fixed expense.
    var fixedID: UUID?
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
    var title: String { self == .monthly ? tr("Mensuel") : tr("Annuel") }
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
    /// The category its payments count in; found from its name when the person doesn't choose.
    var categoryID: UUID?

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

/// Money coming in: a pay, a freelance job, a refund…
struct IncomeEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var amount: Double
    var label: String = tr("Salaire")
    var date = Date()
    /// Set on an income that comes from a fixed income (computed, never saved).
    var fixedID: UUID?
}

/// What a fixed expense is, found from its name (rent, insurance, phone…), so that its payments
/// land in the right category without the person sorting them.
enum FixedExpenseNature: CaseIterable {
    case housing, insurance, telecom, subscription, transport, health, loan, education

    static func of(_ name: String, isSubscription: Bool = false) -> FixedExpenseNature? {
        let words = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased().split { !$0.isLetter }.map(String.init)
        let folded = " " + words.joined(separator: " ") + " "
        for nature in allCases {
            let found = nature.keywords.contains { keyword in
                keyword.contains(" ") ? folded.contains(" \(keyword) ") : words.contains { $0 == keyword || (keyword.count >= 5 && $0.hasPrefix(keyword)) }
            }
            if found { return nature }
        }
        return isSubscription ? .subscription : nil
    }

    var keywords: [String] {
        switch self {
        case .housing: ["loyer", "rent", "hypotheque", "mortgage", "condo", "copropriete", "logement", "appartement", "taxe fonciere", "taxes municipales",
                        "electricite", "hydro", "gaz", "chauffage", "energie", "edf", "engie", "eau potable", "facture d eau"]
        case .insurance: ["assurance", "assurances", "insurance", "mutuelle"]
        case .telecom: ["internet", "telephone", "mobile", "cellulaire", "cell", "forfait", "fibre", "wifi", "bell", "videotron", "rogers", "fido", "telus", "sfr", "bouygues", "phone"]
        case .subscription: ["abonnement", "subscription", "netflix", "spotify", "disney", "prime", "youtube", "icloud", "deezer", "crave", "xbox", "playstation", "chatgpt", "gym"]
        case .transport: ["transport", "bus", "metro", "opus", "navigo", "essence", "voiture", "automobile", "stationnement", "parking", "train", "velo", "passe"]
        case .health: ["sante", "pharmacie", "dentiste", "medecin", "therapie", "psy", "lunettes"]
        case .loan: ["pret", "credit", "emprunt", "loan", "dette"]
        case .education: ["ecole", "scolarite", "universite", "garderie", "creche", "tuition", "frais de scolarite"]
        }
    }

    /// The category it goes in when no category of its kind exists yet.
    var categoryName: String {
        switch self {
        case .housing: tr("Maison")
        case .insurance: tr("Assurances")
        case .telecom: tr("Téléphone et Internet")
        case .subscription: tr("Abonnements")
        case .transport: tr("Transport")
        case .health: tr("Santé")
        case .loan: tr("Crédits")
        case .education: tr("Études")
        }
    }

    var symbol: String {
        switch self {
        case .housing: "house"
        case .insurance: "shield"
        case .telecom: "wifi"
        case .subscription: "repeat"
        case .transport: "bus"
        case .health: "cross.case"
        case .loan: "creditcard"
        case .education: "graduationcap"
        }
    }

    var colorHex: String {
        switch self {
        case .housing: "B7791F"
        case .insurance: "2F8F7A"
        case .telecom: "3366FF"
        case .subscription: "D6409F"
        case .transport: "3366FF"
        case .health: "E5484D"
        case .loan: "64748B"
        case .education: "8C6CFF"
        }
    }

    /// The default category of its kind (rent and energy in « Maison », transport in « Transport »).
    var defaultCategoryID: UUID? {
        switch self {
        case .housing: BudgetState.fixedID(5)
        case .transport: BudgetState.fixedID(3)
        default: nil
        }
    }
}

extension MoneyPeriod {
    /// The time between two payments.
    var step: (component: Calendar.Component, value: Int) {
        switch self {
        case .day: (.day, 1)
        case .week: (.day, 7)
        case .twoWeeks: (.day, 14)
        case .month: (.month, 1)
        case .year: (.year, 1)
        }
    }
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
    var incomes: [IncomeEntry] = []
    /// The fixed incomes and expenses of « Revenus et dépenses fixes », copied here by the app so
    /// that Finances and its widgets count them on their dates.
    var fixedFlows: [MoneyItem] = []
    /// Their first date when an item has none of its own.
    var fixedFlowsStart: Date?

    enum CodingKeys: String, CodingKey {
        case monthlyBudget, categories, expenses, quickExpenses, bills, goals, accounts, netWorthHistory, incomes, fixedFlows, fixedFlowsStart
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
        incomes = c.value(.incomes, [])
        fixedFlows = c.value(.fixedFlows, [])
        fixedFlowsStart = try? c.decodeIfPresent(Date.self, forKey: .fixedFlowsStart)
    }

    static let defaultCategories: [BudgetCategory] = [
        BudgetCategory(id: BudgetState.fixedID(1), name: tr("Épicerie"), symbol: "cart", colorHex: "1E9E75", monthlyLimit: 500),
        BudgetCategory(id: BudgetState.fixedID(2), name: tr("Restos"), symbol: "fork.knife", colorHex: "F06A3C", monthlyLimit: 200),
        BudgetCategory(id: BudgetState.fixedID(3), name: tr("Transport"), symbol: "bus", colorHex: "3366FF", monthlyLimit: 150),
        BudgetCategory(id: BudgetState.fixedID(4), name: tr("Sorties"), symbol: "ticket", colorHex: "8C6CFF", monthlyLimit: 150),
        BudgetCategory(id: BudgetState.fixedID(5), name: tr("Maison"), symbol: "house", colorHex: "B7791F", monthlyLimit: 150),
        BudgetCategory(id: BudgetState.fixedID(6), name: tr("Autre"), symbol: "square.grid.2x2", colorHex: "64748B", monthlyLimit: 0),
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

    mutating func addIncome(_ income: IncomeEntry) {
        incomes.append(income)
        let cutoff = income.date.addingTimeInterval(-800 * 86_400)
        incomes.removeAll { $0.date < cutoff }
    }

    /// Replaces an expense (same id) or adds it.
    mutating func save(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) { expenses[index] = expense } else { add(expense) }
    }

    mutating func save(_ income: IncomeEntry) {
        if let index = incomes.firstIndex(where: { $0.id == income.id }) { incomes[index] = income } else { addIncome(income) }
    }

    /// The category of a fixed expense from its name: the default category of its kind, one of the
    /// same name, or a new one; « Autre » when its kind isn't recognised.
    mutating func categoryID(forFixed name: String, isSubscription: Bool = false) -> UUID? {
        if let id = existingCategoryID(forFixed: name, isSubscription: isSubscription) { return id }
        guard let nature = FixedExpenseNature.of(name, isSubscription: isSubscription) else { return nil }
        let category = BudgetCategory(name: nature.categoryName, symbol: nature.symbol, colorHex: nature.colorHex)
        categories.append(category)
        return category.id
    }

    /// The same, without creating a category.
    func existingCategoryID(forFixed name: String, isSubscription: Bool = false) -> UUID? {
        guard let nature = FixedExpenseNature.of(name, isSubscription: isSubscription) else {
            return categories.first { $0.id == BudgetState.fixedID(6) }?.id
        }
        if let id = nature.defaultCategoryID, categories.contains(where: { $0.id == id }) { return id }
        let wanted = nature.categoryName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return categories.first { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) == wanted }?.id
    }

    /// Deletes an account; the net worth follows.
    mutating func removeAccount(_ id: UUID, at date: Date = Date()) {
        accounts.removeAll { $0.id == id }
        if accounts.isEmpty { netWorthHistory = [] } else { snapshotNetWorth(at: date) }
    }

    /// Adds a payment to a savings goal.
    mutating func deposit(_ amount: Double, toGoal id: UUID) {
        guard amount > 0, let index = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[index].saved += amount
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

    /// What was spent in the interval: the expenses noted, and the payments of the fixed expenses
    /// (bills, fixed costs) on their dates up to now. A payment also noted by hand counts once.
    static func expenses(_ state: BudgetState, in interval: DateInterval, now: Date = Date()) -> [Expense] {
        let noted = state.expenses.filter { interval.contains($0.date) }
        let fixed = fixedExpenses(state, in: interval, now: now).filter { payment in
            !state.expenses.contains { isSamePayment($0.amount, $0.date, payment.amount, payment.date) && ($0.categoryID == payment.categoryID || folded($0.note) == folded(payment.note)) }
        }
        return noted + fixed
    }

    /// The payments of the bills and of the fixed expenses of « Revenus et dépenses fixes » (one
    /// already listed as a bill of the same name isn't counted twice).
    static func fixedExpenses(_ state: BudgetState, in interval: DateInterval, now: Date = Date()) -> [Expense] {
        var result: [Expense] = []
        for bill in state.bills {
            let step: (component: Calendar.Component, value: Int) = bill.period == .monthly ? (.month, 1) : (.year, 1)
            for date in paymentDates(from: bill.anchorDate, every: step, in: interval, until: now) {
                result.append(Expense(id: paymentID(bill.id, date), amount: bill.amount,
                                      categoryID: bill.categoryID ?? state.existingCategoryID(forFixed: bill.name, isSubscription: bill.isSubscription),
                                      note: bill.name, date: date, fixedID: bill.id))
            }
        }
        let billNames = Set(state.bills.map { folded($0.name) })
        for item in state.fixedFlows where !item.isIncome && !billNames.contains(folded(item.name)) {
            for date in paymentDates(from: item.date ?? state.fixedFlowsStart ?? now, every: item.period.step, in: interval, until: now) {
                result.append(Expense(id: paymentID(item.id, date), amount: item.amount,
                                      categoryID: item.categoryID ?? state.existingCategoryID(forFixed: item.name),
                                      note: item.name, date: date, fixedID: item.id))
            }
        }
        return result
    }

    /// The dates a recurring amount falls on in the interval, from its first date and up to now.
    static func paymentDates(from first: Date, every step: (component: Calendar.Component, value: Int), in interval: DateInterval, until now: Date) -> [Date] {
        let start = DateMath.startOfDay(first)
        let end = min(interval.end, now)
        var dates: [Date] = []
        var index = 0
        while index < 5_000, let date = DateMath.calendar.date(byAdding: step.component, value: step.value * index, to: start), date <= end {
            if date >= interval.start, date < interval.end { dates.append(date) }
            index += 1
        }
        return dates
    }

    /// The same payment noted twice: same amount, three days apart at most.
    static func isSamePayment(_ amount: Double, _ date: Date, _ otherAmount: Double, _ otherDate: Date) -> Bool {
        abs(amount - otherAmount) < 0.01 && abs(DateMath.daysBetween(date, otherDate)) <= 3
    }

    private static func folded(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// A stable identifier for a payment of a fixed amount on a day.
    static func paymentID(_ id: UUID, _ date: Date) -> UUID {
        var bytes = id.uuid
        let day = UInt32(max(0, Int(date.timeIntervalSince1970 / 86_400)))
        withUnsafeMutableBytes(of: &bytes) { raw in
            raw[12] ^= UInt8(truncatingIfNeeded: day >> 24)
            raw[13] ^= UInt8(truncatingIfNeeded: day >> 16)
            raw[14] ^= UInt8(truncatingIfNeeded: day >> 8)
            raw[15] ^= UInt8(truncatingIfNeeded: day)
        }
        return UUID(uuid: bytes)
    }

    static func spentThisMonth(_ state: BudgetState, at date: Date) -> Double {
        expenses(state, in: monthInterval(date), now: date).reduce(0) { $0 + $1.amount }
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
        let day = DateInterval(start: DateMath.startOfDay(date), end: DateMath.nextMidnight(after: date))
        return expenses(state, in: day, now: date).reduce(0) { $0 + $1.amount }
    }

    struct CategorySpend: Hashable {
        let category: BudgetCategory?
        let amount: Double
        var name: String { category?.name ?? tr("Sans catégorie") }
        var colorHex: String { category?.colorHex ?? "64748B" }
    }

    static func byCategory(_ state: BudgetState, in interval: DateInterval, now: Date = Date()) -> [CategorySpend] {
        var totals: [UUID?: Double] = [:]
        for expense in expenses(state, in: interval, now: now) {
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
        let now = byCategory(state, in: current, now: date)
        let before = byCategory(state, in: previous, now: date)
        let names = Set(now.map(\.name) + before.map(\.name))
        return names.map { name -> (name: String, current: Double, previous: Double) in
            (name, now.first { $0.name == name }?.amount ?? 0, before.first { $0.name == name }?.amount ?? 0)
        }
    }

    // MARK: Mini-app

    /// What came in: the incomes noted, and the fixed incomes on their dates up to now (one also
    /// noted by hand counts once).
    static func incomes(_ state: BudgetState, in interval: DateInterval, now: Date = Date()) -> [IncomeEntry] {
        let noted = state.incomes.filter { interval.contains($0.date) }
        var fixed: [IncomeEntry] = []
        for item in state.fixedFlows where item.isIncome {
            for date in paymentDates(from: item.date ?? state.fixedFlowsStart ?? now, every: item.period.step, in: interval, until: now)
            where !state.incomes.contains(where: { isSamePayment($0.amount, $0.date, item.amount, date) }) {
                fixed.append(IncomeEntry(id: paymentID(item.id, date), amount: item.amount, label: item.name, date: date, fixedID: item.id))
            }
        }
        return noted + fixed
    }

    static func earned(_ state: BudgetState, in interval: DateInterval, now: Date = Date()) -> Double {
        incomes(state, in: interval, now: now).reduce(0) { $0 + $1.amount }
    }

    static func spent(_ state: BudgetState, in interval: DateInterval, now: Date = Date()) -> Double {
        expenses(state, in: interval, now: now).reduce(0) { $0 + $1.amount }
    }

    /// One month: what came in and what went out.
    struct MonthSummary: Hashable, Identifiable {
        let start: Date
        let spent: Double
        let earned: Double
        var id: Date { start }
        var balance: Double { earned - spent }
    }

    /// The last `count` months, oldest first, the current month (so far) last.
    static func months(_ state: BudgetState, count: Int, at date: Date) -> [MonthSummary] {
        let current = monthInterval(date).start
        return (0..<count).reversed().compactMap { back in
            guard let start = DateMath.calendar.date(byAdding: .month, value: -back, to: current) else { return nil }
            let interval = monthInterval(start)
            return MonthSummary(start: start, spent: spent(state, in: interval, now: date), earned: earned(state, in: interval, now: date))
        }
    }

    /// Spending of this month so far and of last month up to the same day.
    static func monthToDate(_ state: BudgetState, at date: Date) -> (current: Double, previous: Double) {
        let month = monthInterval(date)
        let elapsed = max(1, date.timeIntervalSince(month.start))
        let previousStart = DateMath.calendar.date(byAdding: .month, value: -1, to: month.start) ?? month.start
        let previousEnd = min(previousStart.addingTimeInterval(elapsed), month.start)
        return (spent(state, in: DateInterval(start: month.start, end: max(month.start, date)), now: date),
                spent(state, in: DateInterval(start: previousStart, end: previousEnd), now: date))
    }

    /// A category this month: what was spent against its limit.
    struct CategoryStatus: Hashable, Identifiable {
        let category: BudgetCategory
        let spent: Double
        var id: UUID { category.id }
        var limit: Double { category.monthlyLimit }
        /// Spent over the limit, nil without a limit.
        var ratio: Double? { limit > 0 ? spent / limit : nil }
        var isOver: Bool { limit > 0 && spent > limit }
    }

    /// Every category with a limit or some spending this month, the biggest spending first.
    static func categoryStatus(_ state: BudgetState, at date: Date) -> [CategoryStatus] {
        let spending = expenses(state, in: monthInterval(date), now: date)
        return state.categories.map { category in
            CategoryStatus(category: category, spent: spending.filter { $0.categoryID == category.id }.reduce(0) { $0 + $1.amount })
        }
        .filter { $0.spent > 0 || $0.limit > 0 }
        .sorted { $0.spent > $1.spent }
    }

    /// What to put aside each month to reach a goal by its date; nil without a date or once reached.
    static func monthlyToReach(_ goal: SavingsGoal, at date: Date) -> Double? {
        guard let deadline = goal.deadline, goal.saved < goal.target else { return nil }
        let months = max(1, DateMath.calendar.dateComponents([.month], from: date, to: deadline).month ?? 0)
        return (goal.target - goal.saved) / Double(months)
    }

    /// The bills due in the next days, and their total.
    static func billsTotal(_ state: BudgetState, at date: Date, within days: Int) -> Double {
        upcomingBills(state, at: date, within: days).reduce(0) { $0 + $1.bill.amount }
    }

    static func billsMonthly(_ state: BudgetState) -> Double {
        state.bills.reduce(0) { $0 + $1.monthlyCost }
    }
}
