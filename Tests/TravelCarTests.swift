import XCTest
@testable import Tessera

/// The Travel and Auto mini-apps: a trip's program and budget in any currency, its checklist, and a
/// car's range, distance and consumption, all from what the person noted.
final class TravelCarTests: XCTestCase {
    private func october(_ day: Int, _ hour: Int = 12) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    // MARK: Travel

    func testATripGathersItsProgramDayByDay() {
        var state = TravelState()
        let trip = Trip(destination: "Lisbonne", start: october(10, 21), end: october(17, 18), timeZoneID: "Europe/Lisbon", currencyCode: "EUR")
        state.trips = [trip]
        state.flights = [
            Flight(number: "TP 258", from: "YUL", to: "LIS", departure: october(10, 21), gate: "52"),
            Flight(number: "AC 1", from: "YUL", to: "YYZ", departure: october(2, 8)),
        ]
        state.stays = [Stay(name: "Hôtel Alfama", checkIn: october(11, 15), checkOut: october(17, 11))]
        state.activities = [TripActivity(title: "Tram 28", date: october(12, 11)), TripActivity(title: "Château", date: october(12, 9))]
        XCTAssertEqual(TravelMath.flights(state, for: trip).map(\.number), ["TP 258"], "A flight outside the trip is not in it")
        let program = TravelMath.program(state, for: trip)
        XCTAssertEqual(program.map { DateMath.calendar.component(.day, from: $0.day) }, [10, 11, 12, 17])
        XCTAssertEqual(program[2].items.map(\.title), ["Château", "Tram 28"], "In the order of the day")
        XCTAssertEqual(program[0].items.first?.detail, "YUL → LIS · porte 52")
        XCTAssertEqual(program[3].items.first?.kind, .checkOut)
    }

    func testTheBudgetConvertsWithTheReferenceRates() {
        var state = TravelState()
        let trip = Trip(destination: "Lisbonne", start: october(10), end: october(17), currencyCode: "EUR")
        state.trips = [trip]
        state.expenses = [
            TripExpense(tripID: trip.id, amount: 1_000, currencyCode: "CAD", kind: .transport),
            TripExpense(tripID: trip.id, amount: 66, currencyCode: "EUR", kind: .food),
            TripExpense(tripID: trip.id, amount: 10, currencyCode: "JPY", kind: .other),
            TripExpense(tripID: UUID(), amount: 500, currencyCode: "CAD", kind: .lodging),
        ]
        let rates = FXRates(base: "CAD", rates: ["EUR": 0.66], day: "2026-10-01", fetchedAt: Date())
        let spending = TravelMath.spending(state, for: trip, home: "CAD", rates: rates)
        XCTAssertEqual(spending.total, 1_100, accuracy: 0.001)
        XCTAssertEqual(spending.byKind[.food] ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(spending.unconverted["JPY"], 10, "Without a rate, the amount is shown apart, never guessed")
        XCTAssertNil(spending.byKind[.lodging], "Another trip's expense is not counted")
        // Without any rate, only the home currency adds up.
        XCTAssertEqual(TravelMath.spending(state, for: trip, home: "CAD", rates: nil).total, 1_000)
    }

    func testTheChecklistAddsTheEssentialsOnce() {
        var state = TravelState()
        let trip = UUID()
        state.checklist = [ChecklistItem(tripID: trip, title: "passeport")]
        state.addEssentials(to: trip, abroad: true)
        XCTAssertEqual(state.checklist.filter { $0.title.lowercased() == "passeport" }.count, 1)
        XCTAssertTrue(state.checklist.contains { $0.title == "Adaptateur de prise" })
        let count = state.checklist.count
        state.addEssentials(to: trip, abroad: true)
        XCTAssertEqual(state.checklist.count, count, "No duplicates")
        state.toggleChecklist(state.checklist[0].id)
        XCTAssertTrue(state.checklist[0].isDone)

        var other = TravelState()
        other.addEssentials(to: trip, abroad: false)
        XCTAssertFalse(other.checklist.contains { $0.title == "Passeport" }, "No passport for a trip at home")

        state.trips = [Trip(id: trip, destination: "Québec", start: october(1), end: october(3))]
        state.expenses = [TripExpense(tripID: trip, amount: 20, currencyCode: "CAD")]
        state.deleteTrip(trip)
        XCTAssertTrue(state.trips.isEmpty && state.expenses.isEmpty && state.checklist.isEmpty)
    }

    func testOlderTripsOpenWithoutBudgetOrChecklist() throws {
        let json = #"{"trips":[{"id":"8A1B2C3D-0000-0000-0000-000000000003","destination":"Paris","start":0,"end":86400,"timeZoneID":"Europe/Paris","currencyCode":"EUR"}],"flights":[],"stays":[],"activities":[],"sampleAmount":100}"#
        let state = try JSONDecoder().decode(TravelState.self, from: Data(json.utf8))
        XCTAssertEqual(state.trips.first?.destination, "Paris")
        XCTAssertNil(state.trips.first?.budget)
        XCTAssertTrue(state.expenses.isEmpty)
        XCTAssertTrue(state.checklist.isEmpty)
    }

    // MARK: Car

    func testTheRangeFollowsTheConsumptionSinceTheLastFullTank() {
        var state = CarState()
        state.fills = [
            FuelFill(date: october(1), liters: 40, total: 64, odometer: 10_000),
            FuelFill(date: october(8), liters: 40, total: 64, odometer: 10_500),
        ]
        XCTAssertNil(CarMath.range(state), "Without the tank size, no range")
        state.tankLiters = 50
        // 8 L/100 km; 100 km driven since the last full tank: 42 L left, 525 km.
        state.readings = [OdometerReading(date: october(9), km: 10_600)]
        let range = try? XCTUnwrap(CarMath.range(state))
        XCTAssertEqual(range?.liters ?? 0, 42, accuracy: 0.01)
        XCTAssertEqual(range?.km ?? 0, 525, accuracy: 0.1)
        XCTAssertEqual(range?.share ?? 0, 0.84, accuracy: 0.001)
        // A partial fill adds fuel back, never above the tank.
        state.fills.append(FuelFill(date: october(9, 18), liters: 20, total: 32, odometer: 10_650, isFull: false))
        XCTAssertEqual(CarMath.range(state)?.liters ?? 0, 50, accuracy: 0.01)

        let byFill = CarMath.consumptionByFill(state)
        XCTAssertEqual(byFill.count, 1)
        XCTAssertEqual(byFill[0].perHundred, 8, accuracy: 0.001)
    }

    func testDistanceIsCountedMonthByMonth() {
        var state = CarState()
        let august = DateMath.calendar.date(from: DateComponents(year: 2026, month: 8, day: 28))!
        let september = DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        state.readings = [
            OdometerReading(date: august, km: 20_000),
            OdometerReading(date: september, km: 21_200),
            OdometerReading(date: october(5), km: 21_500),
        ]
        let months = CarMath.kmByMonth(state, count: 3, at: october(6))
        XCTAssertEqual(months.map(\.km), [0, 1_200, 300])

        var fill = FuelFill(liters: 30, total: 50, odometer: 21_600)
        state.save(fill)
        fill.total = 48
        state.save(fill)
        XCTAssertEqual(state.fills.count, 1)
        XCTAssertEqual(state.fills[0].total, 48)
    }
}
