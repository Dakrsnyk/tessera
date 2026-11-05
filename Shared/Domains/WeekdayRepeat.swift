import Foundation

/// The rules of an event repeated on chosen days of the week: pure functions, no stored state. Days are
/// ISO weekdays (1 = lundi … 7 = dimanche), like `ClassSlot.weekday`. An event with no extra day keeps
/// its single weekday (or its date): data saved before the choice of days reads exactly as before.
enum WeekdayRepeat {
    /// The days of the week in display order, starting at `firstWeekday` (Calendar numbering: 1 = Sunday,
    /// 2 = Monday). The app calendar starts on Monday.
    static func ordered(firstWeekday: Int = DateMath.calendar.firstWeekday) -> [Int] {
        let first = ((firstWeekday - 1 + 7) % 7) + 1          // 1…7, Sunday = 1
        let iso = first == 1 ? 7 : first - 1
        return (0..<7).map { (iso - 1 + $0) % 7 + 1 }
    }

    /// The days without doubles or out-of-range values, sorted Monday to Sunday.
    static func normalized(_ days: some Sequence<Int>) -> [Int] {
        Array(Set(days.filter { (1...7).contains($0) })).sorted()
    }

    /// Whether an event whose days are `weekdays` takes place on that date (calendar day, so a change of
    /// time never moves it: only the weekday of the date counts).
    static func occurs(on day: Date, weekdays: some Sequence<Int>) -> Bool {
        weekdays.contains(FitnessMath.isoWeekday(day))
    }

    /// The first letter of each weekday in the language of the app (Monday = 1).
    static func initial(of weekday: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Fmt.locale
        let symbols = cal.veryShortStandaloneWeekdaySymbols      // Sunday first
        guard (1...7).contains(weekday), symbols.count == 7 else { return "" }
        return symbols[weekday % 7]
    }

    /// The full name of a weekday (« lundi »), for accessibility.
    static func name(of weekday: Int) -> String {
        switch weekday {
        case 1: tr("Lundi")
        case 2: tr("Mardi")
        case 3: tr("Mercredi")
        case 4: tr("Jeudi")
        case 5: tr("Vendredi")
        case 6: tr("Samedi")
        default: tr("Dimanche")
        }
    }

    /// The day after « Tous les » (« lundis »), the form each language needs after « Every ».
    private static func each(_ weekday: Int) -> String {
        switch weekday {
        case 1: tr("lundis", context: "each")
        case 2: tr("mardis", context: "each")
        case 3: tr("mercredis", context: "each")
        case 4: tr("jeudis", context: "each")
        case 5: tr("vendredis", context: "each")
        case 6: tr("samedis", context: "each")
        default: tr("dimanches", context: "each")
        }
    }

    /// « Une seule fois », « Tous les lundis et mercredis », « Tous les jours ».
    static func summary(_ days: some Sequence<Int>) -> String {
        let list = normalized(days)
        if list.isEmpty { return tr("Une seule fois") }
        if list.count == 7 { return tr("Tous les jours") }
        let formatter = ListFormatter()
        formatter.locale = Fmt.locale
        let names = formatter.string(from: list.map(each)) ?? list.map(each).joined(separator: ", ")
        return tr("Tous les \(names)")
    }
}
