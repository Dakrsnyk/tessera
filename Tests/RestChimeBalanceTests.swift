import XCTest
@testable import Ardane

/// Requests of 2026-11-23: the « Solde » widget of Budget, « Séance du jour » apart from « Prochaine série », and the
/// « ding » (or a vibration on silent) at the end of a rest.
@MainActor
final class RestChimeBalanceTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func routine() -> Routine {
        Routine(name: "Haut du corps", exercises: [
            ExerciseTemplate(name: "Développé", sets: 3, reps: 8, weight: 60),
            ExerciseTemplate(name: "Tirage", sets: 2, reps: 10, weight: 40)
        ])
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // MARK: End of the rest

    func testTheRestToRingIsTheOneRunning() {
        var state = FitnessState()
        XCTAssertNil(RestNotifier.pendingEnd(state, now: t0), "No session: nothing to ring")
        state.startSession(routine(), at: t0)
        XCTAssertNil(RestNotifier.pendingEnd(state, now: t0), "Started, no set yet: no rest")
        XCTAssertTrue(state.completeNextSet(at: t0.addingTimeInterval(30)))
        let end = state.active?.restEndsAt
        XCTAssertNotNil(end)
        XCTAssertEqual(RestNotifier.pendingEnd(state, now: t0.addingTimeInterval(40)), end)
        XCTAssertNil(RestNotifier.pendingEnd(state, now: t0.addingTimeInterval(200)), "A rest already over rings no more")
        state.pauseRest(at: t0.addingTimeInterval(40))
        XCTAssertNil(RestNotifier.pendingEnd(state, now: t0.addingTimeInterval(41)), "A paused rest does not ring")
    }

    func testTheChimeOnlyRingsOnTimeWithTheAppInFront() {
        XCTAssertTrue(RestChime.shouldRing(end: t0, now: t0, isInBackground: false))
        XCTAssertTrue(RestChime.shouldRing(end: t0, now: t0.addingTimeInterval(2), isInBackground: false))
        XCTAssertFalse(RestChime.shouldRing(end: t0, now: t0.addingTimeInterval(30), isInBackground: false), "Never late")
        XCTAssertFalse(RestChime.shouldRing(end: t0, now: t0, isInBackground: true), "In the background, the notification rings")
    }

    func testTheRestAlertUsesTheArdaneSound() {
        XCTAssertEqual(RestNotifier.soundFile, "ardane-ding.wav")
        let name = (RestNotifier.soundFile as NSString).deletingPathExtension
        XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "wav"), "The sound is in the app")
    }

    // MARK: Séance du jour / Prochaine série

    func testTodaysWorkoutIsTheSessionNotTheSetControls() {
        var state = FitnessState()
        state.routines = [routine()]
        var tile = FitnessTiles.todaysWorkout(state, now: t0)
        XCTAssertTrue(tile.buttons.isEmpty, "No « Série faite » in « Séance du jour »")
        XCTAssertEqual(tile.headerButton?.symbol, "play.fill", "« Commencer » before the session")
        XCTAssertEqual(tile.rows.count, 2, "Every exercise of the session")

        state.startSession(routine(), at: t0)
        _ = state.completeNextSet(at: t0.addingTimeInterval(30))
        tile = FitnessTiles.todaysWorkout(state, now: t0.addingTimeInterval(40))
        XCTAssertTrue(tile.buttons.isEmpty)
        XCTAssertNil(tile.headerButton, "During the session, the sets are done from « Prochaine série »")
        XCTAssertEqual(tile.rows.filter(\.isHighlighted).count, 1, "The current exercise stands out")

        let next = FitnessTiles.nextSet(state, now: t0.addingTimeInterval(40))
        XCTAssertTrue(next.buttons.contains { $0.symbol == "checkmark" }, "« Prochaine série » keeps « Série faite »")
        XCTAssertTrue(WidgetKind.todaysWorkout.isInteractive)
    }

    // MARK: Solde

    func testBalanceWidgetFollowsTheAccount() {
        var state = BudgetState()
        XCTAssertNotNil(MoneyTiles.balance(state, now: day(2026, 10, 15), currency: "CAD").empty, "Nothing noted: the empty state")
        state.openingBalance = 1_000
        state.openingDate = day(2026, 10, 1, 0)
        state.addIncome(IncomeEntry(amount: 500, label: "Salaire", date: day(2026, 10, 5)))
        state.add(Expense(amount: 200, date: day(2026, 10, 10)))
        let tile = MoneyTiles.balance(state, now: day(2026, 10, 15), currency: "CAD")
        XCTAssertNil(tile.empty)
        XCTAssertEqual(tile.value, TF.money(1_300, "CAD"))
        XCTAssertEqual(tile.rows.first?.value, TF.money(1_000, "CAD"), "Balance on the 1st")
        XCTAssertEqual(tile.rows.dropFirst().first?.value, "+" + TF.money(500, "CAD"), "This month's income")
        XCTAssertEqual(tile.rows.last?.value, "−" + TF.money(200, "CAD"), "This month's expenses")
        XCTAssertNil(tile.footnote, "With a « Solde de départ », no warning")
        if case .line = tile.visual {} else { XCTFail("The month's line") }
    }

    func testBalanceWidgetGoesNegativeInRed() {
        var state = BudgetState()
        state.add(Expense(amount: 80, date: day(2026, 10, 3)))
        let tile = MoneyTiles.balance(state, now: day(2026, 10, 4), currency: "CAD")
        XCTAssertEqual(tile.trend, false)
        XCTAssertTrue(tile.value.hasPrefix("−"))
        XCTAssertNotNil(tile.footnote, "Without a « Solde de départ », says the count starts from zero")
    }

    func testBalanceWidgetIsInTheBudgetGroup() {
        XCTAssertEqual(WidgetKind.balance.space, .budget)
        XCTAssertEqual(WidgetKind.balance.category, .finance)
        XCTAssertTrue(TileFactory.isSensitive(.balance), "Hidden on the locked iPhone, like the other amounts")
    }
}
