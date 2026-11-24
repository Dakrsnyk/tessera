import XCTest
@testable import Ardane

/// CEO's request, 2026-11-23: the muscle groups shown by the body with the group in red, framed on it (scripts/demos/anatomy.py),
/// in the style of the « Progression » rows.
final class AnatomyFiguresTests: XCTestCase {
    func testEveryMuscleGroupHasItsFigureFramedOnTheMuscle() throws {
        for group in MuscleGroup.allCases {
            let demo = try XCTUnwrap(ExerciseDemos.demo(for: group.anatomyID), group.rawValue)
            XCTAssertTrue(demo.loop, "\(group): breathing in a loop")
            let view = try XCTUnwrap(demo.views.first, group.rawValue)
            XCTAssertEqual(view.box.count, 4)
            let height = view.box[3] - view.box[1]
            if group == .fullBody {
                XCTAssertNotEqual(view.close, true, "The whole body keeps the usual scale")
                XCTAssertGreaterThan(height, 1.5)
            } else {
                XCTAssertEqual(view.close, true, "\(group): a close-up")
                XCTAssertLessThan(height, 1.1, "\(group): framed on the muscle, not the whole body")
            }
        }
    }

    func testTheMuscleIsInRed() throws {
        // Role 1 is « muscle »: the strokes drawn in the accent colour, as in every exercise demonstration.
        for group in MuscleGroup.allCases {
            let demo = try XCTUnwrap(ExerciseDemos.demo(for: group.anatomyID))
            XCTAssertTrue(demo.prims.contains { $0.role == 1 }, group.rawValue)
        }
    }

    func testTheProgressCategoriesShowTheirMuscles() {
        XCTAssertEqual(ExerciseCategory.chest.anatomyID, "anatomy-chest")
        XCTAssertEqual(ExerciseCategory.legs.anatomyID, "anatomy-quads")
        XCTAssertEqual(ExerciseCategory.arms.anatomyID, "anatomy-biceps")
        XCTAssertNil(ExerciseCategory.cardio.anatomyID, "Cardio keeps its icon")
        for category in ExerciseCategory.allCases {
            if let id = category.anatomyID { XCTAssertNotNil(ExerciseDemos.demo(for: id), category.rawValue) }
        }
    }

    func testTheExerciseDemonstrationsAreUntouched() throws {
        // The anatomy figures were added to ExerciseDemos.json without rebuilding the exercises' own.
        let curl = try XCTUnwrap(ExerciseDemos.demo(for: "db-curl"))
        XCTAssertFalse(curl.views.contains { $0.close == true })
    }
}
