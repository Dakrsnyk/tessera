import Foundation

/// The figures of the deep part of « Analyse » (Finances, 2026-11-26). Pure functions on the person's own
/// operations: each one is an exact computation (a rate, an average, a median), never an estimate from outside
/// data and never advice. `now` is always passed in so the tests choose the date.
enum BudgetAnalysis {
    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// From the 1st of the month of `now` to the end of that day.
    private static func monthSoFar(_ now: Date) -> DateInterval {
        let start = BudgetMath.monthInterval(now).start
        return DateInterval(start: start, end: max(start, DateMath.nextMidnight(after: now)))
    }

    // MARK: Savings rate

    struct Savings: Hashable {
        let earned: Double
        let spent: Double
        /// (earned − spent) / earned; nil without income (no division by zero). Negative when more is spent than earned.
        let rate: Double?
        var kept: Double { earned - spent }
    }

    /// The month so far: what came in, what went out, and the share of the income kept.
    /// Nil when nothing was noted either way.
    static func savings(_ state: BudgetState, at now: Date) -> Savings? {
        let interval = monthSoFar(now)
        let earned = BudgetMath.earned(state, in: interval, now: now)
        let spent = BudgetMath.spent(state, in: interval, now: now)
        guard earned > 0 || spent > 0 else { return nil }
        return Savings(earned: earned, spent: spent, rate: earned > 0 ? (earned - spent) / earned : nil)
    }

    // MARK: End-of-month projection

    struct Projection: Hashable {
        /// Everything spent so far this month: expenses noted and fixed payments already due.
        let spentToDate: Double
        /// The part noted by hand: only it is extrapolated (a rent paid on the 1st is not a daily pace).
        let notedToDate: Double
        let daysElapsed: Int
        let daysInMonth: Int
        /// What is already noted for the days still to come this month.
        let plannedAhead: Double
        /// The fixed payments (bills, fixed costs) still due this month.
        let fixedAhead: Double
        var daysLeft: Int { max(0, daysInMonth - daysElapsed) }
        var perDay: Double { daysElapsed > 0 ? notedToDate / Double(daysElapsed) : 0 }
        /// Spent to date + (noted to date / days elapsed) × days left + noted ahead + fixed payments still due.
        var projected: Double { spentToDate + perDay * Double(daysLeft) + plannedAhead + fixedAhead }
    }

    /// Nil while nothing is spent or planned this month.
    static func projection(_ state: BudgetState, at now: Date) -> Projection? {
        let month = BudgetMath.monthInterval(now)
        let sofar = monthSoFar(now)
        let spent = BudgetMath.spent(state, in: sofar, now: now)
        let noted = state.expenses.filter { sofar.holds($0.date) }.reduce(0) { $0 + $1.amount }
        // Noted by hand for a later day of the month, and the fixed payments that fall then.
        let ahead = state.expenses.filter { $0.date >= sofar.end && $0.date < month.end }.reduce(0) { $0 + $1.amount }
        let rest = DateInterval(start: min(sofar.end, month.end), end: month.end)
        let fixedAhead = rest.duration > 0
            ? BudgetMath.fixedExpenses(state, in: rest, now: month.end).filter { $0.date < month.end }.reduce(0) { $0 + $1.amount }
            : 0
        guard spent > 0 || ahead > 0 || fixedAhead > 0 else { return nil }
        let elapsed = max(1, DateMath.daysBetween(month.start, now) + 1)
        let days = max(elapsed, DateMath.daysBetween(month.start, month.end))
        return Projection(spentToDate: spent, notedToDate: min(noted, spent), daysElapsed: elapsed, daysInMonth: days,
                          plannedAhead: ahead, fixedAhead: fixedAhead)
    }

    // MARK: Categories against last month and the 3 months before

    struct CategoryTrend: Hashable, Identifiable {
        let name: String
        let symbol: String
        let colorHex: String
        let current: Double
        /// Last month, up to the same moment of the month.
        let previous: Double
        /// Average of the up-to-3 months before this one, up to the same moment; nil when none of them has any spending.
        let average: Double?
        let averageMonths: Int
        var id: String { name }
        var differenceFromPrevious: Double { current - previous }
        var differenceFromAverage: Double? { average.map { current - $0 } }
    }

    /// Every category spent this month so far, last month or in the 3 months before, up to the same moment of the month,
    /// the biggest rise against the average first.
    static func categoryTrends(_ state: BudgetState, at now: Date) -> [CategoryTrend] {
        let calendar = DateMath.calendar
        let month = BudgetMath.monthInterval(now)
        let elapsed = max(1, now.timeIntervalSince(month.start))
        func window(_ back: Int) -> DateInterval? {
            guard let start = calendar.date(byAdding: .month, value: -back, to: month.start) else { return nil }
            if back == 0 { return DateInterval(start: month.start, end: max(month.start.addingTimeInterval(1), now)) }
            let monthEnd = BudgetMath.monthInterval(start).end
            return DateInterval(start: start, end: min(start.addingTimeInterval(elapsed), monthEnd))
        }
        guard let currentWindow = window(0) else { return [] }
        let current = BudgetMath.byCategory(state, in: currentWindow, now: now)
        let previous = window(1).map { BudgetMath.byCategory(state, in: $0, now: now) } ?? []
        // Months with something spent (anywhere in them) count in the average; empty months do not drag it down.
        let earlier: [[BudgetMath.CategorySpend]] = (1...3).compactMap { back in
            guard let part = window(back), let start = calendar.date(byAdding: .month, value: -back, to: month.start),
                  BudgetMath.spent(state, in: BudgetMath.monthInterval(start), now: now) > 0 else { return nil }
            return BudgetMath.byCategory(state, in: part, now: now)
        }
        let names = Array(Set(current.map(\.name) + previous.map(\.name) + earlier.flatMap { $0.map(\.name) }))
        return names.map { name in
            let this = current.first { $0.name == name }
            let last = previous.first { $0.name == name }
            var spend = this ?? last
            var sum = 0.0
            for month in earlier {
                if let found = month.first(where: { $0.name == name }) {
                    sum += found.amount
                    if spend == nil { spend = found }
                }
            }
            let average: Double? = earlier.isEmpty ? nil : sum / Double(earlier.count)
            return CategoryTrend(name: name, symbol: spend?.category?.symbol ?? "square.grid.2x2", colorHex: spend?.colorHex ?? "64748B",
                                 current: this?.amount ?? 0, previous: last?.amount ?? 0, average: average, averageMonths: earlier.count)
        }
        .sorted {
            let a = abs($0.differenceFromAverage ?? $0.differenceFromPrevious), b = abs($1.differenceFromAverage ?? $1.differenceFromPrevious)
            return a == b ? $0.name < $1.name : a > b
        }
    }

    /// The categories whose spending so far is at least 1 above their average of the earlier months, the biggest rise first.
    static func biggestRises(_ trends: [CategoryTrend], limit: Int = 3) -> [CategoryTrend] {
        Array(trends.filter { ($0.differenceFromAverage ?? 0) >= 1 }
            .sorted { ($0.differenceFromAverage ?? 0) > ($1.differenceFromAverage ?? 0) }
            .prefix(limit))
    }

    // MARK: Recurring spending

    struct Recurring: Hashable, Identifiable {
        let label: String
        /// Median amount of the occurrences.
        let amount: Double
        let months: Int
        var id: String { label }
    }

    /// Spending noted by hand (not a fixed expense already known) with the same label (note, else shop) in at least 3 different
    /// months of the last 6, at amounts within 10 % of their median. Biggest amount first.
    static func recurring(_ state: BudgetState, at now: Date) -> [Recurring] {
        let calendar = DateMath.calendar
        let thisMonth = BudgetMath.monthInterval(now).start
        guard let from = calendar.date(byAdding: .month, value: -5, to: thisMonth) else { return [] }
        let candidates = BudgetMath.expenses(state, in: DateInterval(start: from, end: max(from, DateMath.nextMidnight(after: now))), now: now)
            .filter { $0.fixedID == nil && $0.amount > 0 }
        var groups: [String: [Expense]] = [:]
        for expense in candidates {
            let key = fold(expense.note.isEmpty ? (expense.merchant ?? "") : expense.note)
            if !key.isEmpty { groups[key, default: []].append(expense) }
        }
        var result: [Recurring] = []
        for (_, items) in groups {
            let sorted = items.map(\.amount).sorted()
            let median = sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            let regular = items.filter { abs($0.amount - median) <= median * 0.1 }
            let months = Set(regular.map { BudgetMath.monthInterval($0.date).start })
            guard months.count >= 3, let first = regular.first else { continue }
            let label = first.note.isEmpty ? (first.merchant ?? "") : first.note
            result.append(Recurring(label: label, amount: median, months: months.count))
        }
        return result.sorted { $0.amount == $1.amount ? $0.label < $1.label : $0.amount > $1.amount }
    }

    // MARK: Days of the week

    struct WeekdaySpend: Hashable, Identifiable {
        /// Calendar numbering: 1 = Sunday … 7 = Saturday.
        let weekday: Int
        let total: Double
        /// How many of that weekday the window holds.
        let occurrences: Int
        /// total / occurrences: what a given day of the week costs on average.
        var average: Double { occurrences > 0 ? total / Double(occurrences) : 0 }
        var id: Int { weekday }
    }

    /// The last 12 weeks (84 days up to today, starting at the first spending if it came later), by day of the week,
    /// in display order. Nil under 8 expenses or 14 days of history: too little to say anything.
    static func weekdays(_ state: BudgetState, at now: Date) -> [WeekdaySpend]? {
        let calendar = DateMath.calendar
        let today = DateMath.startOfDay(now)
        guard let windowStart = calendar.date(byAdding: .day, value: -83, to: today) else { return nil }
        let end = DateMath.nextMidnight(after: now)
        let spending = BudgetMath.expenses(state, in: DateInterval(start: windowStart, end: max(windowStart, end)), now: now)
            .filter { $0.amount > 0 && $0.date < end }
        guard spending.count >= 8, let firstDate = spending.map(\.date).min() else { return nil }
        let start = DateMath.startOfDay(firstDate)
        guard DateMath.daysBetween(start, today) + 1 >= 14 else { return nil }
        var totals = [Int: Double](), counts = [Int: Int]()
        for expense in spending { totals[calendar.component(.weekday, from: expense.date), default: 0] += expense.amount }
        var day = start
        while day <= today {
            counts[calendar.component(.weekday, from: day), default: 0] += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        // Calendar numbering (1 = Sunday), from the first day of the week of the person's calendar.
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return order.map { WeekdaySpend(weekday: $0, total: totals[$0] ?? 0, occurrences: counts[$0] ?? 0) }
    }

    /// The day of the week that costs the most on average; nil when none costs anything.
    static func priciestWeekday(_ days: [WeekdaySpend]) -> WeekdaySpend? {
        days.filter { $0.average > 0 }.max { $0.average < $1.average }
    }
}
