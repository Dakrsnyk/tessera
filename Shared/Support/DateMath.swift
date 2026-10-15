import Foundation

enum DateMath {
    static var calendar: Calendar { Fmt.calendar }

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = Fmt.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Stable identifier for a calendar day, used for habit and hydration logs.
    static func dayKey(_ date: Date) -> String {
        keyFormatter.timeZone = Fmt.timeZone
        return keyFormatter.string(from: date)
    }

    /// The day of a key made by `dayKey` (its start, in the iPhone's time zone).
    static func date(fromKey key: String) -> Date? {
        keyFormatter.timeZone = Fmt.timeZone
        return keyFormatter.date(from: key).map(startOfDay)
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// A time of a day, as the clock shows it (minutes after midnight, 24:00 being the next midnight):
    /// the same reading on the days the clocks change, in the iPhone's time zone. A time the clocks
    /// skip (2:30 when they go forward) becomes the next one that exists.
    static func date(on day: Date, minute: Int, calendar: Calendar = DateMath.calendar) -> Date {
        let start = calendar.startOfDay(for: day)
        let clamped = max(0, minute)
        if clamped >= 24 * 60 {
            let midnight = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            return calendar.date(byAdding: .minute, value: clamped - 24 * 60, to: midnight) ?? midnight
        }
        return calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: start)
            ?? start.addingTimeInterval(TimeInterval(clamped) * 60)
    }

    /// The minutes after midnight a date shows on the clock (the reverse of `date(on:minute:)`).
    static func minuteOfDay(_ date: Date, calendar: Calendar = DateMath.calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func nextMidnight(after date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: startOfDay(date)) ?? date.addingTimeInterval(86_400)
    }

    /// Whole calendar days from `from` to `to` (negative when `to` is earlier).
    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day ?? 0
    }

    /// Monday → Sunday of the week containing `date`.
    static func week(containing date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [date] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    static func interval(of unit: ProgressUnit, containing date: Date) -> DateInterval {
        let component: Calendar.Component
        switch unit {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 1)
    }

    static func progress(of unit: ProgressUnit, at date: Date) -> Double {
        let interval = interval(of: unit, containing: date)
        guard interval.duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(interval.start) / interval.duration))
    }

    static func daysInYear(of date: Date) -> Int {
        calendar.range(of: .day, in: .year, for: date)?.count ?? 365
    }

    static func dayOfYear(_ date: Date) -> Int {
        calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    /// The 6×7 grid (or 5×7) of dates shown for a month view, starting on Monday.
    static func monthGrid(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in days {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    static func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start]).map { $0.uppercased() }
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
}
