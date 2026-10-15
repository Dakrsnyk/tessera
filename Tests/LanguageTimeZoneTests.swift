import XCTest
@testable import Tessera

/// The language and the time zone are two settings: switching Ardane from French to English, then
/// back, changes how dates are written, never the hours saved nor the time zone they are read in.
final class LanguageTimeZoneTests: XCTestCase {
    private let toronto = TimeZone(identifier: "America/Toronto")!
    private let paris = TimeZone(identifier: "Europe/Paris")!
    private let canada = Locale.Region("CA")

    private func calendar(_ language: String, _ zone: TimeZone) -> Calendar {
        Fmt.makeCalendar(locale: Fmt.makeLocale(language: language, region: canada), timeZone: zone)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, in zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testTheTimeZoneIsTheIPhonesWhateverTheLanguage() {
        XCTAssertEqual(Fmt.timeZone.identifier, TimeZone.current.identifier)
        XCTAssertEqual(Fmt.calendar.timeZone.identifier, TimeZone.current.identifier)
        for language in ["fr", "en", "fr", "ja", "de", "fr"] {
            let locale = Fmt.makeLocale(language: language, region: canada)
            XCTAssertNil(Locale.Components(locale: locale).timeZone, "A language never carries a time zone (\(language))")
            XCTAssertEqual(Fmt.makeCalendar(locale: locale, timeZone: toronto).timeZone, toronto)
            XCTAssertEqual(Fmt.makeCalendar(locale: locale, timeZone: paris).timeZone, paris)
        }
    }

    /// French, then English, then French again: the saved times read the same each time.
    func testSwitchingFrenchToEnglishAndBackKeepsTheSavedTimes() throws {
        let due = date(2026, 10, 20, 14, 30, in: toronto)
        let exam = date(2026, 12, 3, 9, 0, in: toronto)
        var student = StudentState()
        student.slots = [ClassSlot(courseID: nil, weekday: 2, startMinute: 9 * 60, endMinute: 10 * 60 + 30, kind: .appointment, title: "Dentiste",
                                   date: Calendar(identifier: .gregorian).startOfDay(for: due))]
        student.exams = [Exam(courseID: nil, title: "Final", date: exam)]
        let task = TaskItem(title: "Appeler", due: due, hasTime: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        var savedStudent = try encoder.encode(student)
        var savedTask = try encoder.encode(task)

        for language in ["fr", "en", "fr"] {
            let locale = Fmt.makeLocale(language: language, region: canada)
            let calendar = calendar(language, toronto)
            let readTask = try decoder.decode(TaskItem.self, from: savedTask)
            let readStudent = try decoder.decode(StudentState.self, from: savedStudent)
            XCTAssertEqual(readTask.due, due, "The due date doesn't move (\(language))")
            XCTAssertEqual(DateMath.minuteOfDay(readTask.due!, calendar: calendar), 14 * 60 + 30)
            XCTAssertEqual(Fmt.time(readTask.due!, uses24Hour: true, timeZone: toronto, locale: locale), "14:30")
            XCTAssertEqual(readStudent.exams.first?.date, exam)
            XCTAssertEqual(DateMath.minuteOfDay(exam, calendar: calendar), 9 * 60)
            XCTAssertEqual(readStudent.slots.first?.startMinute, 9 * 60)
            XCTAssertEqual(readStudent.slots.first?.endMinute, 10 * 60 + 30)
            // Saved again in this language: byte for byte what was there.
            let againStudent = try encoder.encode(readStudent)
            let againTask = try encoder.encode(readTask)
            XCTAssertEqual(againStudent, savedStudent, "Nothing rewritten (\(language))")
            XCTAssertEqual(againTask, savedTask)
            savedStudent = againStudent
            savedTask = againTask
        }
    }

    /// Only the writing follows the language: the hour and the day stay.
    func testTheLanguageChangesTheWritingNotTheHour() {
        let moment = date(2026, 10, 15, 18, 5, in: paris)
        let french = Fmt.makeLocale(language: "fr", region: Locale.Region("FR"))
        let english = Fmt.makeLocale(language: "en", region: Locale.Region("FR"))
        XCTAssertEqual(Fmt.time(moment, uses24Hour: true, timeZone: paris, locale: french),
                       Fmt.time(moment, uses24Hour: true, timeZone: paris, locale: english))
        XCTAssertEqual(calendar("fr", paris).component(.day, from: moment), calendar("en", paris).component(.day, from: moment))
        XCTAssertEqual(calendar("fr", paris).component(.hour, from: moment), 18)
        XCTAssertEqual(calendar("en", paris).component(.hour, from: moment), 18)
    }

    /// The days the clocks change (North America and Europe), a 9:00 entry stays at 9:00.
    func testScheduleTimesFollowTheClockAcrossDaylightSavingTime() {
        let cases: [(TimeZone, [(Int, Int)])] = [(toronto, [(3, 8), (11, 1)]), (paris, [(3, 29), (10, 25)])]
        for (zone, days) in cases {
            for language in ["fr", "en"] {
                let calendar = calendar(language, zone)
                for (month, day) in days {
                    let noon = date(2026, month, day, 12, in: zone)
                    let nine = DateMath.date(on: noon, minute: 9 * 60, calendar: calendar)
                    XCTAssertEqual(calendar.component(.hour, from: nine), 9, "\(zone.identifier) \(month)/\(day) \(language)")
                    XCTAssertEqual(calendar.component(.minute, from: nine), 0)
                    XCTAssertEqual(DateMath.minuteOfDay(DateMath.date(on: noon, minute: 17 * 60 + 45, calendar: calendar), calendar: calendar), 17 * 60 + 45)
                    // Adding seconds to midnight would have been an hour off that day.
                    let naive = calendar.startOfDay(for: noon).addingTimeInterval(9 * 3600)
                    XCTAssertNotEqual(calendar.component(.hour, from: naive), 9, "The clocks change that day")
                }
            }
        }
    }

    /// Every day of a year, in the iPhone's time zone: each entry starts at its own time.
    func testEveryOccurrenceOfTheYearStartsAtItsTime() {
        var state = StudentState()
        state.slots = (1...7).map { ClassSlot(courseID: nil, weekday: $0, startMinute: 8 * 60 + 15, endMinute: 24 * 60, kind: .work, title: "Travail") }
        var day = DateMath.calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        for _ in 0..<365 {
            let occurrence = StudentMath.occurrences(state, on: day).first
            XCTAssertEqual(occurrence.map { DateMath.minuteOfDay($0.start) }, 8 * 60 + 15, "\(DateMath.dayKey(day))")
            XCTAssertEqual(occurrence.map { $0.end }, DateMath.nextMidnight(after: day), "24:00 is the next midnight")
            day = DateMath.calendar.date(byAdding: .day, value: 1, to: day)!
        }
    }
}
