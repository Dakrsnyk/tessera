import SwiftUI
import XCTest
@testable import Ardane

/// The sculpted plastic mannequin of the demonstrations (CEO, 2026-11-23): every demonstration carries its skeleton,
/// the body builds from it, and the muscles of the exercise are the ones lit.
final class SculptMannequinTests: XCTestCase {
    private func camera(yaw: Double = 90, pitch: Double = 4) -> Sculpt.Camera {
        let (R, U, B) = DemoRenderer.basis(yaw: yaw, pitch: pitch)
        return Sculpt.Camera(project: { v in
            (CGPoint(x: 200 + (v * R).sum() * 200, y: 380 - (v * U).sum() * 200), -(v * B).sum())
        }, toward: B, scale: 200)
    }

    func testEveryDemonstrationHasItsSkeleton() throws {
        for id in ExerciseDemos.ids {
            let demo = try XCTUnwrap(ExerciseDemos.demo(for: id), id)
            XCTAssertEqual(demo.skeletonFrames.count, demo.samples, id)
            let joints = try XCTUnwrap(demo.skeleton(at: 0.5), id)
            XCTAssertEqual(joints.count, 26, id)
            XCTAssertTrue(joints.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }, id)
            XCTAssertNotNil(Sculpt.Body(joints), id)
        }
        // The new movements of the triage (2026-11-24) are in it, with their own skeleton.
        XCTAssertGreaterThanOrEqual(ExerciseDemos.ids.filter { $0.hasPrefix("x-") }.count, 75)
    }

    func testTheMannequinIsBuiltWithItsMusclesLit() throws {
        let demo = try XCTUnwrap(ExerciseDemos.demo(for: "anatomy-chest"))
        let joints = try XCTUnwrap(demo.skeleton(at: 0.25))
        let lit = DemoMuscles.forDemo("anatomy-chest")
        XCTAssertEqual(lit.primary, ["chest"])
        let built = try XCTUnwrap(Sculpt.pieces(joints: joints, camera: camera(), muscles: lit, fine: true))
        let skins = built.pieces.filter { if case .skin = $0.kind { return true } else { return false } }
        let red = built.pieces.filter { if case let .muscle(level, _) = $0.kind { return level == 2 } else { return false } }
        XCTAssertGreaterThan(skins.count, 10, "Trunk, neck, head, limbs, joints, hands, feet")
        XCTAssertEqual(red.count, 2, "Both pectorals, seen from the front")
        XCTAssertFalse(built.body.isEmpty)
    }

    func testTheBackIsHiddenFromTheFront() throws {
        let demo = try XCTUnwrap(ExerciseDemos.demo(for: "anatomy-back"))
        let joints = try XCTUnwrap(demo.skeleton(at: 0.25))
        let front = try XCTUnwrap(Sculpt.pieces(joints: joints, camera: camera(yaw: 90), muscles: DemoMuscles(primary: ["back"]), fine: false))
        let back = try XCTUnwrap(Sculpt.pieces(joints: joints, camera: camera(yaw: -90), muscles: DemoMuscles(primary: ["back"]), fine: false))
        func lit(_ pieces: [Sculpt.Piece]) -> Int {
            pieces.filter { if case let .muscle(level, _) = $0.kind { return level == 2 } else { return false } }.count
        }
        XCTAssertGreaterThan(lit(back.pieces), lit(front.pieces), "The latissimus faces the back")
    }

    func testThumbnailsDrawALighterMannequin() throws {
        let demo = try XCTUnwrap(ExerciseDemos.demo(for: "db-curl"))
        let joints = try XCTUnwrap(demo.skeleton(at: 0.5))
        let lit = DemoMuscles.forDemo("db-curl")
        let sheet = try XCTUnwrap(Sculpt.pieces(joints: joints, camera: camera(yaw: 35), muscles: lit, fine: true))
        let thumb = try XCTUnwrap(Sculpt.pieces(joints: joints, camera: camera(yaw: 35), muscles: lit, fine: false))
        XCTAssertEqual(sheet.pieces.count, thumb.pieces.count, "The same pieces")
        XCTAssertLessThan(thumb.body.boundingRect.width * 0.9, sheet.body.boundingRect.width, "The same body, with fewer sections")
    }

    func testTheExerciseMusclesMapToTheMannequin() {
        let bench = DemoMuscles(primary: [.chest], secondary: [.triceps, .shoulders])
        XCTAssertEqual(bench.primary, ["chest"])
        XCTAssertEqual(bench.secondary, ["triceps", "shoulders"])
        XCTAssertEqual(DemoMuscles.keys([.obliques]), ["abs"])
        XCTAssertEqual(DemoMuscles.keys([.fullBody]), DemoMuscles.everyGroup)
        XCTAssertTrue(DemoMuscles.keys([.heart]).isEmpty)
        let curl = DemoMuscles.forDemo("db-curl")
        XCTAssertTrue(curl.primary.contains("biceps"))
        XCTAssertTrue(curl.primary.isDisjoint(with: curl.secondary), "A muscle is red or pink, not both")
    }
}
