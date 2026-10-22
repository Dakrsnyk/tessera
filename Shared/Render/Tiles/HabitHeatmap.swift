import SwiftUI
import WidgetKit

/// The contribution-style grid of a habit: small rounded squares, one per day, in the habit's color when done
/// and faint when not. Pure functions (no view) so the data of the grid can be tested; `HabitHeatmapGrid`
/// draws it for the widget and the Habits screen.
enum HabitHeatmap {
    /// The gap between two cells, as a fraction of a cell (so the grid keeps its proportions at any size).
    static let gapRatio: CGFloat = 0.2

    /// The window of the percentage shown beside a habit: its regularity over the last 30 days.
    static let rateDays = 30

    /// The grid's data, as columns left to right: the last `columns` weeks, the last column being the
    /// current one; each column holds the 7 days of its week in the calendar's order (the first weekday
    /// on top). `true` = done, `false` = not done, `nil` = a day still to come (nothing is drawn).
    static func weeks(for habit: Habit, columns: Int, asOf date: Date = Date()) -> [[Bool?]] {
        guard columns > 0 else { return [] }
        let calendar = DateMath.calendar
        let today = DateMath.startOfDay(date)
        guard let firstOfThisWeek = DateMath.week(containing: today).first else { return [] }
        let keys = Set(habit.completedDays)
        var result: [[Bool?]] = []
        for index in 0..<columns {
            let weekOffset = index - (columns - 1)
            guard let start = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: firstOfThisWeek) else {
                result.append([Bool?](repeating: nil, count: 7))
                continue
            }
            var column: [Bool?] = []
            for offset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: offset, to: start), day <= today {
                    column.append(keys.contains(DateMath.dayKey(day)))
                } else {
                    column.append(nil)
                }
            }
            result.append(column)
        }
        return result
    }

    /// The last `days` days as a single row (one value per column), oldest first, today last; used when the
    /// room is too short for seven rows. Never a day to come: the row always ends today.
    static func recent(for habit: Habit, days: Int, asOf date: Date = Date()) -> [[Bool?]] {
        guard days > 0 else { return [] }
        let calendar = DateMath.calendar
        let today = DateMath.startOfDay(date)
        let keys = Set(habit.completedDays)
        var result: [[Bool?]] = []
        for index in 0..<days {
            let offset = index - (days - 1)
            if let day = calendar.date(byAdding: .day, value: offset, to: today) {
                result.append([keys.contains(DateMath.dayKey(day))])
            } else {
                result.append([nil])
            }
        }
        return result
    }

    /// The data of a grid laid out by `layout(width:height:)`: weeks of seven days, or one row of recent days.
    static func cells(for habit: Habit, layout: (rows: Int, columns: Int), asOf date: Date = Date()) -> [[Bool?]] {
        layout.rows >= 7 ? weeks(for: habit, columns: layout.columns, asOf: date) : recent(for: habit, days: layout.columns, asOf: date)
    }

    /// The number of rows (7 = a week per column, 1 = a row of recent days) and columns that fill an area:
    /// the whole width, in as many columns as the cell size allows. Seven rows only when the height gives
    /// cells of at least `minCell` points; the cells never grow past `maxCell`.
    static func layout(width: CGFloat, height: CGFloat, minCell: CGFloat = 3.5, maxCell: CGFloat = 12,
                       maxWeeks: Int = 53, maxDays: Int = 60) -> (rows: Int, columns: Int) {
        guard width > 0, height > 0 else { return (1, 1) }
        let weekCell = height / (7 + 6 * gapRatio)
        let rows = weekCell >= minCell ? 7 : 1
        let cell = max(1, min(rows == 7 ? weekCell : height, maxCell))
        // Rounded up, so the cells come out a little smaller than `cell` and the grid spans the whole width.
        let raw = Int(((width / cell + gapRatio) / (1 + gapRatio)).rounded(.up))
        return (rows, min(max(1, raw), rows == 7 ? maxWeeks : maxDays))
    }

    /// Width over height of a grid of `columns` x `rows` cells.
    static func aspectRatio(columns: Int, rows: Int) -> CGFloat {
        guard columns > 0, rows > 0 else { return 1 }
        let width = CGFloat(columns) + CGFloat(columns - 1) * gapRatio
        let height = CGFloat(rows) + CGFloat(rows - 1) * gapRatio
        return width / height
    }

    /// The share of days done over the last `days` days, nil before the first day done (a habit without
    /// history has no percentage, nothing is made up).
    static func rate(of habit: Habit, days: Int = HabitHeatmap.rateDays, asOf date: Date = Date()) -> Double? {
        guard let counts = habit.regularity(days: days, asOf: date), counts.total > 0 else { return nil }
        return Double(counts.done) / Double(counts.total)
    }

    /// How many cells of the data are done (what VoiceOver and tests can count).
    static func doneCount(_ columns: [[Bool?]]) -> Int {
        columns.reduce(0) { total, column in total + column.filter { $0 == true }.count }
    }
}

/// Every cell of one state (done, or not done) as one path: a single shape per color keeps a grid of
/// hundreds of cells light for a widget. Days still to come (`nil`) are not drawn.
struct HabitCellsShape: Shape {
    let columns: [[Bool?]]
    let isDone: Bool
    /// The corner radius as a fraction of a cell.
    var roundness: CGFloat = 0.26

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = columns.count
        let rows = columns.map(\.count).max() ?? 0
        guard count > 0, rows > 0, rect.width > 0, rect.height > 0 else { return path }
        let gap = HabitHeatmap.gapRatio
        let cell = min(rect.width / (CGFloat(count) + CGFloat(count - 1) * gap),
                       rect.height / (CGFloat(rows) + CGFloat(rows - 1) * gap))
        guard cell > 0 else { return path }
        let step = cell * (1 + gap)
        let radius = cell * min(roundness, 0.5)
        for (x, column) in columns.enumerated() {
            for (y, state) in column.enumerated() {
                guard let state, state == isDone else { continue }
                let frame = CGRect(x: rect.minX + CGFloat(x) * step, y: rect.minY + CGFloat(y) * step, width: cell, height: cell)
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: radius, height: radius))
            }
        }
        return path
    }
}

/// The grid itself, filling its width (its height follows from the number of columns and rows). Without
/// colors (« Clair », « Teinté ») the caller passes the style's tint and track: no text sits on a cell.
struct HabitHeatmapGrid: View {
    let columns: [[Bool?]]
    let doneColor: Color
    let emptyColor: Color
    var roundness: CGFloat = 0.26

    var body: some View {
        let rows = columns.map(\.count).max() ?? 0
        ZStack {
            HabitCellsShape(columns: columns, isDone: false, roundness: roundness).fill(emptyColor)
            HabitCellsShape(columns: columns, isDone: true, roundness: roundness).fill(doneColor).widgetAccentable()
        }
        .aspectRatio(HabitHeatmap.aspectRatio(columns: columns.count, rows: rows), contentMode: .fit)
        .accessibilityHidden(true)
    }
}
