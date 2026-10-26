import Foundation
import CoreGraphics
@testable import Ardane

// Reference timetables at the level of `RecognizedLine` (what Vision would give: one observation per line of text, a
// place on the page normalised 0...1 with the origin at the top left), each with the answer checked by hand, and a
// deterministic OCR noise injector. Used by ScheduleEvaluationTests, which scores the importer against them.
// All names of people and subjects are invented: no personal data.

private typealias Fx = LayoutFixtures

/// A class the importer must find on a reference page (ISO weekday, minutes since midnight).
struct ReferenceSlot: Equatable {
    var day: Int
    var start: Int
    var end: Int
    var title: String
    var room: String? = nil
}

/// One reference page: its lines of text, the colours of the image when the layout needs them, and the answer.
struct ReferenceSchedule {
    var name: String
    var lines: [RecognizedLine]
    var probe: BlockProbe? = nil
    var expected: [ReferenceSlot]

    /// The same page read without the image (the probe says nothing).
    func withoutProbe() -> ReferenceSchedule {
        var copy = self
        copy.probe = nil
        copy.name = name + "-sans-sonde"
        return copy
    }
}

// MARK: Pseudo-random numbers with a seed

/// SplitMix64: the same seed always gives the same numbers, on every machine.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// A number in 0..<1.
    mutating func unit() -> Double {
        Double(next() >> 11) / 9007199254740992.0
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    /// A number in -amount...amount.
    mutating func offset(_ amount: Double) -> Double {
        (unit() * 2 - 1) * amount
    }

    /// An index in 0..<count (0 when count is 0).
    mutating func index(_ count: Int) -> Int {
        Int(next() % UInt64(max(count, 1)))
    }
}

// MARK: OCR noise

/// Degrades the lines of a clean page the way a poor photo or a small font would: look-alike characters (O and 0, I or l
/// and 1, S and 5, B and 8), letters lost or changed in the names of the days ("Lur", "Mardl"), lines fused or cut,
/// positions that move by up to 0.002, stray marks, and a reading order that changes. Level 0 changes nothing; level 1
/// is a mild noise, level 2 a heavy one. The same level and seed always give the same lines.
struct OCRNoise {
    var level: Int
    var seed: UInt64

    /// A seed that depends on the page, the level and the run, and never on the process (`hashValue` changes on each launch).
    static func seed(name: String, level: Int, run: Int) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        hash = (hash ^ UInt64(level)) &* 0x100000001b3
        hash = (hash ^ UInt64(run)) &* 0x100000001b3
        return hash
    }

    func apply(to lines: [RecognizedLine]) -> [RecognizedLine] {
        guard level > 0 else { return lines }
        var rng = SeededGenerator(seed: seed)
        let charRate = level == 1 ? 0.02 : 0.05
        let dayRate = level == 1 ? 0.12 : 0.30
        let mergeRate = level == 1 ? 0.02 : 0.06
        let splitRate = level == 1 ? 0.02 : 0.05
        let strayCount = level == 1 ? 2 : 5

        var result: [RecognizedLine] = []
        for line in lines {
            var text = OCRNoise.confuse(line.text, rate: charRate, rng: &rng)
            text = OCRNoise.damageDay(text, rate: dayRate, rng: &rng)
            var box = line.box
            box.origin.x += CGFloat(rng.offset(0.002))
            box.origin.y += CGFloat(rng.offset(0.002))
            result.append(RecognizedLine(text: text, box: box))
        }
        result = OCRNoise.fused(result, rate: mergeRate, rng: &rng)
        result = OCRNoise.cut(result, rate: splitRate, rng: &rng)
        for _ in 0..<strayCount {
            let text = OCRNoise.strayTexts[rng.index(OCRNoise.strayTexts.count)]
            let x = 0.02 + rng.unit() * 0.94
            let y = 0.02 + rng.unit() * 0.94
            result.append(RecognizedLine(text: text, box: CGRect(x: x, y: y, width: 0.02, height: 0.012)))
        }
        return result.shuffled(using: &rng)
    }

    // MARK: Pieces (internal so the tests can check them one by one)

    static let lookalikes: [Character: [Character]] = [
        "O": ["0"], "0": ["O"], "I": ["1"], "l": ["1"], "1": ["l", "I"], "S": ["5"], "5": ["S"], "B": ["8"], "8": ["B"]
    ]

    /// Each character that has a look-alike is replaced with it with the probability `rate`.
    static func confuse(_ text: String, rate: Double, rng: inout SeededGenerator) -> String {
        var out = ""
        for character in text {
            if let options = lookalikes[character], rng.chance(rate) {
                out.append(options[rng.index(options.count)])
            } else {
                out.append(character)
            }
        }
        return out
    }

    static let dayWords: Set<String> = [
        "lun", "lundi", "mar", "mardi", "mer", "mercredi", "jeu", "jeudi", "ven", "vendredi", "sam", "samedi", "dim", "dimanche",
        "mon", "monday", "tue", "tuesday", "wed", "wednesday", "thu", "thursday", "fri", "friday", "sat", "saturday", "sun", "sunday",
        "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag"
    ]

    /// Letters that a poor reading takes for another ("Mardi" read "Mardl", "Lun" read "Lur").
    static let dayConfusions: [String: Character] = ["i": "l", "n": "r", "e": "c", "u": "v", "d": "o", "a": "o", "r": "n", "t": "l"]

    /// When the first word of the text is the name of a day, with the probability `rate` one of its letters (never the
    /// first) is lost or changed.
    static func damageDay(_ text: String, rate: Double, rng: inout SeededGenerator) -> String {
        var words = text.split(separator: " ", omittingEmptySubsequences: false).map { String($0) }
        guard let first = words.first else { return text }
        let key = first.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,:;"))
        guard key.count >= 3, dayWords.contains(key), rng.chance(rate) else { return text }
        var letters = Array(first)
        guard letters.count >= 3 else { return text }
        let at = 1 + rng.index(letters.count - 1)
        if rng.chance(0.5) {
            letters.remove(at: at)
        } else if let swapped = dayConfusions[String(letters[at]).lowercased()] {
            letters[at] = swapped
        } else {
            letters.remove(at: at)
        }
        words[0] = String(letters)
        return words.joined(separator: " ")
    }

    static let strayTexts = ["|", "-", "I", "ii", "\u{2022}", "0", "~", "l.", "\u{2014}"]

    /// Two lines that touch (one under the other in the same column, or side by side on the same row).
    static func adjacent(_ a: CGRect, _ b: CGRect) -> Bool {
        let below = abs(a.midX - b.midX) <= 0.03 && b.minY - a.maxY >= -0.002 && b.minY - a.maxY <= 0.012
        let beside = abs(a.midY - b.midY) <= 0.004 && b.minX - a.maxX >= -0.002 && b.minX - a.maxX <= 0.03
        return below || beside
    }

    /// With the probability `rate` a line is fused with the next one that touches it (Vision does that with close texts).
    static func fused(_ lines: [RecognizedLine], rate: Double, rng: inout SeededGenerator) -> [RecognizedLine] {
        let order = lines.indices.sorted { a, b in
            if lines[a].box.minY != lines[b].box.minY { return lines[a].box.minY < lines[b].box.minY }
            return lines[a].box.minX < lines[b].box.minX
        }
        var used = Set<Int>()
        var out: [RecognizedLine] = []
        for (position, i) in order.enumerated() {
            if used.contains(i) { continue }
            used.insert(i)
            var current = lines[i]
            if rng.chance(rate) {
                for j in order.dropFirst(position + 1).prefix(12) where !used.contains(j) {
                    if adjacent(current.box, lines[j].box) {
                        used.insert(j)
                        current = RecognizedLine(text: current.text + " " + lines[j].text, box: current.box.union(lines[j].box))
                        break
                    }
                }
            }
            out.append(current)
        }
        return out
    }

    /// With the probability `rate` a line of three words or more is cut in two (the box is shared out by length).
    static func cut(_ lines: [RecognizedLine], rate: Double, rng: inout SeededGenerator) -> [RecognizedLine] {
        var out: [RecognizedLine] = []
        for line in lines {
            let words = line.text.split(separator: " ").map { String($0) }
            guard words.count >= 3, rng.chance(rate) else {
                out.append(line)
                continue
            }
            let middle = words.count / 2
            let left = words[0..<middle].joined(separator: " ")
            let right = words[middle...].joined(separator: " ")
            let share = CGFloat(left.count) / CGFloat(max(line.text.count, 1))
            let box = line.box
            out.append(RecognizedLine(text: left, box: CGRect(x: box.minX, y: box.minY, width: box.width * share, height: box.height)))
            out.append(RecognizedLine(text: right, box: CGRect(x: box.minX + box.width * share, y: box.minY,
                                                               width: box.width * (1 - share), height: box.height)))
        }
        return out
    }
}

// MARK: Probe of the outlines (boxed blocks)

/// Plays the probe over a page whose blocks are drawn with a thick outline: the stretches between two outlines, per column.
private struct FixtureFramedProbe: BlockProbe {
    /// The outlines of each column of the page (pixels), top to bottom.
    var outlines: [[Double]]
    var edges: [Double]
    var width: Double
    var height: Double

    func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? { nil }

    func framedRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
        let pixel = x * width
        guard let column = (0..<outlines.count).first(where: { pixel >= edges[$0] && pixel < edges[$0 + 1] }) else { return [] }
        var runs: [ClosedRange<Double>] = []
        for (low, high) in zip(outlines[column], outlines[column].dropFirst()) {
            let from = max(low / height, fromY)
            let to = min(high / height, toY)
            if from < to { runs.append(from...to) }
        }
        return runs
    }
}

// MARK: Omnivox pages

/// A white block of an Omnivox grid: its column (0 = Monday), the rows it covers (0 = 08:10...09:00) and its lines of text.
private struct OmnivoxBlockSpec {
    var column: Int
    var first: Int
    var last: Int
    var title: [String]
    /// "101-ALG-CH gr.11010": the code of the course and its group.
    var code: String
    var room: String
    var teacher: String
}

/// A row of the "Liste des cours" above the grid.
private struct OmnivoxCourseSpec {
    var code: String
    var group: String
    var title: String
    var teacher: String
}

/// An Omnivox screenshot (924 x 2000 points) as Vision would read it: the lines of text with their height on the page.
private enum OmnivoxPage {
    static let width = 924.0
    static let height = 2000.0
    static let centers: [Double] = [277, 386, 494, 602, 710]
    static let days = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]
    static let hours: [(String, String)] = [
        ("08:10", "09:00"), ("09:05", "09:55"), ("10:05", "10:55"), ("11:00", "11:50"), ("12:00", "12:50"),
        ("13:00", "13:50"), ("14:00", "14:50"), ("15:00", "15:50"), ("15:55", "16:45"), ("16:50", "17:40")
    ]

    static func line(_ text: String, x: Double, y: Double, width wide: Double? = nil) -> RecognizedLine {
        let w = wide ?? min(100, Double(text.count) * 4.6)
        return RecognizedLine(text: text, box: CGRect(x: (x - w / 2) / width, y: (y - 5) / height, width: w / width, height: 10 / height))
    }

    /// The lines and the probe of a page. `rows` are the 11 edges of the 10 rows, in points from the top.
    static func make(headerY: Double, rows: [Double], listY: Double, courses: [OmnivoxCourseSpec],
                     blocks: [OmnivoxBlockSpec]) -> (lines: [RecognizedLine], probe: BlockProbe) {
        var result: [RecognizedLine] = []
        result.append(line("Horaire de cours", x: 462, y: 237))
        result.append(line("Cliquez ici pour une", x: 233, y: 312, width: 140))
        result.append(line("Informations personnelles", x: 288, y: 395, width: 260))
        result.append(line("Nom, Prénom", x: 198, y: 419))
        result.append(line("Roy, Camille", x: 415, y: 419))
        result.append(line("No étudiant", x: 198, y: 438))
        result.append(line("1234567", x: 426, y: 438))
        result.append(line("Programme", x: 193, y: 457))
        result.append(line("000.A0", x: 428, y: 457))
        result.append(line("Généré le", x: 500, y: 457))
        result.append(line("11-jan-2024 16:26", x: 712, y: 457))
        result.append(line("Liste des cours", x: 234, y: listY - 20, width: 150))
        result.append(line("Date d' annulation maximum", x: 229, y: listY, width: 140))
        result.append(line("Numéro", x: 333, y: listY, width: 40))
        result.append(line("Titre du cours", x: 442, y: listY, width: 70))
        for (index, course) in courses.enumerated() {
            let y = listY + 15.5 * Double(index + 1)
            result.append(line("19-sep", x: 172, y: y, width: 30))
            result.append(line(course.code, x: 338, y: y, width: 50))
            result.append(line(course.group, x: 387, y: y, width: 26))
            let titleWidth = Double(course.title.count) * 4.2
            result.append(line(course.title, x: 408 + titleWidth / 2, y: y, width: titleWidth))
            result.append(line(course.teacher, x: 700, y: y, width: 70))
        }
        result.append(line("Horaire de cours pour la session", x: 320, y: headerY - 77, width: 320))
        result.append(line("Afficher mon horaire par semaine", x: 283, y: headerY - 39, width: 200))
        for (index, name) in days.enumerated() {
            result.append(line(name, x: centers[index], y: headerY, width: 40))
        }
        for (index, pair) in hours.enumerated() {
            let middle = (rows[index] + rows[index + 1]) / 2
            result.append(line(pair.0, x: 194, y: middle - 13, width: 28))
            result.append(line(pair.1, x: 194, y: middle + 13, width: 28))
        }
        for block in blocks {
            let middle = (rows[block.first] + rows[block.last + 1]) / 2
            let texts = block.title + [block.code, block.room, block.teacher, "Présentiel"]
            for (index, text) in texts.enumerated() {
                let y = middle + (Double(index) - Double(texts.count - 1) / 2) * 13
                result.append(line(text, x: centers[block.column], y: y))
            }
        }
        let bottom = rows[rows.count - 1]
        result.append(line("Accès à Omnivox", x: 244, y: bottom + 64, width: 170))
        result.append(line("Tout au long de la session, vous pouvez accéder à Omnivox à l'adresse https://exemple.omnivox.ca",
                           x: 360, y: bottom + 82, width: 400))
        result.append(line("Retourner au choix de la session", x: 200, y: bottom + 146, width: 190))

        // The white blocks of each column; blocks that touch make one stretch.
        var columns = [[ClosedRange<Double>]](repeating: [], count: 5)
        for block in blocks.sorted(by: { $0.first < $1.first }) {
            let low = rows[block.first] / height
            let high = rows[block.last + 1] / height
            if let previous = columns[block.column].last, low - previous.upperBound <= 1 / height {
                columns[block.column][columns[block.column].count - 1] = previous.lowerBound...high
            } else {
                columns[block.column].append(low...high)
            }
        }
        let edges = [223.0, 331.0, 439.0, 547.0, 655.0, 763.0].map { $0 / width }
        return (result, ColourColumnsProbe(edges: edges, lighter: columns, darker: nil))
    }
}

// MARK: Boxed blocks (the "Horaire de l'étudiant" of a college)

/// A block of the boxed page: its column, the half-hour rows it covers (0 = 08:00) and its text.
private struct BoxedBlockSpec {
    var column: Int
    var from: Int
    var to: Int
    var title: String
    var code: String
    var rooms: [String]
    var teacher: String
}

/// The page is a 790 x 1023 picture: the day headings, one label per half hour, a thick outline around each block.
private enum BoxedPage {
    static let width = 790.0
    static let height = 1023.0
    static let columnCenters: [Double] = [151, 286, 421, 556, 690]
    static let firstRowTop = 287.0
    static let rowHeight = 22.55

    static func pixelLine(_ text: String, _ cx: Double, _ cy: Double, _ w: Double = 80, _ h: Double = 9) -> RecognizedLine {
        RecognizedLine(text: text, box: CGRect(x: (cx - w / 2) / width, y: (cy - h / 2) / height, width: w / width, height: h / height))
    }

    static func lines(blocks: [BoxedBlockSpec]) -> [RecognizedLine] {
        var result: [RecognizedLine] = []
        for (column, name) in ["Lun. 26 août", "Mar. 27 août", "Mer. 28 août", "Jeu. 29 août", "Ven. 30 août"].enumerated() {
            result.append(pixelLine(name, columnCenters[column], 266, 90, 12))
        }
        for step in 0..<29 {
            let minutes = 8 * 60 + 30 * step
            result.append(pixelLine(String(format: "%02d:%02d", minutes / 60, minutes % 60), 60, 295 + rowHeight * Double(step), 36, 10))
        }
        for block in blocks {
            let middle = firstRowTop + rowHeight * Double(block.from + block.to) / 2
            let texts = [block.title, block.code] + block.rooms + [block.teacher]
            for (index, text) in texts.enumerated() {
                result.append(pixelLine(text, columnCenters[block.column], middle + (Double(index) - Double(texts.count - 1) / 2) * 11.5))
            }
        }
        // Everything around the grid that is not a class.
        result.append(pixelLine("Arts", 412, 70, 140, 36))
        result.append(pixelLine("et lettres", 412, 108, 190, 36))
        result.append(pixelLine("Horaire de l'étudiant", 680, 58, 170, 14))
        result.append(pixelLine("Semaine du 26 août 2024", 690, 81, 150, 11))
        result.append(pixelLine("Nom, Prénom (No et code permanent)", 140, 143, 210, 10))
        result.append(pixelLine("500.A1 - Arts et lettres (1234567)", 160, 166, 250, 10))
        result.append(pixelLine("SPE 1", 740, 143, 40, 10))
        result.append(pixelLine("CAM - Campus principal", 710, 166, 120, 10))
        result.append(pixelLine("Casier : H-0000", 80, 186, 100, 10))
        result.append(pixelLine("Messages à l'horaire", 85, 205, 110, 10))
        result.append(pixelLine("7 cours / 15 blocs / 26 heures", 435, 215, 350, 22))
        result.append(pixelLine("2024-08-20 14:29", 95, 975, 110, 10))
        result.append(pixelLine("RPHOR025 - Horaire de l'étudiant", 680, 975, 170, 10))
        // A note written over the grid, in the Wednesday column, between two blocks.
        for (y, text) in [(448.0, "Jamais de"), (470.0, "cours les"), (514.0, "mercredis"), (536.0, "midi")] {
            result.append(pixelLine(text, columnCenters[2], y, 100, 17))
        }
        return result
    }

    fileprivate static func probe(blocks: [BoxedBlockSpec]) -> FixtureFramedProbe {
        var outlines: [[Double]] = []
        for column in 0..<5 {
            var edges = Set<Double>()
            for block in blocks where block.column == column {
                edges.insert(firstRowTop + rowHeight * Double(block.from))
                edges.insert(firstRowTop + rowHeight * Double(block.to))
            }
            outlines.append(edges.sorted())
        }
        return FixtureFramedProbe(outlines: outlines, edges: [84, 219, 354, 489, 623, 758], width: width, height: height)
    }
}

// MARK: The corpus

enum ScheduleCorpus {

    // MARK: Helpers

    /// "10:05" to minutes since midnight.
    static func minutes(_ text: String) -> Int {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return 0 }
        return hour * 60 + minute
    }

    /// A class of the answer, written like on the page: day (1 = Monday), start, end, title, room.
    static func slot(_ day: Int, _ from: String, _ to: String, _ title: String, _ room: String? = nil) -> ReferenceSlot {
        ReferenceSlot(day: day, start: minutes(from), end: minutes(to), title: title, room: room)
    }

    /// The lines of a cell of a grid, one under the other from `y`, centred on `cx`.
    private static func cellLines(_ texts: [String], cx: Double, y: Double, width: Double = 0.12) -> [RecognizedLine] {
        texts.enumerated().map { Fx.line($1, cx, y + 0.022 * Double($0), width, 0.016) }
    }

    private static func columnMajor(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        lines.sorted { a, b in a.box.minX != b.box.minX ? a.box.minX < b.box.minX : a.box.minY < b.box.minY }
    }

    private static func rowMajor(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        lines.sorted { a, b in a.box.minY != b.box.minY ? a.box.minY < b.box.minY : a.box.minX < b.box.minX }
    }

    private static func reversed(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        Array(lines.reversed())
    }

    private static func jumbled(_ lines: [RecognizedLine], seed: UInt64) -> [RecognizedLine] {
        var rng = SeededGenerator(seed: seed)
        return lines.shuffled(using: &rng)
    }

    /// The reference pages, then the same pages read without the image (for those that have one).
    static let all: [ReferenceSchedule] = [
        omnivoxSession(), omnivoxThreeRows(), boxedOutaouais(), weekViewCalendar(), schoolGridPeriods(), transposedGrid(),
        dayByDayList(), table(), universityList(), japanesePeriods(), german24Hours(), english12Hours(), twoRooms(),
        breaksSchoolGrid(), freeSlotsFrench(), freeSlotsEnglish(), weekend()
    ]

    /// What is scored: the pages, and those that hold a probe a second time without it.
    static let scored: [ReferenceSchedule] = all + all.filter { $0.probe != nil }.map { $0.withoutProbe() }

    // MARK: 1. Omnivox (pairs of hours in the margin, white blocks)

    private static let omnivoxRows: [Double] = [773, 815, 858, 900, 969, 1011, 1054, 1096, 1139, 1181, 1223]

    /// 4 courses, 7 blocks, the list of courses above the grid gives the full titles.
    private static func omnivoxSession() -> ReferenceSchedule {
        let algebra = OmnivoxCourseSpec(code: "101-ALG-CH", group: "11010", title: "Algèbre linéaire et applications", teacher: "Alice Martel")
        let waves = OmnivoxCourseSpec(code: "202-PHY-CH", group: "22020", title: "Physique des ondes", teacher: "Bruno Garnier")
        let design = OmnivoxCourseSpec(code: "330-HIS-CH", group: "33030", title: "Histoire du design moderne", teacher: "Chloé Bernard")
        let english = OmnivoxCourseSpec(code: "604-ANG-CH", group: "60040", title: "Anglais de communication", teacher: "David Lemieux")
        func block(_ column: Int, _ first: Int, _ last: Int, _ cut: String, _ course: OmnivoxCourseSpec, _ room: String) -> OmnivoxBlockSpec {
            OmnivoxBlockSpec(column: column, first: first, last: last, title: [cut], code: course.code + " gr." + course.group,
                             room: room, teacher: course.teacher)
        }
        let blocks = [
            block(0, 2, 3, "Algèbre linéaire et", algebra, "Local A1010"),
            block(1, 0, 1, "Physique des ondes", waves, "Local B2020"),
            block(1, 5, 6, "Histoire du design", design, "Local C3030"),
            block(2, 2, 3, "Algèbre linéaire et", algebra, "Local A1010"),
            block(3, 7, 8, "Anglais de communic", english, "Local D4040"),
            block(4, 0, 1, "Physique des ondes", waves, "Local B2020"),
            block(4, 5, 5, "Histoire du design", design, "Local C3030")
        ]
        let page = OmnivoxPage.make(headerY: 763, rows: omnivoxRows, listY: 570, courses: [algebra, waves, design, english], blocks: blocks)
        let expected = [
            slot(1, "10:05", "11:50", "Algèbre linéaire et applications", "Local A1010"),
            slot(2, "08:10", "09:55", "Physique des ondes", "Local B2020"),
            slot(2, "13:00", "14:50", "Histoire du design moderne", "Local C3030"),
            slot(3, "10:05", "11:50", "Algèbre linéaire et applications", "Local A1010"),
            slot(4, "15:00", "16:45", "Anglais de communication", "Local D4040"),
            slot(5, "08:10", "09:55", "Physique des ondes", "Local B2020"),
            slot(5, "13:00", "13:50", "Histoire du design moderne", "Local C3030")
        ]
        return ReferenceSchedule(name: "omnivox-session", lines: page.lines, probe: page.probe, expected: expected)
    }

    /// 3 courses, 7 blocks, one block over three rows (09:05 to 11:50), rows of unequal height.
    private static func omnivoxThreeRows() -> ReferenceSchedule {
        let objects = OmnivoxCourseSpec(code: "420-PRG-CH", group: "42010", title: "Programmation orientée objet", teacher: "Éric Fontaine")
        let stats = OmnivoxCourseSpec(code: "360-MAT-CH", group: "36020", title: "Statistiques appliquées", teacher: "Fatima Haddad")
        let literature = OmnivoxCourseSpec(code: "607-LIT-CH", group: "60730", title: "Littérature et société", teacher: "Gabriel Roy")
        func block(_ column: Int, _ first: Int, _ last: Int, _ cut: String, _ course: OmnivoxCourseSpec, _ room: String) -> OmnivoxBlockSpec {
            OmnivoxBlockSpec(column: column, first: first, last: last, title: [cut], code: course.code + " gr." + course.group,
                             room: room, teacher: course.teacher)
        }
        let blocks = [
            block(0, 1, 3, "Littérature et soci", literature, "Local F6033"),
            block(1, 2, 3, "Programmation orient", objects, "Local E5011"),
            block(1, 5, 5, "Statistiques appliqu", stats, "Local E5022"),
            block(2, 1, 1, "Programmation orient", objects, "Local E5011"),
            block(2, 7, 8, "Statistiques appliqu", stats, "Local E5022"),
            block(4, 2, 3, "Statistiques appliqu", stats, "Local E5022"),
            block(4, 5, 6, "Programmation orient", objects, "Local E5011")
        ]
        let rows: [Double] = [759, 802, 870, 914, 955, 998, 1066, 1110, 1151, 1194, 1237]
        let page = OmnivoxPage.make(headerY: 749, rows: rows, listY: 572, courses: [objects, stats, literature], blocks: blocks)
        let expected = [
            slot(1, "09:05", "11:50", "Littérature et société", "Local F6033"),
            slot(2, "10:05", "11:50", "Programmation orientée objet", "Local E5011"),
            slot(2, "13:00", "13:50", "Statistiques appliquées", "Local E5022"),
            slot(3, "09:05", "09:55", "Programmation orientée objet", "Local E5011"),
            slot(3, "15:00", "16:45", "Statistiques appliquées", "Local E5022"),
            slot(5, "10:05", "11:50", "Statistiques appliquées", "Local E5022"),
            slot(5, "13:00", "14:50", "Programmation orientée objet", "Local E5011")
        ]
        return ReferenceSchedule(name: "omnivox-bloc-3-rangees", lines: columnMajor(page.lines), probe: page.probe, expected: expected)
    }

    // MARK: 2. Boxed blocks of the Cégep de l'Outaouais (a label every 30 minutes, 15 blocks, 26 hours)

    private static let boxedBlocks: [BoxedBlockSpec] = [
        BoxedBlockSpec(column: 0, from: 0, to: 4, title: "Physique méca (T)", code: "203-PHM-05 g.00002", rooms: ["2.101"], teacher: "Lavoie, M"),
        BoxedBlockSpec(column: 0, from: 4, to: 6, title: "Physique méca (L)", code: "203-PHM-05 g.00002", rooms: ["2.215"], teacher: "Lavoie, M"),
        BoxedBlockSpec(column: 0, from: 10, to: 14, title: "Calcul intég (T)", code: "201-CAL-05 g.00003", rooms: ["2.037"], teacher: "Girard, P"),
        BoxedBlockSpec(column: 1, from: 2, to: 4, title: "Chimie org (T)", code: "202-CHO-05 g.00001", rooms: ["1.105"], teacher: "Perrin, A"),
        BoxedBlockSpec(column: 1, from: 4, to: 8, title: "Chimie org (L)", code: "202-CHO-05 g.00001", rooms: ["1.614", "1.710"], teacher: "Perrin, A"),
        BoxedBlockSpec(column: 1, from: 10, to: 14, title: "Philo et éthi (T)", code: "340-PHE-05 g.00004", rooms: ["2.913"], teacher: "Roux, S"),
        BoxedBlockSpec(column: 1, from: 14, to: 16, title: "Rédaction (T)", code: "601-RED-05 g.00002", rooms: ["2.005"], teacher: "Fabre, N"),
        BoxedBlockSpec(column: 2, from: 2, to: 6, title: "Anglais II (T)", code: "604-ANG-05 g.00005", rooms: ["2.311"], teacher: "Morel, C"),
        BoxedBlockSpec(column: 2, from: 12, to: 14, title: "Chimie org (T)", code: "202-CHO-05 g.00001", rooms: ["1.105"], teacher: "Perrin, A"),
        BoxedBlockSpec(column: 2, from: 16, to: 20, title: "Calcul intég (T)", code: "201-CAL-05 g.00003", rooms: ["2.045"], teacher: "Girard, P"),
        BoxedBlockSpec(column: 3, from: 0, to: 4, title: "Rédaction (T)", code: "601-RED-05 g.00002", rooms: ["2.005"], teacher: "Fabre, N"),
        BoxedBlockSpec(column: 3, from: 12, to: 16, title: "Éducation phy (T)", code: "109-EDP-05 g.00006", rooms: ["0.101"], teacher: "Blanc, T"),
        BoxedBlockSpec(column: 4, from: 0, to: 4, title: "Physique méca (T)", code: "203-PHM-05 g.00002", rooms: ["2.101"], teacher: "Lavoie, M"),
        BoxedBlockSpec(column: 4, from: 4, to: 8, title: "Philo et éthi (T)", code: "340-PHE-05 g.00004", rooms: ["2.913"], teacher: "Roux, S"),
        BoxedBlockSpec(column: 4, from: 12, to: 16, title: "Anglais II (T)", code: "604-ANG-05 g.00005", rooms: ["2.311"], teacher: "Morel, C")
    ]

    /// The answer of the boxed page, block by block (the half-hour row k starts at 08:00 + 30 k minutes). 7 courses, 15 blocks,
    /// 26 hours, as the heading of the page says.
    static let boxedExpected: [ReferenceSlot] = [
        slot(1, "08:00", "10:00", "Physique méca (T)", "2.101"),
        slot(1, "10:00", "11:00", "Physique méca (L)", "2.215"),
        slot(1, "13:00", "15:00", "Calcul intég (T)", "2.037"),
        slot(2, "09:00", "10:00", "Chimie org (T)", "1.105"),
        slot(2, "10:00", "12:00", "Chimie org (L)", "1.614 / 1.710"),
        slot(2, "13:00", "15:00", "Philo et éthi (T)", "2.913"),
        slot(2, "15:00", "16:00", "Rédaction (T)", "2.005"),
        slot(3, "09:00", "11:00", "Anglais II (T)", "2.311"),
        slot(3, "14:00", "15:00", "Chimie org (T)", "1.105"),
        slot(3, "16:00", "18:00", "Calcul intég (T)", "2.045"),
        slot(4, "08:00", "10:00", "Rédaction (T)", "2.005"),
        slot(4, "14:00", "16:00", "Éducation phy (T)", "0.101"),
        slot(5, "08:00", "10:00", "Physique méca (T)", "2.101"),
        slot(5, "10:00", "12:00", "Philo et éthi (T)", "2.913"),
        slot(5, "14:00", "16:00", "Anglais II (T)", "2.311")
    ]

    private static func boxedOutaouais() -> ReferenceSchedule {
        ReferenceSchedule(name: "outaouais-encadre", lines: reversed(BoxedPage.lines(blocks: boxedBlocks)),
                          probe: BoxedPage.probe(blocks: boxedBlocks), expected: boxedExpected)
    }

    // MARK: 3. Calendar week view (blocks with their hours)

    private static func weekViewCalendar() -> ReferenceSchedule {
        var lines = Fx.weekHeader(["lun. 21", "mar. 22", "mer. 23", "jeu. 24", "ven. 25"], hourLabels: (8..<18).map { String(format: "%02d:00", $0) })
        lines += Fx.event(0, startMinute: 510, "Statistiques", hours: "8:30 – 10:00", room: "Salle 12")
        lines += Fx.event(1, startMinute: 600, "Géographie", hours: "10:00 – 11:30")
        lines += Fx.event(2, startMinute: 780, "Informatique", hours: "13:00 – 15:00", room: "B-204")
        lines += Fx.event(3, startMinute: 540, "Théâtre", hours: "9:00 – 10:30")
        lines += Fx.event(3, startMinute: 840, "Espagnol", hours: "14:00 – 15:00", room: "A-110")
        lines += Fx.event(4, startMinute: 600, "Dessin", hours: "10:00 – 12:00", room: "Salle 3")
        let expected = [
            slot(1, "08:30", "10:00", "Statistiques", "Salle 12"),
            slot(2, "10:00", "11:30", "Géographie"),
            slot(3, "13:00", "15:00", "Informatique", "B-204"),
            slot(4, "09:00", "10:30", "Théâtre"),
            slot(4, "14:00", "15:00", "Espagnol", "A-110"),
            slot(5, "10:00", "12:00", "Dessin", "Salle 3")
        ]
        return ReferenceSchedule(name: "semaine-calendrier", lines: reversed(lines), expected: expected)
    }

    // MARK: 4. School grid with the periods in the margin

    private static func schoolGridPeriods() -> ReferenceSchedule {
        var lines = Fx.schoolHeader(["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"]) + Fx.marginLabels(Fx.periodLabels)
        lines += Fx.cell(0, 0, "Algèbre", "B12") + Fx.cell(0, 1, "Géographie", "A10") + Fx.cell(1, 0, "Littérature", "C30")
        lines += Fx.cell(2, 4, "Musique") + Fx.cell(3, 5, "Théâtre") + Fx.cell(4, 2, "Biologie", "Lab 2")
        let expected = [
            slot(1, "08:00", "09:00", "Algèbre", "B12"),
            slot(1, "09:00", "10:00", "Géographie", "A10"),
            slot(2, "08:00", "09:00", "Littérature", "C30"),
            slot(3, "13:30", "14:30", "Musique"),
            slot(4, "14:30", "15:30", "Théâtre"),
            slot(5, "10:15", "11:15", "Biologie", "Lab 2")
        ]
        return ReferenceSchedule(name: "grille-ecole-periodes", lines: columnMajor(lines), expected: expected)
    }

    // MARK: 5. Transposed grid (days as rows, hours as columns)

    private static func transposedGrid() -> ReferenceSchedule {
        let rows = [0.25, 0.35, 0.45, 0.55, 0.65]
        var lines: [RecognizedLine] = []
        for (index, name) in ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi"].enumerated() {
            lines.append(Fx.line(name, 0.07, rows[index], 0.1))
        }
        let columns = [0.28, 0.44, 0.60, 0.76]
        for (index, label) in ["8h-9h", "9h-10h", "10h-11h", "11h-12h"].enumerated() {
            lines.append(Fx.line(label, columns[index], 0.12, 0.1))
        }
        lines.append(Fx.line("Algèbre", 0.28, rows[0] - 0.008, 0.1))
        lines.append(Fx.line("B12", 0.28, rows[0] + 0.008, 0.1))
        lines.append(Fx.line("Chimie", 0.60, rows[0], 0.1))
        lines.append(Fx.line("Latin", 0.44, rows[1], 0.1))
        lines.append(Fx.line("Sport", 0.44, rows[2], 0.1))
        // A class as wide as two hour columns.
        lines.append(Fx.line("Projet", 0.52, rows[3], 0.30))
        lines.append(Fx.line("Dessin", 0.76, rows[3], 0.1))
        lines.append(Fx.line("Piano", 0.28, rows[4], 0.1))
        let expected = [
            slot(1, "08:00", "09:00", "Algèbre", "B12"),
            slot(1, "10:00", "11:00", "Chimie"),
            slot(2, "09:00", "10:00", "Latin"),
            slot(3, "09:00", "10:00", "Sport"),
            slot(4, "09:00", "11:00", "Projet"),
            slot(4, "11:00", "12:00", "Dessin"),
            slot(5, "08:00", "09:00", "Piano")
        ]
        return ReferenceSchedule(name: "grille-transposee", lines: jumbled(lines, seed: 6), expected: expected)
    }

    // MARK: 6. Day by day list

    private static func dayByDayList() -> ReferenceSchedule {
        let lines = Fx.list([
            "Emploi du temps", "Lundi", "8h30 - 10h Biologie B-204", "10h15 - 11h45 Chimie", "Mardi", "13:00-14:30 Anglais",
            "Jeudi", "9h-10h30 Philosophie Salle 12", "Vendredi", "14h-16h Informatique A-110", "Page 1 sur 1"
        ])
        let expected = [
            slot(1, "08:30", "10:00", "Biologie", "B-204"),
            slot(1, "10:15", "11:45", "Chimie"),
            slot(2, "13:00", "14:30", "Anglais"),
            slot(4, "09:00", "10:30", "Philosophie", "Salle 12"),
            slot(5, "14:00", "16:00", "Informatique", "A-110")
        ]
        return ReferenceSchedule(name: "liste-jour-par-jour", lines: lines, expected: expected)
    }

    // MARK: 7. Table "Jour | Début | Fin | Matière | Salle"

    private static func table() -> ReferenceSchedule {
        let xs = [0.05, 0.22, 0.32, 0.45, 0.75]
        let rows: [[String?]] = [
            ["Jour", "Début", "Fin", "Matière", "Salle"],
            ["Lundi", "08:00", "10:00", "Algèbre", "B12"],
            ["Lundi", "10:15", "11:45", "Physique", "C30"],
            ["Mercredi", "13:00", "14:30", "Anglais", nil],
            ["Jeudi", "09:00", "10:30", "Chimie", "A10"],
            ["Vendredi", "14:00", "16:00", "Laboratoire", nil]
        ]
        var lines: [RecognizedLine] = []
        for (rowIndex, row) in rows.enumerated() {
            for (index, cell) in row.enumerated() {
                if let cell = cell { lines.append(Fx.line(cell, xs[index], 0.10 + 0.06 * Double(rowIndex), 0.09)) }
            }
        }
        let expected = [
            slot(1, "08:00", "10:00", "Algèbre", "B12"),
            slot(1, "10:15", "11:45", "Physique", "C30"),
            slot(3, "13:00", "14:30", "Anglais"),
            slot(4, "09:00", "10:30", "Chimie", "A10"),
            slot(5, "14:00", "16:00", "Laboratoire")
        ]
        return ReferenceSchedule(name: "tableau-jour-debut-fin", lines: jumbled(lines, seed: 8), expected: expected)
    }

    // MARK: 8. University export (CM / TD / TP)

    private static func universityList() -> ReferenceSchedule {
        let lines = Fx.list([
            "Lundi 09:00-11:00 CM Thermodynamique Amphi C", "Lundi 11:15-13:15 TD Mécanique Salle D102",
            "Mercredi 14:00-16:00 TP Électronique Salle 210", "Mercredi 16:15-18:15 TD Thermodynamique Salle D104",
            "Vendredi 08:00-10:00 CM Optique Amphi A"
        ])
        let expected = [
            slot(1, "09:00", "11:00", "CM Thermodynamique", "Amphi C"),
            slot(1, "11:15", "13:15", "TD Mécanique", "Salle D102"),
            slot(3, "14:00", "16:00", "TP Électronique", "Salle 210"),
            slot(3, "16:15", "18:15", "TD Thermodynamique", "Salle D104"),
            slot(5, "08:00", "10:00", "CM Optique", "Amphi A")
        ]
        return ReferenceSchedule(name: "universite-cm-td-tp", lines: jumbled(lines, seed: 9), expected: expected)
    }

    // MARK: 9. Japanese (月火水木金, periods 1限...)

    private static func japanesePeriods() -> ReferenceSchedule {
        let x = [0.26, 0.40, 0.54, 0.68, 0.82]
        var lines: [RecognizedLine] = []
        for (index, day) in "月火水木金".enumerated() { lines.append(Fx.line(String(day), x[index], 0.08, 0.05)) }
        for (index, label) in ["1限 9:00-10:30", "2限 10:40-12:10", "3限 13:00-14:30", "4限 14:40-16:10"].enumerated() {
            lines.append(Fx.line(label, 0.10, 0.2 + 0.12 * Double(index), 0.16))
        }
        func cell(_ column: Int, _ row: Int, _ title: String, _ room: String? = nil) {
            let y = 0.2 + 0.12 * Double(row)
            lines.append(Fx.line(title, x[column], y, 0.1))
            if let room = room { lines.append(Fx.line(room, x[column], y + 0.02, 0.1)) }
        }
        cell(0, 0, "数学", "A101")
        cell(1, 1, "英語")
        cell(2, 0, "物理")
        cell(3, 2, "化学", "B202")
        cell(4, 3, "歴史")
        let expected = [
            slot(1, "09:00", "10:30", "数学", "A101"),
            slot(2, "10:40", "12:10", "英語"),
            slot(3, "09:00", "10:30", "物理"),
            slot(4, "13:00", "14:30", "化学", "B202"),
            slot(5, "14:40", "16:10", "歴史")
        ]
        return ReferenceSchedule(name: "japonais-1限", lines: jumbled(lines, seed: 10), expected: expected)
    }

    // MARK: 10. German, 24 hours (Mo Di Mi Do Fr, Uhr)

    private static func german24Hours() -> ReferenceSchedule {
        let x = [0.2, 0.35, 0.5, 0.65, 0.8]
        var lines: [RecognizedLine] = []
        for (index, day) in ["Mo", "Di", "Mi", "Do", "Fr"].enumerated() { lines.append(Fx.line(day, x[index], 0.05, 0.07)) }
        lines += cellLines(["08:00 - 09:30", "Mathematik", "Raum 101"], cx: x[0], y: 0.20)
        lines += cellLines(["10:15 - 11:45", "Informatik"], cx: x[1], y: 0.20)
        lines += cellLines(["8-10 Uhr", "Physik", "Raum 12"], cx: x[2], y: 0.20)
        lines += cellLines(["14:00 - 15:30", "Deutsch"], cx: x[3], y: 0.20)
        lines += cellLines(["16:00 - 17:30", "Sport"], cx: x[3], y: 0.50)
        lines += cellLines(["13:15 - 14:45", "Geschichte", "Raum 204"], cx: x[4], y: 0.35)
        let expected = [
            slot(1, "08:00", "09:30", "Mathematik", "Raum 101"),
            slot(2, "10:15", "11:45", "Informatik"),
            slot(3, "08:00", "10:00", "Physik", "Raum 12"),
            slot(4, "14:00", "15:30", "Deutsch"),
            slot(4, "16:00", "17:30", "Sport"),
            slot(5, "13:15", "14:45", "Geschichte", "Raum 204")
        ]
        return ReferenceSchedule(name: "allemand-24h", lines: reversed(lines), expected: expected)
    }

    // MARK: 11. English, 12 hours (AM / PM)

    private static func english12Hours() -> ReferenceSchedule {
        let x = [0.2, 0.35, 0.5, 0.65, 0.8]
        var lines: [RecognizedLine] = []
        for (index, day) in ["Mon", "Tue", "Wed", "Thu", "Fri"].enumerated() { lines.append(Fx.line(day, x[index], 0.05, 0.07)) }
        lines += cellLines(["9:00 AM - 10:30 AM", "Psychology", "Room 5"], cx: x[0], y: 0.20)
        lines += cellLines(["1:00 PM - 2:30 PM", "Statistics"], cx: x[1], y: 0.20)
        lines += cellLines(["11:00 AM - 12:30 PM", "Economics", "Room 204"], cx: x[2], y: 0.20)
        lines += cellLines(["8:30 AM - 9:50 AM", "Sociology"], cx: x[3], y: 0.20)
        lines += cellLines(["2:00 PM - 3:30 PM", "Art History"], cx: x[3], y: 0.50)
        lines += cellLines(["6:00 PM - 8:30 PM", "Studio", "Room B-12"], cx: x[4], y: 0.35)
        let expected = [
            slot(1, "09:00", "10:30", "Psychology", "Room 5"),
            slot(2, "13:00", "14:30", "Statistics"),
            slot(3, "11:00", "12:30", "Economics", "Room 204"),
            slot(4, "08:30", "09:50", "Sociology"),
            slot(4, "14:00", "15:30", "Art History"),
            slot(5, "18:00", "20:30", "Studio", "Room B-12")
        ]
        return ReferenceSchedule(name: "anglais-12h", lines: rowMajor(lines), expected: expected)
    }

    // MARK: 12. Two rooms for one class

    private static func twoRooms() -> ReferenceSchedule {
        var lines = Fx.weekHeader(["Mon 21", "Tue 22", "Wed 23", "Thu 24", "Fri 25"], hourLabels: (8..<18).map { String(format: "%02d:00", $0) })
        lines += Fx.event(0, startMinute: 480, "Organic Chemistry", hours: "8:00 - 10:00", room: "B-204 / C-110")
        lines += Fx.event(1, startMinute: 600, "Linguistics", hours: "10:00 - 11:30", room: "A-101")
        lines += Fx.event(2, startMinute: 720, "Seminar", hours: "12:00 - 13:00", room: "A-101 / A-102")
        lines += Fx.event(3, startMinute: 840, "Physics", hours: "14:00 - 16:00", room: "D-210")
        lines += Fx.event(4, startMinute: 540, "Statistics", hours: "9:00 - 10:30")
        let expected = [
            slot(1, "08:00", "10:00", "Organic Chemistry", "B-204 / C-110"),
            slot(2, "10:00", "11:30", "Linguistics", "A-101"),
            slot(3, "12:00", "13:00", "Seminar", "A-101 / A-102"),
            slot(4, "14:00", "16:00", "Physics", "D-210"),
            slot(5, "09:00", "10:30", "Statistics")
        ]
        return ReferenceSchedule(name: "deux-salles", lines: lines, expected: expected)
    }

    // MARK: 13. Breaks and free slots (not classes)

    /// A school grid whose "Récréation" row and "Dîner" row cross all the columns. 7 classes.
    private static let breakLabels = ["8h00-9h00", "9h00-10h00", "10h00-10h20", "10h20-11h20", "11h20-12h20", "12h20-13h20", "13h20-14h20", "14h20-15h20"]

    static func breaksGridLines() -> [RecognizedLine] {
        let step = 0.07
        var lines = Fx.schoolHeader(["Lun", "Mar", "Mer", "Jeu", "Ven"]) + Fx.marginLabels(breakLabels, step: step)
        lines += Fx.cell(0, 0, "Algèbre", "B12", step: step) + Fx.cell(0, 1, "Anglais", "B12", step: step) + Fx.cell(1, 0, "Sport", step: step)
        lines += Fx.cell(2, 3, "Histoire", "A10", step: step) + Fx.cell(3, 4, "Chimie", "Lab 2", step: step)
        lines += Fx.cell(4, 6, "Biologie", "C30", step: step) + Fx.cell(0, 7, "Musique", step: step)
        lines += (0..<5).map { Fx.line("Récréation", Fx.schoolX[$0], Fx.rowY(2, step: step), 0.1) }
        lines += (0..<5).map { Fx.line("Dîner", Fx.schoolX[$0], Fx.rowY(5, step: step), 0.1) }
        return lines
    }

    static let breaksGridExpected: [ReferenceSlot] = [
        slot(1, "08:00", "09:00", "Algèbre", "B12"),
        slot(1, "09:00", "10:00", "Anglais", "B12"),
        slot(2, "08:00", "09:00", "Sport"),
        slot(3, "10:20", "11:20", "Histoire", "A10"),
        slot(4, "11:20", "12:20", "Chimie", "Lab 2"),
        slot(5, "13:20", "14:20", "Biologie", "C30"),
        slot(1, "14:20", "15:20", "Musique")
    ]

    private static func breaksSchoolGrid() -> ReferenceSchedule {
        ReferenceSchedule(name: "pauses-grille-ecole", lines: rowMajor(breaksGridLines()), expected: breaksGridExpected)
    }

    /// A French list with "Pause", "Dîner", "Récréation" and a free slot ("Libre"). 5 classes.
    private static func freeSlotsFrench() -> ReferenceSchedule {
        let lines = Fx.list([
            "Lundi", "8h00-9h00 Mathématiques", "9h00-10h00 Libre", "10h00-10h15 Pause", "10h15-11h15 Anglais",
            "11h15-12h30 Dîner", "13h30-14h30 Histoire", "Mardi", "8h00-10h00 Physique", "10h00-10h20 Récréation", "10h20-12h00 Chimie"
        ])
        let expected = [
            slot(1, "08:00", "09:00", "Mathématiques"),
            slot(1, "10:15", "11:15", "Anglais"),
            slot(1, "13:30", "14:30", "Histoire"),
            slot(2, "08:00", "10:00", "Physique"),
            slot(2, "10:20", "12:00", "Chimie")
        ]
        return ReferenceSchedule(name: "creneaux-libres-fr", lines: lines, expected: expected)
    }

    /// An English list with "Break", "Free period", "Lunch" and "Coffee break". 3 classes.
    private static func freeSlotsEnglish() -> ReferenceSchedule {
        let lines = Fx.list([
            "Monday", "9:00 AM - 10:00 AM Biology", "10:00 AM - 10:15 AM Break", "10:15 AM - 11:15 AM Free period",
            "12:00 PM - 1:00 PM Lunch", "1:00 PM - 2:00 PM Chemistry", "Tuesday", "8:30 AM - 10:00 AM Calculus",
            "10:00 AM - 10:30 AM Coffee break"
        ])
        let expected = [
            slot(1, "09:00", "10:00", "Biology"),
            slot(1, "13:00", "14:00", "Chemistry"),
            slot(2, "08:30", "10:00", "Calculus")
        ]
        return ReferenceSchedule(name: "creneaux-libres-en", lines: lines, expected: expected)
    }

    // MARK: 14. Weekend and evening classes

    private static func weekend() -> ReferenceSchedule {
        let x = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
        var lines: [RecognizedLine] = []
        for (index, day) in ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].enumerated() { lines.append(Fx.line(day, x[index], 0.06, 0.07)) }
        lines += cellLines(["18:00 - 20:00", "Piano"], cx: x[0], y: 0.20, width: 0.09)
        lines += cellLines(["19:00 - 21:00", "Chorale"], cx: x[2], y: 0.20, width: 0.09)
        lines += cellLines(["17:30 - 19:00", "Natation"], cx: x[4], y: 0.40, width: 0.09)
        lines += cellLines(["09:00 - 12:00", "Football"], cx: x[5], y: 0.20, width: 0.09)
        lines += cellLines(["10:00 - 11:30", "Yoga"], cx: x[6], y: 0.20, width: 0.09)
        let expected = [
            slot(1, "18:00", "20:00", "Piano"),
            slot(3, "19:00", "21:00", "Chorale"),
            slot(5, "17:30", "19:00", "Natation"),
            slot(6, "09:00", "12:00", "Football"),
            slot(7, "10:00", "11:30", "Yoga")
        ]
        return ReferenceSchedule(name: "week-end", lines: columnMajor(lines), expected: expected)
    }
}
