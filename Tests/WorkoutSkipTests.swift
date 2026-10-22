import XCTest
@testable import Tessera

/// « Passer » passes the set shown (neither done nor left to do), the workout buttons ignore a tap on a
/// drawing already out of date, the quick food add ignores a double tap, and the light tap plays only
/// for a button accepted while the app is on screen.
final class WorkoutSkipTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }

    private func makeState(sets: Int = 4, second: Bool = true) -> FitnessState {
        var state = FitnessState()
        state.weeklyGoal = 3
        var exercises = [ExerciseTemplate(name: "A", sets: sets, reps: 10, weight: 50, restSeconds: 60)]
        if second { exercises.append(ExerciseTemplate(name: "B", sets: 1, reps: 8, weight: 20, restSeconds: 60)) }
        state.routines = [Routine(name: "Haut du corps", exercises: exercises)]
        return state
    }

    private func temporaryStore() -> SharedStore {
        SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    // MARK: Passing a set

    func testSkippingTheThirdOfFourMovesToTheFourthWithoutCountingIt() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        state.completeNextSet(at: at(2))
        XCTAssertEqual(state.active?.setIndex, 2, "Set 3/4 is shown")

        XCTAssertTrue(state.skipSet(at: at(4)))
        XCTAssertEqual(state.active?.setIndex, 3, "Now 4/4")
        XCTAssertEqual(state.active?.exerciseIndex, 0)
        XCTAssertEqual(state.active?.sets.count, 2, "Nothing logged for the passed set")
        XCTAssertEqual(state.active?.skipped.count, 1)
        XCTAssertEqual(state.active?.skipped.first?.setIndex, 2)
        XCTAssertNil(state.active?.restEndsAt, "No rest after a pass")
        XCTAssertEqual(state.active?.sets.map(\.volume).reduce(0, +), 1000, "Only the two sets done count")
    }

    func testPassingTheLastSetOfAnExerciseMovesToTheNextExercise() {
        var state = makeState(sets: 2)
        state.completeNextSet(at: at(0))
        XCTAssertTrue(state.skipSet(at: at(2)))
        XCTAssertEqual(state.active?.exerciseIndex, 1, "On B")
        XCTAssertEqual(state.active?.setIndex, 0)
        XCTAssertEqual(state.active?.sets.count, 1)
    }

    func testPassingTheLastSetOfTheSessionEndsItAndKeepsTheSetsDone() {
        var state = makeState(sets: 1, second: false)
        state.completeNextSet(at: at(0))
        XCTAssertNil(state.active)
        // A session with two sets: one done, the last one passed.
        state = makeState(sets: 2, second: false)
        state.completeNextSet(at: at(0))
        XCTAssertTrue(state.skipSet(at: at(2)))
        XCTAssertNil(state.active, "The session ended")
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(state.history.first?.sets.count, 1)
        XCTAssertEqual(state.history.first?.end, at(2))
    }

    func testASessionWithNoSetDoneIsNotKeptInTheHistory() {
        var state = makeState(sets: 2, second: false)
        state.completeNextSet(at: at(0))
        // Taken back, then everything passed.
        XCTAssertTrue(state.undoLastSet(at: at(1)))
        XCTAssertTrue(state.skipSet(at: at(2)))
        XCTAssertTrue(state.skipSet(at: at(3)))
        XCTAssertNil(state.active)
        XCTAssertTrue(state.history.isEmpty, "Nothing was done: it counts for nothing")
        XCTAssertFalse(state.canUndoLastSet(at: at(4)))
    }

    func testUndoTakesBackAPassedSet() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        state.skipSet(at: at(2))
        XCTAssertEqual(state.active?.setIndex, 2)
        XCTAssertTrue(state.canUndoLastSet(at: at(3)))

        XCTAssertTrue(state.undoLastSet(at: at(3)))
        XCTAssertEqual(state.active?.setIndex, 1, "Back on the passed set")
        XCTAssertTrue(state.active?.skipped.isEmpty ?? false)
        XCTAssertEqual(state.active?.sets.count, 1, "The set done before is still done")
        XCTAssertTrue(state.undoLastSet(at: at(3)), "Then the set done")
        XCTAssertEqual(state.active?.sets.count, 0)
    }

    func testUndoAfterThePassThatEndedTheSessionBringsItBack() {
        var state = makeState(sets: 2, second: false)
        state.completeNextSet(at: at(0))
        state.skipSet(at: at(2))
        XCTAssertNil(state.active)
        XCTAssertTrue(state.canUndoLastSet(at: at(3)))

        XCTAssertTrue(state.undoLastSet(at: at(3)))
        XCTAssertTrue(state.history.isEmpty)
        XCTAssertEqual(state.active?.setIndex, 1)
        XCTAssertNil(state.active?.end)
        XCTAssertEqual(state.active?.sets.count, 1)
    }

    func testPassingWithoutASessionDoesNothing() {
        var state = makeState()
        XCTAssertFalse(state.skipSet(at: at(0)))
        XCTAssertNil(state.active)
    }

    func testASessionSavedByAnOlderVersionStillReads() throws {
        var session = WorkoutSession(routineID: nil, routineName: "Old", exercises: [], start: start)
        session.sets = []
        let data = try JSONEncoder().encode(session)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "skipped")
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(WorkoutSession.self, from: old)
        XCTAssertTrue(decoded.skipped.isEmpty)
        XCTAssertEqual(decoded.routineName, "Old")
    }

    // MARK: Fast taps

    func testAStalePositionIsIgnored() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        let drawn = state.position
        XCTAssertTrue(state.press(.completeSet, expecting: drawn, at: at(1)))
        // The second tap of a double tap, still carrying the old drawing.
        XCTAssertFalse(state.press(.completeSet, expecting: drawn, at: at(1)))
        XCTAssertFalse(state.press(.skipSet, expecting: drawn, at: at(1)))
        XCTAssertFalse(state.press(.undoSet, expecting: drawn, at: at(1)))
        XCTAssertEqual(state.active?.sets.count, 2, "Counted once")
        XCTAssertTrue(state.active?.skipped.isEmpty ?? false)
    }

    func testAStaleSkipIsIgnored() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        let drawn = state.position
        XCTAssertTrue(state.press(.skipSet, expecting: drawn, at: at(1)))
        XCTAssertFalse(state.press(.skipSet, expecting: drawn, at: at(1)))
        XCTAssertEqual(state.active?.skipped.count, 1, "Passed once")
        XCTAssertEqual(state.active?.setIndex, 2)
    }

    func testButtonOfAnOlderVersionWithoutPositionStillActs() {
        var state = makeState()
        state.completeNextSet(at: at(0))
        XCTAssertTrue(state.press(.completeSet, expecting: nil, at: at(1)))
        XCTAssertEqual(state.active?.sets.count, 2)
    }

    func testPositionRoundTripsThroughAnIntentToken() throws {
        var state = makeState()
        state.completeNextSet(at: at(0))
        let position = state.position
        XCTAssertEqual(WorkoutPosition(token: position.token), position)
        XCTAssertEqual(WorkoutPosition(token: WorkoutPosition.noSession.token), WorkoutPosition.noSession)
        XCTAssertNil(WorkoutPosition(token: "n'importe quoi"))
    }

    // MARK: The intents' path (widget, Lock Screen, notification)

    func testWorkoutButtonsThroughTheStore() {
        let store = temporaryStore()
        var state = makeState()
        state.completeNextSet(at: at(0))
        store.save(state)
        let drawn = store.state(FitnessState.self).position

        XCTAssertTrue(WorkoutButtons.apply(.skipSet, expecting: drawn, store: store, at: at(1)))
        XCTAssertFalse(WorkoutButtons.apply(.skipSet, expecting: drawn, store: store, at: at(1)), "Double tap")
        let saved = store.state(FitnessState.self)
        XCTAssertEqual(saved.active?.skipped.count, 1)
        XCTAssertEqual(saved.active?.setIndex, 2)

        XCTAssertTrue(WorkoutButtons.apply(.undoSet, expecting: saved.position, store: store, at: at(2)))
        XCTAssertEqual(store.state(FitnessState.self).active?.setIndex, 1)
    }

    func testConcurrentTapsOnTheStoreCountOnce() {
        let store = temporaryStore()
        var state = makeState(sets: 10)
        state.completeNextSet(at: at(0))
        store.save(state)
        let drawn = store.state(FitnessState.self).position

        let group = DispatchGroup()
        for _ in 0..<8 {
            DispatchQueue.global().async(group: group) {
                WorkoutButtons.apply(.completeSet, expecting: drawn, store: store, at: self.at(1))
            }
        }
        group.wait()
        XCTAssertEqual(store.state(FitnessState.self).active?.sets.count, 2, "One set more, not eight")
    }

    // MARK: Light tap

    func testTheLightTapPlaysOnlyForAnAcceptedButtonWhileTheAppIsOnScreen() {
        XCTAssertTrue(ButtonFeedback.shouldPlay(accepted: true, appIsActive: true))
        XCTAssertFalse(ButtonFeedback.shouldPlay(accepted: true, appIsActive: false))
        XCTAssertFalse(ButtonFeedback.shouldPlay(accepted: false, appIsActive: true))
        XCTAssertFalse(ButtonFeedback.shouldPlay(accepted: false, appIsActive: false))
    }

    func testTheHookIsCalledOnceForAnAcceptedButtonOnly() {
        var played = 0
        ButtonFeedback.play = { played += 1 }
        defer { ButtonFeedback.play = nil }

        let store = temporaryStore()
        var state = makeState()
        state.completeNextSet(at: at(0))
        store.save(state)
        let drawn = store.state(FitnessState.self).position

        WorkoutButtons.apply(.completeSet, expecting: drawn, store: store, at: at(1))
        XCTAssertEqual(played, 1)
        WorkoutButtons.apply(.completeSet, expecting: drawn, store: store, at: at(1))
        XCTAssertEqual(played, 1, "A tap ignored makes no sound")
    }

    // MARK: Nutrition quick add

    private let apple = FoodItem(id: "test.apple", name: "Pomme", kcal: 52, protein: 0.3, carbs: 14, fat: 0.2, fiber: 2.4,
                                 servingGrams: 150, servingName: "1 pomme", source: .custom)

    func testQuickAddIgnoresADoubleTap() {
        var state = NutritionState()
        XCTAssertTrue(state.quickLog(apple, at: start))
        XCTAssertFalse(state.quickLog(apple, at: start.addingTimeInterval(1)), "Within 2 s: same tap")
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertTrue(state.quickLog(apple, at: start.addingTimeInterval(5)), "A later tap is a real second serving")
        XCTAssertEqual(state.entries.count, 2)
    }

    func testQuickAddOfAnotherFoodIsNotADuplicate() {
        var state = NutritionState()
        var pear = apple
        pear.id = "test.pear"
        XCTAssertTrue(state.quickLog(apple, at: start))
        XCTAssertTrue(state.quickLog(pear, at: start.addingTimeInterval(1)))
        XCTAssertEqual(state.entries.count, 2)
    }

    func testQuickFoodIntentPathLogsOnceForADoubleTap() {
        let store = temporaryStore()
        var state = NutritionState()
        state.favorites = [apple]
        store.save(state)

        XCTAssertTrue(QuickFood.log(foodID: apple.id, store: store, at: start))
        XCTAssertFalse(QuickFood.log(foodID: apple.id, store: store, at: start.addingTimeInterval(0.5)))
        XCTAssertFalse(QuickFood.log(foodID: "inconnu", store: store, at: start.addingTimeInterval(10)))
        XCTAssertEqual(store.state(NutritionState.self).entries.count, 1)
    }
}
