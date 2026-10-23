import Foundation
import CoreGraphics

/// One horizontal band of a page: the lines of one grid, with the week it names ("A", "B", "1", "2") when its heading says.
struct PageBand {
    var lines: [RecognizedLine]
    var heading: String?
}

/// A page that holds several grids one under the other (week A and week B, morning and afternoon) is cut at each row
/// of day names. `ScheduleLayouts.read` reads each band and decides what the later bands are:
/// - a band whose heading says "Semaine B" (or "Week 2"...), or that covers the same hours as the first one, is
///   ANOTHER WEEK: its classes are offered unticked, marked "to check", with the letter of the week after the name.
///   Importing both weeks into one schedule would put two classes at the same time; leaving the second one out
///   without a word would lose it. Unticked, nothing is lost and nothing is doubled.
/// - a band that covers other hours (a grid for the morning, one for the afternoon) is the same timetable going on.
/// Two grids side by side (week A at the left of week B) are not cut: the days repeat in the row, and only the first
/// run of days is read.
enum PageSections {
    /// Two rows of day names closer than this (a share of the page height) belong to the same grid.
    static let minimumDistance: CGFloat = 0.15
    /// The heading of a band lies at most this far above its row of day names.
    static let headingReach: CGFloat = 0.08

    static let headingRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:semaine|week|woche|semana|settimana|sem\.?)\s*([AB12])\b"#, options: [.caseInsensitive])

    /// The bands of the page, or nil when it holds a single grid.
    static func split(_ lines: [RecognizedLine]) -> [PageBand]? {
        let grids = ScheduleParser.allGrids(in: lines)
            .filter { $0.headers.count >= 3 }
            .sorted { $0.headers[0].y < $1.headers[0].y }
        var tops: [ScheduleParser.Grid] = []
        for grid in grids {
            if let last = tops.last, grid.headers[0].y - last.headers[0].y < minimumDistance { continue }
            tops.append(grid)
        }
        guard tops.count >= 2 else { return nil }
        var bands: [PageBand] = []
        for (position, grid) in tops.enumerated() {
            let headerY = grid.headers[0].y
            let from: CGFloat = position == 0 ? -1 : headerY - headingReach
            let to: CGFloat = position + 1 == tops.count ? 2 : tops[position + 1].headers[0].y - headingReach
            let inBand = lines.filter { $0.box.midY >= from && $0.box.midY < to }
            var heading: String? = nil
            if let regex = headingRegex {
                for line in lines where line.box.midY >= from && line.box.midY < headerY - 0.005 {
                    let ns = line.text as NSString
                    if let match = regex.firstMatch(in: line.text, options: [], range: NSRange(location: 0, length: ns.length)),
                       let letter = ScheduleParser.group(match, 1, in: ns) {
                        heading = letter.uppercased()
                    }
                }
            }
            bands.append(PageBand(lines: inBand, heading: heading))
        }
        return bands
    }
}
