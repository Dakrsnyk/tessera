import XCTest
@testable import Ardane

/// Documents that are not timetables of classes: work schedules (a list of shifts, a roster of employees by days), dated
/// appointments (in French and in English with a 12-hour clock), a timetable with appointments, a page with a heading, a
/// footer and text at its edges, and the readings in doubt (a date or an hour that cannot be read, an ambiguous hour, a
/// date whose day and month could be swapped, a day name that does not match its date). The lines are written by hand the
/// way Vision would give them; every name is invented. The answers were checked by hand (24 November 2026 is a Tuesday).
final class ScheduleDocumentTypesTests: XCTestCase {
    private typealias Fx = LayoutFixtures

    // MARK: Helpers

    /// "2026-11-24" in the calendar of the device, the one the importer uses.
    private func dayText(_ date: Date?) -> String {
        guard let date else { return "-" }
        let parts = ScheduleDates.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Day, date, hours, kind, title, place and person of each entry, one line each.
    private func summary(_ slots: [ImportedSlot]) -> [String] {
        slots.map { slot in
            "\(slot.weekday)|\(dayText(slot.date))|\(Fx.hm(slot.startMinute))-\(Fx.hm(slot.endMinute))|\(slot.kind.rawValue)|"
                + "\(slot.title)|\(slot.room ?? "-")|\(slot.detail ?? "-")"
        }
    }

    private func read(_ lines: [RecognizedLine]) -> [ImportedSlot] {
        ScheduleParser.slots(from: lines)
    }

    // MARK: Work schedules

    func testAWorkListGivesShiftsWithoutInventingNames() {
        let slots = read(Fx.list([
            "Horaire de travail - semaine du 23 novembre", "Lun 9h-17h", "Mar 9h-17h Caisse", "Mer Congé", "Jeu 12h-20h", "Ven 9h-13h",
            "Questions : voir le gérant"
        ]))
        XCTAssertEqual(summary(slots), [
            "1|-|09:00-17:00|work||-|-",
            "2|-|09:00-17:00|work|Caisse|-|-",
            "4|-|12:00-20:00|work||-|-",
            "5|-|09:00-13:00|work||-|-"
        ])
        XCTAssertTrue(slots.allSatisfy { $0.isSelected }, "One person's schedule: every shift is ticked")
        XCTAssertTrue(slots.allSatisfy { $0.date == nil }, "A weekly work schedule has no date")
    }

    func testAnEnglishWorkListWithA12HourClock() {
        let slots = read(Fx.list([
            "Work schedule - Week of Nov 23", "Mon 9:00 AM - 5:00 PM", "Tue Off", "Wed 12 PM - 8 PM Cashier", "Fri 7:30 AM - 3:30 PM"
        ]))
        XCTAssertEqual(summary(slots), [
            "1|-|09:00-17:00|work||-|-",
            "3|-|12:00-20:00|work|Cashier|-|-",
            "5|-|07:30-15:30|work||-|-"
        ])
    }

    func testShiftsWithoutAnyMarkOfWorkStayUnread() {
        // The same rows on a page that does not say it is a work schedule: nothing is invented (as before).
        XCTAssertEqual(read(Fx.list(["Lun 9h-17h", "Mar 9h-17h", "Jeu 12h-20h"])), [])
    }

    /// A roster: the days as columns, one row per employee, each cell its own line.
    private func rosterLines() -> [RecognizedLine] {
        let x = [0.30, 0.42, 0.54, 0.66, 0.78]
        var lines = [Fx.line("Café Lumière - semaine du 23 novembre", 0.5, 0.04, 0.5), Fx.line("Employé", 0.10, 0.10, 0.12)]
        for (index, day) in ["Lun", "Mar", "Mer", "Jeu", "Ven"].enumerated() { lines.append(Fx.line(day, x[index], 0.10, 0.08)) }
        let rows: [(String, [String])] = [
            ("Alice Tremblay", ["9h-17h", "9h-17h", "Congé", "12h-20h", "9h-17h"]),
            ("Bruno Kim", ["Repos", "12h-20h", "12h-20h", "9h-17h", "-"]),
            ("Chloé Diaz", ["7h-15h", "7h-15h", "7h-15h", "Congé", "7h-15h"])
        ]
        for (rowIndex, row) in rows.enumerated() {
            let y = 0.18 + 0.08 * Double(rowIndex)
            lines.append(Fx.line(row.0, 0.10, y, 0.14))
            for (column, cell) in row.1.enumerated() { lines.append(Fx.line(cell, x[column], y, 0.09)) }
        }
        lines.append(Fx.line("Imprimé le 20/11/2026", 0.5, 0.92, 0.3))
        return lines
    }

    func testARosterOfSeveralPeopleProposesEveryRowNamedAndUnticked() {
        let slots = read(rosterLines())
        XCTAssertEqual(summary(slots), [
            "1|-|07:00-15:00|work||-|Chloé Diaz",
            "1|-|09:00-17:00|work||-|Alice Tremblay",
            "2|-|07:00-15:00|work||-|Chloé Diaz",
            "2|-|09:00-17:00|work||-|Alice Tremblay",
            "2|-|12:00-20:00|work||-|Bruno Kim",
            "3|-|07:00-15:00|work||-|Chloé Diaz",
            "3|-|12:00-20:00|work||-|Bruno Kim",
            "4|-|09:00-17:00|work||-|Bruno Kim",
            "4|-|12:00-20:00|work||-|Alice Tremblay",
            "5|-|07:00-15:00|work||-|Chloé Diaz",
            "5|-|09:00-17:00|work||-|Alice Tremblay"
        ])
        XCTAssertTrue(slots.allSatisfy { !$0.isSelected }, "Several people: the person picks their row on the check screen")
    }

    func testARosterOfOnePersonReadAsWholeRowsKeepsTheirShifts() {
        // Vision may give the header and the row as one line each: the hours are placed under their day by their place in the line.
        let lines = [
            Fx.line("Café Lumière - horaire de la semaine", 0.5, 0.04, 0.5),
            Fx.line("Employé Lun Mar Mer Jeu Ven", 0.5, 0.12, 0.84),
            Fx.line("Julie Martin 9h-17h 9h-17h Congé 12h-20h 9h-17h", 0.5, 0.20, 0.84)
        ]
        let slots = read(lines)
        XCTAssertEqual(summary(slots), [
            "1|-|09:00-17:00|work||-|-",
            "2|-|09:00-17:00|work||-|-",
            "4|-|12:00-20:00|work||-|-",
            "5|-|09:00-17:00|work||-|-"
        ])
        XCTAssertTrue(slots.allSatisfy { $0.isSelected }, "One name: the row is the person's own schedule")
    }

    func testATimetableWithHoursInTheMarginIsNeverARoster() {
        // Day columns and hours in the margin, hours alone in the cells: a timetable, not a roster (no name in the margin).
        let lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi"]) + [Fx.line("8h-9h", 0.07, 0.2, 0.08), Fx.line("8h-9h", 0.26, 0.2, 0.1)]
        XCTAssertTrue(ShiftRosterLayout.read(lines, cues: DocumentCues()).isEmpty)
    }

    // MARK: Dated appointments

    func testDatedAppointmentsInFrench() {
        let slots = read(Fx.list([
            "Mes rendez-vous",
            "Mardi 24 novembre 2026, 14 h 30, Dr Roy, Clinique du Parc",
            "Jeudi 26 novembre 2026, 9 h - 10 h, Me Tremblay (avocate), 50 rue Champlain",
            "Vendredi 27 novembre 2026, 10 h 15, Renouvellement du passeport, Bureau de Service Canada"
        ]))
        XCTAssertEqual(summary(slots), [
            "2|2026-11-24|14:30-15:30|appointment||Clinique du Parc|Dr Roy",
            "4|2026-11-26|09:00-10:00|appointment||50 rue Champlain|Me Tremblay (avocate)",
            "5|2026-11-27|10:15-11:15|appointment|Renouvellement du passeport|Bureau de Service Canada|-"
        ])
        // The dates were written in full: they are not in doubt; an end that was not written is.
        XCTAssertTrue(slots.allSatisfy { !$0.uncertain.contains(.date) && !$0.uncertain.contains(.day) })
        XCTAssertEqual(slots.map { $0.uncertain.contains(.end) }, [true, false, true])
    }

    func testDatedAppointmentsInEnglishWithA12HourClock() {
        let slots = read(Fx.list([
            "Appointments",
            "Tue, Nov 24, 2026 at 2:30 PM - Dentist, Dr. Smith, 12 Main St",
            "Thu, Nov 26, 2026 9:00 AM - 10:00 AM - Lawyer meeting, Ms. Patel",
            "Nov 30 3:15 PM Haircut"
        ]))
        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(summary(slots.filter { $0.title != "Haircut" }), [
            "2|2026-11-24|14:30-15:30|appointment|Dentist|12 Main St|Dr. Smith",
            "4|2026-11-26|09:00-10:00|appointment|Lawyer meeting|-|Ms. Patel"
        ])
        // No year written: November 30 of the year that comes, the date marked to check.
        let haircut = slots.first { $0.title == "Haircut" }
        XCTAssertEqual(haircut.map { Fx.hm($0.startMinute) }, "15:15")
        XCTAssertEqual(haircut?.kind, .appointment)
        let parts = haircut?.date.map { ScheduleDates.calendar.dateComponents([.month, .day], from: $0) }
        XCTAssertEqual(parts?.month, 11)
        XCTAssertEqual(parts?.day, 30)
        XCTAssertEqual(haircut.flatMap { slot in slot.date.map { ScheduleDates.isoWeekday($0) } }, haircut?.weekday)
        XCTAssertTrue(haircut?.uncertain.contains(.date) ?? false)
        XCTAssertTrue(haircut?.needsCheck ?? false)
    }

    func testOtherLanguagesAndFormatsOfDates() {
        let rows = [
            "martes 24 de noviembre de 2026, 14:30, Dentista, Dra. López",
            "Di., 24.11.2026, 14:30 Uhr, Zahnarzt Dr. Weber",
            "martedì 24 novembre 2026 ore 14:30 Dentista",
            "terça-feira, 24 de novembro de 2026, 14h30, Dentista",
            "2026年11月24日(火) 14:30 歯科 山田先生",
            "2026-11-24 14:30 Dentiste"
        ]
        for row in rows {
            let slots = read(Fx.list(["Rendez-vous", row]))
            XCTAssertEqual(slots.count, 1, row)
            XCTAssertEqual(slots.first.map { dayText($0.date) }, "2026-11-24", row)
            XCTAssertEqual(slots.first?.weekday, 2, row)
            XCTAssertEqual(slots.first?.startMinute, 14 * 60 + 30, row)
            XCTAssertEqual(slots.first?.kind, .appointment, row)
        }
        XCTAssertEqual(read(Fx.list(["Rendez-vous", "2026年11月24日(火) 14:30 歯科 山田先生"])).first?.detail, "山田先生")
    }

    func testCoursesAndAnAppointmentOnOnePage() {
        let slots = read(Fx.list([
            "Horaire de la session", "Lundi", "8h30 - 10h Mathématiques B-204", "Mercredi", "13h - 15h Physique Salle 12",
            "Rendez-vous", "Mardi 24 novembre 2026, 14 h 30, Dentiste, Dr Roy"
        ]))
        XCTAssertEqual(summary(slots), [
            "1|-|08:30-10:00|course|Mathématiques|B-204|-",
            "2|2026-11-24|14:30-15:30|appointment|Dentiste|-|Dr Roy",
            "3|-|13:00-15:00|course|Physique|Salle 12|-"
        ])
    }

    func testAPageWithAHeadingAFooterAndTextAtItsEdges() {
        func edge(_ text: String, x: Double, y: Double, width: Double) -> RecognizedLine {
            RecognizedLine(text: text, box: CGRect(x: x, y: y, width: width, height: 0.016))
        }
        let lines = [
            Fx.line("Horaire - Session d'automne 2026", 0.5, 0.012, 0.6),
            edge("Lundi", x: 0.0, y: 0.04, width: 0.1),
            edge("8h - 9h30 Anglais A-101", x: 0.0, y: 0.08, width: 0.35),
            edge("Vendredi", x: 0.0, y: 0.88, width: 0.12),
            edge("15h - 16h30 Chimie C-210", x: 0.0, y: 0.92, width: 0.35),
            edge("Rendez-vous : jeudi 26 novembre 2026 à 15 h, Dr Lemay", x: 0.45, y: 0.955, width: 0.55),
            Fx.line("Page 1 sur 1", 0.5, 0.988, 0.12)
        ]
        XCTAssertEqual(summary(read(lines)), [
            "1|-|08:00-09:30|course|Anglais|A-101|-",
            "4|2026-11-26|15:00-16:00|appointment|Rendez-vous|-|Dr Lemay",
            "5|-|15:00-16:30|course|Chimie|C-210|-"
        ])
    }

    func testAnAgendaWithDatedHeadingsDatesTheEntriesUnderThem() {
        let slots = read(Fx.list([
            "Mes rendez-vous", "Mardi 24 novembre 2026", "9h00 Dentiste, Dr Roy", "Jeudi 26 novembre 2026", "16h - 17h Physiothérapie"
        ]))
        XCTAssertEqual(summary(slots), [
            "2|2026-11-24|09:00-10:00|appointment|Dentiste|-|Dr Roy",
            "4|2026-11-26|16:00-17:00|appointment|Physiothérapie|-|-"
        ])
    }

    func testATeacherReadWithAClassIsKeptApartFromItsTitle() {
        let slots = read(Fx.list(["Mardi 21 octobre", "08:00 - 10:00 CM Algorithmique (Amphi A) - Dupont J."]))
        XCTAssertEqual(slots.first?.title, "CM Algorithmique")
        XCTAssertEqual(slots.first?.detail, "Dupont J.")
        XCTAssertEqual(slots.first?.kind, .course)
        XCTAssertNil(slots.first?.date, "A class of a timetable comes back every week")
    }

    // MARK: Words of the page and classes

    func testCommonWordsMarkTheirRowButNotThePage() {
        // Common in timetables of classes: they no longer say the whole page is a roster or an agenda.
        XCTAssertEqual(DocumentCues(lines: Fx.list(["Termine und Räume", "Turno: Mañana", "Staff room B-12", "Réunion d'équipe"])),
                       DocumentCues())
        XCTAssertTrue(ScheduleEvents.hasWorkCue("Turno: Mañana"), "The row itself is still marked")
        XCTAssertTrue(ScheduleEvents.hasAppointmentCue("Réunion d'équipe"))
        // Words that leave no doubt still mark the page.
        XCTAssertEqual(DocumentCues(lines: Fx.list(["Horaire de travail", "Mes rendez-vous"])), DocumentCues(work: true, appointments: true))
    }

    func testADatedClassStaysAClassOnAPageOfAppointments() {
        let slots = read(Fx.list(["Rendez-vous", "Mo, 12.10.2026 08:00-10:00 Vorlesung Analysis"]))
        XCTAssertFalse(slots.contains { $0.kind == .appointment }, "A lecture is not an appointment")
    }

    func testAClassOnAWorkScheduleStaysAClass() {
        let slots = read(Fx.list(["Horaire de travail", "Lun 9h-17h", "Mar 18h-21h Cours de comptabilité"]))
        XCTAssertEqual(summary(slots), [
            "1|-|09:00-17:00|work||-|-",
            "2|-|18:00-21:00|course|Cours de comptabilité|-|-"
        ])
    }

    func testAnUndatedRowIsReclassifiedOnlyByAWordWithoutDoubt() {
        let slots = read(Fx.list([
            "Lundi", "8h-10h Physiothérapie", "10h-11h Entretien général d'immeubles", "Mardi", "14h-15h Rendez-vous d'orientation"
        ]))
        XCTAssertEqual(slots.map { "\($0.title)|\($0.kind.rawValue)" }, [
            "Physiothérapie|course", "Entretien général d'immeubles|course", "Rendez-vous d'orientation|appointment"
        ])
    }

    func testATimeStampAloneIsNoAppointmentButALineUnderItCompletesIt() {
        let alone = read(Fx.list(["Mes rendez-vous", "2026-11-24 14:30", "Jeudi 26 novembre 2026, 9 h, Dentiste"]))
        XCTAssertEqual(summary(alone), ["4|2026-11-26|09:00-10:00|appointment|Dentiste|-|-"])
        let twoLines = read(Fx.list(["Mes rendez-vous", "Mardi 24 novembre 2026 · 14 h 30", "Dentiste - Dr Roy, Clinique du Parc"]))
        XCTAssertEqual(summary(twoLines), ["2|2026-11-24|14:30-15:30|appointment|Dentiste|Clinique du Parc|Dr Roy"])
    }

    // MARK: Shifts whose hours are not sure

    func testShiftsWhoseHoursAreNotSureAreProposedAsWrittenUnticked() {
        // "4h-12h" was read 16:00-24:00 as if sure, "5h-13h" and "22h-6h" were dropped: now as written, unticked, marked.
        // Past midnight, the entry stops at 24:00 (a day of the Planning ends there); "9h-17h" stays ticked and sure.
        let slots = read(Fx.list(["Horaire de travail", "Lun 4h-12h", "Mar 5h-13h Caisse", "Mer 22h-6h", "Jeu 9h-17h"]))
        XCTAssertEqual(summary(slots), [
            "1|-|04:00-12:00|work||-|-",
            "2|-|05:00-13:00|work|Caisse|-|-",
            "3|-|22:00-24:00|work||-|-",
            "4|-|09:00-17:00|work||-|-"
        ])
        XCTAssertEqual(slots.map { $0.isSelected }, [false, false, false, true])
        XCTAssertEqual(slots.map { $0.uncertain.isSuperset(of: [.start, .end]) }, [true, true, true, false])
    }

    func testOnlyTheHoursTheUsualReadingWouldMoveAreInDoubt() {
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "5h-13h").count, 1, "5h would be read 17:00: to check")
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "1h-9h").count, 1)
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "6h-14h").count, 0, "6h is read as written: nothing to check")
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "7h-15h").count, 0, "7h is read as written: nothing to check")
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "22h-6h").count, 1, "A shift over midnight is to check")
    }

    func testTheWrittenHoursOfAShiftAreOnlyReadOnAWorkRow() {
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "9h-17h").count, 0)
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "7:30 AM - 3:30 PM").count, 0, "AM and PM leave no doubt")
        XCTAssertEqual(ScheduleEvents.unsureShifts(in: "2026-11-24").count, 0, "A date is not a shift")
        // A timetable of classes keeps its reading: "3h-5h" is still the afternoon.
        XCTAssertEqual(summary(read(Fx.list(["Lundi", "3h-5h Chimie"]))), ["1|-|15:00-17:00|course|Chimie|-|-"])
    }

    // MARK: Readings in doubt

    func testADateThatCannotBeReadStaysEmptyAndMarked() {
        let slots = read(Fx.list(["Rendez-vous", "Mardi ?? novembre 2026, 14 h 30, Dentiste"]))
        XCTAssertEqual(slots.count, 1)
        XCTAssertNil(slots.first?.date, "No date is invented")
        XCTAssertEqual(slots.first?.weekday, 2)
        XCTAssertEqual(slots.first?.startMinute, 14 * 60 + 30)
        XCTAssertEqual(slots.first?.title, "Dentiste")
        XCTAssertTrue(slots.first?.uncertain.contains(.date) ?? false)
        XCTAssertTrue(slots.first?.needsCheck ?? false)
        XCTAssertEqual(slots.first?.isSelected, false, "Unticked: ticked without a date, it would come back every Tuesday")
    }

    func testAnHourWithoutAmOrPmIsMarked() {
        let slot = read(Fx.list(["Rendez-vous", "Jeudi 26 novembre 2026, 2:30, Dr Lemay"])).first
        XCTAssertEqual(slot?.startMinute, 14 * 60 + 30, "Read as the afternoon, as for a class")
        XCTAssertTrue(slot?.uncertain.contains(.start) ?? false, "but marked: it may be the morning")
    }

    func testAnHourThatCannotBeReadIsProposedUntickedAndMarked() {
        let slot = read(Fx.list(["Rendez-vous", "Vendredi 27 novembre 2026, ??h??, Dentiste"])).first
        XCTAssertEqual(slot.map { dayText($0.date) }, "2026-11-27")
        XCTAssertEqual(slot?.isSelected, false)
        XCTAssertTrue(slot?.uncertain.isSuperset(of: [.start, .end]) ?? false)
        XCTAssertEqual(slot?.title, "Dentiste")
    }

    func testDayAndMonthThatCouldBeSwappedAreMarked() {
        let slot = read(Fx.list(["Rendez-vous", "03/04/2026 10:00 Dentiste"])).first
        XCTAssertEqual(slot.map { dayText($0.date) }, "2026-04-03", "Day first, as written in French")
        XCTAssertTrue(slot?.uncertain.contains(.date) ?? false)
    }

    func testADayNameThatDoesNotMatchItsDateMarksBoth() {
        // 18 November 2026 is a Wednesday: the date is kept as written, the day and the date are marked.
        let slot = read(Fx.list(["Rendez-vous", "Mardi 18 novembre 2026, 14 h 30, Dentiste"])).first
        XCTAssertEqual(slot.map { dayText($0.date) }, "2026-11-18")
        XCTAssertEqual(slot?.weekday, 3)
        XCTAssertTrue(slot?.uncertain.isSuperset(of: [.date, .day]) ?? false)
    }

    func testFootersWithADateAndAnHourAreNotAppointments() {
        // "Généré le ... à 08:30" and a time stamp are noise of a timetable, not entries.
        let slots = read(Fx.list(["Généré le 12/10/2026 à 08:30", "2019-11-07 14:29", "Lundi", "8h-10h Maths"]))
        XCTAssertEqual(summary(slots), ["1|-|08:00-10:00|course|Maths|-|-"])
    }

    // MARK: Dates

    func testWrittenDates() {
        func found(_ text: String, monthFirst: Bool = false) -> String {
            guard let date = ScheduleDates.find(in: text, monthFirst: monthFirst) else { return "-" }
            return "\(date.year.map(String.init) ?? "?")-\(date.month)-\(date.day)\(date.swappable ? "~" : "")"
        }
        XCTAssertEqual(found("Mardi 24 novembre 2026"), "2026-11-24")
        XCTAssertEqual(found("1er mars"), "?-3-1")
        XCTAssertEqual(found("24 de noviembre de 2026"), "2026-11-24")
        XCTAssertEqual(found("24. November 2026"), "2026-11-24")
        XCTAssertEqual(found("24 août"), "?-8-24")
        XCTAssertEqual(found("Nov 24, 2026"), "2026-11-24")
        XCTAssertEqual(found("November 24th"), "?-11-24")
        XCTAssertEqual(found("2026-11-24"), "2026-11-24")
        XCTAssertEqual(found("24/11/2026"), "2026-11-24")
        XCTAssertEqual(found("11/24/2026"), "2026-11-24")
        XCTAssertEqual(found("24.11.26"), "2026-11-24")
        XCTAssertEqual(found("03/04/2026"), "2026-4-3~")
        XCTAssertEqual(found("03/04/2026", monthFirst: true), "2026-3-4~")
        XCTAssertEqual(found("2026年11月24日"), "2026-11-24")
        XCTAssertEqual(found("11月24日"), "?-11-24")
        // Not dates: hours, a French "Mar 18" (Tuesday 18th), a room.
        XCTAssertEqual(found("14h30"), "-")
        XCTAssertEqual(found("8.30-10.00"), "-")
        XCTAssertEqual(found("Mar 18"), "-")
        XCTAssertEqual(found("Salle B-204"), "-")
        XCTAssertEqual(found("Mon 9:00 AM - 5:00 PM"), "-")
    }

    func testSettledDates() throws {
        let reference = try XCTUnwrap(ScheduleDates.day(year: 2026, month: 11, day: 17))
        func settled(_ text: String, weekday: Int? = nil) -> SettledDate? {
            ScheduleDates.find(in: text).flatMap { ScheduleDates.settle($0, weekday: weekday, reference: reference) }
        }
        // Written in full and matching its day: sure.
        let full = try XCTUnwrap(settled("24 novembre 2026", weekday: 2))
        XCTAssertEqual(dayText(full.date), "2026-11-24")
        XCTAssertFalse(full.uncertain)
        // No year, but a day name: the year whose date falls on that day.
        let named = try XCTUnwrap(settled("24 novembre", weekday: 2))
        XCTAssertEqual(dayText(named.date), "2026-11-24")
        XCTAssertFalse(named.uncertain)
        // No year and no day name: the next time it comes, in doubt.
        let january = try XCTUnwrap(settled("5 janvier"))
        XCTAssertEqual(dayText(january.date), "2027-01-05")
        XCTAssertTrue(january.uncertain)
        // A day name that matches no reading: the date as written, both in doubt.
        let wrong = try XCTUnwrap(settled("18 novembre 2026", weekday: 2))
        XCTAssertEqual(dayText(wrong.date), "2026-11-18")
        XCTAssertEqual(wrong.weekday, 3)
        XCTAssertTrue(wrong.weekdayConflict)
        // "03/04/2026" with a day name that only the other order matches: swapped, and sure.
        let swapped = try XCTUnwrap(settled("03/04/2026", weekday: 3))
        XCTAssertEqual(dayText(swapped.date), "2026-03-04", "4 March 2026 is a Wednesday, 3 April a Friday")
        XCTAssertFalse(swapped.uncertain)
        // A day that does not exist.
        XCTAssertNil(settled("30/02/2026"))
    }

    // MARK: Measure

    /// The new kinds of documents scored like the corpus of timetables (ScheduleEvaluationTests): a MEASURE printed in the
    /// journal ("SCORE <name> ..."), with a low floor: it shows how they are read, it is not a goal to tighten blindly.
    func testScoresOfTheNewDocuments() {
        let rosterExpected = [
            (1, "07:00", "15:00"), (1, "09:00", "17:00"), (2, "07:00", "15:00"), (2, "09:00", "17:00"), (2, "12:00", "20:00"),
            (3, "07:00", "15:00"), (3, "12:00", "20:00"), (4, "09:00", "17:00"), (4, "12:00", "20:00"), (5, "07:00", "15:00"),
            (5, "09:00", "17:00")
        ].map { ScheduleCorpus.slot($0.0, $0.1, $0.2, "") }
        let pages: [(String, [RecognizedLine], [ReferenceSlot])] = [
            ("travail-liste", Fx.list(["Horaire de travail", "Lun 9h-17h", "Mar 9h-17h Caisse", "Jeu 12h-20h"]),
             [ScheduleCorpus.slot(1, "09:00", "17:00", ""), ScheduleCorpus.slot(2, "09:00", "17:00", "Caisse"),
              ScheduleCorpus.slot(4, "12:00", "20:00", "")]),
            ("employes-par-jours", rosterLines(), rosterExpected),
            ("rendez-vous-fr", Fx.list(["Mes rendez-vous", "Mardi 24 novembre 2026, 14 h 30, Dentiste, Dr Roy",
                                        "Jeudi 26 novembre 2026, 9 h - 10 h, Notaire, Me Tremblay"]),
             [ScheduleCorpus.slot(2, "14:30", "15:30", "Dentiste"), ScheduleCorpus.slot(4, "09:00", "10:00", "Notaire")])
        ]
        var rows: [String] = []
        for (name, lines, expected) in pages {
            let card = ScheduleScorer.card(expected: expected, found: read(lines))
            let row = String(format: "SCORE %@ bruit=0 P=%.2f R=%.2f E=%.2f attendus=%ld", name, card.precision, card.recall,
                             card.exactness, expected.count)
            print(row)
            rows.append(row)
            XCTAssertGreaterThanOrEqual(card.recall, 0.5, row)
        }
        let attachment = XCTAttachment(string: rows.joined(separator: "\n"))
        attachment.name = "SCORES-documents"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
