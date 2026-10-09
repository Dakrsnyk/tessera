import XCTest
@testable import Tessera

/// The Fitness mini-app: a large, consistent exercise library, a search that understands what people
/// type, sessions logged as really done, and performances linked to each exercise.
final class FitnessAppTests: XCTestCase {
    private func ids(_ exercises: [ExerciseInfo]) -> [String] { exercises.map(\.id) }

    func testTheLibraryIsLargeAndConsistent() {
        let all = ExerciseLibrary.all
        XCTAssertGreaterThanOrEqual(all.count, 150)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "Each exercise once")
        for group in MuscleGroup.allCases {
            XCTAssertGreaterThanOrEqual(all.filter { ExerciseLibrary.Filters(group: group).allows($0) }.count, 3, "\(group)")
        }
        for equipment in Equipment.allCases {
            XCTAssertFalse(all.filter { $0.equipment.contains(equipment) }.isEmpty, "\(equipment)")
        }
        for type in ExerciseType.allCases {
            XCTAssertGreaterThanOrEqual(all.filter { $0.type == type }.count, 5, "\(type)")
        }
        for exercise in all {
            let technique = exercise.technique
            XCTAssertFalse(technique.start.isEmpty, exercise.id)
            XCTAssertGreaterThanOrEqual(technique.steps.count, 2, exercise.id)
            XCTAssertFalse(technique.mistakes.isEmpty, exercise.id)
            XCTAssertFalse(exercise.primary.isEmpty, exercise.id)
            XCTAssertFalse(exercise.equipment.isEmpty, exercise.id)
        }
        // Every exercise has its own demonstration (see ExerciseDemoTests).
        XCTAssertTrue(all.allSatisfy { ExerciseDemos.demo(for: $0.id) != nil })
    }

    func testTheSearchUnderstandsWhatPeopleType() {
        let developpe = ids(ExerciseLibrary.search("développé"))
        for id in ["bench-press", "db-bench", "incline-bench", "ohp", "db-shoulder-press"] {
            XCTAssertTrue(developpe.contains(id), id)
        }
        XCTAssertEqual(ExerciseLibrary.search("developpe couche").first?.id, "bench-press", "Without accents")
        XCTAssertTrue(ids(ExerciseLibrary.search("bench")).contains("bench-press"), "English name")
        XCTAssertTrue(ids(ExerciseLibrary.search("tractions")).contains("pull-up"))
        XCTAssertTrue(ids(ExerciseLibrary.search("dos haltères")).contains("db-row"), "A muscle and a tool")
        XCTAssertTrue(ExerciseLibrary.search("zzzz").isEmpty)

        let chest = ExerciseLibrary.search("", filters: ExerciseLibrary.Filters(group: .chest))
        XCTAssertFalse(chest.isEmpty)
        XCTAssertTrue(chest.allSatisfy { $0.primary.contains(.chest) })
        let beginnerBands = ExerciseLibrary.search("", filters: ExerciseLibrary.Filters(equipment: .band, difficulty: .beginner))
        XCTAssertTrue(beginnerBands.allSatisfy { $0.equipment.contains(.band) && $0.difficulty == .beginner })

        let alternatives = ExerciseLibrary.alternatives(to: ExerciseLibrary.info("bench-press")!)
        XCTAssertFalse(alternatives.isEmpty)
        XCTAssertFalse(alternatives.contains { $0.id == "bench-press" })
        XCTAssertTrue(alternatives.allSatisfy { $0.primary.contains(.chest) || $0.primary.contains(.triceps) })
    }

    func testNamesInRoutinesFindTheirExercise() {
        XCTAssertEqual(ExerciseLibrary.match(name: "Développé couché")?.id, "bench-press")
        XCTAssertEqual(ExerciseLibrary.match(name: "Tractions")?.id, "pull-up")
        XCTAssertEqual(ExerciseLibrary.match(name: "Squat")?.id, "back-squat")
        XCTAssertEqual(ExerciseLibrary.match(name: "Soulevé de terre roumain")?.id, "rdl")
        XCTAssertEqual(ExerciseLibrary.match(name: "rowing haltère")?.id, "db-row")
        XCTAssertNil(ExerciseLibrary.match(name: "Mon exercice inventé"))
    }

    func testSetsAreLoggedAsReallyDoneAndLinkedToTheExercise() throws {
        var state = FitnessState()
        let bench = ExerciseTemplate(name: "Développé couché (barre)", sets: 2, reps: 8, weight: 80, exerciseID: "bench-press")
        state.routines = [Routine(name: "Push", exercises: [bench])]
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        state.startSession(state.routines[0], at: start)
        var session = try XCTUnwrap(state.active)
        _ = session.completeSet(at: start.addingTimeInterval(60), reps: 10, weight: 82.5)
        _ = session.completeSet(at: start.addingTimeInterval(240))
        state.active = session
        state.finishActive(at: start.addingTimeInterval(300))

        let history = FitnessMath.history(of: ExerciseLibrary.info("bench-press")!, state)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].sets.map(\.reps), [10, 8])
        XCTAssertEqual(history[0].sets.first?.weight, 82.5)
        XCTAssertEqual(history[0].sets.first?.exerciseID, "bench-press")
        XCTAssertEqual(history[0].best?.weight, 82.5)
        XCTAssertEqual(history[0].volume, 10 * 82.5 + 8 * 80, accuracy: 0.01)

        // Older sets without an id are found by their name.
        var old = WorkoutSession(routineID: nil, routineName: "Ancienne", exercises: [], start: start.addingTimeInterval(-86_400 * 7))
        old.sets = [SetLog(exercise: "Développé couché", reps: 6, weight: 90, date: old.start)]
        old.end = old.start.addingTimeInterval(1_800)
        state.history.insert(old, at: 0)
        XCTAssertEqual(FitnessMath.history(of: ExerciseLibrary.info("bench-press")!, state).count, 2)
        XCTAssertEqual(FitnessMath.frequentExercises(state).first, "bench-press")
    }

    func testSessionsCanSkipAndGrow() {
        var session = WorkoutSession(routineID: nil, routineName: "Libre", exercises: [
            ExerciseTemplate(name: "A", sets: 1, reps: 5, weight: 10),
            ExerciseTemplate(name: "B", sets: 1, reps: 5, weight: 10),
        ], start: Date())
        session.skipExercise(at: Date())
        XCTAssertEqual(session.currentExercise?.name, "B")
        _ = session.completeSet(at: Date())
        XCTAssertTrue(session.isFinished)
        session.append(ExerciseTemplate(name: "C", sets: 2, reps: 5, weight: 10))
        XCTAssertFalse(session.isFinished, "An exercise added at the end reopens the session")
        XCTAssertEqual(session.currentExercise?.name, "C")
    }

    func testACaughtUpSessionRemembersTheDayItWasPlannedFor() throws {
        var state = FitnessState()
        let routine = Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 1, reps: 5, weight: 100)], weekdays: [2])
        state.routines = [routine]
        let missed = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 7))!
        let today = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 18))!
        XCTAssertNil(FitnessMath.catchUp(of: missed, state))

        state.startSession(routine, at: today, catchingUp: missed)
        XCTAssertEqual(state.active?.catchUpFor, DateMath.startOfDay(missed))
        XCTAssertNotNil(FitnessMath.catchUp(of: missed, state), "Under way, it already counts for the missed day")
        _ = state.active?.completeSet(at: today.addingTimeInterval(120))
        state.finishActive(at: today.addingTimeInterval(600))
        let done = try XCTUnwrap(state.history.last)
        XCTAssertTrue(done.isCatchUp)
        XCTAssertEqual(FitnessMath.catchUp(of: missed, state)?.id, done.id)
        XCTAssertNil(FitnessMath.catchUp(of: today, state), "The day it was done isn't a missed day")

        // A session started the usual way isn't a catch-up, and older saved sessions read as such.
        state.startSession(routine, at: today)
        XCTAssertEqual(state.active?.isCatchUp, false)
        let decoded = try JSONDecoder().decode(FitnessState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.history.last?.catchUpFor, DateMath.startOfDay(missed))
    }

    func testTheProgramGrowsFromTheLibrary() {
        var state = FitnessState()
        let squat = ExerciseTemplate(name: "Squat (barre)", sets: 4, reps: 6, weight: 100, restSeconds: 150, exerciseID: "back-squat", tempo: "3-1-1-0", notes: "Ceinture")
        state.add(squat, toRoutine: nil, newRoutineName: "  Jambes ")
        XCTAssertEqual(state.routines.map(\.name), ["Jambes"])
        state.add(ExerciseTemplate(name: "Presse à cuisses", sets: 3, reps: 12, weight: 150, exerciseID: "leg-press"), toRoutine: state.routines[0].id)
        XCTAssertEqual(state.routines[0].exercises.map(\.exerciseID), ["back-squat", "leg-press"])
        XCTAssertEqual(state.recentExercises.first, "leg-press")
        state.toggleFavorite("back-squat")
        XCTAssertEqual(state.favoriteExercises, ["back-squat"])
        state.toggleFavorite("back-squat")
        XCTAssertTrue(state.favoriteExercises.isEmpty)
    }

    func testOlderSavedWorkoutsStillOpen() throws {
        let json = #"{"routines":[{"id":"8A1B2C3D-0000-0000-0000-000000000001","name":"Haut","exercises":[{"name":"Tractions","sets":4,"reps":8,"weight":0}],"weekdays":[1]}],"history":[],"weeklyGoal":3,"bodyWeightKg":75}"#
        let state = try JSONDecoder().decode(FitnessState.self, from: Data(json.utf8))
        let exercise = try XCTUnwrap(state.routines.first?.exercises.first)
        XCTAssertEqual(exercise.restSeconds, 90)
        XCTAssertEqual(exercise.tempo, "")
        XCTAssertNil(exercise.exerciseID)
        XCTAssertEqual(exercise.info?.id, "pull-up")
        XCTAssertTrue(state.customExercises.isEmpty)

        var saved = state
        saved.customExercises = [CustomExercise(name: "Tirage perso", muscle: .back, equipment: .cable)]
        let back = try JSONDecoder().decode(FitnessState.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(back.customExercises.first?.name, "Tirage perso")
        XCTAssertEqual(back.customExercises.first?.muscle, .back)
    }

    func testTheNextSessionIsAnnounced() {
        var state = FitnessState()
        state.routines = [Routine(name: "Push", exercises: [], weekdays: [1]), Routine(name: "Pull", exercises: [], weekdays: [4])]
        // Tuesday 29 September 2026: next is Thursday's Pull.
        let tuesday = DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 9))!
        let next = FitnessMath.nextPlanned(after: tuesday, state)
        XCTAssertEqual(next?.routine.name, "Pull")
        XCTAssertEqual(next.map { FitnessMath.isoWeekday($0.day) }, 4)
    }
}
