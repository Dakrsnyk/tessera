import XCTest
@testable import Ardane

/// The new data of the hybrid Auto mini-app (refonte du 2026-11-17): the history of a maintenance, the deadline
/// that comes back every year and the one marked done. Only numbers and dates are compared, never a translated text.
final class CarHybridTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testMarkingAServiceDoneKeepsEveryTime() {
        var state = CarState()
        let item = ServiceItem(name: "Vidange", intervalKm: 8_000, lastKm: 50_000, cost: 90)
        state.services = [item]
        XCTAssertNil(state.services[0].history)
        state.markServiceDone(item.id, km: 58_000, at: date(2026, 5, 1))
        state.markServiceDone(item.id, km: 66_000, at: date(2026, 11, 1))
        let history = state.services[0].history ?? []
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.last?.km, 66_000)
        XCTAssertEqual(history.last?.cost, 90)
        XCTAssertEqual(state.services[0].lastKm, 66_000, "The last time is still the one the gauge reads")
    }

    func testADeadlineThatRepeatsMovesOneYear() {
        var state = CarState()
        let deadline = CarDeadline(title: "Assurance", date: date(2026, 11, 17), repeatsYearly: true)
        state.deadlines = [deadline]
        state.markDeadlineDone(deadline.id, at: date(2026, 11, 12))
        XCTAssertEqual(state.deadlines[0].date, date(2027, 11, 17))
        XCTAssertNil(state.deadlines[0].doneOn)
    }

    func testARepeatingDeadlineLongPastCatchesUpWithToday() {
        var state = CarState()
        let deadline = CarDeadline(title: "Immatriculation", date: date(2023, 3, 1), repeatsYearly: true)
        state.deadlines = [deadline]
        state.markDeadlineDone(deadline.id, at: date(2026, 11, 12))
        XCTAssertEqual(state.deadlines[0].date, date(2027, 3, 1))
    }

    func testADeadlineDoneLeavesWhatComes() {
        var state = CarState()
        let deadline = CarDeadline(title: "Pneus d'hiver", date: date(2026, 12, 1))
        state.deadlines = [deadline]
        XCTAssertEqual(CarMath.upcomingDeadlines(state, at: date(2026, 11, 12)).count, 1)
        state.markDeadlineDone(deadline.id, at: date(2026, 11, 12))
        XCTAssertNotNil(state.deadlines[0].doneOn)
        XCTAssertEqual(CarMath.upcomingDeadlines(state, at: date(2026, 11, 12)).count, 0)
        XCTAssertEqual(state.deadlines.count, 1, "Nothing is deleted")
    }

    func testAnOldSaveStillDecodes() throws {
        let json = """
        {"name":"Civic","services":[{"id":"6F0F5E6A-3C41-4C6D-8D3E-1F4B7B9A2C11","name":"Vidange","cost":90}],
         "deadlines":[{"id":"1D2C3B4A-5E6F-4A7B-8C9D-0E1F2A3B4C5D","title":"Assurance","date":0,"symbol":"shield.fill"}]}
        """
        let state = try JSONDecoder().decode(CarState.self, from: Data(json.utf8))
        XCTAssertEqual(state.services.count, 1)
        XCTAssertNil(state.services[0].history)
        XCTAssertEqual(state.deadlines.count, 1)
        XCTAssertNil(state.deadlines[0].repeatsYearly)
        XCTAssertNil(state.deadlines[0].doneOn)
    }
}
