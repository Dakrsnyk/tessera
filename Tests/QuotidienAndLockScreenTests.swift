import XCTest
@testable import Tessera

/// Mon Quotidien editing (one source of truth, recalculations), the gender options, the rating
/// request, the Lock Screen workout and the interactive widgets.
@MainActor
final class QuotidienAndLockScreenTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppModel(store: SharedStore(directory: directory))
    }

    // MARK: Gender

    func testEveryGenderCanBeChosenAndKeptAfterSaving() throws {
        for sex in BodySex.allCases {
            var profile = UserProfile()
            profile.sex = sex
            profile.genderDetail = sex == .other ? "Genderfluid" : ""
            let data = try JSONEncoder().encode(profile)
            let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
            XCTAssertEqual(decoded.sex, sex)
            XCTAssertEqual(decoded.genderDetail, profile.genderDetail)
        }
        // An older profile with only female/male still reads.
        let old = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"sex":"female"}"#.utf8))
        XCTAssertEqual(old.sex, .female)
        XCTAssertNil(old.calculationSex)
    }

    func testNonBinaryAnswersUseTheAverageOrTheChosenReference() throws {
        let female = NutritionCalculator.goals(sex: .female, age: 30, heightCm: 170, weightKg: 70, activity: .light, goal: .maintain)
        let male = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 170, weightKg: 70, activity: .light, goal: .maintain)
        let neutral = NutritionCalculator.goals(sex: .neutral, age: 30, heightCm: 170, weightKg: 70, activity: .light, goal: .maintain)
        XCTAssertGreaterThan(neutral.kcal, female.kcal)
        XCTAssertLessThan(neutral.kcal, male.kcal)

        var profile = UserProfile()
        profile.sex = .nonBinary
        XCTAssertEqual(profile.calculatorSex, .neutral)
        profile.calculationSex = .female
        XCTAssertEqual(profile.calculatorSex, .female)
        profile.sex = .male
        XCTAssertEqual(profile.calculatorSex, .male, "A binary answer is used as it is")
        profile.sex = nil
        XCTAssertNil(profile.calculatorSex)
    }

    // MARK: One source of truth

    func testCalculatedTargetsFollowTheWeightUntilTypedByHand() throws {
        let model = temporaryModel()
        model.setAge(30)
        model.setWeight(80)
        model.update(\.profile) {
            $0.heightCm = 178
            $0.sex = .male
        }
        let first = try XCTUnwrap(model.calculatedNutritionGoals(activity: .moderate))
        model.setNutritionGoals(first, calculatedWith: .moderate)
        XCTAssertEqual(model.nutrition.goals.kcal, first.kcal)

        // A new weight, changed from Nutrition or from « Mes informations » (the same data): the targets follow.
        model.setWeight(78)
        XCTAssertEqual(model.profile.weightKg, 78)
        XCTAssertLessThan(model.nutrition.goals.kcal, first.kcal)
        XCTAssertEqual(model.nutrition.goals.protein, (78 * 1.6).rounded())

        // A target typed by hand is the user's own: a later weight no longer changes it.
        model.setNutritionTargets(kcal: 2_600)
        XCTAssertNil(model.profile.calculatedActivity)
        model.setWeight(75)
        XCTAssertEqual(model.nutrition.goals.kcal, 2_600)
    }

    func testEveryMiniAppOffersItsOwnSettings() {
        for app in MiniApp.allCases {
            XCTAssertFalse(app.settingsItems.isEmpty, "\(app) has nothing to change")
        }
        XCTAssertEqual(MiniApp.nutrition.settingsTopic, .nutrition)
        XCTAssertEqual(MiniApp.fitness.settingsTopic, .sport)
        XCTAssertTrue(MiniApp.nutrition.settingsItems.contains(.weight))
        XCTAssertTrue(MiniApp.fitness.settingsItems.contains(.routines))
    }

    // MARK: Mon Quotidien cards

    func testTheViewChosenOnACardIsKept() throws {
        var settings = AppSettings()
        settings.dailyCardPages = ["nutrition": 2, "water": 1]
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.dailyCardPages, ["nutrition": 2, "water": 1])
        let old = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(old.dailyCardPages.isEmpty)
    }

    // MARK: Rating

    func testTheRatingWaitsForAFewOpeningsThenIsAskedOnce() {
        var settings = AppSettings()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for index in 0..<4 {
            ReviewPrompt.countOpen(&settings, at: start.addingTimeInterval(Double(index) * 5 * 3600))
        }
        XCTAssertEqual(settings.openCount, 4)
        XCTAssertFalse(ReviewPrompt.shouldAsk(settings, version: "1"))
        // Coming back a few minutes later is the same opening.
        ReviewPrompt.countOpen(&settings, at: start.addingTimeInterval(3 * 5 * 3600 + 600))
        XCTAssertEqual(settings.openCount, 4)
        ReviewPrompt.countOpen(&settings, at: start.addingTimeInterval(4 * 5 * 3600))
        XCTAssertEqual(settings.openCount, ReviewPrompt.opensBeforeAsking)
        XCTAssertTrue(ReviewPrompt.shouldAsk(settings, version: "1"))
        ReviewPrompt.markAsked(&settings, version: "1")
        XCTAssertFalse(ReviewPrompt.shouldAsk(settings, version: "1"), "Asked once")
        XCTAssertTrue(ReviewPrompt.shouldAsk(settings, version: "2"), "Asked again for a new major version")
    }

    func testGoodMomentsAreAWorkoutFinishedAndAGoalReached() {
        let model = temporaryModel()
        let start = model.goodMoments
        // A set done is not yet a good moment; the workout recorded is.
        let routine = Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 5, weight: 100)])
        model.update(\.fitness) { $0.startSession(routine, at: Date()) }
        model.update(\.fitness) { _ = $0.active?.completeSet(at: Date()) }
        XCTAssertEqual(model.goodMoments, start)
        model.update(\.fitness) { $0.finishActive(at: Date()) }
        XCTAssertEqual(model.goodMoments, start + 1)

        // The calorie goal of the day reached (within 10 %), once.
        model.update(\.nutrition) { $0.goals.kcal = 500 }
        let food = FoodItem(id: "test.food", name: "Riz", brand: nil, kcal: 100, protein: 2, carbs: 22, fat: 0.3, fiber: 0.4,
                            servingGrams: 100, servingName: "", source: .custom, barcode: nil)
        model.update(\.nutrition) { $0.log(food, grams: 300, meal: .lunch) }
        XCTAssertEqual(model.goodMoments, start + 1, "300 kcal of 500: not yet")
        model.update(\.nutrition) { $0.log(food, grams: 180, meal: .dinner) }
        XCTAssertEqual(model.goodMoments, start + 2, "480 kcal of 500: reached")
        model.update(\.nutrition) { $0.log(food, grams: 10, meal: .snack) }
        XCTAssertEqual(model.goodMoments, start + 2, "Still on target: no second time")

        // A savings goal reached.
        model.update(\.budget) { $0.goals = [SavingsGoal(name: "Vélo", target: 800, saved: 750)] }
        XCTAssertEqual(model.goodMoments, start + 2)
        model.update(\.budget) { $0.goals[0].saved = 800 }
        XCTAssertEqual(model.goodMoments, start + 3)
    }

    // MARK: Lock Screen workout

    func testTheLiveActivityShowsTheSetAndTheRest() throws {
        var state = FitnessState()
        XCTAssertNil(WorkoutLiveActivity.content(for: state), "No session, no Live Activity")
        let routine = Routine(name: "Haut du corps", exercises: [
            ExerciseTemplate(name: "Développé couché", sets: 3, reps: 8, weight: 60, restSeconds: 90),
            ExerciseTemplate(name: "Tractions", sets: 3, reps: 6, weight: 0),
        ])
        let now = Date()
        state.startSession(routine, at: now)
        var content = try XCTUnwrap(WorkoutLiveActivity.content(for: state, now: now))
        XCTAssertEqual(content.0.routineName, "Haut du corps")
        XCTAssertEqual(content.1.exercise, "Développé couché")
        XCTAssertEqual(content.1.setNumber, 1)
        XCTAssertEqual(content.1.load, "8 × 60 kg")
        XCTAssertFalse(content.1.isResting(at: now))

        state.completeNextSet(at: now)
        content = try XCTUnwrap(WorkoutLiveActivity.content(for: state, now: now.addingTimeInterval(10)))
        XCTAssertEqual(content.1.setNumber, 2)
        XCTAssertEqual(content.1.doneSets, 1)
        XCTAssertTrue(content.1.isResting(at: now.addingTimeInterval(10)))
        XCTAssertEqual(try XCTUnwrap(content.1.restEnd).timeIntervalSince(now), 90, accuracy: 1)
    }

    // MARK: Interactive widgets

    func testInteractiveWidgetsAreMarked() {
        for kind in [WidgetKind.nextSet, .restTimer, .tasks, .habits, .hydration, .caloriesLeft] {
            XCTAssertTrue(kind.isInteractive, "\(kind) should carry the interactive badge")
        }
        XCTAssertFalse(WidgetKind.clock.isInteractive)
        XCTAssertTrue(KindCatalog.all.contains { $0.kind.supportsLockScreen && $0.kind.isInteractive }, "The Lock Screen category has interactive widgets")
    }
}
