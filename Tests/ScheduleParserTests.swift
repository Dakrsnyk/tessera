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

    // MARK: Omnivox timetables (three real screenshots)

    /// A block of the grid: its column (0 = Monday), the rows it covers (0 = 08:10, 9 = 16:50) and its lines of text.
    private struct ShotBlock {
        var column: Int
        var first: Int
        var last: Int
        var lines: [String]
    }

    /// A line of the "Liste des cours" of the page.
    private struct ShotCourse {
        var code: String
        var group: String
        var title: String
        var teacher: String
    }

    /// Plays the probe over a screenshot: the white stretches of each column, in 0...1 of the page height.
    private struct FakeProbe: BlockProbe {
        var runs: [[ClosedRange<Double>]]
        var edges: [Double]
        var available: Bool

        func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
            guard available else { return nil }
            guard let column = (0..<runs.count).first(where: { x >= edges[$0] && x < edges[$0 + 1] }) else { return [] }
            var result: [ClosedRange<Double>] = []
            for run in runs[column] {
                let low = max(run.lowerBound, fromY)
                let high = min(run.upperBound, toY)
                if low < high { result.append(low...high) }
            }
            return result
        }
    }

    /// An Omnivox screenshot as the iPhone showed it (924 x 2000 points), written from the picture: the lines of
    /// text with their real height on the page, as Vision would return them. The two hours of a row are centred in
    /// it, a block is white and holds 5 or 6 centred lines, the empty cells are grey.
    private struct Shot {
        static let width = 924.0
        static let height = 2000.0
        static let centers = [277.0, 386.0, 494.0, 602.0, 710.0]
        static let days = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]
        static let hours = [("08:10", "09:00"), ("09:05", "09:55"), ("10:05", "10:55"), ("11:00", "11:50"), ("12:00", "12:50"),
                            ("13:00", "13:50"), ("14:00", "14:50"), ("15:00", "15:50"), ("15:55", "16:45"), ("16:50", "17:40")]

        var headerY: Double
        /// The 11 edges of the 10 rows, in points from the top of the screenshot.
        var rows: [Double]
        var listY: Double
        var courses: [ShotCourse]
        var blocks: [ShotBlock]

        func line(_ text: String, x: Double, y: Double, width: Double? = nil) -> RecognizedLine {
            let w = width ?? min(100, Double(text.count) * 4.6)
            return RecognizedLine(text: text, box: CGRect(x: (x - w / 2) / Shot.width, y: (y - 5) / Shot.height,
                                                          width: w / Shot.width, height: 10 / Shot.height))
        }

        func lines() -> [RecognizedLine] {
            var result: [RecognizedLine] = []
            result.append(line("Horaire de cours", x: 462, y: 237))
            result.append(line("Cliquez ici pour une", x: 233, y: 312, width: 140))
            result.append(line("Informations personnelles", x: 288, y: 395, width: 260))
            result.append(line("Nom, Prénom", x: 198, y: 419))
            result.append(line("Cugnet, Léa", x: 415, y: 419))
            result.append(line("No étudiant", x: 198, y: 438))
            result.append(line("2230667", x: 426, y: 438))
            result.append(line("Programme", x: 193, y: 457))
            result.append(line("410.B0", x: 428, y: 457))
            result.append(line("Généré le", x: 500, y: 457))
            result.append(line("11-jan-2023 16:26", x: 712, y: 457))
            result.append(line("Liste des cours", x: 234, y: listY - 20, width: 150))
            result.append(line("Date d' annulation maximum", x: 229, y: listY, width: 140))
            result.append(line("Numéro", x: 333, y: listY, width: 40))
            result.append(line("Titre du cours", x: 442, y: listY, width: 70))
            for (index, course) in courses.enumerated() {
                let y = listY + 15.5 * Double(index + 1)
                result.append(line("19-sep", x: 172, y: y, width: 30))
                result.append(line(course.code, x: 338, y: y, width: 50))
                result.append(line(course.group, x: 387, y: y, width: 26))
                let titleWidth = Double(course.title.count) * 4.2
                result.append(line(course.title, x: 408 + titleWidth / 2, y: y, width: titleWidth))
                result.append(line(course.teacher, x: 700, y: y, width: 70))
            }
            result.append(line("Horaire de cours pour la session", x: 320, y: headerY - 77, width: 320))
            result.append(line("Afficher mon horaire par semaine", x: 283, y: headerY - 39, width: 200))
            for (index, name) in Shot.days.enumerated() {
                result.append(line(name, x: Shot.centers[index], y: headerY, width: 40))
            }
            for (index, pair) in Shot.hours.enumerated() {
                let middle = (rows[index] + rows[index + 1]) / 2
                result.append(line(pair.0, x: 194, y: middle - 13, width: 28))
                result.append(line(pair.1, x: 194, y: middle + 13, width: 28))
            }
            for block in blocks {
                let middle = (rows[block.first] + rows[block.last + 1]) / 2
                for (index, text) in block.lines.enumerated() {
                    let y = middle + (Double(index) - Double(block.lines.count - 1) / 2) * 13
                    result.append(line(text, x: Shot.centers[block.column], y: y))
                }
            }
            let bottom = rows[rows.count - 1]
            result.append(line("Accès à Omnivox", x: 244, y: bottom + 64, width: 170))
            result.append(line("Tout au long de la session, vous pouvez accéder à Omnivox à l'adresse https://cchic.omnivox.ca",
                               x: 360, y: bottom + 82, width: 400))
            result.append(line("Retourner au choix de la session", x: 200, y: bottom + 146, width: 190))
            return result
        }

        func probe(available: Bool = true) -> FakeProbe {
            var columns = [[ClosedRange<Double>]](repeating: [], count: 5)
            for block in blocks.sorted(by: { $0.first < $1.first }) {
                let low = rows[block.first] / Shot.height
                let high = rows[block.last + 1] / Shot.height
                if let previous = columns[block.column].last, low - previous.upperBound <= 1 / Shot.height {
                    columns[block.column][columns[block.column].count - 1] = previous.lowerBound...high
                } else {
                    columns[block.column].append(low...high)
                }
            }
            let edges = [223.0, 331.0, 439.0, 547.0, 655.0, 763.0].map { $0 / Shot.width }
            return FakeProbe(runs: columns, edges: edges, available: available)
        }
    }

    /// A block as written in the grid: the (cut) title, the code with its group, the room, the teacher and the mode.
    private func block(_ column: Int, _ first: Int, _ last: Int, _ title: [String], _ code: String, _ room: String,
                       _ teacher: String) -> ShotBlock {
        ShotBlock(column: column, first: first, last: last, lines: title + [code, room, teacher, "Présentiel"])
    }

    /// Capture 1: winter 2023.
    private func winterShot(withCourses: Bool = true) -> Shot {
        let courses = [
            ShotCourse(code: "201-253-CH", group: "21050", title: "Mathématiques appliquées à la comptabilité et à la gestion", teacher: "Michaël Harvey"),
            ShotCourse(code: "410-242-CH", group: "41040", title: "Comptabilité II", teacher: "Manon Lapointe"),
            ShotCourse(code: "410-243-CH", group: "41060", title: "Gestion informatisée: Access et Powerpoint", teacher: "Annie L'heureux"),
            ShotCourse(code: "410-343-CH", group: "41070", title: "Marketing et communication", teacher: "Benoît Rochefort")
        ]
        let maths = ["Mathématiques appliq"]
        let marketing = ["Marketing et", "communication"]
        let management = ["Gestion informatisée"]
        let accounting = ["Comptabilité II"]
        let blocks = [
            block(0, 2, 3, management, "410-243-CH gr.41060", "Local F5101", "Annie L'heureux"),
            block(1, 0, 1, marketing, "410-343-CH gr.41070", "Local F5107", "Benoît Rochefort"),
            block(1, 2, 3, maths, "201-253-CH gr.21050", "Local H3046", "Michaël Harvey"),
            block(2, 5, 6, accounting, "410-242-CH gr.41040", "Local F5111", "Manon Lapointe"),
            block(3, 3, 3, maths, "201-253-CH gr.21050", "Local H3040", "Michaël Harvey"),
            block(3, 6, 7, management, "410-243-CH gr.41060", "Local F5101", "Annie L'heureux"),
            block(4, 0, 1, accounting, "410-242-CH gr.41040", "Local F5111", "Manon Lapointe"),
            block(4, 2, 3, maths, "201-253-CH gr.21050", "Local H3036", "Michaël Harvey"),
            block(4, 7, 8, marketing, "410-343-CH gr.41070", "Local F5111", "Benoît Rochefort")
        ]
        return Shot(headerY: 763, rows: [773, 815, 858, 900, 969, 1011, 1054, 1096, 1139, 1181, 1223], listY: 570,
                    courses: withCourses ? courses : [], blocks: blocks)
    }

    private let winterExpected = [
        "1|10:05-11:50|Gestion informatisée: Access et Powerpoint|Local F5101",
        "2|08:10-09:55|Marketing et communication|Local F5107",
        "2|10:05-11:50|Mathématiques appliquées à la comptabilité et à la gestion|Local H3046",
        "3|13:00-14:50|Comptabilité II|Local F5111",
        "4|11:00-11:50|Mathématiques appliquées à la comptabilité et à la gestion|Local H3040",
        "4|14:00-15:50|Gestion informatisée: Access et Powerpoint|Local F5101",
        "5|08:10-09:55|Comptabilité II|Local F5111",
        "5|10:05-11:50|Mathématiques appliquées à la comptabilité et à la gestion|Local H3036",
        "5|15:00-16:45|Marketing et communication|Local F5111"
    ]

    /// Capture 2: autumn 2023, three courses.
    private func autumnShot() -> Shot {
        let courses = [
            ShotCourse(code: "201-BSB-05", group: "21210", title: "Complément de calcul différentiel et intégral", teacher: "Michaël Harvey"),
            ShotCourse(code: "203-NYB-05", group: "03090", title: "Électricité et magnétisme", teacher: "Josiane Moisan"),
            ShotCourse(code: "604-BTF-CH", group: "64100", title: "Anglais du préuniversitaire, ensemble transitoire", teacher: "Suzie Simard")
        ]
        let calculus = ["Complément de calcul"]
        let electricity = ["Électricité et magné"]
        let blocks = [
            block(0, 1, 3, ["Anglais du préuniver"], "604-BTF-CH gr.64100", "Local C3021", "Suzie Simard"),
            block(1, 2, 3, electricity, "203-NYB-05 gr.03090", "Local H3077", "Josiane Moisan"),
            block(1, 5, 5, calculus, "201-BSB-05 gr.21210", "Local H3026", "Michaël Harvey"),
            block(2, 1, 1, electricity, "203-NYB-05 gr.03090", "Local H3077", "Josiane Moisan"),
            block(2, 7, 8, calculus, "201-BSB-05 gr.21210", "Local H3034", "Michaël Harvey"),
            block(4, 2, 3, calculus, "201-BSB-05 gr.21210", "Local H3018;H3040", "Michaël Harvey"),
            block(4, 5, 6, electricity, "203-NYB-05 gr.03090", "Local H3077", "Josiane Moisan")
        ]
        return Shot(headerY: 749, rows: [759, 802, 870, 914, 955, 998, 1066, 1110, 1151, 1194, 1237], listY: 572,
                    courses: courses, blocks: blocks)
    }

    private let autumnExpected = [
        "1|09:05-11:50|Anglais du préuniversitaire, ensemble transitoire|Local C3021",
        "2|10:05-11:50|Électricité et magnétisme|Local H3077",
        "2|13:00-13:50|Complément de calcul différentiel et intégral|Local H3026",
        "3|09:05-09:55|Électricité et magnétisme|Local H3077",
        "3|15:00-16:45|Complément de calcul différentiel et intégral|Local H3034",
        "5|10:05-11:50|Complément de calcul différentiel et intégral|Local H3018;H3040",
        "5|13:00-14:50|Électricité et magnétisme|Local H3077"
    ]

    /// Capture 3: autumn 2023, six courses, blocks stuck together in Wednesday.
    private func businessShot() -> Shot {
        let courses = [
            ShotCourse(code: "410-234-CH", group: "41070", title: "Initiation au droit des affaires", teacher: "Marie-Eve Tremblay"),
            ShotCourse(code: "410-342-CH", group: "41190", title: "Comptabilité III", teacher: "Manon Lapointe"),
            ShotCourse(code: "410-344-CH", group: "41200", title: "Finance I", teacher: "Annie L'heureux"),
            ShotCourse(code: "410-345-CH", group: "41060", title: "Gestion des ressources humaines", teacher: "Marc Privé"),
            ShotCourse(code: "410-435-CH", group: "41080", title: "La gestion de l'information", teacher: "Rémi Côté"),
            ShotCourse(code: "604-101-MQ", group: "64000", title: "Langue anglaise et communication", teacher: "Guillaume Rousseau")
        ]
        let resources = ["Gestion des ressourc"]
        let information = ["La gestion de l'info"]
        let finance = ["Finance I"]
        let law = ["Initiation au droit"]
        let accounting = ["Comptabilité III"]
        let blocks = [
            block(0, 0, 1, resources, "410-345-CH gr.41060", "Local F5107", "Marc Privé"),
            block(0, 5, 7, ["Langue anglaise et c"], "604-101-MQ gr.64000", "Local C3017", "Guillaume Rousseau"),
            block(1, 0, 1, information, "410-435-CH gr.41080", "Local F5111", "Rémi Côté"),
            block(1, 5, 6, finance, "410-344-CH gr.41200", "Local C3017", "Annie L'heureux"),
            block(2, 1, 1, law, "410-234-CH gr.41070", "Local F5107", "Marie-Eve Tremblay"),
            block(2, 2, 3, accounting, "410-342-CH gr.41190", "Local F5109", "Manon Lapointe"),
            block(2, 5, 6, resources, "410-345-CH gr.41060", "Local F5107", "Marc Privé"),
            block(3, 0, 1, finance, "410-344-CH gr.41200", "Local C3017", "Annie L'heureux"),
            block(3, 8, 8, information, "410-435-CH gr.41080", "Local F5111", "Rémi Côté"),
            block(4, 2, 3, accounting, "410-342-CH gr.41190", "Local F5111", "Manon Lapointe"),
            block(4, 5, 6, law, "410-234-CH gr.41070", "Local F5107", "Marie-Eve Tremblay")
        ]
        return Shot(headerY: 793, rows: [803, 845, 915, 956, 1000, 1043, 1083, 1126, 1168, 1238, 1280], listY: 570,
                    courses: courses, blocks: blocks)
    }

    private let businessExpected = [
        "1|08:10-09:55|Gestion des ressources humaines|Local F5107",
        "1|13:00-15:50|Langue anglaise et communication|Local C3017",
        "2|08:10-09:55|La gestion de l'information|Local F5111",
        "2|13:00-14:50|Finance I|Local C3017",
        "3|09:05-09:55|Initiation au droit des affaires|Local F5107",
        "3|10:05-11:50|Comptabilité III|Local F5109",
        "3|13:00-14:50|Gestion des ressources humaines|Local F5107",
        "4|08:10-09:55|Finance I|Local C3017",
        "4|15:55-16:45|La gestion de l'information|Local F5111",
        "5|10:05-11:50|Comptabilité III|Local F5111",
        "5|13:00-14:50|Initiation au droit des affaires|Local F5107"
    ]

    private func hm(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    /// Day, hours, title and room of each class, one line each.
    private func summary(_ slots: [ImportedSlot]) -> [String] {
        slots.map { "\($0.weekday)|\(hm($0.startMinute))-\(hm($0.endMinute))|\($0.title)|\($0.room ?? "-")" }
    }

    func testOmnivoxWinterCaptureTakesTheHoursFromTheBlocks() {
        let shot = winterShot()
        XCTAssertEqual(summary(ScheduleParser.slots(from: shot.lines(), probe: shot.probe())), winterExpected)
    }

    func testOmnivoxAutumnCaptureWithABlockOverThreeRows() {
        let shot = autumnShot()
        XCTAssertEqual(summary(ScheduleParser.slots(from: shot.lines(), probe: shot.probe())), autumnExpected)
    }

    func testOmnivoxBusinessCaptureWithBlocksStuckTogether() {
        let shot = businessShot()
        XCTAssertEqual(summary(ScheduleParser.slots(from: shot.lines(), probe: shot.probe())), businessExpected)
    }

    func testOmnivoxWithoutAProbeTheTextCentreFitsTheRows() {
        XCTAssertEqual(summary(ScheduleParser.slots(from: winterShot().lines())), winterExpected)
        XCTAssertEqual(summary(ScheduleParser.slots(from: autumnShot().lines())), autumnExpected)
        XCTAssertEqual(summary(ScheduleParser.slots(from: businessShot().lines())), businessExpected)
    }

    func testOmnivoxProbeThatCannotTellBlocksFromEmptyCellsFallsBackToTheText() {
        let shots = [(winterShot(), winterExpected), (autumnShot(), autumnExpected), (businessShot(), businessExpected)]
        for (shot, expected) in shots {
            XCTAssertEqual(summary(ScheduleParser.slots(from: shot.lines(), probe: shot.probe(available: false))), expected)
        }
    }

    func testOmnivoxWithoutTheListOfCoursesTheCutTitleIsKept() {
        let shot = winterShot(withCourses: false)
        let slots = ScheduleParser.slots(from: shot.lines(), probe: shot.probe())
        XCTAssertEqual(slots.count, 9)
        XCTAssertEqual(slots.first?.title, "Gestion informatisée")
        XCTAssertEqual(slot(slots, day: 2, start: 490)?.title, "Marketing et communication")
        XCTAssertEqual(slot(slots, day: 2, start: 605)?.title, "Mathématiques appliq")
    }

    func testOmnivoxGridWithNoClassGivesNothing() {
        // The list of courses, the personal data and "Accès à Omnivox" must never become classes.
        var shot = winterShot()
        shot.blocks = []
        XCTAssertTrue(ScheduleParser.slots(from: shot.lines(), probe: shot.probe()).isEmpty)
        XCTAssertTrue(ScheduleParser.slots(from: shot.lines()).isEmpty)
    }

    func testAListOfHoursInTheMarginIsNotTakenForPairsOfRows() {
        var lines: [RecognizedLine] = []
        for (index, name) in ["Mon", "Tue", "Wed"].enumerated() {
            lines.append(cell(name, center: [0.3, 0.5, 0.7][index], y: 0.05))
        }
        lines += [line("8:00", x: 0.02, y: 0.29, width: 0.06), line("9:00", x: 0.02, y: 0.39, width: 0.06),
                  line("10:00", x: 0.02, y: 0.49, width: 0.06), line("11:00", x: 0.02, y: 0.59, width: 0.06)]
        lines += [cell("Maths", center: 0.3, y: 0.305)]
        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slot(slots, day: 1, start: 480)?.title, "Maths")
    }
}
