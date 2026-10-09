import Foundation

enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Comparable {
    case none = 0, low, medium, high
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: tr("Aucune")
        case .low: tr("Basse")
        case .medium: tr("Moyenne", context: "priority")
        case .high: tr("Haute")
        }
    }

    var colorHex: String? {
        switch self {
        case .none: nil
        case .low: "3A8DDE"
        case .medium: "F2A33A"
        case .high: "E5484D"
        }
    }

    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum TaskRepeat: String, Codable, CaseIterable, Identifiable {
    case never, daily, weekdays, weekly, monthly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: tr("Jamais")
        case .daily: tr("Chaque jour")
        case .weekdays: tr("En semaine")
        case .weekly: tr("Chaque semaine")
        case .monthly: tr("Chaque mois")
        }
    }

    /// The next date after a due date (weekdays skip Saturday and Sunday).
    func next(after date: Date) -> Date? {
        let calendar = DateMath.calendar
        switch self {
        case .never: return nil
        case .daily: return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .weekdays:
            var next = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            while calendar.isDateInWeekend(next) { next = calendar.date(byAdding: .day, value: 1, to: next) ?? next }
            return next
        }
    }
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var isDone = false
    var createdAt = Date()
    var completedAt: Date?
    var priority: TaskPriority = .none
    /// The day (and time, when `hasTime`) it is due.
    var due: Date?
    var hasTime = false
    var repeats: TaskRepeat = .never
    var notes = ""

    init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date = Date(), completedAt: Date? = nil,
         priority: TaskPriority = .none, due: Date? = nil, hasTime: Bool = false, repeats: TaskRepeat = .never, notes: String = "") {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.priority = priority
        self.due = due
        self.hasTime = hasTime
        self.repeats = repeats
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey { case id, title, isDone, createdAt, completedAt, priority, due, hasTime, repeats, notes }

    /// Tolerant: tasks saved before priorities, due dates and repeats keep working.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        title = c.value(.title, "")
        isDone = c.value(.isDone, false)
        createdAt = c.value(.createdAt, Date())
        completedAt = c.optional(.completedAt)
        priority = c.value(.priority, .none)
        due = c.optional(.due)
        hasTime = c.value(.hasTime, false)
        repeats = c.value(.repeats, .never)
        notes = c.value(.notes, "")
    }

    func isOverdue(at now: Date = Date()) -> Bool {
        guard !isDone, let due else { return false }
        return hasTime ? due < now : DateMath.startOfDay(due) < DateMath.startOfDay(now)
    }

    func isDue(on day: Date) -> Bool {
        guard let due else { return false }
        return DateMath.isSameDay(due, day)
    }
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
        case .day: tr("par jour")
        case .week: tr("par semaine")
        case .twoWeeks: tr("aux 2 semaines")
        case .month: tr("par mois")
        case .year: tr("par an")
        }
    }
}

struct MoneyItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var amount: Double
    var period: MoneyPeriod
    var isIncome: Bool
    /// The day of a payment (the next or a past one); nil: the start of the calculation.
    var date: Date?
    /// For an expense, the Finances category its payments count in (found from its name).
    var categoryID: UUID?

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

    mutating func toggleTask(_ id: UUID, at now: Date = Date()) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isDone.toggle()
        tasks[index].completedAt = tasks[index].isDone ? now : nil
        // A repeating task comes back for its next date once done.
        let task = tasks[index]
        guard task.repeats != .never, let next = task.repeats.next(after: task.due ?? now) else { return }
        let isNext = { (other: TaskItem) in
            !other.isDone && other.title == task.title && other.repeats == task.repeats && other.due.map { DateMath.isSameDay($0, next) } == true
        }
        if task.isDone {
            guard !tasks.contains(where: isNext) else { return }
            tasks.append(TaskItem(title: task.title, createdAt: now, priority: task.priority, due: next, hasTime: task.hasTime, repeats: task.repeats, notes: task.notes))
        } else if let copy = tasks.lastIndex(where: isNext) {
            // Unchecked by mistake: the next one it had created goes away.
            tasks.remove(at: copy)
        }
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
