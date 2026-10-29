import Foundation

/// What the « Horaire » widget of the Lock Screen says at a given moment: the day's name, then the event in
/// progress or the next one. Pure logic (no SwiftUI): the events come from `StudentMath.occurrences`, which
/// already applies the cancellations and the exceptions of the day, so this never reads `slots` itself.
enum ScheduleGlance {
    enum Phase: Equatable {
        /// An event is in progress (`event`).
        case current
        /// Nothing in progress; `event` starts later today.
        case upcoming
        /// The day had events and they are all over, and tomorrow has none.
        case finished
        /// No event today, and tomorrow has none.
        case empty
        /// Nothing more today (all over, or no event at all); `event` is the first one of tomorrow.
        case tomorrow
    }

    struct Result: Equatable {
        /// The weekday, written in the language of the app (« Lundi »).
        let dayName: String
        let phase: Phase
        /// The event to show (nil when `finished` or `empty`; tomorrow's first for `tomorrow`).
        let event: StudentMath.ClassOccurrence?
        /// When the answer changes: the next start or end of today, else the next midnight.
        let nextChange: Date
    }

    /// The rule for overlaps: among the events in progress, the one that ends last is shown (it is the one
    /// still to come when the others are over); on a tie, the one that started first, then the stored order.
    /// An event that ends right when another starts is over at that moment (the end is exclusive).
    static func compute(_ state: StudentState, now: Date) -> Result {
        let today = events(state, on: now)
        let name = Fmt.weekday(now)
        let midnight = DateMath.nextMidnight(after: now)
        let change = (boundaries(today).filter { $0 > now }.min()).map { min($0, midnight) } ?? midnight

        let current = today.filter { $0.start <= now && now < $0.end }
        if let shown = current.min(by: { ($1.end, $0.start) < ($0.end, $1.start) }) {
            return Result(dayName: name, phase: .current, event: shown, nextChange: change)
        }
        if let next = today.first(where: { $0.start > now }) {
            return Result(dayName: name, phase: .upcoming, event: next, nextChange: change)
        }
        if let tomorrow = events(state, on: midnight).first {
            return Result(dayName: name, phase: .tomorrow, event: tomorrow, nextChange: change)
        }
        return Result(dayName: name, phase: today.isEmpty ? .empty : .finished, event: nil, nextChange: change)
    }

    /// The moments the widget must be redrawn from `now` to the end of tomorrow: every start and end of
    /// today and tomorrow, and midnight. Sorted, without duplicates, starting with `now`.
    static func transitions(_ state: StudentState, from now: Date) -> [Date] {
        let midnight = DateMath.nextMidnight(after: now)
        let tomorrow = events(state, on: midnight)
        let all = boundaries(events(state, on: now)) + [midnight] + boundaries(tomorrow) + [DateMath.nextMidnight(after: midnight)]
        let later = Set(all.filter { $0 > now })
        return [now] + later.sorted()
    }

    /// The day's events, those with a duration, by start.
    private static func events(_ state: StudentState, on day: Date) -> [StudentMath.ClassOccurrence] {
        StudentMath.occurrences(state, on: day).filter { $0.end > $0.start }
    }

    private static func boundaries(_ events: [StudentMath.ClassOccurrence]) -> [Date] {
        events.flatMap { [$0.start, $0.end] }
    }
}
