import XCTest
@testable import Tessera

/// Apprentissage local du scan : une correction ne suffit pas, deux concordantes oui, une correction aberrante
/// est mise en quarantaine, la quantité habituelle est la médiane, le journal est borné, et les anciennes
/// données (sans la clé) se décodent.
final class ScanLearningTests: XCTestCase {
    private let range: ClosedRange<Double> = 1...2_000
    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private var tick = 0.0

    private func correction(label: String = "pizza", detected: String = "builtin.burger", validated: String = "builtin.pizza",
                            initial: Double = 110, grams: Double = 180) -> ScanCorrection {
        tick += 1
        return ScanCorrection(date: start.addingTimeInterval(tick * 60), labels: [label], detectedFoodID: detected,
                              initialGrams: initial, validatedFoodID: validated, validatedGrams: grams, quarantined: false)
    }

    private func record(_ learning: inout ScanLearning, _ c: ScanCorrection) {
        learning.record(c, plausibleGramsRange: range)
    }

    // MARK: Préférence d'aliment

    func testNothingLearnedAtFirst() {
        let learning = ScanLearning()
        XCTAssertTrue(learning.corrections.isEmpty)
        XCTAssertNil(learning.preferredFoodID(forLabel: "pizza"))
        XCTAssertNil(learning.usualGrams(forFoodID: "builtin.pizza"))
    }

    func testOneCorrectionIsNotEnough() {
        var learning = ScanLearning()
        record(&learning, correction())
        XCTAssertEqual(learning.corrections.count, 1)
        XCTAssertNil(learning.preferredFoodID(forLabel: "pizza"), "Une seule correction ne devient jamais une préférence")
    }

    func testTwoConcordantCorrectionsMakeAPreference() {
        var learning = ScanLearning()
        record(&learning, correction())
        record(&learning, correction())
        XCTAssertEqual(learning.preferredFoodID(forLabel: "pizza"), "builtin.pizza")
        XCTAssertNil(learning.preferredFoodID(forLabel: "sushi"), "Une autre étiquette n'est pas touchée")
    }

    func testTwoDisagreeingCorrectionsMakeNoPreference() {
        var learning = ScanLearning()
        record(&learning, correction(validated: "builtin.pizza"))
        record(&learning, correction(validated: "builtin.burger"))
        XCTAssertNil(learning.preferredFoodID(forLabel: "pizza"))
    }

    func testOneOddCorrectionDoesNotOverrideTwoConcordantOnes() {
        var learning = ScanLearning()
        record(&learning, correction(validated: "builtin.pizza"))
        record(&learning, correction(validated: "builtin.pizza"))
        record(&learning, correction(validated: "builtin.burger"))
        XCTAssertEqual(learning.preferredFoodID(forLabel: "pizza"), "builtin.pizza")
    }

    func testQuarantinedCorrectionsDoNotCountForThePreference() {
        var learning = ScanLearning()
        record(&learning, correction(grams: 180))
        record(&learning, correction(grams: 9_000)) // hors bornes : quarantaine
        XCTAssertEqual(learning.corrections.last?.quarantined, true)
        XCTAssertNil(learning.preferredFoodID(forLabel: "pizza"), "Une correction valide + une en quarantaine : pas fiable")
    }

    // MARK: Quantités habituelles

    func testUsualGramsIsTheMedian() throws {
        var learning = ScanLearning()
        for grams in [100.0, 300, 200] { record(&learning, correction(grams: grams)) }
        XCTAssertEqual(try XCTUnwrap(learning.usualGrams(forFoodID: "builtin.pizza")), 200, accuracy: 0.001,
                       "Médiane de 100, 200, 300 : 200 (pas la moyenne d'une valeur extrême)")
        record(&learning, correction(grams: 210))
        record(&learning, correction(grams: 190))
        XCTAssertEqual(try XCTUnwrap(learning.usualGrams(forFoodID: "builtin.pizza")), 200, accuracy: 0.001)
    }

    func testUsualGramsAreKeptPerFood() throws {
        var learning = ScanLearning()
        for grams in [150.0, 160, 155] { record(&learning, correction(validated: "builtin.rice", grams: grams)) }
        for grams in [180.0, 190, 185] { record(&learning, correction(validated: "builtin.pizza", grams: grams)) }
        XCTAssertEqual(try XCTUnwrap(learning.usualGrams(forFoodID: "builtin.rice")), 155, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(learning.usualGrams(forFoodID: "builtin.pizza")), 185, accuracy: 0.001)
        XCTAssertNil(learning.usualGrams(forFoodID: "builtin.apple"))
    }

    func testOutOfRangeCorrectionIsQuarantined() {
        var learning = ScanLearning()
        record(&learning, correction(grams: 5_000))
        XCTAssertEqual(learning.corrections.last?.quarantined, true, "5 000 g est hors des bornes plausibles (1 à 2 000 g)")
        record(&learning, correction(grams: 0.2))
        XCTAssertEqual(learning.corrections.last?.quarantined, true, "Moins de 1 g est hors des bornes")
        record(&learning, correction(grams: 150))
        XCTAssertEqual(learning.corrections.last?.quarantined, false)
    }

    func testTenTimesTheMedianIsQuarantinedAndIgnored() throws {
        var learning = ScanLearning()
        for grams in [150.0, 160, 155] { record(&learning, correction(grams: grams)) }
        record(&learning, correction(grams: 1_800)) // dans les bornes, mais plus de 10 fois la médiane
        XCTAssertEqual(learning.corrections.last?.quarantined, true)
        XCTAssertEqual(try XCTUnwrap(learning.usualGrams(forFoodID: "builtin.pizza")), 155, accuracy: 0.001,
                       "La correction en quarantaine ne bouge pas la quantité habituelle")
    }

    func testOneBigButPlausibleCorrectionDoesNotDominate() throws {
        var learning = ScanLearning()
        for grams in [150.0, 160, 155] { record(&learning, correction(grams: grams)) }
        record(&learning, correction(grams: 400))
        let usual = try XCTUnwrap(learning.usualGrams(forFoodID: "builtin.pizza"))
        XCTAssertGreaterThanOrEqual(usual, 155)
        XCTAssertLessThanOrEqual(usual, 160, "Une valeur isolée ne tire pas la médiane")
    }

    func testRecordDoesNotDeduplicate() {
        // La protection contre le double appui est dans `commit` (fenêtre de 2 s), pas dans `record`.
        var learning = ScanLearning()
        let c = correction()
        record(&learning, c)
        record(&learning, c)
        XCTAssertEqual(learning.corrections.count, 2)
    }

    func testInvalidCorrectionsAreDropped() {
        var learning = ScanLearning()
        record(&learning, correction(grams: 0))
        record(&learning, correction(grams: -5))
        record(&learning, correction(grams: .nan))
        record(&learning, correction(validated: ""))
        XCTAssertTrue(learning.corrections.isEmpty)
    }

    func testUsualGramsNeedTwoValidCorrections() {
        var learning = ScanLearning()
        record(&learning, correction(grams: 300))
        XCTAssertNil(learning.usualGrams(forFoodID: "builtin.pizza"), "Une seule correction valide ne fixe rien")
        record(&learning, correction(grams: 200))
        XCTAssertEqual(learning.usualGrams(forFoodID: "builtin.pizza"), 250, "Médiane de deux valeurs : leur milieu")
    }

    func testPlausibleGramsAreNarrowForFats() throws {
        let oil = try XCTUnwrap(FoodDatabase.item("builtin.oliveoil"))
        let rice = try XCTUnwrap(FoodDatabase.item("builtin.rice"))
        XCTAssertTrue(ScanLearning.plausibleGrams(for: oil).contains(10))
        XCTAssertFalse(ScanLearning.plausibleGrams(for: oil).contains(400), "400 g d'huile n'est pas plausible")
        XCTAssertTrue(ScanLearning.plausibleGrams(for: rice).contains(400))
    }

    func testContributionIsOffByDefault() throws {
        XCTAssertFalse(ScanLearning().contributionEnabled)
        let old = try JSONDecoder().decode(ScanLearning.self, from: Data("{}".utf8))
        XCTAssertFalse(old.contributionEnabled)
        XCTAssertTrue(old.corrections.isEmpty)
    }

    func testTolerantDecodingOfACorrection() throws {
        let c = try JSONDecoder().decode(ScanCorrection.self, from: Data(#"{"validatedFoodID":"a","validatedGrams":"mauvais"}"#.utf8))
        XCTAssertEqual(c.validatedFoodID, "a")
        XCTAssertFalse(c.quarantined)
    }

    // MARK: Validation d'un récapitulatif

    private func pizza() throws -> FoodItem { try XCTUnwrap(FoodDatabase.item("builtin.pizza")) }

    func testCommitMarksEntriesAsScanned() throws {
        var recap = ScanRecap()
        recap.add(try pizza(), grams: 100)
        var state = NutritionState()
        recap.commit(into: &state, meal: .lunch, at: start)
        XCTAssertEqual(state.entries.first?.origin, .scan)
        XCTAssertTrue(state.scanLearning.corrections.isEmpty, "Un produit sans photo n'enregistre rien à apprendre")
    }

    func testPhotoCommitRecordsTheCorrectionAndLearnsAfterTwo() throws {
        let food = try pizza()
        var state = NutritionState()
        for index in 0..<2 {
            var recap = ScanRecap(proposals: [MealProposal(food: food, grams: 110, confidence: 0.6, label: "pizza", detectedFoodID: "builtin.burger")])
            recap.setGrams(recap.lines[0].id, 180)
            recap.commit(into: &state, meal: .dinner, at: start.addingTimeInterval(Double(index) * 3_600))
        }
        XCTAssertEqual(state.scanLearning.corrections.count, 2)
        let first = try XCTUnwrap(state.scanLearning.corrections.first)
        XCTAssertEqual(first.labels, ["pizza"])
        XCTAssertEqual(first.detectedFoodID, "builtin.burger")
        XCTAssertEqual(first.initialGrams, 110)
        XCTAssertEqual(first.validatedFoodID, "builtin.pizza")
        XCTAssertEqual(first.validatedGrams, 180)
        XCTAssertEqual(state.scanLearning.preferredFoodID(forLabel: "pizza"), "builtin.pizza")
        XCTAssertEqual(state.scanLearning.usualGrams(forFoodID: "builtin.pizza"), 180)
    }

    func testDoubleTapOnAPhotoCommitRecordsOnce() throws {
        let food = try pizza()
        let recap = ScanRecap(proposals: [MealProposal(food: food, grams: 110, confidence: 0.6, label: "pizza")])
        var state = NutritionState()
        recap.commit(into: &state, meal: .lunch, at: start)
        recap.commit(into: &state, meal: .lunch, at: start.addingTimeInterval(0.5))
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(state.scanLearning.corrections.count, 1)
    }

    // MARK: Limite

    func testJournalIsCappedAtFiveHundredAndKeepsTheLatest() {
        var learning = ScanLearning()
        for _ in 0..<520 { record(&learning, correction(grams: 180)) }
        XCTAssertEqual(learning.corrections.count, 500, "Seules les plus anciennes sont écartées")
        let lastDate = start.addingTimeInterval(tick * 60)
        XCTAssertTrue(learning.corrections.contains { $0.date == lastDate }, "La plus récente est gardée")
        XCTAssertEqual(learning.preferredFoodID(forLabel: "pizza"), "builtin.pizza")
    }

    // MARK: Anciennes données et codage

    func testOldNutritionStateWithoutTheKeyStillDecodes() throws {
        let state = try JSONDecoder().decode(NutritionState.self, from: Data("{}".utf8))
        XCTAssertTrue(state.scanLearning.corrections.isEmpty)
        XCTAssertTrue(state.entries.isEmpty)

        let old = Data(#"{"goals":{},"entries":[],"favorites":[],"customFoods":[],"recentFoods":[],"savedMeals":[]}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(NutritionState.self, from: old).scanLearning.corrections.isEmpty)
    }

    func testOldFoodEntryWithoutOriginDecodesWithNoOrigin() throws {
        let food = FoodItem(id: "a", name: "a", brand: nil, kcal: 100, protein: 5, carbs: 10, fat: 2, fiber: 1,
                            servingGrams: 100, servingName: "1", source: .custom, barcode: nil)
        let entry = FoodEntry(date: start, meal: .lunch, food: food, grams: 150)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any])
        object.removeValue(forKey: "origin")
        let data = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(FoodEntry.self, from: data)
        XCTAssertEqual(decoded.grams, 150)
        XCTAssertNil(decoded.origin, "Une entrée d'avant n'a pas d'origine")
    }

    func testLearningSurvivesEncodingAndStoreRoundTrip() throws {
        var state = NutritionState()
        record(&state.scanLearning, correction())
        record(&state.scanLearning, correction())
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(NutritionState.self, from: data)
        XCTAssertEqual(decoded.scanLearning.corrections.count, 2)
        XCTAssertEqual(decoded.scanLearning.preferredFoodID(forLabel: "pizza"), "builtin.pizza")
    }

    func testCorruptedLearningDoesNotBreakTheState() throws {
        let broken = Data(#"{"entries":[],"scanLearning":"n'importe quoi"}"#.utf8)
        let state = try JSONDecoder().decode(NutritionState.self, from: broken)
        XCTAssertTrue(state.scanLearning.corrections.isEmpty)
    }

    func testQuarantinedCorrectionIsStillKeptForTheRecord() {
        var learning = ScanLearning()
        record(&learning, correction(grams: 9_999))
        XCTAssertEqual(learning.corrections.count, 1, "La correction douteuse est gardée mais ignorée")
    }
}
