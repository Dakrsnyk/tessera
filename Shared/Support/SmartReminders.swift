import Foundation
import UserNotifications

/// « Rappels intelligents »: the workout planned today and not started at its hour, a day without any
/// meal noted in the evening, a bill due tomorrow. They are planned a week ahead and planned again each
/// time the data changes (in the app, or from a widget button), so a reminder never comes for what is
/// already done. Nothing is asked here: they come once notifications are allowed (Profil › Rappels).
/// Since the « notifications intelligentes », these three are candidates of `NotificationEngine`, which
/// adds the other categories and applies the same rules (switches, quiet hours, ceiling, no repeat).
enum SmartReminders {
    static let prefix = "tessera.smart."

    struct Reminder: Hashable {
        let id: String
        let title: String
        let body: String
        let date: Date
    }

    /// The reminders the data calls for, from `now` over the next `days` days, the soonest first.
    static func plan(fitness: FitnessState, nutrition: NutritionState, budget: BudgetState, settings: AppSettings,
                     now: Date = Date(), days: Int = 7) -> [Reminder] {
        let calendar = DateMath.calendar
        let today = DateMath.startOfDay(now)
        let coming = (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        func at(_ day: Date, hour: Int) -> Date? {
            calendar.date(bySettingHour: min(23, max(0, hour)), minute: 0, second: 0, of: day)
        }
        var result: [Reminder] = []

        // The workout of the day: only on a day the program plans one, and not once it has begun.
        if settings.remindsWorkout {
            for day in coming {
                guard let routine = fitness.routines.first(where: { $0.weekdays.contains(FitnessMath.isoWeekday(day)) }),
                      let date = at(day, hour: settings.workoutReminderHour), date > now else { continue }
                if DateMath.isSameDay(day, now) {
                    let begun = FitnessMath.sessions(fitness).contains { DateMath.isSameDay($0.start, now) }
                        || fitness.active.map { !$0.isFinished } == true
                    if begun { continue }
                }
                result.append(Reminder(id: prefix + "workout." + DateMath.dayKey(day), title: tr("Ta séance t'attend"),
                                       body: tr("« \(routine.name) » est prévue aujourd'hui."), date: date))
            }
        }

        // Meals: only for someone who notes them (this past week), and not once a meal is noted that day.
        if settings.remindsMeals {
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            if nutrition.entries.contains(where: { $0.date >= weekAgo }) {
                for day in coming {
                    guard let date = at(day, hour: settings.mealReminderHour), date > now else { continue }
                    if DateMath.isSameDay(day, now), !NutritionMath.entries(nutrition, on: now).isEmpty { continue }
                    result.append(Reminder(id: prefix + "meals." + DateMath.dayKey(day), title: tr("Rien de noté aujourd'hui"),
                                           body: tr("Ajoute tes repas en quelques secondes pour garder ton suivi juste."), date: date))
                }
            }
        }

        // Bills: at 9:00 the day before each one due over the period.
        if settings.remindsBills, let horizon = calendar.date(byAdding: .day, value: days, to: today) {
            for bill in budget.bills {
                var due = bill.nextDue(after: now)
                var count = 0
                while due <= horizon, count < 3 {
                    if let eve = calendar.date(byAdding: .day, value: -1, to: due), let date = at(eve, hour: 9), date > now {
                        result.append(Reminder(id: prefix + "bill." + bill.id.uuidString + "." + DateMath.dayKey(due),
                                               title: tr("\(bill.name) demain"),
                                               body: tr("\(TF.money(bill.amount, settings.currencyCode, decimals: 2)) à payer demain."), date: date))
                    }
                    guard let next = calendar.date(byAdding: .day, value: 1, to: due) else { break }
                    due = bill.nextDue(after: next)
                    count += 1
                }
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Replaces every planned notification of the engine (these reminders and the other smart ones, all
    /// under `prefix`) by the ones today's data calls for: the obsolete ones are taken back, and none is
    /// planned without permission. Nothing is asked here.
    static func sync(_ inputs: NotificationEngine.Inputs, now: Date = Date(),
                     defaults: UserDefaults = NotificationLog.defaults) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let planned = pending.filter { $0.hasPrefix(prefix) }
        // What waits outside this plan (habits, countdowns, encouragements, Focus) takes room under iOS's 64.
        let outside = pending.count - planned.count
        center.removePendingNotificationRequests(withIdentifiers: planned)
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            NotificationEngine.forgetPending(now: now, defaults: defaults)
            return
        }
        let plan = NotificationEngine.commit(inputs, now: now, defaults: defaults, pendingOutside: outside)
        var refused = Set<String>()
        for candidate in plan {
            let content = UNMutableNotificationContent()
            content.title = candidate.title
            content.body = candidate.body
            content.sound = .default
            content.threadIdentifier = prefix + candidate.category.rawValue
            let parts = DateMath.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: candidate.id, content: content, trigger: trigger))
            } catch {
                refused.insert(candidate.id)
            }
        }
        NotificationEngine.forget(ids: refused, defaults: defaults)
        // Hardening: a concurrent sync (another process) may have left requests outside this plan.
        let keep = Set(plan.map(\.id))
        let stray = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) && !keep.contains($0) }
        if !stray.isEmpty { center.removePendingNotificationRequests(withIdentifiers: stray) }
    }

    /// After a widget button (a meal noted, a set done, a bill paid): the same, from the shared data.
    /// The steps are not read here (the motion sensor belongs to the app): no steps reminder is kept.
    static func refresh() async {
        let store = SharedStore.shared
        var inputs = NotificationEngine.Inputs()
        inputs.settings = store.settings
        inputs.fitness = store.state(FitnessState.self)
        inputs.nutrition = store.state(NutritionState.self)
        inputs.budget = store.state(BudgetState.self)
        inputs.content = store.content
        inputs.student = store.state(StudentState.self)
        inputs.profile = store.state(UserProfile.self)
        await sync(inputs)
    }
}

/// Where a tap on a notification leads, from its identifier (the ones of the scheduler, the smart
/// reminders and the encouragements): an existing deep link, opened with `Router.handle`.
enum NotificationRoute {
    static func link(for identifier: String) -> DeepLink? {
        // A countdown: its widget (one identifier per part of a combined widget: « …<uuid>.<part> »).
        let countdown = "tessera.countdown."
        if identifier.hasPrefix(countdown) {
            let rest = identifier.dropFirst(countdown.count)
            return UUID(uuidString: String(rest.prefix(36))).map { DeepLink.design($0) }
        }
        if identifier.hasPrefix("tessera.habit.") { return .space(Space.habits.rawValue) }
        if identifier.hasPrefix(Encouragements.prefix) {
            let rest = identifier.dropFirst(Encouragements.prefix.count)
            let kind = rest.split(separator: ".").first.map(String.init) ?? ""
            switch Encouragements.Kind(rawValue: kind) {
            case .meal, .calorieGoal: return .space(Space.nutrition.rawValue)
            case .workout, .weeklyWorkouts: return .space(Space.fitness.rawValue)
            case .longStudy, .weeklyStudy: return .space(Space.student.rawValue)
            case .habitStreak: return .space(Space.habits.rawValue)
            default: return nil
            }
        }
        if identifier.hasPrefix(SmartReminders.prefix + "bill.") { return .space(Space.budget.rawValue) }
        if identifier.hasPrefix(SmartReminders.prefix + "workout.") { return .space(Space.fitness.rawValue) }
        if identifier.hasPrefix(SmartReminders.prefix + "meals.") { return .space(Space.nutrition.rawValue) }
        if identifier.hasPrefix(NotificationEngine.prefix) {
            // « tessera.smart.n.<kind>.<day>… »
            let rest = identifier.dropFirst(NotificationEngine.prefix.count)
            let kind = rest.split(separator: ".").first.map(String.init) ?? ""
            guard let kindValue = NotificationEngine.Kind(rawValue: kind) else { return nil }
            switch kindValue {
            case .lunch, .calories, .protein, .nutritionWeek, .hydration, .legacyMeals:
                return .space(Space.nutrition.rawValue)
            case .habitsLeft, .habitStreak, .habitRecord, .habitsWeek:
                return .space(Space.habits.rawValue)
            case .sessionsLeft, .steps, .nextSession, .fitnessWeek, .legacyWorkout, .weightProgress, .goalsWeek, .weekStart:
                return .space(Space.fitness.rawValue)
            case .classSoon, .eventTomorrow, .busyTomorrow:
                return .space(Space.student.rawValue)
            case .tasksLeft:
                return .tasks
            case .legacyBill:
                return .space(Space.budget.rawValue)
            }
        }
        return nil
    }
}
