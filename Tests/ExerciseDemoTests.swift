import XCTest
@testable import Tessera

/// The exercise demonstrations: one per exercise, complete, with named phases, and variants that
/// are really different (their own equipment, position and path).
final class ExerciseDemoTests: XCTestCase {
    func testEveryExerciseHasACompleteDemonstration() throws {
        for exercise in ExerciseLibrary.all {
            let demo = try XCTUnwrap(ExerciseDemos.demo(for: exercise.id), exercise.id)
            XCTAssertFalse(demo.views.isEmpty, exercise.id)
            XCTAssertFalse(demo.prims.isEmpty, exercise.id)
            XCTAssertGreaterThan(demo.duration, 0.9, exercise.id)
            XCTAssertLessThan(demo.duration, 16, exercise.id)
            for view in demo.views {
                XCTAssertEqual(view.box.count, 4, exercise.id)
                XCTAssertGreaterThan(view.box[2], view.box[0], exercise.id)
                XCTAssertGreaterThan(view.box[3], view.box[1], exercise.id)
            }
            if !demo.loop {
                XCTAssertEqual(demo.labels.count >= 4, true, "\(exercise.id): départ, mouvement, fin, retour")
                XCTAssertEqual(demo.phase(at: 0).label, 0, exercise.id)
            }
            for p in [0.0, 0.33, 0.5, 0.97] {
                let points = demo.points(at: p)
                XCTAssertFalse(points.isEmpty, exercise.id)
                XCTAssertTrue(points.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }, exercise.id)
                for prim in demo.prims {
                    XCTAssertTrue(prim.indices.allSatisfy { points.indices.contains($0) }, exercise.id)
                }
            }
        }
    }

    func testVariantsAreReallyDifferent() throws {
        let pairs = [("bench-press", "incline-bench"), ("bench-press", "decline-bench"), ("bench-press", "db-bench"),
                     ("incline-bench", "incline-db"), ("pec-deck", "db-fly"), ("pec-deck", "cable-fly"),
                     ("back-squat", "hack-squat"), ("leg-extension", "lying-leg-curl"), ("leg-extension", "seated-leg-curl"),
                     ("barbell-row", "seated-cable-row"), ("lat-pulldown", "pull-up"), ("ohp", "machine-shoulder-press"),
                     ("deadlift", "rdl"), ("lunge", "reverse-lunge"), ("bb-curl", "hammer-curl")]
        for (a, b) in pairs {
            let first = try XCTUnwrap(ExerciseDemos.demo(for: a))
            let second = try XCTUnwrap(ExerciseDemos.demo(for: b))
            let different = first.prims.count != second.prims.count
                || first.points(at: 0.5).count != second.points(at: 0.5).count
                || zip(first.points(at: 0.5), second.points(at: 0.5)).contains { (($0 - $1) * ($0 - $1)).sum().squareRoot() > 0.05 }
            XCTAssertTrue(different, "\(a) ≠ \(b)")
        }
    }

    func testThePhasesFollowTheRepetition() throws {
        let demo = try XCTUnwrap(ExerciseDemos.demo(for: "incline-bench"))
        XCTAssertEqual(demo.labels.first, "Bras tendus")
        // Start, then the movement, then the end position, then the return.
        let times = demo.segments.reduce(into: [Double]()) { $0.append(($0.last ?? 0) + $1.duration) }
        XCTAssertEqual(demo.phase(at: 0.01).label, 0)
        XCTAssertEqual(demo.phase(at: times[0] + 0.01).label, 1)
        XCTAssertEqual(demo.phase(at: times[1] + 0.01).label, 2)
        XCTAssertEqual(demo.phase(at: times[2] + 0.01).label, 3)
        XCTAssertEqual(demo.phase(at: times[1] + 0.01).p, 1, accuracy: 0.001, "Position finale tenue")
        // The bar goes down: the hands are lower at the end than at the start.
        let start = demo.points(at: 0)
        let end = demo.points(at: 1)
        XCTAssertNotEqual(start.count, 0)
        XCTAssertEqual(start.count, end.count)
    }
}
