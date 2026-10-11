import Foundation

/// When to ask for a rating: right after a good moment (a workout finished, the calorie goal of the
/// day reached, a savings goal reached, a widget made), never at the opening of the app; once the app
/// has been opened on a few different occasions, and once per major version.
/// Apple decides whether the request is shown (at most three times a year) and never says whether
/// the user rated, so Ardane only remembers that it asked.
enum ReviewPrompt {
    static let opensBeforeAsking = 5
    /// Coming back to the app within this time is the same opening.
    static let minimumGap: TimeInterval = 4 * 3600

    /// Counts an opening, unless the previous one was too recent.
    static func countOpen(_ settings: inout AppSettings, at date: Date = Date()) {
        if let last = settings.lastCountedOpen, date.timeIntervalSince(last) < minimumGap { return }
        settings.openCount += 1
        settings.lastCountedOpen = date
    }

    static func shouldAsk(_ settings: AppSettings, version: String = currentMajorVersion) -> Bool {
        settings.openCount >= opensBeforeAsking && settings.reviewRequestedVersion != version
    }

    static func markAsked(_ settings: inout AppSettings, version: String = currentMajorVersion) {
        settings.reviewRequestedVersion = version
    }

    /// "1" for 1.4.2.
    static var currentMajorVersion: String {
        let full = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"
        return full.split(separator: ".").first.map(String.init) ?? full
    }
}
