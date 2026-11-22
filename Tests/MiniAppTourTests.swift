import XCTest
@testable import Ardane

/// Le tutoriel de découverte des mini-apps : montré à la première ouverture seulement, marqué « vu » aussitôt,
/// indépendant d'une mini-app à l'autre, absent pour une personne qui a déjà ouvert la mini-app ou ses données,
/// et jamais plus de deux étapes.
final class MiniAppTourTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suite = "MiniAppTourTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func store() -> MiniAppTourStore { MiniAppTourStore(defaults: defaults) }

    func testFirstOpeningShowsThenNeverAgain() {
        XCTAssertTrue(store().claim("nutrition", priorOpens: 0, hasData: false))
        XCTAssertFalse(store().claim("nutrition", priorOpens: 0, hasData: false))
        XCTAssertTrue(store().isSeen("nutrition"))
    }

    func testEachMiniAppIsIndependent() {
        XCTAssertTrue(store().claim("fitness", priorOpens: 0, hasData: false))
        XCTAssertFalse(store().isSeen("car"))
        XCTAssertTrue(store().claim("car", priorOpens: 0, hasData: false))
        XCTAssertTrue(store().claim(MiniAppTourContent.habitsID, priorOpens: 0, hasData: false))
    }

    func testSeenSurvivesANewInstance() {
        store().markSeen("studies")
        XCTAssertTrue(MiniAppTourStore(defaults: defaults).isSeen("studies"))
        XCTAssertEqual(defaults.stringArray(forKey: MiniAppTourStore.key), ["studies"])
    }

    func testExistingUserGetsNoTour() {
        // Opened before the update (counter above zero when this opening is not yet counted), or data already there.
        XCTAssertFalse(store().claim("finances", priorOpens: 3, hasData: false))
        XCTAssertFalse(store().claim("travel", priorOpens: 0, hasData: true))
        // And it is marked seen: emptying the data later does not start a tour.
        XCTAssertFalse(store().claim("travel", priorOpens: 0, hasData: false))
    }

    func testControllerRunsTwoStepsThenEnds() {
        let tour = MiniAppTourController(store: store())
        XCTAssertTrue(tour.begin("photos", priorOpens: 0, hasData: false))
        XCTAssertEqual(tour.id, "photos")
        XCTAssertEqual(tour.step, 0)
        tour.next()
        XCTAssertEqual(tour.step, 1)
        tour.next()
        XCTAssertNil(tour.id)
        // Left and come back: no tour.
        XCTAssertFalse(tour.begin("photos", priorOpens: 0, hasData: false))
    }

    func testSkipEndsAndLeavingMarksSeen() {
        let tour = MiniAppTourController(store: store())
        XCTAssertTrue(tour.begin("business", priorOpens: 0, hasData: false))
        tour.end("business")
        XCTAssertNil(tour.id)
        XCTAssertTrue(store().isSeen("business"))
        // Ending another mini-app's tour changes nothing.
        XCTAssertTrue(tour.begin("car", priorOpens: 0, hasData: false))
        tour.end("business")
        XCTAssertEqual(tour.id, "car")
    }

    func testNoMoreThanTwoStepsAndEveryTourHasText() {
        for id in MiniAppTourContent.allIDs {
            let steps = MiniAppTourContent.steps(id)
            XCTAssertFalse(steps.isEmpty, id)
            XCTAssertLessThanOrEqual(steps.count, MiniAppTourContent.maxSteps, id)
            for step in steps {
                XCTAssertFalse(step.text.isEmpty, id)
                XCTAssertLessThanOrEqual(step.text.count, 80, "une phrase courte : \(id)")
            }
        }
        XCTAssertEqual(MiniAppTourContent.allIDs.count, MiniApp.allCases.count + 1)
    }
}
