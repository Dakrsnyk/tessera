import XCTest
@testable import Tessera

/// « Mes informations »: one home per value, reused everywhere, and nothing shown that wasn't given.
@MainActor
final class ProfileTests: XCTestCase {
    /// A model on its own empty store, so tests never touch the real data.
    private func temporaryModel(prepare: (SharedStore) -> Void = { _ in }) -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SharedStore(directory: directory)
        prepare(store)
        return AppModel(store: store)
    }

    func testProfilesFromOtherVersionsDecode() throws {
        let json = #"{"interests":["sport","astrology","nutrition"],"weightKg":80,"provided":["kcalTarget","somethingNew"]}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.interests, [.sport, .nutrition])
        XCTAssertEqual(profile.weightKg, 80)
        XCTAssertEqual(profile.provided, [.kcalTarget])
        XCTAssertNil(profile.heightCm)
        let empty = try JSONDecoder().decode(UserProfile.self, from: Data("{}".utf8))
        XCTAssertTrue(empty.interests.isEmpty)
        XCTAssertFalse(empty.migrated)
    }

    func testProfileSurvivesSaving() throws {
        let sample = UserProfile.sample
        let data = try JSONEncoder().encode(sample)
        XCTAssertEqual(try JSONDecoder().decode(UserProfile.self, from: data), sample)
    }

    func testQuestionsFollowTheInterestsWithoutRepeats() {
        var profile = UserProfile()
        profile.interests = [.budget, .travel, .finance, .sport]
        XCTAssertEqual(profile.topics, [.money, .sport], "Finance and budget share one page; travel asks nothing")
        XCTAssertEqual(profile.preferredSpaces, [.budget, .travel, .investing, .markets, .fitness])
        XCTAssertEqual(profile.preferredCategories.first, .finance)
    }

    func testAgeFromTheBirthYearOrTheBirthday() throws {
        var profile = UserProfile()
        let now = Date()
        XCTAssertNil(profile.age(birthday: nil, now: now))
        profile.birthYear = DateMath.calendar.component(.year, from: now) - 30
        XCTAssertEqual(profile.age(birthday: nil, now: now), 30)
        let birthday = try XCTUnwrap(DateMath.calendar.date(byAdding: .year, value: -25, to: now)).addingTimeInterval(-86_400)
        XCTAssertEqual(profile.age(birthday: birthday, now: now), 25, "The birthday wins over the birth year")
    }

    func testWidgetDataTakesTheWeightFromTheProfile() {
        var data = DomainData()
        XCTAssertTrue(data.knowsWeight, "Example data counts as given")
        XCTAssertTrue(data.knows(.kcalTarget))
        var profile = UserProfile()
        data.apply(profile)
        XCTAssertFalse(data.knowsWeight)
        XCTAssertFalse(data.knows(.kcalTarget))
        profile.weightKg = 82
        data.apply(profile)
        XCTAssertEqual(data.fitness.bodyWeightKg, 82)
    }

    func testWidgetsNeverShowATargetTheUserDidNotGive() {
        var state = NutritionState()
        let food = FoodItem(id: "test", name: "Test", brand: nil, kcal: 200, protein: 10, carbs: 20, fat: 5, fiber: 1,
                            servingGrams: 100, servingName: "100 g", source: .custom, barcode: nil)
        let now = Date()
        state.log(food, grams: 100, meal: .lunch, at: now)
        let unknown = NutritionTiles.caloriesLeft(state, now: now, known: .init(all: false))
        XCTAssertEqual(unknown.value, TF.int(200))
        XCTAssertEqual(unknown.caption, "mangées aujourd'hui")
        XCTAssertNil(unknown.gauge)
        XCTAssertTrue(unknown.rows.allSatisfy { $0.progress == nil })
        let known = NutritionTiles.caloriesLeft(state, now: now)
        XCTAssertEqual(known.value, TF.int(2_000))
        let streak = FitnessTiles.streak(FitnessState(), now: now, knowsGoal: false)
        XCTAssertEqual(streak.value, "0")
        XCTAssertNil(streak.gauge)
        let budget = MoneyTiles.budgetLeft(BudgetState(), now: now, currency: "CAD", knowsBudget: false)
        XCTAssertEqual(budget.title, "Dépenses du mois")
    }

    func testValuesChangedInSpacesBeforeTheUpdateAreKept() {
        let model = temporaryModel { store in
            var nutrition = NutritionState()
            nutrition.goals.kcal = 2_600
            store.save(nutrition)
            var fitness = FitnessState()
            fitness.bodyWeightKg = 84
            store.save(fitness)
        }
        XCTAssertTrue(model.profile.migrated)
        XCTAssertTrue(model.profile.knows(.kcalTarget))
        XCTAssertFalse(model.profile.knows(.proteinTarget), "Still the default: never shown as the user's")
        XCTAssertFalse(model.profile.knows(.monthlyBudget))
        XCTAssertEqual(model.profile.weightKg, 84)
    }

    func testOneValueUsedEverywhere() {
        let model = temporaryModel()
        model.setWeight(80)
        XCTAssertEqual(model.domains.fitness.bodyWeightKg, 80)
        model.setWeight(78)
        XCTAssertEqual(model.domains.fitness.bodyWeightKg, 78)
        XCTAssertEqual(model.payload(for: WidgetDesign(kind: .caloriesBurned)).domains.fitness.bodyWeightKg, 78, "What the widget draws")
        model.setMonthlyBudget(1_800)
        XCTAssertTrue(model.profile.knows(.monthlyBudget))
        XCTAssertEqual(model.budget.monthlyBudget, 1_800)
        model.forget(.monthlyBudget)
        XCTAssertFalse(model.profile.knows(.monthlyBudget))
        model.setNutritionTargets(kcal: 2_500)
        XCTAssertTrue(model.profile.knows(.kcalTarget))
        XCTAssertFalse(model.profile.knows(.proteinTarget))
        XCTAssertEqual(model.nutrition.goals.kcal, 2_500)
        model.setAge(30)
        XCTAssertEqual(model.age, 30)
        model.reloadFromDisk()
        XCTAssertEqual(model.profile.weightKg, 78)
        XCTAssertEqual(model.age, 30)
        XCTAssertEqual(model.nutrition.goals.kcal, 2_500)
    }

    func testTargetsAreCalculatedOnlyFromTheUsersBody() throws {
        let model = temporaryModel()
        XCTAssertNil(model.calculatedNutritionGoals(activity: .light))
        model.setAge(30)
        model.setWeight(80)
        model.update(\.profile) {
            $0.heightCm = 180
            $0.sex = .male
        }
        let goals = try XCTUnwrap(model.calculatedNutritionGoals(activity: .moderate))
        XCTAssertGreaterThan(goals.kcal, 2_000)
        XCTAssertEqual(goals.protein, 128, "1.6 g per kg to maintain")
    }

    func testTheScanLinkOpensTheScanner() {
        XCTAssertEqual(DeepLink(url: DeepLink.scanFood.url), .scanFood)
    }
}
