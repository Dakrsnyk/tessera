import Foundation
import CoreGraphics

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
}

/// Looks at the colours of the image along a vertical line, to tell the blocks that hold a class (lighter)
/// from the empty cells of a timetable grid. Kept as a protocol so the parser stays pure and testable.
protocol BlockProbe {
    /// The vertical stretches (0...1, origin at the top) of "block" colour along the line at `x`, between
    /// `fromY` and `toY`; nil when blocks cannot be told from empty cells.
    func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]?
}

/// One line of text read from an image, with its place on the page.
struct RecognizedLine: Equatable {
    var text: String
    /// Normalised (0...1) with the origin at the top left.
    var box: CGRect
}

/// Turns the lines of text read from a timetable into classes. Pure logic (no Vision, no UIKit), so it is
/// tested without an image. Everything is approximate on purpose: the person checks the result before it
/// is saved. Two layouts are understood: a grid with the days as columns, and a day-by-day list.
enum ScheduleParser {

    // MARK: Entry points

    /// The classes found on ONE page, without looking at the colours of the image.
    static func slots(from lines: [RecognizedLine]) -> [ImportedSlot] {
        slots(from: lines, probe: nil)
    }

    /// The classes found on ONE page. Never fails: unreadable input gives an empty list. The probe (when the
    /// image is known) tells where the blocks of a timetable start and stop; without it their height is guessed.
    static func slots(from lines: [RecognizedLine], probe: BlockProbe?) -> [ImportedSlot] {
        var cleaned: [RecognizedLine] = []
        for line in lines {
            if let kept = cleanedLine(line) { cleaned.append(kept) }
        }
        guard !cleaned.isEmpty else { return [] }
        var drafts: [Draft] = []
        if let grid = detectGrid(in: cleaned) {
            // A grid with a pair of hours per row (Omnivox...): the classes come from the grid only, never from the list.
            if let timetable = timetableDrafts(cleaned, grid, probe: probe) {
                return finalize(timetable)
            }
            drafts = gridDrafts(cleaned, grid)
        }
        if drafts.isEmpty {
            drafts = listDrafts(cleaned)
        }
        return finalize(drafts)
    }

    /// Removes identical classes (same day, hours and title), keeping a room when one copy has it, and sorts
    /// by day then hour.
    static func deduplicated(_ slots: [ImportedSlot]) -> [ImportedSlot] {
        var result: [ImportedSlot] = []
        var indexOfKey: [String: Int] = [:]
        for slot in slots {
            let key = "\(slot.weekday)|\(slot.startMinute)|\(slot.endMinute)|\(fold(slot.title))"
            if let existing = indexOfKey[key] {
                if result[existing].room == nil, slot.room != nil { result[existing].room = slot.room }
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
    }

    struct TimeFound {
        var start: Int
        var end: Int?
        var range: NSRange
    }

    struct Placement {
        var start: Int
        var end: Int?
    }

    struct Analysis {
        var time: TimeFound?
        var title: String
        var room: String?
    }

    struct DayCandidate {
        var day: Int
        var key: String
        var strong: Bool
        var x: CGFloat
        var y: CGFloat
        var bottom: CGFloat
        var line: Int
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
        pattern: #"(?:^|[\s(@,;|-])((?:salle|local|room|raum|aula|sala|stanza|labo|lab|amphi|amphitheatre|amphithéâtre|classe|class|pièce|piece)\.?\s*[:#]?\s*(?:[A-Za-z0-9.\-/]*\d[A-Za-z0-9.\-/]*|(?-i:[A-Z])(?![A-Za-z]))(?:\s\d{1,4}[A-Za-z]?)?)"#,
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

    /// The first time or range of times in the text.
    static func findTime(in text: String) -> TimeFound? {
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

    /// The time when the text holds nothing else (a row label of a grid: "8h", "8h-9h", "8:00 AM").
    static func timeOnly(_ text: String) -> TimeFound? {
        guard let found = findTime(in: text) else { return nil }
        let rest = removing(found.range, from: text)
        if rest.contains(where: { $0.isLetter }) { return nil }
        return found
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
        "intervalo", "cafe", "coffee", "昼休み", "休憩", "昼食"
    ]

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

    static func isTeacher(_ title: String) -> Bool {
        if title.contains("先生") { return true }
        guard let first = words(of: title).first else { return false }
        return teacherWords.contains(first)
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
                return (ns.replacingCharacters(in: match.range(at: 1), with: " "), cleanRoom)
            }
        }
        if let regex = codeRoomRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                guard let room = group(match, 1, in: ns), let letters = group(match, 2, in: ns) else { continue }
                if notRoomCodes.contains(letters.uppercased()) { continue }
                return (ns.replacingCharacters(in: match.range(at: 1), with: " "), room.trimmingCharacters(in: .whitespaces))
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

    /// Time, room and title of a piece of text. Noise (page numbers, "generated on ...") gives nothing.
    static func analyze(_ text: String) -> Analysis {
        var rest = text
        let found = findTime(in: rest)
        if let found = found { rest = removing(found.range, from: rest) }
        if isNoise(rest) { return Analysis(time: nil, title: "", room: nil) }
        let split = extractRoom(from: rest)
        var title = cleanTitle(split.text)
        if isTeacher(title) { title = "" }
        return Analysis(time: found, title: title, room: split.room)
    }

    // MARK: Day names

    static let strongDays: [String: Int] = {
        let table: [(Int, [String])] = [
            (1, ["lun", "lundi", "lunedi", "lunes", "montag", "mon", "monday", "segunda", "seg", "月曜日", "月曜"]),
            (2, ["mar", "mardi", "martedi", "martes", "dienstag", "tue", "tues", "tuesday", "terca", "ter", "火曜日", "火曜"]),
            (3, ["mer", "mercredi", "mercoledi", "miercoles", "mie", "mittwoch", "wed", "weds", "wednesday", "quarta", "qua", "水曜日", "水曜"]),
            (4, ["jeu", "jeudi", "giovedi", "jueves", "jue", "donnerstag", "thu", "thur", "thurs", "thursday", "gio", "quinta", "qui", "木曜日", "木曜"]),
            (5, ["ven", "vendredi", "venerdi", "viernes", "vie", "freitag", "fri", "friday", "sexta", "sex", "金曜日", "金曜"]),
            (6, ["sam", "samedi", "sabato", "sabado", "sab", "samstag", "sonnabend", "sat", "saturday", "土曜日", "土曜"]),
            (7, ["dim", "dimanche", "domenica", "domingo", "dom", "sonntag", "sun", "sunday", "日曜日", "日曜"])
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
            (1, ["mo", "lu", "月"]),
            (2, ["di", "ma", "tu", "火"]),
            (3, ["mi", "me", "we", "水"]),
            (4, ["th", "je", "gi", "ju", "木"]),
            (5, ["fr", "ve", "vi", "金"]),
            (6, ["sa", "土"]),
            (7, ["so", "su", "日"])
        ]
        var map: [String: Int] = [:]
        for (day, names) in table {
            for name in names where map[name] == nil { map[name] = day }
        }
        return map
    }()

    static let cjkDayCharacters: String = "月火水木金土日"

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
        strongDays[normalizedToken(word)]
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
    static func leadingDays(in text: String) -> (days: [Int], rest: String)? {
        let source = text.replacingOccurrences(of: "-feira", with: "", options: .caseInsensitive)
        let tokens = source.split(separator: " ").map { String($0) }
        var days: [Int] = []
        var consumed = 0
        var pendingRange = false
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if let list = gluedDays(token) {
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
        return (unique, rest)
    }

    /// "Lun", "Lun/Mer/Ven", "Lun,", "Lun-Ven" (a range) or "月・水": the days, or nil if a word is not a day.
    static func gluedDays(_ token: String) -> [Int]? {
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
        for part in parts {
            guard let day = strongDay(part) else { return nil }
            found.append(day)
        }
        if found.count == 2, seps.count == 1, seps[0] == "-", found[0] < found[1] {
            return Array(found[0]...found[1])
        }
        return found
    }

    // MARK: Layout: grid with the days as columns

    /// The days written side by side in a line of the page ("Lun Mar Mer" or one line per day at the same height).
    static func dayCandidates(line: RecognizedLine, index: Int) -> [DayCandidate] {
        var text = line.text.replacingOccurrences(of: #"\d{1,2}\s?[月日]"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "-feira", with: "", options: .caseInsensitive)
        let tokens = headerTokens(text)
        guard !tokens.isEmpty, tokens.count <= 8 else { return [] }
        var found: [DayCandidate] = []
        func candidate(_ day: Int, _ key: String, _ strong: Bool, _ fraction: Double) -> DayCandidate {
            DayCandidate(day: day, key: key, strong: strong, x: line.box.minX + CGFloat(fraction) * line.box.width,
                         y: line.box.midY, bottom: line.box.maxY, line: index)
        }
        for token in tokens {
            let key = normalizedToken(token.token)
            let middle = (token.from + token.to) / 2
            if let day = strongDays[key] {
                found.append(candidate(day, key, true, middle))
            } else if key == "do" {
                found.append(candidate(7, key, false, middle))
            } else if let day = weakDays[key] {
                found.append(candidate(day, key, false, middle))
            } else if key.count >= 2, key.allSatisfy({ cjkDayCharacters.contains($0) }) {
                let characters = Array(key)
                for (position, character) in characters.enumerated() {
                    guard let day = weakDays[String(character)] else { return [] }
                    let fraction = token.from + (token.to - token.from) * (Double(position) + 0.5) / Double(characters.count)
                    found.append(candidate(day, String(character), false, fraction))
                }
            } else {
                return []
            }
        }
        return found
    }

    /// The row of day names that heads the columns, if the page is a grid.
    static func detectGrid(in lines: [RecognizedLine]) -> Grid? {
        var all: [DayCandidate] = []
        for (index, line) in lines.enumerated() {
            all.append(contentsOf: dayCandidates(line: line, index: index))
        }
        guard all.count >= 2 else { return nil }
        all.sort { $0.y < $1.y }
        var groups: [[DayCandidate]] = []
        for candidate in all {
            if let first = groups.last?.first, abs(candidate.y - first.y) <= 0.025 {
                groups[groups.count - 1].append(candidate)
            } else {
                groups.append([candidate])
            }
        }
        var best: Grid? = nil
        for group in groups where group.count >= 2 {
            // "Do" is Thursday in German, Sunday in the other languages.
            let german = group.contains { germanOnlyKeys.contains($0.key) }
            var members = group.map { candidate -> DayCandidate in
                var copy = candidate
                if copy.key == "do", german { copy.day = 4 }
                return copy
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
            if let current = best, current.headers.count >= kept.count { continue }
            best = Grid(headers: kept,
                        lineIndexes: Set(group.map { $0.line }),
                        bandBottom: group.map { $0.bottom }.max() ?? 0)
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
                if let draft = blockDraft(block, weekday: headers[column].day, axis: axis) {
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
        var titles: [String] = []
        for line in lines {
            let info = analyze(line.text)
            if time == nil { time = info.time }
            if room == nil { room = info.room }
            if !info.title.isEmpty { titles.append(info.title) }
        }
        let title = titles.prefix(2).joined(separator: " ")
        guard !title.isEmpty else { return nil }
        if let time = time {
            return Draft(weekday: weekday, start: time.start, end: time.end, title: title, room: room)
        }
        let top = lines.map { $0.box.minY }.min() ?? 0
        let bottom = lines.map { $0.box.maxY }.max() ?? top
        guard let placed = axis.lookup(top: top, center: (top + bottom) / 2) else { return nil }
        return Draft(weekday: weekday, start: placed.start, end: placed.end, title: title, room: room)
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
                if let minute = ScheduleParser.clockMinute(line.text) { labels.append((y: line.box.midY, minute: minute)) }
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
    }

    /// Offsets (0...1 of the page width) from the left edge of a column where the probe looks: inside the cell but
    /// left of the centred text.
    static let probeOffsets: [Double] = [0.003, 0.005]

    /// "08:10", "8h10": a clock time and nothing else.
    static let clockRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^(\d{1,2})\s?[:hH]\s?(\d{2})$"#, options: [])

    static func clockMinute(_ text: String) -> Int? {
        guard let regex = clockRegex else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              let hour = Int(group(match, 1, in: ns) ?? ""), let minute = Int(group(match, 2, in: ns) ?? ""),
              hour < 24, minute < 60 else { return nil }
        return hour * 60 + minute
    }

    /// "410-343-CH", "203-NYB-05": the code of a course, as written in a block and in the list of courses.
    static let courseCodeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![A-Za-z0-9])\d{3}-[A-Za-z0-9]{3}-[A-Za-z0-9]{2}(?![0-9])"#, options: [])

    /// The first course code of a text, with what comes before and after it.
    static func courseCode(in text: String) -> (code: String, before: String, after: String)? {
        guard let regex = courseCodeRegex else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        let end = match.range.location + match.range.length
        return (ns.substring(with: match.range).uppercased(), ns.substring(to: match.range.location), ns.substring(from: end))
    }

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
        let room = roomIndex.map { texts[$0].trimmingCharacters(in: .whitespaces) }
        return BlockContent(title: parts.joined(separator: " "), room: room, code: code)
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

    /// The stretches that the probe agrees on along the left edge of a column, or nil when it cannot tell.
    static func columnRuns(_ probe: BlockProbe, left: CGFloat, from: Double, to: Double) -> [ClosedRange<Double>]? {
        var common: [ClosedRange<Double>]? = nil
        for offset in probeOffsets {
            let x = Double(left) + offset
            guard x >= 0, x < 1, let runs = probe.blockRuns(atX: x, fromY: from, toY: to) else { continue }
            if let known = common {
                common = intersection(known, runs)
            } else {
                common = runs
            }
        }
        guard let result = common else { return nil }
        // A letter of the text can cut a run on one of the lines: small holes are closed.
        var merged: [ClosedRange<Double>] = []
        for run in result.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, run.lowerBound - last.upperBound <= 0.003 {
                merged[merged.count - 1] = last.lowerBound...max(last.upperBound, run.upperBound)
            } else {
                merged.append(run)
            }
        }
        return merged
    }

    static func intersection(_ a: [ClosedRange<Double>], _ b: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        var result: [ClosedRange<Double>] = []
        for first in a {
            for second in b {
                let low = max(first.lowerBound, second.lowerBound)
                let high = min(first.upperBound, second.upperBound)
                if low <= high { result.append(low...high) }
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
            let runs = probe.flatMap { columnRuns($0, left: edges[column], from: fromY, to: toY) }
            for (index, cluster) in clusters.enumerated() {
                guard let content = blockContent(cluster.lines) else { continue }
                let span = blockRows(clusters, index, runs: runs, timeline: timeline)
                let title = fullTitle(content.title, code: content.code, catalog: catalog)
                guard !title.isEmpty else { continue }
                drafts.append(Draft(weekday: headers[column].day, start: timeline.rows[span.first].start,
                                    end: timeline.rows[span.last].end, title: title, room: content.room))
            }
        }
        return drafts
    }

    /// The rows covered by the block of a cluster: from the colours when the probe sees the block, else from the
    /// place of the text.
    static func blockRows(_ clusters: [TextCluster], _ index: Int, runs: [ClosedRange<Double>]?,
                          timeline: Timeline) -> (first: Int, last: Int) {
        let cluster = clusters[index]
        if let runs = runs, let found = runs.first(where: { $0.contains(Double(cluster.center)) }) {
            // Two blocks stuck together make one stretch: cut halfway between their texts.
            func sameRun(_ k: Int) -> Bool {
                clusters.indices.contains(k) && found.contains(Double(clusters[k].center))
            }
            let top = sameRun(index - 1) ? (clusters[index - 1].bottom + cluster.top) / 2 : CGFloat(found.lowerBound)
            let bottom = sameRun(index + 1) ? (cluster.bottom + clusters[index + 1].top) / 2 : CGFloat(found.upperBound)
            let snapped = timeline.snap(top: top, bottom: bottom)
            if snapped.last - snapped.first < Timeline.maxSpan { return snapped }
        }
        return timeline.fit(top: cluster.top, bottom: cluster.bottom)
            ?? timeline.snap(top: cluster.top, bottom: cluster.bottom)
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

        func startDay(_ newDays: [Int]) {
            days = newDays
            pendingTitle = nil
            pendingRoom = nil
            recent = []
            awaiting = false
        }

        for row in readingRows(lines) {
            var text = row
            if let lead = leadingDays(in: text) {
                let hasTime = analyze(lead.rest).time != nil
                if hasTime || isDateish(lead.rest) {
                    startDay(lead.days)
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
                recent = []
                for day in days {
                    recent.append(drafts.count)
                    drafts.append(Draft(weekday: day, start: time.start, end: time.end, title: title, room: room))
                }
                awaiting = title.isEmpty
                pendingTitle = nil
                pendingRoom = nil
            } else if awaiting, !info.title.isEmpty {
                for index in recent where index < drafts.count {
                    drafts[index].title = info.title
                    if drafts[index].room == nil { drafts[index].room = info.room }
                }
                awaiting = false
            } else if info.title.isEmpty {
                if let room = info.room {
                    for index in recent where index < drafts.count && drafts[index].room == nil {
                        drafts[index].room = room
                    }
                }
            } else {
                pendingTitle = info.title
                pendingRoom = info.room
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
        var slots: [ImportedSlot] = []
        for draft in drafts {
            guard (1...7).contains(draft.weekday), (0..<1440).contains(draft.start) else { continue }
            let title = cleanTitle(draft.title)
            guard !title.isEmpty, !isBreak(title) else { continue }
            let end = min(draft.end ?? (draft.start + usual), 1440)
            guard end > draft.start else { continue }
            slots.append(ImportedSlot(weekday: draft.weekday, startMinute: draft.start, endMinute: end,
                                      title: title, room: draft.room))
        }
        return deduplicated(slots)
    }
}
