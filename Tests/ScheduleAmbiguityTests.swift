import XCTest
@testable import Ardane

/// What the reading of a timetable does with the confusions of the OCR (O for 0, l for 1, "Mardl" for "Mardi"), with the
/// free periods and the breaks, and with what it cannot know: every value that was corrected or guessed is listed in
/// `ImportedSlot.uncertain`, and nothing is invented (no class without a name that was read). The lines are written by
/// hand like Vision would give them; each test is the non-regression of one confusion.
final class ScheduleAmbiguityTests: XCTestCase {
    private typealias Fx = LayoutFixtures

    private func read(_ lines: [RecognizedLine]) -> [ImportedSlot] {
        ScheduleParser.slots(from: lines)
    }

    private func summary(_ lines: [RecognizedLine]) -> [String] {
        Fx.summary(read(lines))
    }

    // MARK: Look-alike letters in hours

    func testZeroReadAsLetterOInAnHourRange() {
        // "8h3O-1Oh": 8h30 to 10h.
        let slots = read(Fx.list(["Lundi", "8h3O-1Oh Maths"]))
        XCTAssertEqual(Fx.summary(slots), ["1|08:30-10:00|Maths|-"])
        XCTAssertEqual(slots.first?.uncertain, [.start, .end], "The hours were corrected: the person is shown them")
        XCTAssertEqual(slots.first?.needsCheck, true)
    }

    func testOneReadAsLowerCaseLAndZeroAsOInColonTimes() {
        // "l0:30-1l:45" is 10:30-11:45 and "O9:00-1O:30" is 09:00-10:30.
        let first = read(Fx.list(["Mardi", "l0:30-1l:45 Physique"]))
        XCTAssertEqual(Fx.summary(first), ["2|10:30-11:45|Physique|-"])
        XCTAssertEqual(first.first?.uncertain, [.start, .end])
        let second = read(Fx.list(["Mercredi", "O9:00-1O:30 Chimie"]))
        XCTAssertEqual(Fx.summary(second), ["3|09:00-10:30|Chimie|-"])
        XCTAssertEqual(second.first?.uncertain, [.start, .end])
    }

    func testAnHourWithTheMarkerAfterALookalikeStart() {
        // "1O h": 10 h, no end written: the end is a guess too.
        let slots = read(Fx.list(["Jeudi", "1O h Maths"]))
        XCTAssertEqual(Fx.summary(slots), ["4|10:00-11:00|Maths|-"])
        XCTAssertEqual(slots.first?.uncertain, [.start, .end])
    }

    func testLowerCaseLForOneBeforeTheMinutes() {
        // "1l:45": 11:45.
        let slots = read(Fx.list(["Vendredi", "1l:45 Latin"]))
        XCTAssertEqual(Fx.summary(slots), ["5|11:45-12:45|Latin|-"])
        XCTAssertTrue(slots.first?.uncertain.contains(.start) ?? false)
    }

    func testLookalikesInTwelveHourAndBareRanges() {
        let evening = ScheduleParser.findTime(in: "1O PM")
        XCTAssertEqual(evening?.start, 22 * 60)
        XCTAssertEqual(evening?.repaired, true)
        let bare = ScheduleParser.findTime(in: "O8-1O Maths")
        XCTAssertEqual(bare?.start, 8 * 60)
        XCTAssertEqual(bare?.end, 10 * 60)
        XCTAssertEqual(bare?.repaired, true)
        XCTAssertEqual(ScheduleParser.findTime(in: "l:45")?.start, 13 * 60 + 45, "A lone l before minutes is a one")
    }

    func testCleanHoursAreNotMarked() {
        let slots = read(Fx.list(["Lundi", "8h30-10h Maths"]))
        XCTAssertEqual(Fx.summary(slots), ["1|08:30-10:00|Maths|-"])
        XCTAssertTrue(slots.first?.uncertain.isEmpty ?? false)
        XCTAssertEqual(slots.first?.needsCheck, false)
    }

    func testTitlesAndWordsAreNotTurnedIntoHours() {
        XCTAssertNil(ScheduleParser.findTime(in: "Salle B-2O4"))
        XCTAssertNil(ScheduleParser.findTime(in: "Bob 8"))
        XCTAssertNil(ScheduleParser.findTime(in: "Oh"))
        XCTAssertNil(ScheduleParser.findTime(in: "SB:30"), "Two letters and no digit anchor are not an hour")
        XCTAssertNil(ScheduleParser.findTime(in: "B:30"), "A B is an 8 only next to a real digit")
        XCTAssertNil(ScheduleParser.repairedHours("Sociologie Bio"))
        let slots = read(Fx.list(["Lundi", "8h-9h Sociologie B-12"]))
        XCTAssertEqual(Fx.summary(slots), ["1|08:00-09:00|Sociologie|B-12"])
        XCTAssertTrue(slots.first?.uncertain.isEmpty ?? false)
    }

    func testMarginLabelsWithLookalikesStillMakeTheRows() {
        XCTAssertEqual(ScheduleParser.clockMinute("O8:1O"), 8 * 60 + 10)
        XCTAssertEqual(ScheduleParser.clockPair("O8:10 O9:OO")?.second, 9 * 60)
        XCTAssertNil(ScheduleParser.clockMinute("25:00"))
        XCTAssertNil(ScheduleParser.clockMinute("12/10/2026"))
    }

    // MARK: Look-alike letters in rooms

    func testRoomWithAnOForAZeroIsReadAndMarked() {
        let withWord = read(Fx.list(["Lundi", "9h-10h Chimie Salle B-2O4"]))
        XCTAssertEqual(Fx.summary(withWord), ["1|09:00-10:00|Chimie|Salle B-204"])
        XCTAssertEqual(withWord.first?.uncertain, [.room])
        // Without the word, "B-2O4" was not even a room: it stayed in the title.
        let bare = read(Fx.list(["Lundi", "9h-10h Chimie B-2O4"]))
        XCTAssertEqual(Fx.summary(bare), ["1|09:00-10:00|Chimie|B-204"])
        XCTAssertEqual(bare.first?.uncertain, [.room])
    }

    func testRoomRepairOnlyInsideTheNumber() {
        let fixed = ScheduleParser.repairedRoomWords(in: "Local H3O46")
        XCTAssertEqual(fixed.text, "Local H3046")
        XCTAssertEqual(fixed.tokens, ["H3046"])
        XCTAssertTrue(ScheduleParser.repairedRoomWords(in: "Salle B204").tokens.isEmpty)
        XCTAssertTrue(ScheduleParser.repairedRoomWords(in: "BIO BO4 Local").tokens.isEmpty, "Words are left alone")
        XCTAssertEqual(ScheduleParser.repairedRoomWords(in: "Biologie").text, "Biologie")
    }

    func testOmnivoxRoomWithAnOIsMarked() {
        let box = CGRect(x: 0, y: 0, width: 0.1, height: 0.01)
        let lines = ["Marketing", "410-343-CH gr.41070", "Local H3O46", "Benoît Rochefort", "Présentiel"].map {
            RecognizedLine(text: $0, box: box)
        }
        let content = ScheduleParser.blockContent(lines)
        XCTAssertEqual(content?.title, "Marketing")
        XCTAssertEqual(content?.room, "Local H3046")
        XCTAssertEqual(content?.roomRepaired, true)
        let clean = ScheduleParser.blockContent(["Marketing", "410-343-CH gr.41070", "Local F5107"].map { RecognizedLine(text: $0, box: box) })
        XCTAssertEqual(clean?.roomRepaired, false)
    }

    func testCourseCodeWithALookalikeInItsDigits() {
        XCTAssertEqual(ScheduleParser.courseCode(in: "41O-343-CH gr.41070")?.code, "410-343-CH")
        XCTAssertEqual(ScheduleParser.courseCode(in: "410-343-CH")?.code, "410-343-CH")
        XCTAssertNil(ScheduleParser.courseCode(in: "OOO-ABC-DE"), "No real digit: not a code")
    }

    /// An Omnivox page without the colours of the image: the hours come from the middle of the text, which is a guess.
    func testOmnivoxHoursFromTheMiddleOfTheTextAreMarked() {
        var lines: [RecognizedLine] = []
        for (index, name) in ["Lundi", "Mardi", "Mercredi"].enumerated() {
            lines.append(Fx.line(name, [0.35, 0.55, 0.75][index], 0.10, 0.12, 0.01))
        }
        // Three rows of two hours each (08:10-09:00, 09:05-09:55, 10:05-10:55), centred at 0.25, 0.35, 0.45.
        for (index, pair) in [("08:10", "09:00"), ("09:05", "09:55"), ("10:05", "10:55")].enumerated() {
            let centre = 0.25 + 0.10 * Double(index)
            lines.append(Fx.line(pair.0, 0.10, centre - 0.02, 0.06, 0.01))
            lines.append(Fx.line(pair.1, 0.10, centre + 0.02, 0.06, 0.01))
        }
        // A block of two rows (08:10-09:55) on Monday.
        for (index, text) in ["Gestion info", "410-243-CH gr.41060", "Local H3O46", "Présentiel"].enumerated() {
            lines.append(Fx.line(text, 0.35, 0.27 + 0.02 * Double(index), 0.12, 0.012))
        }
        let slots = read(lines)
        XCTAssertEqual(Fx.summary(slots), ["1|08:10-09:55|Gestion info|Local H3046"])
        XCTAssertEqual(slots.first?.uncertain, [.start, .end, .room])
        XCTAssertEqual(slots.first?.needsCheck, true)
    }

    // MARK: Day names read with a wrong letter

    func testDayNamesWithOneWrongLetterAreMatchedAndMarked() {
        let cases: [(String, Int)] = [("Lur", 1), ("Mardl", 2), ("Mercredl", 3), ("Jeud1", 4), ("Vendred1", 5), ("Man", 1)]
        for (word, day) in cases {
            let match = ScheduleParser.dayMatch(word)
            XCTAssertEqual(match?.day, day, word)
            XCTAssertEqual(match?.fuzzy, true, word)
        }
        XCTAssertEqual(ScheduleParser.dayMatch("Mardi")?.fuzzy, false)
        XCTAssertEqual(ScheduleParser.dayMatch("Mon")?.day, 1)
        XCTAssertEqual(ScheduleParser.dayMatch("Mon")?.fuzzy, false)
    }

    func testOrdinaryWordsAreNeverTakenForDays() {
        for word in ["Mars", "Maths", "Mes", "Jeux", "Lu", "Salle", "Fin", "Début", "Jour", "Mai"] {
            XCTAssertNotEqual(ScheduleParser.dayMatch(word)?.fuzzy, true, word)
        }
        // "Lu" and "Mai" are not days here at all; two letters are never matched by resemblance.
        XCTAssertNil(ScheduleParser.fuzzyDay("Lu"))
        XCTAssertNil(ScheduleParser.fuzzyDay("Mars"))
        XCTAssertNil(ScheduleParser.fuzzyDay("Mai"))
        XCTAssertNil(ScheduleParser.fuzzyDay("Jeux"))
    }

    func testListWithAMisreadDayKeepsItsClassesAndMarksTheDay() {
        let slots = read(Fx.list(["Mardl", "8h-9h30 Histoire", "Jeud1", "13h-14h Art"]))
        XCTAssertEqual(Fx.summary(slots), ["2|08:00-09:30|Histoire|-", "4|13:00-14:00|Art|-"])
        XCTAssertTrue(slots.allSatisfy { $0.uncertain.contains(.day) })
        let clear = read(Fx.list(["Mardi", "8h-9h30 Histoire"]))
        XCTAssertFalse(clear.first?.uncertain.contains(.day) ?? true)
    }

    private func schoolPage(header: [String]) -> [RecognizedLine] {
        var lines = Fx.schoolHeader(header) + Fx.marginLabels(Fx.periodLabels)
        lines += Fx.cell(0, 0, "Maths", "B12") + Fx.cell(1, 0, "Français", "C30") + Fx.cell(0, 1, "Histoire", "A10")
        lines += Fx.cell(4, 2, "Chimie", "Lab 2") + Fx.cell(2, 4, "Sport") + Fx.cell(3, 5, "Art")
        return lines
    }

    func testGridWhoseHeaderIsMisreadStillGivesEveryClassOnItsDay() {
        let slots = read(schoolPage(header: ["Lur", "Mardl", "Mercredl", "Jeud1", "Vendred1"]))
        XCTAssertEqual(Fx.summary(slots), Fx.schoolExpected)
        XCTAssertTrue(slots.allSatisfy { $0.uncertain.contains(.day) }, "Every day name was matched by resemblance")
        XCTAssertTrue(slots.allSatisfy { $0.needsCheck })
        // A clean header marks nothing.
        let clean = read(schoolPage(header: ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]))
        XCTAssertEqual(Fx.summary(clean), Fx.schoolExpected)
        XCTAssertTrue(clean.allSatisfy { !$0.uncertain.contains(.day) })
    }

    func testAMisreadNameThatLooksLikeADayAlreadyTakenIsTheOtherDay() {
        // "Man" could be Mon or Mar; Monday is already "Lun", so it is Tuesday.
        let slots = read(schoolPage(header: ["Lun", "Man", "Mer", "Jeu", "Ven"]))
        XCTAssertEqual(Fx.summary(slots), Fx.schoolExpected)
        XCTAssertEqual(slots.first { $0.title == "Français" }?.uncertain.contains(.day), true)
        XCTAssertEqual(slots.first { $0.title == "Maths" }?.uncertain.contains(.day), false)
    }

    // MARK: Courses, free periods, breaks and holes

    func testFreePeriodsBreaksAndEmptyCellsAreNotClasses() {
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]) + Fx.marginLabels(Fx.periodLabels)
        lines += Fx.cell(0, 0, "Maths", "B12") + Fx.cell(1, 0, "Libre") + Fx.cell(2, 0, "Pause") + Fx.cell(3, 0, "—") + Fx.cell(4, 0, "X")
        lines += Fx.cell(0, 1, "Study hall") + Fx.cell(1, 1, "Free period") + Fx.cell(2, 1, "Période libre")
        lines += Fx.cell(3, 1, "Déjeuner") + Fx.cell(4, 1, "Histoire", "A10")
        lines += Fx.cell(0, 2, "Lunch") + Fx.cell(1, 2, "Récréation") + Fx.cell(2, 2, "N/A") + Fx.cell(3, 2, "Break")
        XCTAssertEqual(summary(lines), ["1|08:00-09:00|Maths|B12", "5|09:00-10:00|Histoire|A10"])
    }

    func testFreeSlotsWrittenAsListLinesAreNotClasses() {
        XCTAssertEqual(summary(Fx.list(["Lundi", "9h-10h Libre", "10h-11h Free period", "11h-12h Maths"])), ["1|11:00-12:00|Maths|-"])
    }

    func testSeveralRoomsOnOneLineAreAllKept() {
        XCTAssertEqual(summary(Fx.list(["Monday", "8:00 - 10:00 Organic Chemistry B-204 / C-110"])),
                       ["1|08:00-10:00|Organic Chemistry|B-204 / C-110"])
        let found = ScheduleParser.extractRoom(from: "Seminar A-101 / A-102")
        XCTAssertEqual(found.room, "A-101 / A-102")
        XCTAssertEqual(found.text.trimmingCharacters(in: .whitespaces), "Seminar")
        XCTAssertEqual(ScheduleParser.extractRoom(from: "Maths B-204").room, "B-204")
        XCTAssertEqual(ScheduleParser.extractRoom(from: "Maths B-204 / Physique").room, "B-204")
    }

    func testAFreeWordInsideARealTitleKeepsTheClass() {
        XCTAssertEqual(summary(Fx.list(["Lundi", "8h-10h Free Software", "10h15-11h45 Libre expression"])),
                       ["1|08:00-10:00|Free Software|-", "1|10:15-11:45|Libre expression|-"])
        XCTAssertFalse(ScheduleParser.isNonCourse("Étude de cas", coded: false))
    }

    func testACodeMakesAStudyHallOrADinnerACourse() {
        func draft(_ title: String, coded: Bool) -> ScheduleParser.Draft {
            ScheduleParser.Draft(weekday: 1, start: 12 * 60, end: 13 * 60, title: title, room: nil, coded: coded)
        }
        XCTAssertEqual(ScheduleParser.finalize([draft("Dîner de gala", coded: true)]).map { $0.title }, ["Dîner de gala"])
        XCTAssertTrue(ScheduleParser.finalize([draft("Dîner de gala", coded: false)]).isEmpty)
        XCTAssertEqual(ScheduleParser.finalize([draft("Study hall", coded: true)]).map { $0.title }, ["Study hall"])
        XCTAssertTrue(ScheduleParser.finalize([draft("Study hall", coded: false)]).isEmpty)
        XCTAssertTrue(ScheduleParser.finalize([draft("N/A", coded: true)]).isEmpty, "An empty mark is never a course")
    }

    func testAHoleBetweenTwoClassesIsNeverAClassAndStopsTheClassBefore() {
        let slots = read(Fx.list(["Lundi", "8h30 Maths", "9h Pause", "10h Physique"]))
        XCTAssertEqual(Fx.summary(slots), ["1|08:30-09:00|Maths|-", "1|10:00-11:00|Physique|-"])
        XCTAssertTrue(slots.allSatisfy { $0.uncertain.contains(.end) }, "Only a start was written: the end is a guess")
    }

    // MARK: Nothing is invented

    func testNoClassIsMadeWithoutAReadName() {
        // A time alone, a time and symbols, a time and numbers, a time and a name made of digits: nothing.
        XCTAssertTrue(read(Fx.list(["Lundi", "8h-10h", "10h15-11h45 ???", "13h-14h 12 34", "15h-16h 1234 5678 ab"])).isEmpty)
        XCTAssertTrue(ScheduleParser.slots(from: Fx.list(["Lundi", "8h-10h Maths"])).allSatisfy { !$0.title.isEmpty })
    }

    func testAnEndGuessedFromTheUsualLengthIsMarkedAndAWrittenEndIsNot() {
        let guessed = read(Fx.list(["Lundi", "8h30 Maths"]))
        XCTAssertEqual(guessed.first?.uncertain, [.end])
        XCTAssertEqual(guessed.first?.needsCheck, true)
        let written = read(Fx.list(["Lundi", "8h30-10h Maths"]))
        XCTAssertEqual(written.first?.uncertain, [])
        XCTAssertEqual(written.first?.needsCheck, false)
    }

    func testTwoReadingsOfTheSameClassAreInDoubtOnlyWhereBothAre() {
        let doubtful = ImportedSlot(weekday: 1, startMinute: 480, endMinute: 540, title: "Maths", uncertain: [.end, .room])
        let sure = ImportedSlot(weekday: 1, startMinute: 480, endMinute: 540, title: "Maths", room: "B-12")
        let merged = ScheduleParser.deduplicated([doubtful, sure])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.uncertain, [], "A clean reading of the same class settles the fields")
        let both = ScheduleParser.deduplicated([doubtful, doubtful])
        XCTAssertEqual(both.first?.uncertain, [.end, .room])
    }

    func testTheSlotFieldsDefaultToNothingInDoubt() {
        XCTAssertTrue(ImportedSlot(weekday: 1, startMinute: 480, endMinute: 540, title: "Maths").uncertain.isEmpty)
        XCTAssertEqual(Set<SlotField>([.day, .start, .end, .title, .room]).count, 5)
        XCTAssertEqual(SlotField(rawValue: "room"), .room)
    }
}
