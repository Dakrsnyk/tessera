import Foundation
import CoreGraphics

/// A school grid: the days are the columns, the rows are periods named in the left margin, and each cell holds a
/// subject (and maybe a room). The margin gives the hours of each row in one of three ways:
/// - two hours stacked or side by side ("9:00" over "10:30"), as in Japanese university timetables;
/// - a range with or without the name of the period ("8h00-9h00", "Période 1 8:15-9:05", "1限 9:00-10:30");
/// - only the number of the period ("1", "P2", "3e heure"), whose hours are in a legend of the page ("P1 8:00-8:50 P2
///   8:55-9:45 ..." or "1限 9:00-10:30" written anywhere).
/// Each text is given to the row it sits in, so cells stuck together (a dense table) are not mixed up; a text between
/// two rows is a class over both rows; the same class on two following rows is one class.
struct PeriodGridLayout: ScheduleLayout {
    let name = "periodGrid"
    let role = LayoutRole.grid

    /// A row of the grid: where it is on the page (centre of its label) and its hours.
    struct Row {
        var y: CGFloat
        var start: Int
        var end: Int
    }

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        guard let grid = ScheduleParser.detectGrid(in: lines), grid.headers.count >= 2 else { return [] }
        let headers = grid.headers
        let count = headers.count
        let edges = ScheduleParser.columnEdges(headers)
        let margin = ScheduleParser.marginLines(lines, grid: grid, edges: edges)
        guard let rows = PeriodGridLayout.rows(margin: margin, lines: lines), rows.count >= 2 else { return [] }
        let n = rows.count
        let centers = rows.map { $0.y }
        // The edges of the rows: halfway between two labels (half a row at the two ends).
        var bounds = [CGFloat](repeating: 0, count: n + 1)
        for k in 1..<n { bounds[k] = (centers[k - 1] + centers[k]) / 2 }
        bounds[0] = centers[0] - (centers[1] - centers[0]) / 2
        bounds[n] = centers[n - 1] + (centers[n - 1] - centers[n - 2]) / 2
        var columns = [[RecognizedLine]](repeating: [], count: count)
        for (index, line) in lines.enumerated() {
            if grid.lineIndexes.contains(index) { continue }
            let y = line.box.midY
            let x = line.box.midX
            guard y > grid.bandBottom, y >= bounds[0], y <= bounds[n], x >= edges[0], x < edges[count] else { continue }
            columns[ScheduleParser.columnIndex(of: x, edges: edges)].append(line)
        }
        var drafts: [ScheduleParser.Draft] = []
        for (column, columnLines) in columns.enumerated() {
            drafts.append(contentsOf: PeriodGridLayout.draftsOfColumn(columnLines, weekday: headers[column].day,
                                                                      rows: rows, centers: centers))
        }
        return drafts
    }

    /// The classes of one column: its lines are given to the rows, then each cell becomes a class.
    private static func draftsOfColumn(_ lines: [RecognizedLine], weekday: Int, rows: [Row],
                                       centers: [CGFloat]) -> [ScheduleParser.Draft] {
        let n = rows.count
        var regular: [Int: [RecognizedLine]] = [:]
        var straddle: [Int: [RecognizedLine]] = [:]
        for line in lines.sorted(by: { $0.box.midY < $1.box.midY }) {
            let y = line.box.midY
            if y <= centers[0] { regular[0, default: []].append(line); continue }
            if y >= centers[n - 1] { regular[n - 1, default: []].append(line); continue }
            var i = 0
            while i < n - 2, y >= centers[i + 1] { i += 1 }
            let fraction = (y - centers[i]) / (centers[i + 1] - centers[i])
            if fraction >= 0.38, fraction <= 0.62 {
                // Halfway between two rows: a cell over both (the text of a merged cell is centred in it).
                straddle[i, default: []].append(line)
            } else {
                regular[fraction < 0.5 ? i : i + 1, default: []].append(line)
            }
        }
        var cells: [(first: Int, last: Int, lines: [RecognizedLine])] = []
        for boundary in straddle.keys.sorted() {
            let held = straddle[boundary] ?? []
            if regular[boundary] != nil || regular[boundary + 1] != nil {
                // One of the two rows has a text of its own: these lines belong to their nearest row.
                for line in held {
                    let y = line.box.midY
                    let row = (y - centers[boundary]) < (centers[boundary + 1] - y) ? boundary : boundary + 1
                    regular[row, default: []].append(line)
                }
            } else {
                cells.append((first: boundary, last: boundary + 1, lines: held))
            }
        }
        for row in regular.keys.sorted() {
            cells.append((first: row, last: row, lines: regular[row] ?? []))
        }
        cells.sort { $0.first < $1.first }
        var found: [ScheduleParser.Draft] = []
        for cell in cells {
            let ordered = cell.lines.sorted { $0.box.minY < $1.box.minY }
            if let draft = ScheduleParser.cellDraft(ordered, weekday: weekday, start: rows[cell.first].start, end: rows[cell.last].end) {
                found.append(draft)
            }
        }
        // The same class written in two following rows is one class (a break of a quarter of an hour at most).
        var merged: [ScheduleParser.Draft] = []
        for draft in found {
            if var previous = merged.last, let previousEnd = previous.end,
               ScheduleParser.fold(previous.title) == ScheduleParser.fold(draft.title), previous.room == draft.room,
               draft.start - previousEnd <= 15, draft.start >= previous.start {
                previous.end = draft.end
                merged[merged.count - 1] = previous
            } else {
                merged.append(draft)
            }
        }
        return merged
    }

    // MARK: Rows of the margin

    /// The rows named by the margin, top to bottom; nil when it names fewer than two.
    static func rows(margin: [RecognizedLine], lines: [RecognizedLine]) -> [Row]? {
        if let timeline = ScheduleParser.Timeline(margin: margin) {
            return timeline.rows.map { Row(y: ($0.startY + $0.endY) / 2, start: $0.start, end: $0.end) }
        }
        var ranges: [Row] = []
        for line in margin.sorted(by: { $0.box.midY < $1.box.midY }) {
            guard let found = ScheduleParser.timeOnly(line.text), let end = found.end else { continue }
            if let last = ranges.last, line.box.midY <= last.y + 0.001 { continue }
            ranges.append(Row(y: line.box.midY, start: found.start, end: end))
        }
        if ranges.count >= 2 { return ranges }
        // Only the numbers of the periods: their hours are in a legend somewhere on the page.
        let legend = periodLegend(lines)
        var numbered: [Row] = []
        for line in margin.sorted(by: { $0.box.midY < $1.box.midY }) {
            if ScheduleParser.timeOnly(line.text) != nil { continue }
            guard let number = periodNumber(line.text), let hours = legend[number], let end = hours.end else { continue }
            if let last = numbered.last, line.box.midY <= last.y + 0.001 { continue }
            numbered.append(Row(y: line.box.midY, start: hours.start, end: end))
        }
        return numbered.count >= 2 ? numbered : nil
    }

    // MARK: Number of a period and legend

    static let periodNumberRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:(?:periode|period|per|p|stunde|std|lesson|heure|hora|ora|cours|clase)\.?\s?)?(\d{1,2})\s?(?:限|時限|時間目|ere|er|re|eme|e|st|nd|rd|th|a|o|\.)?(?:\s?(?:heure|hour|stunde|hora|ora|periode|period|lesson|cours))?$"#,
        options: [])
    static let periodNumberKanjiRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^第\s?(\d{1,2})\s?(?:限|時限|時間目)$"#, options: [])

    /// "1", "P2", "3e heure", "Période 4", "5. Stunde", "1限", "第2限": the number of a period and nothing else.
    static func periodNumber(_ text: String) -> Int? {
        let folded = ScheduleParser.fold(text).trimmingCharacters(in: .whitespaces)
        let range = NSRange(location: 0, length: (folded as NSString).length)
        for regex in [periodNumberKanjiRegex, periodNumberRegex] {
            guard let regex = regex, let match = regex.firstMatch(in: folded, options: [], range: range),
                  let number = Int(ScheduleParser.group(match, 1, in: folded as NSString) ?? "") else { continue }
            return (1...20).contains(number) ? number : nil
        }
        return nil
    }

    /// A number of a period followed by its hours, anywhere in a text: "P1 8:00-8:50", "1限 9:00-10:30", "2. 9h-10h".
    /// The number must not be cut off a longer one ("10:00" is not the period 1 followed by "0:00").
    static let legendLabelRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\dA-Za-z:.])(?:(?:p(?:é|e)?riode?|period|stunde|lesson|heure|hora|ora|cours|clase|p)\.?\s?)?(\d{1,2})(?!\d)\s?(?:限|時限|時間目|ère|ere|re|er|ème|eme|e|st|nd|rd|th|ª|º|°)?\s?[:=)\-]?\s*(?=\d{1,2}\s?(?:[:hH]|\s?[aApP]\.?[mM]))"#,
        options: [.caseInsensitive])

    /// (number, start, end) of each period written in a text.
    static func legendEntries(in text: String) -> [(number: Int, start: Int, end: Int?)] {
        guard let regex = legendLabelRegex else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        var result: [(number: Int, start: Int, end: Int?)] = []
        for (position, match) in matches.enumerated() {
            guard let number = Int(ScheduleParser.group(match, 1, in: ns) ?? ""), (1...20).contains(number) else { continue }
            let from = match.range.location + match.range.length
            let to = position + 1 < matches.count ? matches[position + 1].range.location : ns.length
            guard to > from else { continue }
            let segment = ns.substring(with: NSRange(location: from, length: to - from))
            guard let found = ScheduleParser.findTime(in: segment) else { continue }
            let before = (segment as NSString).substring(to: found.range.location)
            if !before.trimmingCharacters(in: CharacterSet(charactersIn: " -:|,")).isEmpty { continue }
            result.append((number: number, start: found.start, end: found.end))
        }
        return result
    }

    /// The hours of each numbered period written anywhere on the page. A period with a start only ends after the usual
    /// length of the periods of the page: the shortest gap between two starts, less the break when it ends on a 5
    /// ("8:00", "8:55", "10:00": 55 minutes apart, 50 minutes long).
    static func periodLegend(_ lines: [RecognizedLine]) -> [Int: (start: Int, end: Int?)] {
        var entries: [Int: (start: Int, end: Int?)] = [:]
        for line in lines {
            for entry in legendEntries(in: line.text) where entries[entry.number] == nil {
                entries[entry.number] = (start: entry.start, end: entry.end)
            }
        }
        let numbers = entries.keys.sorted()
        var gaps: [Int] = []
        for number in numbers {
            guard let next = entries[number + 1], let current = entries[number] else { continue }
            let gap = next.start - current.start
            if (20...240).contains(gap) { gaps.append(gap) }
        }
        var usual: Int? = nil
        if let shortest = gaps.min() { usual = shortest - (shortest % 10 == 5 ? 5 : 0) }
        var result: [Int: (start: Int, end: Int?)] = [:]
        for number in numbers {
            guard let entry = entries[number] else { continue }
            var end = entry.end
            if end == nil, let length = usual {
                var guess = entry.start + length
                if let next = entries[number + 1], next.start < guess { guess = next.start }
                end = guess
            }
            result[number] = (start: entry.start, end: end)
        }
        return result
    }
}
