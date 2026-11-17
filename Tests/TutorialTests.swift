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
                       ["welcome", "daily", "create", "studio", "mine", "homeScreen", "store", "finish"],
                       "L'ordre du tutoriel : le chemin d'un widget, puis le Store")
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

    /// 2026-11-17: « Ton planning », « Études » and « Un objectif pour deux » don't explain how the app works: removed.
    /// What is left follows a widget from the app to the Home Screen, and the Store comes after.
    func testTheThreeStepsAboutMiniAppsAreGoneAndTheStoreComesAfterTheHomeScreen() throws {
        for name in ["planning", "studies", "info"] {
            XCTAssertNil(TutorialStep(rawValue: name), "L'étape « \(name) » n'existe plus")
        }
        let steps = TutorialStep.allCases
        XCTAssertEqual(steps.count, 8)
        let path: [TutorialStep] = [.create, .studio, .mine, .homeScreen, .store]
        let numbers = path.map(\.number)
        XCTAssertEqual(numbers, numbers.sorted(), "Créer, Studio, Mes widgets, écran d'accueil, puis le Store")
        XCTAssertEqual(TutorialStep.studio.number, 4)
        XCTAssertEqual(TutorialStep.store.number, 7)
        // No step talks about a mini-app in particular any more.
        for step in steps {
            let text = step.title + " " + step.message
            for word in ["Planning", "Études", "Nutrition", "Fitness"] {
                XCTAssertFalse(text.contains(word), "« \(word) » dans l'étape \(step.rawValue)")
            }
        }
        // The first two steps say how the app works: mini-apps feed the widgets, a card opens its mini-app.
        XCTAssertTrue(TutorialStep.welcome.message.contains("mini-apps"))
        XCTAssertTrue(TutorialStep.welcome.message.contains("widgets"))
        XCTAssertTrue(TutorialStep.daily.message.contains("mini-app"))
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
        for name in ["welcome", "daily", "create", "studio", "store", "mine", "homeScreen", "finish"] {
            XCTAssertNotNil(TutorialStep(rawValue: name), name)
        }
    }

    func testStepsLightUpTheirPartsOrNothing() {
        XCTAssertTrue(TutorialStep.welcome.targets.isEmpty)
        XCTAssertTrue(TutorialStep.studio.targets.isEmpty)
        XCTAssertTrue(TutorialStep.homeScreen.targets.isEmpty)
        // One part each, small enough to be lit whole above the bubble: the aisles of the Store, the widget in the
        // middle of Mes widgets (2026-11-17: the screen of the week and the whole carousel were too tall to be lit).
        XCTAssertEqual(TutorialStep.store.targets, [[.storeAisles]])
        XCTAssertEqual(TutorialStep.mine.targets, [[.myWidgets]])
        XCTAssertEqual(TutorialStep.create.targets, [[.createSpace]])
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
