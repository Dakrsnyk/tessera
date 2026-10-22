import XCTest
@testable import Tessera

/// Permissions iOS: an explanation before the system prompt, a refusal respected. Pure logic only: the real
/// services (notifications, calendar, position, motion) are never touched, the states are injected.
@MainActor
final class PermissionTests: XCTestCase {
    private func temporaryDefaults() -> UserDefaults {
        let suite = "tessera.permission-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    // MARK: Decision

    func testNeverExplainedAndNotAskedExplainsFirst() {
        XCTAssertEqual(PermissionPolicy.step(state: .notDetermined, explained: false), .explain)
    }

    func testAlreadyExplainedAndNotAskedAsksTheSystemDirectly() {
        XCTAssertEqual(PermissionPolicy.step(state: .notDetermined, explained: true), .requestDirectly)
    }

    func testRefusedOffersTheSettingsWhateverWasExplained() {
        XCTAssertEqual(PermissionPolicy.step(state: .denied, explained: false), .openSettings)
        XCTAssertEqual(PermissionPolicy.step(state: .denied, explained: true), .openSettings)
    }

    func testGrantedDoesNothing() {
        XCTAssertEqual(PermissionPolicy.step(state: .granted, explained: false), PermissionStep.none)
        XCTAssertEqual(PermissionPolicy.step(state: .granted, explained: true), PermissionStep.none)
    }

    func testNoStateEverGoesStraightToThePromptWithoutExplanation() {
        for state in [PermissionState.notDetermined, .granted, .denied] {
            XCTAssertNotEqual(PermissionPolicy.step(state: state, explained: false), .requestDirectly)
        }
    }

    // MARK: Memory

    func testExplanationIsRememberedPerPermission() {
        let defaults = temporaryDefaults()
        for permission in AppPermission.allCases {
            XCTAssertFalse(PermissionMemory.hasExplained(permission, defaults: defaults))
        }
        PermissionMemory.markExplained(.calendar, defaults: defaults)
        XCTAssertTrue(PermissionMemory.hasExplained(.calendar, defaults: defaults))
        XCTAssertFalse(PermissionMemory.hasExplained(.motion, defaults: defaults), "Another permission is explained on its own")
        XCTAssertFalse(PermissionMemory.hasExplained(.notifications, defaults: defaults))
    }

    func testMarkingTwiceKeepsOneEntry() {
        let defaults = temporaryDefaults()
        PermissionMemory.markExplained(.location, defaults: defaults)
        PermissionMemory.markExplained(.location, defaults: defaults)
        XCTAssertEqual(defaults.stringArray(forKey: PermissionMemory.key), [AppPermission.location.rawValue])
    }

    func testFullFlowAsksOnceThenDirectly() {
        let defaults = temporaryDefaults()
        let permission = AppPermission.notifications
        // First action of the person: the explanation.
        XCTAssertEqual(PermissionPolicy.step(state: .notDetermined, explained: PermissionMemory.hasExplained(permission, defaults: defaults)), .explain)
        PermissionMemory.markExplained(permission, defaults: defaults)
        // The system left the choice open (prompt dismissed): next time, no new explanation.
        XCTAssertEqual(PermissionPolicy.step(state: .notDetermined, explained: PermissionMemory.hasExplained(permission, defaults: defaults)), .requestDirectly)
        // Refused afterwards: the settings, never another prompt.
        XCTAssertEqual(PermissionPolicy.step(state: .denied, explained: PermissionMemory.hasExplained(permission, defaults: defaults)), .openSettings)
    }

    // MARK: Texts

    func testEveryPermissionHasItsExplanation() {
        for permission in AppPermission.allCases {
            XCTAssertFalse(permission.title.isEmpty)
            XCTAssertFalse(permission.symbol.isEmpty)
            XCTAssertFalse(permission.why.isEmpty)
            XCTAssertFalse(permission.privacy.isEmpty)
        }
        XCTAssertEqual(Set(AppPermission.allCases.map(\.rawValue)).count, AppPermission.allCases.count)
    }

    // MARK: Steps

    func testStepsAreNotReadBeforeThePersonChooses() {
        // The home screen's plain refresh must not reach the pedometer (and so the prompt) while access was never asked.
        XCTAssertFalse(StepCounter.canQuery(.notAsked, asking: false))
        XCTAssertTrue(StepCounter.canQuery(.notAsked, asking: true))
    }

    func testStepsAreReadWhenAllowedAndNeverWhenRefusedOrMissing() {
        XCTAssertTrue(StepCounter.canQuery(.allowed, asking: false))
        XCTAssertTrue(StepCounter.canQuery(.allowed, asking: true))
        XCTAssertFalse(StepCounter.canQuery(.denied, asking: true), "A refusal is respected: no new request")
        XCTAssertFalse(StepCounter.canQuery(.denied, asking: false))
        XCTAssertFalse(StepCounter.canQuery(.unavailable, asking: true))
    }
}
