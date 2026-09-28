import Foundation

struct Course: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var colorHex: String = "D6409F"
    var teacher: String = ""
    /// Credits (or coefficient) used to weight the overall average.
    var credits: Double = 3
}

/// A weekly class in the timetable. Times are minutes after midnight.
struct ClassSlot: Codable, Hashable, Identifiable {
    var id = UUID()
    var courseID: UUID?
    /// ISO weekday, 1 = lundi … 7 = dimanche.
    var weekday: Int
    var startMinute: Int
    var endMinute: Int
    var room: String = ""
}

struct Exam: Codable, Hashable, Identifiable {
    var id = UUID()
    var courseID: UUID?
    var title: String
    var date: Date
    var room: String = ""
}

struct Assignment: Codable, Hashable, Identifiable {
    var id = UUID()
    var courseID: UUID?
    var title: String
    var due: Date
    var isDone = false
}

struct Grade: Codable, Hashable, Identifiable {
    var id = UUID()
    var courseID: UUID?
    var title: String
    var score: Double
    var maxScore: Double = 100
    /// Weight of this evaluation within its course (percent of the final grade).
    var weight: Double = 10

    var ratio: Double { maxScore > 0 ? score / maxScore : 0 }
}

/// A flashcard reviewed with a Leitner schedule: a known card moves up a box and comes back later.
struct Flashcard: Codable, Hashable, Identifiable {
    var id = UUID()
    var deck: String = "Général"
    var front: String
    var back: String
    var box: Int = 1
    var due = Date()
}

struct StudySession: Codable, Hashable {
    var date: Date
    var minutes: Int
    var courseID: UUID?
}

struct StudentState: Codable, Hashable {
    var courses: [Course] = []
    var slots: [ClassSlot] = []
    var exams: [Exam] = []
    var assignments: [Assignment] = []
    var grades: [Grade] = []
    var cards: [Flashcard] = []
    var sessions: [StudySession] = []
    var semesterStart: Date?
    var semesterEnd: Date?
    var weeklyStudyGoalHours: Double = 10
    /// Whether the flashcard widget currently shows the answer.
    var isCardRevealed = false

    enum CodingKeys: String, CodingKey {
        case courses, slots, exams, assignments, grades, cards, sessions, semesterStart, semesterEnd, weeklyStudyGoalHours, isCardRevealed
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        courses = c.value(.courses, [])
        slots = c.value(.slots, [])
        exams = c.value(.exams, [])
        assignments = c.value(.assignments, [])
        grades = c.value(.grades, [])
        cards = c.value(.cards, [])
        sessions = c.value(.sessions, [])
        semesterStart = c.optional(.semesterStart)
        semesterEnd = c.optional(.semesterEnd)
        weeklyStudyGoalHours = c.value(.weeklyStudyGoalHours, 10)
        isCardRevealed = c.value(.isCardRevealed, false)
    }

    func course(_ id: UUID?) -> Course? {
        guard let id else { return nil }
        return courses.first { $0.id == id }
    }

    mutating func toggleAssignment(_ id: UUID) {
        guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }
        assignments[index].isDone.toggle()
    }

    /// Grades the card due now; a known card is pushed back 1, 2, 4, 8 or 16 days.
    mutating func gradeDueCard(known: Bool, at date: Date = Date()) {
        guard let card = StudentMath.dueCard(self, at: date), let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        let box = known ? min(5, cards[index].box + 1) : 1
        cards[index].box = box
        let days = known ? [1, 2, 4, 8, 16][box - 1] : 0
        let next = DateMath.calendar.date(byAdding: .day, value: days, to: date) ?? date
        cards[index].due = known ? DateMath.startOfDay(next) : date.addingTimeInterval(10 * 60)
        isCardRevealed = false
    }

    mutating func logStudy(minutes: Int, courseID: UUID?, at date: Date = Date()) {
        sessions.append(StudySession(date: date, minutes: minutes, courseID: courseID))
        let cutoff = date.addingTimeInterval(-200 * 86_400)
        sessions.removeAll { $0.date < cutoff }
    }
}

enum StudentMath {
    struct ClassOccurrence: Hashable {
        let slot: ClassSlot
        let start: Date
        let end: Date
    }

    static func occurrences(_ state: StudentState, on day: Date) -> [ClassOccurrence] {
        let weekday = FitnessMath.isoWeekday(day)
        let start = DateMath.startOfDay(day)
        return state.slots.filter { $0.weekday == weekday }.map { slot in
            ClassOccurrence(
                slot: slot,
                start: start.addingTimeInterval(TimeInterval(slot.startMinute) * 60),
                end: start.addingTimeInterval(TimeInterval(slot.endMinute) * 60)
            )
        }
        .sorted { $0.start < $1.start }
    }

    /// The class in progress or the next one, looking up to a week ahead.
    static func nextClass(_ state: StudentState, at date: Date) -> ClassOccurrence? {
        for offset in 0..<8 {
            guard let day = DateMath.calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if let next = occurrences(state, on: day).first(where: { $0.end > date }) { return next }
        }
        return nil
    }

    static func nextExam(_ state: StudentState, at date: Date) -> Exam? {
        state.exams.filter { $0.date > date }.min { $0.date < $1.date }
    }

    static func openAssignments(_ state: StudentState) -> [Assignment] {
        state.assignments.filter { !$0.isDone }.sorted { $0.due < $1.due }
    }

    /// Weighted average of a course in percent, or nil without grades.
    static func courseAverage(_ state: StudentState, course: UUID?) -> Double? {
        let grades = state.grades.filter { $0.courseID == course }
        let weight = grades.reduce(0) { $0 + $1.weight }
        guard weight > 0 else { return nil }
        return grades.reduce(0) { $0 + $1.ratio * $1.weight } / weight * 100
    }

    /// Average across courses, weighted by credits.
    static func overallAverage(_ state: StudentState) -> Double? {
        var total = 0.0
        var credits = 0.0
        for course in state.courses {
            guard let average = courseAverage(state, course: course.id) else { continue }
            total += average * course.credits
            credits += course.credits
        }
        if credits == 0, let loose = courseAverage(state, course: nil) { return loose }
        return credits > 0 ? total / credits : nil
    }

    static func semesterProgress(_ state: StudentState, at date: Date) -> Double? {
        guard let start = state.semesterStart, let end = state.semesterEnd, end > start else { return nil }
        return min(1, max(0, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    static func studyMinutes(_ state: StudentState, weekOf date: Date) -> Double {
        guard let week = DateMath.calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return Double(state.sessions.filter { week.contains($0.date) }.reduce(0) { $0 + $1.minutes })
    }

    static func studyByDay(_ state: StudentState, weekOf date: Date) -> [Double] {
        DateMath.week(containing: date).map { day in
            Double(state.sessions.filter { DateMath.isSameDay($0.date, day) }.reduce(0) { $0 + $1.minutes })
        }
    }

    static func dueCard(_ state: StudentState, at date: Date) -> Flashcard? {
        state.cards.filter { $0.due <= date }.min { $0.due < $1.due }
    }

    static func dueCount(_ state: StudentState, at date: Date) -> Int {
        state.cards.filter { $0.due <= date }.count
    }
}
