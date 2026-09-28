import Foundation

/// One of the three priorities of the day. Done flags only count for the day they were set.
struct PriorityItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var doneDayKey: String?

    func isDone(on date: Date) -> Bool {
        doneDayKey == DateMath.dayKey(date)
    }
}

struct ProjectTask: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var isDone = false
    var completedAt: Date?
}

struct Project: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var colorHex: String = "3366FF"
    var deadline: Date?
    var tasks: [ProjectTask] = []

    var doneCount: Int { tasks.filter(\.isDone).count }
    var remaining: [ProjectTask] { tasks.filter { !$0.isDone } }
    var progress: Double { tasks.isEmpty ? 0 : Double(doneCount) / Double(tasks.count) }

    mutating func toggle(_ taskID: UUID, at date: Date = Date()) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].isDone.toggle()
        tasks[index].completedAt = tasks[index].isDone ? date : nil
    }
}

struct Deadline: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    /// Exact moment of the deadline (date and time).
    var date: Date
}

/// A tap counter: coffees, push-ups, pages… Daily counters restart at midnight.
struct CounterItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var symbol: String = "plus.circle"
    var colorHex: String = "3366FF"
    var step: Int = 1
    var goal: Int?
    var resetsDaily = true
    var total: Int = 0
    var dayKey: String?

    func value(on date: Date) -> Int {
        guard resetsDaily else { return total }
        return dayKey == DateMath.dayKey(date) ? total : 0
    }

    mutating func add(_ delta: Int, on date: Date) {
        let current = value(on: date)
        total = max(0, current + delta)
        dayKey = DateMath.dayKey(date)
    }
}

/// A Focus session, logged when it starts (and shortened if stopped early).
struct FocusLog: Codable, Hashable {
    var start: Date
    var minutes: Int
}

struct ProductivityState: Codable, Hashable {
    var priorities: [PriorityItem] = []
    var projects: [Project] = []
    var deadlines: [Deadline] = []
    var counters: [CounterItem] = []
    var focusLog: [FocusLog] = []
    var weeklyFocusGoalHours: Double = 10

    enum CodingKeys: String, CodingKey { case priorities, projects, deadlines, counters, focusLog, weeklyFocusGoalHours }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        priorities = c.value(.priorities, [])
        projects = c.value(.projects, [])
        deadlines = c.value(.deadlines, [])
        counters = c.value(.counters, [])
        focusLog = c.value(.focusLog, [])
        weeklyFocusGoalHours = c.value(.weeklyFocusGoalHours, 10)
    }

    mutating func togglePriority(_ id: UUID, on date: Date = Date()) {
        guard let index = priorities.firstIndex(where: { $0.id == id }) else { return }
        let key = DateMath.dayKey(date)
        priorities[index].doneDayKey = priorities[index].doneDayKey == key ? nil : key
    }

    mutating func toggleProjectTask(project: UUID, task: UUID, at date: Date = Date()) {
        guard let index = projects.firstIndex(where: { $0.id == project }) else { return }
        projects[index].toggle(task, at: date)
    }

    mutating func stepCounter(_ id: UUID, by delta: Int, on date: Date = Date()) {
        guard let index = counters.firstIndex(where: { $0.id == id }) else { return }
        counters[index].add(delta * max(1, counters[index].step), on: date)
    }

    mutating func logFocusStart(at date: Date, minutes: Int) {
        focusLog.append(FocusLog(start: date, minutes: minutes))
        let cutoff = date.addingTimeInterval(-120 * 86_400)
        focusLog.removeAll { $0.start < cutoff }
    }

    /// Shortens the running session to the time actually spent.
    mutating func logFocusStop(at date: Date) {
        guard let last = focusLog.last else { return }
        let plannedEnd = last.start.addingTimeInterval(TimeInterval(last.minutes) * 60)
        guard plannedEnd > date else { return }
        let spent = Int((date.timeIntervalSince(last.start) / 60).rounded(.down))
        if spent <= 0 {
            focusLog.removeLast()
        } else {
            focusLog[focusLog.count - 1].minutes = spent
        }
    }
}

enum ProductivityMath {
    /// Minutes of Focus already spent (a running session only counts its elapsed part).
    static func focusMinutes(_ state: ProductivityState, in interval: DateInterval, now: Date) -> Double {
        state.focusLog.reduce(0.0) { total, log in
            guard interval.contains(log.start) else { return total }
            let end = min(now, log.start.addingTimeInterval(TimeInterval(log.minutes) * 60))
            return total + max(0, end.timeIntervalSince(log.start) / 60)
        }
    }

    static func focusMinutes(_ state: ProductivityState, weekOf date: Date) -> Double {
        guard let week = DateMath.calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return focusMinutes(state, in: week, now: date)
    }

    /// Focus minutes for each day of the current week, Monday first.
    static func focusByDay(_ state: ProductivityState, weekOf date: Date) -> [Double] {
        DateMath.week(containing: date).map { day in
            let interval = DateInterval(start: DateMath.startOfDay(day), duration: 86_400)
            return focusMinutes(state, in: interval, now: date)
        }
    }

    static func nextDeadline(_ state: ProductivityState, after date: Date) -> Deadline? {
        state.deadlines.filter { $0.date > date }.min { $0.date < $1.date }
    }

    /// The project with the nearest deadline, or the first unfinished one.
    static func mainProject(_ state: ProductivityState, at date: Date) -> Project? {
        let open = state.projects.filter { $0.progress < 1 || $0.tasks.isEmpty }
        let dated = open.filter { $0.deadline != nil }.sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
        return dated.first ?? open.first ?? state.projects.first
    }
}
