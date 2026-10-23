import XCTest
@testable import Tessera

/// Pages of text laid out in other ways than the Omnivox screenshots: calendar week views, school grids with periods,
/// transposed grids, lists and tables, university exports. The lines are written by hand with a place on the page
/// (0...1, origin at the top left), the way Vision would return them; no image and no Vision are involved.
enum LayoutFixtures {
    /// A line of text centred on (cx, cy).
    static func line(_ text: String, _ cx: Double, _ cy: Double, _ width: Double = 0.12, _ height: Double = 0.016) -> RecognizedLine {
        RecognizedLine(text: text, box: CGRect(x: cx - width / 2, y: cy - height / 2, width: width, height: height))
    }

    /// Lines stacked from top to bottom at the left: a day-by-day list.
    static func list(_ texts: [String]) -> [RecognizedLine] {
        texts.enumerated().map { index, text in
            RecognizedLine(text: text, box: CGRect(x: 0.1, y: 0.05 + Double(index) * 0.04, width: 0.6, height: 0.02))
        }
    }

    static func hm(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    /// Day, hours, title and room of each class, one line each.
    static func summary(_ slots: [ImportedSlot]) -> [String] {
        slots.map { "\($0.weekday)|\(hm($0.startMinute))-\(hm($0.endMinute))|\($0.title)|\($0.room ?? "-")" }
    }

    /// A page turned by `degrees` around its centre (pixels W wide and H = aspect x W high), as a tilted photo.
    static func rotated(_ lines: [RecognizedLine], degrees: Double, aspect: Double) -> [RecognizedLine] {
        let angle = degrees * Double.pi / 180
        return lines.map { item in
            let px = Double(item.box.midX) - 0.5
            let py = (Double(item.box.midY) - 0.5) * aspect
            let rx = px * cos(angle) - py * sin(angle)
            let ry = px * sin(angle) + py * cos(angle)
            let cx = 0.5 + rx
            let cy = 0.5 + ry / aspect
            return RecognizedLine(text: item.text, box: CGRect(x: cx - Double(item.box.width) / 2, y: cy - Double(item.box.height) / 2,
                                                               width: Double(item.box.width), height: Double(item.box.height)))
        }
    }

    // MARK: Calendar week view

    static let weekX = [0.22, 0.36, 0.50, 0.64, 0.78]

    /// Height of an hour line: 8:00 at 0.15, 0.08 per hour.
    static func hourY(_ hours: Double) -> Double { 0.15 + 0.08 * (hours - 8) }

    static func weekHeader(_ names: [String], hourLabels: [String]) -> [RecognizedLine] {
        var lines: [RecognizedLine] = []
        for (index, name) in names.enumerated() { lines.append(line(name, weekX[index], 0.07, 0.1)) }
        for (index, label) in hourLabels.enumerated() { lines.append(line(label, 0.07, hourY(8 + Double(index)), 0.08)) }
        return lines
    }

    /// An event of the week view: its title (and hours, room) written from the top of its block.
    static func event(_ column: Int, startMinute: Int, _ title: String, hours: String? = nil, room: String? = nil) -> [RecognizedLine] {
        let top = hourY(Double(startMinute) / 60)
        let cx = weekX[column]
        var lines = [line(title, cx, top + 0.012)]
        var y = top + 0.034
        if let hours = hours {
            lines.append(line(hours, cx, y))
            y += 0.022
        }
        if let room = room { lines.append(line(room, cx, y)) }
        return lines
    }

    // MARK: School grid

    static let schoolX = [0.26, 0.40, 0.54, 0.68, 0.82]
    static let periodLabels = ["8h00-9h00", "9h00-10h00", "10h15-11h15", "11h15-12h15", "13h30-14h30", "14h30-15h30"]

    static func schoolHeader(_ names: [String]) -> [RecognizedLine] {
        names.enumerated().map { line($1, schoolX[$0], 0.08, 0.1) }
    }

    static func rowY(_ row: Int, step: Double = 0.1) -> Double { 0.18 + step * Double(row) }

    static func marginLabels(_ labels: [String], step: Double = 0.1) -> [RecognizedLine] {
        labels.enumerated().map { line($1, 0.10, rowY($0, step: step), 0.14) }
    }

    /// The text of one cell: a subject, and a room under it.
    static func cell(_ column: Int, _ row: Int, _ title: String, _ room: String? = nil, step: Double = 0.1) -> [RecognizedLine] {
        var lines = [line(title, schoolX[column], rowY(row, step: step) - (room == nil ? 0 : 0.008), 0.1)]
        if let room = room { lines.append(line(room, schoolX[column], rowY(row, step: step) + 0.008, 0.1)) }
        return lines
    }

    /// A school page with six classes (the one the tilted photos are made of).
    static func schoolPage() -> [RecognizedLine] {
        var lines = schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]) + marginLabels(periodLabels)
        lines += cell(0, 0, "Maths", "B12") + cell(1, 0, "Français", "C30") + cell(0, 1, "Histoire", "A10")
        lines += cell(4, 2, "Chimie", "Lab 2") + cell(2, 4, "Sport") + cell(3, 5, "Art")
        return lines
    }

    static let schoolExpected = [
        "1|08:00-09:00|Maths|B12", "1|09:00-10:00|Histoire|A10", "2|08:00-09:00|Français|C30",
        "3|13:30-14:30|Sport|-", "4|14:30-15:30|Art|-", "5|10:15-11:15|Chimie|Lab 2"
    ]
}

/// Plays the probe over a calendar: the stretches of the blocks and of the empty page, per column.
struct ColourColumnsProbe: BlockProbe {
    var edges: [Double]
    var lighter: [[ClosedRange<Double>]]?
    var darker: [[ClosedRange<Double>]]?

    private func cut(_ columns: [[ClosedRange<Double>]]?, _ x: Double, _ fromY: Double, _ toY: Double) -> [ClosedRange<Double>]? {
        guard let columns = columns else { return nil }
        guard let column = (0..<columns.count).first(where: { x >= edges[$0] && x < edges[$0 + 1] }) else { return [] }
        var pieces: [ClosedRange<Double>] = []
        for run in columns[column] {
            let low = max(run.lowerBound, fromY)
            let high = min(run.upperBound, toY)
            if low < high { pieces.append(low...high) }
        }
        return pieces
    }

    func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? { cut(lighter, x, fromY, toY) }
    func darkRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? { cut(darker, x, fromY, toY) }

    /// The blocks (column, start hour, end hour) as the darker kind of cell on a light page, or as the lighter kind
    /// on a dark page (`blocksAreDarker` false); the rest of the page is the other kind.
    static func calendar(blocks: [(column: Int, from: Double, to: Double)], blocksAreDarker: Bool) -> ColourColumnsProbe {
        let edges = (0...5).map { 0.15 + 0.14 * Double($0) }
        var blockRuns = [[ClosedRange<Double>]](repeating: [], count: 5)
        var pageRuns = [[ClosedRange<Double>]](repeating: [], count: 5)
        for column in 0..<5 {
            let mine = blocks.filter { $0.column == column }.sorted { $0.from < $1.from }
            var cursor = 0.1
            for block in mine {
                let low = LayoutFixtures.hourY(block.from)
                let high = LayoutFixtures.hourY(block.to)
                blockRuns[column].append(low...high)
                if low > cursor { pageRuns[column].append(cursor...low) }
                cursor = high
            }
            if cursor < 0.99 { pageRuns[column].append(cursor...0.99) }
        }
        return blocksAreDarker
            ? ColourColumnsProbe(edges: edges, lighter: pageRuns, darker: blockRuns)
            : ColourColumnsProbe(edges: edges, lighter: blockRuns, darker: pageRuns)
    }
}

final class ScheduleParserLayoutsTests: XCTestCase {
    private typealias Fx = LayoutFixtures

    private func read(_ lines: [RecognizedLine], probe: BlockProbe? = nil) -> [String] {
        Fx.summary(ScheduleParser.slots(from: lines, probe: probe))
    }

    // MARK: 1. Calendar week view (Google Agenda, Apple Calendrier, Outlook, Teams)

    func testWeekViewEventsThatShowTheirHours() {
        let hours = (8..<18).map { String(format: "%02d:00", $0) }
        var lines = Fx.weekHeader(["lun. 21", "mar. 22", "mer. 23", "jeu. 24", "ven. 25"], hourLabels: hours)
        lines += Fx.event(0, startMinute: 510, "Maths", hours: "8:30 – 10:00", room: "Salle 12")
        lines += Fx.event(1, startMinute: 600, "Physique", hours: "10:00 – 11:30")
        lines += Fx.event(3, startMinute: 780, "Anglais", hours: "13:00 – 14:00", room: "B-204")
        XCTAssertEqual(read(lines), ["1|08:30-10:00|Maths|Salle 12", "2|10:00-11:30|Physique|-", "4|13:00-14:00|Anglais|B-204"])
    }

    func testWeekViewTitlesOnlyTakeTheirEndFromTheBlocksWhateverTheTheme() {
        let labels = [8, 9, 10, 11].map { "\($0) AM" } + ["12 PM"] + (1...5).map { "\($0) PM" }
        var lines = Fx.weekHeader(["Mon 21", "Tue 22", "Wed 23", "Thu 24", "Fri 25"], hourLabels: labels)
        lines += Fx.event(0, startMinute: 540, "Calculus") + Fx.event(2, startMinute: 600, "Biology") + Fx.event(2, startMinute: 780, "Chemistry")
        let blocks: [(column: Int, from: Double, to: Double)] = [(0, 9, 11), (2, 10, 11.5), (2, 13, 14)]
        let expected = ["1|09:00-11:00|Calculus|-", "3|10:00-11:30|Biology|-", "3|13:00-14:00|Chemistry|-"]
        // Coloured blocks darker than the page, then (dark mode) blocks lighter than the page: the same reading.
        XCTAssertEqual(read(lines, probe: ColourColumnsProbe.calendar(blocks: blocks, blocksAreDarker: true)), expected)
        XCTAssertEqual(read(lines, probe: ColourColumnsProbe.calendar(blocks: blocks, blocksAreDarker: false)), expected)
        // Without the colours the usual length (one hour) is used.
        XCTAssertEqual(read(lines), ["1|09:00-10:00|Calculus|-", "3|10:00-11:00|Biology|-", "3|13:00-14:00|Chemistry|-"])
    }

    func testWeekViewIgnoresTheAllDayRowAndTheTimeZoneLabel() {
        let labels = [8, 9, 10, 11].map { "\($0) AM" } + ["12 PM"] + (1...5).map { "\($0) PM" }
        var lines = Fx.weekHeader(["Mon 21", "Tue 22", "Wed 23", "Thu 24", "Fri 25"], hourLabels: labels)
        lines += [Fx.line("GMT-05", 0.07, 0.1, 0.08), Fx.line("Holiday", 0.50, 0.11, 0.1), Fx.line("all-day", 0.07, 0.115, 0.08)]
        lines += Fx.event(0, startMinute: 540, "Calculus", hours: "9:00 – 10:30 AM") + Fx.event(1, startMinute: 840, "Lab", hours: "2:00 – 4:00 PM", room: "Room 5")
        XCTAssertEqual(read(lines), ["1|09:00-10:30|Calculus|-", "2|14:00-16:00|Lab|Room 5"])
    }

    func testWeekHeaderWithTheInitialsOfTheDays() {
        // The Apple Calendar header: "L M M J V", the letters side by side in one line.
        var lines = [RecognizedLine(text: "L M M J V", box: CGRect(x: 0.15, y: 0.06, width: 0.7, height: 0.02))]
        lines += (8..<12).map { Fx.line(String(format: "%02d:00", $0), 0.07, Fx.hourY(Double($0)), 0.08) }
        lines += Fx.event(1, startMinute: 600, "Biologie", hours: "10:00 – 11:30")
        let found = ScheduleParser.slots(from: lines)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.title, "Biologie")
        XCTAssertEqual(found.first?.startMinute, 600)
    }

    // MARK: 2. School grid with periods in the first column

    func testSchoolGridWithTheHoursOfEachRowInTheMargin() {
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]) + Fx.marginLabels(Fx.periodLabels)
        lines += Fx.cell(0, 0, "Maths", "B12") + Fx.cell(1, 0, "Français", "C30") + Fx.cell(0, 1, "Histoire", "A10")
        lines += Fx.cell(4, 2, "Chimie", "Lab 2") + Fx.cell(2, 4, "Sport")
        XCTAssertEqual(read(lines), ["1|08:00-09:00|Maths|B12", "1|09:00-10:00|Histoire|A10", "2|08:00-09:00|Français|C30",
                                    "3|13:30-14:30|Sport|-", "5|10:15-11:15|Chimie|Lab 2"])
    }

    func testDenseSchoolGridWithABreakAndAClassOnTwoRows() {
        // Rows only 0.035 apart: the cells touch, and Vision gives a line for each text. The break row is not a class;
        // the same class on two following rows is one class (and the lunch hour keeps the afternoon one apart).
        let step = 0.035
        var lines = [Fx.line("Classe 3B - Horaire 2026-2027", 0.5, 0.03, 0.5)] + Fx.schoolHeader(["Lun", "Mar", "Mer", "Jeu", "Ven"])
        lines += Fx.marginLabels(Fx.periodLabels.map { $0.replacingOccurrences(of: "-", with: " - ") }, step: step)
        lines += Fx.cell(0, 0, "Maths", "B12", step: step) + Fx.cell(0, 1, "Anglais", "B12", step: step) + Fx.cell(1, 0, "Sport", step: step)
        lines += (0..<5).map { Fx.line("Récréation", Fx.schoolX[$0], Fx.rowY(2, step: step), 0.1) }
        lines += Fx.cell(2, 3, "Histoire", "A10", step: step) + Fx.cell(2, 4, "Histoire", "A10", step: step)
        XCTAssertEqual(read(lines), ["1|08:00-09:00|Maths|B12", "1|09:00-10:00|Anglais|B12", "2|08:00-09:00|Sport|-",
                                    "3|11:15-12:15|Histoire|A10", "3|13:30-14:30|Histoire|A10"])
    }

    func testSchoolGridDoublePeriodWrittenBetweenTwoRows() {
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]) + Fx.marginLabels(Fx.periodLabels)
        let middle = (Fx.rowY(0) + Fx.rowY(1)) / 2
        lines += [Fx.line("Physique", Fx.schoolX[3], middle - 0.008, 0.1), Fx.line("Labo 4", Fx.schoolX[3], middle + 0.008, 0.1)]
        lines += Fx.cell(0, 3, "Latin")
        XCTAssertEqual(read(lines), ["1|11:15-12:15|Latin|-", "4|08:00-10:00|Physique|Labo 4"])
    }

    func testSchoolGridWithPeriodNamesAndFusedLinesInAnyOrder() {
        // "Period 1 8:15-9:05" in the margin, header and cells read as whole lines, lines in a jumbled order.
        var lines = Fx.schoolHeader(["Mon", "Tue", "Wed", "Thu", "Fri"])
        lines += Fx.marginLabels(["Period 1 8:15-9:05", "Period 2 9:10-10:00", "Period 3 10:15-11:05"])
        lines += [Fx.line("Math Rm 204", Fx.schoolX[0], Fx.rowY(0), 0.1), Fx.line("Art", Fx.schoolX[3], Fx.rowY(1), 0.1),
                  Fx.line("Science", Fx.schoolX[2], Fx.rowY(2), 0.1), Fx.line("Lunch", Fx.schoolX[2], Fx.rowY(1), 0.1)]
        lines.reverse()
        XCTAssertEqual(read(lines), ["1|08:15-09:05|Math|Rm 204", "3|10:15-11:05|Science|-", "4|09:10-10:00|Art|-"])
    }

    // MARK: 3. Transposed grid (days as rows, hours as columns)

    func testTransposedGridWithRangesAsColumns() {
        let rows = [0.25, 0.35, 0.45, 0.55, 0.65]
        var lines = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"].enumerated().map { Fx.line($1, 0.07, rows[$0], 0.1) }
        lines += ["8h-9h", "9h-10h", "10h-11h", "11h-12h"].enumerated().map { Fx.line($1, [0.28, 0.44, 0.60, 0.76][$0], 0.12, 0.1) }
        lines += [Fx.line("Maths", 0.28, rows[0] - 0.008, 0.1), Fx.line("B12", 0.28, rows[0] + 0.008, 0.1),
                  Fx.line("Anglais", 0.60, rows[0], 0.1), Fx.line("Sport", 0.44, rows[2], 0.1)]
        XCTAssertEqual(read(lines), ["1|08:00-09:00|Maths|B12", "1|10:00-11:00|Anglais|-", "3|09:00-10:00|Sport|-"])
    }

    func testTransposedGridWithHourLabelsAtTheEdgeOfTheirColumnAndAClassOverTwoColumns() {
        let rows = [0.25, 0.35, 0.45, 0.55, 0.65]
        var lines = ["Mon", "Tue", "Wed", "Thu", "Fri"].enumerated().map { Fx.line($1, 0.07, rows[$0], 0.1) }
        // The labels sit on the left edge of their column; the cells are between two labels.
        lines += ["8:00", "9:00", "10:00", "11:00"].enumerated().map { Fx.line($1, [0.20, 0.36, 0.52, 0.68][$0], 0.12, 0.06) }
        lines += [Fx.line("Physics", 0.28, rows[1], 0.1), Fx.line("Lab", 0.52, rows[3], 0.31)]
        XCTAssertEqual(read(lines), ["2|08:00-09:00|Physics|-", "4|09:00-11:00|Lab|-"])
    }

    // MARK: 4. Lists and tables

    func testListWithDashesBeforeTheRoomAndAColonAfterTheDay() {
        let lines = Fx.list(["Lundi", "8h-10h Maths — salle 12", "10h15-11h45 Physique - Salle B-204", "Mardi :", "13h30-15h Anglais"])
        XCTAssertEqual(read(lines), ["1|08:00-10:00|Maths|salle 12", "1|10:15-11:45|Physique|Salle B-204", "2|13:30-15:00|Anglais|-"])
    }

    private func tableRow(_ y: Double, _ cells: [String?]) -> [RecognizedLine] {
        let xs = [0.05, 0.22, 0.32, 0.45, 0.75]
        var lines: [RecognizedLine] = []
        for (index, cell) in cells.enumerated() {
            if let cell = cell { lines.append(Fx.line(cell, xs[index], y, 0.09)) }
        }
        return lines
    }

    func testTableDayStartEndSubjectRoomReadAsSeparateLines() {
        var lines = tableRow(0.1, ["Jour", "Début", "Fin", "Matière", "Salle"])
        lines += tableRow(0.16, ["Lundi", "08:00", "10:00", "Maths", "B12"]) + tableRow(0.22, ["Lundi", "10:15", "11:45", "Physique", "C30"])
        lines += tableRow(0.28, ["Mercredi", "13:00", "14:30", "Anglais", nil])
        XCTAssertEqual(read(lines), ["1|08:00-10:00|Maths|B12", "1|10:15-11:45|Physique|C30", "3|13:00-14:30|Anglais|-"])
    }

    func testTableWithHoursWithoutMinutesAndAPageNumber() {
        var lines = tableRow(0.1, ["Jour", "Début", "Fin", "Matière", "Salle"]) + [Fx.line("Page 1 / 2", 0.5, 0.95)]
        lines += tableRow(0.16, ["Lun", "8h", "10h", "Maths", "B12"]) + tableRow(0.2205, ["Lun", "10h15", "11h45", "Physique", "C30"])
        lines += tableRow(0.28, ["Ven", "14:00", "16:00", "Labo", nil])
        XCTAssertEqual(read(lines), ["1|08:00-10:00|Maths|B12", "1|10:15-11:45|Physique|C30", "5|14:00-16:00|Labo|-"])
    }

    // MARK: 5. University exports (ADE, Moodle, Celcat)

    func testUniversityListWithCourseTypesAndCodes() {
        let lines = Fx.list(["Lundi 08:00-10:00 CM Analyse Amphi B", "Lundi 10:15-12:15 TD Algèbre Salle C204",
                             "Mardi 14:00-16:00 TP Informatique Salle 105", "Jeudi 08:00-10:00 UE 301 Probabilités Amphi A"])
        XCTAssertEqual(read(lines), ["1|08:00-10:00|CM Analyse|Amphi B", "1|10:15-12:15|TD Algèbre|Salle C204",
                                    "2|14:00-16:00|TP Informatique|Salle 105", "4|08:00-10:00|UE 301 Probabilités|Amphi A"])
    }

    func testUniversityExportWithDatesTeachersAndAPrintLine() {
        let lines = Fx.list(["Mardi 21 octobre", "08:00 - 10:00 CM Algorithmique (Amphi A) - Dupont J.",
                             "10:15 - 12:15 TD Réseaux Salle 210 - Mme Durand", "Imprimé le 20/10/2026",
                             "Mercredi 22 octobre", "14:00 - 16:00 TP Bases de données Salle 12"])
        XCTAssertEqual(read(lines), ["2|08:00-10:00|CM Algorithmique|Amphi A", "2|10:15-12:15|TD Réseaux|Salle 210",
                                    "3|14:00-16:00|TP Bases de données|Salle 12"])
    }
}
