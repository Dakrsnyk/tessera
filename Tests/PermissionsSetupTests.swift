import XCTest
@testable import Ardane

/// L'étape « Autorisations » du premier lancement et Profil › Autorisations. Logique pure : aucun service réel
/// (notifications, caméra, mouvement, calendrier) n'est touché, les états sont injectés.
@MainActor
final class PermissionsSetupTests: XCTestCase {
    private func temporaryDefaults() -> UserDefaults {
        let suite = "tessera.permissions-setup-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    // MARK: Decisions

    func testGrantedAsksNothing() {
        for explained in [false, true] {
            XCTAssertEqual(PermissionsSetup.action(state: .granted, explained: explained), PermissionStep.none)
        }
    }

    func testRefusedOnlyOffersTheSettings() {
        for explained in [false, true] {
            XCTAssertEqual(PermissionsSetup.action(state: .denied, explained: explained), .openSettings)
        }
    }

    func testUndecidedOffersTheRequestAndRemembersTheExplanation() {
        XCTAssertEqual(PermissionsSetup.action(state: .notDetermined, explained: false), .explain)
        XCTAssertEqual(PermissionsSetup.action(state: .notDetermined, explained: true), .requestDirectly)
    }

    // MARK: Memory

    func testExplanationMemoryIsPerPermissionIncludingTheCamera() {
        let defaults = temporaryDefaults()
        XCTAssertFalse(PermissionMemory.hasExplained(.camera, defaults: defaults))
        PermissionMemory.markExplained(.camera, defaults: defaults)
        XCTAssertTrue(PermissionMemory.hasExplained(.camera, defaults: defaults))
        XCTAssertFalse(PermissionMemory.hasExplained(.motion, defaults: defaults))
        XCTAssertFalse(PermissionMemory.hasExplained(.notifications, defaults: defaults))
    }

    func testSetupSeenIsRememberedOnce() {
        let defaults = temporaryDefaults()
        XCTAssertFalse(defaults.bool(forKey: PermissionsSetup.seenKey))
        PermissionsSetup.markSeen(defaults: defaults)
        PermissionsSetup.markSeen(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: PermissionsSetup.seenKey))
    }

    // MARK: Content

    func testEveryPermissionOfTheSetupHasItsTexts() {
        XCTAssertEqual(Set(PermissionsSetup.order), Set(AppPermission.allCases), "Une autorisation manque à l'écran")
        XCTAssertEqual(PermissionsSetup.order.count, Set(PermissionsSetup.order).count, "Pas de doublon")
        for permission in PermissionsSetup.order {
            XCTAssertFalse(PermissionsSetup.benefit(permission).isEmpty)
            XCTAssertFalse(permission.privacy.isEmpty)
        }
    }

    func testNotificationsComeFirst() {
        XCTAssertEqual(PermissionsSetup.order.first, .notifications)
    }

    // MARK: Order of the onboarding steps

    func testFirstSetupEndsWithThePermissions() {
        let steps = OnboardingView.orderedSteps(styleOnly: false, personalizationOnly: false, topics: [])
        XCTAssertEqual(steps, [.style, .identity, .interests, .permissions])
    }

    func testPermissionsComeAfterTheTopicPages() {
        guard let topic = ProfileTopic.allCases.first else { return XCTFail("Aucun thème") }
        let steps = OnboardingView.orderedSteps(styleOnly: false, personalizationOnly: false, topics: [topic])
        XCTAssertEqual(steps, [.style, .identity, .interests, .topic(topic), .permissions])
    }

    func testExistingInstallsDoNotSeeThePermissionsAutomatically() {
        XCTAssertEqual(OnboardingView.orderedSteps(styleOnly: true, personalizationOnly: false, topics: []), [.style])
        let personal = OnboardingView.orderedSteps(styleOnly: false, personalizationOnly: true, topics: [])
        XCTAssertEqual(personal, [.identity, .interests])
        XCTAssertFalse(personal.contains(.permissions))
    }
}
