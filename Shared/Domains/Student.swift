import Foundation

struct Course: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var colorHex: String = "D6409F"
    var teacher: String = ""
    /// Credits (or coefficient) used to weight the overall average.
    var credits: Double = 3
}

/// What an entry of the week's schedule is: chosen by the person when adding it.
enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
    case course, work, appointment, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .course: tr("Cours")
        case .work: tr("Travail")
        case .appointment: tr("Rendez-vous")
        case .other: tr("Autre événement")
        }
    }

    var symbol: String {
        switch self {
        case .course: "graduationcap.fill"
        case .work: "briefcase.fill"
        case .appointment: "person.2.fill"
        case .other: "star.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .course: "D6409F"
        case .work: "3366FF"
        case .appointment: "F2A33A"
        case .other: "7FA33A"
        }
    }
}

/// A weekly entry of the Planning schedule: a class (with its course) or another event of the week
/// (work, an appointment…). Times are minutes after midnight.
struct ClassSlot: Codable, Hashable, Identifiable {
    var id = UUID()
    var courseID: UUID?
    /// ISO weekday, 1 = lundi … 7 = dimanche.
    var weekday: Int
    var startMinute: Int
    var endMinute: Int
    /// The place (a classroom for a class).
    var room: String = ""
    var kind: ScheduleKind = .course
    /// The name of an event that isn't a class (a class shows its course's name).
    var title: String = ""

    enum CodingKeys: String, CodingKey { case id, courseID, weekday, startMinute, endMinute, room, kind, title }

    init(courseID: UUID?, weekday: Int, startMinute: Int, endMinute: Int, room: String = "", kind: ScheduleKind = .course, title: String = "") {
        self.courseID = courseID
        self.weekday = weekday
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.room = room
        self.kind = kind
        self.title = title
    }

    /// Classes saved before the other kinds of events existed read as classes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        courseID = try c.decodeIfPresent(UUID.self, forKey: .courseID)
        weekday = try c.decode(Int.self, forKey: .weekday)
        startMinute = try c.decode(Int.self, forKey: .startMinute)
        endMinute = try c.decode(Int.self, forKey: .endMinute)
        room = try c.decodeIfPresent(String.self, forKey: .room) ?? ""
        kind = (try? c.decodeIfPresent(ScheduleKind.self, forKey: .kind)) ?? .course
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    }
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
    var deck: String = tr("Général")
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
    /// A study timer under way (kept when the app closes).
    var timerStart: Date?
    var timerCourseID: UUID?

    enum CodingKeys: String, CodingKey {
        case courses, slots, exams, assignments, grades, cards, sessions, semesterStart, semesterEnd, weeklyStudyGoalHours, isCardRevealed, timerStart, timerCourseID
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
        timerStart = c.optional(.timerStart)
        timerCourseID = c.optional(.timerCourseID)
    }

    /// What a schedule entry is called: its course for a class, its own name for another event.
    func title(of slot: ClassSlot) -> String {
        if slot.kind == .course { return course(slot.courseID)?.name ?? tr("Cours") }
        return slot.title.trimmed.isEmpty ? slot.kind.title : slot.title
    }

    /// Its color: the course's for a class, the kind's for another event.
    func colorHex(of slot: ClassSlot) -> String {
        slot.kind == .course ? (course(slot.courseID)?.colorHex ?? ScheduleKind.course.colorHex) : slot.kind.colorHex
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

    mutating func startTimer(courseID: UUID?, at date: Date = Date()) {
        timerStart = date
        timerCourseID = courseID
    }

    /// Stops the timer and logs the time studied (a minute at least, four hours at most). Returns
    /// the minutes logged, 0 when too short to count.
    @discardableResult
    mutating func stopTimer(at date: Date = Date()) -> Int {
        defer {
            timerStart = nil
            timerCourseID = nil
        }
        guard let start = timerStart else { return 0 }
        let minutes = min(240, Int(date.timeIntervalSince(start) / 60))
        guard minutes >= 1 else { return 0 }
        logStudy(minutes: minutes, courseID: timerCourseID, at: date)
        return minutes
    }

    /// Removes a course with its place in the timetable; its grades, exams and homework stay, without a course.
    mutating func deleteCourse(_ id: UUID) {
        courses.removeAll { $0.id == id }
        slots.removeAll { $0.courseID == id }
        for index in grades.indices where grades[index].courseID == id { grades[index].courseID = nil }
        for index in exams.indices where exams[index].courseID == id { exams[index].courseID = nil }
        for index in assignments.indices where assignments[index].courseID == id { assignments[index].courseID = nil }
        for index in sessions.indices where sessions[index].courseID == id { sessions[index].courseID = nil }
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

    /// The class in progress or the next one, looking up to a week ahead (classes only, not the
    /// other events of the schedule).
    static func nextClass(_ state: StudentState, at date: Date) -> ClassOccurrence? {
        for offset in 0..<8 {
            guard let day = DateMath.calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if let next = occurrences(state, on: day).first(where: { $0.end > date && $0.slot.kind == .course }) { return next }
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

    // MARK: Mini-app

    static func upcomingExams(_ state: StudentState, at date: Date) -> [Exam] {
        state.exams.filter { $0.date > date }.sorted { $0.date < $1.date }
    }

    static func pastExams(_ state: StudentState, at date: Date) -> [Exam] {
        state.exams.filter { $0.date <= date }.sorted { $0.date > $1.date }
    }

    /// Homework still to do, split into late, due within seven days and later.
    struct AssignmentGroups: Hashable {
        var late: [Assignment] = []
        var thisWeek: [Assignment] = []
        var later: [Assignment] = []
        var isEmpty: Bool { late.isEmpty && thisWeek.isEmpty && later.isEmpty }
    }

    static func assignmentGroups(_ state: StudentState, at date: Date) -> AssignmentGroups {
        var groups = AssignmentGroups()
        let week = date.addingTimeInterval(7 * 86_400)
        for assignment in openAssignments(state) {
            if assignment.due < date { groups.late.append(assignment) } else if assignment.due <= week { groups.thisWeek.append(assignment) } else { groups.later.append(assignment) }
        }
        return groups
    }

    /// Minutes studied in a period, all courses together.
    static func studyMinutes(_ state: StudentState, from start: Date, to end: Date) -> Int {
        state.sessions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.minutes }
    }

    /// Minutes studied in a period for one course (nil: time logged without a course).
    static func studyMinutes(_ state: StudentState, course: UUID?, from start: Date, to end: Date) -> Int {
        state.sessions.filter { $0.courseID == course && $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.minutes }
    }

    struct StudyWeek: Hashable, Identifiable {
        let start: Date
        let minutes: Int
        var id: Date { start }
    }

    /// Minutes studied each week, oldest first, the current week last.
    static func studyByWeek(_ state: StudentState, weeks: Int, at date: Date) -> [StudyWeek] {
        let monday = DateMath.week(containing: date).first ?? DateMath.startOfDay(date)
        return (0..<weeks).reversed().compactMap { back in
            guard let start = DateMath.calendar.date(byAdding: .day, value: -7 * back, to: monday),
                  let end = DateMath.calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            return StudyWeek(start: start, minutes: studyMinutes(state, from: start, to: end))
        }
    }

    /// Minutes of class a week for a course, from the timetable.
    static func weeklyClassMinutes(_ state: StudentState, course: UUID) -> Int {
        state.slots.filter { $0.courseID == course }.reduce(0) { $0 + max(0, $1.endMinute - $1.startMinute) }
    }

    /// Share of the course's grade already evaluated (sum of the weights, up to 100 %).
    static func evaluatedWeight(_ state: StudentState, course: UUID?) -> Double {
        min(100, state.grades.filter { $0.courseID == course }.reduce(0) { $0 + $1.weight })
    }

    /// The average (in percent) needed on what is left of a course to finish at `target` percent.
    /// Nil when nothing is left to evaluate; the value can be above 100 (then out of reach) or below 0.
    static func neededAverage(_ state: StudentState, course: UUID?, target: Double) -> Double? {
        let grades = state.grades.filter { $0.courseID == course }
        let done = grades.reduce(0) { $0 + $1.weight }
        let left = 100 - done
        guard left > 0.5 else { return nil }
        let earned = grades.reduce(0) { $0 + $1.ratio * $1.weight * 100 }
        return (target * 100 - earned) / left
    }

    struct Deck: Hashable, Identifiable {
        let name: String
        let total: Int
        let due: Int
        var id: String { name }
    }

    /// The decks of flashcards, with the cards to review now.
    static func decks(_ state: StudentState, at date: Date) -> [Deck] {
        let names = Array(Set(state.cards.map(\.deck))).sorted { $0.localizedCompare($1) == .orderedAscending }
        return names.map { name in
            let cards = state.cards.filter { $0.deck == name }
            return Deck(name: name, total: cards.count, due: cards.filter { $0.due <= date }.count)
        }
    }
}
