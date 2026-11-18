import XCTest
@testable import Ardane

/// The figures of the hybrid Travel screens (direction 5, 2026-11-17): the phase of a trip, what is left to spend
/// each day, the overrun, the grouping of « Mes voyages », and the deletion of a trip with what belongs to it.
/// Only numbers and values are compared, never a translated text.
final class TravelHybridTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Lisbon from the 12th to the 19th of June 2027 (8 days), 1 500 of budget.
    private func lisbon() -> Trip {
        var trip = Trip(destination: "Lisbonne", start: date(2027, 6, 12, 9), end: date(2027, 6, 19, 18))
        trip.budget = 1_500
        return trip
    }

    func testThePhaseFollowsWholeDays() {
        let trip = lisbon()
        XCTAssertEqual(TravelHybrid.phase(trip, at: date(2027, 6, 11, 23)), .upcoming)
        XCTAssertEqual(TravelHybrid.phase(trip, at: date(2027, 6, 12, 1)), .ongoing)
        XCTAssertEqual(TravelHybrid.phase(trip, at: date(2027, 6, 19, 23)), .ongoing)
        XCTAssertEqual(TravelHybrid.phase(trip, at: date(2027, 6, 20, 1)), .finished)
    }

    func testWhatIsLeftEachDayCountsTheDaysLeftTodayIncluded() throws {
        let trip = lisbon()
        // Day 3 of 8: six days left, today included.
        let perDay = try XCTUnwrap(TravelHybrid.perDay(budget: 1_500, spent: 600, trip: trip, at: date(2027, 6, 14)))
        XCTAssertEqual(perDay, 150, accuracy: 0.0001)
        // The last day: all that is left.
        let last = try XCTUnwrap(TravelHybrid.perDay(budget: 1_500, spent: 600, trip: trip, at: date(2027, 6, 19)))
        XCTAssertEqual(last, 900, accuracy: 0.0001)
    }

    func testNoPerDayBeforeAfterOrWithoutRoom() {
        let trip = lisbon()
        XCTAssertNil(TravelHybrid.perDay(budget: 1_500, spent: 0, trip: trip, at: date(2027, 6, 1)), "not begun")
        XCTAssertNil(TravelHybrid.perDay(budget: 1_500, spent: 0, trip: trip, at: date(2027, 6, 25)), "finished")
        XCTAssertNil(TravelHybrid.perDay(budget: nil, spent: 0, trip: trip, at: date(2027, 6, 14)), "no budget")
        XCTAssertNil(TravelHybrid.perDay(budget: 500, spent: 500, trip: trip, at: date(2027, 6, 14)), "nothing left")
        XCTAssertNil(TravelHybrid.perDay(budget: 500, spent: 700, trip: trip, at: date(2027, 6, 14)), "over the budget")
    }

    func testTheOverrunIsTheAmountOverTheBudget() throws {
        XCTAssertEqual(try XCTUnwrap(TravelHybrid.overrun(budget: 1_000, spent: 1_151.1)), 151.1, accuracy: 0.0001)
        XCTAssertNil(TravelHybrid.overrun(budget: 1_000, spent: 1_000))
        XCTAssertNil(TravelHybrid.overrun(budget: 0, spent: 50))
        XCTAssertNil(TravelHybrid.overrun(budget: nil, spent: 50))
    }

    func testTheTripsAreGroupedByWhatIsAheadAndWhatIsOver() {
        let now = date(2027, 6, 14)
        let past1 = Trip(destination: "New York", start: date(2026, 9, 5), end: date(2026, 9, 9))
        let past2 = Trip(destination: "Paris", start: date(2027, 3, 1), end: date(2027, 3, 5))
        let current = lisbon()
        let later = Trip(destination: "Tokyo", start: date(2027, 10, 1), end: date(2027, 10, 12))
        let groups = TravelHybrid.grouped([past1, later, past2, current], at: now)
        XCTAssertEqual(groups.ahead.map(\.id), [current.id, later.id], "under way first, then the soonest")
        XCTAssertEqual(groups.finished.map(\.id), [past2.id, past1.id], "the latest finished first")
    }

    func testDeletingATripRemovesItsExpensesAndChecklist() {
        let lisbon = lisbon()
        let other = Trip(destination: "Paris", start: date(2027, 9, 1), end: date(2027, 9, 5))
        var state = TravelState()
        state.trips = [lisbon, other]
        state.expenses = [TripExpense(tripID: lisbon.id, amount: 10, currencyCode: "EUR"), TripExpense(tripID: other.id, amount: 20, currencyCode: "EUR")]
        state.checklist = [ChecklistItem(tripID: lisbon.id, title: "A"), ChecklistItem(tripID: other.id, title: "B")]
        state.deleteTrip(lisbon.id)
        XCTAssertEqual(state.trips.map(\.id), [other.id])
        XCTAssertEqual(state.expenses.map(\.tripID), [other.id])
        XCTAssertEqual(state.checklist.map(\.tripID), [other.id])
    }

    func testTheNewExpenseUsesTheCurrencyThereOnlyUnderWay() {
        var trip = lisbon()
        trip.currencyCode = "EUR"
        XCTAssertEqual(Travel.newExpense(for: trip, home: "CAD", now: date(2027, 6, 14)).currencyCode, "EUR")
        XCTAssertEqual(Travel.newExpense(for: trip, home: "CAD", now: date(2027, 5, 1)).currencyCode, "CAD")
        XCTAssertEqual(Travel.newExpense(for: trip, home: "CAD", now: date(2027, 6, 14)).tripID, trip.id)
    }

    /// No stored field was added: a save from before still reads (the state keeps its tolerant decoding).
    func testAnOldSaveStillDecodes() throws {
        let json = #"{"trips":[],"sampleAmount":100}"#.data(using: .utf8)!
        let state = try JSONDecoder().decode(TravelState.self, from: json)
        XCTAssertTrue(state.trips.isEmpty)
        XCTAssertTrue(state.expenses.isEmpty)
        XCTAssertTrue(state.checklist.isEmpty)
    }
}
