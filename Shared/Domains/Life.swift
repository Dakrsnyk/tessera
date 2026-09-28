import Foundation

enum HolidayRegion: String, Codable, CaseIterable, Identifiable {
    case quebec, canada, france, unitedStates
    var id: String { rawValue }

    var title: String {
        switch self {
        case .quebec: "Québec"
        case .canada: "Canada (fédéral)"
        case .france: "France"
        case .unitedStates: "États-Unis"
        }
    }
}

/// Personal details used by the "Ma vie" widgets. Everything stays on the device.
struct LifeState: Codable, Hashable {
    var birthday: Date?
    var holidayRegion: HolidayRegion = .quebec
    /// Expected lifespan used by the optional "vie en semaines" view.
    var lifeExpectancy: Int = 85

    enum CodingKeys: String, CodingKey { case birthday, holidayRegion, lifeExpectancy }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        birthday = c.optional(.birthday)
        holidayRegion = c.value(.holidayRegion, .quebec)
        lifeExpectancy = c.value(.lifeExpectancy, 85)
    }
}

enum LifeMath {
    /// Age in years with decimals, e.g. 27.43.
    static func age(birthday: Date, at date: Date) -> Double {
        let cal = DateMath.calendar
        let years = cal.dateComponents([.year], from: birthday, to: date).year ?? 0
        guard let last = cal.date(byAdding: .year, value: years, to: birthday),
              let next = cal.date(byAdding: .year, value: years + 1, to: birthday) else { return Double(years) }
        let fraction = date.timeIntervalSince(last) / max(1, next.timeIntervalSince(last))
        return Double(years) + min(1, max(0, fraction))
    }

    /// The next birthday on or after today, and the age it celebrates.
    static func nextBirthday(birthday: Date, after date: Date) -> (date: Date, age: Int) {
        let cal = DateMath.calendar
        let today = DateMath.startOfDay(date)
        let years = cal.dateComponents([.year], from: birthday, to: today).year ?? 0
        for offset in 0...2 {
            if let candidate = cal.date(byAdding: .year, value: years + offset, to: birthday) {
                let day = DateMath.startOfDay(candidate)
                if day >= today { return (day, years + offset) }
            }
        }
        return (today, years)
    }
}

struct Holiday: Hashable {
    let name: String
    let date: Date
}

enum Holidays {
    /// Easter Sunday (Gregorian computus).
    static func easter(_ year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return make(year, month, day)
    }

    static func make(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private static func shift(_ date: Date, _ days: Int) -> Date {
        DateMath.calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// The `nth` given weekday (1 = dimanche … 7 = samedi, Gregorian numbering) of a month; nth = -1 for the last one.
    static func nthWeekday(_ nth: Int, weekday: Int, month: Int, year: Int) -> Date {
        let cal = DateMath.calendar
        if nth > 0 {
            var date = make(year, month, 1)
            while cal.component(.weekday, from: date) != weekday { date = shift(date, 1) }
            return shift(date, 7 * (nth - 1))
        }
        let firstNext = month == 12 ? make(year + 1, 1, 1) : make(year, month + 1, 1)
        var date = shift(firstNext, -1)
        while cal.component(.weekday, from: date) != weekday { date = shift(date, -1) }
        return date
    }

    /// The Monday before May 25 (Journée nationale des patriotes / Victoria Day).
    static func mondayBeforeMay25(_ year: Int) -> Date {
        var date = make(year, 5, 24)
        while DateMath.calendar.component(.weekday, from: date) != 2 { date = shift(date, -1) }
        return date
    }

    static func list(_ region: HolidayRegion, year: Int) -> [Holiday] {
        let easter = Self.easter(year)
        var days: [Holiday]
        switch region {
        case .quebec:
            days = [
                Holiday(name: "Jour de l'An", date: make(year, 1, 1)),
                Holiday(name: "Vendredi saint", date: shift(easter, -2)),
                Holiday(name: "Lundi de Pâques", date: shift(easter, 1)),
                Holiday(name: "Journée nationale des patriotes", date: mondayBeforeMay25(year)),
                Holiday(name: "Fête nationale du Québec", date: make(year, 6, 24)),
                Holiday(name: "Fête du Canada", date: make(year, 7, 1)),
                Holiday(name: "Fête du Travail", date: nthWeekday(1, weekday: 2, month: 9, year: year)),
                Holiday(name: "Action de grâce", date: nthWeekday(2, weekday: 2, month: 10, year: year)),
                Holiday(name: "Noël", date: make(year, 12, 25)),
            ]
        case .canada:
            days = [
                Holiday(name: "Jour de l'An", date: make(year, 1, 1)),
                Holiday(name: "Vendredi saint", date: shift(easter, -2)),
                Holiday(name: "Lundi de Pâques", date: shift(easter, 1)),
                Holiday(name: "Fête de la Reine / Victoria", date: mondayBeforeMay25(year)),
                Holiday(name: "Fête du Canada", date: make(year, 7, 1)),
                Holiday(name: "Congé civique", date: nthWeekday(1, weekday: 2, month: 8, year: year)),
                Holiday(name: "Fête du Travail", date: nthWeekday(1, weekday: 2, month: 9, year: year)),
                Holiday(name: "Vérité et réconciliation", date: make(year, 9, 30)),
                Holiday(name: "Action de grâce", date: nthWeekday(2, weekday: 2, month: 10, year: year)),
                Holiday(name: "Jour du Souvenir", date: make(year, 11, 11)),
                Holiday(name: "Noël", date: make(year, 12, 25)),
                Holiday(name: "Lendemain de Noël", date: make(year, 12, 26)),
            ]
        case .france:
            days = [
                Holiday(name: "Jour de l'An", date: make(year, 1, 1)),
                Holiday(name: "Lundi de Pâques", date: shift(easter, 1)),
                Holiday(name: "Fête du Travail", date: make(year, 5, 1)),
                Holiday(name: "Victoire 1945", date: make(year, 5, 8)),
                Holiday(name: "Ascension", date: shift(easter, 39)),
                Holiday(name: "Lundi de Pentecôte", date: shift(easter, 50)),
                Holiday(name: "Fête nationale", date: make(year, 7, 14)),
                Holiday(name: "Assomption", date: make(year, 8, 15)),
                Holiday(name: "Toussaint", date: make(year, 11, 1)),
                Holiday(name: "Armistice 1918", date: make(year, 11, 11)),
                Holiday(name: "Noël", date: make(year, 12, 25)),
            ]
        case .unitedStates:
            days = [
                Holiday(name: "New Year's Day", date: make(year, 1, 1)),
                Holiday(name: "Martin Luther King Jr. Day", date: nthWeekday(3, weekday: 2, month: 1, year: year)),
                Holiday(name: "Presidents' Day", date: nthWeekday(3, weekday: 2, month: 2, year: year)),
                Holiday(name: "Memorial Day", date: nthWeekday(-1, weekday: 2, month: 5, year: year)),
                Holiday(name: "Juneteenth", date: make(year, 6, 19)),
                Holiday(name: "Independence Day", date: make(year, 7, 4)),
                Holiday(name: "Labor Day", date: nthWeekday(1, weekday: 2, month: 9, year: year)),
                Holiday(name: "Columbus Day", date: nthWeekday(2, weekday: 2, month: 10, year: year)),
                Holiday(name: "Veterans Day", date: make(year, 11, 11)),
                Holiday(name: "Thanksgiving", date: nthWeekday(4, weekday: 5, month: 11, year: year)),
                Holiday(name: "Christmas Day", date: make(year, 12, 25)),
            ]
        }
        days.sort { $0.date < $1.date }
        return days
    }

    /// Upcoming holidays from today (included), across the year boundary.
    static func upcoming(_ region: HolidayRegion, from date: Date, count: Int = 3) -> [Holiday] {
        let year = DateMath.calendar.component(.year, from: date)
        let today = DateMath.startOfDay(date)
        let all = list(region, year: year) + list(region, year: year + 1)
        return Array(all.filter { $0.date >= today }.prefix(count))
    }
}

/// Moon phase from the mean synodic month, accurate to about a day, which is enough for a widget.
enum MoonPhase {
    static let synodicMonth = 29.530588853
    /// A known new moon: 6 January 2000, 18:14 UTC.
    static let reference = Date(timeIntervalSince1970: 947_182_440)

    /// 0 = new moon, 0.5 = full moon, back to 1.
    static func phase(at date: Date) -> Double {
        let days = date.timeIntervalSince(reference) / 86_400
        let cycles = days / synodicMonth
        let fraction = cycles - cycles.rounded(.down)
        return fraction < 0 ? fraction + 1 : fraction
    }

    /// Lit fraction of the disc, 0 to 1.
    static func illumination(at date: Date) -> Double {
        (1 - cos(2 * Double.pi * phase(at: date))) / 2
    }

    private static func index(_ phase: Double) -> Int {
        Int((phase * 8).rounded()) % 8
    }

    static func name(at date: Date) -> String {
        ["Nouvelle lune", "Premier croissant", "Premier quartier", "Lune gibbeuse croissante",
         "Pleine lune", "Lune gibbeuse décroissante", "Dernier quartier", "Dernier croissant"][index(phase(at: date))]
    }

    static func symbol(at date: Date) -> String {
        ["moonphase.new.moon", "moonphase.waxing.crescent", "moonphase.first.quarter", "moonphase.waxing.gibbous",
         "moonphase.full.moon", "moonphase.waning.gibbous", "moonphase.last.quarter", "moonphase.waning.crescent"][index(phase(at: date))]
    }

    /// Next moment the phase reaches `target` (0.5 for the full moon, 0 for the new moon).
    static func next(_ target: Double, after date: Date) -> Date {
        let current = phase(at: date)
        var delta = target - current
        if delta <= 0.001 { delta += 1 }
        return date.addingTimeInterval(delta * synodicMonth * 86_400)
    }
}
