import Foundation

/// A date as written in a line of text, before the year and the order of its numbers are settled.
struct WrittenDate: Equatable {
    var year: Int?
    var month: Int
    var day: Int
    /// Two numbers that could each be the day or the month ("03/04/2026"): the order is a guess.
    var swappable = false
    /// Where the date is in the text (UTF-16), to take it out before the hours and the name are read.
    var range: NSRange
}

/// A date settled to a day of the calendar, with what is in doubt about it.
struct SettledDate: Equatable {
    /// Midnight of the day, in the time zone of the device.
    var date: Date
    /// ISO weekday of the date (1 = Monday ... 7 = Sunday).
    var weekday: Int
    /// The date is a guess the person checks: no year written and no day name to settle it, day and month that could be
    /// swapped with nothing to tell which order, or a day name that matches no reading (`weekdayConflict`). A missing year
    /// or a swappable order settled by the day name written next to the date is not in doubt.
    var uncertain: Bool
    /// The day name written next to the date is another day ("Mardi 18 novembre 2026" is a Wednesday): both are in doubt.
    var weekdayConflict: Bool
}

/// Dates written in the six languages of the app and in Japanese: "Mardi 24 novembre 2026", "24 de noviembre de 2026",
/// "Nov 24, 2026", "24. November", "2026-11-24", "24/11/2026", "11/24/2026", "2026年11月24日". Pure (no Vision, no UIKit).
/// Nothing is invented: a date read without its year, or whose day and month could be swapped, comes back `uncertain`.
enum ScheduleDates {

    // MARK: Month names

    /// Month names and their short forms, folded (lowercase, no accents), in French, English, Spanish, German, Italian
    /// and Portuguese.
    static let months: [String: Int] = {
        let table: [(Int, [String])] = [
            (1, ["janvier", "janv", "jan", "january", "enero", "ene", "januar", "janner", "jaenner", "gennaio", "gen", "janeiro"]),
            (2, ["fevrier", "fevr", "fev", "february", "feb", "febrero", "februar", "febbraio", "fevereiro"]),
            (3, ["mars", "march", "mar", "marzo", "marz", "maerz", "marco"]),
            (4, ["avril", "avr", "april", "apr", "abril", "abr", "aprile"]),
            (5, ["mai", "may", "mayo", "maggio", "mag", "maio"]),
            (6, ["juin", "june", "jun", "junio", "juni", "giugno", "giu", "junho"]),
            (7, ["juillet", "juil", "july", "jul", "julio", "juli", "luglio", "lug", "julho"]),
            (8, ["aout", "august", "aug", "agosto", "ago"]),
            (9, ["septembre", "sept", "sep", "september", "septiembre", "settembre", "set", "setembro"]),
            (10, ["octobre", "oct", "october", "octubre", "oktober", "okt", "ottobre", "ott", "outubro", "out"]),
            (11, ["novembre", "nov", "november", "noviembre", "novembro"]),
            (12, ["decembre", "dec", "december", "diciembre", "dic", "dezember", "dez", "dicembre", "dezembro"])
        ]
        var map: [String: Int] = [:]
        for (month, names) in table {
            for name in names where map[name] == nil { map[name] = month }
        }
        return map
    }()

    /// Short forms that are also common words or day names ("mar" is Tuesday in French, "out" and "set" are English words):
    /// before a number ("Mar 18") they are not trusted; after one ("18 mar.") they are.
    static let weakMonthWords: Set<String> = ["mar", "may", "out", "set", "ago", "gen", "mag", "dic", "giu", "lug", "ott"]

    /// A letter of a month name with its accented forms, so that the pattern finds "août", "décembre", "März" in the text as
    /// written (the positions found are then the ones of the text itself).
    private static func accented(_ word: String) -> String {
        var pattern = ""
        for character in word {
            switch character {
            case "a": pattern += "[aàâäã]"
            case "e": pattern += "[eéèêë]"
            case "i": pattern += "[iìíîï]"
            case "o": pattern += "[oòóôöõ]"
            case "u": pattern += "[uùúûü]"
            case "c": pattern += "[cç]"
            default: pattern += String(character)
            }
        }
        return pattern
    }

    /// The month names as one alternation, longest first ("[aàâ]...|..."), accents allowed. "marz" also takes "märz";
    /// "maerz" is left as written.
    private static func monthAlternation(_ words: [String]) -> String {
        words.sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }.map { accented($0) }.joined(separator: "|")
    }

    // MARK: Patterns

    /// "2026-11-24", "2026/11/24", "2026.11.24". Groups: 1 year, 2 month, 3 day.
    static let isoRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\d])(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?![\d])"#, options: [])

    /// "2026年11月24日", "11月24日". Groups: 1 year (optional), 2 month, 3 day.
    static let japaneseRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:(\d{4})\s?年\s?)?(\d{1,2})\s?月\s?(\d{1,2})\s?日"#, options: [])

    /// "24/11/2026", "24.11.2026", "11/24/26". Groups: 1 first number, 2 second number, 3 year (two or four digits).
    static let numericRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\d/.:,])(\d{1,2})[/.](\d{1,2})[/.](\d{4}|\d{2})(?![\d/.:])"#, options: [])

    /// "24/11" without a year (a slash only: "14.30" is an hour). Groups: 1 first number, 2 second number.
    static let shortNumericRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![\d/.:,])(\d{1,2})/(\d{1,2})(?![\d/])"#, options: [])

    /// "24 novembre 2026", "1er mars", "24 de noviembre de 2026", "24. November", "18 Nov". Groups: 1 day, 2 month, 3 year.
    static let dayMonthRegex: NSRegularExpression? = {
        let names = monthAlternation(Array(months.keys))
        let pattern = #"(?<![\d\p{L}])(\d{1,2})(?:er|re|st|nd|rd|th|º|°|\.)?\s*(?:de\s+|of\s+)?("# + names
            + #")\.?(?![\p{L}])(?:,?\s*(?:de\s+)?(\d{4})(?![\d:]))?"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// "November 24, 2026", "Nov 24", "Nov. 24th". Groups: 1 month, 2 day, 3 year.
    static let monthDayRegex: NSRegularExpression? = {
        let names = monthAlternation(Array(months.keys))
        let pattern = #"(?<![\p{L}])("# + names + #")\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?![\d:.hH])(?:,?\s*(\d{4})(?![\d:]))?"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// A month name standing alone in a word (to tell "a date was written but its day is unreadable").
    static let monthWordRegex: NSRegularExpression? = {
        let strong = months.keys.filter { $0.count >= 4 && !weakMonthWords.contains($0) }
        let pattern = #"(?<![\p{L}])("# + monthAlternation(Array(strong)) + #")(?![\p{L}])"#
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    // MARK: Reading

    /// The month a word names (folded, without its full stop), or nil.
    static func monthNumber(_ word: String) -> Int? {
        let key = ScheduleParser.fold(word).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return months[key]
    }

    private static func number(_ match: NSTextCheckingResult, _ index: Int, in ns: NSString) -> Int? {
        ScheduleParser.group(match, index, in: ns).flatMap { Int($0) }
    }

    private static func fullYear(_ value: Int) -> Int {
        value < 100 ? 2000 + value : value
    }

    /// The first date written in the text. `monthFirst` reads "03/04/2026" as March 4 (an English page, with AM/PM);
    /// otherwise as 3 April. Either way the reading is `swappable` and the person checks it.
    static func find(in text: String, monthFirst: Bool = false) -> WrittenDate? {
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let regex = isoRegex, let match = regex.firstMatch(in: text, options: [], range: full),
           let year = number(match, 1, in: ns), let month = number(match, 2, in: ns), let day = number(match, 3, in: ns),
           (1...12).contains(month), (1...31).contains(day) {
            return WrittenDate(year: year, month: month, day: day, range: match.range)
        }
        if let regex = japaneseRegex, let match = regex.firstMatch(in: text, options: [], range: full),
           let month = number(match, 2, in: ns), let day = number(match, 3, in: ns), (1...12).contains(month), (1...31).contains(day) {
            return WrittenDate(year: number(match, 1, in: ns), month: month, day: day, range: match.range)
        }
        if let regex = dayMonthRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                guard let day = number(match, 1, in: ns), (1...31).contains(day),
                      let word = ScheduleParser.group(match, 2, in: ns), let month = monthNumber(word) else { continue }
                return WrittenDate(year: number(match, 3, in: ns), month: month, day: day, range: match.range)
            }
        }
        if let regex = monthDayRegex {
            for match in regex.matches(in: text, options: [], range: full) {
                guard let word = ScheduleParser.group(match, 1, in: ns), let month = monthNumber(word),
                      let day = number(match, 2, in: ns), (1...31).contains(day) else { continue }
                let year = number(match, 3, in: ns)
                // "Mar 18" may be Tuesday the 18th (French): a weak month word before a number needs a year after it.
                if weakMonthWords.contains(ScheduleParser.fold(word)), year == nil { continue }
                return WrittenDate(year: year, month: month, day: day, range: match.range)
            }
        }
        for regex in [numericRegex, shortNumericRegex] {
            guard let regex = regex else { continue }
            for match in regex.matches(in: text, options: [], range: full) {
                guard let first = number(match, 1, in: ns), let second = number(match, 2, in: ns) else { continue }
                let year = number(match, 3, in: ns).map(fullYear)
                var day = first
                var month = second
                if first > 12, second <= 12 {
                    day = first; month = second
                } else if second > 12, first <= 12 {
                    day = second; month = first
                } else if first <= 12, second <= 12 {
                    if monthFirst { day = second; month = first }
                } else {
                    continue
                }
                guard (1...12).contains(month), (1...31).contains(day) else { continue }
                let swappable = first <= 12 && second <= 12 && first != second
                return WrittenDate(year: year, month: month, day: day, swappable: swappable, range: match.range)
            }
        }
        return nil
    }

    /// Whether the text names a month without any readable date ("Mardi ?? novembre"): a date was written, but cannot be read.
    static func mentionsMonth(_ text: String) -> Bool {
        guard let regex = monthWordRegex else { return false }
        return regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    // MARK: Calendar

    /// The Gregorian calendar in the time zone of the device (the dates are days of the person's calendar).
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        return calendar
    }

    /// ISO weekday (1 = Monday ... 7 = Sunday).
    static func isoWeekday(_ date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    /// Midnight of the day, or nil when the day does not exist (30 February).
    static func day(year: Int, month: Int, day: Int) -> Date? {
        let calendar = self.calendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard parts.year == year, parts.month == month, parts.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// The day the written date stands for. The year, when missing, is the one that agrees with the day name written next to
    /// it, else the next time that day comes (up to two months back); the day and the month of "03/04" are swapped when only
    /// the other order agrees with the day name. Anything guessed is `uncertain`; a day name that agrees with no reading is a
    /// `weekdayConflict` (the date as written is kept). nil when no reading is a real day.
    static func settle(_ written: WrittenDate, weekday: Int?, reference: Date) -> SettledDate? {
        let calendar = self.calendar
        let thisYear = calendar.component(.year, from: reference)
        let orders: [(month: Int, day: Int)] = written.swappable
            ? [(written.month, written.day), (written.day, written.month)]
            : [(written.month, written.day)]
        let years = written.year.map { [$0] } ?? [thisYear - 1, thisYear, thisYear + 1]
        var readings: [(date: Date, order: Int)] = []
        for (index, order) in orders.enumerated() {
            for year in years {
                if let date = day(year: year, month: order.month, day: order.day) { readings.append((date, index)) }
            }
        }
        guard !readings.isEmpty else { return nil }
        let today = calendar.startOfDay(for: reference)
        func nearest(_ list: [(date: Date, order: Int)]) -> (date: Date, order: Int) {
            var best = list[0]
            for item in list.dropFirst() where abs(item.date.timeIntervalSince(today)) < abs(best.date.timeIntervalSince(today)) {
                best = item
            }
            return best
        }
        if let named = weekday {
            let agreeing = readings.filter { isoWeekday($0.date) == named }
            if !agreeing.isEmpty {
                let chosen = nearest(agreeing)
                // Two readings that both agree (rare): the one kept is a guess.
                let doubt = Set(agreeing.map { $0.order }).count > 1
                return SettledDate(date: chosen.date, weekday: named, uncertain: doubt, weekdayConflict: false)
            }
        }
        // No day name, or one that agrees with nothing: the first order as written.
        let firstOrder = readings.filter { $0.order == 0 }
        let pool = firstOrder.isEmpty ? readings : firstOrder
        var chosen = pool[0].date
        if written.year == nil {
            // The next time the day comes, counting up to two months back (a list of the term that just started).
            let earliest = calendar.date(byAdding: .day, value: -60, to: today) ?? today
            let upcoming = pool.map { $0.date }.filter { $0 >= earliest }.sorted()
            chosen = upcoming.first ?? pool.map { $0.date }.max() ?? chosen
        }
        let conflict = weekday != nil
        let guessed = written.year == nil || written.swappable || firstOrder.isEmpty
        return SettledDate(date: chosen, weekday: isoWeekday(chosen), uncertain: guessed || conflict, weekdayConflict: conflict)
    }
}
