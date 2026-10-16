import Foundation

struct ExerciseTemplate: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: Int
    var weight: Double
    var restSeconds: Int = 90
    /// The exercise of the library it comes from (nil for a name typed by the person).
    var exerciseID: String?
    /// "3-1-1-0": seconds down, pause, up, pause.
    var tempo: String = ""
    var notes: String = ""

    init(id: UUID = UUID(), name: String, sets: Int, reps: Int, weight: Double, restSeconds: Int = 90,
         exerciseID: String? = nil, tempo: String = "", notes: String = "") {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.restSeconds = restSeconds
        self.exerciseID = exerciseID
        self.tempo = tempo
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey { case id, name, sets, reps, weight, restSeconds, exerciseID, tempo, notes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        name = c.value(.name, "")
        sets = c.value(.sets, 3)
        reps = c.value(.reps, 10)
        weight = c.value(.weight, 0)
        restSeconds = c.value(.restSeconds, 90)
        exerciseID = c.optional(.exerciseID)
        tempo = c.value(.tempo, "")
        notes = c.value(.notes, "")
    }

    /// The library entry: the one chosen, else the one the name matches.
    var info: ExerciseInfo? {
        exerciseID.flatMap(ExerciseLibrary.info) ?? ExerciseLibrary.match(name: name)
    }
}

/// An exercise the person added themselves (« Mes exercices »).
struct CustomExercise: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var muscle: Muscle = .fullBody
    var equipment: Equipment = .other
    var type: ExerciseType = .strength
    var notes: String = ""

    init(name: String, muscle: Muscle = .fullBody, equipment: Equipment = .other, type: ExerciseType = .strength, notes: String = "") {
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.type = type
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey { case id, name, muscle, equipment, type, notes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        name = c.value(.name, "")
        muscle = c.value(.muscle, .fullBody)
        equipment = c.value(.equipment, .other)
        type = c.value(.type, .strength)
        notes = c.value(.notes, "")
    }
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
    var exerciseID: String?

    var volume: Double { Double(reps) * weight }
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
    /// A rest put on pause: the seconds left (the rest has no end while it is paused).
    var restPausedRemaining: TimeInterval?
    /// A session caught up: the day it was planned for (« Séance rattrapée »).
    var catchUpFor: Date?

    var isFinished: Bool { end != nil }
    var isCatchUp: Bool { catchUpFor != nil }
    var currentExercise: ExerciseTemplate? { exercises[safe: exerciseIndex] }
    var volume: Double { sets.reduce(0) { $0 + Double($1.reps) * $1.weight } }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }

    /// Logs the current set as done and moves to the next one; returns the rest to take.
    /// The reps and weight actually done can differ from the plan.
    mutating func completeSet(at date: Date, reps: Int? = nil, weight: Double? = nil) -> Int? {
        guard let exercise = currentExercise else { return nil }
        sets.append(SetLog(exercise: exercise.name, reps: reps ?? exercise.reps, weight: weight ?? exercise.weight, date: date, exerciseID: exercise.exerciseID))
        setIndex += 1
        if setIndex >= exercise.sets {
            setIndex = 0
            exerciseIndex += 1
        }
        restPausedRemaining = nil
        if exerciseIndex >= exercises.count {
            end = date
            restEndsAt = nil
            return nil
        }
        restEndsAt = date.addingTimeInterval(TimeInterval(exercise.restSeconds))
        return exercise.restSeconds
    }
}

extension WorkoutSession {
    /// Moves to the next exercise without logging the sets left.
    mutating func skipExercise(at date: Date) {
        guard currentExercise != nil else { return }
        setIndex = 0
        exerciseIndex += 1
        restEndsAt = nil
        restPausedRemaining = nil
        if exerciseIndex >= exercises.count { end = date }
    }

    /// Adds an exercise at the end of the session (from the library or written by the person, during the workout).
    mutating func append(_ exercise: ExerciseTemplate) {
        exercises.append(exercise)
        if end != nil, exerciseIndex >= exercises.count - 1 { end = nil }
    }

    /// Takes back the last set logged (a « Série faite » touched by mistake): the session goes back to
    /// that set, without rest, and is no longer finished. Returns the set removed, nil when there is none.
    @discardableResult
    mutating func undoLastSet() -> SetLog? {
        guard let last = sets.popLast() else { return nil }
        func isSame(_ exercise: ExerciseTemplate) -> Bool {
            exercise.name == last.exercise && exercise.exerciseID == last.exerciseID
        }
        if setIndex > 0, let current = currentExercise, isSame(current) {
            setIndex -= 1
        } else if !exercises.isEmpty {
            // The set ended an exercise: back to the closest one before (an exercise skipped in between is skipped again).
            let before = min(exerciseIndex, exercises.count) - 1
            if let index = stride(from: before, through: 0, by: -1).first(where: { isSame(exercises[$0]) }) {
                exerciseIndex = index
            } else {
                exerciseIndex = min(exerciseIndex, exercises.count - 1)
            }
            // The sets of this exercise still logged, just before the one removed.
            let logged = sets.reversed().prefix(while: { $0.exercise == last.exercise && $0.exerciseID == last.exerciseID }).count
            setIndex = min(logged, max(0, exercises[exerciseIndex].sets - 1))
        }
        end = nil
        restEndsAt = nil
        restPausedRemaining = nil
        return last
    }

    var duration: TimeInterval {
        let last = end ?? sets.last?.date ?? start
        return max(0, last.timeIntervalSince(start))
    }
}

struct FitnessState: Codable, Hashable {
    var routines: [Routine] = []
    var active: WorkoutSession?
    var history: [WorkoutSession] = []
    var weeklyGoal = 3
    var bodyWeightKg = 70.0
    /// « Mes exercices » and the library shortcuts.
    var customExercises: [CustomExercise] = []
    var favoriteExercises: [String] = []
    var recentExercises: [String] = []

    enum CodingKeys: String, CodingKey { case routines, active, history, weeklyGoal, bodyWeightKg, customExercises, favoriteExercises, recentExercises }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        routines = c.value(.routines, [])
        active = c.optional(.active)
        history = c.value(.history, [])
        weeklyGoal = c.value(.weeklyGoal, 3)
        bodyWeightKg = c.value(.bodyWeightKg, 70)
        customExercises = c.value(.customExercises, [])
        favoriteExercises = c.value(.favoriteExercises, [])
        recentExercises = c.value(.recentExercises, [])
    }

    mutating func toggleFavorite(_ exerciseID: String) {
        if favoriteExercises.contains(exerciseID) {
            favoriteExercises.removeAll { $0 == exerciseID }
        } else {
            favoriteExercises.insert(exerciseID, at: 0)
        }
    }

    mutating func noteUsed(_ exerciseID: String) {
        recentExercises.removeAll { $0 == exerciseID }
        recentExercises.insert(exerciseID, at: 0)
        if recentExercises.count > 15 { recentExercises.removeLast(recentExercises.count - 15) }
    }

    /// Adds an exercise to a routine (or a new routine), from the library or an exercise sheet.
    mutating func add(_ exercise: ExerciseTemplate, toRoutine routineID: UUID?, newRoutineName: String = "") {
        if let routineID, let index = routines.firstIndex(where: { $0.id == routineID }) {
            routines[index].exercises.append(exercise)
        } else {
            let name = newRoutineName.trimmed.isEmpty ? tr("Nouvelle séance") : newRoutineName.trimmed
            routines.append(Routine(name: name, exercises: [exercise]))
        }
        if let id = exercise.exerciseID { noteUsed(id) }
    }

    /// The routine planned for today, or the first one if none is scheduled.
    func routine(for date: Date) -> Routine? {
        let weekday = FitnessMath.isoWeekday(date)
        return routines.first { $0.weekdays.contains(weekday) } ?? routines.first
    }

    func isScheduled(_ date: Date) -> Bool {
        routines.contains { $0.weekdays.contains(FitnessMath.isoWeekday(date)) }
    }

    /// Starts a routine; `missedDay`: the day it was planned for, when it is caught up later.
    mutating func startSession(_ routine: Routine, at date: Date, catchingUp missedDay: Date? = nil) {
        finishActive(at: date)
        active = WorkoutSession(routineID: routine.id, routineName: routine.name, exercises: routine.exercises, start: date,
                                catchUpFor: missedDay.map(DateMath.startOfDay))
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

    /// How long after its last set a session finished by that set can still be taken back.
    static let undoWindow: TimeInterval = 3600

    /// The session just finished by its last set (`completeSet` then `finishActive`), still in the
    /// window to take that set back. A session finished by « Terminer la séance » is not reopened.
    func justFinishedSession(at date: Date) -> WorkoutSession? {
        guard active == nil, let last = history.last, let lastSet = last.sets.last, last.end == lastSet.date,
              last.exerciseIndex >= last.exercises.count else { return nil }
        let elapsed = date.timeIntervalSince(lastSet.date)
        guard elapsed >= 0, elapsed < Self.undoWindow, DateMath.isSameDay(lastSet.date, date) else { return nil }
        return last
    }

    /// True when « Annuler la dernière série » has a set to take back.
    func canUndoLastSet(at date: Date) -> Bool {
        if let active { return !active.sets.isEmpty }
        return justFinishedSession(at: date) != nil
    }

    /// The session in progress without any set yet (started by mistake): « Annuler la séance » is offered instead.
    var activeHasNoSets: Bool {
        guard let active else { return false }
        return !active.isFinished && active.sets.isEmpty
    }

    /// Takes back the last « Série faite » (Lock Screen, Dynamic Island, widget or app). When that set had
    /// finished the session, the session leaves the history and is in progress again. A session left
    /// without any set stays in progress: « Annuler la séance » then removes it. Returns false when
    /// there was nothing to take back.
    @discardableResult
    mutating func undoLastSet(at date: Date) -> Bool {
        if active == nil, let finished = justFinishedSession(at: date) {
            history.removeLast()
            active = finished
        }
        guard var session = active, session.undoLastSet() != nil else { return false }
        active = session
        return true
    }

    /// Drops the session in progress (started by mistake, or not to keep): it never goes to the
    /// history, so it counts neither as done nor as half done (week, streak, records, calories, reminders).
    mutating func cancelActive() {
        active = nil
    }

    mutating func skipRest() {
        active?.restEndsAt = nil
        active?.restPausedRemaining = nil
    }

    /// Stops the rest countdown where it is (from the app, Mon Quotidien or the Lock Screen).
    mutating func pauseRest(at date: Date) {
        guard let end = active?.restEndsAt, end > date else { return }
        active?.restPausedRemaining = end.timeIntervalSince(date)
        active?.restEndsAt = nil
    }

    /// Starts the paused rest again, for the seconds that were left.
    mutating func resumeRest(at date: Date) {
        guard let left = active?.restPausedRemaining else { return }
        active?.restEndsAt = date.addingTimeInterval(left)
        active?.restPausedRemaining = nil
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

    /// The session that caught up the one planned on `day` (done another day, or under way).
    static func catchUp(of day: Date, _ state: FitnessState) -> WorkoutSession? {
        var all = state.history
        if let active = state.active { all.append(active) }
        return all.first { $0.catchUpFor.map { DateMath.isSameDay($0, day) } ?? false }
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

    /// The sets done for an exercise, by session (most recent last). Sets are matched by library id
    /// or, for older sets, by name.
    struct ExerciseSession: Identifiable, Hashable {
        var date: Date
        var sets: [SetLog]
        var id: Date { date }
        var best: SetLog? { sets.max { FitnessMath.oneRepMax($0) < FitnessMath.oneRepMax($1) } }
        var volume: Double { sets.reduce(0) { $0 + $1.volume } }
        var topWeight: Double { sets.map(\.weight).max() ?? 0 }
        var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    }

    static func oneRepMax(_ set: SetLog) -> Double { set.weight * (1 + Double(set.reps) / 30) }

    static func matches(_ set: SetLog, _ exercise: ExerciseInfo) -> Bool {
        if let id = set.exerciseID { return id == exercise.id }
        return ExerciseLibrary.match(name: set.exercise)?.id == exercise.id
    }

    /// An exercise added to the session in progress: what was lifted the last time (its heaviest set),
    /// else 3 × 10 for strength and one round for the rest.
    static func sessionTemplate(for exercise: ExerciseInfo, _ state: FitnessState) -> ExerciseTemplate {
        let last = history(of: exercise, state).last
        let strength = exercise.type == .strength
        let top = last?.sets.max { $0.weight < $1.weight }
        return ExerciseTemplate(name: exercise.name, sets: strength ? max(1, min(6, last?.sets.count ?? 3)) : 1,
                                reps: strength ? (top?.reps ?? 10) : 1, weight: top?.weight ?? 0, exerciseID: exercise.id)
    }

    static func history(of exercise: ExerciseInfo, _ state: FitnessState) -> [ExerciseSession] {
        sessions(state)
            .sorted { $0.start < $1.start }
            .compactMap { session in
                let sets = session.sets.filter { matches($0, exercise) }
                return sets.isEmpty ? nil : ExerciseSession(date: session.start, sets: sets)
            }
    }

    /// The same, for an exercise the library doesn't know (matched by name).
    static func history(named name: String, _ state: FitnessState) -> [ExerciseSession] {
        let key = ExerciseLibrary.normalized(name)
        return sessions(state)
            .sorted { $0.start < $1.start }
            .compactMap { session in
                let sets = session.sets.filter { ExerciseLibrary.normalized($0.exercise) == key }
                return sets.isEmpty ? nil : ExerciseSession(date: session.start, sets: sets)
            }
    }

    /// Exercises most often done, most frequent first (library ids).
    static func frequentExercises(_ state: FitnessState, limit: Int = 6) -> [String] {
        var counts: [String: Int] = [:]
        for session in sessions(state) {
            let ids = Set(session.sets.compactMap { $0.exerciseID ?? ExerciseLibrary.match(name: $0.exercise)?.id })
            for id in ids { counts[id, default: 0] += 1 }
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(limit).map(\.key)
    }

    /// Minutes trained in the week of a date.
    static func minutes(inWeekOf date: Date, _ state: FitnessState) -> Double {
        guard let week = DateMath.calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return sessions(state).filter { week.contains($0.start) }.reduce(0) { $0 + $1.duration / 60 }
    }

    /// Whether each day of the week of a date (Monday first) had a session.
    static func trainedDays(inWeekOf date: Date, _ state: FitnessState) -> [Bool] {
        let keys = Set(sessions(state).map { DateMath.dayKey($0.start) })
        return DateMath.week(containing: date).map { keys.contains(DateMath.dayKey($0)) }
    }

    /// The next day with a routine planned after a date, and that routine.
    static func nextPlanned(after date: Date, _ state: FitnessState) -> (day: Date, routine: Routine)? {
        for offset in 1...7 {
            guard let day = DateMath.calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let weekday = isoWeekday(day)
            if let routine = state.routines.first(where: { $0.weekdays.contains(weekday) }) { return (day, routine) }
        }
        return nil
    }

    static func caloriesThisWeek(_ state: FitnessState, weekOf date: Date) -> Double {
        DateMath.week(containing: date).reduce(0) { $0 + caloriesBurned(state, on: $1) }
    }

    static func trainedDays(_ state: FitnessState, inMonthOf date: Date) -> Set<String> {
        guard let month = DateMath.calendar.dateInterval(of: .month, for: date) else { return [] }
        return Set(sessions(state).filter { month.contains($0.start) }.map { DateMath.dayKey($0.start) })
    }
}
