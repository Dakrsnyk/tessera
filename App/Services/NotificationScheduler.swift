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
        content.body = tr("C'est le moment de valider ton habitude du jour.")
        content.sound = .default
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        add([UNNotificationRequest(identifier: habitID(habit.id), content: content, trigger: trigger)])
    }

    // MARK: Global ceiling

    /// iOS keeps 64 pending notifications and silently drops the others.
    static let pendingLimit = NotificationEngine.systemLimit

    /// How many requests can still be added to `pending` waiting ones without passing the ceiling.
    static func room(pending: Int) -> Int { max(0, pendingLimit - pending) }

    /// Adds the requests the ceiling leaves room for (the first ones, so the soonest when sorted).
    private static func add(_ requests: [UNNotificationRequest]) {
        guard !requests.isEmpty else { return }
        Task {
            let pending = await center.pendingNotificationRequests().count
            for request in requests.prefix(room(pending: pending)) {
                try? await center.add(request)
            }
        }
    }

    static func cancelHabitReminder(_ id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [habitID(id)])
    }

    // MARK: Water (removed)

    /// The water reminders of earlier versions: the water mini-app is gone, so are its reminders.
    static func cancelWaterReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [10, 12, 14, 16, 18, 20].map { "tessera.water.\($0)" })
    }

    // MARK: Countdown

    /// The identifier of a countdown's reminder: the widget's own, or one per part of a combined widget.
    static func countdownID(_ id: UUID, part: Int? = nil) -> String {
        let base = "tessera.countdown.\(id.uuidString)"
        return part.map { "\(base).\($0)" } ?? base
    }

    /// A combined widget holds at most eight parts: the identifiers to take back for a design.
    private static func countdownIDs(for id: UUID) -> [String] {
        [countdownID(id)] + (0..<8).map { countdownID(id, part: $0) }
    }

    /// The reminders a design asks for: at 9:00 on the day of each countdown (the widget itself, or each
    /// countdown part of a combined widget), when its option is on and the day is still ahead.
    static func countdownRequests(for design: WidgetDesign, now: Date = Date()) -> [UNNotificationRequest] {
        let isCombo = design.isCombo
        return design.partDesigns.enumerated().compactMap { (index: Int, part: WidgetDesign) -> UNNotificationRequest? in
            guard part.kind == .countdown, part.options.countdownMode == .until, part.options.countdownReminder else { return nil }
            var components = DateMath.calendar.dateComponents([.year, .month, .day], from: part.options.countdownDate)
            components.hour = 9
            guard let fireDate = DateMath.calendar.date(from: components), fireDate > now else { return nil }
            let content = UNMutableNotificationContent()
            content.title = part.options.countdownTitle.trimmed.isEmpty ? tr("C'est le grand jour") : part.options.countdownTitle
            content.body = tr("Le jour J est arrivé.")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: countdownID(design.id, part: isCombo ? index : nil), content: content, trigger: trigger)
        }
    }

    /// The reminders of a design's countdowns, replaced by what its options ask for now.
    static func syncCountdownReminder(for design: WidgetDesign) {
        center.removePendingNotificationRequests(withIdentifiers: countdownIDs(for: design.id))
        add(countdownRequests(for: design))
    }

    static func cancelCountdownReminder(for id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: countdownIDs(for: id))
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
