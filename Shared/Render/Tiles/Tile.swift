import Foundation

/// A button inside a widget. Each case maps to one App Intent (see `TileActionButton`).
enum TileAction: Hashable {
    case completeSet
    case skipRest
    case logFood(String)
    case quickExpense(String)
    case counter(String, Int)
    case togglePriority(String)
    case toggleProjectTask(String, String)
    case revealCard
    case gradeCard(Bool)
    case toggleAssignment(String)
    case startFocus(Int)
    case toggleHabit(String)
    case addWater
    /// Opens the app on the barcode scanner. Widgets can't use the camera: this is a link, which works
    /// on medium and large widgets (see `RenderContext.allowsLinks`).
    case scanFood
}

struct TileButton: Hashable {
    var title: String
    var symbol: String
    var action: TileAction
    var isProminent = false
}

struct TileRow: Hashable, Identifiable {
    var id: String
    var title: String
    var value: String? = nil
    var detail: String? = nil
    var symbol: String? = nil
    var colorHex: String? = nil
    var progress: Double? = nil
    /// Shows a checkbox; tapping it runs `action`.
    var isDone: Bool? = nil
    var action: TileAction? = nil
    var isHighlighted = false
}

struct TileSegment: Hashable {
    var label: String
    var value: Double
    var colorHex: String
}

/// The chart or graphic of a widget, drawn by `TileVisualView`.
enum TileVisual: Hashable {
    case none
    case ring(Double)
    case bar(Double)
    /// Vertical bars (oldest first), with optional labels and the index to highlight.
    case bars([Double], labels: [String], highlight: Int?)
    case line([Double])
    case segments([TileSegment])
    /// Monday-first week: true = done, false = missed, nil = future or not planned.
    case week([Bool?])
    /// A month as dots: the offset of the 1st (0 = Monday), marked days (1-based) and today.
    case month(days: Int, offset: Int, marked: Set<Int>, today: Int?)
    /// Rows of seven days (habits × week).
    case grid(names: [String], rows: [[Bool?]], colors: [String])
    case symbol(String)
    /// Sun course between sunrise and sunset, 0 to 1 (nil at night).
    case sun(progress: Double?, sunrise: String, sunset: String)
    /// A live countdown bar.
    case timer(Date, Date)
    /// The week's schedule: Monday-first columns, blocks between the first and last hour shown,
    /// and today's column (0 = Monday).
    /// A week (Monday first): its blocks, today's column, the day numbers, the hours shown (minutes).
    case schedule([ScheduleBlock], today: Int?, dates: [Int], firstMinute: Int, lastMinute: Int)
}

/// One entry of the week's schedule, placed in its day's column (0 = Monday). `start` and `end` are
/// fractions of the hours shown (0 = the first, 1 = the last).
struct ScheduleBlock: Hashable {
    var day: Int
    var start: Double
    var end: Double
    var colorHex: String
    var title: String
    /// Its start time, written in the block when there is room.
    var time: String?
}

struct TileEmpty: Hashable {
    var symbol: String
    var title: String
    var message: String
}

/// What a data widget shows, independent of its size. Builders fill it from the user's data;
/// `TileView` lays it out for small, medium, large and Lock Screen widgets.
struct Tile: Hashable {
    var title: String
    var symbol: String
    var value: String = "—"
    var unit: String? = nil
    var caption: String? = nil
    var detail: String? = nil
    /// Colors the main value: true = positive (green), false = negative (red).
    var trend: Bool? = nil
    var visual: TileVisual = .none
    var rows: [TileRow] = []
    var buttons: [TileButton] = []
    /// A small button at the top right of medium and large widgets (the Nutrition scanner).
    var headerButton: TileButton? = nil
    /// When set, the value is a live countdown to the end of this range.
    var timer: ClosedRange<Date>? = nil
    var empty: TileEmpty? = nil
    /// Lock Screen texts.
    var inline: String? = nil
    var gauge: Double? = nil
    var shortValue: String? = nil
    /// Small print (data source or disclaimer), shown on medium and large widgets.
    var footnote: String? = nil
    /// Small widgets show the rows (a checklist or a list) instead of the big value.
    var compactRows = false
    /// Lock Screen rectangular widget: a few figures side by side under the title, each with its bar
    /// (title = a short label, value, progress).
    var lockColumns: [TileRow] = []

    static func empty(_ title: String, symbol: String, message: String, emptySymbol: String? = nil) -> Tile {
        var tile = Tile(title: title, symbol: symbol)
        tile.empty = TileEmpty(symbol: emptySymbol ?? symbol, title: title, message: message)
        tile.inline = title
        return tile
    }
}
