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
        XCTAssertLessThan(thumb.pieces.count, sheet.pieces.count, "Fewer slices")
        XCTAssertEqual(Set(sheet.pieces.map(\.part)), Set(thumb.pieces.map(\.part)), "The same body parts")
        XCTAssertLessThan(thumb.body.boundingRect.width * 0.9, sheet.body.boundingRect.width, "The same body, with fewer sections")
    }

    /// The body comes in slices, each at its own depth (2026-11-24): a whole trunk sorted by its middle let the backrest
    /// of an incline bench be painted over the shoulders lying on it. Each muscle knows the slices it is drawn on.
    func testTheBodyComesInSlicesTheMusclesLieOn() throws {
        let demo = try XCTUnwrap(ExerciseDemos.demo(for: "x-incline-dumbbell-flyes"))
        let joints = try XCTUnwrap(demo.skeleton(at: 1))
        let built = try XCTUnwrap(Sculpt.pieces(joints: joints, camera: camera(yaw: 55, pitch: 18),
                                                muscles: DemoMuscles.forDemo("x-incline-dumbbell-flyes"), fine: true))
        let trunk = built.pieces.filter { $0.part == Sculpt.Part.trunk }
        XCTAssertEqual(trunk.count, 26)
        let depths = trunk.map(\.depth)
        XCTAssertGreaterThan(try XCTUnwrap(depths.max()) - (try XCTUnwrap(depths.min())), 0.15,
                             "Lying on the bench, the shoulders are farther than the hips")
        XCTAssertEqual(built.pieces.filter { $0.part == Sculpt.Part.limb("thigh", -1) }.count, 12)
        let skins = built.pieces.filter { if case .skin = $0.kind { return true } else { return false } }
        XCTAssertTrue(skins.allSatisfy { $0.part >= 0 && !$0.box.isNull })
        let muscles = built.pieces.filter { if case .muscle = $0.kind { return true } else { return false } }
        XCTAssertFalse(muscles.isEmpty)
        for muscle in muscles {
            XCTAssertFalse(muscle.spans.isEmpty)
            let hosts = skins.filter { skin in
                skin.spans.contains { at in muscle.spans.contains { $0.part == at.part && at.lo >= $0.lo && at.hi <= $0.hi } }
            }
            XCTAssertFalse(hosts.isEmpty, "A muscle is drawn on slices of the body")
        }
    }

    /// No limb is a flat sheet (2026-11-24): with the elbow at a right angle the forearm's front lay along the forearm,
    /// so the forearm and the hand of a runner were drawn as planes; a leg opened to the side was squashed the same way.
    func testNoLimbIsAFlatSheet() throws {
        for id in ExerciseDemos.ids {
            let demo = try XCTUnwrap(ExerciseDemos.demo(for: id), id)
            for p in [0.0, 0.33, 0.5, 0.83] {
                let joints = try XCTUnwrap(demo.skeleton(at: p), id)
                let body = try XCTUnwrap(Sculpt.Body(joints), id)
                for (key, limb) in body.limbs {
                    let span = limb.b - limb.a
                    let size = (span * span).sum().squareRoot()
                    guard size > 0.01 else { continue }
                    let axis = span / size
                    let front = limb.front - axis * (limb.front * axis).sum()
                    let away = limb.away - axis * (limb.away * axis).sum()
                    let c = Vec3(front.y * away.z - front.z * away.y, front.z * away.x - front.x * away.z,
                                 front.x * away.y - front.y * away.x)
                    let section = (c * c).sum().squareRoot()
                    XCTAssertGreaterThan(section, 0.6, "\(id) \(key) at \(p): a section of \(section) of its size")
                }
            }
        }
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
