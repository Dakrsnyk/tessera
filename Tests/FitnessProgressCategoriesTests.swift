import XCTest
@testable import Ardane

final class FitnessProgressCategoriesTests: XCTestCase {
    private func set(_ name: String, reps: Int, weight: Double, id: String? = nil, at date: Date) -> SetLog {
        SetLog(exercise: name, reps: reps, weight: weight, date: date, exerciseID: id)
    }

    private func state(_ sessions: [[SetLog]]) -> FitnessState {
        var state = FitnessState()
        for (index, sets) in sessions.enumerated() {
            let start = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400)
            state.history.append(WorkoutSession(routineName: "Test", exercises: [], start: start, end: start.addingTimeInterval(3600), sets: sets))
        }
        return state
    }

    private func category(_ id: String) -> ExerciseCategory? {
        ExerciseLibrary.info(id).map(ExerciseCategory.of)
    }

    func testCategoryRules() {
        XCTAssertEqual(category("bench-press"), .chest)
        XCTAssertEqual(category("pull-up"), .back)
        XCTAssertEqual(category("air-squat"), .legs)
        XCTAssertEqual(category("plank"), .abs)
        XCTAssertEqual(category("running"), .cardio)
        XCTAssertEqual(category("hamstring-stretch"), .mobility)
    }

    func testGroupsInCategoryOrderAndEmptyOnesLeftOut() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let groups = FitnessProgressCategories.groups(state([[
            set("Course à pied", reps: 1, weight: 0, id: "running", at: d),
            set("Développé couché (barre)", reps: 8, weight: 60, id: "bench-press", at: d),
        ]]))
        XCTAssertEqual(groups.map(\.category), [.chest, .cardio])
    }

    func testTwoNamesOfTheSameExerciseMergeIntoOne() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let groups = FitnessProgressCategories.groups(state([
            [set("Développé couché (barre)", reps: 8, weight: 60, id: "bench-press", at: d)],
            [set("Développé couché (barre)", reps: 5, weight: 70, at: d)],
        ]))
        let chest = groups.first { $0.category == .chest }
        XCTAssertEqual(chest?.exercises.count, 1)
        XCTAssertEqual(chest?.exercises.first?.id, "bench-press")
        XCTAssertEqual(chest?.exercises.first?.sessionCount, 2)
        XCTAssertEqual(chest?.exercises.first?.bestWeight, 70)
        XCTAssertEqual(chest?.exercises.first?.gain, 10)
    }

    func testBodyweightCountsWithItsBestReps() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let groups = FitnessProgressCategories.groups(state([
            [set("Pompes", reps: 12, weight: 0, id: "push-up", at: d)],
            [set("Pompes", reps: 20, weight: 0, id: "push-up", at: d)],
        ]))
        let pushUp = groups.flatMap(\.exercises).first { $0.id == "push-up" }
        XCTAssertEqual(pushUp?.bestReps, 20)
        XCTAssertEqual(pushUp?.bestWeight, 0)
        XCTAssertEqual(pushUp?.gain, 0)
        XCTAssertEqual(pushUp?.sessionCount, 2)
    }

    func testUnknownExerciseGoesToOthersWithoutId() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let groups = FitnessProgressCategories.groups(state([
            [set("Zzqx machine inventée", reps: 10, weight: 30, at: d)],
        ]))
        XCTAssertEqual(groups.map(\.category), [.other])
        XCTAssertNil(groups.first?.exercises.first?.id)
        XCTAssertEqual(groups.first?.exercises.first?.name, "Zzqx machine inventée")
    }

    func testMostPractisedFirst() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let groups = FitnessProgressCategories.groups(state([
            [set("Pompes", reps: 10, weight: 0, id: "push-up", at: d), set("Développé couché (barre)", reps: 8, weight: 60, id: "bench-press", at: d)],
            [set("Pompes", reps: 10, weight: 0, id: "push-up", at: d)],
        ]))
        XCTAssertEqual(groups.first?.exercises.first?.id, "push-up")
    }
}
