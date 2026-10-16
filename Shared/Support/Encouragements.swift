import Foundation
import UserNotifications

/// « Encouragements »: a word when something done deserves it (a workout finished, a new record, a
/// long study session, a weekly goal reached, a habit kept for a week…) or when the day's meals call
/// for a tip (what's left to eat, too many carbs and not enough protein).
///
/// They must never feel like spam, so every message goes through the same rules (`allows`):
/// - two a day at most, three hours apart at least, never between 22:00 and 8:00 (skipped, not queued);
/// - each kind has its own rhythm: one meal tip a day (from the 2nd meal or after 14:00, and only when
///   the figures say something), a workout every other day at most (a record replaces the plain
///   « séance terminée »), a weekly goal once a week…;
/// - nothing for a cancelled workout (it never reaches the history), nothing when turned off.
///
/// `evaluate` is pure (tested); `consider` reads the log, records what it sends and posts it. The log
/// lives in the App Group's defaults: the app and the Lock Screen intents (run in the app's process)
/// share it, so the same moment never gives two notifications.
enum Encouragements {
    static let prefix = "tessera.encourage."
    static let maxPerDay = 2
    static let minSpacing: TimeInterval = 3 * 3_600
    /// Quiet hours: nothing before 8:00 nor from 22:00.
    static let firstHour = 8
    static let lastHour = 22
    /// A meal tip comes ten minutes later: a meal is noted food by food, and the tip should speak of the
    /// whole meal (each new food replaces the tip still waiting). Done things are cheered right away.
    static let mealDelay: TimeInterval = 10 * 60
    static let eventDelay: TimeInterval = 5

    enum Kind: String, Codable, CaseIterable {
        case meal, calorieGoal, workout, progress, weeklyWorkouts, longStudy, weeklyStudy, habitStreak

        /// Kinds that count as one for their cooldown (a record and a plain workout are both « a workout »).
        var family: String {
            switch self {
            case .workout, .progress: "workout"
            default: rawValue
            }
        }

        /// The least time between two of the same family.
        var cooldown: TimeInterval {
            switch self {
            case .workout, .progress: 44 * 3_600
            case .weeklyWorkouts, .weeklyStudy: 6 * 86_400
            default: 20 * 3_600
            }
        }

        /// Once a day (meal tips, study, habits) or once a week (weekly goals) whatever the hours.
        var oncePerWeek: Bool { self == .weeklyWorkouts || self == .weeklyStudy }
    }

    struct Message: Hashable {
        let kind: Kind
        let title: String
        let body: String
        /// When it shows: a few seconds after the event, or ten minutes after a meal.
        let date: Date

        var id: String { Encouragements.prefix + kind.rawValue + "." + DateMath.dayKey(date) }
    }

    /// What to do after a change: post a message, and/or take back a meal tip still waiting.
    struct Outcome: Hashable {
        var message: Message?
        var cancelled: [String] = []
    }

    // MARK: Rules

    static func isAwake(_ date: Date) -> Bool {
        let hour = DateMath.calendar.component(.hour, from: date)
        return hour >= firstHour && hour < lastHour
    }

    /// Whether a message of this kind may show at `date`, given the ones already sent.
    static func allows(_ kind: Kind, at date: Date, now: Date, log: EncouragementLog) -> Bool {
        guard isAwake(now), isAwake(date) else { return false }
        let sent = log.entries
        if sent.filter({ DateMath.isSameDay($0.date, date) }).count >= maxPerDay { return false }
        if sent.contains(where: { abs($0.date.timeIntervalSince(date)) < minSpacing }) { return false }
        let family = sent.filter { $0.kind?.family == kind.family }
        if family.contains(where: { abs($0.date.timeIntervalSince(date)) < kind.cooldown }) { return false }
        if kind.oncePerWeek {
            if let week = DateMath.calendar.dateInterval(of: .weekOfYear, for: date),
               family.contains(where: { week.contains($0.date) }) { return false }
        } else if family.contains(where: { DateMath.isSameDay($0.date, date) }) {
            return false
        }
        return true
    }

    /// The same message every time on a given day (stable tests), another one the next day.
    private static func variant(_ count: Int, _ now: Date) -> Int {
        DateMath.dayOfYear(now) % max(1, count)
    }

    // MARK: Evaluation

    /// The encouragement a change calls for (nil: nothing to do). Works on any saved state, like
    /// `AppModel.update(_:_:)` does: nutrition, fitness, studies and habits are looked at.
    static func evaluate<T>(from before: T, to after: T, settings: AppSettings, now: Date = Date(),
                            log: EncouragementLog) -> Outcome? {
        guard settings.encourages else { return nil }
        if let old = before as? NutritionState, let new = after as? NutritionState {
            return afterMeal(old: old, new: new, now: now, log: log)
        }
        if let old = before as? FitnessState, let new = after as? FitnessState {
            return afterWorkout(old: old, new: new, now: now, log: log).map { Outcome(message: $0) }
        }
        if let old = before as? StudentState, let new = after as? StudentState {
            return afterStudy(old: old, new: new, now: now, log: log).map { Outcome(message: $0) }
        }
        if let old = before as? ContentState, let new = after as? ContentState {
            return afterHabit(old: old, new: new, now: now, log: log).map { Outcome(message: $0) }
        }
        return nil
    }

    /// The message alone (tests and previews).
    static func message<T>(from before: T, to after: T, settings: AppSettings, now: Date = Date(),
                           log: EncouragementLog) -> Message? {
        evaluate(from: before, to: after, settings: settings, now: now, log: log)?.message
    }

    // MARK: Meals

    /// After a food noted for today: the calorie goal reached, too many carbs for too little protein,
    /// or the calories left. Once a day, from the 2nd meal or after 14:00.
    static func afterMeal(old: NutritionState, new: NutritionState, now: Date, log: EncouragementLog) -> Outcome? {
        let entries = NutritionMath.entries(new, on: now)
        // A food added today (not one removed or edited, not a past day).
        guard entries.count > NutritionMath.entries(old, on: now).count else { return nil }
        // A tip still waiting is reconsidered with the new food: replaced, or taken back.
        let waiting = log.entries.filter { ($0.kind == .meal || $0.kind == .calorieGoal) && $0.date > now }
        var free = log
        free.entries.removeAll { entry in waiting.contains(entry) }
        var outcome = Outcome(message: nil, cancelled: waiting.map(\.id))

        let date = now.addingTimeInterval(mealDelay)
        let goals = new.goals
        let totals = NutritionMath.totals(new, on: now)

        // The goal of the day reached (within 10 %).
        if goals.kcal > 0, abs(totals.kcal - goals.kcal) <= goals.kcal * 0.1,
           allows(.calorieGoal, at: date, now: now, log: free) {
            outcome.message = Message(kind: .calorieGoal, title: tr("Objectif calorique atteint"),
                                      body: tr("\(Fmt.number(Int(safely: totals.kcal.rounded()))) kcal sur \(Fmt.number(Int(safely: goals.kcal.rounded()))) : pile dans ta cible aujourd'hui. Bien joué !"),
                                      date: date)
            return outcome
        }

        let hour = DateMath.calendar.component(.hour, from: now)
        let meals = Set(entries.map(\.meal)).count
        guard meals >= 2 || hour >= 14, allows(.meal, at: date, now: now, log: free) else {
            return outcome.cancelled.isEmpty ? nil : outcome
        }

        // Carbs well ahead of their share of the day while protein lags, with a meal still to come.
        let minute = Double(DateMath.minuteOfDay(date))
        let share = min(1, max(0.3, (minute / 60 - 7) / 14))
        let proteinLeft = goals.protein - totals.protein
        if goals.carbs > 0, goals.protein > 0, MealType.next(after: date) != nil,
           totals.carbs >= goals.carbs * share * 1.2, totals.protein < goals.protein * share * 0.8, proteinLeft >= 20 {
            outcome.message = Message(kind: .meal, title: tr("Petit conseil"),
                                      body: tr("Pas mal de glucides aujourd'hui : mise sur les protéines à ton prochain repas (encore \(Fmt.number(Int(safely: proteinLeft.rounded()))) g)."),
                                      date: date)
            return outcome
        }

        // What's left for the day, when it says something (not almost nothing, not almost everything).
        let left = goals.kcal - totals.kcal
        if goals.kcal > 0, left >= 150, left <= 1_500 {
            let kcal = Fmt.number(Int(safely: (left / 10).rounded() * 10))
            let bodies = [
                tr("Super, il te reste \(kcal) kcal pour compléter ta journée."),
                tr("Bien noté ! Encore \(kcal) kcal et ta journée est complète."),
            ]
            outcome.message = Message(kind: .meal, title: tr("Repas noté"), body: bodies[variant(bodies.count, now)], date: date)
            return outcome
        }
        return outcome.cancelled.isEmpty ? nil : outcome
    }

    // MARK: Workouts

    /// After a session that reached the history (a cancelled one never does): a new record first,
    /// then the weekly goal reached, then a plain « bravo ». One message, never several.
    static func afterWorkout(old: FitnessState, new: FitnessState, now: Date, log: EncouragementLog) -> Message? {
        guard let session = new.history.last, !session.sets.isEmpty,
              !old.history.contains(where: { $0.id == session.id }) else { return nil }
        // Finished now, not an old session put back.
        let end = session.end ?? session.sets.last?.date ?? session.start
        guard now.timeIntervalSince(end) < 3 * 3_600 else { return nil }
        let date = now.addingTimeInterval(eventDelay)

        // Everything done before this session.
        var prior = new
        prior.history.removeAll { $0.id == session.id }
        prior.active = nil

        // A record: the best estimated 1RM of an exercise already done before, beaten.
        let before = Dictionary(FitnessMath.records(prior).map { ($0.exercise, $0) }, uniquingKeysWith: { first, _ in first })
        var best: (record: FitnessMath.Record, gain: Double)?
        for set in session.sets where set.weight > 0 {
            guard let previous = before[set.exercise], previous.oneRepMax > 0 else { continue }
            let record = FitnessMath.Record(exercise: set.exercise, weight: set.weight, reps: set.reps)
            let gain = record.oneRepMax / previous.oneRepMax - 1
            if gain > 0.001, gain > (best?.gain ?? 0) { best = (record, gain) }
        }
        if let record = best?.record, allows(.progress, at: date, now: now, log: log) {
            let weight = TF.decimal(record.weight, record.weight.rounded() == record.weight ? 0 : 1)
            return Message(kind: .progress, title: tr("Belle progression"),
                           body: tr("Nouveau record sur \(record.exercise) : \(weight) kg × \(Fmt.number(record.reps))."), date: date)
        }

        // The weekly goal reached with this session.
        let goal = new.weeklyGoal
        let done = FitnessMath.workouts(inWeekOf: now, new)
        if goal > 0, done >= goal, FitnessMath.workouts(inWeekOf: now, prior) < goal,
           allows(.weeklyWorkouts, at: date, now: now, log: log) {
            return Message(kind: .weeklyWorkouts, title: tr("Objectif de la semaine atteint"),
                           body: tr("\(Fmt.plural(done, tr("séance"), tr("séances"))) cette semaine, comme prévu. Bravo !"), date: date)
        }

        guard allows(.workout, at: date, now: now, log: log) else { return nil }
        let minutes = Int(safely: (end.timeIntervalSince(session.start) / 60).rounded())
        var bodies = [
            tr("Bravo ! Belle régularité, continue comme ça."),
            tr("Une séance de plus au compteur. Ton futur toi te dit merci !"),
        ]
        if minutes >= 5 {
            bodies.append(tr("\(Fmt.plural(session.sets.count, tr("série"), tr("séries"))) en \(Fmt.minutes(Double(minutes))). Bien joué !"))
        }
        return Message(kind: .workout, title: tr("Séance terminée"), body: bodies[variant(bodies.count, now)], date: date)
    }

    // MARK: Studies

    /// After study time logged today: the weekly goal reached, or 1 h 30 of study in the day.
    static func afterStudy(old: StudentState, new: StudentState, now: Date, log: EncouragementLog) -> Message? {
        let day = DateMath.startOfDay(now)
        let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: day) ?? now
        let today = StudentMath.studyMinutes(new, from: day, to: tomorrow)
        let todayBefore = StudentMath.studyMinutes(old, from: day, to: tomorrow)
        guard today > todayBefore else { return nil }
        let date = now.addingTimeInterval(eventDelay)

        let goal = new.weeklyStudyGoalHours * 60
        let week = StudentMath.studyMinutes(new, weekOf: now)
        if goal > 0, week >= goal, StudentMath.studyMinutes(old, weekOf: now) < goal,
           allows(.weeklyStudy, at: date, now: now, log: log) {
            return Message(kind: .weeklyStudy, title: tr("Objectif d'étude atteint"),
                           body: tr("\(Fmt.minutes(week)) d'étude cette semaine : ton objectif est atteint. Bravo !"), date: date)
        }

        if today >= longStudyMinutes, todayBefore < longStudyMinutes, allows(.longStudy, at: date, now: now, log: log) {
            return Message(kind: .longStudy, title: tr("Beau travail"),
                           body: tr("\(Fmt.minutes(Double(today))) d'étude aujourd'hui. Pense à faire une pause."), date: date)
        }
        return nil
    }

    static let longStudyMinutes = 90

    // MARK: Habits

    static let streakMilestones = [7, 21, 30, 50, 100, 200, 365]

    /// A habit checked today that reaches 7, 21, 30… days in a row.
    static func afterHabit(old: ContentState, new: ContentState, now: Date, log: EncouragementLog) -> Message? {
        let date = now.addingTimeInterval(eventDelay)
        for habit in new.habits where habit.isDone(on: now) {
            let streak = habit.streak(asOf: now)
            let was = old.habits.first { $0.id == habit.id }?.streak(asOf: now) ?? 0
            guard let milestone = streakMilestones.last(where: { was < $0 && $0 <= streak }) else { continue }
            guard allows(.habitStreak, at: date, now: now, log: log) else { return nil }
            return Message(kind: .habitStreak, title: tr("Belle série"),
                           body: tr("\(Fmt.plural(milestone, tr("jour"), tr("jours"))) d'affilée pour « \(habit.name) ». Continue comme ça !"),
                           date: date)
        }
        return nil
    }

    // MARK: Delivery

    private static let lock = NSLock()

    /// The entry point after a change saved by the app (`AppModel.update`): decides, records it in the
    /// shared log right away (so a second call can't double it), then posts it.
    static func consider<T>(from before: T, to after: T, settings: AppSettings? = nil, now: Date = Date(),
                            defaults: UserDefaults = EncouragementLog.defaults) {
        guard let outcome = decide(from: before, to: after, settings: settings, now: now, defaults: defaults) else { return }
        Task { await deliver(outcome, defaults: defaults) }
    }

    /// The same from a Lock Screen button (an intent): waits until the notification is posted, so the
    /// intent doesn't end before.
    static func considerAndDeliver<T>(from before: T, to after: T, settings: AppSettings? = nil, now: Date = Date(),
                                      defaults: UserDefaults = EncouragementLog.defaults) async {
        guard let outcome = decide(from: before, to: after, settings: settings, now: now, defaults: defaults) else { return }
        await deliver(outcome, defaults: defaults)
    }

    /// Evaluates the change against the shared log and records the outcome in it, under a lock.
    private static func decide<T>(from before: T, to after: T, settings: AppSettings?, now: Date,
                                  defaults: UserDefaults) -> Outcome? {
        guard before is NutritionState || before is FitnessState || before is StudentState || before is ContentState else { return nil }
        let settings = settings ?? SharedStore.shared.settings
        return lock.withLock {
            var log = EncouragementLog.load(defaults)
            guard let outcome = evaluate(from: before, to: after, settings: settings, now: now, log: log) else { return nil }
            log.entries.removeAll { outcome.cancelled.contains($0.id) }
            if let message = outcome.message { log.record(message, now: now) }
            log.save(defaults)
            return outcome
        }
    }

    /// Posts the message (only once notifications are allowed: nothing is asked here). Without the
    /// permission, the message is struck from the log so it doesn't count among the day's two.
    static func deliver(_ outcome: Outcome, defaults: UserDefaults = EncouragementLog.defaults) async {
        let center = UNUserNotificationCenter.current()
        if !outcome.cancelled.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: outcome.cancelled)
        }
        guard let message = outcome.message else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            lock.withLock {
                var log = EncouragementLog.load(defaults)
                log.entries.removeAll { $0.id == message.id }
                log.save(defaults)
            }
            return
        }
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.threadIdentifier = "tessera.encourage"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, message.date.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: message.id, content: content, trigger: trigger))
    }
}

/// The encouragements sent (or waiting to show), the last two weeks: what the rules count.
struct EncouragementLog: Codable, Hashable {
    struct Entry: Codable, Hashable {
        /// The kind's raw value: an entry of a kind a later version removes is kept, and simply ignored.
        var kindName: String
        var id: String
        /// When it shows (or showed).
        var date: Date

        var kind: Encouragements.Kind? { Encouragements.Kind(rawValue: kindName) }
    }

    var entries: [Entry] = []

    static let key = "tessera.encouragements.log"

    /// The App Group's defaults: shared by the app and the intents.
    static var defaults: UserDefaults { UserDefaults(suiteName: AppGroup.identifier) ?? .standard }

    mutating func record(_ message: Encouragements.Message, now: Date) {
        entries.removeAll { $0.id == message.id }
        entries.append(Entry(kindName: message.kind.rawValue, id: message.id, date: message.date))
        let cutoff = now.addingTimeInterval(-14 * 86_400)
        entries.removeAll { $0.date < cutoff }
    }

    static func load(_ defaults: UserDefaults = EncouragementLog.defaults) -> EncouragementLog {
        guard let data = defaults.data(forKey: key),
              let log = try? JSONDecoder().decode(EncouragementLog.self, from: data) else { return EncouragementLog() }
        return log
    }

    func save(_ defaults: UserDefaults = EncouragementLog.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
