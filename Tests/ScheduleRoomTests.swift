import WidgetKit
import XCTest
@testable import Ardane

/// The room of a class (and the place of an appointment or an event) on the week's tables: in the
/// app's full table and in the large « Horaire de la semaine » widget, written under the name when the
/// block has room for it, hidden on short blocks, always said by VoiceOver.
@MainActor
final class ScheduleRoomTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(store: SharedStore(directory: directory))
    }

    /// Wednesday 30 September 2026 at the given hour.
    private func wednesday(_ hour: Int, _ minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour, minute: minute))!
    }

    // MARK: The app

    func testTheAgendaKnowsWhereThingsTakePlace() {
        let model = temporaryModel()
        let course = Course(name: "Chimie", colorHex: "3366FF")
        model.update(\.student) { state in
            state.courses = [course]
            state.slots = [
                ClassSlot(courseID: course.id, weekday: 3, startMinute: 10 * 60, endMinute: 12 * 60, room: " B-12 "),
                ClassSlot(courseID: nil, weekday: 3, startMinute: 13 * 60, endMinute: 14 * 60, room: "Clinique du Parc", kind: .appointment, title: "Dentiste"),
                ClassSlot(courseID: course.id, weekday: 3, startMinute: 15 * 60, endMinute: 16 * 60),
            ]
            state.exams = [Exam(courseID: course.id, title: "Quiz", date: wednesday(17), room: "A-1")]
        }
        let event = EventSnapshot(id: "e", title: "Réunion", start: wednesday(18), end: wednesday(19), isAllDay: false, colorHex: "FF6B57", location: "Café")
        let items = Agenda.items(on: wednesday(7), model: model, events: [event])
        XCTAssertEqual(items.filter { $0.kind == .classSlot }.map(\.place), ["B-12", "Clinique du Parc", nil], "The room as entered, without its spaces; none when empty")
        XCTAssertEqual(items.first { $0.kind == .exam }?.place, "A-1")
        XCTAssertEqual(items.first { $0.kind == .event }?.place, "Café")
    }

    func testTheAppTableWritesTheRoomWhenTheBlockHasRoom() {
        // An hour at 38 points an hour (Planning's week): the name, the room, then the time.
        let hour = WeekTimetable.lines(height: 37, minutes: 60, hasPlace: true)
        XCTAssertTrue(hour.place)
        XCTAssertTrue(hour.time)
        // 50 minutes: the room before the time, which the hours down the side already give.
        let short = WeekTimetable.lines(height: 30.7, minutes: 50, hasPlace: true)
        XCTAssertTrue(short.place)
        XCTAssertFalse(short.time)
        // Half an hour: the name alone, the room hidden rather than over the next block.
        let half = WeekTimetable.lines(height: 18, minutes: 30, hasPlace: true)
        XCTAssertFalse(half.place)
        XCTAssertFalse(half.time)
        // Too short for the room, or without one: the time as before, from 50 minutes.
        let small = WeekTimetable.lines(height: 21, minutes: 60, hasPlace: true)
        XCTAssertFalse(small.place)
        XCTAssertTrue(small.time)
        let without = WeekTimetable.lines(height: 30.7, minutes: 50, hasPlace: false)
        XCTAssertFalse(without.place)
        XCTAssertTrue(without.time)

        let item = AgendaItem(id: "class-x", kind: .classSlot, title: "Chimie", detail: "Salle B-12", start: wednesday(10), end: wednesday(12),
                              colorHex: "3366FF", symbol: "graduationcap.fill", place: "B-12")
        let spoken = WeekTimetable.spoken(item)
        XCTAssertTrue(spoken.hasPrefix("Chimie, "))
        XCTAssertTrue(spoken.hasSuffix(", Salle B-12"), "VoiceOver says the room even when the block hides it")
    }

    // MARK: The widget

    func testTheWeekWidgetCarriesTheRoomAndSaysIt() {
        var state = StudentState()
        let course = Course(name: "Chimie", colorHex: "3366FF")
        state.courses = [course]
        state.slots = [
            ClassSlot(courseID: course.id, weekday: 3, startMinute: 10 * 60, endMinute: 12 * 60, room: "B-12"),
            ClassSlot(courseID: course.id, weekday: 4, startMinute: 10 * 60, endMinute: 11 * 60, room: "  "),
        ]
        let design = WidgetDesign(kind: .timetable)
        let context = RenderContext(design: design, style: ResolvedStyle(design: design), family: .systemLarge, date: wednesday(9),
                                    payload: WidgetPayload(), isInteractive: false)
        let tile = StudentTiles.weekSchedule(state, context: context)
        guard case let .schedule(blocks, _, _, _, _) = tile.visual else { return XCTFail("The large widget shows the week") }
        XCTAssertEqual(blocks.map(\.room), ["B-12", nil])
        XCTAssertEqual(ScheduleWeek.spoken(blocks[0]), "Chimie, 10:00, B-12")
        XCTAssertEqual(ScheduleWeek.spoken(blocks[1]), "Chimie, 10:00")
    }

    func testTheWeekWidgetHidesTheRoomOnShortBlocks() {
        let tiny = ScheduleWeek.lines(height: 10, hasRoom: true)
        XCTAssertEqual(tiny.title, 0)
        XCTAssertFalse(tiny.room)
        let short = ScheduleWeek.lines(height: 20, hasRoom: true)
        XCTAssertEqual(short.title, 1)
        XCTAssertFalse(short.room, "No room for it: hidden rather than over the block's edge")
        let hour = ScheduleWeek.lines(height: 26, hasRoom: true)
        XCTAssertTrue(hour.room)
        XCTAssertFalse(hour.time)
        let long = ScheduleWeek.lines(height: 40, hasRoom: true)
        XCTAssertEqual(long.title, 2)
        XCTAssertTrue(long.room)
        XCTAssertTrue(long.time)
        // Without a room, as before: the time from 24 points, the name on two lines from 34.
        let without = ScheduleWeek.lines(height: 36, hasRoom: false)
        XCTAssertEqual(without.title, 2)
        XCTAssertFalse(without.room)
        XCTAssertTrue(without.time)
    }
}
