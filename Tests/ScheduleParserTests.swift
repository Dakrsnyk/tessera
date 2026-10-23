import XCTest
@testable import Tessera

/// The text read from a photo or a PDF of a timetable, turned into classes. Pure logic: the lines are written
/// by hand with a place on the page (0...1, origin at the top left), so no image and no Vision are involved.
final class ScheduleParserTests: XCTestCase {

    // MARK: Helpers

    private func line(_ text: String, x: Double, y: Double, width: Double = 0.12) -> RecognizedLine {
        RecognizedLine(text: text, box: CGRect(x: x, y: y, width: width, height: 0.02))
    }

    /// A text centred on a column.
    private func cell(_ text: String, center: Double, y: Double) -> RecognizedLine {
        line(text, x: center - 0.06, y: y)
    }

    /// Lines stacked from top to bottom at the left: a day-by-day list.
    private func list(_ texts: [String]) -> [RecognizedLine] {
        texts.enumerated().map { index, text in
            line(text, x: 0.1, y: 0.05 + Double(index) * 0.04, width: 0.6)
        }
    }

    private func slot(_ slots: [ImportedSlot], day: Int, start: Int) -> ImportedSlot? {
        slots.first { $0.weekday == day && $0.startMinute == start }
    }

    // MARK: Grid with the days as columns

    func testARoomWrittenWithItsWordKeepsItsWholeCode() {
        let centers = [0.15, 0.33, 0.51, 0.69, 0.87]
        var lines: [RecognizedLine] = []
        for (index, name) in ["Lun", "Mar", "Mer", "Jeu", "Ven"].enumerated() {
            lines.append(cell(name, center: centers[index], y: 0.05))
        }
        lines += [cell("9h-10h", center: 0.15, y: 0.20), cell("Chimie", center: 0.15, y: 0.225), cell("Salle B-204", center: 0.15, y: 0.25)]
        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots.first?.title, "Chimie")
        XCTAssertEqual(slots.first?.room, "Salle B-204")
    }

    func testGridWithTimesInsideTheCells() {
        let centers = [0.15, 0.33, 0.51, 0.69, 0.87]
        var lines: [RecognizedLine] = []
        for (index, name) in ["Lun", "Mar", "Mer", "Jeu", "Ven"].enumerated() {
            lines.append(cell(name, center: centers[index], y: 0.05))
        }
        lines += [cell("8h30-10h", center: 0.15, y: 0.20), cell("Mathématiques", center: 0.15, y: 0.225), cell("B-204", center: 0.15, y: 0.25)]
        lines += [cell("10h15-11h45", center: 0.33, y: 0.20), cell("Physique", center: 0.33, y: 0.225), cell("Local 3.12", center: 0.33, y: 0.25)]
        lines += [cell("13h-14h30", center: 0.51, y: 0.50), cell("Anglais", center: 0.51, y: 0.525)]
        lines += [cell("8h-9h30", center: 0.87, y: 0.20), cell("Histoire", center: 0.87, y: 0.225)]

        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.count, 4)
        let monday = slot(slots, day: 1, start: 510)
        XCTAssertEqual(monday?.endMinute, 600)
        XCTAssertEqual(monday?.title, "Mathématiques")
        XCTAssertEqual(monday?.room, "B-204")
        let tuesday = slot(slots, day: 2, start: 615)
        XCTAssertEqual(tuesday?.endMinute, 705)
        XCTAssertEqual(tuesday?.title, "Physique")
        XCTAssertEqual(tuesday?.room, "Local 3.12")
        let wednesday = slot(slots, day: 3, start: 780)
        XCTAssertEqual(wednesday?.endMinute, 870)
        XCTAssertEqual(wednesday?.title, "Anglais")
        XCTAssertNil(wednesday?.room)
        let friday = slot(slots, day: 5, start: 480)
        XCTAssertEqual(friday?.endMinute, 570)
        XCTAssertEqual(friday?.title, "Histoire")
    }

    func testGridWithHoursInTheLeftMargin() {
        var lines: [RecognizedLine] = []
        for (index, name) in ["Mon", "Tue", "Wed"].enumerated() {
            lines.append(cell(name, center: [0.3, 0.5, 0.7][index], y: 0.05))
        }
        // Row labels: 8:00, 9:00, 10:00 at the heights 0.30, 0.40, 0.50.
        lines += [line("8:00", x: 0.02, y: 0.29, width: 0.06), line("9:00", x: 0.02, y: 0.39, width: 0.06), line("10:00", x: 0.02, y: 0.49, width: 0.06)]
        lines += [cell("Maths", center: 0.3, y: 0.305)]
        lines += [cell("Chimie", center: 0.5, y: 0.405), cell("B-12", center: 0.5, y: 0.43)]

        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.count, 2)
        let maths = slot(slots, day: 1, start: 480)
        XCTAssertEqual(maths?.title, "Maths")
        XCTAssertEqual(maths?.endMinute, 540, "No end written: one hour by default")
        let chemistry = slot(slots, day: 2, start: 540)
        XCTAssertEqual(chemistry?.title, "Chimie")
        XCTAssertEqual(chemistry?.room, "B-12")
        XCTAssertEqual(chemistry?.endMinute, 600)
    }

    func testEnglishGridWithAmPm() {
        var lines: [RecognizedLine] = []
        for (index, name) in ["Mon", "Tue", "Wed"].enumerated() {
            lines.append(cell(name, center: [0.3, 0.5, 0.7][index], y: 0.05))
        }
        lines += [cell("9:00 AM - 10:30 AM", center: 0.3, y: 0.20), cell("Psychology", center: 0.3, y: 0.225)]
        lines += [cell("1:00 PM - 2:30 PM", center: 0.5, y: 0.20), cell("Chemistry", center: 0.5, y: 0.225)]

        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slot(slots, day: 1, start: 540)?.endMinute, 630)
        XCTAssertEqual(slot(slots, day: 1, start: 540)?.title, "Psychology")
        XCTAssertEqual(slot(slots, day: 2, start: 780)?.endMinute, 870)
        XCTAssertEqual(slot(slots, day: 2, start: 780)?.title, "Chemistry")
    }

    func testGermanTwoLetterHeadersKeepDoAsThursday() {
        var lines: [RecognizedLine] = []
        let centers = [0.2, 0.35, 0.5, 0.65, 0.8]
        for (index, name) in ["Mo", "Di", "Mi", "Do", "Fr"].enumerated() {
            lines.append(cell(name, center: centers[index], y: 0.05))
        }
        lines += [cell("08:00 - 09:30", center: 0.2, y: 0.20), cell("Mathe", center: 0.2, y: 0.225)]
        lines += [cell("10:00 - 11:30", center: 0.65, y: 0.20), cell("Physik", center: 0.65, y: 0.225)]

        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slot(slots, day: 1, start: 480)?.title, "Mathe")
        XCTAssertEqual(slot(slots, day: 4, start: 600)?.title, "Physik")
        XCTAssertEqual(slot(slots, day: 4, start: 600)?.endMinute, 690)
    }

    // MARK: Day-by-day list

    func testFrenchList() {
        let slots = ScheduleParser.slots(from: list([
            "Emploi du temps", "Lundi", "8h30 - 10h Mathématiques B-204", "10h15 - 11h45 Physique",
            "Mardi", "13:00-14:30 Anglais", "Page 1 sur 1"
        ]))
        XCTAssertEqual(slots.count, 3)
        let maths = slot(slots, day: 1, start: 510)
        XCTAssertEqual(maths?.endMinute, 600)
        XCTAssertEqual(maths?.title, "Mathématiques")
        XCTAssertEqual(maths?.room, "B-204")
        XCTAssertEqual(slot(slots, day: 1, start: 615)?.title, "Physique")
        XCTAssertEqual(slot(slots, day: 2, start: 780)?.endMinute, 870)
        XCTAssertEqual(slot(slots, day: 2, start: 780)?.title, "Anglais")
    }

    func testTimeAndTitleOnTheSameRowButSeparateLines() {
        let lines = [
            line("Mercredi", x: 0.1, y: 0.10, width: 0.2),
            line("14h-15h30", x: 0.1, y: 0.20, width: 0.15),
            line("Chimie", x: 0.5, y: 0.20, width: 0.15)
        ]
        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots.first?.weekday, 3)
        XCTAssertEqual(slots.first?.startMinute, 840)
        XCTAssertEqual(slots.first?.endMinute, 930)
        XCTAssertEqual(slots.first?.title, "Chimie")
    }

    func testTitleOnTheLineAfterTheTimeAndRoomOnTheNext() {
        let slots = ScheduleParser.slots(from: list(["Jeudi", "9h-10h30", "Histoire", "Salle 12"]))
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots.first?.weekday, 4)
        XCTAssertEqual(slots.first?.title, "Histoire")
        XCTAssertEqual(slots.first?.room, "Salle 12")
    }

    func testSeveralDaysOnOneLine() {
        let some = ScheduleParser.slots(from: list(["Lun/Mer 8h-10h Maths"]))
        XCTAssertEqual(some.map { $0.weekday }, [1, 3])
        let range = ScheduleParser.slots(from: list(["Lun-Ven 9h-10h Stand-up"]))
        XCTAssertEqual(range.map { $0.weekday }, [1, 2, 3, 4, 5])
        XCTAssertEqual(range.first?.title, "Stand-up")
    }

    func testDayAndSlotOnTheSameLine() {
        let slots = ScheduleParser.slots(from: list(["Vendredi 15h-17h Chimie"]))
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots.first?.weekday, 5)
        XCTAssertEqual(slots.first?.startMinute, 900)
        XCTAssertEqual(slots.first?.endMinute, 1020)
    }

    // MARK: Hours

    func testTwelveHourClockAndTwentyFourHourClock() {
        let slots = ScheduleParser.slots(from: list([
            "Monday", "8:30 AM - 10:00 AM Calculus", "1:15 PM - 2:45 PM Biology", "Tuesday", "8:30-10 PM Yoga", "Wednesday", "14:00-15:30 Physics"
        ]))
        XCTAssertEqual(slots.count, 4)
        XCTAssertEqual(slot(slots, day: 1, start: 510)?.endMinute, 600)
        XCTAssertEqual(slot(slots, day: 1, start: 510)?.title, "Calculus")
        XCTAssertEqual(slot(slots, day: 1, start: 795)?.endMinute, 885)
        XCTAssertEqual(slot(slots, day: 2, start: 1230)?.endMinute, 1320, "8:30-10 PM reads as the evening")
        XCTAssertEqual(slot(slots, day: 3, start: 840)?.endMinute, 930)
    }

    func testHourRangeWithoutMinutes() {
        let slots = ScheduleParser.slots(from: list(["Lundi", "8h-9h30 Histoire", "08:30 – 10:00 Maths", "8 h - 9 h Sport"]))
        XCTAssertEqual(slot(slots, day: 1, start: 480)?.endMinute, 540, "8 h - 9 h Sport and 8h-9h30 start together")
        XCTAssertNotNil(slots.first { $0.title == "Histoire" && $0.endMinute == 570 })
        XCTAssertNotNil(slots.first { $0.title == "Maths" && $0.startMinute == 510 && $0.endMinute == 600 })
        XCTAssertNotNil(slots.first { $0.title == "Sport" && $0.endMinute == 540 })
    }

    func testAfternoonHoursWithoutPrefix() {
        let slots = ScheduleParser.slots(from: list(["Lundi", "1h30-3h Latin"]))
        XCTAssertEqual(slots.first?.startMinute, 13 * 60 + 30)
        XCTAssertEqual(slots.first?.endMinute, 15 * 60)
    }

    func testNoEndTimeUsesTheUsualLengthOfThePage() {
        let one = ScheduleParser.slots(from: list(["Lundi", "8h30 Maths"]))
        XCTAssertEqual(one.first?.endMinute, 570, "One hour when nothing else tells")
        let usual = ScheduleParser.slots(from: list(["Lundi", "8h30-10h Maths", "14h Chimie"]))
        XCTAssertEqual(slot(usual, day: 1, start: 840)?.endMinute, 930, "The page's lessons last 1 h 30")
    }

    func testGermanUhr() {
        let slots = ScheduleParser.slots(from: list([
            "Montag", "08:00 - 09:30 Mathematik Raum 101", "10:15 - 11:45 Informatik", "Mittwoch", "8-10 Uhr Physik"
        ]))
        XCTAssertEqual(slots.count, 3)
        let maths = slot(slots, day: 1, start: 480)
        XCTAssertEqual(maths?.endMinute, 570)
        XCTAssertEqual(maths?.title, "Mathematik")
        XCTAssertEqual(maths?.room, "Raum 101")
        XCTAssertEqual(slot(slots, day: 1, start: 615)?.title, "Informatik")
        XCTAssertEqual(slot(slots, day: 3, start: 480)?.endMinute, 600)
    }

    func testJapaneseDaysAndWideCharacters() {
        let slots = ScheduleParser.slots(from: list(["月曜日", "9：00～10：30 数学", "火曜日", "13:00-14:30 英語"]))
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slot(slots, day: 1, start: 540)?.endMinute, 630)
        XCTAssertEqual(slot(slots, day: 1, start: 540)?.title, "数学")
        XCTAssertEqual(slot(slots, day: 2, start: 780)?.title, "英語")
    }

    func testSpanishAndItalianDayNames() {
        let slots = ScheduleParser.slots(from: list(["Martes", "9:00-10:30 Historia", "Venerdì", "11:00-12:30 Matematica"]))
        XCTAssertEqual(slot(slots, day: 2, start: 540)?.title, "Historia")
        XCTAssertEqual(slot(slots, day: 5, start: 660)?.title, "Matematica")
    }

    // MARK: Cleaning and doubles

    func testDuplicatesAreRemoved() {
        let slots = ScheduleParser.slots(from: list(["Lundi", "8h-10h Maths", "8h-10h Maths"]))
        XCTAssertEqual(slots.count, 1)
        let id = UUID()
        let a = ImportedSlot(id: id, weekday: 1, startMinute: 480, endMinute: 540, title: "Maths", room: nil)
        let b = ImportedSlot(weekday: 1, startMinute: 480, endMinute: 540, title: "maths", room: "B-204")
        let merged = ScheduleParser.deduplicated([a, b])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.room, "B-204", "A copy that knows the room completes the other")
    }

    func testResultIsSortedByDayThenHour() {
        let slots = ScheduleParser.slots(from: list(["Mardi", "8h-9h Bio", "Lundi", "14h-15h Art", "8h-9h Chi"]))
        XCTAssertEqual(slots.map { $0.title }, ["Chi", "Art", "Bio"])
        XCTAssertEqual(slots.map { $0.weekday }, [1, 1, 2])
        XCTAssertEqual(slots.map { $0.startMinute }, [480, 840, 480])
    }

    func testNoiseIsIgnored() {
        let slots = ScheduleParser.slots(from: list([
            "Page 1 sur 3", "Généré le 12/10/2026 à 08:30", "Emploi du temps", "Lundi", "12", "8h-10h Maths", "©"
        ]))
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots.first?.title, "Maths")
        XCTAssertEqual(slots.first?.startMinute, 480)
    }

    func testBreaksAndTeachersAreNotClasses() {
        let slots = ScheduleParser.slots(from: list(["Lundi", "12h-13h Pause déjeuner", "13h-14h Prof. Tremblay"]))
        XCTAssertTrue(slots.isEmpty)
        let named = ScheduleParser.slots(from: list(["Lundi", "9h-10h", "Biologie", "Prof. Tremblay"]))
        XCTAssertEqual(named.count, 1)
        XCTAssertEqual(named.first?.title, "Biologie")
    }

    func testCourseTypesAreNotTakenForRooms() {
        let slots = ScheduleParser.slots(from: list(["Lundi", "9h-10h Chimie TD 12"]))
        XCTAssertEqual(slots.count, 1)
        XCTAssertNil(slots.first?.room)
        XCTAssertEqual(slots.first?.title, "Chimie TD 12")
    }

    func testMonHoraireIsNotMonday() {
        // "Mon horaire" starts with an English day name but names nothing.
        let slots = ScheduleParser.slots(from: list(["Mon horaire", "8h-10h Maths"]))
        XCTAssertTrue(slots.isEmpty, "No day known: the lesson cannot be placed")
    }

    // MARK: Nothing to find

    func testEmptyAndUnreadableInputGiveNothing() {
        XCTAssertTrue(ScheduleParser.slots(from: []).isEmpty)
        XCTAssertTrue(ScheduleParser.slots(from: [line("   ", x: 0.1, y: 0.1)]).isEmpty)
        XCTAssertTrue(ScheduleParser.slots(from: list(["Lorem ipsum dolor sit amet", "consectetur 2026", "8h"])).isEmpty)
        let odd = RecognizedLine(text: "Lundi 8h-10h Maths", box: CGRect(x: CGFloat.nan, y: CGFloat.infinity, width: -1, height: CGFloat.nan))
        XCTAssertTrue(ScheduleParser.slots(from: [odd]).isEmpty, "A box that is not a number is skipped, never a crash")
    }

    func testHourFormsAreNotConfusedWithRoomsOrDates() {
        XCTAssertNil(ScheduleParser.findTime(in: "Local 3.12"))
        XCTAssertNil(ScheduleParser.findTime(in: "B-204"))
        XCTAssertNil(ScheduleParser.findTime(in: "12/10/2026"))
        XCTAssertNil(ScheduleParser.findTime(in: "Chapitre 3 History"))
        XCTAssertEqual(ScheduleParser.findTime(in: "de 8h à 10h")?.start, 480)
        XCTAssertEqual(ScheduleParser.findTime(in: "de 8h à 10h")?.end, 600)
    }
}
