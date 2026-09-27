import Foundation

struct TaskItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var isDone = false
    var createdAt = Date()
    var completedAt: Date?
}

struct Habit: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var colorHex: String
    /// Day keys (yyyy-MM-dd) on which the habit was completed.
    var completedDays: [String] = []
    var reminderHour: Int?
    var reminderMinute: Int?

    func isDone(on date: Date) -> Bool {
        completedDays.contains(DateMath.dayKey(date))
    }

    mutating func toggle(on date: Date) {
        let key = DateMath.dayKey(date)
        if let index = completedDays.firstIndex(of: key) {
            completedDays.remove(at: index)
        } else {
            completedDays.append(key)
            // Keep the log bounded: a year of history is enough for streaks.
            if completedDays.count > 400 { completedDays.removeFirst(completedDays.count - 400) }
        }
    }

    /// Consecutive completed days ending today (or yesterday if today isn't done yet).
    func streak(asOf date: Date = Date()) -> Int {
        var day = isDone(on: date) ? date : DateMath.calendar.date(byAdding: .day, value: -1, to: date) ?? date
        var count = 0
        while isDone(on: day) {
            count += 1
            guard let previous = DateMath.calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var reminderDate: Date? {
        guard let reminderHour, let reminderMinute else { return nil }
        return DateMath.calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date())
    }
}

struct HydrationState: Codable, Hashable {
    var goal = 8
    /// Glasses per day key.
    var log: [String: Int] = [:]

    func glasses(on date: Date) -> Int { log[DateMath.dayKey(date)] ?? 0 }

    mutating func add(_ delta: Int, on date: Date) {
        let key = DateMath.dayKey(date)
        log[key] = min(40, max(0, (log[key] ?? 0) + delta))
        if log.count > 120 {
            let keep = Set(log.keys.sorted().suffix(90))
            log = log.filter { keep.contains($0.key) }
        }
    }
}

struct FocusSession: Codable, Hashable {
    var startDate: Date?
    var endDate: Date?
    var lastDurationMinutes = 25

    func isRunning(at date: Date = Date()) -> Bool {
        guard let endDate else { return false }
        return endDate > date
    }

    func hasJustFinished(at date: Date = Date()) -> Bool {
        guard let endDate else { return false }
        return endDate <= date && date.timeIntervalSince(endDate) < 60 * 60
    }
}

enum MoneyPeriod: String, Codable, CaseIterable, Identifiable {
    case day, week, twoWeeks, month, year
    var id: String { rawValue }

    var days: Double {
        switch self {
        case .day: 1
        case .week: 7
        case .twoWeeks: 14
        case .month: 365.0 / 12.0
        case .year: 365
        }
    }

    var title: String {
        switch self {
        case .day: "par jour"
        case .week: "par semaine"
        case .twoWeeks: "aux 2 semaines"
        case .month: "par mois"
        case .year: "par an"
        }
    }
}

struct MoneyItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double
    var period: MoneyPeriod
    var isIncome: Bool

    var perDay: Double { amount / period.days }
}

struct MoneyState: Codable, Hashable {
    var items: [MoneyItem] = []
    var startDate: Date = DateMath.startOfDay(Date())
}

/// Everything the user writes in the app that widgets display: tasks, habits, water, focus, money.
struct ContentState: Codable, Hashable {
    var tasks: [TaskItem] = []
    var habits: [Habit] = []
    var hydration = HydrationState()
    var focus = FocusSession()
    var money = MoneyState()

    enum CodingKeys: String, CodingKey { case tasks, habits, hydration, focus, money }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = (try? c.decodeIfPresent([TaskItem].self, forKey: .tasks)) ?? []
        habits = (try? c.decodeIfPresent([Habit].self, forKey: .habits)) ?? []
        hydration = (try? c.decodeIfPresent(HydrationState.self, forKey: .hydration)) ?? HydrationState()
        focus = (try? c.decodeIfPresent(FocusSession.self, forKey: .focus)) ?? FocusSession()
        money = (try? c.decodeIfPresent(MoneyState.self, forKey: .money)) ?? MoneyState()
    }

    mutating func toggleTask(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone.toggle()
        tasks[index].completedAt = tasks[index].isDone ? Date() : nil
    }

    mutating func toggleHabit(_ id: UUID, on date: Date = Date()) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].toggle(on: date)
    }

    /// Open tasks first, then the ones done today; older completed tasks are hidden.
    func visibleTasks(showingCompleted: Bool, now: Date = Date()) -> [TaskItem] {
        let open = tasks.filter { !$0.isDone }
        guard showingCompleted else { return open }
        let doneToday = tasks.filter { task in
            guard task.isDone, let completedAt = task.completedAt else { return false }
            return DateMath.isSameDay(completedAt, now)
        }
        return open + doneToday
    }
}
