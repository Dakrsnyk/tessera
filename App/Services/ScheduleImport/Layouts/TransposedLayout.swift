import Foundation
import CoreGraphics

/// A transposed grid: the days are the rows (their names stacked in the first column) and the hours are the columns
/// (labels along the top: "8h-9h", "9h-10h" or "8:00", "9:00"). A text belongs to the day whose row it is in and to
/// the hour columns it covers: a text as wide as two columns is a class of two hours. Hour labels written as one hour
/// ("8:00", "9:00") sit either over their column or at its left edge; which one is told by where the texts are.
struct TransposedLayout: ScheduleLayout {
    let name = "transposed"
    let role = LayoutRole.sequence

    /// An hour column: its hours and the x of its label.
    private struct HourColumn {
        var start: Int
        var end: Int
        var x: CGFloat
    }

    /// The texts of one row that touch each other side by side (one cell, or a class over several columns).
    private struct Cluster {
        var lines: [RecognizedLine]
        var minX: CGFloat
        var maxX: CGFloat
    }

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        // The days: lines that are one day name, left aligned in a column of the page.
        var candidates: [ScheduleParser.DayCandidate] = []
        for (index, line) in lines.enumerated() {
            let found = ScheduleParser.dayCandidates(line: line, index: index)
            if found.count == 1 { candidates.append(found[0]) }
        }
        guard candidates.count >= 3 else { return [] }
        var column: [ScheduleParser.DayCandidate] = []
        for candidate in candidates {
            let group = candidates.filter { abs($0.x - candidate.x) <= 0.06 }
            if Set(group.map { $0.day }).count > Set(column.map { $0.day }).count { column = group }
        }
        guard Set(column.map { $0.day }).count >= 3 else { return [] }
        var seen = Set<Int>()
        var labels: [ScheduleParser.DayCandidate] = []
        for candidate in column.sorted(by: { $0.y < $1.y }) where !seen.contains(candidate.day) {
            seen.insert(candidate.day)
            labels.append(candidate)
        }
        guard labels.count >= 3 else { return [] }
        let ys = labels.map { $0.y }
        let spacing = (ys[ys.count - 1] - ys[0]) / CGFloat(ys.count - 1)
        guard spacing > 0.01 else { return [] }
        let labelIndexes = Set(labels.map { $0.line })
        let labelRight = labels.map { lines[$0.line].box.maxX }.max() ?? 0

        // The hours: labels above the first day, the biggest group at the same height.
        var heads: [(x: CGFloat, y: CGFloat, time: ScheduleParser.TimeFound)] = []
        for line in lines where line.box.midY < ys[0] - 0.4 * spacing {
            if let time = ScheduleParser.timeOnly(line.text) { heads.append((x: line.box.midX, y: line.box.midY, time: time)) }
        }
        guard heads.count >= 3 else { return [] }
        heads.sort { $0.y < $1.y }
        var groups: [[(x: CGFloat, y: CGFloat, time: ScheduleParser.TimeFound)]] = []
        for head in heads {
            if let first = groups.last?.first, abs(head.y - first.y) <= 0.02 {
                groups[groups.count - 1].append(head)
            } else {
                groups.append([head])
            }
        }
        guard var row = groups.max(by: { $0.count < $1.count }), row.count >= 3 else { return [] }
        row.sort { $0.x < $1.x }
        for index in 1..<row.count where row[index].x - row[index - 1].x < 0.02 { return [] }
        let headerY = row.map { $0.y }.max() ?? 0
        let ranges = row.allSatisfy { $0.time.end != nil }
        var hours: [HourColumn] = []
        if ranges {
            for head in row { hours.append(HourColumn(start: head.time.start, end: head.time.end ?? head.time.start, x: head.x)) }
        } else {
            let starts = row.map { $0.time.start }
            for index in 1..<starts.count where starts[index] <= starts[index - 1] { return [] }
            var steps = (1..<starts.count).map { starts[$0] - starts[$0 - 1] }
            steps.sort()
            let step = steps[steps.count / 2]
            for (index, head) in row.enumerated() {
                let end = index + 1 < starts.count ? starts[index + 1] : head.time.start + step
                hours.append(HourColumn(start: head.time.start, end: end, x: head.x))
            }
        }
        let n = hours.count
        let spacingX = (hours[n - 1].x - hours[0].x) / CGFloat(n - 1)
        guard spacingX > 0.01 else { return [] }

        // The texts of each day's row, cut into cells.
        var bounds = [CGFloat](repeating: 0, count: labels.count + 1)
        for k in 1..<labels.count { bounds[k] = (ys[k - 1] + ys[k]) / 2 }
        bounds[0] = ys[0] - spacing / 2
        bounds[labels.count] = ys[labels.count - 1] + spacing / 2
        var cells: [(day: Int, fuzzy: Bool, cluster: Cluster)] = []
        for (rowIndex, label) in labels.enumerated() {
            var body: [RecognizedLine] = []
            for (index, line) in lines.enumerated() {
                if labelIndexes.contains(index) { continue }
                let y = line.box.midY
                guard y >= bounds[rowIndex], y < bounds[rowIndex + 1], y > headerY + 0.005, line.box.minX >= labelRight - 0.005 else { continue }
                body.append(line)
            }
            body.sort { $0.box.minX < $1.box.minX }
            var clusters: [Cluster] = []
            for line in body {
                if let last = clusters.last, line.box.minX <= last.maxX + 0.004 {
                    clusters[clusters.count - 1].lines.append(line)
                    clusters[clusters.count - 1].maxX = max(last.maxX, line.box.maxX)
                } else {
                    clusters.append(Cluster(lines: [line], minX: line.box.minX, maxX: line.box.maxX))
                }
            }
            for cluster in clusters { cells.append((day: label.day, fuzzy: label.fuzzy, cluster: cluster)) }
        }

        // Hour labels at the left edge of their column: the cells then sit between two labels.
        var edgeMode = false
        if !ranges, !cells.isEmpty {
            let fractions = cells.map { cell -> CGFloat in
                let position = ((cell.cluster.minX + cell.cluster.maxX) / 2 - hours[0].x) / spacingX
                return position - position.rounded(.down)
            }.sorted()
            let median = fractions[fractions.count / 2]
            edgeMode = median >= 0.3 && median <= 0.7
        }

        var drafts: [ScheduleParser.Draft] = []
        for cell in cells {
            let cluster = cell.cluster
            var first = 0
            var last = 0
            if edgeMode {
                first = Int(((cluster.minX + 0.003 - hours[0].x) / spacingX).rounded(.down))
                last = Int(((cluster.maxX - 0.003 - hours[0].x) / spacingX).rounded(.down))
                first = min(max(first, 0), n - 1)
                last = min(max(last, first), n - 1)
            } else {
                var firstCovered: Int? = nil
                var lastCovered = 0
                for index in 0..<n where cluster.minX - 0.002 <= hours[index].x && hours[index].x <= cluster.maxX + 0.002 {
                    if firstCovered == nil { firstCovered = index }
                    lastCovered = index
                }
                if let covered = firstCovered {
                    first = covered
                    last = lastCovered
                } else {
                    let middle = (cluster.minX + cluster.maxX) / 2
                    var nearest = 0
                    for index in 1..<n where abs(hours[index].x - middle) < abs(hours[nearest].x - middle) { nearest = index }
                    first = nearest
                    last = nearest
                }
            }
            let ordered = cluster.lines.sorted { $0.box.minY < $1.box.minY }
            if var draft = ScheduleParser.cellDraft(ordered, weekday: cell.day, start: hours[first].start, end: hours[last].end) {
                if cell.fuzzy { draft.uncertain.insert(.day) }
                drafts.append(draft)
            }
        }
        return drafts
    }
}
