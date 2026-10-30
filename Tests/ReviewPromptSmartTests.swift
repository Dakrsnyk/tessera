import XCTest
@testable import Ardane

/// The rating request: real use, a real positive experience, growing spacing, yearly limit, opt-out,
/// migration from the old per-version flag.
final class ReviewPromptSmartTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A log of a person who opened the app on `days` different days, starting at `start`.
    private func usedLog(days: Int, opensPerDay: Int = 2) -> ReviewLog {
        var log = ReviewLog()
        for d in 0..<days {
            for o in 0..<opensPerDay {
                log.recordOpen(at: start.addingTimeInterval(Double(d) * day + Double(o) * 5 * 3600))
            }
        }
        return log
    }

    private func habit(streak: Int, endingOn date: Date) -> Habit {
        var habit = Habit(name: "Test", symbol: "star", colorHex: "#FFFFFF")
        for offset in 0..<streak {
            habit.completedDays.append(DateMath.dayKey(date.addingTimeInterval(-Double(offset) * day)))
        }
        return habit
    }

    // MARK: Use

    func testANewPersonIsNeverAsked() {
        var log = ReviewLog()
        log.recordOpen(at: start)
        log.goodMomentsSinceAsk = 5
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .workouts, now: start), .notEnoughUse)
    }

    func testRegularUseWithoutAPositiveExperienceIsNotAsked() {
        let log = usedLog(days: 7)
        let now = start.addingTimeInterval(7 * day)
        XCTAssertTrue(log.hasEnoughUse(now: now))
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: nil, now: now), .noPositiveExperience)
    }

    func testFewDaysOrFewOpeningsStillWait() {
        // 10 openings on 2 days: not enough different days.
        let twoDays = usedLog(days: 2, opensPerDay: 5)
        XCTAssertGreaterThanOrEqual(twoDays.openCount, ReviewPrompt.opensBeforeAsking)
        XCTAssertEqual(ReviewPrompt.blocker(twoDays, positive: .habitStreak, now: start.addingTimeInterval(9 * day)), .notEnoughUse)
        // Enough days and openings, but the first use is under 5 days old.
        let recent = usedLog(days: 3)
        XCTAssertEqual(ReviewPrompt.blocker(recent, positive: .habitStreak, now: start.addingTimeInterval(3 * day)), .notEnoughUse)
    }

    func testTheFirstRequestComesAfterTheThresholdAndAPositiveExperience() {
        let log = usedLog(days: 6)
        let now = start.addingTimeInterval(6 * day)
        XCTAssertNil(ReviewPrompt.blocker(log, positive: .habitStreak, now: now))
        // Good moments piling up count too, three of them.
        var moments = log
        moments.goodMomentsSinceAsk = 2
        XCTAssertEqual(ReviewPrompt.blocker(moments, positive: nil, now: now), .noPositiveExperience)
        moments.goodMomentsSinceAsk = 3
        XCTAssertNil(ReviewPrompt.blocker(moments, positive: nil, now: now))
    }

    // MARK: Spacing

    func testRecordingAnAttemptSchedulesTheNextOne() {
        var log = usedLog(days: 6)
        let now = start.addingTimeInterval(6 * day)
        ReviewPrompt.recordAttempt(&log, positive: .workouts, now: now)
        XCTAssertEqual(log.askCount, 1)
        XCTAssertEqual(log.lastAskedDate, now)
        XCTAssertEqual(log.lastPositiveKind, ReviewPrompt.Positive.workouts.rawValue)
        XCTAssertEqual(log.nextAllowedDate, now.addingTimeInterval(30 * day))
        XCTAssertEqual(log.goodMomentsSinceAsk, 0)
    }

    func testTheSecondRequestNeedsThirtyDaysAndANewGoodMoment() {
        var log = usedLog(days: 6)
        let first = start.addingTimeInterval(6 * day)
        ReviewPrompt.recordAttempt(&log, positive: .habitStreak, now: first)
        log.goodMomentsSinceAsk = 1
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .habitStreak, now: first.addingTimeInterval(29 * day)), .tooSoon)
        let later = first.addingTimeInterval(30 * day)
        // 30 days later but nothing new since the first request.
        log.goodMomentsSinceAsk = 0
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .habitStreak, now: later), .noPositiveExperience)
        log.goodMomentsSinceAsk = 1
        XCTAssertNil(ReviewPrompt.blocker(log, positive: .habitStreak, now: later))
    }

    func testTheThirdRequestNeedsNinetyDays() {
        var log = usedLog(days: 6)
        let first = start.addingTimeInterval(6 * day)
        ReviewPrompt.recordAttempt(&log, positive: .habitStreak, now: first)
        let second = first.addingTimeInterval(31 * day)
        ReviewPrompt.recordAttempt(&log, positive: .workouts, now: second)
        XCTAssertEqual(log.askCount, 2)
        XCTAssertEqual(log.nextAllowedDate, second.addingTimeInterval(90 * day))
        log.goodMomentsSinceAsk = 2
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .workouts, now: second.addingTimeInterval(89 * day)), .tooSoon)
        XCTAssertNil(ReviewPrompt.blocker(log, positive: .workouts, now: second.addingTimeInterval(90 * day)))
    }

    func testNoMoreThanThreeAttemptsInAYear() {
        var log = usedLog(days: 6)
        var now = start.addingTimeInterval(6 * day)
        for _ in 0..<3 {
            ReviewPrompt.recordAttempt(&log, positive: .workouts, now: now)
            now = now.addingTimeInterval(100 * day)
        }
        log.goodMomentsSinceAsk = 4
        // 300 days after the first attempt: spacing is fine, the yearly limit is not.
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .workouts, now: now), .yearlyLimit)
        // More than a year after the first attempt, the oldest one no longer counts.
        let nextYear = start.addingTimeInterval(6 * day + 366 * day)
        XCTAssertEqual(log.attemptsInLastYear(now: nextYear), 2)
        XCTAssertNil(ReviewPrompt.blocker(log, positive: .workouts, now: nextYear))
    }

    // MARK: Opt-out

    func testOptOutStopsEverything() {
        var log = usedLog(days: 6)
        ReviewPrompt.optOut(&log)
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .workouts, now: start.addingTimeInterval(400 * day)), .optedOut)
    }

    // MARK: Migration

    func testSomeoneAlreadyAskedForThisVersionIsNotAskedAtOnce() {
        var settings = AppSettings()
        settings.openCount = 12
        settings.lastCountedOpen = start
        settings.reviewRequestedVersion = "1"
        var log = usedLog(days: 6)
        let now = start.addingTimeInterval(6 * day)
        ReviewPrompt.absorbLegacy(&log, settings: settings, now: now)
        XCTAssertEqual(log.askCount, 1)
        XCTAssertEqual(log.openCount, 12)
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .workouts, now: now.addingTimeInterval(day)), .tooSoon)
        // Absorbed once: a second pass changes nothing.
        let saved = log
        ReviewPrompt.absorbLegacy(&log, settings: settings, now: now.addingTimeInterval(day))
        XCTAssertEqual(log, saved)
    }

    func testAManualRatingDelaysTheNextRequestWithoutCountingAnAttempt() {
        var log = usedLog(days: 6)
        let now = start.addingTimeInterval(6 * day)
        ReviewPrompt.recordAttempt(&log, positive: .habitStreak, now: now.addingTimeInterval(-40 * day))
        var settings = AppSettings()
        settings.reviewRequestedVersion = "1"
        ReviewPrompt.absorbLegacy(&log, settings: settings, now: now)
        XCTAssertEqual(log.askCount, 1, "No system request was made by the button")
        XCTAssertEqual(log.attemptsInLastYear(now: now), 1)
        log.goodMomentsSinceAsk = 1
        XCTAssertEqual(ReviewPrompt.blocker(log, positive: .workouts, now: now.addingTimeInterval(day)), .tooSoon)
    }

    func testAnUnaskedPersonKeepsHerOpeningsInTheMigration() {
        var settings = AppSettings()
        settings.openCount = 9
        settings.lastCountedOpen = start
        var log = ReviewLog()
        ReviewPrompt.absorbLegacy(&log, settings: settings, now: start.addingTimeInterval(day))
        XCTAssertEqual(log.openCount, 9)
        XCTAssertEqual(log.askCount, 0)
        XCTAssertNotNil(log.firstUseDate)
    }

    // MARK: Signals and persistence

    func testAHabitStreakOfFiveDaysIsAPositiveExperience() {
        var content = ContentState()
        content.habits = [habit(streak: 4, endingOn: start)]
        XCTAssertNil(ReviewPrompt.positiveExperience(content: content, fitness: FitnessState(), nutrition: NutritionState(), now: start))
        content.habits = [habit(streak: 5, endingOn: start)]
        XCTAssertEqual(ReviewPrompt.positiveExperience(content: content, fitness: FitnessState(), nutrition: NutritionState(), now: start),
                       .habitStreak)
    }

    func testTheLogIsSavedAndReadTolerantly() throws {
        let suite = "tessera.test.review.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(ReviewLog.load(defaults), ReviewLog())
        ReviewPrompt.recordOpen(at: start, defaults: defaults)
        ReviewPrompt.noteGoodMoment(defaults: defaults)
        ReviewPrompt.optOut(defaults: defaults)
        let log = ReviewLog.load(defaults)
        XCTAssertEqual(log.openCount, 1)
        XCTAssertEqual(log.goodMomentsSinceAsk, 1)
        XCTAssertTrue(log.optedOut)
        // An empty or older record reads as a new log.
        let empty = try JSONDecoder().decode(ReviewLog.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, ReviewLog())
    }
}
