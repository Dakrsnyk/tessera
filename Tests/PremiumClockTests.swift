import XCTest
@testable import Ardane

/// The cached Premium status is not trusted when the clock goes back before the last online check, and a
/// backup never gives a free account more than the free plan.
@MainActor
final class PremiumClockTests: XCTestCase {
    private func temporaryStore() -> SharedStore {
        SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    /// `hasPurchase` is the real purchase check, the one the Debug switch can't change.
    func testAClockSetBackCancelsTheCachedStatus() {
        let verified = Date()
        let state = PremiumState(isActive: true, productID: PremiumConfiguration.yearlyID,
                                 expirationDate: verified.addingTimeInterval(30 * 86_400), verifiedAt: verified)
        XCTAssertFalse(state.hasPurchase(at: verified.addingTimeInterval(-86_400)), "Clock set back one day")
        XCTAssertTrue(state.hasPurchase(at: verified.addingTimeInterval(3_600)), "One hour later, before the end")
        XCTAssertTrue(state.hasPurchase(at: verified), "Same instant")
    }

    /// « Commencer » of the free « Séance du jour »: only when a session is planned, not under way, not done; no set is done.
    func testTodaysWorkoutStartButtonAndStart() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var routine = Routine(name: "Haut", exercises: [ExerciseTemplate(name: "Développé", sets: 3, reps: 8, weight: 60)])
        var state = FitnessState()
        state.routines = [routine]
        routine.weekdays = [FitnessMath.isoWeekday(now)]
        XCTAssertFalse(state.startPlannedSession(at: now), "Nothing planned today: nothing starts")
        XCTAssertNil(FitnessTiles.todaysWorkout(state, now: now).headerButton)

        state.routines = [routine]
        XCTAssertEqual(FitnessTiles.todaysWorkout(state, now: now).headerButton?.action, .startWorkout)
        XCTAssertTrue(state.startPlannedSession(at: now))
        XCTAssertEqual(state.active?.sets.count, 0, "Starting does not do a set")
        XCTAssertNil(FitnessTiles.todaysWorkout(state, now: now).headerButton, "Under way: no button")
        XCTAssertFalse(state.startPlannedSession(at: now), "Already under way")
    }

    func testABackupDoesNotGiveMoreThanTheFreePlan() throws {
        #if DEBUG
        let previous = DebugPremium.isUnlocked
        DebugPremium.setUnlocked(false)
        defer { DebugPremium.setUnlocked(previous) }
        #endif
        let source = temporaryStore()
        source.designs = (0..<6).map { _ in WidgetDesign(kind: .clock, format: .small) }
            + [WidgetDesign(kind: .photos, format: .small)]
        var content = ContentState()
        content.habits = (0..<5).map { Habit(name: "H\($0)", symbol: "star", colorHex: "FF0000") }
        source.content = content
        let data = try DataBackup.make(store: source)

        let target = temporaryStore()
        let model = AppModel(store: target)
        XCTAssertFalse(model.isPremium)
        model.restore(try DataBackup.read(data, store: target))

        XCTAssertEqual(model.limitedDesignCount, AppModel.freeDesignLimit)
        XCTAssertEqual(model.designs.count, AppModel.freeDesignLimit + 1, "Photo widgets stay unlimited")
        XCTAssertEqual(model.content.habits.count, AppModel.freeHabitLimit)
        XCTAssertEqual(target.designs.count, AppModel.freeDesignLimit + 1)
        XCTAssertEqual(target.content.habits.count, AppModel.freeHabitLimit)
    }
}
