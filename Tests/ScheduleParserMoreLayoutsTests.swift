import XCTest
@testable import Tessera

/// More layouts of timetables (see ScheduleParserLayoutsTests for the first ones): periods named by a legend, hours
/// written as starts only or as several ranges on a row, two weeks on a page, other languages, a tilted photo, a
/// page printed as boxed blocks (the "Horaire de l'étudiant" of a college), the colours of the image, and what is
/// marked "to check". The lines are written by hand like Vision would give them.
private struct FramedColumnsProbe: BlockProbe {
    /// The outlines of each column of the page (pixels of a 790 x 1023 image), top to bottom.
    var outlines: [[Double]]
    var edges: [Double]
    var width: Double
    var height: Double

    func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? { nil }

    func framedRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
        let pixel = x * width
        guard let column = (0..<outlines.count).first(where: { pixel >= edges[$0] && pixel < edges[$0 + 1] }) else { return [] }
        var runs: [ClosedRange<Double>] = []
        for (low, high) in zip(outlines[column], outlines[column].dropFirst()) {
            let from = max(low / height, fromY)
            let to = min(high / height, toY)
            if from < to { runs.append(from...to) }
        }
        return runs
    }
}

final class ScheduleParserMoreLayoutsTests: XCTestCase {
    private typealias Fx = LayoutFixtures

    private func read(_ lines: [RecognizedLine], probe: BlockProbe? = nil, aspect: Double = 4.0 / 3.0) -> [String] {
        Fx.summary(ScheduleParser.slots(from: lines, probe: probe, aspect: aspect))
    }

    // MARK: 6. Numbered periods and a legend of the bells

    func testNumberedPeriodsWithTheBellsInOneLegendLine() {
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"])
        lines += (0..<5).map { Fx.line(String($0 + 1), 0.07, Fx.rowY($0), 0.04) }
        lines += Fx.cell(0, 0, "Maths", "B12") + Fx.cell(2, 1, "Histoire", "A10") + Fx.cell(1, 3, "Chimie")
        lines += [Fx.line("Cloches : P1 8:00-8:50 P2 8:55-9:45 P3 10:00-10:50 P4 10:55-11:45 P5 13:00-13:50", 0.5, 0.93, 0.9)]
        XCTAssertEqual(read(lines), ["1|08:00-08:50|Maths|B12", "2|10:55-11:45|Chimie|-", "3|08:55-09:45|Histoire|A10"])
    }

    func testNumberedPeriodsWhoseLegendGivesOnlyTheStarts() {
        // "P1 8:00", "P2 8:55"...: 55 minutes apart, so a period lasts 50 minutes (the break is 5).
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"])
        lines += (0..<5).map { Fx.line("P\($0 + 1)", 0.07, Fx.rowY($0), 0.04) }
        lines += Fx.cell(0, 0, "Maths", "B12") + Fx.cell(2, 1, "Histoire", "A10") + Fx.cell(1, 3, "Chimie")
        for (index, text) in ["P1 8:00", "P2 8:55", "P3 10:00", "P4 10:55", "P5 13:00"].enumerated() {
            lines.append(Fx.line(text, 0.2 + 0.15 * Double(index), 0.93, 0.1))
        }
        XCTAssertEqual(read(lines), ["1|08:00-08:50|Maths|B12", "2|10:55-11:45|Chimie|-", "3|08:55-09:45|Histoire|A10"])
    }

    func testJapanesePeriodsNamedInTheMarginWithTheirHours() {
        let x = [0.26, 0.40, 0.54, 0.68, 0.82]
        var lines = "月火水木金".enumerated().map { Fx.line(String($1), x[$0], 0.08, 0.05) }
        lines += ["1限 9:00-10:30", "2限 10:40-12:10", "3限 13:00-14:30"].enumerated().map { Fx.line($1, 0.10, 0.2 + 0.12 * Double($0), 0.16) }
        lines += [Fx.line("数学", x[0], 0.2, 0.1), Fx.line("A101", x[0], 0.22, 0.1), Fx.line("英語", x[1], 0.32, 0.1), Fx.line("物理", x[4], 0.44, 0.1)]
        XCTAssertEqual(read(lines), ["1|09:00-10:30|数学|A101", "2|10:40-12:10|英語|-", "5|13:00-14:30|物理|-"])
    }

    func testJapanesePeriodsWithTheHoursStackedInTheMargin() {
        let x = [0.26, 0.40, 0.54, 0.68, 0.82]
        var lines = "月火水木金".enumerated().map { Fx.line(String($1), x[$0], 0.08, 0.05) }
        for (index, row) in [("1", "9:00", "10:30"), ("2", "10:40", "12:10"), ("3", "13:00", "14:30")].enumerated() {
            let y = 0.2 + 0.12 * Double(index)
            lines += [Fx.line(row.0, 0.05, y, 0.03), Fx.line(row.1, 0.10, y - 0.025, 0.06), Fx.line(row.2, 0.10, y + 0.025, 0.06)]
        }
        lines += [Fx.line("数学", x[0], 0.2, 0.1), Fx.line("英語", x[1], 0.32, 0.1), Fx.line("物理", x[4], 0.44, 0.1)]
        XCTAssertEqual(read(lines), ["1|09:00-10:30|数学|-", "2|10:40-12:10|英語|-", "5|13:00-14:30|物理|-"])
    }

    func testPeriodNumbersAndLegendEntries() {
        XCTAssertEqual(PeriodGridLayout.periodNumber("3"), 3)
        XCTAssertEqual(PeriodGridLayout.periodNumber("P2"), 2)
        XCTAssertEqual(PeriodGridLayout.periodNumber("1re heure"), 1)
        XCTAssertEqual(PeriodGridLayout.periodNumber("4. Stunde"), 4)
        XCTAssertEqual(PeriodGridLayout.periodNumber("2限"), 2)
        XCTAssertEqual(PeriodGridLayout.periodNumber("第3限"), 3)
        XCTAssertNil(PeriodGridLayout.periodNumber("Lundi"))
        XCTAssertNil(PeriodGridLayout.periodNumber("8:00"))
        let entries = PeriodGridLayout.legendEntries(in: "P1 8:00-8:50 P2 8:55")
        XCTAssertEqual(entries.map { $0.number }, [1, 2])
        XCTAssertEqual(entries.first?.end, 530)
        XCTAssertNil(entries.last?.end)
        XCTAssertTrue(PeriodGridLayout.legendEntries(in: "10:00-10:50").isEmpty, "A time is not the number of a period")
    }

    // MARK: 7. Starts only, 8. several ranges on a row

    func testStartsOnlyEndWhereTheNextClassBeginsOrAfterTheUsualLength() {
        XCTAssertEqual(read(Fx.list(["Lundi", "9h Maths", "10h Physique", "11h30 Bio"])),
                       ["1|09:00-10:00|Maths|-", "1|10:00-11:00|Physique|-", "1|11:30-12:30|Bio|-"])
        XCTAssertEqual(read(Fx.list(["Lundi", "9h Maths", "9h45 Physique", "14h Bio"])),
                       ["1|09:00-09:45|Maths|-", "1|09:45-10:45|Physique|-", "1|14:00-15:00|Bio|-"])
    }

    func testSeveralRangesOnOneRowAreOneClassEach() {
        XCTAssertEqual(read(Fx.list(["Lundi 9h-12h / 13h-17h Atelier", "Mardi : 9h-12h / 13h-17h Atelier"])),
                       ["1|09:00-12:00|Atelier|-", "1|13:00-17:00|Atelier|-", "2|09:00-12:00|Atelier|-", "2|13:00-17:00|Atelier|-"])
        // Shifts with no name are not classes: nothing is invented.
        XCTAssertEqual(read(Fx.list(["Lundi : 9h-12h / 13h-17h", "Mardi : 9h-12h / 13h-17h"])), [])
    }

    // MARK: 9. Two weeks on a page

    private func weekGrid(top: Double, heading: String, _ entries: [(Int, String, String)]) -> [RecognizedLine] {
        var lines = [Fx.line(heading, 0.5, top + 0.03, 0.3)]
        for (index, name) in ["Lun", "Mar", "Mer", "Jeu", "Ven"].enumerated() { lines.append(Fx.line(name, Fx.schoolX[index], top + 0.08, 0.1)) }
        for (column, hours, title) in entries {
            lines.append(Fx.line(hours, Fx.schoolX[column], top + 0.14, 0.12))
            lines.append(Fx.line(title, Fx.schoolX[column], top + 0.165, 0.12))
        }
        return lines
    }

    func testTwoWeeksOnOnePageGiveTheSecondOneUntickedAndMarked() {
        let lines = weekGrid(top: 0, heading: "Semaine A", [(0, "8h-9h", "Maths"), (1, "9h-10h", "Anglais")])
            + weekGrid(top: 0.45, heading: "Semaine B", [(0, "8h-9h", "Physique"), (2, "10h-11h", "Sport")])
        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(Fx.summary(slots), ["1|08:00-09:00|Maths|-", "1|08:00-09:00|Physique (B)|-", "2|09:00-10:00|Anglais|-", "3|10:00-11:00|Sport (B)|-"])
        XCTAssertEqual(slots.map { $0.isSelected }, [true, false, true, false])
        XCTAssertEqual(slots.map { $0.needsCheck }, [false, true, false, true])
    }

    func testAMorningGridAndAnAfternoonGridAreOneTimetable() {
        let lines = weekGrid(top: 0, heading: "Matin", [(0, "8h-9h", "Maths")]) + weekGrid(top: 0.45, heading: "Après-midi", [(0, "14h-15h", "Sport")])
        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(Fx.summary(slots), ["1|08:00-09:00|Maths|-", "1|14:00-15:00|Sport|-"])
        XCTAssertEqual(slots.map { $0.isSelected }, [true, true])
    }

    // MARK: 10. Other languages

    func testItalianPortugueseSpanishChineseAndKoreanLists() {
        XCTAssertEqual(read(Fx.list(["Lunedì 8.30-10.00 Matematica Aula 3", "Martedì 10:00-11:30 Fisica"])),
                       ["1|08:30-10:00|Matematica|Aula 3", "2|10:00-11:30|Fisica|-"])
        XCTAssertEqual(read(Fx.list(["Segunda-feira 08:00-09:30 Matemática Sala 12", "Quarta-feira 10:00-11:30 Física"])),
                       ["1|08:00-09:30|Matemática|Sala 12", "3|10:00-11:30|Física|-"])
        XCTAssertEqual(read(Fx.list(["lunes 8:00-9:30 Matemáticas Aula 3", "jueves 10:00-11:30 Física"])),
                       ["1|08:00-09:30|Matemáticas|Aula 3", "4|10:00-11:30|Física|-"])
        XCTAssertEqual(read(Fx.list(["星期一 8:00-9:40 高等数学", "星期三 10:00-11:40 大学物理"])),
                       ["1|08:00-09:40|高等数学|-", "3|10:00-11:40|大学物理|-"])
        XCTAssertEqual(read(Fx.list(["월요일 9:00-10:30 수학", "수요일 13:00-14:30 영어"])),
                       ["1|09:00-10:30|수학|-", "3|13:00-14:30|영어|-"])
    }

    func testGermanGridWithLessonsNamedInTheMargin() {
        let x = [0.26, 0.40, 0.54, 0.68, 0.82]
        var lines = ["Mo", "Di", "Mi", "Do", "Fr"].enumerated().map { Fx.line($1, x[$0], 0.08, 0.06) }
        lines += ["1. Stunde 8:00-8:45", "2. Stunde 8:50-9:35", "3. Stunde 9:55-10:40"].enumerated().map { Fx.line($1, 0.10, 0.2 + 0.1 * Double($0), 0.16) }
        lines += [Fx.line("Mathe", x[0], 0.2, 0.1), Fx.line("Raum 12", x[0], 0.22, 0.1), Fx.line("Physik", x[3], 0.3, 0.1), Fx.line("Kunst", x[4], 0.4, 0.1)]
        XCTAssertEqual(read(lines), ["1|08:00-08:45|Mathe|Raum 12", "4|08:50-09:35|Physik|-", "5|09:55-10:40|Kunst|-"])
    }

    func testDayHeadersWithADateInOtherScripts() {
        XCTAssertEqual(ScheduleParser.dayCandidates(line: Fx.line("Lun. 26 août", 0.3, 0.1, 0.2), index: 0).map { $0.day }, [1])
        XCTAssertEqual(ScheduleParser.dayCandidates(line: Fx.line("Mar. 27 août", 0.3, 0.1, 0.2), index: 0).map { $0.day }, [2])
        XCTAssertEqual(ScheduleParser.dayCandidates(line: Fx.line("周一 周二 周三", 0.5, 0.1, 0.6), index: 0).map { $0.day }, [1, 2, 3])
        XCTAssertEqual(ScheduleParser.dayCandidates(line: Fx.line("월화수목금", 0.5, 0.1, 0.6), index: 0).map { $0.day }, [1, 2, 3, 4, 5])
        XCTAssertEqual(ScheduleParser.dayCandidates(line: Fx.line("L M M J V", 0.5, 0.1, 0.6), index: 0).map { $0.day }, [1, 2, 3, 4, 5])
        XCTAssertTrue(ScheduleParser.dayCandidates(line: Fx.line("Mon horaire", 0.5, 0.1, 0.3), index: 0).isEmpty)
    }

    // MARK: 11. A photo of a sheet, slightly tilted

    func testTiltedPhotoOfASchoolGridIsReadLikeAFlatOne() {
        let page = Fx.schoolPage()
        XCTAssertEqual(read(page), Fx.schoolExpected)
        for degrees in [-2.0, 2.0, 3.0] {
            let photo = Fx.rotated(page, degrees: degrees, aspect: 4.0 / 3.0)
            XCTAssertEqual(read(photo), Fx.schoolExpected, "tilt of \(degrees) degrees")
        }
    }

    func testStronglyTiltedPhotoAndTheMeasureOfTheTilt() {
        let page = Fx.schoolPage()
        for degrees in [-4.0, 5.0] {
            let photo = Fx.rotated(page, degrees: degrees, aspect: 4.0 / 3.0)
            XCTAssertEqual(read(photo), Fx.schoolExpected, "tilt of \(degrees) degrees")
        }
        XCTAssertNil(PageSkew.slope(of: page), "A level page has nothing to straighten")
        let measured = PageSkew.slope(of: Fx.rotated(page, degrees: 3, aspect: 4.0 / 3.0))
        XCTAssertNotNil(measured)
        XCTAssertGreaterThan(measured?.slope ?? 0, 0.03)
        XCTAssertNotNil(PageSkew.straightened(Fx.rotated(page, degrees: 3, aspect: 4.0 / 3.0), aspect: 4.0 / 3.0))
    }

    // MARK: 13. A PDF made by software, 14. weekend, evening, 12 hours

    func testPDFGridWithCleanColumnsAndAFooter() {
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]) + Fx.marginLabels(Fx.periodLabels)
        lines += [Fx.line("Maths (B12)", Fx.schoolX[0], Fx.rowY(0), 0.1), Fx.line("Français (C30)", Fx.schoolX[1], Fx.rowY(0), 0.1),
                  Fx.line("Généré le 12/10/2026 par Untis", 0.5, 0.97, 0.5), Fx.line("Page 1/1", 0.9, 0.97, 0.1)]
        XCTAssertEqual(read(lines), ["1|08:00-09:00|Maths|B12", "2|08:00-09:00|Français|C30"])
    }

    func testWeekendEveningAndTwelveHourClock() {
        let x = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
        var lines = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].enumerated().map { Fx.line($1, x[$0], 0.06, 0.07) }
        lines += [Fx.line("9:00 AM - 12:00 PM", x[5], 0.2, 0.09), Fx.line("Soccer", x[5], 0.22, 0.09),
                  Fx.line("6 PM - 8 PM", x[0], 0.4, 0.09), Fx.line("Yoga", x[0], 0.42, 0.09),
                  Fx.line("7:30 PM - 9 PM", x[6], 0.6, 0.09), Fx.line("Piano", x[6], 0.62, 0.09)]
        XCTAssertEqual(read(lines), ["1|18:00-20:00|Yoga|-", "6|09:00-12:00|Soccer|-", "7|19:30-21:00|Piano|-"])
        XCTAssertEqual(read(Fx.list(["Saturday 9 AM - 12 PM Soccer", "Sunday 7:30 PM - 9 PM Piano", "Monday 6 PM - 8 PM Yoga"])),
                       ["1|18:00-20:00|Yoga|-", "6|09:00-12:00|Soccer|-", "7|19:30-21:00|Piano|-"])
    }

    // MARK: 12 and more. Boxed blocks (the "Horaire de l'étudiant" of a college)

    private struct BoxedBlock {
        var column: Int
        var from: Int
        var to: Int
        var title: String
        var code: String
        var rooms: [String]
        var teacher: String
    }

    private static let blocks: [BoxedBlock] = [
        BoxedBlock(column: 0, from: 0, to: 4, title: "Allemand I (T)", code: "609-C01-HU g.00001", rooms: ["2.547"], teacher: "Chavant, L"),
        BoxedBlock(column: 0, from: 4, to: 6, title: "Allemand I (L)", code: "609-C01-HU g.00001", rooms: ["2.711"], teacher: "Chavant, L"),
        BoxedBlock(column: 0, from: 10, to: 14, title: "Écriture et lit (T)", code: "601-101-MQ g.00001", rooms: ["2.037"], teacher: "Berteau-Lord, G"),
        BoxedBlock(column: 0, from: 14, to: 18, title: "Philosophie et (T)", code: "340-101-MQ g.00003", rooms: ["2.913"], teacher: "Beaudoin, S"),
        BoxedBlock(column: 1, from: 2, to: 4, title: "Évolution diver (T)", code: "101-NYA-05 g.00002", rooms: ["1.105"], teacher: "Schoonheere, E"),
        BoxedBlock(column: 1, from: 4, to: 8, title: "Évolution diver (L)", code: "101-NYA-05 g.00002", rooms: ["1.614"], teacher: "Schoonheere, E"),
        BoxedBlock(column: 1, from: 10, to: 14, title: "Chimie générale (L)", code: "202-NYA-05 g.00003", rooms: ["1.629", "1.710"], teacher: "Pardin, C"),
        BoxedBlock(column: 1, from: 14, to: 16, title: "Calcul différen (L)", code: "201-NYA-05 g.00003", rooms: ["2.005"], teacher: "Crosnier, N"),
        BoxedBlock(column: 2, from: 2, to: 6, title: "Philosophie et (T)", code: "340-101-MQ g.00003", rooms: ["2.913"], teacher: "Beaudoin, S"),
        BoxedBlock(column: 2, from: 16, to: 19, title: "Chimie générale (T)", code: "202-NYA-05 g.00003", rooms: ["2.045"], teacher: "Pardin, C"),
        BoxedBlock(column: 3, from: 0, to: 4, title: "Écriture et lit (T)", code: "601-101-MQ g.00001", rooms: ["2.037"], teacher: "Berteau-Lord, G"),
        BoxedBlock(column: 3, from: 12, to: 16, title: "Calcul différen (T)", code: "201-NYA-05 g.00003", rooms: ["2.209"], teacher: "Crosnier, N"),
        BoxedBlock(column: 4, from: 0, to: 4, title: "Calcul différen (L)", code: "201-NYA-05 g.00003", rooms: ["2.005"], teacher: "Crosnier, N"),
        BoxedBlock(column: 4, from: 4, to: 8, title: "Évolution diver (L)", code: "101-NYA-05 g.00002", rooms: ["1.382"], teacher: "Schoonheere, E"),
        BoxedBlock(column: 4, from: 12, to: 15, title: "Chimie générale (T)", code: "202-NYA-05 g.00003", rooms: ["2.045"], teacher: "Pardin, C")
    ]

    private static let boxedExpected = [
        "1|08:00-10:00|Allemand I (T)|2.547", "1|10:00-11:00|Allemand I (L)|2.711",
        "1|13:00-15:00|Écriture et lit (T)|2.037", "1|15:00-17:00|Philosophie et (T)|2.913",
        "2|09:00-10:00|Évolution diver (T)|1.105", "2|10:00-12:00|Évolution diver (L)|1.614",
        "2|13:00-15:00|Chimie générale (L)|1.629 / 1.710", "2|15:00-16:00|Calcul différen (L)|2.005",
        "3|09:00-11:00|Philosophie et (T)|2.913", "3|16:00-17:30|Chimie générale (T)|2.045",
        "4|08:00-10:00|Écriture et lit (T)|2.037", "4|14:00-16:00|Calcul différen (T)|2.209",
        "5|08:00-10:00|Calcul différen (L)|2.005", "5|10:00-12:00|Évolution diver (L)|1.382", "5|14:00-15:30|Chimie générale (T)|2.045"
    ]

    private static let pageWidth = 790.0
    private static let pageHeight = 1023.0
    private static let columnCenters = [151.0, 286.0, 421.0, 556.0, 690.0]
    private static let firstRowTop = 287.0
    private static let rowHeight = 22.55

    /// A line of the report in pixels of the 790 x 1023 picture (centre x, centre y, width, height).
    private func pixelLine(_ text: String, _ cx: Double, _ cy: Double, _ width: Double = 80, _ height: Double = 9) -> RecognizedLine {
        let w = Self.pageWidth
        let h = Self.pageHeight
        return RecognizedLine(text: text, box: CGRect(x: (cx - width / 2) / w, y: (cy - height / 2) / h, width: width / w, height: height / h))
    }

    /// The page: the day headings, one label per half hour, the 15 blocks (their text centred, `bias` pixels lower) and,
    /// when asked, everything around the grid that is not a class.
    private func boxedPage(noise: Bool, bias: Double = 0) -> [RecognizedLine] {
        var lines: [RecognizedLine] = []
        for (column, name) in ["Lun. 26 août", "Mar. 27 août", "Mer. 28 août", "Jeu. 29 août", "Ven. 30 août"].enumerated() {
            lines.append(pixelLine(name, Self.columnCenters[column], 266, 90, 12))
        }
        for step in 0..<29 {
            let minutes = 8 * 60 + 30 * step
            lines.append(pixelLine(String(format: "%02d:%02d", minutes / 60, minutes % 60), 60, 295 + Self.rowHeight * Double(step), 36, 10))
        }
        for block in Self.blocks {
            let middle = (Self.firstRowTop + Self.rowHeight * Double(block.from + block.to) / 2) + bias
            let texts = [block.title, block.code] + block.rooms + [block.teacher]
            for (index, text) in texts.enumerated() {
                lines.append(pixelLine(text, Self.columnCenters[block.column], middle + (Double(index) - Double(texts.count - 1) / 2) * 11.5))
            }
        }
        if noise {
            lines += [pixelLine("Sciences", 412, 70, 140, 36), pixelLine("de la nature", 412, 108, 190, 36),
                      pixelLine("Horaire de l'étudiant", 680, 58, 170, 14), pixelLine("Semaine du 26 août 2019", 690, 81, 150, 11),
                      pixelLine("Nom, Prénom (No et code permanent)", 140, 143, 210, 10),
                      pixelLine("200.B0 - Sciences de la nature (1951120)", 160, 166, 250, 10),
                      pixelLine("SPE 1", 740, 143, 40, 10), pixelLine("GAB - Gabrielle-Roy", 710, 166, 120, 10),
                      pixelLine("Casier : H-6393", 80, 186, 100, 10), pixelLine("Messages à l'horaire", 85, 205, 110, 10),
                      pixelLine("7 cours / 15 blocs / 26 heures", 435, 215, 350, 22),
                      pixelLine("2019-11-07 14:29", 95, 975, 110, 10), pixelLine("RPHOR025 - Horaire de l'étudiant", 680, 975, 170, 10)]
            // Written over the grid, in the Wednesday column, between two blocks.
            for (y, text) in [(448.0, "Jamais de"), (470.0, "cours les"), (514.0, "mercredis"), (536.0, "midi")] {
                lines.append(pixelLine(text, Self.columnCenters[2], y, 100, 17))
            }
        }
        return lines
    }

    private func boxedProbe() -> FramedColumnsProbe {
        var outlines: [[Double]] = []
        for column in 0..<5 {
            var edges = Set<Double>()
            for block in Self.blocks where block.column == column {
                edges.insert(Self.firstRowTop + Self.rowHeight * Double(block.from))
                edges.insert(Self.firstRowTop + Self.rowHeight * Double(block.to))
            }
            outlines.append(edges.sorted())
        }
        return FramedColumnsProbe(outlines: outlines, edges: [84, 219, 354, 489, 623, 758], width: Self.pageWidth, height: Self.pageHeight)
    }

    func testBoxedBlocksPageWithTheOutlinesOfTheBlocks() {
        let found = ScheduleParser.slots(from: boxedPage(noise: true), probe: boxedProbe())
        XCTAssertEqual(Fx.summary(found), Self.boxedExpected)
        XCTAssertEqual(found.count, 15, "The heading says 15 blocks")
        XCTAssertTrue(found.allSatisfy { !$0.needsCheck }, "Nothing is in doubt in a clean reading")
    }

    func testBoxedBlocksPageWithoutTheImageFitsTheCentreOfTheText() {
        XCTAssertEqual(read(boxedPage(noise: true)), Self.boxedExpected)
        XCTAssertEqual(read(boxedPage(noise: false)), Self.boxedExpected)
        // The text a few pixels above the middle of its block, as printed.
        XCTAssertEqual(read(boxedPage(noise: true, bias: -6)), Self.boxedExpected)
    }

    func testBoxedBlocksOutlinesWinOverATextThatIsNotCentred() {
        XCTAssertEqual(Fx.summary(ScheduleParser.slots(from: boxedPage(noise: true, bias: 9), probe: boxedProbe())), Self.boxedExpected)
    }

    func testBoxedBlocksPageTotalsTheHoursOfTheHeading() {
        let hours = ScheduleParser.slots(from: boxedPage(noise: true), probe: boxedProbe()).reduce(0) { $0 + $1.endMinute - $1.startMinute }
        XCTAssertEqual(hours, 26 * 60, "The heading says 26 hours")
    }

    func testBoxedBlocksHoursFromTheLengthsOfTheTextAlone() {
        XCTAssertEqual(BoxedBlocksLayout.fit(centerMinute: 540, textMinutes: 40)?.start, 480, "centred on 9:00: two hours from 8:00")
        XCTAssertEqual(BoxedBlocksLayout.fit(centerMinute: 630, textMinutes: 40)?.start, 600, "centred on 10:30: one hour from 10:00")
        XCTAssertEqual(BoxedBlocksLayout.fit(centerMinute: 1005, textMinutes: 40)?.end, 1050, "centred on 16:45: 1 h 30 from 16:00")
        XCTAssertNil(BoxedBlocksLayout.fit(centerMinute: 555, textMinutes: 40), "centred on 9:15: no block that begins on the hour")
    }

    func testBoxedBlockContentKeepsTheTypeOfTheClassAndBothRooms() {
        let content = BoxedBlocksLayout.content(of: ["Chimie générale (L)", "202-NYA-05 g.00003", "1.629", "1.710", "Pardin, C"].map {
            RecognizedLine(text: $0, box: CGRect(x: 0, y: 0, width: 0.1, height: 0.01))
        })
        XCTAssertEqual(content?.title, "Chimie générale (L)")
        XCTAssertEqual(content?.room, "1.629 / 1.710")
        let note = ["Jamais de", "cours les"].map { RecognizedLine(text: $0, box: CGRect(x: 0, y: 0, width: 0.1, height: 0.01)) }
        XCTAssertNil(BoxedBlocksLayout.content(of: note), "A note over the grid is not a class")
    }

    func testBoxedPageIsNotMistakenForAnOmnivoxOneNorAWeekView() {
        // The same hours with their text at the top of each block would be a calendar: no code of a course, no claim.
        var lines = Fx.weekHeader(["Mon 21", "Tue 22", "Wed 23", "Thu 24", "Fri 25"], hourLabels: (8..<14).map { "\($0):00" })
        lines += Fx.event(0, startMinute: 540, "Calculus", hours: "9:00 - 10:30", room: "2.547")
        XCTAssertEqual(read(lines), ["1|09:00-10:30|Calculus|2.547"])
    }

    func testBoxedPageTiltedByAPhotoIsReadOnStraightenedLines() {
        let aspect = Self.pageHeight / Self.pageWidth
        for degrees in [1.0, 2.0, 3.0] {
            let photo = Fx.rotated(boxedPage(noise: true), degrees: degrees, aspect: aspect)
            XCTAssertEqual(read(photo, aspect: aspect), Self.boxedExpected, "tilt of \(degrees) degrees")
        }
    }

    func testACalendarWhoseTitlesHoldTheCodeOfACourseIsNotABoxedPage() {
        // Course codes alone do not make the page of the college report: no printed group "g.00001", no outlines.
        var lines = Fx.weekHeader(["Mon 21", "Tue 22", "Wed 23", "Thu 24", "Fri 25"], hourLabels: (8..<14).map { "\($0):00" })
        lines += Fx.event(0, startMinute: 540, "Algèbre", hours: "9:00 - 10:30")
        lines += [Fx.line("201-NYA-05", Fx.weekX[0], Fx.hourY(9) + 0.056)]
        XCTAssertEqual(read(lines), ["1|09:00-10:30|Algèbre 201-NYA-05|-"])
        XCTAssertFalse(BoxedBlocksLayout.matches(BoxedBlocksLayout.printedGroupRegex, "gr.41070"))
        XCTAssertTrue(BoxedBlocksLayout.matches(BoxedBlocksLayout.printedGroupRegex, "609-C01-HU g.00001"))
    }

    func testBoxedBlockWithFiveLinesOfTextInOneHourStaysOneHour() {
        // Text 1.2 times as tall as the block at most: still the hour, not an hour and a half.
        XCTAssertEqual(BoxedBlocksLayout.fit(centerMinute: 630, textMinutes: 70)?.end, 660)
    }

    // MARK: Colours of the image (the probe)

    /// A grey page with rectangles of other levels: `fills` are (x range, y range, level).
    private func canvas(width: Int, height: Int, level: UInt8, fills: [(x: Range<Int>, y: Range<Int>, level: UInt8)]) -> [UInt8] {
        var pixels = [UInt8](repeating: level, count: width * height)
        for fill in fills {
            for y in fill.y {
                for x in fill.x { pixels[y * width + x] = fill.level }
            }
        }
        return pixels
    }

    private func assertRuns(_ runs: [ClosedRange<Double>]?, _ expected: [(Int, Int)], height: Int, tolerance: Int = 3,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let runs = runs else { return XCTFail("no stretch", file: file, line: line) }
        XCTAssertEqual(runs.count, expected.count, "\(runs)", file: file, line: line)
        for (run, want) in zip(runs, expected) {
            XCTAssertEqual(run.lowerBound * Double(height), Double(want.0), accuracy: Double(tolerance), file: file, line: line)
            XCTAssertEqual(run.upperBound * Double(height), Double(want.1), accuracy: Double(tolerance), file: file, line: line)
        }
    }

    func testProbeFindsBlocksDarkerThanTheirPageAndLighterThanTheirPage() {
        let blocks: [(x: Range<Int>, y: Range<Int>, level: UInt8)] = [(0..<200, 100..<260, 225), (0..<200, 400..<520, 225)]
        // Pastel blocks on white: the darker kind of cell is the block.
        if let probe = LuminanceProbe(width: 400, height: 800, pixels: canvas(width: 400, height: 800, level: 255, fills: blocks)) {
            assertRuns(probe.darkRuns(atX: 0.1, fromY: 0.05, toY: 0.9), [(100, 260), (400, 520)], height: 800)
            assertRuns(probe.blockRuns(atX: 0.1, fromY: 0.05, toY: 0.9), [(40, 100), (260, 400), (520, 720)], height: 800)
        } else { XCTFail("no probe") }
        // Dark mode: blocks lighter than the page, the lighter kind of cell.
        let lighter: [(x: Range<Int>, y: Range<Int>, level: UInt8)] = [(0..<200, 100..<260, 90), (0..<200, 400..<520, 90)]
        if let probe = LuminanceProbe(width: 400, height: 800, pixels: canvas(width: 400, height: 800, level: 30, fills: lighter)) {
            assertRuns(probe.blockRuns(atX: 0.1, fromY: 0.05, toY: 0.9), [(100, 260), (400, 520)], height: 800)
        } else { XCTFail("no probe") }
        // Saturated blocks (a grey level of 120, darker than the usual text limit) on white.
        let saturated: [(x: Range<Int>, y: Range<Int>, level: UInt8)] = [(0..<200, 100..<260, 120), (0..<200, 400..<520, 120)]
        if let probe = LuminanceProbe(width: 400, height: 800, pixels: canvas(width: 400, height: 800, level: 255, fills: saturated)) {
            assertRuns(probe.darkRuns(atX: 0.1, fromY: 0.05, toY: 0.9), [(100, 260), (400, 520)], height: 800)
        } else { XCTFail("no probe") }
        // Dark blocks on a dark page, darker than the page.
        let darker: [(x: Range<Int>, y: Range<Int>, level: UInt8)] = [(0..<200, 100..<260, 25), (0..<200, 400..<520, 25)]
        if let probe = LuminanceProbe(width: 400, height: 800, pixels: canvas(width: 400, height: 800, level: 70, fills: darker)) {
            assertRuns(probe.darkRuns(atX: 0.1, fromY: 0.05, toY: 0.9), [(100, 260), (400, 520)], height: 800)
        } else { XCTFail("no probe") }
    }

    func testProbeTellsNothingOnAColumnOfOneKindOfCell() {
        if let probe = LuminanceProbe(width: 400, height: 800, pixels: canvas(width: 400, height: 800, level: 255, fills: [])) {
            XCTAssertNil(probe.blockRuns(atX: 0.1, fromY: 0.05, toY: 0.9))
            XCTAssertNil(probe.darkRuns(atX: 0.1, fromY: 0.05, toY: 0.9))
            XCTAssertNil(probe.framedRuns(atX: 0.1, fromY: 0.05, toY: 0.9))
        } else { XCTFail("no probe") }
    }

    func testProbeFindsTheStretchesBetweenThickBlackLines() {
        // A 790 x 1023 page: thin grey lines every 22 pixels, thick black lines (2 pixels) at the edges of three blocks,
        // dashes of text (dark, but never most of a row) inside them.
        let width = 790
        let height = 1023
        var fills: [(x: Range<Int>, y: Range<Int>, level: UInt8)] = []
        var y = 287
        while y < 940 {
            fills.append((x: 84..<219, y: y..<(y + 1), level: 225))
            y += 22
        }
        let edges = [287, 376, 422, 513, 603]
        for edge in edges { fills.append((x: 84..<219, y: edge..<(edge + 2), level: 20)) }
        for row in stride(from: 300, to: 360, by: 11) {
            for x in stride(from: 110, to: 190, by: 4) { fills.append((x: x..<(x + 2), y: row..<(row + 7), level: 40)) }
        }
        guard let probe = LuminanceProbe(width: width, height: height, pixels: canvas(width: width, height: height, level: 255, fills: fills)) else {
            return XCTFail("no probe")
        }
        let runs = probe.framedRuns(atX: 84.0 / 790 + 0.004, fromY: 280.0 / 1023, toY: 740.0 / 1023)
        assertRuns(runs, [(288, 377), (377, 423), (423, 514), (514, 604)], height: height)
        // On a dark page there is no black outline to find.
        if let dark = LuminanceProbe(width: 400, height: 800, pixels: canvas(width: 400, height: 800, level: 30, fills: [])) {
            XCTAssertNil(dark.framedRuns(atX: 0.1, fromY: 0.05, toY: 0.9))
        }
    }

    /// A grey image as the reader would hand it to the probe.
    private func image(width: Int, height: Int, pixels: [UInt8]) -> CGImage? {
        var data = pixels
        return data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> CGImage? in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return nil }
            return context.makeImage()
        }
    }

    func testOutlinesOfBlocksThatShareALineGiveSeparateStretchesThroughTheRealProbe() {
        // One column of a 790 x 1023 page: thick black lines (2 pixels) at 287, 376, 422, 513, 603 and 694, so the blocks
        // 287-376, 376-422 (stuck to it), 513-603 and 603-694 (stuck to it) and the empty cells between; thin grey lines
        // and dashes of text inside. Each stretch must stay on its own, and be where the lines are.
        let width = 790
        let height = 1023
        var fills: [(x: Range<Int>, y: Range<Int>, level: UInt8)] = []
        var y = 287
        while y < 940 {
            fills.append((x: 84..<219, y: y..<(y + 1), level: 225))
            y += 22
        }
        for edge in [287, 376, 422, 513, 603, 694] { fills.append((x: 84..<219, y: edge..<(edge + 2), level: 20)) }
        for row in stride(from: 300, to: 360, by: 11) {
            for x in stride(from: 110, to: 190, by: 4) { fills.append((x: x..<(x + 2), y: row..<(row + 7), level: 40)) }
        }
        let pixels = canvas(width: width, height: height, level: 255, fills: fills)
        guard let picture = image(width: width, height: height, pixels: pixels), let probe = LuminanceProbe(picture) else {
            return XCTFail("no probe")
        }
        let stretches = ScheduleParser.columnRuns(probe, left: CGFloat(84.0 / 790), from: 280.0 / 1023, to: 740.0 / 1023, kind: .framed)
        assertRuns(stretches, [(287, 376), (376, 422), (422, 513), (513, 603), (603, 694)], height: height, tolerance: 2)
        // The voting by places of the lines, from probes that disagree by a pixel or two.
        let voted = ScheduleParser.outlineStretches([
            [0.280...0.368, 0.368...0.412], [0.2803...0.3683, 0.3683...0.4123], [0.2797...0.3677, 0.3677...0.4117]
        ])
        XCTAssertEqual(voted.count, 2)
        let lone = ScheduleParser.outlineStretches([[0.28...0.37], [0.5...0.6], [0.7...0.8]])
        XCTAssertTrue(lone.isEmpty, "A line that only one probe saw is not kept")
    }

    func testProbeSecondLimitSeparatesBlocksDarkerThan150OnALightPage() {
        // Blocks at grey 140 (darker than the first limit) on white, with thin black lines across: the first pass, which
        // keeps what is above 150, sees one kind of cell only; the second one, above 60, finds the blocks.
        var fills: [(x: Range<Int>, y: Range<Int>, level: UInt8)] = [(0..<200, 100..<260, 140), (0..<200, 400..<520, 140)]
        for row in stride(from: 40, to: 720, by: 30) { fills.append((x: 0..<400, y: row..<(row + 1), level: 10)) }
        if let probe = LuminanceProbe(width: 400, height: 800, pixels: canvas(width: 400, height: 800, level: 255, fills: fills)) {
            assertRuns(probe.darkRuns(atX: 0.1, fromY: 0.05, toY: 0.9), [(101, 260), (401, 520)], height: 800)
        } else { XCTFail("no probe") }
    }

    // MARK: What is marked "to check"

    func testClassesThatOverlapOrLastLongAreMarkedAndTheOthersAreNot() {
        let slots = ScheduleParser.slots(from: Fx.list(["Lundi", "8h-10h Maths", "9h-11h Physique", "13h-14h Art"]))
        XCTAssertEqual(slots.map { $0.title }, ["Maths", "Physique", "Art"])
        XCTAssertEqual(slots.map { $0.needsCheck }, [true, true, false])
        let long = ScheduleParser.slots(from: Fx.list(["Lundi", "8h-14h Stage"]))
        XCTAssertEqual(long.map { $0.needsCheck }, [true], "Six hours is not a class")
    }

    func testAPageThatTheReadingMostlyDoesNotExplainMarksItsClassToCheck() {
        let lines = Fx.list(["Lundi", "8h-10h Maths", "Lorem ipsum dolor sit amet", "Consectetur adipiscing elit", "Sed do eiusmod tempor",
                             "Incididunt ut labore", "Magna aliqua enim", "Veniam quis nostrud", "Exercitation ullamco", "Laboris nisi aliquip"])
        let slots = ScheduleParser.slots(from: lines)
        XCTAssertEqual(slots.map { $0.title }, ["Maths"])
        XCTAssertEqual(slots.map { $0.needsCheck }, [true], "Almost nothing of the page is explained: look at it closely")
    }

    func testNothingReliableGivesNothing() {
        XCTAssertTrue(ScheduleParser.slots(from: Fx.list(["Facture n° 2026-1012", "Total : 123,45 €", "Merci de votre visite"])).isEmpty)
        XCTAssertTrue(ScheduleParser.slots(from: []).isEmpty)
    }

    func testScoringRulesOnReadyMadeClasses() {
        let good = ImportedSlot(weekday: 1, startMinute: 480, endMinute: 540, title: "Maths")
        XCTAssertFalse(ScheduleScoring.evaluate([good], lines: []).doubtful[0])
        let night = ImportedSlot(weekday: 1, startMinute: 180, endMinute: 240, title: "Maths")
        XCTAssertTrue(ScheduleScoring.evaluate([night], lines: []).doubtful[0])
        let noisy = ImportedSlot(weekday: 1, startMinute: 480, endMinute: 540, title: "12 34 56 a7")
        XCTAssertTrue(ScheduleScoring.evaluate([noisy], lines: []).doubtful[0])
        XCTAssertEqual(ScheduleScoring.evaluate([], lines: []).value, 0)
        XCTAssertFalse(ImportedSlot(weekday: 1, startMinute: 480, endMinute: 540, title: "x").needsCheck, "Not in doubt unless the reading says so")
    }
}
