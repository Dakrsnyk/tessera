import Foundation
import CoreGraphics

/// A field of an `ImportedSlot` whose value may be wrong (see `ImportedSlot.uncertain`).
enum SlotField: String, Hashable {
    case day, start, end, title, room
}

/// A class found in a photo or a PDF of a timetable, before the person checks it.
struct ImportedSlot: Identifiable, Hashable {
    var id = UUID()
    /// ISO weekday like `ClassSlot.weekday` (Shared/Domains/Student.swift): 1 = Monday ... 7 = Sunday.
    var weekday: Int
    /// Minutes since midnight.
    var startMinute: Int
    var endMinute: Int
    var title: String
    var room: String? = nil
    var isSelected = true
    /// The reading of this class is doubtful (odd hours, overlap, noisy name, or a page read with little confidence):
    /// the check screen highlights it. Kept last so every memberwise call that does not know it still compiles.
    var needsCheck = false
    /// The fields whose value comes from an OCR correction ("8h3O" read as 8:30), from a guess (end from the usual length
    /// or from the next class, start from the centre of the text) or from an ambiguous reading. The check screen
    /// highlights exactly these fields. Kept after `needsCheck`, empty by default, so older memberwise calls still compile.
    var uncertain: Set<SlotField> = []
}

/// Looks at the colours of the image along a vertical line, to tell the blocks that hold a class (lighter)
/// from the empty cells of a timetable grid. Kept as a protocol so the parser stays pure and testable.
protocol BlockProbe {
    /// The vertical stretches (0...1, origin at the top) of the LIGHTER kind of cell along the line at `x`, between
    /// `fromY` and `toY` (the white blocks of Omnivox, a block lighter than a dark background); nil when the two kinds
    /// of cell cannot be told apart.
    func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]?
    /// The stretches of the DARKER kind of cell (a coloured block on a white page, a block darker than its background).
    /// Which of the two kinds holds the text is decided by the parser, from where the text is.
    func darkRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]?
    /// For timetables whose blocks are white rectangles drawn with a thick black outline on a white page (the colours of
    /// the cells tell nothing): the stretches between two consecutive thick horizontal lines. The empty stretches between
    /// blocks are included; the parser keeps the ones that hold the text of a class.
    func framedRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]?
}

extension BlockProbe {
    /// A probe that only knows the lighter kind (the default) gives nothing for the darker one, nor for outlines.
    func darkRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? { nil }
    func framedRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? { nil }
}

/// One line of text read from an image, with its place on the page.
struct RecognizedLine: Equatable {
    var text: String
    /// Normalised (0...1) with the origin at the top left.
    var box: CGRect
}

/// Turns the lines of text read from a timetable into classes. Pure logic (no Vision, no UIKit), so it is
/// tested without an image. Everything is approximate on purpose: the person checks the result before it
/// is saved. Many layouts are understood (see `Layouts/`): the grids with the days as columns (a school grid with
/// periods, a calendar week view, an Omnivox page), the transposed grid with the days as rows, and the lists
/// (day by day, tables, university exports). `ScheduleLayouts` tries them and keeps the best reading.
enum ScheduleParser {

    // MARK: Entry points

    /// The classes found on ONE page, without looking at the colours of the image.
    static func slots(from lines: [RecognizedLine]) -> [ImportedSlot] {
        slots(from: lines, probe: nil)
    }

    /// The classes found on ONE page. Never fails: unreadable input gives an empty list. The probe (when the
    /// image is known) tells where the blocks of a timetable start and stop; without it their height is guessed.
    static func slots(from lines: [RecognizedLine], probe: BlockProbe?) -> [ImportedSlot] {
        slots(from: lines, probe: probe, aspect: ScheduleLayouts.defaultAspect)
    }

    /// Same, with the height over the width of the page (the photo may be slightly tilted: the tilt is measured
    /// on the row of day names and the lines are straightened with this ratio).
    static func slots(from lines: [RecognizedLine], probe: BlockProbe?, aspect: Double) -> [ImportedSlot] {
        var cleaned: [RecognizedLine] = []
        for line in lines {
            if let kept = cleanedLine(line) { cleaned.append(kept) }
        }
        guard !cleaned.isEmpty else { return [] }
        return ScheduleLayouts.read(cleaned, probe: probe, aspect: aspect)
    }

    /// Removes identical classes (same day, hours and title), keeping a room when one copy has it, and sorts
    /// by day then hour.
    static func deduplicated(_ slots: [ImportedSlot]) -> [ImportedSlot] {
        var result: [ImportedSlot] = []
        var indexOfKey: [String: Int] = [:]
        for slot in slots {
            let key = "\(slot.weekday)|\(slot.startMinute)|\(slot.endMinute)|\(fold(slot.title))"
            if let existing = indexOfKey[key] {
                // The same class read twice: a field is in doubt only if both readings doubt it.
                result[existing].uncertain.formIntersection(slot.uncertain)
                if result[existing].room == nil, slot.room != nil {
                    result[existing].room = slot.room
                    if slot.uncertain.contains(.room) { result[existing].uncertain.insert(.room) }
                }
            } else {
                indexOfKey[key] = result.count
                result.append(slot)
            }
        }
        return result.sorted { a, b in
            if a.weekday != b.weekday { return a.weekday < b.weekday }
            if a.startMinute != b.startMinute { return a.startMinute < b.startMinute }
            return a.endMinute < b.endMinute
        }
    }

    // MARK: Intermediate types

    /// A class before the default length and the checks are applied.
    struct Draft {
        var weekday: Int
        var start: Int
        var end: Int?
        var title: String
        var room: String?
        /// The fields read with a doubt (see `ImportedSlot.uncertain`); `finalize` adds the ones it guesses itself.
        var uncertain: Set<SlotField> = []
        /// The class has the code of a course (Omnivox, boxed blocks): "Study hall" or "Dîner" is then a course, not a break.
        var coded = false
    }

    struct TimeFound {
        var start: Int
        var end: Int?
        var range: NSRange
        /// A look-alike letter was read as a digit ("8h3O" as 8:30) inside this time.
        var repaired = false
    }

    struct Placement {
        var start: Int
        var end: Int?
    }

    struct Analysis {
        var time: TimeFound?
        var title: String
        var room: String?
        /// The other ranges of the same text ("9h-12h / 13h-17h"): the class is repeated at each of them.
        var extraTimes: [TimeFound] = []
        /// The room holds a look-alike letter that was read as a digit ("B-2O4" as "B-204").
        var roomRepaired = false
    }

    struct DayCandidate {
        var day: Int
        var key: String
        var strong: Bool
        var x: CGFloat
        var y: CGFloat
        var bottom: CGFloat
        var line: Int
        /// The name was read with one wrong letter ("Mardl") and matched to a day by its resemblance.
        var fuzzy = false
        /// Other days the same misread name could be (used when the first one is already taken by a clear name).
        var alternates: [Int] = []
    }

    struct Grid {
        var headers: [DayCandidate]
        var lineIndexes: Set<Int>
        var bandBottom: CGFloat
    }

    struct HeaderToken {
        var token: String
        var from: Double
        var to: Double
    }

    // MARK: Cleaning

    static func cleanedLine(_ line: RecognizedLine) -> RecognizedLine? {
        let text = normalize(line.text)
        guard !text.isEmpty else { return nil }
        let b = line.box
        let values: [CGFloat] = [b.origin.x, b.origin.y, b.size.width, b.size.height]
        guard values.allSatisfy({ $0.isFinite }) else { return nil }
        let box = CGRect(x: b.origin.x, y: b.origin.y, width: max(b.size.width, 0), height: max(b.size.height, 0))
        return RecognizedLine(text: text, box: box)
    }

    /// Full-width forms to plain ones, dashes to "-", spaces collapsed.
    static func normalize(_ raw: String) -> String {
        var text = raw.folding(options: .widthInsensitive, locale: nil)
        for dash in ["\u{2010}", "\u{2011}", "\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}", "\u{2212}"] {
            text = text.replacingOccurrences(of: dash, with: "-")
        }
        let words = text.split(whereSeparator: { $0.isWhitespace })
        return words.joined(separator: " ")
    }

    /// Lowercase without accents.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
    }

    static func normalizedToken(_ raw: String) -> String {
        fold(raw).trimmingCharacters(in: CharacterSet(charactersIn: ".,:;()[]{}\"'"))
    }

    // MARK: Regular expressions

    static let markerPattern = #"(\s?(?:[hH](?![A-Za-z])|[:時])\s?(\d{2})?分?|\s?Uhr\b)"#
    static let meridiemPattern = #"(?:\s?([aApP])\.?[mM]\.?(?![A-Za-z]))"#

    /// "8h30-10h", "08:30 - 10:00", "8:30 AM to 10 PM", "8-10 Uhr". Groups: 1 hour, 2 marker, 3 minutes,
    /// 4 am/pm of the start, then 5 to 8 the same for the end.
    static let rangeRegex: NSRegularExpression? = {
        let unit1 = #"(\d{1,2})"# + markerPattern + "?" + meridiemPattern + "?"
        let unit2 = #"(\d{1,2})"# + markerPattern + "?" + meridiemPattern + "?"
        let separator = #"(?:\s*(?:[-~→〜～]|から)\s*|\s+(?:to|a|à|au|al|bis|até|ate|until|till)\s+)"#
        return try? NSRegularExpression(pattern: #"(?<![\d:.,/])(?<![A-Za-z])"# + unit1 + separator + unit2 + #"(?!\d)"#,
                                        options: [.caseInsensitive])
    }()

    /// "8.30-10.00" (the Italian way): two hours with two-digit minutes. Groups: 1 and 2 the start, 3 and 4 the end.
    static let dotRangeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\d:.,/])(?<![A-Za-z])(\d{1,2})\.(\d{2})\s?-\s?(\d{1,2})\.(\d{2})(?![\d.:])"#, options: [])

    /// "08:00 10:00": the start and the end in two columns of a table, side by side. Groups as above. (Written `[hH:]`,
    /// not `[:hH]`: ICU reads "[:" ... ":]" as a POSIX class when the pattern holds a ":]" further on.)
    static let pairRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\d:.,/])(?<![A-Za-z])(\d{1,2})\s?[hH:]\s?(\d{2})\s+(\d{1,2})\s?[hH:]\s?(\d{2})(?![:\d])"#, options: [])

    /// "8h 10h", "8h30 10h": the same with the "h" form, minutes optional. Groups: 1 hour, 2 minutes, 3 hour, 4 minutes.
    static let pairHourRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\d:.,/])(?<![A-Za-z])(\d{1,2})\s?[hH]\s?(\d{2})?\s+(\d{1,2})\s?[hH]\s?(\d{2})?(?![\d:A-Za-z])"#, options: [])

    /// A single time with a marker or am/pm: "8h30", "8 h", "08:30", "8:30 AM", "10 PM". Groups: 1 hour,
    /// 2 marker, 3 minutes, 4 am/pm after a marker, 5 am/pm alone.
    static let singleRegex: NSRegularExpression? = {
        let withMarker = markerPattern + meridiemPattern + "?"
        let pattern = #"(?<![\d:.,/])(?<![A-Za-z])(\d{1,2})(?:"# + withMarker + "|" + meridiemPattern + #")(?!\d)"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// A small word that introduces a time ("de 8h à 10h", "von 8 bis 10").
    static let leadWordRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:^|\s)(?:de|du|from|von|da|dalle|desde|das|ab|um|at|el|le)\s*$"#, options: [.caseInsensitive])

    /// "Salle B-204", "Local 3.12", "Room 5", "Amphi A". The word alone is not enough: a number or one capital letter must follow.
    static let prefixedRoomRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:^|[\s(@,;|-])((?:salle|local|room|rm|raum|aula|sala|stanza|labo|lab|amphi|amphitheatre|amphithéâtre|classe|class|pièce|piece)\.?\s*[:#]?\s*(?:[A-Za-z0-9.\-/]*\d[A-Za-z0-9.\-/]*|(?-i:[A-Z])(?![A-Za-z]))(?:\s\d{1,4}[A-Za-z]?)?)"#,
        options: [.caseInsensitive])

    /// "B-204", "B204", "AB 12" (one or two capitals then two to four digits).
    static let codeRoomRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:^|[\s(@,;|-])(((?-i:[A-Z]{1,2}))\s?-?\s?\d{2,4}[A-Za-z]?)(?![A-Za-z\d])"#, options: [.caseInsensitive])

    static let dottedRoomRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\d{1,2}\.\d{1,3}$"#, options: [])

    static let cjkDayRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[(（]\s*([月火水木金土日])\s*[)）]|([月火水木金土日])曜"#, options: [])

    /// Course types that look like a room code but are not.
    static let notRoomCodes: Set<String> = ["TD", "TP", "CM", "UE", "EC", "LV", "ED"]

    // MARK: Times

    static func group(_ match: NSTextCheckingResult, _ index: Int, in text: NSString) -> String? {
        guard index < match.numberOfRanges else { return nil }
        let range = match.range(at: index)
        guard range.location != NSNotFound, range.location + range.length <= text.length else { return nil }
        return text.substring(with: range)
    }

    static func isPM(_ letter: String?) -> Bool? {
        guard let first = letter?.lowercased().first else { return nil }
        if first == "p" { return true }
        if first == "a" { return false }
        return nil
    }

    /// Hour on 24 hours from a 12-hour reading; an hour that is not on 12 hours stays as it is.
    static func to24(_ hour: Int, _ pm: Bool?) -> Int {
        guard let pm = pm, (1...12).contains(hour) else { return hour }
        return hour % 12 + (pm ? 12 : 0)
    }

    // MARK: Look-alike letters in hours

    /// Letters that OCR reads in place of a digit.
    static let lookalikeDigits: [Character: Character] = ["O": "0", "o": "0", "I": "1", "l": "1", "|": "1", "S": "5", "B": "8"]

    /// "8h3O", "l0:30", "O9:00", "1O h": an hour (one or two characters), "h" or ":", then maybe two characters of minutes.
    /// The look-alikes of digits only count in a place that looks like an hour (the checks are in `repairedHours`).
    /// (A plain `[0-9OoIl|SB]` set: no "[:" inside, which ICU would read as a POSIX class.)
    static let repairMarkerRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])([0-9OoIl|SB]{1,2})(\s?[hH:])([0-9OoIl|SB]{2})?(?![A-Za-z0-9])"#, options: [])

    /// "1O PM", "l0 AM".
    static let repairMeridiemRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9:.,/])([0-9OoIl|SB]{1,2})\s?[aApP]\.?[mM]\.?(?![A-Za-z])"#, options: [])

    /// "O8-1O": two bare hours joined by a dash.
    static let repairBareRangeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9:.,/])([0-9OoIl|]{1,2})(\s*[-~]\s*)([0-9OoIl|]{1,2})(?![A-Za-z0-9])"#, options: [])

    /// A piece of an hour with its look-alikes turned into digits; nil when a character is neither. `S` and `B` count only
    /// next to a real digit of the same piece ("1S" is 15, a lone "S" is a letter).
    static func lookalikeValue(_ part: String) -> (digits: String, changed: Bool, anchored: Bool)? {
        var digits = ""
        var changed = false
        var anchored = false
        var weak = false
        for character in part {
            if character.isASCII && character.isNumber {
                digits.append(character)
                anchored = true
            } else if let digit = lookalikeDigits[character] {
                digits.append(digit)
                changed = true
                if character == "S" || character == "B" { weak = true }
            } else {
                return nil
            }
        }
        if weak, !anchored { return nil }
        return (digits, changed, anchored)
    }

    /// The text with the look-alikes turned back into digits, in the places that read as an hour (a digit near, then "h",
    /// ":" or a dash). One character is replaced by one character, so every position of the text stays valid; `changed`
    /// lists the positions (UTF-16) that were replaced. nil when nothing was repaired. Titles are not touched: "Bob",
    /// "Sb", "Oh" hold no real digit, and "B-2O4" has no "h" nor ":".
    static func repairedHours(_ text: String) -> (text: String, changed: Set<Int>)? {
        guard text.contains(where: { lookalikeDigits[$0] != nil }) else { return nil }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let result = NSMutableString(string: text)
        var changed = Set<Int>()
        func put(_ range: NSRange, _ digits: String) {
            guard range.length == (digits as NSString).length else { return }
            let new = digits as NSString
            for offset in 0..<range.length where ns.character(at: range.location + offset) != new.character(at: offset) {
                changed.insert(range.location + offset)
            }
            result.replaceCharacters(in: range, with: digits)
        }
        if let regex = repairMarkerRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                let hourRange = match.range(at: 1)
                let minuteRange = match.range(at: 3)
                guard let hour = lookalikeValue(ns.substring(with: hourRange)), let hourNumber = Int(hour.digits) else { continue }
                var minute: (digits: String, changed: Bool, anchored: Bool)? = nil
                if minuteRange.location != NSNotFound {
                    guard let found = lookalikeValue(ns.substring(with: minuteRange)), let minuteNumber = Int(found.digits),
                          minuteNumber < 60 else { continue }
                    minute = found
                }
                guard hourNumber <= 24, hour.changed || (minute?.changed ?? false) else { continue }
                // Some real digit must anchor it; an hour made only of look-alikes is one letter ("l:45") with minutes.
                guard hour.anchored || (minute?.anchored ?? false) else { continue }
                if !hour.anchored { guard hourRange.length == 1, minute != nil else { continue } }
                put(hourRange, hour.digits)
                if let found = minute { put(minuteRange, found.digits) }
            }
        }
        if let regex = repairMeridiemRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                let hourRange = match.range(at: 1)
                guard let hour = lookalikeValue(ns.substring(with: hourRange)), hour.changed, hour.anchored,
                      let number = Int(hour.digits), number <= 24 else { continue }
                put(hourRange, hour.digits)
            }
        }
        if let regex = repairBareRangeRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                let leftRange = match.range(at: 1)
                let rightRange = match.range(at: 3)
                guard let left = lookalikeValue(ns.substring(with: leftRange)), let right = lookalikeValue(ns.substring(with: rightRange)),
                      left.anchored, right.anchored, left.changed || right.changed,
                      let leftNumber = Int(left.digits), let rightNumber = Int(right.digits),
                      leftNumber <= 24, rightNumber <= 24 else { continue }
                put(leftRange, left.digits)
                put(rightRange, right.digits)
            }
        }
        guard !changed.isEmpty else { return nil }
        return (result as String, changed)
    }

    /// The first time or range of times in the text. A look-alike letter in an hour ("8h3O-1Oh") is read as the digit it
    /// stands for, and the time is then marked `repaired`.
    static func findTime(in text: String) -> TimeFound? {
        guard let fixed = repairedHours(text) else { return findTimeExact(in: text) }
        if var found = findTimeExact(in: fixed.text) {
            let first = found.range.location
            let end = first + found.range.length
            found.repaired = fixed.changed.contains { $0 >= first && $0 < end }
            return found
        }
        return findTimeExact(in: text)
    }

    static func findTimeExact(in text: String) -> TimeFound? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let regex = rangeRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                guard let h1 = Int(group(match, 1, in: ns) ?? ""), let h2 = Int(group(match, 5, in: ns) ?? "") else { continue }
                let m1 = Int(group(match, 3, in: ns) ?? "0") ?? 0
                let m2 = Int(group(match, 7, in: ns) ?? "0") ?? 0
                let before = ns.substring(to: match.range.location)
                let atStart = before.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-:;|,.([#*"))).isEmpty
                if let resolved = resolveRange(h1: h1, m1: m1, mark1: group(match, 2, in: ns) != nil, pm1: isPM(group(match, 4, in: ns)),
                                               h2: h2, m2: m2, mark2: group(match, 6, in: ns) != nil, pm2: isPM(group(match, 8, in: ns)),
                                               atStart: atStart) {
                    return TimeFound(start: resolved.start, end: resolved.end, range: match.range)
                }
            }
        }
        if let regex = dotRangeRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                guard let h1 = Int(group(match, 1, in: ns) ?? ""), let m1 = Int(group(match, 2, in: ns) ?? ""),
                      let h2 = Int(group(match, 3, in: ns) ?? ""), let m2 = Int(group(match, 4, in: ns) ?? "") else { continue }
                // "8.30-10.00" only: a morning or afternoon hour, minutes that exist, a lesson of at most 6 hours.
                guard (6...22).contains(h1), h2 <= 23, m1 < 60, m2 < 60 else { continue }
                let start = h1 * 60 + m1
                let end = h2 * 60 + m2
                if end > start, end - start <= 360 { return TimeFound(start: start, end: end, range: match.range) }
            }
        }
        for pairs in [pairRegex, pairHourRegex] {
            guard let regex = pairs else { continue }
            for match in regex.matches(in: text, options: [], range: full) {
                guard let h1 = Int(group(match, 1, in: ns) ?? ""), let h2 = Int(group(match, 3, in: ns) ?? "") else { continue }
                let m1 = Int(group(match, 2, in: ns) ?? "0") ?? 0
                let m2 = Int(group(match, 4, in: ns) ?? "0") ?? 0
                guard h1 < 24, h2 < 24, m1 < 60, m2 < 60 else { continue }
                let start = h1 * 60 + m1
                let end = h2 * 60 + m2
                if end > start, end - start <= 720, start >= 300 { return TimeFound(start: start, end: end, range: match.range) }
            }
        }
        if let regex = singleRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                guard let hour = Int(group(match, 1, in: ns) ?? "") else { continue }
                let minute = Int(group(match, 3, in: ns) ?? "0") ?? 0
                let pm = isPM(group(match, 4, in: ns)) ?? isPM(group(match, 5, in: ns))
                if let start = resolveSingle(hour: hour, minute: minute, pm: pm) {
                    return TimeFound(start: start, end: nil, range: match.range)
                }
            }
        }
        return nil
    }

    static func resolveSingle(hour: Int, minute: Int, pm: Bool?) -> Int? {
        guard (0...23).contains(hour), minute < 60 else { return nil }
        var hour24 = to24(hour, pm)
        // Nobody studies at 3 in the morning: "3h" or "3:30" means the afternoon.
        if pm == nil, (1...5).contains(hour24) { hour24 += 12 }
        return hour24 * 60 + minute
    }

    static func resolveRange(h1: Int, m1: Int, mark1: Bool, pm1: Bool?,
                             h2: Int, m2: Int, mark2: Bool, pm2: Bool?, atStart: Bool) -> (start: Int, end: Int)? {
        guard (0...24).contains(h1), (0...24).contains(h2), m1 < 60, m2 < 60 else { return nil }
        let anyMarker = mark1 || mark2 || pm1 != nil || pm2 != nil
        if !anyMarker {
            // "8-10" alone is too vague to be an hour range anywhere but at the start of a line.
            guard atStart, (6...22).contains(h1), h2 > h1, h2 <= 23, h2 - h1 <= 6 else { return nil }
        }
        var start = 0
        var end = 0
        if pm1 != nil, pm2 != nil {
            start = to24(h1, pm1) * 60 + m1
            end = to24(h2, pm2) * 60 + m2
        } else if let p2 = pm2 {
            // "8:30-10 PM": the start shares the end's period unless that puts it after the end.
            end = to24(h2, p2) * 60 + m2
            start = to24(h1, p2) * 60 + m1
            if start >= end { start = to24(h1, !p2) * 60 + m1 }
        } else if let p1 = pm1 {
            start = to24(h1, p1) * 60 + m1
            end = to24(h2, p1) * 60 + m2
            if end <= start { end = to24(h2, !p1) * 60 + m2 }
        } else {
            start = h1 * 60 + m1
            end = h2 * 60 + m2
            if (1...5).contains(h1) {
                start += 720
                if (1...11).contains(h2) { end += 720 }
            }
            if end <= start, end + 720 > start { end += 720 }
        }
        guard start >= 0, end <= 1440, end > start, end - start <= 720 else { return nil }
        return (start, end)
    }

    /// The text without the time (and the small word that introduced it).
    static func removing(_ found: NSRange, from text: String) -> String {
        let ns = text as NSString
        guard found.location != NSNotFound, found.location + found.length <= ns.length else { return text }
        var location = found.location
        let before = ns.substring(to: location)
        let beforeLength = (before as NSString).length
        if let lead = leadWordRegex?.firstMatch(in: before, options: [], range: NSRange(location: 0, length: beforeLength)) {
            location = lead.range.location
        }
        let removal = NSRange(location: location, length: found.location + found.length - location)
        return ns.replacingCharacters(in: removal, with: " ")
    }

    /// The time when the text holds nothing else (a row label of a grid: "8h", "8h-9h", "8:00 AM") or only the name of
    /// the period it belongs to ("Période 1 8:15-9:05", "1re heure 8h-9h", "3. Stunde 9:55-10:40", "1限 9:00-10:30").
    static func timeOnly(_ text: String) -> TimeFound? {
        guard let found = findTime(in: text) else { return nil }
        let rest = removing(found.range, from: text)
        if rest.contains(where: { $0.isLetter }) {
            let list = words(of: rest)
            guard !list.isEmpty, list.allSatisfy({ isLabelToken($0) }) else { return nil }
        }
        return found
    }

    /// Words that name a period in the margin of a grid (together with its number).
    static let labelWords: Set<String> = [
        "periode", "period", "per", "p", "heure", "heures", "hour", "hours", "stunde", "std", "lesson", "cours", "class",
        "clase", "hora", "ora", "lecon", "limit", "tranche", "creneau", "slot", "h"
    ]

    static let labelTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(?:\d{1,2}(?:re|er|e|eme|ere|st|nd|rd|th|a|o|ª|º|°)|[a-z]{1,2}\d{1,2})$"#, options: [])

    /// "1", "p1", "1re", "heure", "1限": a piece of a period label.
    static func isLabelToken(_ token: String) -> Bool {
        if !token.isEmpty, token.allSatisfy({ $0.isNumber }) { return true }
        if labelWords.contains(token) { return true }
        if token.contains("限") || token.contains("時間目") || token.contains("第") { return true }
        guard let regex = labelTokenRegex else { return false }
        return regex.firstMatch(in: token, options: [], range: NSRange(location: 0, length: (token as NSString).length)) != nil
    }

    // MARK: Text of a class

    static let noisePhrases: [String] = [
        "emploi du temps", "mis a jour", "horaire", "horaires", "schedule", "timetable", "stundenplan", "horario", "orario",
        "semestre", "semester", "trimestre", "page", "pagina", "seite", "genere", "updated", "generated", "imprime",
        "printed", "version", "copyright", "semaine", "week", "woche", "semana", "settimana", "calendar", "calendrier",
        "kalender", "calendario"
    ]

    static let breakWords: Set<String> = [
        "pause", "dejeuner", "diner", "lunch", "break", "recreation", "recre", "repas", "midi", "almuerzo", "recreo",
        "descanso", "comida", "mittagspause", "mittag", "mittagessen", "pranzo", "intervallo", "pausa", "almoco",
        "intervalo", "cafe", "coffee", "昼休み", "休憩", "昼食", "recess", "snack", "collation", "gouter", "ricreazione",
        "merienda", "pausenzeit"
    ]

    /// Words of a free period or an empty cell ("Libre", "Free", "Aucun", "Annulé"): the cell holds no class.
    static let freeWords: Set<String> = [
        "libre", "libres", "free", "frei", "libero", "libera", "livre", "vacant", "vacante", "vide", "empty", "aucun", "aucune",
        "none", "nada", "kein", "keine", "nessuno", "tbd", "tba", "rien", "trou", "spare", "gap", "blank", "annule", "annulee",
        "cancelled", "canceled", "cancelado", "abgesagt", "annullato", "空き", "空"
    ]

    /// Small words that may stand next to a free word ("Période libre", "Free time", "Temps libre", "Heure libre").
    static let freeFillers: Set<String> = [
        "periode", "period", "temps", "time", "heure", "hour", "creneau", "slot", "block", "bloc", "cours", "class", "sans", "pas",
        "de", "du", "d", "en", "stunde", "hora", "ora", "ore", "tiempo", "tempo", "zeit", "periodo", "no", "sin", "ohne", "nessun"
    ]

    /// Whole titles that name a study period or a hole ("Study hall"); a course code makes them a course again.
    static let studyPhrases: Set<String> = [
        "study hall", "salle d etude", "etude", "etude libre", "etude surveillee", "permanence", "free study", "self study",
        "studienzeit", "no class", "no classes", "pas de cours", "aucun cours", "kein unterricht", "sin clase", "nessuna lezione"
    ]

    /// Texts that stand for nothing at all.
    static let emptyMarks: Set<String> = ["n/a", "n.a.", "n.d.", "...", "???", "--", "---", "tbc"]

    static let teacherWords: Set<String> = [
        "prof", "professeur", "professeure", "professor", "professora", "dr", "mr", "mme", "mrs", "ms", "mlle", "herr",
        "frau", "sr", "sra", "doc", "docente", "docteur", "teacher", "instructor", "enseignant", "lecturer"
    ]

    static func words(of text: String) -> [String] {
        fold(text).split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map { String($0) }
    }

    static func isNoise(_ text: String) -> Bool {
        if text.contains("時間割") || text.contains("©") || text.lowercased().contains("http") { return true }
        let padded = " " + words(of: text).joined(separator: " ") + " "
        for phrase in noisePhrases where padded.contains(" \(phrase) ") { return true }
        return false
    }

    static func isBreak(_ title: String) -> Bool {
        let list = words(of: title)
        guard let first = list.first, list.count <= 3 else { return false }
        return breakWords.contains(first)
    }

    /// A free period, a hole, an empty cell ("Libre", "Période libre", "Free", "N/A", "Study hall").
    static func isFreePeriod(_ title: String) -> Bool {
        let list = words(of: title)
        if list.isEmpty { return true }
        let joined = list.joined(separator: " ")
        if studyPhrases.contains(joined) || emptyMarks.contains(fold(title).trimmingCharacters(in: .whitespaces)) { return true }
        guard list.count <= 3, list.contains(where: { freeWords.contains($0) }) else { return false }
        return list.allSatisfy { freeWords.contains($0) || freeFillers.contains($0) }
    }

    /// What a cell is that holds no class: a break, a free period, an empty mark. A class that has the code of a course
    /// is a course whatever its name ("Dîner", "Study hall" with a code), except an empty mark.
    static func isNonCourse(_ title: String, coded: Bool) -> Bool {
        if coded {
            let list = words(of: title)
            return list.isEmpty || emptyMarks.contains(fold(title).trimmingCharacters(in: .whitespaces))
        }
        return isBreak(title) || isFreePeriod(title)
    }

    /// A name that is mostly digits and symbols is not read: no class is made of it.
    static func isUnreadableTitle(_ title: String) -> Bool {
        let characters = title.filter { !$0.isWhitespace }
        guard !characters.isEmpty else { return true }
        return characters.filter { $0.isLetter }.count * 2 < characters.count
    }

    static func isTeacher(_ title: String) -> Bool {
        if title.contains("先生") { return true }
        guard let first = words(of: title).first else { return false }
        return teacherWords.contains(first)
    }

    /// Another room right after a first one: "/ C-110", "; H3040", "& 2.711".
    static let moreRoomRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\s*[/;&]\s*([A-Z]{1,2}\s?-?\s?\d{2,4}[A-Za-z]?(?![A-Za-z\d])|\d{1,2}\.\d{1,3}(?![A-Za-z\d]))"#, options: [])

    /// The rooms that follow a first one (up to three), and where the last one ends in the text.
    static func moreRooms(after first: NSRange, in ns: NSString) -> (rooms: [String], end: Int) {
        var end = first.location + first.length
        var rooms: [String] = []
        guard let regex = moreRoomRegex else { return (rooms, end) }
        while rooms.count < 3, end < ns.length {
            let rest = ns.substring(from: end)
            guard let match = regex.firstMatch(in: rest, options: [], range: NSRange(location: 0, length: (rest as NSString).length)),
                  let room = group(match, 1, in: rest as NSString) else { break }
            rooms.append(room.trimmingCharacters(in: .whitespaces))
            end += match.range.location + match.range.length
        }
        return (rooms, end)
    }

    /// Splits the room out of a text: (text without the room, room).
    static func extractRoom(from text: String) -> (text: String, room: String?) {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let regex = prefixedRoomRegex,
           let match = regex.firstMatch(in: text, options: [], range: full),
           let room = group(match, 1, in: ns) {
            let cleanRoom = room.trimmingCharacters(in: .whitespaces)
            if !cleanRoom.isEmpty {
                let more = moreRooms(after: match.range(at: 1), in: ns)
                let span = NSRange(location: match.range(at: 1).location, length: more.end - match.range(at: 1).location)
                return (ns.replacingCharacters(in: span, with: " "), ([cleanRoom] + more.rooms).joined(separator: " / "))
            }
        }
        if let regex = codeRoomRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                guard let room = group(match, 1, in: ns), let letters = group(match, 2, in: ns) else { continue }
                if notRoomCodes.contains(letters.uppercased()) { continue }
                // "B-204 / C-110": a class that moves, or two rooms in one cell, keeps both.
                let more = moreRooms(after: match.range(at: 1), in: ns)
                let span = NSRange(location: match.range(at: 1).location, length: more.end - match.range(at: 1).location)
                let rooms = [room.trimmingCharacters(in: .whitespaces)] + more.rooms
                return (ns.replacingCharacters(in: span, with: " "), rooms.joined(separator: " / "))
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let regex = dottedRoomRegex,
           regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: (trimmed as NSString).length)) != nil {
            return ("", trimmed)
        }
        return (text, nil)
    }

    /// A title cleaned of separators and stray brackets; empty when what is left is not a name.
    static func cleanTitle(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: #"\(\s*\)|\[\s*\]"#, with: " ", options: .regularExpression)
        let edge = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-:;|,.·•*/@#_>→{}"))
        text = text.trimmingCharacters(in: edge)
        if text.hasSuffix(")"), !text.contains("(") { text.removeLast() }
        if text.hasPrefix("("), !text.contains(")") { text.removeFirst() }
        if text.hasSuffix("]"), !text.contains("[") { text.removeLast() }
        if text.hasPrefix("["), !text.contains("]") { text.removeFirst() }
        text = text.trimmingCharacters(in: edge)
        text = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard text.filter({ $0.isLetter }).count >= 2 else { return "" }
        return String(text.prefix(60))
    }

    /// All the ranges of a text ("9h-12h / 13h-17h" gives two) and the text without them. A start alone is only
    /// taken when the text holds no range.
    static func findTimes(in text: String) -> (times: [TimeFound], rest: String) {
        guard let first = findTime(in: text) else { return ([], text) }
        var times = [first]
        var rest = removing(first.range, from: text)
        if first.end != nil {
            while let next = findTime(in: rest), next.end != nil {
                times.append(next)
                rest = removing(next.range, from: rest)
            }
        }
        return (times, rest)
    }

    /// "Dupont J.", "Durand M. A.", "J. Dupont": a person written without a title (the initial ends with a full stop,
    /// so "Groupe A" is not one).
    static let personTailRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\p{L}[\p{L}'’-]+(?:\s\p{L}\.){1,2}$"#, options: [])
    static let personHeadRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\p{L}\.\s?\p{L}[\p{L}'’-]+$"#, options: [])

    static func isPersonName(_ part: String) -> Bool {
        guard let first = part.first, first.isUppercase else { return false }
        let range = NSRange(location: 0, length: (part as NSString).length)
        if let regex = personTailRegex, regex.firstMatch(in: part, options: [], range: range) != nil { return true }
        if let regex = personHeadRegex, regex.firstMatch(in: part, options: [], range: range) != nil { return true }
        return false
    }

    /// "CM Analyse - Dupont J." keeps "CM Analyse": the pieces cut by " - ", " / " or " | " that name a teacher are dropped
    /// (a title word like "Prof." or a bare name after the first piece). A text of a single piece is left alone.
    static func dropTeacherParts(_ raw: String) -> String {
        let title = raw.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        let parts = title.components(separatedBy: " - ").flatMap { $0.components(separatedBy: " / ") }
            .flatMap { $0.components(separatedBy: " | ") }
        guard parts.count >= 2 else { return title }
        var kept: [String] = []
        for (index, part) in parts.enumerated() {
            if isTeacher(part) || (index > 0 && isPersonName(part)) { continue }
            kept.append(part)
        }
        return kept.isEmpty ? title : kept.joined(separator: " ")
    }

    /// Time, room and title of a piece of text. Noise (page numbers, "generated on ...") gives nothing.
    static func analyze(_ text: String) -> Analysis {
        let split = findTimes(in: text)
        let found = split.times.first
        if isNoise(split.rest) { return Analysis(time: nil, title: "", room: nil) }
        var placed = extractRoom(from: split.rest)
        var roomRepaired = false
        // "B-2O4" holds no room for the patterns above: read it with the O as a zero, and say the room is in doubt.
        let fixed = repairedRoomWords(in: split.rest)
        if !fixed.tokens.isEmpty {
            let attempt = extractRoom(from: fixed.text)
            if let room = attempt.room, fixed.tokens.contains(where: { room.contains($0) }) {
                placed = attempt
                roomRepaired = true
            }
        }
        var title = cleanTitle(dropTeacherParts(placed.text))
        if isTeacher(title) { title = "" }
        return Analysis(time: found, title: title, room: placed.room, extraTimes: Array(split.times.dropFirst()),
                        roomRepaired: roomRepaired)
    }

    // MARK: Look-alike letters in rooms

    /// A code of a room: one or two capitals, maybe a dash, then two to four characters that are digits or look-alikes.
    static let roomLookalikeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])([A-Z]{1,2}-?)([0-9OoIl|]{2,4})(?![A-Za-z0-9])"#, options: [])

    /// "B-2O4" -> "B-204", "H3O46" -> "H3046": a letter that stands for a zero or a one INSIDE the number of a room (it
    /// starts with a digit, or follows a dash, and ends with a digit). Nothing else of the text changes (a word such as
    /// "BIO" or "Local" holds no real digit). `tokens` are the repaired codes, to find them again in a room.
    static func repairedRoomWords(in text: String) -> (text: String, tokens: [String]) {
        guard text.contains(where: { lookalikeDigits[$0] != nil }), let regex = roomLookalikeRegex else { return (text, []) }
        let ns = text as NSString
        let result = NSMutableString(string: text)
        var tokens: [String] = []
        func isDigit(_ character: Character) -> Bool { character.isASCII && character.isNumber }
        for match in regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            let prefix = ns.substring(with: match.range(at: 1))
            let partRange = match.range(at: 2)
            let part = ns.substring(with: partRange)
            guard let first = part.first, let last = part.last, isDigit(last), isDigit(first) || prefix.hasSuffix("-") else { continue }
            var digits = ""
            for character in part {
                if isDigit(character) {
                    digits.append(character)
                } else if let digit = lookalikeDigits[character] {
                    digits.append(digit)
                } else {
                    digits = ""
                    break
                }
            }
            guard digits.count == part.count, digits != part else { continue }
            result.replaceCharacters(in: partRange, with: digits)
            tokens.append(prefix + digits)
        }
        return (result as String, tokens)
    }

    // MARK: Day names

    static let strongDays: [String: Int] = {
        let table: [(Int, [String])] = [
            (1, ["lun", "lundi", "lunedi", "lunes", "montag", "mon", "monday", "segunda", "seg", "月曜日", "月曜", "星期一", "周一", "週一", "礼拜一", "월요일"]),
            (2, ["mar", "mardi", "martedi", "martes", "dienstag", "tue", "tues", "tuesday", "terca", "ter", "火曜日", "火曜", "星期二", "周二", "週二", "礼拜二", "화요일"]),
            (3, ["mer", "mercredi", "mercoledi", "miercoles", "mie", "mittwoch", "wed", "weds", "wednesday", "quarta", "qua", "水曜日", "水曜", "星期三", "周三", "週三", "礼拜三", "수요일"]),
            (4, ["jeu", "jeudi", "giovedi", "jueves", "jue", "donnerstag", "thu", "thur", "thurs", "thursday", "gio", "quinta", "qui", "木曜日", "木曜", "星期四", "周四", "週四", "礼拜四", "목요일"]),
            (5, ["ven", "vendredi", "venerdi", "viernes", "vie", "freitag", "fri", "friday", "sexta", "sex", "金曜日", "金曜", "星期五", "周五", "週五", "礼拜五", "금요일"]),
            (6, ["sam", "samedi", "sabato", "sabado", "sab", "samstag", "sonnabend", "sat", "saturday", "土曜日", "土曜", "星期六", "周六", "週六", "礼拜六", "토요일"]),
            (7, ["dim", "dimanche", "domenica", "domingo", "dom", "sonntag", "sun", "sunday", "日曜日", "日曜", "星期日", "星期天", "周日", "周天", "週日", "礼拜日", "일요일"])
        ]
        var map: [String: Int] = [:]
        for (day, names) in table {
            for name in names where map[name] == nil { map[name] = day }
        }
        return map
    }()

    /// Two-letter forms and single kanji: only trusted in a header row with several days.
    static let weakDays: [String: Int] = {
        let table: [(Int, [String])] = [
            (1, ["mo", "lu", "月", "월"]),
            (2, ["di", "ma", "tu", "火", "화"]),
            (3, ["mi", "me", "we", "水", "수"]),
            (4, ["th", "je", "gi", "ju", "木", "목"]),
            (5, ["fr", "ve", "vi", "金", "금"]),
            (6, ["sa", "土", "토"]),
            (7, ["so", "su", "日", "일"])
        ]
        var map: [String: Int] = [:]
        for (day, names) in table {
            for name in names where map[name] == nil { map[name] = day }
        }
        return map
    }()

    static let cjkDayCharacters: String = "月火水木金土日월화수목금토일"

    static let germanOnlyKeys: Set<String> = ["di", "fr", "so"]

    static let monthPrefixes: Set<String> = [
        "jan", "ene", "gen", "feb", "fev", "mar", "apr", "avr", "abr", "may", "mai", "mag", "jun", "jui", "giu", "jul",
        "lug", "aug", "aou", "ago", "sep", "set", "oct", "out", "ott", "okt", "nov", "dec", "dez", "dic"
    ]

    static let dateWords: Set<String> = [
        "de", "of", "the", "le", "la", "del", "el", "der", "den", "am", "um", "st", "nd", "rd", "th", "er", "dia", "da",
        "月", "日", "年"
    ]

    static let headerSeparators: Set<Character> = Set(" \t/.,:;()[]{}-_|0123456789・、")

    /// Words of a header row (digits and punctuation are separators) with their place in the line (0...1).
    static func headerTokens(_ text: String) -> [HeaderToken] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }
        let total = Double(characters.count)
        var result: [HeaderToken] = []
        var start: Int? = nil
        for index in 0...characters.count {
            let isSeparator = index == characters.count || headerSeparators.contains(characters[index])
            if isSeparator {
                if let begin = start {
                    result.append(HeaderToken(token: String(characters[begin..<index]), from: Double(begin) / total, to: Double(index) / total))
                    start = nil
                }
            } else if start == nil {
                start = index
            }
        }
        return result
    }

    static func strongDay(_ word: String) -> Int? {
        strongDays[dayKey(word)]
    }

    /// The day a word names: exactly ("Mardi"), or by resemblance when it holds one wrong letter ("Mardl"), and then `fuzzy`.
    static func dayMatch(_ word: String) -> (day: Int, fuzzy: Bool)? {
        if let day = strongDay(word) { return (day, false) }
        if let near = fuzzyDay(word) { return (near.day, true) }
        return nil
    }

    // MARK: Day names read with a wrong letter

    /// Pairs of characters (sorted) that OCR swaps often, and ones it swaps sometimes.
    static let strongConfusions: Set<String> = ["ao", "il", "1i", "1l", "0o", "ce", "uv", "ij"]
    static let weakConfusions: Set<String> = ["hn", "nr", "mn", "ae", "bh", "co", "gq", "5s", "8b", "vy", "nu", "ft"]

    /// 1 when the two characters are swapped often, 2 sometimes, nil when never.
    static func confusionTier(_ a: Character, _ b: Character) -> Int? {
        let pair = String([min(a, b), max(a, b)])
        if strongConfusions.contains(pair) { return 1 }
        if weakConfusions.contains(pair) { return 2 }
        return nil
    }

    /// The day names made of plain letters, as arrays of characters.
    static let asciiDayKeys: [(key: [Character], day: Int)] = {
        var keys: [(key: [Character], day: Int)] = []
        for (name, day) in strongDays {
            let letters = Array(name)
            if letters.allSatisfy({ $0.isASCII && $0.isLetter }) { keys.append((key: letters, day: day)) }
        }
        return keys
    }()

    /// Whether `short` is `long` without one letter.
    static func isOneLetterShorter(_ short: [Character], than long: [Character]) -> Bool {
        guard long.count == short.count + 1 else { return false }
        var index = 0
        while index < short.count, short[index] == long[index] { index += 1 }
        return Array(short[index...]) == Array(long[(index + 1)...])
    }

    /// A day name read with ONE wrong character: "Lur" (Lun), "Mardl", "Mercredl", "Jeud1", "Vendred1", "Man" (Mon). Only
    /// where the wrong character is one OCR confuses with the right one, or a name cut short ("Vendred"); never for two
    /// letters; nil when two different days are as near. `alternates` are the other days a three-letter name could be.
    static func fuzzyDay(_ raw: String) -> (day: Int, alternates: [Int])? {
        let token = Array(normalizedToken(raw))
        guard token.count >= 3, token.count <= 10, token.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
              token.contains(where: { $0.isLetter }) else { return nil }
        let word = String(token)
        guard strongDays[word] == nil, weakDays[word] == nil, !(token.count == 3 && monthPrefixes.contains(word)) else { return nil }
        var strong = Set<Int>()
        var pool = Set<Int>()
        for entry in asciiDayKeys {
            let key = entry.key
            if key.count == token.count {
                var differences: [Int] = []
                for index in 0..<key.count where key[index] != token[index] {
                    differences.append(index)
                    if differences.count > 1 { break }
                }
                guard differences.count == 1, let tier = confusionTier(token[differences[0]], key[differences[0]]) else { continue }
                if key.count == 3, tier == 1 { strong.insert(entry.day) } else { pool.insert(entry.day) }
            } else if key.count >= 5, key.count == token.count + 1 {
                // A name cut short ("Vendred") or with one letter lost inside a long one ("Vendedi").
                if token.count >= 4, Array(key.prefix(token.count)) == token { pool.insert(entry.day) }
                else if token.count >= 6, isOneLetterShorter(token, than: key) { pool.insert(entry.day) }
            }
        }
        if !strong.isEmpty {
            guard strong.count == 1, let day = strong.first else { return nil }
            return (day, Array(pool.subtracting([day])).sorted())
        }
        guard pool.count == 1, let day = pool.first else { return nil }
        return (day, [])
    }

    /// Whether what follows a day name is only a date ("12 octobre", "Oct 12th") and not a course.
    static func isDateish(_ text: String) -> Bool {
        let tokens = headerTokens(text).map { normalizedToken($0.token) }
        return tokens.allSatisfy { monthPrefixes.contains(String($0.prefix(3))) || dateWords.contains($0) }
    }

    /// The day written in Japanese inside a line: "(月)" or "月曜".
    static func embeddedCJKDay(in text: String) -> Int? {
        guard let regex = cjkDayRegex else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        let character = group(match, 1, in: ns) ?? group(match, 2, in: ns) ?? ""
        return weakDays[character]
    }

    /// Days named at the start of a text (one, a list "Lun/Mer", a range "Lun-Ven" or "Lun à Ven") and the rest.
    static func leadingDays(in text: String) -> (days: [Int], rest: String, fuzzy: Bool)? {
        let source = text.replacingOccurrences(of: "-feira", with: "", options: .caseInsensitive)
        let tokens = source.split(separator: " ").map { String($0) }
        var days: [Int] = []
        var consumed = 0
        var pendingRange = false
        var anyFuzzy = false
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if let glued = gluedDays(token) {
                let list = glued.days
                if glued.fuzzy { anyFuzzy = true }
                if pendingRange, let last = days.last, list.count == 1 {
                    if last < list[0] { for day in (last + 1)...list[0] { days.append(day) } } else { days.append(list[0]) }
                    pendingRange = false
                } else {
                    days.append(contentsOf: list)
                }
                consumed = index + 1
                index += 1
                continue
            }
            if !days.isEmpty {
                let key = normalizedToken(token)
                if ["et", "and", "y", "und", "e", "&", "+", ","].contains(key) { index += 1; continue }
                if ["à", "a", "au", "to", "bis", "ate", "al", "-"].contains(key) { pendingRange = true; index += 1; continue }
            }
            break
        }
        guard !days.isEmpty else { return nil }
        var unique: [Int] = []
        for day in days where !unique.contains(day) { unique.append(day) }
        let rest = tokens[consumed...].joined(separator: " ")
        return (unique, rest, anyFuzzy)
    }

    /// "Lun", "Lun/Mer/Ven", "Lun,", "Lun-Ven" (a range) or "月・水": the days, or nil if a word is not a day. `fuzzy` when
    /// a name was matched by its resemblance ("Mardl").
    static func gluedDays(_ token: String) -> (days: [Int], fuzzy: Bool)? {
        let separators: Set<Character> = ["/", ",", "&", "+", "・", "、", "-"]
        var parts: [String] = []
        var seps: [Character] = []
        var current = ""
        for character in token {
            if separators.contains(character) {
                if !current.isEmpty { parts.append(current); current = "" }
                seps.append(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { parts.append(current) }
        guard !parts.isEmpty else { return nil }
        var found: [Int] = []
        var fuzzy = false
        for part in parts {
            guard let match = dayMatch(part) else { return nil }
            found.append(match.day)
            if match.fuzzy { fuzzy = true }
        }
        if found.count == 2, seps.count == 1, seps[0] == "-", found[0] < found[1] {
            return (Array(found[0]...found[1]), fuzzy)
        }
        return (found, fuzzy)
    }

    // MARK: Layout: grid with the days as columns

    /// The days written side by side in a line of the page ("Lun Mar Mer" or one line per day at the same height).
    static func dayCandidates(line: RecognizedLine, index: Int) -> [DayCandidate] {
        var text = line.text.replacingOccurrences(of: #"\d{1,2}\s?[月日]"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "-feira", with: "", options: .caseInsensitive)
        let tokens = headerTokens(text).filter { !isMonthWord($0.token) }
        guard !tokens.isEmpty, tokens.count <= 8 else { return [] }
        var found: [DayCandidate] = []
        func candidate(_ day: Int, _ key: String, _ strong: Bool, _ fraction: Double, fuzzy: Bool = false,
                       alternates: [Int] = []) -> DayCandidate {
            DayCandidate(day: day, key: key, strong: strong, x: line.box.minX + CGFloat(fraction) * line.box.width,
                         y: line.box.midY, bottom: line.box.maxY, line: index, fuzzy: fuzzy, alternates: alternates)
        }
        // "L M M J V" (the initials of a week): five to seven single letters in a known order.
        if (5...7).contains(tokens.count), tokens.allSatisfy({ $0.token.count == 1 && ($0.token.first?.isLetter ?? false) }),
           let days = initialsDays(tokens.map { $0.token }) {
            return zip(days, tokens).map { pair in
                candidate(pair.0, pair.1.token.lowercased(), false, (pair.1.from + pair.1.to) / 2)
            }
        }
        let hasDigits = text.contains(where: { $0.isNumber })
        for (position, token) in tokens.enumerated() {
            let key = dayKey(token.token)
            var middle = (token.from + token.to) / 2
            if hasDigits {
                // "lun. 21 mar. 22": a cell is the day name with its date, up to the next day name.
                let next = position + 1 < tokens.count ? tokens[position + 1].from : 1.0
                middle = tokens.count > 1 ? (token.from + next) / 2 : 0.5
            }
            if let day = strongDays[key] {
                found.append(candidate(day, key, true, middle))
            } else if key == "do" {
                found.append(candidate(7, key, false, middle))
            } else if let day = weakDays[key] {
                found.append(candidate(day, key, false, middle))
            } else if key.count >= 2, let sequence = cjkSequence(key) {
                for item in sequence {
                    let fraction = token.from + (token.to - token.from) * (item.from + item.to) / 2
                    found.append(candidate(item.day, "cjk", false, fraction))
                }
            } else if let near = fuzzyDay(token.token) {
                // "Mardl", "Lur": a name with one wrong letter. Never a clear name (not strong) and always in doubt.
                found.append(candidate(near.day, key, false, middle, fuzzy: true, alternates: near.alternates))
            } else {
                return []
            }
        }
        return found
    }

    /// A month written after a day and its date ("Lun. 26 août"): not a word that cancels the header.
    static func isMonthWord(_ token: String) -> Bool {
        let key = normalizedToken(token)
        guard key.count >= 3, key.allSatisfy({ $0.isLetter }), monthPrefixes.contains(String(key.prefix(3))) else { return false }
        // "Mardl" starts like a month ("mar") but is a day read with a wrong letter.
        return strongDays[key] == nil && weakDays[key] == nil && fuzzyDay(token) == nil
    }

    /// The key of a header word in the day tables: folded ("Lundi" -> "lundi"), or as written for the scripts that
    /// folding could change.
    static func dayKey(_ raw: String) -> String {
        let folded = normalizedToken(raw)
        if strongDays[folded] != nil || weakDays[folded] != nil { return folded }
        let plain = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,:;()[]{}\"'"))
        if strongDays[plain] != nil || weakDays[plain] != nil { return plain }
        return folded
    }

    static let zhDigits: [Character: Int] = ["一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7, "天": 7]
    static let cjkPrefixes: [String] = ["星期", "礼拜", "禮拜", "周", "週"]

    /// A run of day characters without spaces ("月火水木金", "周一周二周三", "월화수목금"): each day with its place (0...1)
    /// in the word. nil when a character is not a day.
    static func cjkSequence(_ key: String) -> [(day: Int, from: Double, to: Double)]? {
        let characters = Array(key)
        let count = characters.count
        var result: [(day: Int, from: Double, to: Double)] = []
        var index = 0
        while index < count {
            var day: Int? = nil
            var next = index + 1
            for prefix in cjkPrefixes {
                let length = prefix.count
                if index + length < count, String(characters[index..<(index + length)]) == prefix,
                   let digit = zhDigits[characters[index + length]] {
                    day = digit
                    next = index + length + 1
                    break
                }
            }
            if day == nil {
                guard cjkDayCharacters.contains(characters[index]), let single = weakDays[String(characters[index])] else { return nil }
                day = single
            }
            guard let found = day else { return nil }
            result.append((day: found, from: Double(index) / Double(count), to: Double(next) / Double(count)))
            index = next
        }
        return result.isEmpty ? nil : result
    }

    /// Initials of the days in a week header, with the days they stand for (Monday first, or Sunday first for "S M T W T F S").
    static let initialsSequences: [(letters: String, days: [Int])] = [
        ("MTWTFSS", [1, 2, 3, 4, 5, 6, 7]), ("LMMJVSD", [1, 2, 3, 4, 5, 6, 7]), ("LMXJVSD", [1, 2, 3, 4, 5, 6, 7]),
        ("MDMDFSS", [1, 2, 3, 4, 5, 6, 7]), ("LMMGVSD", [1, 2, 3, 4, 5, 6, 7]),
        ("SMTWTFS", [7, 1, 2, 3, 4, 5, 6]), ("DLMMJVS", [7, 1, 2, 3, 4, 5, 6])
    ]

    static func initialsDays(_ letters: [String]) -> [Int]? {
        let joined = letters.joined().uppercased()
        let count = letters.count
        for sequence in initialsSequences {
            if count == 7, joined == sequence.letters { return sequence.days }
            if (5...6).contains(count), sequence.days[0] == 1, sequence.letters.hasPrefix(joined) {
                return Array(sequence.days.prefix(count))
            }
        }
        return nil
    }

    /// The initials of a week when each letter is a line of its own, side by side ("L" "M" "M" "J" "V").
    static func initialsFromSeparateLines(_ lines: [RecognizedLine]) -> [DayCandidate] {
        var singles: [(index: Int, line: RecognizedLine)] = []
        for (index, line) in lines.enumerated() where line.text.count == 1 && (line.text.first?.isLetter ?? false) {
            singles.append((index: index, line: line))
        }
        singles.sort { $0.line.box.midY < $1.line.box.midY }
        var groups: [[(index: Int, line: RecognizedLine)]] = []
        for single in singles {
            if let first = groups.last?.first, abs(single.line.box.midY - first.line.box.midY) <= 0.02 {
                groups[groups.count - 1].append(single)
            } else {
                groups.append([single])
            }
        }
        var result: [DayCandidate] = []
        for group in groups where (5...7).contains(group.count) {
            let ordered = group.sorted { $0.line.box.midX < $1.line.box.midX }
            guard let days = initialsDays(ordered.map { $0.line.text }) else { continue }
            for (day, single) in zip(days, ordered) {
                result.append(DayCandidate(day: day, key: single.line.text.lowercased(), strong: false, x: single.line.box.midX,
                                           y: single.line.box.midY, bottom: single.line.box.maxY, line: single.index))
            }
        }
        return result
    }

    /// Every row of day names of the page (at least two days, three unless one is unmistakable), top to bottom.
    static func allGrids(in lines: [RecognizedLine]) -> [Grid] {
        var all: [DayCandidate] = []
        for (index, line) in lines.enumerated() {
            all.append(contentsOf: dayCandidates(line: line, index: index))
        }
        all.append(contentsOf: initialsFromSeparateLines(lines))
        guard all.count >= 2 else { return [] }
        all.sort { $0.y < $1.y }
        var groups: [[DayCandidate]] = []
        for candidate in all {
            if let first = groups.last?.first, abs(candidate.y - first.y) <= 0.025 {
                groups[groups.count - 1].append(candidate)
            } else {
                groups.append([candidate])
            }
        }
        var result: [Grid] = []
        for group in groups where group.count >= 2 {
            // "Do" is Thursday in German, Sunday in the other languages.
            let german = group.contains { germanOnlyKeys.contains($0.key) }
            var members = group.map { candidate -> DayCandidate in
                var copy = candidate
                if copy.key == "do", german { copy.day = 4 }
                return copy
            }
            // A name read with a wrong letter ("Man") that lands on a day a clear name already holds ("Lun") is another day.
            let clearDays = Set(members.filter { !$0.fuzzy }.map { $0.day })
            for index in members.indices where members[index].fuzzy && clearDays.contains(members[index].day) {
                if let other = members[index].alternates.first(where: { !clearDays.contains($0) }) { members[index].day = other }
            }
            members.sort { $0.x < $1.x }
            var kept: [DayCandidate] = []
            for member in members {
                if let last = kept.last, member.x - last.x < 0.04 { continue }
                if kept.contains(where: { $0.day == member.day }) { continue }
                kept.append(member)
            }
            let strongCount = kept.filter { $0.strong }.count
            guard kept.count >= 3 || (kept.count == 2 && strongCount >= 1) else { continue }
            result.append(Grid(headers: kept,
                               lineIndexes: Set(group.map { $0.line }),
                               bandBottom: group.map { $0.bottom }.max() ?? 0))
        }
        return result
    }

    /// The row of day names that heads the columns, if the page is a grid (the one with the most days).
    static func detectGrid(in lines: [RecognizedLine]) -> Grid? {
        var best: Grid? = nil
        for candidate in allGrids(in: lines) {
            if let current = best, current.headers.count >= candidate.headers.count { continue }
            best = candidate
        }
        return best
    }

    /// Where the hours are, from the labels in the left margin of a grid.
    struct TimeAxis {
        /// Labels that are ranges ("8h-9h"): the row they name.
        var rows: [(y: CGFloat, start: Int, end: Int)] = []
        /// Labels that are one hour ("8h"), increasing with the height on the page.
        var points: [(y: CGFloat, minute: Int)] = []

        init(margin: [RecognizedLine]) {
            var rawPoints: [(y: CGFloat, minute: Int)] = []
            for line in margin.sorted(by: { $0.box.midY < $1.box.midY }) {
                guard let found = ScheduleParser.timeOnly(line.text) else { continue }
                if let end = found.end {
                    rows.append((y: line.box.midY, start: found.start, end: end))
                } else {
                    rawPoints.append((y: line.box.midY, minute: found.start))
                }
            }
            var lastY = -CGFloat.infinity
            var lastMinute = -1
            for point in rawPoints where point.y > lastY + 0.001 && point.minute > lastMinute {
                points.append(point)
                lastY = point.y
                lastMinute = point.minute
            }
        }

        /// The hours of a block of text that has none of its own, from where it sits.
        func lookup(top: CGFloat, center: CGFloat) -> Placement? {
            if rows.count >= 2 {
                var best = rows[0]
                for row in rows where abs(row.y - center) < abs(best.y - center) { best = row }
                return Placement(start: best.start, end: best.end)
            }
            guard points.count >= 2 else { return nil }
            var low = points[0]
            var high = points[1]
            for index in 0..<(points.count - 1) where top >= points[index].y {
                low = points[index]
                high = points[index + 1]
            }
            let span = high.y - low.y
            guard span > 0 else { return nil }
            let raw = Double(low.minute) + Double((top - low.y) / span) * Double(high.minute - low.minute)
            let snapped = Int((raw / 15).rounded()) * 15
            guard (0..<1440).contains(snapped) else { return nil }
            return Placement(start: snapped, end: nil)
        }
    }

    static func gridDrafts(_ lines: [RecognizedLine], _ grid: Grid) -> [Draft] {
        let headers = grid.headers
        let count = headers.count
        guard count >= 2 else { return [] }
        let spacing = max((headers[count - 1].x - headers[0].x) / CGFloat(count - 1), 0.02)
        var columns = [[RecognizedLine]](repeating: [], count: count)
        var margin: [RecognizedLine] = []
        for (index, line) in lines.enumerated() {
            if grid.lineIndexes.contains(index) || line.box.midY <= grid.bandBottom { continue }
            let x = line.box.midX
            if x < headers[0].x - spacing / 2 { margin.append(line); continue }
            if x > headers[count - 1].x + spacing / 2 { continue }
            var nearest = 0
            var nearestDistance = abs(x - headers[0].x)
            for column in 1..<count {
                let distance = abs(x - headers[column].x)
                if distance < nearestDistance { nearest = column; nearestDistance = distance }
            }
            columns[nearest].append(line)
        }
        let axis = TimeAxis(margin: margin)
        var drafts: [Draft] = []
        for (column, columnLines) in columns.enumerated() {
            let sorted = columnLines.sorted { $0.box.minY < $1.box.minY }
            for block in blocks(of: sorted) {
                if var draft = blockDraft(block, weekday: headers[column].day, axis: axis) {
                    if headers[column].fuzzy { draft.uncertain.insert(.day) }
                    drafts.append(draft)
                }
            }
        }
        return drafts
    }

    /// Lines of one column, top to bottom, cut into cells: a big gap or a second time starts a new cell.
    static func blocks(of lines: [RecognizedLine]) -> [[RecognizedLine]] {
        var result: [[RecognizedLine]] = []
        var current: [RecognizedLine] = []
        var currentHasTime = false
        for line in lines {
            let hasTime = findTime(in: line.text) != nil
            if let last = current.last {
                let gap = line.box.minY - last.box.maxY
                let limit = 0.9 * max(line.box.height, last.box.height, 0.008)
                if gap > limit || (hasTime && currentHasTime) {
                    result.append(current)
                    current = []
                    currentHasTime = false
                }
            }
            current.append(line)
            if hasTime { currentHasTime = true }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    static func blockDraft(_ lines: [RecognizedLine], weekday: Int, axis: TimeAxis) -> Draft? {
        var time: TimeFound? = nil
        var room: String? = nil
        var roomRepaired = false
        var titles: [String] = []
        for line in lines {
            let info = analyze(line.text)
            if time == nil { time = info.time }
            if room == nil, let found = info.room {
                room = found
                roomRepaired = info.roomRepaired
            }
            if !info.title.isEmpty { titles.append(info.title) }
        }
        let title = titles.prefix(2).joined(separator: " ")
        guard !title.isEmpty else { return nil }
        let roomFlag: Set<SlotField> = room != nil && roomRepaired ? [.room] : []
        if let time = time {
            return Draft(weekday: weekday, start: time.start, end: time.end, title: title, room: room,
                         uncertain: timeFlags(time).union(roomFlag))
        }
        let top = lines.map { $0.box.minY }.min() ?? 0
        let bottom = lines.map { $0.box.maxY }.max() ?? top
        guard let placed = axis.lookup(top: top, center: (top + bottom) / 2) else { return nil }
        return Draft(weekday: weekday, start: placed.start, end: placed.end, title: title, room: room, uncertain: roomFlag)
    }

    /// The fields in doubt because a look-alike letter was read as a digit in a time.
    static func timeFlags(_ time: TimeFound) -> Set<SlotField> {
        guard time.repaired else { return [] }
        return time.end == nil ? [.start] : [.start, .end]
    }

    /// The drafts of a column whose day name was read with a wrong letter: their day is in doubt.
    static func marked(_ drafts: [Draft], dayInDoubt: Bool) -> [Draft] {
        guard dayInDoubt else { return drafts }
        return drafts.map { draft in
            var copy = draft
            copy.uncertain.insert(.day)
            return copy
        }
    }

    // MARK: Layout: timetable grid where the height of a block gives the hours

    /// The rows of a grid whose left margin writes two hours per row ("08:10" then "09:00", "09:05" then "09:55"...).
    /// The text of a block does not say when it starts or ends: the rows it covers do.
    struct Timeline {
        struct Row {
            var start: Int
            var end: Int
            var startY: CGFloat
            var endY: CGFloat
        }

        /// A block never covers more rows than this.
        static let maxSpan = 4

        var rows: [Row]
        /// Estimated edges of the rows on the page: `bounds[i]` is the top of row i, `bounds[rows.count]` the bottom
        /// of the last one. The two hours of a row are centred in it, so an edge is halfway between the end label of
        /// a row and the start label of the next.
        var bounds: [CGFloat]

        /// Pairs the hour labels of the margin (top to bottom) into rows; a label with no partner is ignored.
        init?(margin: [RecognizedLine]) {
            var labels: [(y: CGFloat, minute: Int)] = []
            for line in margin.sorted(by: { $0.box.midY < $1.box.midY }) {
                if let minute = ScheduleParser.clockMinute(line.text) {
                    labels.append((y: line.box.midY, minute: minute))
                } else if let pair = ScheduleParser.clockPair(line.text) {
                    // Both hours of a row in one box. Stacked (a tall box): the start is in the upper half and the end
                    // in the lower one. Side by side: the same height, the start first.
                    let box = line.box
                    if box.height > 0.010 {
                        labels.append((y: box.minY + box.height * 0.25, minute: pair.first))
                        labels.append((y: box.minY + box.height * 0.75, minute: pair.second))
                    } else {
                        labels.append((y: box.midY, minute: pair.first))
                        labels.append((y: box.midY + 0.0001, minute: pair.second))
                    }
                }
            }
            var found: [Row] = []
            var index = 0
            while index + 1 < labels.count {
                let first = labels[index]
                let second = labels[index + 1]
                let length = second.minute - first.minute
                if length >= 30, length <= 180, second.y > first.y, first.minute >= (found.last?.end ?? 0) {
                    found.append(Row(start: first.minute, end: second.minute, startY: first.y, endY: second.y))
                    index += 2
                } else {
                    index += 1
                }
            }
            guard found.count >= 2 else { return nil }
            // Rows follow each other closely (a break of 5 to 10 minutes). A plain list of hours (8:00, 9:00, 10:00...)
            // would pair up wrongly, and the gaps between its pairs are as long as the pairs themselves.
            var tight = 0
            for k in 1..<found.count where found[k].start - found[k - 1].end < found[k - 1].end - found[k - 1].start {
                tight += 1
            }
            guard tight * 2 >= found.count - 1 else { return nil }
            let count = found.count
            var edges = [CGFloat](repeating: 0, count: count + 1)
            for k in 1..<count { edges[k] = (found[k - 1].endY + found[k].startY) / 2 }
            edges[0] = found[0].startY - (found[1].startY - found[0].endY) / 2
            edges[count] = found[count - 1].endY + (found[count - 1].startY - found[count - 2].endY) / 2
            for k in 1...count where edges[k] <= edges[k - 1] { return nil }
            self.rows = found
            self.bounds = edges
        }

        /// The rows whose top is the nearest to `top` and whose bottom is the nearest to `bottom`.
        func snap(top: CGFloat, bottom: CGFloat) -> (first: Int, last: Int) {
            var first = 0
            for k in 0..<rows.count where abs(bounds[k] - top) < abs(bounds[first] - top) { first = k }
            var last = rows.count - 1
            for k in 0..<rows.count where abs(bounds[k + 1] - bottom) < abs(bounds[last + 1] - bottom) { last = k }
            if last < first { last = first }
            return (first, last)
        }

        /// The rows of a block seen only by its text, which is centred in the block: the rows that hold the text and
        /// whose middle is the nearest to the middle of the text, the smallest range when several are about as good.
        func fit(top: CGFloat, bottom: CGFloat) -> (first: Int, last: Int)? {
            let center = (top + bottom) / 2
            var candidates: [(first: Int, last: Int, error: CGFloat)] = []
            for first in 0..<rows.count {
                for last in first..<min(rows.count, first + Timeline.maxSpan) {
                    let blockTop = bounds[first]
                    let blockBottom = bounds[last + 1]
                    guard blockTop <= top + 0.005, blockBottom >= bottom - 0.005 else { continue }
                    candidates.append((first: first, last: last, error: abs((blockTop + blockBottom) / 2 - center)))
                }
            }
            guard let best = candidates.map({ $0.error }).min() else { return nil }
            var chosen: (first: Int, last: Int, error: CGFloat)? = nil
            for candidate in candidates where candidate.error <= best + 0.004 {
                if let current = chosen {
                    let size = candidate.last - candidate.first
                    let currentSize = current.last - current.first
                    if size < currentSize || (size == currentSize && candidate.error < current.error) { chosen = candidate }
                } else {
                    chosen = candidate
                }
            }
            guard let picked = chosen else { return nil }
            return (picked.first, picked.last)
        }
    }

    /// The lines of a block of text in one column of the grid.
    struct TextCluster {
        var lines: [RecognizedLine]
        var top: CGFloat
        var bottom: CGFloat
        var center: CGFloat { (top + bottom) / 2 }
    }

    /// What the text of a block says: a title (maybe cut by the cell), a room and the code of the course.
    struct BlockContent {
        var title: String
        var room: String?
        var code: String?
        /// The room holds a look-alike letter that was read as a digit.
        var roomRepaired = false
    }

    /// Offsets (0...1 of the page width) from the left edge of a column where the probe looks: just inside the cell
    /// (the edge itself is only known to a few pixels), left of the centred text. On the real captures the cell
    /// border is 0 to 3 pixels from the estimated edge and the widest text starts about 5 pixels after it.
    static let probeOffsets: [Double] = [0.003, 0.0045, 0.006, 0.0075, 0.009]

    /// "08:10", "08.10", "8h10": a clock time and nothing else.
    static let clockRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(\d{1,2})\s?(?:[:hH]|\.)\s?(\d{2})$"#, options: [])

    /// Two clock times in one line ("08:10 09:00"): the start and the end of a row read as one text.
    static let clockPairRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(\d{1,2}\s?(?:[:hH]|\.)\s?\d{2})\s+(\d{1,2}\s?(?:[:hH]|\.)\s?\d{2})$"#, options: [])

    static func clockMinute(_ raw: String) -> Int? {
        guard let regex = clockRegex else { return nil }
        // "O8:1O" in the margin is 08:10 (the labels of a row are not marked one by one).
        let text = repairedHours(raw)?.text ?? raw
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              let hour = Int(group(match, 1, in: ns) ?? ""), let minute = Int(group(match, 2, in: ns) ?? ""),
              hour < 24, minute < 60 else { return nil }
        return hour * 60 + minute
    }

    /// The two times of a line that holds both, in reading order.
    static func clockPair(_ raw: String) -> (first: Int, second: Int)? {
        guard let regex = clockPairRegex else { return nil }
        let text = repairedHours(raw)?.text ?? raw
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              let first = clockMinute(group(match, 1, in: ns) ?? ""),
              let second = clockMinute(group(match, 2, in: ns) ?? "") else { return nil }
        return (first, second)
    }

    /// "410-343-CH", "203-NYB-05": the code of a course, as written in a block and in the list of courses.
    static let courseCodeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])\d{3}-[A-Za-z0-9]{3}-[A-Za-z0-9]{2}(?![0-9])"#, options: [])

    /// The first course code of a text, with what comes before and after it.
    static func courseCode(in text: String) -> (code: String, before: String, after: String)? {
        guard let regex = courseCodeRegex else { return nil }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var match = regex.firstMatch(in: text, options: [], range: full)
        var repaired: String? = nil
        // "41O-343-CH": a look-alike in the three digits of the code is read as the digit it stands for.
        if match == nil, let near = courseCodeLookalikeRegex?.firstMatch(in: text, options: [], range: full) {
            let raw = ns.substring(with: near.range)
            if let digits = lookalikeValue(String(raw.prefix(3))), digits.anchored {
                match = near
                repaired = digits.digits + String(raw.dropFirst(3))
            }
        }
        guard let found = match else { return nil }
        let end = found.range.location + found.range.length
        let code = (repaired ?? ns.substring(with: found.range)).uppercased()
        return (code, ns.substring(to: found.range.location), ns.substring(from: end))
    }

    /// The same with a look-alike letter among the three digits.
    static let courseCodeLookalikeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])[0-9OoIl]{3}-[A-Za-z0-9]{3}-[A-Za-z0-9]{2}(?![0-9])"#, options: [])

    static let roomWords: Set<String> = ["local", "salle", "room", "classe", "amphi", "labo", "aula", "raum", "sala"]

    /// "Local F5107", "Salle B-204": a line that is a room.
    static func isRoomLine(_ text: String) -> Bool {
        let list = words(of: text)
        guard list.count >= 2, let first = list.first else { return false }
        return roomWords.contains(first)
    }

    static let modeLines: Set<String> = ["presentiel", "en ligne", "a distance", "distance", "hybride", "comodal", "online"]

    /// "Présentiel", "En ligne": how the class is given (a line of its own in the block).
    static func isModeLine(_ text: String) -> Bool {
        modeLines.contains(words(of: text).joined(separator: " "))
    }

    /// "gr.41070" written alone or after a code that was not read.
    static func isGroupLine(_ text: String) -> Bool {
        text.range(of: #"(?i)\bgr\.?\s?\d{3,}"#, options: .regularExpression) != nil
    }

    /// The text of a list entry without the number of its group ("21050 Titre" or "gr.21050 Titre").
    static func withoutGroupNumber(_ text: String) -> String {
        let stripped = text.replacingOccurrences(of: #"^\s*(?:gr\.?\s*)?\d{3,6}(?![A-Za-z0-9])\s*"#, with: "",
                                                  options: [.regularExpression, .caseInsensitive])
        return stripped.trimmingCharacters(in: .whitespaces)
    }

    /// Title, room and code of a block. The title is what comes before the code line; the teacher, the mode and
    /// the code line itself are dropped. A block with no code, no room and no mode is not a class.
    static func blockContent(_ lines: [RecognizedLine]) -> BlockContent? {
        let texts = lines.map { $0.text }
        let codeIndex = texts.firstIndex { courseCode(in: $0) != nil }
        let roomIndex = texts.firstIndex { isRoomLine($0) }
        let modeIndex = texts.firstIndex { isModeLine($0) }
        guard let end = codeIndex ?? roomIndex ?? modeIndex else { return nil }
        var parts: [String] = []
        for text in texts[0..<end] where !isModeLine(text) && !isRoomLine(text) && !isGroupLine(text) {
            parts.append(text)
        }
        var code: String? = nil
        if let at = codeIndex, let found = courseCode(in: texts[at]) {
            code = found.code
            let before = found.before.trimmingCharacters(in: .whitespaces)
            if !before.isEmpty { parts.append(before) }
        }
        var room = roomIndex.map { texts[$0].trimmingCharacters(in: .whitespaces) }
        var roomRepaired = false
        // "Local H3O46": the room is read with the O as a zero, and said to be in doubt.
        if let line = room {
            let fixed = repairedRoomWords(in: line)
            if !fixed.tokens.isEmpty {
                room = fixed.text
                roomRepaired = true
            }
        }
        return BlockContent(title: parts.joined(separator: " "), room: room, code: code, roomRepaired: roomRepaired)
    }

    /// Code to full title, from the "Liste des cours" above the grid (one row per course: date, code, group, title,
    /// teacher; Vision may return the whole row or each column on its own, so lines at the same height are one row).
    static func courseCatalog(_ lines: [RecognizedLine], aboveY limit: CGFloat) -> [String: String] {
        let candidates = lines.filter { $0.box.midY < limit }.sorted { $0.box.midY < $1.box.midY }
        var rows: [[RecognizedLine]] = []
        for line in candidates {
            if let first = rows.last?.first, abs(line.box.midY - first.box.midY) <= 0.0035 {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        var catalog: [String: String] = [:]
        for row in rows {
            let items = row.sorted { $0.box.minX < $1.box.minX }
            guard let at = items.firstIndex(where: { courseCode(in: $0.text) != nil }),
                  let found = courseCode(in: items[at].text) else { continue }
            var pieces = [found.after]
            for item in items[(at + 1)...] { pieces.append(item.text) }
            for piece in pieces {
                let title = withoutGroupNumber(piece)
                if title.filter({ $0.isLetter }).count >= 3 {
                    if catalog[found.code] == nil { catalog[found.code] = title }
                    break
                }
            }
        }
        return catalog
    }

    /// The full title of a class: the one of the list (by code), else the one the cut title starts.
    static func fullTitle(_ cut: String, code: String?, catalog: [String: String]) -> String {
        if let code = code, let full = catalog[code] { return full }
        let key = fold(cut)
        guard key.count >= 4 else { return cut }
        let matches = Set(catalog.values.filter { fold($0).hasPrefix(key) })
        if matches.count == 1, let only = matches.first { return only }
        return cut
    }

    /// Lines of one column cut into blocks of text: a gap, or two course codes, starts a new one.
    static func textClusters(_ lines: [RecognizedLine]) -> [TextCluster] {
        let sorted = lines.sorted { $0.box.minY < $1.box.minY }
        var groups: [[RecognizedLine]] = []
        var current: [RecognizedLine] = []
        var currentBottom: CGFloat = 0
        var currentHeight: CGFloat = 0
        for line in sorted {
            if !current.isEmpty {
                let limit = max(0.006, 0.9 * max(line.box.height, currentHeight))
                if line.box.minY - currentBottom > limit {
                    groups.append(current)
                    current = []
                    currentBottom = 0
                    currentHeight = 0
                }
            }
            current.append(line)
            currentBottom = max(currentBottom, line.box.maxY)
            currentHeight = max(currentHeight, line.box.height)
        }
        if !current.isEmpty { groups.append(current) }
        var clusters: [TextCluster] = []
        for group in groups {
            for part in splitByCourseCodes(group) where !part.isEmpty {
                let top = part.map { $0.box.minY }.min() ?? 0
                let bottom = part.map { $0.box.maxY }.max() ?? top
                clusters.append(TextCluster(lines: part, top: top, bottom: bottom))
            }
        }
        return clusters
    }

    /// Two blocks stuck together (no gap) hold two course codes: cut at the biggest gap between the two codes.
    static func splitByCourseCodes(_ lines: [RecognizedLine]) -> [[RecognizedLine]] {
        let codes = lines.indices.filter { courseCode(in: lines[$0].text) != nil }
        guard codes.count >= 2 else { return [lines] }
        var cuts: [Int] = []
        for pair in 0..<(codes.count - 1) {
            var bestCut = codes[pair] + 1
            var bestGap = -CGFloat.infinity
            for cut in (codes[pair] + 1)...codes[pair + 1] {
                let gap = lines[cut].box.minY - lines[cut - 1].box.maxY
                if gap > bestGap {
                    bestGap = gap
                    bestCut = cut
                }
            }
            cuts.append(bestCut)
        }
        var result: [[RecognizedLine]] = []
        var start = 0
        for cut in cuts + [lines.count] {
            result.append(Array(lines[start..<cut]))
            start = cut
        }
        return result
    }

    /// Holes shorter than this (0...1 of the page height) inside a stretch are closed: a line of text, or a letter
    /// the probe hit. An empty row is at least about 0.02 high, so two blocks are never joined by this.
    static let closedHole = 0.010

    /// Which stretches a probe is asked for.
    enum RunKind { case lighter, darker, framed }

    /// The stretches that most of the probes agree on along the left edge of a column, or nil when none can tell.
    /// The probes are a few pixels apart: the border of the cell, a letter or the neighbour column spoil a few of
    /// them, not most. For the outlines of boxed blocks the vote is on the places of the lines (see `outlineStretches`).
    static func columnRuns(_ probe: BlockProbe, left: CGFloat, from: Double, to: Double, kind: RunKind = .lighter) -> [ClosedRange<Double>]? {
        var lists: [[ClosedRange<Double>]] = []
        for offset in probeOffsets {
            let x = Double(left) + offset
            guard x >= 0, x < 1 else { continue }
            let found: [ClosedRange<Double>]?
            switch kind {
            case .lighter: found = probe.blockRuns(atX: x, fromY: from, toY: to)
            case .darker: found = probe.darkRuns(atX: x, fromY: from, toY: to)
            case .framed: found = probe.framedRuns(atX: x, fromY: from, toY: to)
            }
            guard let runs = found else { continue }
            lists.append(runs)
        }
        guard !lists.isEmpty else { return nil }
        if kind == .framed { return outlineStretches(lists) }
        var merged: [ClosedRange<Double>] = []
        for run in majorityRuns(lists) {
            if let last = merged.last, run.lowerBound - last.upperBound <= closedHole {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, run.upperBound)
            } else {
                merged.append(run)
            }
        }
        return merged
    }

    /// Two outlines seen by different probes are the same line when they are this close (0...1 of the page height).
    static let outlineTolerance = 0.0025
    /// Two lines closer than this are not a block.
    static let shortestStretch = 0.01

    /// The stretches between the outlines that most probes saw. Each list holds stretches that touch (the end of one is
    /// the start of the next), so the lines are the bounds of the stretches; a line seen by most lists, within a couple
    /// of pixels, is kept (its place is the mean of the places seen), and the stretches run from one kept line to the next.
    /// Voting on the stretches themselves would join blocks that share a line.
    static func outlineStretches(_ lists: [[ClosedRange<Double>]]) -> [ClosedRange<Double>] {
        var seen: [(place: Double, list: Int)] = []
        for (index, list) in lists.enumerated() {
            for run in list {
                seen.append((place: run.lowerBound, list: index))
                seen.append((place: run.upperBound, list: index))
            }
        }
        seen.sort { $0.place < $1.place }
        let needed = lists.count / 2 + 1
        var lines: [Double] = []
        var group: [(place: Double, list: Int)] = []
        func close() {
            if Set(group.map { $0.list }).count >= needed {
                lines.append(group.map { $0.place }.reduce(0, +) / Double(group.count))
            }
            group = []
        }
        for item in seen {
            if let first = group.first, item.place - first.place > outlineTolerance { close() }
            group.append(item)
        }
        if !group.isEmpty { close() }
        var result: [ClosedRange<Double>] = []
        for index in 0..<max(0, lines.count - 1) where lines[index + 1] - lines[index] >= shortestStretch {
            result.append(lines[index]...lines[index + 1])
        }
        return result
    }

    /// The stretches of the kind of cell that holds the text: the lighter ones (Omnivox: white blocks on grey cells) or the
    /// darker ones (a coloured block on a white page, a dark-mode screenshot), whichever contains more of the `marks`
    /// (heights where text sits, 0...1). The lighter ones win a tie; nil when the probe tells nothing.
    static func bestRuns(_ probe: BlockProbe, left: CGFloat, from: Double, to: Double, marks: [Double]) -> [ClosedRange<Double>]? {
        let light = columnRuns(probe, left: left, from: from, to: to)
        let dark = columnRuns(probe, left: left, from: from, to: to, kind: .darker)
        func covered(_ runs: [ClosedRange<Double>]?) -> Int {
            guard let runs = runs else { return 0 }
            return marks.filter { mark in runs.contains { $0.contains(mark) } }.count
        }
        let darkCount = covered(dark)
        if darkCount > covered(light), darkCount * 10 >= marks.count * 6 { return dark }
        return light
    }

    /// The stretches covered by more than half of the lists.
    static func majorityRuns(_ lists: [[ClosedRange<Double>]]) -> [ClosedRange<Double>] {
        let needed = lists.count / 2 + 1
        var events: [(y: Double, change: Int)] = []
        for list in lists {
            for run in list {
                events.append((y: run.lowerBound, change: 1))
                events.append((y: run.upperBound, change: -1))
            }
        }
        events.sort { a, b in a.y != b.y ? a.y < b.y : a.change > b.change }
        var result: [ClosedRange<Double>] = []
        var count = 0
        var start: Double? = nil
        for event in events {
            count += event.change
            if count >= needed, start == nil {
                start = event.y
            } else if count < needed, let begin = start {
                if event.y > begin { result.append(begin...event.y) }
                start = nil
            }
        }
        return result
    }

    /// The classes of a grid whose rows are named by two hours in the left margin. nil when the page is not such a
    /// grid (the other readings then apply); an empty list when it is one but holds no class.
    static func timetableDrafts(_ lines: [RecognizedLine], _ grid: Grid, probe: BlockProbe?) -> [Draft]? {
        let headers = grid.headers
        let count = headers.count
        guard count >= 2 else { return nil }
        // Column edges: halfway between the centres of the day names (half a column at the two ends).
        var edges: [CGFloat] = [headers[0].x - (headers[1].x - headers[0].x) / 2]
        for index in 1..<count { edges.append((headers[index - 1].x + headers[index].x) / 2) }
        edges.append(headers[count - 1].x + (headers[count - 1].x - headers[count - 2].x) / 2)
        var margin: [RecognizedLine] = []
        for (index, line) in lines.enumerated() {
            if grid.lineIndexes.contains(index) || line.box.midY <= grid.bandBottom { continue }
            if line.box.midX < edges[0] { margin.append(line) }
        }
        guard let timeline = Timeline(margin: margin), let lastRow = timeline.rows.last,
              let gridBottom = timeline.bounds.last else { return nil }
        let gridTop = timeline.bounds[0]
        // Only the grid: not the list of courses above it, nor what is written under it ("Accès à Omnivox").
        let lowest = lastRow.endY + 0.008
        var columns = [[RecognizedLine]](repeating: [], count: count)
        for (index, line) in lines.enumerated() {
            if grid.lineIndexes.contains(index) { continue }
            let y = line.box.midY
            let x = line.box.midX
            guard y > grid.bandBottom, y >= gridTop - 0.004, y <= lowest, x >= edges[0], x < edges[count] else { continue }
            var column = 0
            while column < count - 1, x >= edges[column + 1] { column += 1 }
            columns[column].append(line)
        }
        let catalog = courseCatalog(lines, aboveY: headers.map { $0.y }.min() ?? 0)
        let fromY = max(0, Double(gridTop) - 0.002)
        let toY = min(1, Double(gridBottom) + 0.002)
        var drafts: [Draft] = []
        for (column, columnLines) in columns.enumerated() where !columnLines.isEmpty {
            let clusters = textClusters(columnLines)
            let marks = clusters.map { Double($0.center) }
            let runs = probe.flatMap { bestRuns($0, left: edges[column], from: fromY, to: toY, marks: marks) }
            for (index, cluster) in clusters.enumerated() {
                guard let content = blockContent(cluster.lines) else { continue }
                let span = blockRows(clusters, index, runs: runs, timeline: timeline)
                let title = fullTitle(content.title, code: content.code, catalog: catalog)
                guard !title.isEmpty else { continue }
                var uncertain: Set<SlotField> = []
                // The hours come from the middle of the text, not from the colours of the block: a guess.
                if span.estimated { uncertain.formUnion([.start, .end]) }
                if content.roomRepaired, content.room != nil { uncertain.insert(.room) }
                if headers[column].fuzzy { uncertain.insert(.day) }
                drafts.append(Draft(weekday: headers[column].day, start: timeline.rows[span.first].start,
                                    end: timeline.rows[span.last].end, title: title, room: content.room,
                                    uncertain: uncertain, coded: content.code != nil))
            }
        }
        return drafts
    }

    /// The rows covered by the block of a cluster: from the colours when the probe sees the block, else from the
    /// place of the text (`estimated`).
    static func blockRows(_ clusters: [TextCluster], _ index: Int, runs: [ClosedRange<Double>]?,
                          timeline: Timeline) -> (first: Int, last: Int, estimated: Bool) {
        let cluster = clusters[index]
        if let runs = runs, let found = runs.first(where: { $0.contains(Double(cluster.center)) }) {
            // Two blocks stuck together make one stretch: cut halfway between their texts.
            func sameRun(_ k: Int) -> Bool {
                clusters.indices.contains(k) && found.contains(Double(clusters[k].center))
            }
            let top = sameRun(index - 1) ? (clusters[index - 1].bottom + cluster.top) / 2 : CGFloat(found.lowerBound)
            let bottom = sameRun(index + 1) ? (cluster.bottom + clusters[index + 1].top) / 2 : CGFloat(found.upperBound)
            let snapped = timeline.snap(top: top, bottom: bottom)
            if snapped.last - snapped.first < Timeline.maxSpan { return (snapped.first, snapped.last, false) }
        }
        let guess = timeline.fit(top: cluster.top, bottom: cluster.bottom)
            ?? timeline.snap(top: cluster.top, bottom: cluster.bottom)
        return (guess.first, guess.last, true)
    }

    // MARK: Layout: list day by day

    /// Lines at the same height are one row ("8h-10h" at the left, "Maths" at the right).
    static func readingRows(_ lines: [RecognizedLine]) -> [String] {
        let sorted = lines.sorted { a, b in
            if a.box.midY == b.box.midY { return a.box.minX < b.box.minX }
            return a.box.midY < b.box.midY
        }
        var rows: [[RecognizedLine]] = []
        for line in sorted {
            if let first = rows.last?.first {
                let tolerance = max(0.008, 0.5 * max(line.box.height, first.box.height))
                if abs(line.box.midY - first.box.midY) <= tolerance {
                    rows[rows.count - 1].append(line)
                    continue
                }
            }
            rows.append([line])
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map { $0.text }.joined(separator: " ")
        }
    }

    static func listDrafts(_ lines: [RecognizedLine]) -> [Draft] {
        var drafts: [Draft] = []
        var days: [Int] = []
        var pendingTitle: String? = nil
        var pendingRoom: String? = nil
        var recent: [Int] = []
        var awaiting = false
        // The day was matched by its resemblance ("Mardl"), and the room waiting for its class was repaired ("B-2O4").
        var dayFuzzy = false
        var pendingRoomRepaired = false

        func startDay(_ newDays: [Int], fuzzy: Bool = false) {
            days = newDays
            dayFuzzy = fuzzy
            pendingTitle = nil
            pendingRoom = nil
            pendingRoomRepaired = false
            recent = []
            awaiting = false
        }

        for row in readingRows(lines) {
            var text = row
            if let lead = leadingDays(in: text) {
                let hasTime = analyze(lead.rest).time != nil
                // A short word that only looks like a day ("Don") alone on a line does not start a day: it needs a time with it.
                let shortGuess = lead.fuzzy && !hasTime && (text.split(separator: " ").first.map { $0.count < 4 } ?? true)
                if (hasTime || isDateish(lead.rest)) && !shortGuess {
                    startDay(lead.days, fuzzy: lead.fuzzy)
                    if !hasTime { continue }
                    text = lead.rest
                }
            } else if let day = embeddedCJKDay(in: text), analyze(text).time == nil {
                startDay([day])
                continue
            }
            let info = analyze(text)
            if let time = info.time {
                guard !days.isEmpty else { continue }
                let title = info.title.isEmpty ? (pendingTitle ?? "") : info.title
                let room = info.room ?? (info.title.isEmpty ? pendingRoom : nil)
                let roomRepaired = info.room != nil ? info.roomRepaired : (room != nil && pendingRoomRepaired)
                recent = []
                for day in days {
                    // "9h-12h / 13h-17h": the same class at each range of the row.
                    for each in [time] + info.extraTimes {
                        recent.append(drafts.count)
                        var flags = timeFlags(each)
                        if dayFuzzy { flags.insert(.day) }
                        if roomRepaired { flags.insert(.room) }
                        drafts.append(Draft(weekday: day, start: each.start, end: each.end, title: title, room: room, uncertain: flags))
                    }
                }
                awaiting = title.isEmpty
                pendingTitle = nil
                pendingRoom = nil
                pendingRoomRepaired = false
            } else if awaiting, !info.title.isEmpty {
                for index in recent where index < drafts.count {
                    drafts[index].title = info.title
                    if drafts[index].room == nil, let found = info.room {
                        drafts[index].room = found
                        if info.roomRepaired { drafts[index].uncertain.insert(.room) }
                    }
                }
                awaiting = false
            } else if info.title.isEmpty {
                if let room = info.room {
                    for index in recent where index < drafts.count && drafts[index].room == nil {
                        drafts[index].room = room
                        if info.roomRepaired { drafts[index].uncertain.insert(.room) }
                    }
                }
            } else {
                pendingTitle = info.title
                pendingRoom = info.room
                pendingRoomRepaired = info.roomRepaired
            }
        }
        return drafts
    }

    // MARK: Final pass

    /// Gives a missing end the usual length of the page (the middle of the lengths written, else 1 h),
    /// drops what is not a class and removes duplicates.
    static func finalize(_ drafts: [Draft]) -> [ImportedSlot] {
        var lengths: [Int] = []
        for draft in drafts {
            if let end = draft.end, end - draft.start >= 20 { lengths.append(end - draft.start) }
        }
        lengths.sort()
        var usual = 60
        if !lengths.isEmpty {
            let middle = lengths[lengths.count / 2]
            usual = min(max(((middle + 2) / 5) * 5, 30), 180)
        }
        var kept: [(draft: Draft, title: String)] = []
        var startsOfDay: [Int: [Int]] = [:]
        for draft in drafts {
            guard (1...7).contains(draft.weekday), (0..<1440).contains(draft.start) else { continue }
            let title = cleanTitle(draft.title)
            // No class without a name that was read: nothing is invented to fill it.
            guard !title.isEmpty else { continue }
            if isNonCourse(title, coded: draft.coded) {
                // A break or a free period is no class, but a class before it ends where it begins.
                startsOfDay[draft.weekday, default: []].append(draft.start)
                continue
            }
            guard !isUnreadableTitle(title) else { continue }
            kept.append((draft: draft, title: title))
            startsOfDay[draft.weekday, default: []].append(draft.start)
        }
        var slots: [ImportedSlot] = []
        for item in kept {
            let draft = item.draft
            var uncertain = draft.uncertain
            var end = draft.end ?? (draft.start + usual)
            if draft.end == nil {
                // The end is a guess (the usual length of the page), or the start of the next class.
                uncertain.insert(.end)
                if let next = (startsOfDay[draft.weekday] ?? []).filter({ $0 > draft.start }).min(),
                   next < end, next - draft.start >= 20 {
                    // Only a start is written ("8h30 Maths", "10h Physique"): the class ends when the next one begins,
                    // when that comes before the usual length.
                    end = next
                }
            }
            end = min(end, 1440)
            guard end > draft.start else { continue }
            if draft.room == nil { uncertain.remove(.room) }
            // A name of two letters ("TP", "Ed") may be what is left of a longer one.
            if !ScheduleScoring.hasCJK(item.title), item.title.filter({ $0.isLetter }).count <= 2 { uncertain.insert(.title) }
            slots.append(ImportedSlot(weekday: draft.weekday, startMinute: draft.start, endMinute: end,
                                      title: item.title, room: draft.room, uncertain: uncertain))
        }
        return deduplicated(slots)
    }
}
