import Foundation
import CoreGraphics

/// A calendar week view (Google Calendar, Apple Calendar, Outlook, Teams): the days are the columns with their date
/// ("lun. 21", "Mon 21"), the hours are labels in the left margin ("8 AM", "9 h", "08:00") and the events are floating
/// blocks that start where their text starts. An event shows its hours ("8:30 – 10:00"), or only its title: its start
/// then comes from the height of its text and its end from the height of its coloured block (the probe), else it gets
/// the usual length. What lies above the first hour (the all-day events) is not a class.
struct WeekViewLayout: ScheduleLayout {
    let name = "weekView"
    let role = LayoutRole.grid

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        guard let grid = ScheduleParser.detectGrid(in: lines), grid.headers.count >= 2 else { return [] }
        let headers = grid.headers
        let count = headers.count
        let edges = ScheduleParser.columnEdges(headers)
        let margin = ScheduleParser.marginLines(lines, grid: grid, edges: edges)
        let axis = ScheduleParser.TimeAxis(margin: margin)
        // Labels of one hour: at least two. Rows of two hours (periods) are another layout's.
        guard axis.rows.count < 2, axis.points.count >= 2, ScheduleParser.Timeline(margin: margin) == nil else { return [] }
        let points = axis.points
        let step = points[1].y - points[0].y
        guard step > 0 else { return [] }
        let topLimit = points[0].y - 0.3 * step
        let bottomLimit = points[points.count - 1].y + 1.5 * step
        var columns = [[RecognizedLine]](repeating: [], count: count)
        for (index, line) in lines.enumerated() {
            if grid.lineIndexes.contains(index) { continue }
            let y = line.box.midY
            let x = line.box.midX
            guard y > grid.bandBottom, y >= topLimit, y <= bottomLimit, x >= edges[0], x < edges[count] else { continue }
            columns[ScheduleParser.columnIndex(of: x, edges: edges)].append(line)
        }
        var drafts: [ScheduleParser.Draft] = []
        for (column, columnLines) in columns.enumerated() {
            let sorted = columnLines.sorted { $0.box.minY < $1.box.minY }
            let blocks = ScheduleParser.blocks(of: sorted)
            let tops = blocks.map { block in block.map { $0.box.minY }.min() ?? 0 }
            var runs: [ClosedRange<Double>]? = nil
            if let probe = probe, !blocks.isEmpty {
                // A little under the top of each text: the text of a block starts a few pixels inside it.
                let marks = tops.map { Double($0) + 0.004 }
                runs = ScheduleParser.bestRuns(probe, left: edges[column], from: max(0, Double(points[0].y - step)),
                                               to: min(1, Double(points[points.count - 1].y + step)), marks: marks)
            }
            for (position, block) in blocks.enumerated() {
                if let draft = WeekViewLayout.draft(block, top: tops[position], weekday: headers[column].day, points: points,
                                                    nextTop: position + 1 < tops.count ? tops[position + 1] : nil, runs: runs) {
                    drafts.append(draft)
                }
            }
        }
        return drafts
    }

    /// One event: its title and room, and its hours (written in it, or placed on the hour labels).
    private static func draft(_ block: [RecognizedLine], top: CGFloat, weekday: Int, points: [(y: CGFloat, minute: Int)],
                              nextTop: CGFloat?, runs: [ClosedRange<Double>]?) -> ScheduleParser.Draft? {
        var time: ScheduleParser.TimeFound? = nil
        var room: String? = nil
        var titles: [String] = []
        for line in block {
            let info = ScheduleParser.analyze(line.text)
            if time == nil { time = info.time }
            if room == nil { room = info.room }
            if !info.title.isEmpty { titles.append(info.title) }
        }
        let title = titles.prefix(2).joined(separator: " ")
        guard !title.isEmpty else { return nil }
        if let time = time {
            return ScheduleParser.Draft(weekday: weekday, start: time.start, end: time.end, title: title, room: room)
        }
        guard let raw = minute(at: top, points: points) else { return nil }
        let start = snapped(raw, to: 15)
        guard (0..<1440).contains(start) else { return nil }
        var end: Int? = nil
        if let runs = runs, let found = runs.first(where: { $0.lowerBound - 0.012 <= Double(top) && Double(top) <= $0.upperBound }) {
            var bottom = found.upperBound
            // Two blocks stuck together make one stretch: this one stops where the next text begins.
            if let next = nextTop, Double(next) < bottom, next > top { bottom = Double(next) - 0.002 }
            if let endRaw = minute(at: CGFloat(bottom), points: points) {
                let candidate = snapped(endRaw, to: 5)
                if candidate - start >= 20, candidate - start <= 360 { end = candidate }
            }
        }
        return ScheduleParser.Draft(weekday: weekday, start: start, end: end, title: title, room: room)
    }

    /// The minute at a height, interpolated (or extended) from the hour labels, which increase with the height.
    static func minute(at y: CGFloat, points: [(y: CGFloat, minute: Int)]) -> Double? {
        guard points.count >= 2 else { return nil }
        var low = points[0]
        var high = points[1]
        for index in 0..<(points.count - 1) where y >= points[index].y {
            low = points[index]
            high = points[index + 1]
        }
        let span = high.y - low.y
        guard span > 0 else { return nil }
        return Double(low.minute) + Double((y - low.y) / span) * Double(high.minute - low.minute)
    }

    static func snapped(_ minutes: Double, to step: Int) -> Int {
        Int((minutes / Double(step)).rounded()) * step
    }
}
