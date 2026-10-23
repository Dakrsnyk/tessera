import Foundation
import CoreGraphics

/// What the grid layouts share: where the columns of a row of day names are, and what lies in the left margin.
extension ScheduleParser {

    /// Column edges: halfway between the centres of the day names (half a column at the two ends).
    static func columnEdges(_ headers: [DayCandidate]) -> [CGFloat] {
        let count = headers.count
        var edges: [CGFloat] = [headers[0].x - (headers[1].x - headers[0].x) / 2]
        for index in 1..<count { edges.append((headers[index - 1].x + headers[index].x) / 2) }
        edges.append(headers[count - 1].x + (headers[count - 1].x - headers[count - 2].x) / 2)
        return edges
    }

    /// The column an x belongs to (`edges` has one more value than there are columns).
    static func columnIndex(of x: CGFloat, edges: [CGFloat]) -> Int {
        let count = edges.count - 1
        var column = 0
        while column < count - 1, x >= edges[column + 1] { column += 1 }
        return column
    }

    /// The lines under the row of day names that lie left of the first column.
    static func marginLines(_ lines: [RecognizedLine], grid: Grid, edges: [CGFloat]) -> [RecognizedLine] {
        var margin: [RecognizedLine] = []
        for (index, line) in lines.enumerated() {
            if grid.lineIndexes.contains(index) || line.box.midY <= grid.bandBottom { continue }
            if line.box.midX < edges[0] { margin.append(line) }
        }
        return margin
    }

    /// Title (the first two pieces) and room of the lines of one cell, hours left out; nil when it holds no name.
    static func cellDraft(_ lines: [RecognizedLine], weekday: Int, start: Int, end: Int) -> Draft? {
        var titles: [String] = []
        var room: String? = nil
        for line in lines {
            let info = analyze(line.text)
            if room == nil { room = info.room }
            if !info.title.isEmpty { titles.append(info.title) }
        }
        let title = titles.prefix(2).joined(separator: " ")
        guard !title.isEmpty else { return nil }
        return Draft(weekday: weekday, start: start, end: end, title: title, room: room)
    }
}
