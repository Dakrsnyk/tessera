import Foundation
import UserNotifications

/// Optional local reminders. Permission is requested only when the user turns one on.
enum NotificationScheduler {
    private static var center: UNUserNotificationCenter { .current() }

    static func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    // MARK: Habits

    private static func habitID(_ id: UUID) -> String { "tessera.habit.\(id.uuidString)" }

    static func syncHabitReminder(_ habit: Habit) {
        center.removePendingNotificationRequests(withIdentifiers: [habitID(habit.id)])
        guard let hour = habit.reminderHour, let minute = habit.reminderMinute else { return }
        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = "C'est le moment de valider ton habitude du jour."
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: habitID(habit.id), content: content, trigger: trigger))
    }

    static func cancelHabitReminder(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [habitID(id)])
    }

    // MARK: Hydration

    private static let hydrationHours = [10, 12, 14, 16, 18, 20]

    static func setHydrationReminders(_ enabled: Bool) {
        let ids = hydrationHours.map { "tessera.water.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled else { return }
        for hour in hydrationHours {
            let content = UNMutableNotificationContent()
            content.title = "Un verre d'eau ?"
            content.body = "Ajoute-le d'une touche depuis ton widget."
            content.sound = .default
            var components = DateComponents()
            components.hour = hour
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: "tessera.water.\(hour)", content: content, trigger: trigger))
        }
    }

    // MARK: Countdown

    private static func countdownID(_ id: UUID) -> String { "tessera.countdown.\(id.uuidString)" }

    /// A reminder at 9:00 on the day of a countdown, when the design asks for it.
    static func syncCountdownReminder(for design: WidgetDesign) {
        center.removePendingNotificationRequests(withIdentifiers: [countdownID(design.id)])
        guard design.kind == .countdown, design.options.countdownMode == .until, design.options.countdownReminder else { return }
        var components = DateMath.calendar.dateComponents([.year, .month, .day], from: design.options.countdownDate)
        components.hour = 9
        guard let fireDate = DateMath.calendar.date(from: components), fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = design.options.countdownTitle.trimmed.isEmpty ? "C'est le grand jour" : design.options.countdownTitle
        content.body = "Le jour J est arrivé."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: countdownID(design.id), content: content, trigger: trigger))
    }

    static func cancelCountdownReminder(for id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [countdownID(id)])
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
