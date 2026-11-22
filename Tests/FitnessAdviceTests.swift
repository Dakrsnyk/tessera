import XCTest
@testable import Ardane

/// The Fitness questions follow the person (2026-11-22): goals that fit the body first, none unsafe for a minor,
/// and sessions a week that fit the level, the goal and the age.
final class FitnessAdviceTests: XCTestCase {
    func testBodyMassIndex() throws {
        XCTAssertNil(FitnessAdvice.bmi(weightKg: 80, heightCm: nil))
        XCTAssertNil(FitnessAdvice.bmi(weightKg: nil, heightCm: 180))
        XCTAssertEqual(try XCTUnwrap(FitnessAdvice.bmi(weightKg: 81, heightCm: 180)), 25, accuracy: 0.01)
    }

    func testGoalsFollowTheBodyAndTheAge() {
        XCTAssertEqual(FitnessAdvice.goals(bmi: nil, isMinor: false), FitnessGoal.displayOrder, "Unknown body: the usual list")
        XCTAssertEqual(FitnessAdvice.goals(bmi: 22, isMinor: false), FitnessGoal.displayOrder)
        let heavier = FitnessAdvice.goals(bmi: 29, isMinor: false)
        XCTAssertEqual(Array(heavier.prefix(2)), [.weightLoss, .recomposition])
        XCTAssertEqual(Set(heavier), Set(FitnessGoal.displayOrder), "Nothing is hidden for an adult")
        XCTAssertEqual(Array(FitnessAdvice.goals(bmi: 17, isMinor: false).prefix(2)), [.muscleGain, .bulk])
        let minor = FitnessAdvice.goals(bmi: 17, isMinor: true)
        XCTAssertFalse(minor.contains(.cut))
        XCTAssertFalse(minor.contains(.bulk))
        XCTAssertEqual(minor.first, .muscleGain)
    }

    func testSessionsFollowTheLevelTheGoalAndTheAge() {
        XCTAssertNil(FitnessAdvice.sessions(level: nil, goal: .strength, age: 30, isMinor: false))
        XCTAssertEqual(FitnessAdvice.sessions(level: .beginner, goal: nil, age: 30, isMinor: false), 2...3)
        XCTAssertEqual(FitnessAdvice.sessions(level: .intermediate, goal: .strength, age: 30, isMinor: false), 3...4)
        XCTAssertEqual(FitnessAdvice.sessions(level: .advanced, goal: .endurance, age: 30, isMinor: false), 4...6)
        XCTAssertEqual(FitnessAdvice.sessions(level: .advanced, goal: nil, age: 65, isMinor: false), 3...3, "At most 3 from 60")
        XCTAssertEqual(FitnessAdvice.sessions(level: .advanced, goal: .performance, age: 16, isMinor: true), 4...4, "At most 4 under 18")
    }
}
