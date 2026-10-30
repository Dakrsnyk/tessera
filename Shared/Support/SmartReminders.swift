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
        let planned = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: planned)
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            NotificationEngine.forgetPending(now: now, defaults: defaults)
            return
        }
        let plan = NotificationEngine.commit(inputs, now: now, defaults: defaults)
        for candidate in plan {
            let content = UNMutableNotificationContent()
            content.title = candidate.title
            content.body = candidate.body
            content.sound = .default
            content.threadIdentifier = prefix + candidate.category.rawValue
            let parts = DateMath.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: candidate.id, content: content, trigger: trigger))
        }
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
