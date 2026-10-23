import Foundation
import CoreGraphics

/// A student timetable printed by a college report (the Cégep de l'Outaouais "Horaire de l'étudiant", RPHOR025): the
/// days are the columns ("Lun. 26 août"), the left margin has ONE label per half hour ("08:00", "08:30", ... "22:00")
/// centred in its row, and a class is a white rectangle with a thick black outline on a grid of thin grey lines. The
/// text is tiny and centred in the block: a title with its type ("Allemand I (T)", "(L)" for a lab), the code of the
/// course with its group ("609-C01-HU g.00001"), the room alone ("2.547", two of them when the class moves), the
/// teacher ("Chavant, L"). Titles, headings, a footer and handwriting over the grid are not classes: only a block with
/// the code of a course is.
///
/// A label names the row that STARTS at its time and is centred on it: the top of a block that begins at 08:00 is half a
/// row above the label "08:00". The hours of a block come from its outline (`BlockProbe.framedRuns`); without the image
/// (or where the outline is not found) from the middle of its text: the lengths of a block are 1 h, 1 h 30 or 2 h and it
/// begins on the hour, which tells them apart (a block centred on hh:00 is 2 h, on hh:30 it is 1 h, on hh:45 it is 1 h 30).
/// It is not Omnivox (rows of two hours, coloured cells) and not a calendar week view (text at the top of the block):
/// it claims its page.
struct BoxedBlocksLayout: ScheduleLayout {
    let name = "boxedBlocks"
    let role = LayoutRole.claim

    /// What a block holds: its title and its room (or rooms, separated by " / ").
    struct Content {
        var title: String
        var room: String?
    }

    func drafts(lines: [RecognizedLine], probe: BlockProbe?) -> [ScheduleParser.Draft] {
        guard let grid = ScheduleParser.detectGrid(in: lines), grid.headers.count >= 2 else { return [] }
        let headers = grid.headers
        let count = headers.count
        let edges = ScheduleParser.columnEdges(headers)
        let margin = ScheduleParser.marginLines(lines, grid: grid, edges: edges)
        let axis = ScheduleParser.TimeAxis(margin: margin)
        guard axis.rows.count < 2, axis.points.count >= 4 else { return [] }
        let points = axis.points
        // One label per row of the same height and the same length (15, 30 or 60 minutes).
        var heights: [CGFloat] = []
        var lengths: [Int] = []
        for index in 1..<points.count {
            heights.append(points[index].y - points[index - 1].y)
            lengths.append(points[index].minute - points[index - 1].minute)
        }
        let stepY = heights.sorted()[heights.count / 2]
        let stepMinutes = lengths.sorted()[lengths.count / 2]
        guard stepY > 0, [15, 30, 60].contains(stepMinutes) else { return [] }
        var regular = 0
        for index in 0..<heights.count where abs(heights[index] - stepY) <= 0.2 * stepY && lengths[index] == stepMinutes {
            regular += 1
        }
        guard regular * 10 >= heights.count * 8 else { return [] }
        let half = stepY / 2
        let gridTop = points[0].y - half
        let gridBottom = points[points.count - 1].y + half
        let snapStep = stepMinutes >= 30 ? 30 : stepMinutes
        func minute(at y: CGFloat) -> Double { WeekViewLayout.minute(at: y + half, points: points) ?? 0 }

        var columns = [[RecognizedLine]](repeating: [], count: count)
        for (index, line) in lines.enumerated() {
            if grid.lineIndexes.contains(index) { continue }
            let y = line.box.midY
            let x = line.box.midX
            guard y > grid.bandBottom, y >= gridTop, y <= gridBottom, x >= edges[0], x < edges[count] else { continue }
            columns[ScheduleParser.columnIndex(of: x, edges: edges)].append(line)
        }
        let shortest = Double(0.5 * stepY)
        let longest = Double(12 * stepY)
        var drafts: [ScheduleParser.Draft] = []
        var fromOutline = 0
        for (column, columnLines) in columns.enumerated() {
            let clusters = ScheduleParser.textClusters(columnLines)
            guard !clusters.isEmpty else { continue }
            var outlines: [ClosedRange<Double>]? = nil
            if let probe = probe {
                outlines = ScheduleParser.columnRuns(probe, left: edges[column], from: max(0, Double(gridTop) - 0.004),
                                                     to: min(1, Double(gridBottom) + 0.004), kind: .framed)
            }
            for cluster in clusters {
                guard let content = BoxedBlocksLayout.content(of: cluster.lines), !content.title.isEmpty else { continue }
                let center = Double(cluster.center)
                var span: (start: Int, end: Int)? = nil
                if let outlines = outlines {
                    let enclosing = outlines.first { block in
                        let length = block.upperBound - block.lowerBound
                        return block.lowerBound <= center && center <= block.upperBound && length >= shortest && length <= longest
                    }
                    if let block = enclosing {
                        let start = WeekViewLayout.snapped(minute(at: CGFloat(block.lowerBound)), to: snapStep)
                        let end = WeekViewLayout.snapped(minute(at: CGFloat(block.upperBound)), to: snapStep)
                        if end - start >= snapStep {
                            span = (start: start, end: end)
                            fromOutline += 1
                        }
                    }
                }
                if span == nil {
                    let heightMinutes = Double((cluster.bottom - cluster.top) / stepY) * Double(stepMinutes)
                    span = BoxedBlocksLayout.fit(centerMinute: minute(at: cluster.center), textMinutes: heightMinutes)
                }
                if let found = span {
                    drafts.append(ScheduleParser.Draft(weekday: headers[column].day, start: found.start, end: found.end,
                                                       title: content.title, room: content.room))
                }
            }
        }
        // Not a calendar whose titles happen to hold the code of a course: the printed group ("g.00001") must be there, or
        // the outlines must have given the hours of most of the blocks.
        let printedGroup = lines.contains { BoxedBlocksLayout.matches(BoxedBlocksLayout.printedGroupRegex, $0.text) }
        guard printedGroup || fromOutline * 2 >= drafts.count else { return [] }
        return drafts
    }

    /// A page of this layout has at least one block: it is then this layout's, even when another layout could read it.
    func claimsPage(lines: [RecognizedLine], probe: BlockProbe?, drafts: [ScheduleParser.Draft]) -> Bool {
        !drafts.isEmpty
    }

    // MARK: Text of a block

    /// "g.00001", "gr.41070": the group of a course.
    static let groupCodeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])gr?\.?\s?\d{3,6}(?![0-9A-Za-z])"#, options: [.caseInsensitive])
    /// "g.00001" as printed by the college report (not "gr.41070", the Omnivox group): the mark of this layout.
    static let printedGroupRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])g\.\d{3,6}(?![0-9A-Za-z])"#, options: [])
    /// "2.547", "1.105": a room written alone.
    static let dottedRoomRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #"^\d{1,2}\.\d{2,3}$"#, options: [])
    /// "Chavant, L", "Berteau-Lord, G": a teacher, family name then initial.
    static let teacherRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\p{L}[\p{L}'’ -]*,\s?\p{L}\.?$"#, options: [])

    static func matches(_ regex: NSRegularExpression?, _ text: String) -> Bool {
        guard let regex = regex else { return false }
        return regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    /// Where the code of a course starts in a line (what comes before it is still part of the title).
    private static func codeStart(in text: String) -> String? {
        if let found = ScheduleParser.courseCode(in: text) { return found.before }
        guard let regex = groupCodeRegex,
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) else { return nil }
        return (text as NSString).substring(to: match.range.location)
    }

    /// The title and the rooms of a block, or nil when the lines hold no code of a course (a heading, a note written over
    /// the grid). The title is what comes before the code; the teacher and the way the class is given are left out.
    static func content(of lines: [RecognizedLine]) -> Content? {
        let texts = lines.map { $0.text }
        guard let codeIndex = texts.firstIndex(where: { codeStart(in: $0) != nil }) else { return nil }
        var titles: [String] = []
        var rooms: [String] = []
        for (index, text) in texts.enumerated() {
            if index == codeIndex {
                let before = (codeStart(in: text) ?? "").trimmingCharacters(in: .whitespaces)
                if !before.isEmpty { titles.append(before) }
                continue
            }
            if matches(dottedRoomRegex, text) || ScheduleParser.isRoomLine(text) {
                rooms.append(text.trimmingCharacters(in: .whitespaces))
                continue
            }
            if matches(teacherRegex, text) || ScheduleParser.isModeLine(text) || index > codeIndex { continue }
            titles.append(text)
        }
        return Content(title: titles.prefix(2).joined(separator: " "), room: rooms.isEmpty ? nil : rooms.joined(separator: " / "))
    }

    // MARK: Hours from the text alone

    /// A block of 60, 90 or 120 minutes (150, 180 and 240 when the text is taller than that) that begins on the hour and is
    /// centred on `centerMinute`: the centre of such a block is at :30, :45 or :00 (:15, :30, :00). The nearest of these
    /// centres wins; nothing within 12 minutes of any of them gives nil.
    static func fit(centerMinute: Double, textMinutes: Double) -> (start: Int, end: Int)? {
        var best: (error: Double, length: Int, center: Double)? = nil
        for (length, offset) in [(60, 30), (90, 45), (120, 0), (150, 15), (180, 30), (240, 0)] {
            // The text may be a little taller than its block (five lines in an hour): a fifth of leeway.
            if Double(length) * 1.2 < textMinutes { continue }
            let hours = ((centerMinute - Double(offset)) / 60).rounded()
            let center = hours * 60 + Double(offset)
            let error = abs(centerMinute - center)
            if best == nil || error < best!.error - 1e-9 { best = (error: error, length: length, center: center) }
        }
        guard let found = best, found.error <= 12 else { return nil }
        let start = Int((found.center - Double(found.length) / 2).rounded())
        return (start: start, end: start + found.length)
    }
}
