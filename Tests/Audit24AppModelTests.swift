import UIKit
import XCTest
@testable import Ardane

/// Audit prépublication (chantier 24), corrections du modèle : le quota gratuit d'analyses photo survit à
/// l'effacement et à la restauration, la réinitialisation est complète, la limite de 5 habitudes tient,
/// les objectifs nutritionnels calculés restent dans les bornes de sécurité, un style Premium n'est pas
/// donné sans Premium, et une simple date de vérification n'écrit rien.
@MainActor
final class Audit24AppModelTests: XCTestCase {
    // `resetAllData` also clears what lives outside the isolated store (preferences of the process, the photos
    // of the App Group, the Stripe key): it is all put back after each test so the other tests don't notice.
    private let touchedDefaults = [StepCounter.historyKey, "miniAppOpens", "miniAppsHidden", SetupFavorites.key]
    private var savedDefaults: [String: Any] = [:]
    private var savedImages: [String: Data] = [:]
    private var savedStripeKey: String?

    override func setUp() async throws {
        savedDefaults = [:]
        for key in touchedDefaults {
            if let value = UserDefaults.standard.object(forKey: key) { savedDefaults[key] = value }
        }
        savedImages = [:]
        for name in ImageStore.allNames() {
            if let data = ImageStore.data(named: name) { savedImages[name] = data }
        }
        savedStripeKey = SecretStore.read(StripeSync.keychainAccount)
    }

    override func tearDown() async throws {
        for key in touchedDefaults {
            if let value = savedDefaults[key] { UserDefaults.standard.set(value, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) }
        }
        for (name, data) in savedImages { ImageStore.restore(data, named: name) }
        if let savedStripeKey { _ = SecretStore.save(savedStripeKey, for: StripeSync.keychainAccount) }
    }

    private func temporaryStore() -> SharedStore {
        SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    private func subscribed() -> PremiumState {
        PremiumState(isActive: true, productID: PremiumConfiguration.yearlyID,
                     expirationDate: Date().addingTimeInterval(30 * 86_400), verifiedAt: Date())
    }

    /// Runs `body` without the Debug test switch (it keeps Premium true in a Debug build), then puts it back.
    private func withoutDebugUnlock(_ body: () throws -> Void) rethrows {
        #if DEBUG
        let previous = DebugPremium.isUnlocked
        DebugPremium.setUnlocked(false)
        defer { DebugPremium.setUnlocked(previous) }
        #endif
        try body()
    }

    // MARK: Free analyses (K-03 / N-03)

    func testTheCountOfFreeAnalysesSurvivesErasingTheData() {
        let store = temporaryStore()
        let model = AppModel(store: store)
        model.update(\.nutrition) { $0.photoScansUsed = 7 }
        model.resetAllData()
        XCTAssertEqual(model.nutrition.photoScansUsed, 7, "Erasing the data doesn't give the analyses back")
        XCTAssertEqual(AppModel(store: store).nutrition.photoScansUsed, 7, "Kept on disk too")
        XCTAssertTrue(model.nutrition.entries.isEmpty)
    }

    func testTheCountOfFreeAnalysesNeverGoesDownWithABackup() throws {
        // The backup was made when 2 analyses were used; this iPhone has used 9 since.
        let source = temporaryStore()
        var old = NutritionState()
        old.photoScansUsed = 2
        source.save(old)
        let data = try DataBackup.make(store: source)

        let target = temporaryStore()
        var recent = NutritionState()
        recent.photoScansUsed = 9
        target.save(recent)
        DataBackup.restore(try DataBackup.read(data, store: target), store: target)
        XCTAssertEqual(target.state(NutritionState.self).photoScansUsed, 9)

        // A backup that holds more than this iPhone: the larger count is kept.
        var fresh = NutritionState()
        fresh.photoScansUsed = 1
        let other = temporaryStore()
        other.save(fresh)
        DataBackup.restore(try DataBackup.read(data, store: other), store: other)
        XCTAssertEqual(other.state(NutritionState.self).photoScansUsed, 2)
    }

    func testARestoredBackupWithoutNutritionStillKeepsTheCount() throws {
        let source = temporaryStore()
        source.content = ContentState()
        let data = try DataBackup.make(store: source)
        let target = temporaryStore()
        var used = NutritionState()
        used.photoScansUsed = 4
        target.save(used)
        DataBackup.restore(try DataBackup.read(data, store: target), store: target)
        XCTAssertEqual(target.state(NutritionState.self).photoScansUsed, 4)
    }

    // MARK: Full reset (K-04 / W-09)

    func testResetErasesTheStylesTheStepsAndTheMiniAppCounters() {
        let store = temporaryStore()
        let model = AppModel(store: store)
        model.saveStyle(named: "Mon thème", from: WidgetDesign(kind: .note))
        model.addHabit(Habit(name: "Lire", symbol: "book", colorHex: "7FA33A"))
        let defaults = UserDefaults.standard
        defaults.set(["2026-11-06": [1_000.0]], forKey: StepCounter.historyKey)
        defaults.set(["nutrition": 3], forKey: "miniAppOpens")
        defaults.set(["finances"], forKey: "miniAppsHidden")
        defaults.set("a,b", forKey: SetupFavorites.key)
        XCTAssertEqual(model.savedStyles.count, 1)

        model.resetAllData()

        XCTAssertTrue(model.savedStyles.isEmpty)
        XCTAssertNil(store.rawData(.styles), "« Mes styles » file removed")
        XCTAssertTrue(AppModel(store: store).savedStyles.isEmpty)
        XCTAssertTrue(model.content.habits.isEmpty)
        XCTAssertNil(defaults.object(forKey: StepCounter.historyKey))
        XCTAssertNil(defaults.object(forKey: "miniAppOpens"))
        XCTAssertNil(defaults.object(forKey: "miniAppsHidden"))
        XCTAssertNil(defaults.object(forKey: SetupFavorites.key))
    }

    // MARK: Free habits (K-05 / F-01)

    func testTheFifthHabitIsTheLastWithoutPremium() {
        withoutDebugUnlock {
            let model = AppModel(store: temporaryStore())
            for index in 1...AppModel.freeHabitLimit {
                XCTAssertTrue(model.addHabit(Habit(name: "H\(index)", symbol: "checkmark", colorHex: "7FA33A")))
            }
            XCTAssertFalse(model.canAddHabit)
            XCTAssertFalse(model.addHabit(Habit(name: "De trop", symbol: "checkmark", colorHex: "7FA33A")))
            XCTAssertEqual(model.content.habits.count, AppModel.freeHabitLimit, "Nothing is added past the limit")
            XCTAssertFalse(model.content.habits.contains { $0.name == "De trop" })

            model.updatePremium(subscribed())
            XCTAssertTrue(model.isPremium)
            XCTAssertTrue(model.addHabit(Habit(name: "Avec Premium", symbol: "checkmark", colorHex: "7FA33A")))
            XCTAssertEqual(model.content.habits.count, AppModel.freeHabitLimit + 1)
        }
    }

    // MARK: Safe nutrition targets (N-04)

    private func bodyModel(age: Int, weightKg: Double, heightCm: Double, aim: NutritionAim, stage: LifeStage? = nil) -> AppModel {
        let model = AppModel(store: temporaryStore())
        model.setAge(age)
        model.setWeight(weightKg)
        model.update(\.profile) {
            $0.heightCm = heightCm
            $0.sex = .male
            $0.nutritionAim = aim
            $0.calculatedActivity = .sedentary
            $0.lifeStage = stage
        }
        model.followCalculatedNutritionGoals()
        return model
    }

    private func maintenanceKcal(_ model: AppModel, weightKg: Double, heightCm: Double) -> Double {
        NutritionCalculator.goals(sex: .male, age: model.age ?? 0, heightCm: heightCm, weightKg: weightKg, activity: .sedentary, goal: .maintain).kcal
    }

    func testAMinorNeverGetsADeficit() {
        let model = bodyModel(age: 16, weightKg: 70, heightCm: 175, aim: .lose)
        XCTAssertEqual(model.nutritionGoal, .maintain)
        let expected = maintenanceKcal(model, weightKg: 70, heightCm: 175)
        XCTAssertEqual(model.recommendedNutritionGoals()?.kcal ?? 0, expected, accuracy: 0.5)
        XCTAssertEqual(model.nutrition.goals.kcal, expected, accuracy: 0.5)
    }

    func testALowBodyMassIndexNeverGetsADeficit() {
        // 50 kg at 1,80 m: index 15,4.
        let model = bodyModel(age: 30, weightKg: 50, heightCm: 180, aim: .lose)
        XCTAssertEqual(model.nutritionGoal, .maintain)
        XCTAssertEqual(model.recommendedNutritionGoals()?.kcal ?? 0, maintenanceKcal(model, weightKg: 50, heightCm: 180), accuracy: 0.5)
        // The same low index may still gain.
        XCTAssertEqual(bodyModel(age: 30, weightKg: 50, heightCm: 180, aim: .gain).nutritionGoal, .gain)
    }

    func testPregnancyAndBreastfeedingNeverGetADeficitOrASurplus() {
        for stage in [LifeStage.pregnant, .breastfeeding] {
            XCTAssertEqual(bodyModel(age: 30, weightKg: 70, heightCm: 170, aim: .lose, stage: stage).nutritionGoal, .maintain, "\(stage)")
            XCTAssertEqual(bodyModel(age: 30, weightKg: 70, heightCm: 170, aim: .gain, stage: stage).nutritionGoal, .maintain, "\(stage)")
        }
    }

    func testNoGainFromAnObesityIndexButAdultsKeepTheirAim() {
        // 100 kg at 1,75 m: index 32,7.
        XCTAssertEqual(bodyModel(age: 35, weightKg: 100, heightCm: 175, aim: .gain).nutritionGoal, .maintain)
        let adult = bodyModel(age: 30, weightKg: 70, heightCm: 175, aim: .lose)
        XCTAssertEqual(adult.nutritionGoal, .lose)
        XCTAssertLessThan(adult.recommendedNutritionGoals()?.kcal ?? .infinity, maintenanceKcal(adult, weightKg: 70, heightCm: 175))
    }

    func testTheCalorieFloorAndTheRangesOfTheCalculation() throws {
        // A small man of 60: 55 kg, 1,60 m, sedentary. 85 % of his energy is 1 280, under his floor of 1 500.
        let goals = try XCTUnwrap(NutritionSafety.goals(sex: .male, age: 60, heightCm: 160, weightKg: 55, activity: .sedentary, goal: .lose))
        XCTAssertEqual(goals.kcal, 1_500, accuracy: 0.5)
        XCTAssertEqual(NutritionSafety.minimumKcal(sex: .male, age: 60, heightCm: 160, weightKg: 55), 1_500)
        XCTAssertGreaterThan(goals.protein, 0)
        // A body whose loss stays above the floor is the plain calculation, unchanged.
        let plain = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 90, activity: .moderate, goal: .lose)
        XCTAssertEqual(NutritionSafety.goals(sex: .male, age: 30, heightCm: 180, weightKg: 90, activity: .moderate, goal: .lose), plain)
        // Calories typed by hand are never changed.
        XCTAssertEqual(NutritionSafety.goals(sex: .male, age: 60, heightCm: 160, weightKg: 55, activity: .sedentary, goal: .lose, kcal: 1_200)?.kcal, 1_200)
        // Data outside the ranges: nothing is calculated.
        XCTAssertNil(NutritionSafety.goals(sex: .male, age: 8, heightCm: 130, weightKg: 30, activity: .light, goal: .maintain))
        XCTAssertNil(NutritionSafety.goals(sex: .male, age: 30, heightCm: 100, weightKg: 70, activity: .light, goal: .maintain))
        XCTAssertNil(NutritionSafety.goals(sex: .male, age: 30, heightCm: 175, weightKg: 400, activity: .light, goal: .maintain))
    }

    func testAllowedGoalIsPure() {
        XCTAssertEqual(NutritionSafety.allowedGoal(.lose, heightCm: 175, weightKg: 70, isMinor: true, lifeStage: nil), .maintain)
        XCTAssertEqual(NutritionSafety.allowedGoal(.lose, heightCm: 175, weightKg: 70, isMinor: false, lifeStage: .minor), .maintain)
        XCTAssertEqual(NutritionSafety.allowedGoal(.lose, heightCm: 175, weightKg: 70, isMinor: false, lifeStage: nil), .lose)
        XCTAssertEqual(NutritionSafety.allowedGoal(.lose, heightCm: 175, weightKg: 55, isMinor: false, lifeStage: .adult), .maintain, "Index 18,0")
        XCTAssertEqual(NutritionSafety.allowedGoal(.maintain, heightCm: 175, weightKg: 55, isMinor: true, lifeStage: .pregnant), .maintain)
    }

    // MARK: Premium looks (W-07) and the check date (K-07)

    func testAPremiumLookIsNotGivenWithoutPremium() {
        withoutDebugUnlock {
            let model = AppModel(store: temporaryStore())
            let target = WidgetDesign(kind: .note)
            model.save(target)
            let source = WidgetDesign(kind: .clock, themeID: .aurora, accentHex: "123456", background: .gradient, font: .serif)
            XCTAssertTrue(source.usesPremiumFeatures)
            let style = model.saveStyle(named: "Premium", from: source)

            XCTAssertTrue(model.needsPremium(style))
            XCTAssertEqual(model.apply(style, to: [target.id]), 0)
            XCTAssertEqual(model.design(id: target.id)?.themeID, target.themeID, "The widget is untouched")

            model.updatePremium(subscribed())
            XCTAssertFalse(model.needsPremium(style))
            XCTAssertEqual(model.apply(style, to: [target.id]), 1)
            XCTAssertEqual(model.design(id: target.id)?.themeID, .aurora)
        }
    }

    func testTheSheetGivesAFreeLookAndAsksForPremiumForAPremiumOne() {
        withoutDebugUnlock {
            let model = AppModel(store: temporaryStore())
            let target = WidgetDesign(kind: .note)
            model.save(target)
            let premiumLook = model.saveStyle(named: "Premium", from: WidgetDesign(kind: .clock, themeID: .aurora, accentHex: "123456", background: .gradient, font: .serif))
            guard case .needsPremium(let shown) = model.applyOrAskPremium(premiumLook, to: [target.id]) else {
                return XCTFail("a Premium look on a free plan asks for Premium")
            }
            XCTAssertEqual(shown.count, 1)
            XCTAssertEqual(model.design(id: target.id)?.themeID, target.themeID, "nothing changed")

            // The look a widget already wears is free: it is applied (0 changed), never a paywall.
            let same = model.saveStyle(named: "Pareil", from: target)
            guard case .applied(let count) = model.applyOrAskPremium(same, to: [target.id]) else {
                return XCTFail("a free look applies")
            }
            XCTAssertEqual(count, 0)

            model.updatePremium(subscribed())
            guard case .applied(let applied) = model.applyOrAskPremium(premiumLook, to: [target.id]) else {
                return XCTFail("Premium applies it")
            }
            XCTAssertEqual(applied, 1)
        }
    }

    // MARK: Shared photos (W-03)

    func testAPhotoSharedByTwoWidgetsStaysWhenOneIsDeleted() throws {
        let model = AppModel(store: temporaryStore())
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let shared = try XCTUnwrap(ImageStore.save(image))
        let own = try XCTUnwrap(ImageStore.save(image))
        defer { ImageStore.delete(named: shared); ImageStore.delete(named: own) }
        var first = WidgetDesign(kind: .caloriesLeft, background: .photo(shared), format: .small)
        first.options.photos = [PhotoSlot(file: own)]
        let second = WidgetDesign(kind: .proteinLeft, background: .photo(shared), format: .small)
        model.save(first)
        model.save(second)

        model.delete(first)
        XCTAssertNotNil(ImageStore.image(named: shared), "Another widget still uses this photo")
        XCTAssertNil(ImageStore.image(named: own), "A photo nobody uses any more goes")

        model.delete([second])
        XCTAssertNil(ImageStore.image(named: shared), "The last widget takes it with it")
    }

    func testChangingABackgroundKeepsAPhotoAnotherWidgetUses() throws {
        let model = AppModel(store: temporaryStore())
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { _ in }
        let shared = try XCTUnwrap(ImageStore.save(image))
        defer { ImageStore.delete(named: shared) }
        var first = WidgetDesign(kind: .caloriesLeft, background: .photo(shared), format: .small)
        model.save(first)
        model.save(WidgetDesign(kind: .proteinLeft, background: .photo(shared), format: .small))
        first.background = .theme
        model.save(first)
        XCTAssertNotNil(ImageStore.image(named: shared))
    }

    func testOnlyTheCheckDateChangingWritesNothing() {
        withoutDebugUnlock {
            let store = temporaryStore()
            let model = AppModel(store: store)
            let first = subscribed()
            model.updatePremium(first)
            XCTAssertTrue(store.premium.isActive)
            XCTAssertNotNil(store.premium.verifiedAt)

            var later = first
            later.verifiedAt = Date().addingTimeInterval(3_600)
            model.updatePremium(later)
            XCTAssertEqual(store.premium.verifiedAt?.timeIntervalSince1970 ?? 0, first.verifiedAt?.timeIntervalSince1970 ?? -1, accuracy: 0.001,
                           "A new check date alone isn't written")

            var ended = later
            ended.isActive = false
            model.updatePremium(ended)
            XCTAssertFalse(store.premium.isActive, "A real change is written")
        }
    }
}
