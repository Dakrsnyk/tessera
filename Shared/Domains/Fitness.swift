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

/// A set passed with « Passer »: neither done (no reps, no load, not counted anywhere) nor left to do.
struct SkippedSet: Codable, Hashable {
    var exerciseIndex: Int
    var setIndex: Int
    /// The sets logged when it was passed: it is the session's last step while none came after.
    var afterSets: Int
    var date: Date
}

/// Where the workout stands, as a button drawn for it saw it: the session in progress (nil: none)
/// and its exercise and set. A button carries it, so a second tap on a drawing already out of date
/// (a double tap before the widget or the Lock Screen is drawn again) is ignored.
struct WorkoutPosition: Codable, Hashable {
    var sessionID: UUID?
    var exerciseIndex: Int
    var setIndex: Int

    static let noSession = WorkoutPosition(sessionID: nil, exerciseIndex: 0, setIndex: 0)

    /// "UUID:2:1" (or ":0:0" without a session): how an intent parameter carries it.
    var token: String { "\(sessionID?.uuidString ?? ""):\(exerciseIndex):\(setIndex)" }

    init(sessionID: UUID?, exerciseIndex: Int, setIndex: Int) {
        self.sessionID = sessionID
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
    }

    init?(token: String) {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, let exercise = Int(parts[1]), let set = Int(parts[2]) else { return nil }
        if parts[0].isEmpty {
            sessionID = nil
        } else if let id = UUID(uuidString: String(parts[0])) {
            sessionID = id
        } else {
            return nil
        }
        exerciseIndex = exercise
        setIndex = set
    }
}

/// The workout buttons outside the app's screens (widget, Lock Screen, Dynamic Island).
enum WorkoutButton: String {
    case completeSet, skipSet, undoSet
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
    /// The sets passed with « Passer » (kept apart from `sets`, which only holds the sets done).
    var skipped: [SkippedSet] = []

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
    enum CodingKeys: String, CodingKey {
        case id, routineID, routineName, exercises, start, end, sets, exerciseIndex, setIndex, restEndsAt,
             restPausedRemaining, catchUpFor, skipped
    }

    /// Sessions saved by an older version (without `skipped`) still read, like every other field.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        routineID = c.optional(.routineID)
        routineName = c.value(.routineName, "")
        exercises = c.value(.exercises, [])
        start = c.value(.start, Date())
        end = c.optional(.end)
        sets = c.value(.sets, [])
        exerciseIndex = c.value(.exerciseIndex, 0)
        setIndex = c.value(.setIndex, 0)
        restEndsAt = c.optional(.restEndsAt)
        restPausedRemaining = c.optional(.restPausedRemaining)
        catchUpFor = c.optional(.catchUpFor)
        skipped = c.value(.skipped, [])
    }

    /// The last « Passer » is the session's last step: no set was logged after it.
    private var lastStepIsSkip: Bool {
        guard let skip = skipped.last else { return false }
        return skip.afterSets >= sets.count
    }

    /// When the last step (a set done or passed) was taken.
    var lastStepDate: Date? {
        lastStepIsSkip ? skipped.last?.date : sets.last?.date
    }

    /// A set done or passed that « Annuler la dernière série » can take back.
    var hasSteps: Bool { !sets.isEmpty || !skipped.isEmpty }

    /// « Passer »: the set now is passed (not done: no reps, no load, never counted) and the session
    /// moves on, without rest: the next set, the next exercise after the last set of one, the end
    /// after the last set of the session. Returns false when there is no set to pass.
    @discardableResult
    mutating func skipSet(at date: Date) -> Bool {
        guard !isFinished, let exercise = currentExercise else { return false }
        skipped.append(SkippedSet(exerciseIndex: exerciseIndex, setIndex: setIndex, afterSets: sets.count, date: date))
        setIndex += 1
        if setIndex >= exercise.sets {
            setIndex = 0
            exerciseIndex += 1
        }
        restEndsAt = nil
        restPausedRemaining = nil
        if exerciseIndex >= exercises.count { end = date }
        return true
    }

    /// Takes back the last step, a set done or a set passed: the session goes back to that set,
    /// without rest, and is no longer finished. Returns false when there is nothing to take back.
    @discardableResult
    mutating func undoLastStep() -> Bool {
        guard lastStepIsSkip, let skip = skipped.popLast() else { return undoLastSet() != nil }
        exerciseIndex = min(skip.exerciseIndex, max(0, exercises.count - 1))
        setIndex = min(skip.setIndex, max(0, (exercises[safe: exerciseIndex]?.sets ?? 1) - 1))
        end = nil
        restEndsAt = nil
        restPausedRemaining = nil
        return true
    }

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
            // The sets of this exercise still logged, just before the one removed, and those passed in it.
            let logged = sets.reversed().prefix(while: { $0.exercise == last.exercise && $0.exerciseID == last.exerciseID }).count
            let passed = skipped.filter { $0.exerciseIndex == exerciseIndex }.count
            setIndex = min(logged + passed, max(0, exercises[exerciseIndex].sets - 1))
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

    /// The session just finished by its last set, done or passed (`completeSet` or `skipSet`, then
    /// `finishActive`), still in the window to take that set back. A session finished by « Terminer la
    /// séance » is not reopened.
    func justFinishedSession(at date: Date) -> WorkoutSession? {
        guard active == nil, let last = history.last, let lastStep = last.lastStepDate, last.end == lastStep,
              last.exerciseIndex >= last.exercises.count else { return nil }
        let elapsed = date.timeIntervalSince(lastStep)
        guard elapsed >= 0, elapsed < Self.undoWindow, DateMath.isSameDay(lastStep, date) else { return nil }
        return last
    }

    /// True when « Annuler la dernière série » has a set, done or passed, to take back.
    func canUndoLastSet(at date: Date) -> Bool {
        if let active { return active.hasSteps }
        return justFinishedSession(at: date) != nil
    }

    /// The session in progress without any set done or passed yet (started by mistake): « Annuler la
    /// séance » is offered instead.
    var activeHasNoSets: Bool {
        guard let active else { return false }
        return !active.isFinished && !active.hasSteps
    }

    /// Where the workout stands now (see `WorkoutPosition`).
    var position: WorkoutPosition {
        guard let active else { return .noSession }
        return WorkoutPosition(sessionID: active.id, exerciseIndex: active.exerciseIndex, setIndex: active.setIndex)
    }

    /// A workout button from a widget, the Lock Screen or the Dynamic Island. `expected`: the position it
    /// was drawn for; when the workout is no longer there (the first tap of a double tap already moved
    /// it), the tap is ignored rather than logging, passing or taking back one set more. nil (a button
    /// of an older version): no check. Returns true when the button changed the workout.
    @discardableResult
    mutating func press(_ button: WorkoutButton, expecting expected: WorkoutPosition?, at date: Date) -> Bool {
        if let expected, expected != position { return false }
        switch button {
        case .completeSet: return completeNextSet(at: date)
        case .skipSet: return skipSet(at: date)
        case .undoSet: return undoLastSet(at: date)
        }
    }

    /// « Passer » from the app, a widget, the Lock Screen or the Dynamic Island: the set now is passed,
    /// not counted. The session it ends goes to the history when a set was done in it; without any set
    /// done it counts for nothing. Returns false when there is no set to pass.
    @discardableResult
    mutating func skipSet(at date: Date) -> Bool {
        guard var session = active, session.skipSet(at: date) else { return false }
        active = session
        if session.isFinished { finishActive(at: date) }
        return true
    }

    /// Takes back the last « Série faite » or « Passer » (Lock Screen, Dynamic Island, widget or app).
    /// When that set had finished the session, the session leaves the history and is in progress again.
    /// A session left without any set stays in progress: « Annuler la séance » then removes it. Returns
    /// false when there was nothing to take back.
    @discardableResult
    mutating func undoLastSet(at date: Date) -> Bool {
        if active == nil, let finished = justFinishedSession(at: date) {
            history.removeLast()
            active = finished
        }
        guard var session = active, session.undoLastStep() else { return false }
        active = session
        return true
    }

    /// Drops the session in progress (started by mistake, or not to keep): it never goes to the
    /// history, so it counts neither as done nor as half done (week, streak, records, calories, reminders).
    mutating func cancelActive() {
        active = nil
    }

    /// « Supprimer la séance »: a session recorded by mistake leaves the history, as if it had never
    /// been done. Everything derives from the history (week, streak, records, calories, volume, « Séance
    /// faite », the catch-up, the reminders), so the day's routine can be started again. The session in
    /// progress (listed once it has a set) is dropped like `cancelActive`. Unknown id: nothing changes.
    /// Returns true when a session was removed.
    @discardableResult
    mutating func deleteSession(id: UUID) -> Bool {
        if active?.id == id {
            cancelActive()
            history.removeAll { $0.id == id }
            return true
        }
        let count = history.count
        history.removeAll { $0.id == id }
        return history.count != count
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

    /// Logs one set from a widget or the app, starting today's routine if needed. Returns true when a set was logged.
    @discardableResult
    mutating func completeNextSet(at date: Date) -> Bool {
        if active == nil || active?.isFinished == true, let planned = routine(for: date) {
            startSession(planned, at: date)
        }
        guard var session = active else { return false }
        let logged = session.sets.count
        _ = session.completeSet(at: date)
        active = session
        if session.isFinished { finishActive(at: date) }
        return session.sets.count > logged
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
