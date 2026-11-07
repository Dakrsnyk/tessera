import Foundation
import UserNotifications

/// Shows the encouragements as a banner while Ardane is open (a meal is noted, a workout finished in
/// the app): without a delegate, iOS keeps a notification silent when its app is in front. The other
/// notifications (reminders, habits, countdowns) keep their behaviour: nothing while the app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    /// Set as early as possible (the app's init): the center keeps only a weak reference.
    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier.hasPrefix(Encouragements.prefix) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([])
        }
    }

    /// A tap opens the app on the screen the notification is about (a mini-app, a countdown's widget…):
    /// the link goes through `AppOpenRequests`, which the app reads (also at launch) and hands to `Router.handle`.
    /// A notification with no screen of its own just opens the app, as without a delegate.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let link = NotificationRoute.link(for: response.notification.request.identifier) {
            Task { @MainActor in AppOpenRequests.shared.pending = link }
        }
        completionHandler()
    }
}
