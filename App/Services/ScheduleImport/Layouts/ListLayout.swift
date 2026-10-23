import Foundation

/// A list read row by row: a day (a title line, or the first word of the row) then its classes ("8h-10h Maths -
/// salle 12", "9h-12h / 13h-17h Atelier", "8h30 Maths" with a start only), the university exports ("Lundi 08:00-10:00 CM
/// Analyse Amphi B") and the tables whose columns Vision reads as lines at the same height ("Lundi | 08:00 | 10:00 |
/// Maths | B12"). The logic lives in `ScheduleParser.listDrafts`.
struct ListLayout: ScheduleLayout {
    let name = "list"
    let role = LayoutRole.sequence

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        ScheduleParser.listDrafts(lines)
    }
}
