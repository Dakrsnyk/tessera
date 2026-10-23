import Foundation

/// An Omnivox timetable: a grid whose left margin writes two hours per row ("08:10" then "09:00"), whose blocks are
/// white on grey cells and hold a course code. The hours come from the rows the blocks cover (read from the colours
/// of the image, else from where the text sits). The logic lives in `ScheduleParser.timetableDrafts`.
struct OmnivoxLayout: ScheduleLayout {
    let name = "omnivox"
    let role = LayoutRole.claim

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        guard let grid = ScheduleParser.detectGrid(in: lines) else { return [] }
        return ScheduleParser.timetableDrafts(lines, grid, probe: probe) ?? []
    }

    /// A page with rows of two hours and the code of a course somewhere (the list of courses above the grid) is an
    /// Omnivox page even when no block was read in it: the list and the personal data must never become classes.
    func claimsPage(lines: [RecognizedLine], probe: BlockProbe?, drafts: [ScheduleParser.Draft]) -> Bool {
        if !drafts.isEmpty { return true }
        guard lines.contains(where: { ScheduleParser.courseCode(in: $0.text) != nil }),
              let grid = ScheduleParser.detectGrid(in: lines) else { return false }
        return ScheduleParser.timetableDrafts(lines, grid, probe: probe) != nil
    }
}
