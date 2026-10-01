import XCTest
@testable import Tessera

/// The tutorial after the first questions: shown once to a new person, never pushed on someone who
/// already knew the app, every step in order with what it shows, and replayable.
@MainActor
final class TutorialTests: XCTestCase {
    func testANewPersonSeesItOnceAndAnEarlierInstallDoesNot() throws {
        XCTAssertFalse(AppSettings().hasSeenTutorial, "Une nouvelle installation voit le tutoriel")
        // Saved by a version without the tutorial, after the first launch: not shown again.
        let earlier = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"hasCompletedOnboarding":true}"#.utf8))
        XCTAssertTrue(earlier.hasSeenTutorial)
        // Stopped before the end of the first questions: the tutorial still follows them.
        let unfinished = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"hasCompletedOnboarding":false}"#.utf8))
        XCTAssertFalse(unfinished.hasSeenTutorial)
        // Saved, it stays seen.
        var seen = AppSettings()
        seen.hasSeenTutorial = true
        let again = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(seen))
        XCTAssertTrue(again.hasSeenTutorial)
    }

    func testTheStepsCoverTheAppInOrder() {
        let steps = TutorialStep.allCases
        XCTAssertEqual(steps.first, .welcome)
        XCTAssertEqual(steps.last, .finish)
        XCTAssertEqual(Set(steps.map(\.tab)), [.home, .spaces, .explore, .mine], "Chaque onglet est montré")
        for (index, step) in steps.enumerated() {
            XCTAssertEqual(step.number, index + 1)
            XCTAssertEqual(step.next, index + 1 < steps.count ? steps[index + 1] : nil)
            XCTAssertFalse(step.message.isEmpty)
            XCTAssertFalse(step.title(name: "Mathys").isEmpty)
        }
        XCTAssertEqual(TutorialStep.welcome.title(name: "Mathys"), "Bienvenue, Mathys !")
        XCTAssertEqual(TutorialStep.welcome.title(name: ""), "Bienvenue !")
    }

    func testStartingAgainOpensTheFirstStepOnHome() {
        let router = Router()
        router.tab = .mine
        router.homePath = [.info]
        router.isProfilePresented = true
        router.startTutorial()
        XCTAssertEqual(router.tutorialStep, .welcome)
        XCTAssertEqual(router.tab, .home)
        XCTAssertTrue(router.homePath.isEmpty)
        XCTAssertFalse(router.isProfilePresented)
    }

    func testTargetsReportOnlyRealMoves() {
        let frames = TutorialFrames()
        frames.update(.daily, CGRect(x: 20, y: 100, width: 300, height: 200))
        frames.update(.daily, CGRect(x: 20.2, y: 100.1, width: 300, height: 200))
        XCTAssertEqual(frames.frames[.daily], CGRect(x: 20, y: 100, width: 300, height: 200), "Un déplacement de moins d'un demi-point est ignoré")
        frames.update(.daily, CGRect(x: 20, y: 60, width: 300, height: 200))
        XCTAssertEqual(frames.frames[.daily]?.minY, 60)
    }
}
