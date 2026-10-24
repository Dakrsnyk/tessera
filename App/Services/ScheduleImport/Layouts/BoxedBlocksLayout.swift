import Foundation
import CoreGraphics

/// A student timetable printed by a college report (the Cégep de l'Outaouais "Horaire de l'étudiant", RPHOR025): the
/// days are the columns ("Lun. 26 août"), the left margin has ONE label per half hour ("08:00", "08:30", ... "22:00")
/// centred in its row, and a class is a white rectangle with a thick black outline on a grid of thin grey lines. The
/// text is tiny and centred in the block: a title with its type ("Allemand I (T)", "(L)" for a lab), the code of the
/// course with its group ("609-C01-HU g.00001"), the room alone ("2.547", two of them when the class moves), the
/// teacher ("Chavant, L"). Titles, headings, a footer and handwriting over the grid are not classes: only a block with
/// the code of a course is (or, inside an outline, one whose code was lost but whose room and teacher were read).
///
/// A label names the row that STARTS at its time and is centred on it: the top of a block that begins at 08:00 is half a
/// row above the label "08:00". The hours of a block come from its outline (`BlockProbe.framedRuns`); without the image
/// (or where the outline is not found) from the middle of its text: the lengths of a block are 1 h, 1 h 30 or 2 h and it
/// begins on the hour, which tells them apart (a block centred on hh:00 is 2 h, on hh:30 it is 1 h, on hh:45 it is 1 h 30).
/// It is not Omnivox (rows of two hours, coloured cells) and not a calendar week view (text at the top of the block):
/// it claims its page.
///
/// What Vision really gives on such a page (measured on the CI simulator with synthetic pages): the label may stand on the
/// line of its time instead of in the middle of the row (the shift is measured from the outlines); a block can lose its
/// title and its code (two lines merged into one tall, garbled observation, or lines dropped), keeping only its room and its
/// teacher; the code can lose its first digits ("2-C01-HU g.000"); the title can lose its first letters ("imie générale (").
/// A block without a readable title takes the one of the blocks of the page that have the same room or teacher (to check),
/// and a cut title is completed from the whole titles of the page.
struct BoxedBlocksLayout: ScheduleLayout {
    let name = "boxedBlocks"
    let role = LayoutRole.claim

    /// What a block holds: its title and its room (or rooms, separated by " / ").
    struct Content {
        /// How much the lines say of a class: only a room or a teacher, both, or the code of a course.
        enum Evidence: Int { case fragment = 0, partial, code }

        var title: String
        var room: String?
        /// The teacher ("Moreau, T") when a line of the block is one.
        var teacher: String? = nil
        var evidence: Evidence = .code
    }

    /// A block found on the page, before its title is completed.
    struct Block {
        var column: Int
        var content: Content
        var start: Int
        var end: Int
        /// The hours come from the middle of the text, not from the outline.
        var estimated: Bool
        /// The title was completed or taken from another block of the page.
        var titleGuessed = false
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
        let clustersOf = columns.map { ScheduleParser.textClusters($0) }
        // The outlines of every column first: they also tell where the labels stand against the lines (see `labelShift`).
        var outlinesOf = [[ClosedRange<Double>]?](repeating: nil, count: count)
        if let probe = probe {
            for column in 0..<count where !clustersOf[column].isEmpty {
                outlinesOf[column] = ScheduleParser.columnRuns(probe, left: edges[column], from: max(0, Double(gridTop) - 0.004),
                                                               to: min(1, Double(gridBottom) + 0.004), kind: .framed)
            }
        }
        // The label of a row is usually centred in it (half a row below its top line); some pages write it on the line itself.
        // The place of the first label is the mean over all the labels (a label read a little off, or lost, does not move it).
        var originSum = 0.0
        for point in points {
            originSum += Double(point.y) - Double(point.minute - points[0].minute) / Double(stepMinutes) * Double(stepY)
        }
        let firstLabel = CGFloat(originSum / Double(points.count))
        let shift = BoxedBlocksLayout.labelShift(outlines: outlinesOf.compactMap { $0 }, firstLabel: firstLabel, step: stepY) ?? half
        func minute(at y: CGFloat) -> Double { WeekViewLayout.minute(at: y + shift, points: points) ?? 0 }

        var blocks: [Block] = []
        for (column, clusters) in clustersOf.enumerated() {
            for cluster in clusters {
                let center = Double(cluster.center)
                var enclosing: ClosedRange<Double>? = nil
                if let outlines = outlinesOf[column] {
                    enclosing = outlines.first { block in
                        let length = block.upperBound - block.lowerBound
                        return block.lowerBound <= center && center <= block.upperBound && length >= shortest && length <= longest
                    }
                }
                // A room or a teacher alone is a block only inside an outline.
                guard let content = BoxedBlocksLayout.content(of: cluster.lines, loose: enclosing != nil) else { continue }
                var span: (start: Int, end: Int)? = nil
                var estimated = false
                if let block = enclosing {
                    let start = WeekViewLayout.snapped(minute(at: CGFloat(block.lowerBound)), to: snapStep)
                    let end = WeekViewLayout.snapped(minute(at: CGFloat(block.upperBound)), to: snapStep)
                    if end - start >= snapStep { span = (start: start, end: end) }
                }
                if span == nil {
                    guard content.evidence == .code else { continue }
                    let heightMinutes = Double((cluster.bottom - cluster.top) / stepY) * Double(stepMinutes)
                    span = BoxedBlocksLayout.fit(centerMinute: minute(at: cluster.center), textMinutes: heightMinutes)
                    estimated = true
                }
                if let found = span {
                    blocks.append(Block(column: column, content: content, start: found.start, end: found.end, estimated: estimated))
                }
            }
        }
        // The page of this layout holds the code of a course in at least one block; a room and a teacher alone are not enough
        // to take a calendar for it.
        guard blocks.contains(where: { $0.content.evidence == .code }) else { return [] }
        blocks = BoxedBlocksLayout.withoutDuplicateFragments(blocks)
        BoxedBlocksLayout.completeTitles(&blocks)

        var drafts: [ScheduleParser.Draft] = []
        var fromOutline = 0
        for block in blocks where !block.content.title.isEmpty {
            // Hours from the middle of the text, not from the outline of the block: a guess.
            var uncertain: Set<SlotField> = []
            if block.estimated { uncertain.formUnion([.start, .end]) } else { fromOutline += 1 }
            if block.titleGuessed { uncertain.insert(.title) }
            if headers[block.column].fuzzy { uncertain.insert(.day) }
            drafts.append(ScheduleParser.Draft(weekday: headers[block.column].day, start: block.start, end: block.end,
                                               title: block.content.title, room: block.content.room, uncertain: uncertain,
                                               coded: block.content.evidence == .code))
        }
        // Not a calendar whose titles happen to hold the code of a course: the printed group ("g.00001") must be there, or
        // the outlines must have given the hours of most of the blocks.
        let printedGroup = lines.contains { BoxedBlocksLayout.matches(BoxedBlocksLayout.printedGroupRegex, $0.text) }
        guard printedGroup || fromOutline * 2 >= drafts.count else { return [] }
        return drafts
    }

    /// How far (in the height of the page) to move the place of an outline so that it falls on the label of its time. A label
    /// that is centred in its row has the top line of the row half a step above it (the college report): the shift is half a
    /// step. A label written on its line: no shift. Measured on the places of all the outlines against the first label, as
    /// the circular mean of their position in the step (a line is at the same place of the step everywhere); nil when the
    /// outlines are too few or do not agree, and the half step is then assumed.
    static func labelShift(outlines: [[ClosedRange<Double>]], firstLabel: CGFloat, step: CGFloat) -> CGFloat? {
        guard step > 0 else { return nil }
        var sumCos = 0.0
        var sumSin = 0.0
        var seen = 0.0
        for column in outlines {
            for run in column {
                for bound in [run.lowerBound, run.upperBound] {
                    let angle = 2 * Double.pi * (bound - Double(firstLabel)) / Double(step)
                    sumCos += cos(angle)
                    sumSin += sin(angle)
                    seen += 1
                }
            }
        }
        guard seen >= 6 else { return nil }
        let agreement = (sumCos * sumCos + sumSin * sumSin).squareRoot() / seen
        guard agreement >= 0.6 else { return nil }
        var place = atan2(sumSin, sumCos) / (2 * Double.pi)
        if place < 0 { place += 1 }
        // The lines are `place` of a step after a label: move up when that is little, down to the next label otherwise.
        return CGFloat(place < 0.25 ? -place : 1 - place) * step
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
    /// "2.547", "1.105", "A.201": a room written alone.
    static let dottedRoomRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #"^(?:\d{1,2}|[A-Z]{1,2})\.\d{2,3}$"#, options: [])
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

    /// A piece of a course code, whole or cut at the start ("202-C01-HU", "2-C01-HU", "530-1103-HU"): two dashes between short pieces
    /// and a digit somewhere (so "Rock-and-roll" is not one).
    static let codeTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?=.*\p{N})[\p{L}\p{N}]{1,4}(?:-[\p{L}\p{N}]{1,4}){2}$"#, options: [])

    /// A line of the title: without the pieces of a course code that Vision glued to it, nil when what is left is not a name
    /// (a line of digits and symbols, a lone bracket).
    static func titlePiece(_ text: String) -> String? {
        let words = text.split(separator: " ").map { String($0) }.filter { !matches(codeTokenRegex, $0) }
        let cleaned = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return ScheduleParser.isUnreadableTitle(cleaned) ? nil : cleaned
    }

    /// The title and the rooms of a block, or nil when the lines hold no code of a course (a heading, a note written over
    /// the grid). The title is what comes before the code; the teacher and the way the class is given are left out.
    /// Without a code, a room AND a teacher make a block too (Vision lost the two lines above them), and a room or a teacher
    /// alone does when `loose` (the block is outlined in the image); its title is then what stands above the room or the
    /// teacher, usually nothing.
    static func content(of lines: [RecognizedLine], loose: Bool = false) -> Content? {
        let texts = lines.map { $0.text }
        let codeIndex = texts.firstIndex(where: { codeStart(in: $0) != nil })
        var rooms: [String] = []
        var teacher: String? = nil
        var firstDetail: Int? = nil
        for (index, text) in texts.enumerated() where index != codeIndex {
            if matches(dottedRoomRegex, text) || ScheduleParser.isRoomLine(text) {
                rooms.append(text.trimmingCharacters(in: .whitespaces))
                if firstDetail == nil { firstDetail = index }
            } else if matches(teacherRegex, text) {
                if teacher == nil { teacher = text.trimmingCharacters(in: .whitespaces) }
                if firstDetail == nil { firstDetail = index }
            }
        }
        let evidence: Content.Evidence
        if codeIndex != nil {
            evidence = .code
        } else if !rooms.isEmpty && teacher != nil {
            evidence = .partial
        } else if loose && (!rooms.isEmpty || teacher != nil) {
            evidence = .fragment
        } else {
            return nil
        }
        let limit = codeIndex ?? firstDetail ?? texts.count
        var titles: [String] = []
        for (index, text) in texts.enumerated() {
            if index == codeIndex {
                if let piece = titlePiece(codeStart(in: text) ?? "") { titles.append(piece) }
                continue
            }
            guard index < limit else { continue }
            if matches(dottedRoomRegex, text) || ScheduleParser.isRoomLine(text) || matches(teacherRegex, text)
                || ScheduleParser.isModeLine(text) { continue }
            if let piece = titlePiece(text) { titles.append(piece) }
        }
        return Content(title: titles.prefix(2).joined(separator: " "), room: rooms.isEmpty ? nil : rooms.joined(separator: " / "),
                       teacher: teacher, evidence: evidence)
    }

    // MARK: Titles Vision cut or lost

    /// The type of a title at its end: "(T)", "(L)", cut short ("(T", "(").
    static let typeSuffixRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\s*\(\s*([A-Za-z]{0,2})\s*(\)?)\s*$"#, options: [])

    /// "Chimie générale (T)" -> base "Chimie générale", type "T", whole. A type that was cut ("Chimie générale (T", "imie générale (")
    /// is not whole.
    static func splitType(_ title: String) -> (base: String, type: String, whole: Bool, parenthesis: Bool) {
        let ns = title as NSString
        if let regex = typeSuffixRegex,
           let match = regex.firstMatch(in: title, options: [], range: NSRange(location: 0, length: ns.length)) {
            let base = ns.substring(to: match.range.location).trimmingCharacters(in: .whitespaces)
            let type = ScheduleParser.group(match, 1, in: ns) ?? ""
            let closed = ScheduleParser.group(match, 2, in: ns) ?? ""
            return (base, type, closed == ")" && !type.isEmpty, true)
        }
        return (title.trimmingCharacters(in: .whitespaces), "", false, false)
    }

    /// The text without a last word of one character that is not a letter ("elier de dessin 1": the "(T)" misread).
    static func withoutLoneTail(_ text: String) -> String {
        let words = text.split(separator: " ").map { String($0) }
        if words.count >= 2, let last = words.last, last.count == 1, !(last.first?.isLetter ?? false) {
            return words.dropLast().joined(separator: " ")
        }
        return text
    }

    /// A block without a code that sits in the same outline as a block read with its code is part of it, and a place holds
    /// one block without a code at most.
    static func withoutDuplicateFragments(_ blocks: [Block]) -> [Block] {
        func place(_ block: Block) -> String { "\(block.column)|\(block.start)|\(block.end)" }
        let withCode = Set(blocks.filter { $0.content.evidence == .code }.map { place($0) })
        var seen = Set<String>()
        var result: [Block] = []
        for block in blocks {
            if block.content.evidence != .code {
                let here = place(block)
                if withCode.contains(here) || seen.contains(here) { continue }
                seen.insert(here)
            }
            result.append(block)
        }
        return result
    }

    /// Completes the titles Vision cut or lost, from the whole titles of the same page ("Chimie générale (L)"):
    /// - a cut title ("imie générale (", "elier de dessin 1") takes the whole one that holds it, when only one does (the type
    ///   of the class, "(T)" or "(L)", stays the one that was read);
    /// - a block with no title at all (its title and its code were merged into one garbled line, or lost) takes the title of
    ///   the blocks that have the same room, else the same teacher, when they all agree.
    /// What is completed or taken that way is marked in doubt.
    static func completeTitles(_ blocks: inout [Block]) {
        func key(_ text: String) -> String { ScheduleParser.fold(text).trimmingCharacters(in: .whitespaces) }
        var known: [String: String] = [:]
        var baseOfRoom: [String: Set<String>] = [:]
        var baseOfTeacher: [String: Set<String>] = [:]
        for block in blocks where block.content.evidence == .code {
            let parts = splitType(block.content.title)
            guard parts.whole, parts.base.filter({ $0.isLetter }).count >= 4 else { continue }
            let base = key(parts.base)
            if known[base] == nil { known[base] = parts.base }
            for room in (block.content.room ?? "").components(separatedBy: " / ") where !room.isEmpty {
                baseOfRoom[key(room), default: []].insert(base)
            }
            if let teacher = block.content.teacher { baseOfTeacher[key(teacher), default: []].insert(base) }
        }
        guard !known.isEmpty else { return }
        for index in blocks.indices {
            let content = blocks[index].content
            if content.title.isEmpty {
                var fromRoom = Set<String>()
                for room in (content.room ?? "").components(separatedBy: " / ") where !room.isEmpty {
                    fromRoom.formUnion(baseOfRoom[key(room)] ?? [])
                }
                let fromTeacher: Set<String> = content.teacher.flatMap { baseOfTeacher[key($0)] } ?? []
                let candidates = fromRoom.isEmpty ? fromTeacher : (fromTeacher.isEmpty ? fromRoom : fromRoom.intersection(fromTeacher))
                if candidates.count == 1, let base = candidates.first, let shown = known[base] {
                    blocks[index].content.title = shown
                    blocks[index].titleGuessed = true
                }
                continue
            }
            let parts = splitType(content.title)
            if parts.whole { continue }
            let base = withoutLoneTail(parts.base)
            let ending = parts.type.isEmpty ? "" : " (\(parts.type))"
            if base.filter({ $0.isLetter }).count >= 5 {
                let wanted = key(base)
                let matching = known.keys.filter { $0.contains(wanted) }
                if matching.count == 1, let shown = known[matching[0]] {
                    blocks[index].content.title = shown + ending
                    blocks[index].titleGuessed = true
                    continue
                }
            }
            // Nothing to complete it with: only close the type that was cut ("Initiation à la linguistique (T" -> "(T)").
            if parts.parenthesis {
                blocks[index].content.title = parts.base + ending
            }
        }
    }

    // MARK: Hours from the text alone

    /// A block of 60, 90 or 120 minutes (150, 180 and 240 when the text is taller than 2 h) that begins on the hour and is
    /// centred on `centerMinute`: the centre of such a block is at :30, :45 or :00 (:15, :30, :00). The nearest of these
    /// centres wins; nothing within 12 minutes of any of them gives nil.
    static func fit(centerMinute: Double, textMinutes: Double) -> (start: Int, end: Int)? {
        var best: (error: Double, length: Int, center: Double)? = nil
        // 1 h, 1 h 30 and 2 h; longer blocks only for a text too tall for these.
        let usual = [(60, 30), (90, 45), (120, 0)]
        let longer = [(150, 15), (180, 30), (240, 0)]
        for (length, offset) in textMinutes > 120 * 1.2 ? usual + longer : usual {
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
