import XCTest
@testable import Ardane

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
        XCTAssertEqual(steps.map(\.rawValue),
                       ["welcome", "daily", "planning", "studies", "info", "create", "studio", "store", "mine", "homeScreen", "finish"],
                       "L'ordre du tutoriel")
        XCTAssertEqual(steps.first, .welcome)
        XCTAssertEqual(steps.last, .finish)
        XCTAssertEqual(Set(steps.map(\.tab)), [.home, .spaces, .explore, .mine], "Chaque onglet est montré")
        for (index, step) in steps.enumerated() {
            XCTAssertEqual(step.number, index + 1)
            XCTAssertEqual(step.next, index + 1 < steps.count ? steps[index + 1] : nil)
            XCTAssertFalse(step.message.isEmpty)
            XCTAssertFalse(step.title.isEmpty)
            XCTAssertFalse(step.place(name: "Mathys").isEmpty)
            XCTAssertFalse(step.place(name: "").isEmpty)
            XCTAssertFalse(step.symbol.isEmpty)
        }
    }

    func testTheNameArrivesOnMonQuotidienNotOnTheFirstSlide() {
        for step in TutorialStep.allCases {
            let withName = [step.title, step.message, step.place(name: "Mathys")].joined(separator: " ")
            if step == .daily {
                XCTAssertTrue(step.place(name: "Mathys").contains("Mathys"), "Le prénom est sur la 2e diapositive")
                XCTAssertFalse(step.place(name: "").contains("Mathys"))
                XCTAssertFalse(step.place(name: "").isEmpty, "Sans prénom : « Bonjour » seul")
            } else {
                XCTAssertFalse(withName.contains("Mathys"), "Le prénom n'est que sur Mon Quotidien (\(step.rawValue))")
            }
        }
        XCTAssertEqual(TutorialStep.welcome.title, "Bienvenue !")
        XCTAssertEqual(TutorialStep.daily.place(name: "Mathys"), "Bonjour Mathys")
        XCTAssertEqual(TutorialStep.daily.place(name: ""), "Bonjour")
    }

    func testEveryNameOfTheScreenshotsStillOpensAStep() {
        // The CI screenshots open « tutorial-<name> »: none of these may stop working.
        for name in ["welcome", "daily", "info", "create", "studio", "store", "mine", "homeScreen", "finish"] {
            XCTAssertNotNil(TutorialStep(rawValue: name), name)
        }
    }

    func testStepsLightUpTheirPartsOrNothing() {
        XCTAssertTrue(TutorialStep.welcome.targets.isEmpty)
        XCTAssertTrue(TutorialStep.studio.targets.isEmpty)
        XCTAssertEqual(TutorialStep.planning.targets, [[.dailyPlanning], [.dailyPlanningTop]])
        XCTAssertEqual(TutorialStep.finish.targets, [[.profile]])
        // Mon Quotidien: the whole section first, then smaller parts down to the title alone.
        XCTAssertEqual(TutorialStep.daily.targets.first, [.daily])
        XCTAssertEqual(TutorialStep.daily.targets.last, [.dailyHeader])
        for step in TutorialStep.allCases {
            XCTAssertFalse(step.targets.contains { $0.isEmpty }, "Pas de groupe vide (\(step.rawValue))")
        }
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
