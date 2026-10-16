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

    /// A tap opens the app, as without a delegate.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
