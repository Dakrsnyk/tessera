import XCTest
@testable import Ardane

/// The Planning widget and calendar: the week's schedule fills its widget, the calendar zooms by clear gestures only.
final class PlanningLayoutTests: XCTestCase {
    func testOnlyTheWeekScheduleTakesAllTheHeightOfAWidget() {
        XCTAssertTrue(TileVisual.schedule([], today: nil, dates: [], firstMinute: 8 * 60, lastMinute: 18 * 60).isSchedule)
        XCTAssertFalse(TileVisual.none.isSchedule)
        XCTAssertFalse(TileVisual.ring(0.5).isSchedule)
        XCTAssertFalse(TileVisual.bar(0.5).isSchedule)
        XCTAssertFalse(TileVisual.line([1, 2, 3]).isSchedule)
    }

    func testAPinchOnlyZoomsWhenItIsClear() {
        XCTAssertEqual(CalendarScale.step(for: 1.0), 0, "No gesture: nothing")
        XCTAssertEqual(CalendarScale.step(for: 1.2), 0, "A slight spread: nothing")
        XCTAssertEqual(CalendarScale.step(for: 0.85), 0, "A slight pinch: nothing")
        XCTAssertEqual(CalendarScale.step(for: 1.5), -1, "A clear spread zooms in")
        XCTAssertEqual(CalendarScale.step(for: 0.6), 1, "A clear pinch zooms out")
    }

    func testTheScalesGoFromTheDayToTheYear() {
        XCTAssertNil(CalendarScale.day.closer)
        XCTAssertEqual(CalendarScale.day.wider, .week)
        XCTAssertEqual(CalendarScale.week.wider, .month)
        XCTAssertEqual(CalendarScale.month.wider, .year)
        XCTAssertNil(CalendarScale.year.wider)
        XCTAssertEqual(CalendarScale.year.closer, .month)
    }
}
