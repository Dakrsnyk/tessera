import XCTest
@testable import Ardane

/// Moving an exercise of a session changes only the order: nothing lost, nothing doubled, no field touched.
final class ExerciseReorderTests: XCTestCase {
    private func sample() -> [ExerciseTemplate] {
        [ExerciseTemplate(name: "A", sets: 3, reps: 10, weight: 20, restSeconds: 60, tempo: "3-1-1-0", notes: "a"),
         ExerciseTemplate(name: "B", sets: 4, reps: 8, weight: 50),
         ExerciseTemplate(name: "C", sets: 5, reps: 5, weight: 80, restSeconds: 120)]
    }

    private func names(_ items: [ExerciseTemplate]) -> String { items.map(\.name).joined() }

    func testMoveDownAndUp() {
        XCTAssertEqual(names(ExerciseReorder.move(sample(), from: 0, to: 2)), "BCA")
        XCTAssertEqual(names(ExerciseReorder.move(sample(), from: 2, to: 0)), "CAB")
        XCTAssertEqual(names(ExerciseReorder.move(sample(), from: 1, to: 2)), "ACB")
    }

    func testBoundsAreClampedAndBadSourceChangesNothing() {
        XCTAssertEqual(names(ExerciseReorder.move(sample(), from: 0, to: 9)), "BCA")
        XCTAssertEqual(names(ExerciseReorder.move(sample(), from: 2, to: -4)), "CAB")
        XCTAssertEqual(names(ExerciseReorder.move(sample(), from: 5, to: 0)), "ABC")
        XCTAssertEqual(names(ExerciseReorder.move(sample(), from: 1, to: 1)), "ABC")
        XCTAssertTrue(ExerciseReorder.move([ExerciseTemplate](), from: 0, to: 0).isEmpty)
    }

    func testEveryFieldIsKept() {
        let before = sample()
        let after = ExerciseReorder.move(before, from: 0, to: 2)
        XCTAssertEqual(after.count, before.count)
        XCTAssertEqual(Set(after.map(\.id)), Set(before.map(\.id)))
        for item in before { XCTAssertEqual(after.first { $0.id == item.id }, item) }
    }
}
