import Foundation

/// When to ask for a rating: right after a good moment (a workout finished, the calorie goal of the
/// day reached, a savings goal reached, a widget made), never at the opening of the app.
///
/// Apple's rules: the system window shows at most 3 times per 365 days per app, may not show at all,
/// `requestReview` guarantees nothing, and the API never says whether the person rated or dismissed.
/// So Ardane counts its own ATTEMPTS (never "refusals"), waits for real use and for a real positive
/// experience, spaces the attempts more and more, and lets the person opt out. No fake window, no
/// rating asked in advance, no reward tied to a review.
///
/// Chosen values (and why):
/// - First attempt only after 5 openings on 3 different days and 5 days since the first use: the app
///   has been lived with, not just tried. Never in the first uses.
/// - A positive experience is needed each time (a habit streak of 5 days or more, 3 workouts with the
///   last one this week, 3 days of food tracking this week, or 3 good moments since the last attempt).
///   For the 2nd and 3rd attempts at least one NEW good moment since the previous one.
/// - 2nd attempt at least 30 days after the 1st, 3rd (and last of the series) at least 90 days after
///   the 2nd: a person who did not rate once is not pressed again within weeks.
/// - At most 3 attempts in any 365 days, as Apple does: a 4th can only come when the oldest attempt
///   is more than a year old.
/// - "Do not ask me again" (`optOut`) stops everything for good.
/// The legacy per-version functions (`shouldAsk`/`markAsked`) stay for the manual "Noter" button and
/// for the migration: someone already asked for this version is not asked again at once.
enum ReviewPrompt {
    static let opensBeforeAsking = 5
    static let distinctDaysBeforeAsking = 3
    static let daysSinceFirstUseBeforeAsking = 5
    static let firstGap: TimeInterval = 30 * 86_400
    static let laterGap: TimeInterval = 90 * 86_400
    static let maxAttemptsPerYear = 3
    static let yearLength: TimeInterval = 365 * 86_400
    /// A streak, workouts and meals tracked: the thresholds of a "positive experience".
    static let streakDays = 5
    static let workoutsNeeded = 3
    static let nutritionDaysNeeded = 3
    static let goodMomentsNeeded = 3
    /// Coming back to the app within this time is the same opening.
    static let minimumGap: TimeInterval = 4 * 3600

    // MARK: Legacy (per major version)

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

    // MARK: Positive experiences

    enum Positive: String, Codable, CaseIterable {
        case habitStreak, workouts, nutritionTracking, goodMoments
    }

    /// Why a request must wait (nil from `blocker`: it may go).
    enum Blocker: Equatable {
        case optedOut, notEnoughUse, tooSoon, yearlyLimit, noPositiveExperience
    }

    /// A positive experience read from the real data, nil when there is none.
    /// - Habits: a streak of 5 days or more (today or yesterday included).
    /// - Fitness: 3 workouts recorded, the last one within the week.
    /// - Nutrition: food noted on 3 different days of the last 7.
    static func positiveExperience(content: ContentState, fitness: FitnessState, nutrition: NutritionState,
                                   now: Date = Date()) -> Positive? {
        if content.habits.contains(where: { $0.streak(asOf: now) >= streakDays }) { return .habitStreak }

        let workouts = fitness.history.compactMap { session -> Date? in
            guard !session.sets.isEmpty else { return nil }
            return session.end ?? session.sets.last?.date ?? session.start
        }
        if workouts.count >= workoutsNeeded, let last = workouts.max(), now.timeIntervalSince(last) <= 7 * 86_400 {
            return .workouts
        }

        let weekStart = now.addingTimeInterval(-7 * 86_400)
        let days = Set(nutrition.entries.filter { $0.date >= weekStart && $0.date <= now }.map { DateMath.dayKey($0.date) })
        if days.count >= nutritionDaysNeeded { return .nutritionTracking }
        return nil
    }

    /// Reads the saved states (the app and the widget share them) and gives the positive experience.
    static func positiveExperience(store: SharedStore = .shared, now: Date = Date()) -> Positive? {
        positiveExperience(content: store.content, fitness: store.state(FitnessState.self),
                           nutrition: store.state(NutritionState.self), now: now)
    }

    // MARK: Decision

    /// What stops a request now (nil: it may go). `positive` is the experience read from the data.
    static func blocker(_ log: ReviewLog, positive: Positive?, now: Date = Date()) -> Blocker? {
        if log.optedOut { return .optedOut }
        let attempts = log.attemptsInLastYear(now: now)
        if attempts >= maxAttemptsPerYear { return .yearlyLimit }
        guard log.hasEnoughUse(now: now) else { return .notEnoughUse }
        if let next = log.nextAllowedDate, now < next { return .tooSoon }
        // A positive experience, real: from the data, or good moments piling up since the last attempt.
        let piledUp = log.goodMomentsSinceAsk >= goodMomentsNeeded
        guard positive != nil || piledUp else { return .noPositiveExperience }
        // After a first attempt: something NEW since then, not the same old streak.
        if log.askCount > 0 && log.goodMomentsSinceAsk < 1 { return .noPositiveExperience }
        return nil
    }

    /// Records the attempt BEFORE the system call (state saved first, one call per calm moment) and
    /// schedules the next permitted date. Call only when `blocker` is nil.
    static func recordAttempt(_ log: inout ReviewLog, positive: Positive?, now: Date = Date()) {
        let kind = positive ?? .goodMoments
        log.lastPositiveKind = kind.rawValue
        log.lastPositiveDate = now
        log.askDates.append(now)
        log.askDates = Array(log.askDates.suffix(10))
        log.askCount += 1
        log.lastAskedDate = now
        log.goodMomentsSinceAsk = 0
        log.nextAllowedDate = now.addingTimeInterval(log.askCount <= 1 ? firstGap : laterGap)
    }

    /// "Do not ask me again": nothing is asked any more.
    static func optOut(_ log: inout ReviewLog) {
        log.optedOut = true
    }

    static func optOut(defaults: UserDefaults = ReviewLog.defaults) {
        var log = ReviewLog.load(defaults)
        optOut(&log)
        log.save(defaults)
    }

    /// Picks up what the old per-version flag says: someone already asked for this version (by the old
    /// logic, or by the "Noter" button) is not asked again at once. Without a known date, "now" is used.
    static func absorbLegacy(_ log: inout ReviewLog, settings: AppSettings, now: Date = Date()) {
        log.openCount = max(log.openCount, settings.openCount)
        if log.firstUseDate == nil, settings.openCount > 0 {
            // The real first use is unknown: the latest known opening is the cautious choice.
            log.firstUseDate = min(now, settings.lastCountedOpen ?? now)
        }
        guard let version = settings.reviewRequestedVersion, log.legacyVersion != version else { return }
        log.legacyVersion = version
        if log.askDates.isEmpty {
            // The old flow did call the system request: it counts as an attempt.
            recordAttempt(&log, positive: nil, now: now)
        } else {
            // A manual rating: only the spacing starts again, no system request was made.
            log.nextAllowedDate = max(log.nextAllowedDate ?? now, now.addingTimeInterval(firstGap))
        }
    }

    // MARK: Persistence helpers (the app calls these)

    /// An opening of the app: the count, the days of use, the first use.
    static func recordOpen(at date: Date = Date(), defaults: UserDefaults = ReviewLog.defaults) {
        var log = ReviewLog.load(defaults)
        log.recordOpen(at: date)
        log.save(defaults)
    }

    /// A good moment happened (workout recorded, goal reached, widget made).
    static func noteGoodMoment(defaults: UserDefaults = ReviewLog.defaults) {
        var log = ReviewLog.load(defaults)
        log.goodMoments += 1
        log.goodMomentsSinceAsk += 1
        log.save(defaults)
    }

    /// True when a request may be worth waiting for (nothing saved, cheap).
    static func isWorthWaitingFor(settings: AppSettings, store: SharedStore = .shared, now: Date = Date(),
                                  defaults: UserDefaults = ReviewLog.defaults) -> Bool {
        var log = ReviewLog.load(defaults)
        absorbLegacy(&log, settings: settings, now: now)
        return blocker(log, positive: positiveExperience(store: store, now: now), now: now) == nil
    }

    /// Decides and, if it may go, records the attempt and saves it: the caller then makes the system
    /// call, once. Returns false (and saves only the absorbed legacy state) otherwise.
    static func claimRequest(settings: AppSettings, store: SharedStore = .shared, now: Date = Date(),
                             defaults: UserDefaults = ReviewLog.defaults) -> Bool {
        var log = ReviewLog.load(defaults)
        absorbLegacy(&log, settings: settings, now: now)
        let positive = positiveExperience(store: store, now: now)
        guard blocker(log, positive: positive, now: now) == nil else {
            log.save(defaults)
            return false
        }
        recordAttempt(&log, positive: positive, now: now)
        log.save(defaults)
        return true
    }
}

/// What Ardane remembers about its rating requests: its own attempts, never the person's answer
/// (iOS does not tell). Same scheme as `EncouragementLog`: Codable, in the App Group's defaults,
/// read tolerantly.
struct ReviewLog: Codable, Hashable {
    var openCount = 0
    var lastCountedOpen: Date?
    /// Day keys (yyyy-MM-dd) of the days the app was opened, the last 60.
    var openDays: [String] = []
    var firstUseDate: Date?
    var lastAskedDate: Date?
    var askCount = 0
    /// The dates of the attempts (the last 10), for the yearly limit.
    var askDates: [Date] = []
    var lastPositiveKind: String?
    var lastPositiveDate: Date?
    var nextAllowedDate: Date?
    var optedOut = false
    var goodMoments = 0
    var goodMomentsSinceAsk = 0
    /// The old per-version flag already taken in.
    var legacyVersion: String?

    static let key = "tessera.review.log"

    /// The App Group's defaults: shared by the app and the intents.
    static var defaults: UserDefaults { UserDefaults(suiteName: AppGroup.identifier) ?? .standard }

    enum CodingKeys: String, CodingKey {
        case openCount, lastCountedOpen, openDays, firstUseDate, lastAskedDate, askCount, askDates
        case lastPositiveKind, lastPositiveDate, nextAllowedDate, optedOut, goodMoments, goodMomentsSinceAsk, legacyVersion
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        openCount = c.value(.openCount, 0)
        lastCountedOpen = c.optional(.lastCountedOpen)
        openDays = c.value(.openDays, [])
        firstUseDate = c.optional(.firstUseDate)
        lastAskedDate = c.optional(.lastAskedDate)
        askCount = c.value(.askCount, 0)
        askDates = c.value(.askDates, [])
        lastPositiveKind = c.optional(.lastPositiveKind)
        lastPositiveDate = c.optional(.lastPositiveDate)
        nextAllowedDate = c.optional(.nextAllowedDate)
        optedOut = c.value(.optedOut, false)
        goodMoments = c.value(.goodMoments, 0)
        goodMomentsSinceAsk = c.value(.goodMomentsSinceAsk, 0)
        legacyVersion = c.optional(.legacyVersion)
    }

    /// Counts an opening, unless the previous one was too recent; remembers the day and the first use.
    mutating func recordOpen(at date: Date) {
        if firstUseDate == nil { firstUseDate = date }
        let key = DateMath.dayKey(date)
        if !openDays.contains(key) {
            openDays.append(key)
            if openDays.count > 60 { openDays.removeFirst(openDays.count - 60) }
        }
        if let last = lastCountedOpen, date.timeIntervalSince(last) < ReviewPrompt.minimumGap { return }
        openCount += 1
        lastCountedOpen = date
    }

    func attemptsInLastYear(now: Date) -> Int {
        askDates.filter { now.timeIntervalSince($0) < ReviewPrompt.yearLength }.count
    }

    /// 5 openings, on 3 different days, and 5 days since the first use.
    func hasEnoughUse(now: Date) -> Bool {
        guard openCount >= ReviewPrompt.opensBeforeAsking,
              openDays.count >= ReviewPrompt.distinctDaysBeforeAsking,
              let first = firstUseDate else { return false }
        return DateMath.daysBetween(first, now) >= ReviewPrompt.daysSinceFirstUseBeforeAsking
    }

    static func load(_ defaults: UserDefaults = ReviewLog.defaults) -> ReviewLog {
        guard let data = defaults.data(forKey: key),
              let log = try? JSONDecoder().decode(ReviewLog.self, from: data) else { return ReviewLog() }
        return log
    }

    func save(_ defaults: UserDefaults = ReviewLog.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
