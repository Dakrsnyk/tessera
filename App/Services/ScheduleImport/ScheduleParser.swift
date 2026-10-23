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

    /// The classes found on ONE page. Never fails: unreadable input gives an empty list.
    static func slots(from lines: [RecognizedLine]) -> [ImportedSlot] {
        var cleaned: [RecognizedLine] = []
        for line in lines {
            if let kept = cleanedLine(line) { cleaned.append(kept) }
        }
        guard !cleaned.isEmpty else { return [] }
        var drafts: [Draft] = []
        if let grid = detectGrid(in: cleaned) {
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

    static let markerPattern = #"(\s?(?:[hH](?![A-Za-z])|[:時])\s?(\d{2})?|\s?Uhr\b)"#
    static let meridiemPattern = #"(?:\s?([aApP])\.?[mM]\.?(?![A-Za-z]))"#

    /// "8h30-10h", "08:30 - 10:00", "8:30 AM to 10 PM", "8-10 Uhr". Groups: 1 hour, 2 marker, 3 minutes,
    /// 4 am/pm of the start, then 5 to 8 the same for the end.
    static let rangeRegex: NSRegularExpression? = {
        let unit1 = #"(\d{1,2})"# + markerPattern + "?" + meridiemPattern + "?"
        let unit2 = #"(\d{1,2})"# + markerPattern + "?" + meridiemPattern + "?"
        let separator = #"(?:\s*(?:[-~→〜]|から)\s*|\s+(?:to|a|à|au|al|bis|até|ate|until|till)\s+)"#
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
        pattern: #"(?:^|[\s(@,;|-])((?:salle|local|room|raum|aula|sala|stanza|labo|lab|amphi|amphitheatre|amphithéâtre|classe|class|pièce|piece)\.?\s*[:#]?\s*(?:(?-i:[A-Z])(?![A-Za-z])|[A-Za-z0-9.\-/]*\d[A-Za-z0-9.\-/]*)(?:\s\d{1,4}[A-Za-z]?)?)"#,
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
