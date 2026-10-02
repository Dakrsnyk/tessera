import AppIntents
import Foundation
import UserNotifications
import WidgetKit

/// Actions triggered by buttons inside widgets (iOS 17 interactive widgets).
/// They run in the widget extension and write straight to the shared store.

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Cocher une tâche"
    static var isDiscoverable = false

    @Parameter(title: "Tâche")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: taskID) {
            SharedStore.shared.updateContent { $0.toggleTask(id) }
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Valider une habitude"
    static var isDiscoverable = false

    @Parameter(title: "Habitude")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: habitID) {
            SharedStore.shared.updateContent { $0.toggleHabit(id) }
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Ajouter un verre d'eau"
    static var isDiscoverable = false

    @Parameter(title: "Verres")
    var glasses: Int

    init() {
        glasses = 1
    }

    init(glasses: Int) {
        self.glasses = glasses
    }

    func perform() async throws -> some IntentResult {
        SharedStore.shared.updateContent { $0.hydration.add(glasses, on: Date()) }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Lancer une session Focus"
    static var isDiscoverable = false

    @Parameter(title: "Minutes")
    var minutes: Int

    init() {
        minutes = 25
    }

    init(minutes: Int) {
        self.minutes = minutes
    }

    func perform() async throws -> some IntentResult {
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(minutes) * 60)
        SharedStore.shared.updateContent {
            $0.focus = FocusSession(startDate: now, endDate: end, lastDurationMinutes: minutes)
        }
        let planned = minutes
        SharedStore.shared.update(ProductivityState.self) { $0.logFocusStart(at: now, minutes: planned) }
        await FocusNotifier.schedule(end: end, minutes: minutes)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct StopFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Arrêter la session Focus"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        SharedStore.shared.updateContent {
            $0.focus.startDate = nil
            $0.focus.endDate = nil
        }
        SharedStore.shared.update(ProductivityState.self) { $0.logFocusStop(at: Date()) }
        FocusNotifier.cancel()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Notifies the end of a Focus session, if the user allowed notifications in the app.
enum FocusNotifier {
    static let identifier = "tessera.focus.end"

    static func schedule(end: Date, minutes: Int) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = tr("Session terminée")
        content.body = tr("\(minutes) minutes de concentration. Prends une pause.")
        content.sound = .default
        let interval = max(1, end.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
