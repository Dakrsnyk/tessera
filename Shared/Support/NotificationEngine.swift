import Foundation

/// The six families of « notifications intelligentes », each with its own switch (Profil › Rappels).
enum SmartCategory: String, Codable, CaseIterable, Identifiable {
    case nutrition, habits, fitness, planning, goals, general
    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: tr("Nutrition")
        case .habits: tr("Habitudes")
        case .fitness: tr("Fitness")
        case .planning: tr("Planning")
        case .goals: tr("Objectifs et motivation")
        case .general: tr("Rappels généraux")
        }
    }

    var symbol: String {
        switch self {
        case .nutrition: "fork.knife"
        case .habits: "checkmark.circle"
        case .fitness: "figure.strengthtraining.traditional"
        case .planning: "calendar"
        case .goals: "target"
        case .general: "bell"
        }
    }

    func isEnabled(in settings: AppSettings) -> Bool {
        switch self {
        case .nutrition: settings.remindsNutrition
        case .habits: settings.remindsHabits
        case .fitness: settings.remindsFitness
        case .planning: settings.remindsPlanning
        case .goals: settings.remindsGoals
        case .general: settings.remindsGeneral
        }
    }
}

/// What the engine planned or sent, the last two weeks: what the « no repeat » rule reads. Lives in the
/// App Group's defaults (like `EncouragementLog`), so the app and the Lock Screen intents share it.
/// An entry dated in the future is a notification still waiting: the next planning replaces it.
struct NotificationLog: Codable, Hashable {
    struct Entry: Codable, Hashable {
        var id: String
        /// The category's raw value: an entry of a category a later version removes is kept and ignored.
        var categoryName: String
        var date: Date

        enum CodingKeys: String, CodingKey { case id, categoryName, date }

        init(id: String, categoryName: String, date: Date) {
            self.id = id
            self.categoryName = categoryName
            self.date = date
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = c.value(.id, "")
            categoryName = c.value(.categoryName, "")
            date = c.value(.date, Date.distantPast)
        }
    }

    var entries: [Entry] = []

    static let key = "tessera.notifications.log"

    static var defaults: UserDefaults { UserDefaults(suiteName: AppGroup.identifier) ?? .standard }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = c.value(.entries, [])
    }

    enum CodingKeys: String, CodingKey { case entries }

    static func load(_ defaults: UserDefaults = NotificationLog.defaults) -> NotificationLog {
        guard let data = defaults.data(forKey: key),
              let log = try? JSONDecoder().decode(NotificationLog.self, from: data) else { return NotificationLog() }
        return log
    }

    func save(_ defaults: UserDefaults = NotificationLog.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

/// THE engine of the local smart notifications. One pipeline, the same for every category:
/// data → candidates → the person's switches → still relevant? → no repeat (history) → quiet hours →
/// daily ceiling and spacing → planned. It extends `SmartReminders` (the workout of the day, the meal
/// nobody noted, the bills: they enter as candidates) and counts the `Encouragements` already sent, so
/// the day's total stays under the ceiling whatever their origin.
///
/// `plan` is pure (tested): every state and the date are injected. `SmartReminders.sync` plans again
/// after each change of data and takes back the notifications that no longer apply.
///
/// Tone: positive, never guilt. A candidate exists only when the data allows it (no figure made up);
/// the ones that depend on a day's figures are planned for today only, because they are planned again
/// at each change (a notification for next Sunday could not know Sunday's figures).
enum NotificationEngine {
    static let prefix = SmartReminders.prefix + "n."

    enum Kind: String, Hashable {
        case lunch, calories, protein, nutritionWeek, hydration
        case habitsLeft, habitStreak, habitRecord, habitsWeek
        case sessionsLeft, steps, nextSession, fitnessWeek
        case classSoon, eventTomorrow, busyTomorrow, tasksLeft
        case weightProgress, goalsWeek, weekStart
        case legacyWorkout, legacyMeals, legacyBill
    }

    /// A notification the data calls for.
    struct Candidate: Hashable {
        let id: String
        let category: SmartCategory
        let kind: Kind
        let title: String
        let body: String
        /// When it shows. The engine may push it a little later to keep the spacing.
        var date: Date
        /// The data that justifies it (for the logs and the tests, never shown).
        let basis: String
        /// 0 comes first when the ceiling is reached: a class in 30 minutes, then the former reminders…
        let priority: Int
        /// false: keeps its time whatever the spacing (a class in 30 minutes is useless an hour later).
        let flexible: Bool
    }

    /// Today's steps and the goal, given by the app only when the motion access is allowed and available.
    struct Steps: Hashable {
        var today: Int
        var goal: Int
    }

    /// Everything the engine reads.
    struct Inputs {
        var settings = AppSettings()
        var fitness = FitnessState()
        var nutrition = NutritionState()
        var budget = BudgetState()
        var content = ContentState()
        var student = StudentState()
        var profile = UserProfile()
        var steps: Steps? = nil
        /// The ISO weekdays (1 = lundi … 7 = dimanche) a habit is planned on. A habit absent from it (or
        /// with no day) is planned every day. A day not planned is neither asked nor counted against.
        var habitSchedule: [UUID: Set<Int>] = [:]

        func isPlanned(_ habit: Habit, on day: Date) -> Bool {
            guard let days = habitSchedule[habit.id], !days.isEmpty else { return true }
            return days.contains(FitnessMath.isoWeekday(day))
        }
    }

    // MARK: Plan

    /// The notifications to plan from `now` over `days` days, the soonest first.
    static func plan(_ inputs: Inputs, log: NotificationLog = NotificationLog(),
                     encouragements: EncouragementLog = EncouragementLog(),
                     now: Date = Date(), days: Int = 7) -> [Candidate] {
        let settings = inputs.settings
        let delivered = log.entries.filter { $0.date <= now }
        let deliveredIDs = Set(delivered.map(\.id))

        var pool = collect(inputs, encouragements: encouragements, now: now, days: days)
            .filter { $0.category.isEnabled(in: settings) }
            .filter { isRelevant($0, inputs, now: now) }
            .filter { !isQuiet($0.date, settings: settings) }
            .filter { !deliveredIDs.contains($0.id) }
            .sorted { ($0.priority, $0.date) < ($1.priority, $1.date) }
        var seen = Set<String>()
        pool = pool.filter { seen.insert($0.id).inserted }

        // What already takes room: the notifications sent, and the encouragements sent or waiting.
        var taken = delivered.map(\.date) + encouragements.entries.map(\.date)
        var perDay: [String: Int] = [:]
        for date in taken { perDay[DateMath.dayKey(date), default: 0] += 1 }
        let spacing = TimeInterval(settings.minNotificationSpacingMinutes * 60)
        let cap = max(1, settings.dailyNotificationCap)

        var accepted: [Candidate] = []
        for var candidate in pool {
            let key = DateMath.dayKey(candidate.date)
            guard perDay[key, default: 0] < cap,
                  let date = freeDate(candidate, taken: taken, spacing: spacing, settings: settings) else { continue }
            candidate.date = date
            accepted.append(candidate)
            taken.append(date)
            perDay[key, default: 0] += 1
        }
        return accepted.sorted { $0.date < $1.date }
    }

    /// The time the candidate can keep, or a later one the same day that respects the spacing; nil if none.
    private static func freeDate(_ candidate: Candidate, taken: [Date], spacing: TimeInterval, settings: AppSettings) -> Date? {
        func isFree(_ date: Date) -> Bool {
            !taken.contains { abs($0.timeIntervalSince(date)) < spacing }
        }
        if !candidate.flexible || isFree(candidate.date) { return candidate.date }
        var date = candidate.date
        for _ in 0..<12 {
            date = date.addingTimeInterval(15 * 60)
            guard DateMath.isSameDay(date, candidate.date), !isQuiet(date, settings: settings) else { return nil }
            if isFree(date) { return date }
        }
        return nil
    }

    /// Whether a date falls in the quiet hours (by default 22:00 to 8:00).
    static func isQuiet(_ date: Date, settings: AppSettings) -> Bool {
        let hour = DateMath.calendar.component(.hour, from: date)
        let start = settings.quietStartHour
        let end = settings.quietEndHour
        if start == end { return false }
        return start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
    }

    /// A last look at the data: is the thing still worth saying at that time?
    private static func isRelevant(_ candidate: Candidate, _ i: Inputs, now: Date) -> Bool {
        guard candidate.date > now, DateMath.startOfDay(candidate.date) >= DateMath.startOfDay(now) else { return false }
        let day = candidate.date
        switch candidate.kind {
        case .lunch:
            return !NutritionMath.entries(i.nutrition, on: day).contains { $0.meal == .lunch }
        case .legacyMeals:
            return NutritionMath.entries(i.nutrition, on: day).isEmpty
        case .habitsLeft:
            return !habitsLeft(i, on: day).isEmpty
        case .steps:
            return !isRestDay(i.fitness, day)
        case .sessionsLeft:
            return !isRestDay(i.fitness, day) && !hasTrained(i.fitness, on: day, now: now)
        case .legacyWorkout:
            return !hasTrained(i.fitness, on: day, now: now)
        default:
            return true
        }
    }

    // MARK: Delivery

    private static let lock = NSLock()

    /// Plans, then records what is kept in the history. The lock only protects the current process: an
    /// intent run in another process can still write at the same time (a rare race, the last write wins;
    /// `SmartReminders.sync` then removes any pending request outside the plan). The entries still waiting
    /// from the last planning are replaced.
    static func commit(_ inputs: Inputs, now: Date = Date(), defaults: UserDefaults = NotificationLog.defaults) -> [Candidate] {
        lock.withLock {
            var log = NotificationLog.load(defaults)
            log.entries.removeAll { $0.date > now }
            let list = plan(inputs, log: log, encouragements: EncouragementLog.load(defaults), now: now)
            for candidate in list {
                log.entries.append(NotificationLog.Entry(id: candidate.id, categoryName: candidate.category.rawValue, date: candidate.date))
            }
            let cutoff = now.addingTimeInterval(-14 * 86_400)
            log.entries.removeAll { $0.date < cutoff }
            log.save(defaults)
            return list
        }
    }

    /// Nothing is planned (no permission): the waiting entries go, so they don't count against the day.
    static func forgetPending(now: Date = Date(), defaults: UserDefaults = NotificationLog.defaults) {
        lock.withLock {
            var log = NotificationLog.load(defaults)
            log.entries.removeAll { $0.date > now }
            log.save(defaults)
        }
    }

    // MARK: Collecting

    private static func collect(_ i: Inputs, encouragements: EncouragementLog, now: Date, days: Int) -> [Candidate] {
        let calendar = DateMath.calendar
        let today = DateMath.startOfDay(now)
        let coming = (0..<max(1, days)).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        var out: [Candidate] = []
        out += legacy(i, now: now, days: days)
        out += nutrition(i, encouragements: encouragements, now: now, today: today)
        out += habits(i, now: now, today: today)
        out += fitness(i, now: now, today: today, coming: coming)
        out += planning(i, now: now, today: today, coming: coming)
        out += goals(i, now: now, today: today, coming: coming)
        return out
    }

    private static func at(_ day: Date, hour: Int, minute: Int = 0) -> Date {
        DateMath.date(on: day, minute: min(23, max(0, hour)) * 60 + minute)
    }

    private static func make(_ kind: Kind, _ category: SmartCategory, day: Date, suffix: String = "", title: String, body: String,
                             date: Date, basis: String, priority: Int = 3, flexible: Bool = true) -> Candidate {
        let tail = suffix.isEmpty ? "" : "." + suffix
        return Candidate(id: prefix + kind.rawValue + "." + DateMath.dayKey(day) + tail, category: category, kind: kind, title: title,
                         body: body, date: date, basis: basis, priority: priority, flexible: flexible)
    }

    /// Monday of the week of `day` up to `day` (ISO weeks: the same whatever the region's first weekday).
    static func weekDays(through day: Date) -> [Date] {
        let start = DateMath.startOfDay(day)
        let back = FitnessMath.isoWeekday(start) - 1
        return (0...back).reversed().compactMap { DateMath.calendar.date(byAdding: .day, value: -$0, to: start) }
    }

    private static func isSunday(_ day: Date) -> Bool { FitnessMath.isoWeekday(day) == 7 }

    // MARK: Former reminders (SmartReminders)

    /// The workout of the day, the meal nobody noted and the bills enter as candidates: their own
    /// switches (`remindsWorkout`, `remindsMeals`, `remindsBills`) are applied by `SmartReminders.plan`.
    private static func legacy(_ i: Inputs, now: Date, days: Int) -> [Candidate] {
        SmartReminders.plan(fitness: i.fitness, nutrition: i.nutrition, budget: i.budget, settings: i.settings, now: now, days: days).map { reminder in
            let (kind, category) = legacyKind(of: reminder.id)
            return Candidate(id: reminder.id, category: category, kind: kind, title: reminder.title, body: reminder.body,
                             date: reminder.date, basis: reminder.id, priority: 1, flexible: true)
        }
    }

    private static func legacyKind(of id: String) -> (Kind, SmartCategory) {
        if id.hasPrefix(SmartReminders.prefix + "workout.") { return (.legacyWorkout, .fitness) }
        if id.hasPrefix(SmartReminders.prefix + "meals.") { return (.legacyMeals, .nutrition) }
        return (.legacyBill, .general)
    }

    // MARK: Nutrition

    /// The usual minute of the lunch: the median of the first lunch entry of each day, over four weeks.
    /// Nil before three days of lunches (nothing guessed).
    static func usualLunchMinute(_ state: NutritionState, before today: Date) -> Int? {
        let from = DateMath.calendar.date(byAdding: .day, value: -28, to: today) ?? today
        let lunches = state.entries.filter { $0.meal == .lunch && $0.date >= from && $0.date < today }
        let byDay = Dictionary(grouping: lunches) { DateMath.dayKey($0.date) }
        let minutes = byDay.values.compactMap { entries in entries.map { DateMath.minuteOfDay($0.date) }.min() }.sorted()
        guard minutes.count >= 3 else { return nil }
        return minutes[minutes.count / 2]
    }

    private static func nutrition(_ i: Inputs, encouragements: EncouragementLog, now: Date, today: Date) -> [Candidate] {
        var out: [Candidate] = []
        let state = i.nutrition
        let entries = NutritionMath.entries(state, on: now)
        let evening = at(today, hour: i.settings.summaryReminderHour)

        // The lunch not noted, an hour after the person's usual lunch time.
        if !entries.contains(where: { $0.meal == .lunch }), let usual = usualLunchMinute(state, before: today) {
            let minute = min(15 * 60, max(11 * 60 + 30, usual + 60))
            out.append(make(.lunch, .nutrition, day: today, title: tr("Un dîner à noter ?"),
                            body: tr("Ajoute-le en quelques secondes, ton suivi sera plus juste."),
                            date: DateMath.date(on: today, minute: minute), basis: "usual lunch minute \(usual)", priority: 2))
        }

        // Calories and protein: only for a day with food noted, and when the encouragements haven't just said it.
        let encouraged = encouragements.entries.contains { DateMath.isSameDay($0.date, now) && ($0.kind == .meal || $0.kind == .calorieGoal) }
        if !entries.isEmpty, !encouraged {
            let totals = NutritionMath.totals(state, on: now)
            let defaults = NutritionGoals()
            let goals = state.goals
            if goals.kcal > 0, i.profile.knows(.kcalTarget) || goals.kcal != defaults.kcal {
                let left = goals.kcal - totals.kcal
                if abs(left) <= goals.kcal * 0.1 {
                    out.append(make(.calories, .nutrition, day: today, title: tr("Objectif calorique en vue"),
                                    body: tr("\(Fmt.number(Int(safely: totals.kcal.rounded()))) kcal sur \(Fmt.number(Int(safely: goals.kcal.rounded()))) : tu es dans ta cible aujourd'hui."),
                                    date: evening, basis: "kcal \(Int(totals.kcal)) / \(Int(goals.kcal))"))
                } else if left >= 150, left <= 1_500 {
                    let kcal = Fmt.number(Int(safely: (left / 10).rounded() * 10))
                    out.append(make(.calories, .nutrition, day: today, title: tr("Ta journée en calories"),
                                    body: tr("Il te reste \(kcal) kcal pour compléter ta journée."),
                                    date: evening, basis: "kcal left \(Int(left))"))
                }
            }
            if goals.protein > 0, !totals.isIncomplete, i.profile.knows(.proteinTarget) || goals.protein != defaults.protein {
                let left = goals.protein - totals.protein
                if left >= 20 {
                    out.append(make(.protein, .nutrition, day: today, title: tr("Protéines du jour"),
                                    body: tr("Encore \(Fmt.number(Int(safely: left.rounded()))) g de protéines pour atteindre ta cible."),
                                    date: at(today, hour: i.settings.summaryReminderHour - 2), basis: "protein left \(Int(left))", priority: 4))
                }
            }
        }

        // The week, on Sunday: the days followed (at least three).
        if isSunday(now) {
            let monday = weekDays(through: today).first ?? today
            let stats = NutritionMath.stats(state, from: monday, to: today)
            if stats.trackedDays >= 3 {
                let days = Fmt.plural(stats.trackedDays, tr("jour"), tr("jours"))
                let body = stats.daysOnTarget > 0
                    ? tr("\(days) suivis cette semaine, dont \(stats.daysOnTarget) dans ta cible. Belle constance !")
                    : tr("\(days) suivis cette semaine. Belle constance !")
                out.append(make(.nutritionWeek, .nutrition, day: today, title: tr("Bilan nutrition de la semaine"), body: body,
                                date: evening, basis: "tracked \(stats.trackedDays), on target \(stats.daysOnTarget)", priority: 4))
            }
        }

        // Water: only while glasses are noted today (the water mini-app is gone: nothing without that data).
        let hydration = i.content.hydration
        let glasses = hydration.glasses(on: now)
        if glasses > 0, hydration.goal > glasses {
            out.append(make(.hydration, .nutrition, day: today, title: tr("Un verre d'eau ?"),
                            body: tr("\(Fmt.plural(glasses, tr("verre"), tr("verres"))) sur \(hydration.goal) aujourd'hui."),
                            date: at(today, hour: 15), basis: "glasses \(glasses) / \(hydration.goal)", priority: 4))
        }
        return out
    }

    // MARK: Habits

    /// The habits planned on a day and not done.
    static func habitsLeft(_ i: Inputs, on day: Date) -> [Habit] {
        i.content.habits.filter { i.isPlanned($0, on: day) && !$0.isDone(on: day) }
    }

    /// The days done out of the days planned this week, from each habit's first day done. A day not
    /// planned counts neither way; nothing before the habit began.
    static func weekRegularity(_ i: Inputs, now: Date) -> (done: Int, total: Int) {
        let days = weekDays(through: now)
        var done = 0
        var total = 0
        for habit in i.content.habits {
            guard let first = habit.completedDays.compactMap(DateMath.date(fromKey:)).min() else { continue }
            for day in days where DateMath.startOfDay(day) >= DateMath.startOfDay(first) && i.isPlanned(habit, on: day) {
                total += 1
                if habit.isDone(on: day) { done += 1 }
            }
        }
        return (done, total)
    }

    /// The longest streak of a habit without the run that ends today.
    private static func bestStreak(before habit: Habit, run: Int, now: Date) -> Int {
        var copy = habit
        let keys = Set((0..<run).compactMap { DateMath.calendar.date(byAdding: .day, value: -$0, to: now) }.map(DateMath.dayKey))
        copy.completedDays.removeAll { keys.contains($0) }
        return copy.bestStreak
    }

    private static func habits(_ i: Inputs, now: Date, today: Date) -> [Candidate] {
        let list = i.content.habits
        guard !list.isEmpty else { return [] }
        var out: [Candidate] = []
        let evening = at(today, hour: i.settings.summaryReminderHour)
        // Someone who uses their habits (one day done in two weeks), not a list just created.
        let isActive = list.contains { ($0.regularity(days: 14, asOf: now)?.done ?? 0) > 0 }

        let left = habitsLeft(i, on: now)
        if isActive, !left.isEmpty {
            out.append(make(.habitsLeft, .habits, day: today, title: tr("Tes habitudes du jour"),
                            body: tr("Il te reste \(Fmt.plural(left.count, tr("habitude"), tr("habitudes"))) aujourd'hui. Un petit effort et ta journée est complète !"),
                            date: evening, basis: "habits left \(left.count)"))
        }

        // A streak to keep, from 3 days (the longest one).
        if let best = left.max(by: { $0.streak(asOf: now) < $1.streak(asOf: now) }), best.streak(asOf: now) >= 3 {
            let streak = best.streak(asOf: now)
            out.append(make(.habitStreak, .habits, day: today, suffix: best.id.uuidString,
                            title: tr("Ta série continue"),
                            body: tr("\(Fmt.plural(streak, tr("jour"), tr("jours"))) d'affilée pour « \(best.name) ». Garde le rythme ce soir !"),
                            date: evening, basis: "streak \(streak)", priority: 4))
        }

        // A record beaten today (a round milestone is already cheered by the encouragements).
        for habit in list where habit.isDone(on: now) && i.isPlanned(habit, on: now) {
            let streak = habit.streak(asOf: now)
            guard streak >= 3, !Encouragements.streakMilestones.contains(streak) else { continue }
            let before = bestStreak(before: habit, run: streak, now: now)
            guard before >= 2, streak > before else { continue }
            out.append(make(.habitRecord, .habits, day: today, suffix: habit.id.uuidString, title: tr("Nouveau record"),
                            body: tr("\(Fmt.plural(streak, tr("jour"), tr("jours"))) d'affilée pour « \(habit.name) » : ton meilleur résultat. Bravo !"),
                            date: evening, basis: "streak \(streak) > best \(before)", priority: 4))
        }

        // The week, on Sunday.
        if isSunday(now) {
            let week = weekRegularity(i, now: now)
            if week.total >= 3, week.done > 0 {
                let ratio = Double(week.done) / Double(week.total)
                out.append(make(.habitsWeek, .habits, day: today, title: tr("Ta semaine d'habitudes"),
                                body: tr("Tu as tenu \(Fmt.percent(ratio)) de tes habitudes prévues cette semaine. Bravo, et belle semaine à venir !"),
                                date: evening, basis: "regularity \(week.done)/\(week.total)"))
            }
        }
        return out
    }

    // MARK: Fitness

    /// A session done that day, or under way (when the day is `now`'s).
    static func hasTrained(_ f: FitnessState, on day: Date, now: Date) -> Bool {
        FitnessMath.sessions(f).contains { DateMath.isSameDay($0.start, day) }
            || (DateMath.isSameDay(day, now) && f.active.map { !$0.isFinished } == true)
    }

    /// A day with no workout planned while the program plans some on other days: rest, no fitness reminder.
    static func isRestDay(_ f: FitnessState, _ day: Date) -> Bool {
        !f.routines.isEmpty && !f.isScheduled(day)
    }

    /// The days with a session this week (Monday to `day`).
    static func workoutDays(through day: Date, _ f: FitnessState) -> Int {
        let week = Set(weekDays(through: day).map(DateMath.dayKey))
        let trained = Set(FitnessMath.sessions(f).map { DateMath.dayKey($0.start) })
        return week.intersection(trained).count
    }

    private static func fitness(_ i: Inputs, now: Date, today: Date, coming: [Date]) -> [Candidate] {
        let f = i.fitness
        let settings = i.settings
        var out: [Candidate] = []
        let evening = at(today, hour: settings.summaryReminderHour)
        let rest = isRestDay(f, now)
        let trained = hasTrained(f, on: now, now: now)

        // Today is a training day and the week's goal is not reached: how many are left.
        if !rest, !trained, f.isScheduled(now), f.weeklyGoal > 0 {
            let left = f.weeklyGoal - workoutDays(through: now, f)
            if left >= 1 {
                out.append(make(.sessionsLeft, .fitness, day: today, title: tr("Ta semaine sportive"),
                                body: tr("Encore \(Fmt.plural(left, tr("séance"), tr("séances"))) pour atteindre ton objectif de la semaine."),
                                date: at(today, hour: 12), basis: "goal \(f.weeklyGoal), left \(left)"))
            }
        }

        // Steps: only when the motion access is allowed and the iPhone gives them, and not on a rest day.
        if !rest, let steps = i.steps, steps.goal > 0, steps.today < steps.goal {
            out.append(make(.steps, .fitness, day: today, title: tr("Un petit tour ?"),
                            body: tr("Quelques pas de plus et ton objectif de la journée est atteint."),
                            date: at(today, hour: 17), basis: "steps \(steps.today) / \(steps.goal)", priority: 4))
        }

        // The next session, the evening before.
        for day in coming {
            guard let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: day),
                  let routine = f.routines.first(where: { $0.weekdays.contains(FitnessMath.isoWeekday(tomorrow)) }) else { continue }
            out.append(make(.nextSession, .fitness, day: day, title: tr("Séance demain"),
                            body: tr("« \(routine.name) » est prévue demain."),
                            date: at(day, hour: settings.summaryReminderHour), basis: "routine \(routine.name) on \(DateMath.dayKey(tomorrow))"))
        }

        // The week, on Sunday.
        if isSunday(now) {
            let done = workoutDays(through: now, f)
            if done >= 1 {
                let count = Fmt.plural(done, tr("séance"), tr("séances"))
                let body = f.weeklyGoal > 0
                    ? tr("\(count) cette semaine sur \(f.weeklyGoal) prévues. Beau travail !")
                    : tr("\(count) cette semaine. Beau travail !")
                out.append(make(.fitnessWeek, .fitness, day: today, title: tr("Bilan sportif de la semaine"), body: body,
                                date: evening, basis: "workouts \(done) / \(f.weeklyGoal)", priority: 4))
            }
        }
        return out
    }

    // MARK: Planning

    private static func name(of slot: ClassSlot, _ student: StudentState) -> String {
        let title = slot.title.trimmed
        if !title.isEmpty { return title }
        return student.courses.first { $0.id == slot.courseID }?.name ?? slot.kind.title
    }

    private static func planning(_ i: Inputs, now: Date, today: Date, coming: [Date]) -> [Candidate] {
        let student = i.student
        let settings = i.settings
        var out: [Candidate] = []
        let calendar = DateMath.calendar

        // A class in 30 minutes, over every planned day. A class cancelled or deleted gives nothing.
        for day in coming {
            for occurrence in StudentMath.occurrences(student, on: day) where occurrence.slot.kind == .course && occurrence.end > occurrence.start {
                // 30 minutes before falls in the silence but the class itself starts after it: the reminder
                // is moved to the first minute outside the silence (never sent during it), if still before the class.
                var date = occurrence.start.addingTimeInterval(-30 * 60)
                if isQuiet(date, settings: settings), !isQuiet(occurrence.start, settings: settings) {
                    var edge = calendar.dateInterval(of: .hour, for: date)?.end ?? date
                    for _ in 0..<24 where isQuiet(edge, settings: settings) { edge = edge.addingTimeInterval(3_600) }
                    guard edge < occurrence.start else { continue }
                    date = edge
                }
                let time = Fmt.time(occurrence.start, uses24Hour: settings.uses24HourClock)
                let title = name(of: occurrence.slot, student)
                let room = occurrence.slot.room.trimmed
                let body = room.isEmpty
                    ? tr("\(title) commence à \(time).")
                    : tr("\(title) commence à \(time), salle \(room).")
                out.append(make(.classSoon, .planning, day: day, suffix: occurrence.base.id.uuidString,
                                title: tr("Cours dans 30 minutes"), body: body,
                                date: date, basis: "class \(title) at \(time)",
                                priority: 0, flexible: false))
            }
        }

        // The evening before: tomorrow's appointments and exams, and a full day.
        for day in coming {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            let evening = at(day, hour: settings.summaryReminderHour)
            let events = StudentMath.occurrences(student, on: tomorrow).filter { $0.end > $0.start }
            let appointments = events.filter { $0.slot.kind == .appointment || $0.slot.kind == .other }
            if let first = appointments.first {
                let time = Fmt.time(first.start, uses24Hour: settings.uses24HourClock)
                let title = name(of: first.slot, student)
                let body = appointments.count == 1
                    ? tr("\(title) à \(time).")
                    : tr("Tu as \(appointments.count) rendez-vous demain, le premier à \(time).")
                out.append(make(.eventTomorrow, .planning, day: day, suffix: "agenda", title: tr("Rendez-vous demain"), body: body,
                                date: evening, basis: "\(appointments.count) appointments on \(DateMath.dayKey(tomorrow))", priority: 2))
            }
            for exam in student.exams where DateMath.isSameDay(exam.date, tomorrow) {
                out.append(make(.eventTomorrow, .planning, day: day, suffix: exam.id.uuidString, title: tr("Examen demain"),
                                body: tr("« \(exam.title) » est prévu demain. Bonne préparation !"),
                                date: evening, basis: "exam \(exam.title)", priority: 2))
            }
            if events.count >= 4, let first = events.first {
                let time = Fmt.time(first.start, uses24Hour: settings.uses24HourClock)
                out.append(make(.busyTomorrow, .planning, day: day, title: tr("Demain, une journée bien remplie"),
                                body: tr("\(events.count) activités au programme, la première à \(time). Pense à bien te reposer ce soir."),
                                date: evening, basis: "\(events.count) events on \(DateMath.dayKey(tomorrow))", priority: 4))
            }
        }

        // Important tasks due today and not done.
        let tasks = i.content.tasks.filter { !$0.isDone && $0.priority == .high && $0.isDue(on: now) }
        if !tasks.isEmpty {
            out.append(make(.tasksLeft, .planning, day: today, title: tr("Tâches importantes"),
                            body: tr("Il te reste \(Fmt.plural(tasks.count, tr("tâche importante"), tr("tâches importantes"))) pour aujourd'hui."),
                            date: at(today, hour: settings.summaryReminderHour), basis: "high tasks due today \(tasks.count)", priority: 2))
        }
        return out
    }

    // MARK: Goals

    /// Share of the week's goals reached (workouts and study, those that have data), nil without any.
    static func weekGoalsProgress(_ i: Inputs, now: Date) -> Double? {
        var ratios: [Double] = []
        let f = i.fitness
        if f.weeklyGoal > 0, !FitnessMath.sessions(f).isEmpty {
            ratios.append(min(1, Double(workoutDays(through: now, f)) / Double(f.weeklyGoal)))
        }
        let goalMinutes = i.student.weeklyStudyGoalHours * 60
        if goalMinutes > 0, !i.student.sessions.isEmpty {
            ratios.append(min(1, StudentMath.studyMinutes(i.student, weekOf: now) / goalMinutes))
        }
        guard !ratios.isEmpty else { return nil }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    private static func goals(_ i: Inputs, now: Date, today: Date, coming: [Date]) -> [Candidate] {
        var out: [Candidate] = []
        let settings = i.settings
        let evening = at(today, hour: settings.summaryReminderHour)

        if isSunday(now) {
            if let progress = weekGoalsProgress(i, now: now), progress > 0 {
                out.append(make(.goalsWeek, .goals, day: today, title: tr("Tes objectifs de la semaine"),
                                body: tr("Tu as atteint \(Fmt.percent(progress)) de tes objectifs cette semaine. Continue comme ça !"),
                                date: evening, basis: "week goals \(progress)"))
            }
            // The weight goal: the share of the way done, from the smoothed weight (never a single weigh-in).
            if let plan = i.profile.weightPlan, abs(plan.targetKg - plan.startKg) >= 0.5,
               let current = WeightPlanCalculator.smoothedWeight(i.profile.weightLog, now: now) {
                let share = (plan.startKg - current) / (plan.startKg - plan.targetKg)
                if share >= 0.05 {
                    out.append(make(.weightProgress, .goals, day: today, title: tr("Objectif de poids"),
                                    body: tr("Tu as parcouru \(Fmt.percent(min(1, share))) du chemin vers ton objectif. Continue comme ça !"),
                                    date: evening, basis: "weight share \(share)", priority: 4))
                }
            }
        }

        // Monday morning: the week's workout goal, for someone who trains (a program or sessions done).
        let f = i.fitness
        if f.weeklyGoal > 0, !f.routines.isEmpty || !f.history.isEmpty {
            let hour = min(12, max(9, settings.quietEndHour + 1))
            for day in coming where FitnessMath.isoWeekday(day) == 1 {
                out.append(make(.weekStart, .goals, day: day, title: tr("Nouvelle semaine"),
                                body: tr("Cap sur \(Fmt.plural(f.weeklyGoal, tr("séance"), tr("séances"))) cette semaine. Tu as tout pour y arriver !"),
                                date: at(day, hour: hour), basis: "weekly goal \(f.weeklyGoal)"))
            }
        }
        return out
    }
}
