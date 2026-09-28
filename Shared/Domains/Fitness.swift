import Foundation

struct ExerciseTemplate: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    var restSeconds: Int = 90
}

struct Routine: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var exercises: [ExerciseTemplate]
    /// ISO weekdays (1 = lundi … 7 = dimanche) on which this routine is planned.
    var weekdays: [Int] = []
}

struct SetLog: Codable, Hashable, Identifiable {
    var id = UUID()
    var exercise: String
    var reps: Int
    var weight: Double
    var date: Date
}

struct WorkoutSession: Codable, Hashable, Identifiable {
    var id = UUID()
    var routineID: UUID?
    var routineName: String
    var exercises: [ExerciseTemplate]
    var start: Date
    var end: Date?
    var sets: [SetLog] = []
    var exerciseIndex = 0
    var setIndex = 0
    var restEndsAt: Date?

    var isFinished: Bool { end != nil }
    var currentExercise: ExerciseTemplate? { exercises[safe: exerciseIndex] }
    var volume: Double { sets.reduce(0) { $0 + Double($1.reps) * $1.weight } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }

    /// Logs the current set as done and moves to the next one; returns the rest to take.
    mutating func completeSet(at date: Date) -> Int? {
        guard let exercise = currentExercise else { return nil }
        sets.append(SetLog(exercise: exercise.name, reps: exercise.reps, weight: exercise.weight, date: date))
        setIndex += 1
        if setIndex >= exercise.sets {
            setIndex = 0
            exerciseIndex += 1
        }
        if exerciseIndex >= exercises.count {
            end = date
            restEndsAt = nil
            return nil
        }
        restEndsAt = date.addingTimeInterval(TimeInterval(exercise.restSeconds))
        return exercise.restSeconds
    }
}

struct FitnessState: Codable, Hashable {
    var routines: [Routine] = []
    var active: WorkoutSession?
    var history: [WorkoutSession] = []
    var weeklyGoal = 3
    var bodyWeightKg = 70.0

    enum CodingKeys: String, CodingKey { case routines, active, history, weeklyGoal, bodyWeightKg }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        routines = c.value(.routines, [])
        active = c.optional(.active)
        history = c.value(.history, [])
        weeklyGoal = c.value(.weeklyGoal, 3)
        bodyWeightKg = c.value(.bodyWeightKg, 70)
    }

    /// The routine planned for today, or the first one if none is scheduled.
    func routine(for date: Date) -> Routine? {
        let weekday = FitnessMath.isoWeekday(date)
        return routines.first { $0.weekdays.contains(weekday) } ?? routines.first
    }

    func isScheduled(_ date: Date) -> Bool {
        routines.contains { $0.weekdays.contains(FitnessMath.isoWeekday(date)) }
    }

    mutating func startSession(_ routine: Routine, at date: Date) {
        finishActive(at: date)
        active = WorkoutSession(routineID: routine.id, routineName: routine.name, exercises: routine.exercises, start: date)
    }

    mutating func finishActive(at date: Date) {
        guard var session = active else { return }
        if !session.sets.isEmpty {
            session.end = session.end ?? date
            session.restEndsAt = nil
            history.append(session)
            if history.count > 300 { history.removeFirst(history.count - 300) }
        }
        active = nil
    }

    /// Logs one set from a widget or the app, starting today's routine if needed.
    mutating func completeNextSet(at date: Date) {
        if active == nil || active?.isFinished == true, let planned = routine(for: date) {
            startSession(planned, at: date)
        }
        guard var session = active else { return }
        _ = session.completeSet(at: date)
        active = session
        if session.isFinished { finishActive(at: date) }
    }
}

enum FitnessMath {
    static func isoWeekday(_ date: Date) -> Int {
        let weekday = DateMath.calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    static func sessions(_ state: FitnessState) -> [WorkoutSession] {
        var all = state.history
        if let active = state.active, !active.sets.isEmpty { all.append(active) }
        return all
    }

    static func workouts(inWeekOf date: Date, _ state: FitnessState) -> Int {
        guard let week = DateMath.calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        let days = Set(sessions(state).filter { week.contains($0.start) }.map { DateMath.dayKey($0.start) })
        return days.count
    }

    /// Consecutive weeks (including this one if already met) reaching the weekly goal.
    static func weekStreak(_ state: FitnessState, until date: Date) -> Int {
        var count = 0
        var cursor = date
        if workouts(inWeekOf: cursor, state) < state.weeklyGoal {
            cursor = DateMath.calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }
        while workouts(inWeekOf: cursor, state) >= state.weeklyGoal, count < 520 {
            count += 1
            cursor = DateMath.calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    /// Weight × reps lifted per day of the current week (Monday first).
    static func weeklyVolume(_ state: FitnessState, weekOf date: Date) -> [Double] {
        DateMath.week(containing: date).map { day in
            sessions(state).flatMap(\.sets).filter { DateMath.isSameDay($0.date, day) }
                .reduce(0) { $0 + Double($1.reps) * $1.weight }
        }
    }

    struct Record: Hashable {
        let exercise: String
        let weight: Double
        let reps: Int
        /// Estimated one-rep max (Epley).
        var oneRepMax: Double { weight * (1 + Double(reps) / 30) }
    }

    static func records(_ state: FitnessState) -> [Record] {
        var best: [String: Record] = [:]
        for set in sessions(state).flatMap(\.sets) where set.weight > 0 {
            let record = Record(exercise: set.exercise, weight: set.weight, reps: set.reps)
            if let current = best[set.exercise], current.oneRepMax >= record.oneRepMax { continue }
            best[set.exercise] = record
        }
        return best.values.sorted { $0.oneRepMax > $1.oneRepMax }
    }

    /// Rough estimate from a moderate-intensity strength MET value (5), clearly labelled in the UI.
    static func caloriesBurned(_ state: FitnessState, on day: Date) -> Double {
        let minutes = sessions(state).filter { DateMath.isSameDay($0.start, day) }.reduce(0.0) { total, session in
            let end = session.end ?? session.sets.last?.date ?? session.start
            return total + max(0, end.timeIntervalSince(session.start) / 60)
        }
        return 5 * state.bodyWeightKg * minutes / 60
    }

    static func caloriesThisWeek(_ state: FitnessState, weekOf date: Date) -> Double {
        DateMath.week(containing: date).reduce(0) { $0 + caloriesBurned(state, on: $1) }
    }

    static func trainedDays(_ state: FitnessState, inMonthOf date: Date) -> Set<String> {
        guard let month = DateMath.calendar.dateInterval(of: .month, for: date) else { return [] }
        return Set(sessions(state).filter { month.contains($0.start) }.map { DateMath.dayKey($0.start) })
    }
}
