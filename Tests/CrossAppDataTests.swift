import XCTest
@testable import Ardane

/// What a person types once must serve everywhere, and nothing is overwritten silently (audit of the exchanges
/// between mini-apps, 2026-11-17): the study hours, the concentration goal, the Études card, the birthday, the
/// body under Nutrition, the activity level and the reset.
@MainActor
final class CrossAppDataTests: XCTestCase {
    private func temporaryStore() -> SharedStore {
        SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    private func ids(_ facts: [InfoFact]) -> [String] { facts.map(\.id) }

    // MARK: 1. The study hours are one goal

    func testTheStudyHoursOfMyParametersAreTheGoalOfStudies() {
        let store = temporaryStore()
        let model = AppModel(store: store)
        XCTAssertFalse(model.profile.knows(.studyGoal))
        XCTAssertFalse(ids(model.facts(for: .studies)).contains("hours"), "A default is never shown as given")
        model.setStudyGoal(14)
        XCTAssertEqual(model.student.weeklyStudyGoalHours, 14)
        XCTAssertTrue(model.profile.knows(.studyGoal))
        let hours = model.facts(for: .studies).first { $0.id == "hours" }
        XCTAssertNotNil(hours, "« Mes informations » reads the goal of Études")
        XCTAssertTrue(hours?.value.contains("14") == true)
        XCTAssertEqual(AppModel(store: store).student.weeklyStudyGoalHours, 14, "Saved")
    }

    func testTheOldStudyHoursAreTakenOverOnceWhenTheGoalWasNeverSet() throws {
        let store = temporaryStore()
        let old = #"{"interests":["studies"],"weeklyStudyHours":14,"migrated":true}"#
        store.save(try JSONDecoder().decode(UserProfile.self, from: Data(old.utf8)))

        let model = AppModel(store: store)
        XCTAssertEqual(model.student.weeklyStudyGoalHours, 14, "The value typed before is not lost")
        XCTAssertTrue(model.profile.knows(.studyGoal))
        XCTAssertEqual(model.profile.weeklyStudyHours, 14, "The old field stays in the file")

        // Changed afterwards: a new launch does not bring the old number back.
        model.setStudyGoal(9)
        XCTAssertEqual(AppModel(store: store).student.weeklyStudyGoalHours, 9)
    }

    func testAGoalAlreadySetIsNotReplacedByTheOldStudyHours() throws {
        let store = temporaryStore()
        let old = #"{"weeklyStudyHours":14,"migrated":true}"#
        store.save(try JSONDecoder().decode(UserProfile.self, from: Data(old.utf8)))
        var student = StudentState()
        student.weeklyStudyGoalHours = 8
        store.save(student)

        let model = AppModel(store: store)
        XCTAssertEqual(model.student.weeklyStudyGoalHours, 8)
        XCTAssertTrue(model.profile.knows(.studyGoal), "A goal set on the Révisions page counts as given")
    }

    // MARK: 2. Concentration has a home

    func testFocusWidgetsOpenStudiesWithoutChangingTheirKind() {
        func link(_ kind: WidgetKind) -> URL {
            WidgetLinks.url(for: WidgetDesign.starter(for: kind), payload: WidgetPayload(), isPremium: true, isSaved: true)
        }
        let studies = DeepLink.space(Space.student.rawValue).url
        XCTAssertEqual(link(.focus), studies)
        XCTAssertEqual(link(.deepWork), studies)
        XCTAssertEqual(WidgetKind.focus.space, .productivity, "Their space and kind do not change")
        XCTAssertEqual(WidgetKind.deepWork.space, .productivity)
        XCTAssertEqual(link(.timetable), DeepLink.space(Space.productivity.rawValue).url, "The schedule still opens Planning")
    }

    func testTheConcentrationQuestionIsAskedOnceAndOnlyInStudies() {
        let model = AppModel(store: temporaryStore())
        model.update(\.profile) { $0.interests = [.productivity, .studies] }
        model.setFocusGoal(6)
        XCTAssertTrue(ids(model.facts(for: .studies)).contains("focus"))
        XCTAssertFalse(ids(model.facts(for: .productivity)).contains("focus"))
        XCTAssertTrue(MiniApp.studies.infoTopics.contains(.studies))
        XCTAssertFalse(MiniApp.planning.infoTopics.contains(.studies))
        XCTAssertEqual(MiniApp.planning.infoTopics, [.productivity])
        let topics = MiniApp.allCases.flatMap(\.infoTopics)
        XCTAssertEqual(topics.count, Set(topics).count, "A topic of « Mes paramètres » appears once")
    }

    // MARK: 3. A card with classes is never empty

    func testTheStudiesCardSaysSomethingWhenThereAreClassesOnly() {
        let model = AppModel(store: temporaryStore())
        let now = Date()
        XCTAssertNil(MiniAppSummary.caption(.studies, model, now: now), "Nothing yet: no figure")
        model.update(\.student) { $0.courses = [Course(name: "Maths"), Course(name: "Physique")] }
        let caption = MiniAppSummary.caption(.studies, model, now: now)
        XCTAssertNotNil(caption, "Classes exist: the card does not ask for them again")
        XCTAssertTrue(caption?.contains("2") == true, "\(caption ?? "")")
        let input = DailyBrief.Input(model: model, now: now, steps: nil)
        XCTAssertTrue(DailyCategories.wanted(input: input, settings: model.settings).contains(.studies))
    }

    // MARK: 4. The birthday starts from the age already given

    func testTheBirthdayStartsFromTheBirthYearKnown() {
        let model = AppModel(store: temporaryStore())
        XCTAssertEqual(DateMath.calendar.component(.year, from: model.profile.startingBirthday), 2000, "Nothing known: as before")
        model.setAge(35)
        let start = model.profile.startingBirthday
        XCTAssertEqual(DateMath.calendar.component(.year, from: start), model.profile.birthYear)
        XCTAssertEqual(DateMath.calendar.component(.month, from: start), 1)
        XCTAssertEqual(DateMath.calendar.component(.day, from: start), 1)
        model.update(\.life) { $0.birthday = start }
        XCTAssertEqual(model.age, 35, "Adding the date does not change the age the calculations use")
    }

    // MARK: 5. The body under Nutrition without Sport

    func testTheBodyShowsUnderNutritionOnlyWhenSportIsNotFollowed() {
        let model = AppModel(store: temporaryStore())
        model.setAge(30)
        model.setWeight(80)
        model.update(\.profile) { $0.heightCm = 180 }
        let body: Set<String> = ["weight", "height", "age"]

        model.update(\.profile) { $0.interests = [.nutrition] }
        XCTAssertTrue(body.isSubset(of: Set(ids(model.facts(for: .nutrition)))), "Nutrition uses them: shown there")

        model.update(\.profile) { $0.interests = [.sport, .nutrition] }
        XCTAssertTrue(body.isSubset(of: Set(ids(model.facts(for: .sport)))))
        XCTAssertTrue(body.isDisjoint(with: Set(ids(model.facts(for: .nutrition)))), "Never twice")
    }

    // MARK: 6. The activity read from the workouts keeps following them

    func testTouchingTheActivityDeducedFromWorkoutsPinsNothing() {
        let model = AppModel(store: temporaryStore())
        model.setWeeklyWorkouts(3)
        XCTAssertEqual(model.activityFromWorkouts, .light)
        XCTAssertNil(model.profile.calculatedActivity)

        model.tapNutritionActivity(.light)
        XCTAssertNil(model.profile.calculatedActivity, "The level shown came from the workouts: nothing is written")
        model.setWeeklyWorkouts(5)
        XCTAssertEqual(model.activityFromWorkouts, .moderate, "It still follows the workouts")

        model.tapNutritionActivity(.active)
        XCTAssertEqual(model.profile.calculatedActivity, .active, "Another level is a choice")
        model.tapNutritionActivity(.active)
        XCTAssertNil(model.profile.calculatedActivity, "Touched again: back to the workouts")
    }

    // MARK: 7. The reset keeps the preferences

    func testResetKeepsTheCurrencyAndTheClockLikeTheUnit() {
        let model = AppModel(store: temporaryStore())
        model.updateSettings {
            $0.currencyCode = "EUR"
            $0.uses24HourClock = false
            $0.unitSystem = .imperial
        }
        model.resetAllData()
        XCTAssertEqual(model.settings.currencyCode, "EUR")
        XCTAssertFalse(model.settings.uses24HourClock)
        XCTAssertEqual(model.settings.unitSystem, .imperial)
    }
}
