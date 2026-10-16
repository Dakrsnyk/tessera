import AppIntents
import Foundation
import os
import WidgetKit

// Buttons of the study timer's Live Activity (Lock Screen, Dynamic Island).

extension Notification.Name {
    /// The study timer was changed outside the app's screens (Lock Screen, Dynamic Island): the app
    /// reads the studies back, so the timer has a single state everywhere.
    static let studySavedOutside = Notification.Name("tessera.studySavedOutside")
}

/// Saves a timer change made outside the app, then updates the widgets, the app (when it is
/// running) and the Live Activity.
private func changeStudy(_ change: (inout StudentState) -> Void) async {
    let before = SharedStore.shared.state(StudentState.self)
    guard SharedStore.shared.update(StudentState.self, change) else {
        Logger(subsystem: "com.dakrsnyk.tessera.widgets", category: "intents").error("study button: the studies file can't be read right now")
        return
    }
    WidgetCenter.shared.reloadAllTimelines()
    await MainActor.run { NotificationCenter.default.post(name: .studySavedOutside, object: nil) }
    await StudyLiveActivity.sync(SharedStore.shared.state(StudentState.self))
    await Encouragements.considerAndDeliver(from: before, to: SharedStore.shared.state(StudentState.self))
}

/// Stops the timer and adds the time studied to the week, like « Terminer et noter » in the app.
struct StopStudyIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Terminer le temps d'étude"
    static var isDiscoverable = false
    /// Runs from the Lock Screen without unlocking, and never opens the app.
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    static var openAppWhenRun: Bool { false }

    init() {}

    func perform() async throws -> some IntentResult {
        await changeStudy { _ = $0.stopTimer(at: Date()) }
        return .result()
    }
}

/// Clears a timer started by mistake: nothing is logged.
struct CancelStudyIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Annuler le temps d'étude"
    static var isDiscoverable = false
    /// Runs from the Lock Screen without unlocking, and never opens the app.
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    static var openAppWhenRun: Bool { false }

    init() {}

    func perform() async throws -> some IntentResult {
        await changeStudy {
            $0.timerStart = nil
            $0.timerCourseID = nil
        }
        return .result()
    }
}
