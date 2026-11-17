import Foundation
import CoreGraphics

/// A work roster: the days as columns, one row per employee, the shifts in the cells ("Employé | Lun | Mar | Mer ...",
/// "Alice T. | 9h-17h | Congé | 12h-20h ..."). Vision gives each cell as a line, or a whole row as one line: a line is cut
/// into its hours and its words, each placed in the column under which it sits (by its place in the line).
///
/// It only reads a page that says it is a roster: a word of a work schedule on the page (`DocumentCues.work`), a header
/// whose first column names the people ("Employé", "Nom", "Name", "Mitarbeiter"), or at least two rows that each give a
/// name in the margin and only hours in their cells. The margin of a timetable holds hours or periods, never names, so a
/// timetable of classes is never read as a roster.
///
/// One name: its row is the person's schedule (selected, without the name). Several names: every row is proposed with its
/// name (`detail`), unticked, and the check screen lets the person keep their own row.
struct ShiftRosterLayout: ScheduleLayout {
    let name = "roster"
    let role = LayoutRole.document

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        ShiftRosterLayout.read(lines, cues: DocumentCues(lines: lines))
    }

    /// One column of days.
    struct Column {
        var day: Int
        var x: CGFloat
        var fuzzy: Bool
    }

    /// The row of day names: its columns, its bottom, its lines, and whether it names the column of the people.
    struct Header {
        var columns: [Column]
        var bottom: CGFloat
        var lineIndexes: Set<Int>
        var namesPeople: Bool
    }

    /// Words of the first column of a roster.
    static let peopleWords: Set<String> = [
        "employe", "employes", "employee", "employees", "nom", "noms", "name", "names", "personne", "person", "staff", "equipe",
        "team", "mitarbeiter", "empleado", "empleados", "nombre", "nome", "dipendente", "dipendenti", "funcionario",
        "collaborateur", "agent", "agents", "personnel", "氏名", "名前", "スタッフ"
    ]

    static func read(_ lines: [RecognizedLine], cues: DocumentCues) -> [ScheduleParser.Draft] {
        guard let header = header(in: lines) else { return [] }
        let columns = header.columns
        let count = columns.count
        let spacing = max((columns[count - 1].x - columns[0].x) / CGFloat(max(1, count - 1)), 0.02)
        let leftEdge = columns[0].x - spacing / 2
        let rightEdge = columns[count - 1].x + spacing / 2
        var body: [Int] = []
        for (index, line) in lines.enumerated() where !header.lineIndexes.contains(index) && line.box.midY > header.bottom {
            body.append(index)
        }
        // Hours written in the margin are the rows of a timetable (or of a calendar): a roster names people there, never hours.
        let marginHours = body.filter { lines[$0].box.maxX < leftEdge && ScheduleParser.timeOnly(lines[$0].text) != nil }.count
        guard marginHours < 2 else { return [] }
        let rowGroups = ScheduleParser.readingRowGroups(body.map { lines[$0] })

        struct Row {
            var label: String
            var drafts: [ScheduleParser.Draft]
            var onlyHours: Int
        }
        var rows: [Row] = []
        var timeLabels = 0
        for group in rowGroups {
            var labelWords: [String] = []
            var cellWords = [[String]](repeating: [], count: count)
            var cellTimes = [[(time: ScheduleParser.TimeFound, unsure: Bool)]](repeating: [], count: count)
            for position in group {
                let line = lines[body[position]]
                for piece in pieces(of: line) {
                    if piece.x < leftEdge {
                        if piece.time == nil { labelWords.append(piece.text) }
                        continue
                    }
                    guard piece.x <= rightEdge else { continue }
                    var nearest = 0
                    for column in 1..<count where abs(piece.x - columns[column].x) < abs(piece.x - columns[nearest].x) { nearest = column }
                    if let time = piece.time {
                        cellTimes[nearest].append((time: time, unsure: piece.unsure))
                    } else {
                        cellWords[nearest].append(piece.text)
                    }
                }
            }
            let label = ScheduleParser.cleanTitle(labelWords.joined(separator: " "))
            if !label.isEmpty, ScheduleParser.timeOnly(label) != nil || isPeriodLabel(label) { timeLabels += 1 }
            var drafts: [ScheduleParser.Draft] = []
            var onlyHours = 0
            for column in 0..<count where !cellTimes[column].isEmpty {
                var role = ScheduleParser.cleanTitle(cellWords[column].joined(separator: " "))
                if ScheduleParser.isUnreadableTitle(role) || ScheduleEvents.isOff(role) || ScheduleParser.isNoise(role) { role = "" }
                if role.isEmpty { onlyHours += 1 }
                for cell in cellTimes[column] {
                    var fields = ScheduleParser.timeFlags(cell.time)
                    if columns[column].fuzzy { fields.insert(.day) }
                    // Hours kept as written but not sure ("4h-12h", "22h-6h"): to check, unticked.
                    if cell.unsure { fields.formUnion([.start, .end]) }
                    drafts.append(ScheduleParser.Draft(weekday: columns[column].day, start: cell.time.start, end: cell.time.end,
                                                       title: role, room: nil, uncertain: fields, kind: .work, unselected: cell.unsure))
                }
            }
            guard !drafts.isEmpty else { continue }
            rows.append(Row(label: isName(label) ? label : "", drafts: drafts, onlyHours: onlyHours))
        }
        guard !rows.isEmpty, timeLabels * 2 < rows.count + 1 else { return [] }
        let named = rows.filter { !$0.label.isEmpty }
        let structural = named.count >= 2 && named.allSatisfy { $0.onlyHours >= 2 }
        // Rows without a name (one person's week in a grid) need the page to say it is a work schedule.
        let trusted = cues.work || (header.namesPeople && !named.isEmpty) || structural
        guard trusted else { return [] }
        let names = Set(named.map { ScheduleParser.fold($0.label) })
        var result: [ScheduleParser.Draft] = []
        for row in rows {
            if !cues.work, row.label.isEmpty { continue }
            for var draft in row.drafts {
                if names.count >= 2 {
                    draft.detail = row.label.isEmpty ? nil : row.label
                    draft.unselected = true
                }
                result.append(draft)
            }
        }
        return result
    }

    /// "1", "P2", "1re heure": the margin of a timetable, not a name.
    static func isPeriodLabel(_ text: String) -> Bool {
        let list = ScheduleParser.words(of: text)
        return !list.isEmpty && list.allSatisfy { ScheduleParser.isLabelToken($0) }
    }

    /// A name of a person in the margin: letters, not a day, not a word of the page ("Total", "Semaine").
    static func isName(_ text: String) -> Bool {
        guard text.filter({ $0.isLetter }).count >= 2, !isPeriodLabel(text), ScheduleParser.timeOnly(text) == nil else { return false }
        if ScheduleParser.leadingDays(in: text) != nil || ScheduleParser.isNoise(text) { return false }
        let list = ScheduleParser.words(of: text)
        return !list.contains { ["total", "totaux", "heures", "hours", "stunden", "ore", "horas"].contains($0) }
    }

    // MARK: Header

    /// The row of day names: a row found by the grid readings (three days or more), else a line that starts with the
    /// name of the people's column ("Employé Lun Mar Mer Jeu Ven"), whose days are placed by their place in the line.
    static func header(in lines: [RecognizedLine]) -> Header? {
        var best: ScheduleParser.Grid? = nil
        for grid in ScheduleParser.allGrids(in: lines) where grid.headers.count >= 3 {
            if let current = best, current.headers.count >= grid.headers.count { continue }
            best = grid
        }
        if let grid = best {
            let y = grid.headers.map { $0.y }.reduce(0, +) / CGFloat(grid.headers.count)
            let firstX = grid.headers[0].x
            let namesPeople = lines.contains { line in
                abs(line.box.midY - y) <= 0.025 && line.box.midX < firstX && namesThePeople(line.text)
            }
            return Header(columns: grid.headers.map { Column(day: $0.day, x: $0.x, fuzzy: $0.fuzzy) }, bottom: grid.bandBottom,
                          lineIndexes: grid.lineIndexes, namesPeople: namesPeople)
        }
        for (index, line) in lines.enumerated() {
            guard let columns = labelledDays(line) else { continue }
            return Header(columns: columns, bottom: line.box.maxY, lineIndexes: [index], namesPeople: true)
        }
        return nil
    }

    static func namesThePeople(_ text: String) -> Bool {
        if peopleWords.contains(where: { ScheduleScoring.hasCJK($0) && text.contains($0) }) { return true }
        return ScheduleParser.words(of: text).contains { peopleWords.contains($0) }
    }

    /// "Employé Lun Mar Mer Jeu Ven": one or two words naming the people, then three day names or more, each placed at its
    /// place in the line.
    static func labelledDays(_ line: RecognizedLine) -> [Column]? {
        let tokens = ScheduleParser.headerTokens(line.text)
        guard tokens.count >= 4, tokens.count <= 10 else { return nil }
        var lead = 0
        while lead < min(2, tokens.count), dayOf(tokens[lead].token) == nil { lead += 1 }
        guard lead >= 1, namesThePeople(tokens[0..<lead].map { $0.token }.joined(separator: " ")) else { return nil }
        var columns: [Column] = []
        for token in tokens[lead...] {
            guard let day = dayOf(token.token), !columns.contains(where: { $0.day == day }) else { return nil }
            let middle = (token.from + token.to) / 2
            columns.append(Column(day: day, x: line.box.minX + CGFloat(middle) * line.box.width, fuzzy: false))
        }
        return columns.count >= 3 ? columns : nil
    }

    static func dayOf(_ token: String) -> Int? {
        let key = ScheduleParser.dayKey(token)
        return ScheduleParser.strongDays[key] ?? ScheduleParser.weakDays[key]
    }

    // MARK: Pieces of a line

    /// One part of a line: a range of hours, or a word, with the place (0...1 of the page width) where it sits.
    struct Piece {
        var text: String
        var time: ScheduleParser.TimeFound?
        var x: CGFloat
        /// A range read as written whose hours are not sure (see `ScheduleEvents.unsureShifts`).
        var unsure = false
    }

    /// The ranges of hours of a line and its other words, each with its place estimated from its place among the characters.
    static func pieces(of line: RecognizedLine) -> [Piece] {
        let length = (line.text as NSString).length
        guard length > 0 else { return [] }
        func place(_ location: Int, _ size: Int) -> CGFloat {
            line.box.minX + line.box.width * CGFloat(Double(location) + Double(size) / 2) / CGFloat(length)
        }
        var result: [Piece] = []
        // The ranges whose hours the rules of a timetable would change or drop ("4h-12h", "22h-6h") are read first, as written.
        let unsure = ScheduleEvents.unsureShifts(in: line.text)
        for shift in unsure {
            let time = ScheduleParser.TimeFound(start: shift.start, end: shift.end, range: shift.range)
            result.append(Piece(text: (line.text as NSString).substring(with: shift.range), time: time,
                                x: place(shift.range.location, shift.range.length), unsure: true))
        }
        var masked = ScheduleEvents.masking(unsure, in: line.text)
        while result.count < 14, let found = ScheduleParser.findTime(in: masked), found.end != nil {
            let original = (line.text as NSString).substring(with: found.range)
            result.append(Piece(text: original, time: found, x: place(found.range.location, found.range.length)))
            masked = (masked as NSString).replacingCharacters(in: found.range, with: String(repeating: " ", count: found.range.length))
        }
        let ns = masked as NSString
        var start: Int? = nil
        for index in 0...length {
            let isSpace = index == length || ns.character(at: index) == 32
            if isSpace {
                if let begin = start {
                    let word = ns.substring(with: NSRange(location: begin, length: index - begin))
                    result.append(Piece(text: word, time: nil, x: place(begin, index - begin)))
                    start = nil
                }
            } else if start == nil {
                start = index
            }
        }
        return result.sorted { $0.x < $1.x }
    }
}
