import XCTest
@testable import Ardane

/// The figures of the hybrid Planning page (refonte du 2026-11-17) : the card « Prochain événement » and the start
/// of an event made by the « Nouvel événement » button.
final class PlanningHybridTests: XCTestCase {
    /// Thursday 12 November 2026 at the given time, the day of the mock-ups.
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hour, minute: minute))!
    }

    private func item(_ title: String, from start: Date?, to end: Date?, done: Bool? = nil) -> AgendaItem {
        AgendaItem(id: title, kind: .classSlot, title: title, detail: nil, start: start, end: end,
                   colorHex: "3366FF", symbol: "book", isDone: done)
    }

    func testTheNextEventIsTheFirstToBegin() {
        let items = [item("Soir", from: at(18, 30), to: at(19, 30)), item("Comptabilité", from: at(14), to: at(15))]
        let pick = PlanningNext.pick(from: items, now: at(13, 20))
        XCTAssertEqual(pick?.item.title, "Comptabilité")
        XCTAssertEqual(pick?.inProgress, false)
        XCTAssertEqual(pick?.minutes, 40)
    }

    func testAnEventInProgressComesFirstWithTheTimeLeft() {
        let items = [item("Comptabilité", from: at(14), to: at(15)), item("Soir", from: at(18), to: at(19))]
        let pick = PlanningNext.pick(from: items, now: at(14, 20))
        XCTAssertEqual(pick?.item.title, "Comptabilité")
        XCTAssertEqual(pick?.inProgress, true)
        XCTAssertEqual(pick?.minutes, 40)
    }

    func testWhatIsOverCheckedOffOrWithoutTimeDoesNotCount() {
        let items = [item("Fini", from: at(9), to: at(10)),
                     item("Sans fin", from: at(12), to: nil),
                     item("Journée", from: nil, to: nil),
                     item("Fait", from: at(16), to: at(17), done: true)]
        XCTAssertNil(PlanningNext.pick(from: items, now: at(13, 20)))
        XCTAssertNil(PlanningNext.pick(from: [], now: at(13, 20)))
    }

    func testLengthsReadInMinutesThenInHours() {
        // The words come from the catalogue (language of the simulator): only the numbers are checked.
        XCTAssertTrue(PlanningNext.lengthText(minutes: 0).hasPrefix("1"))
        XCTAssertTrue(PlanningNext.lengthText(minutes: 40).hasPrefix("40"))
        let long = PlanningNext.lengthText(minutes: 125)
        XCTAssertTrue(long.hasPrefix("2") && long.contains("05"), long)
    }

    func testTheNewEventStartsAtTheNextHalfHourToday() {
        XCTAssertEqual(PlanningNext.defaultStartMinute(now: at(13, 20), isToday: true), 13 * 60 + 30)
        XCTAssertEqual(PlanningNext.defaultStartMinute(now: at(13, 30), isToday: true), 14 * 60)
        XCTAssertEqual(PlanningNext.defaultStartMinute(now: at(23, 50), isToday: true), 23 * 60)
    }

    func testTheNewEventStartsAtNineOnAnotherDay() {
        XCTAssertEqual(PlanningNext.defaultStartMinute(now: at(13, 20), isToday: false), 9 * 60)
    }
}
