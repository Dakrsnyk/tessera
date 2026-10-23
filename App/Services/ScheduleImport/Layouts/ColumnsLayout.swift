import Foundation

/// The generic grid: the days are the columns, each text goes to the nearest day, and its hours come from the cell
/// itself ("8h30-10h" written in it) or from the hour labels of the left margin. It does not know periods nor
/// floating calendar blocks (`PeriodGridLayout` and `WeekViewLayout` do), so it only reads a page when they find nothing.
struct ColumnsLayout: ScheduleLayout {
    let name = "columns"
    let role = LayoutRole.gridFallback

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        guard let grid = ScheduleParser.detectGrid(in: lines) else { return [] }
        return ScheduleParser.gridDrafts(lines, grid)
    }
}
