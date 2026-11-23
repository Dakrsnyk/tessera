import CoreGraphics
import XCTest
@testable import Ardane

/// The context of the meal (`ScannerMealContext`): the foods of a plate make each other more or less likely, but never add a
/// food, never make one sure on their own, and never beat a clear image.
final class ScannerMealContextTests: XCTestCase {
    private typealias Candidates = [(key: String, probability: Double)]

    /// A small table with the associations of the examples of the request (2026-11-23), in the units of the real one.
    private let table = MealContextTable(alpha: 0.5, cap: 0.7, tentativeWeight: 0.5, pairs: [
        ("rice", "chicken", 1.5), ("rice", "fish", 1.0), ("rice", "curry", 2.0), ("rice", "coffee", -3.0),
        ("steak", "potato", 1.3), ("steak", "pasta", 0.6), ("steak", "fries", 1.3), ("steak", "popcorn", -1.5),
        ("pasta", "tomatosauce", 2.4), ("pasta", "beef", 1.2), ("tomatosauce", "beef", 1.0), ("pasta", "parmesan", 2.4),
        ("fish", "potato", 1.5), ("chicken", "vegetables", 1.6), ("rice", "vegetables", 1.5),
        ("lettuce", "tomato", 1.1), ("lettuce", "dressing", 2.0), ("tomato", "dressing", 1.0),
    ])

    private func zone(_ candidates: Candidates, tentative: Bool = false) -> MealContextZone {
        MealContextZone(candidates: candidates, isTentative: tentative)
    }

    private func first(_ candidates: Candidates) -> String? { candidates.first?.key }

    // MARK: Rules

    func testAZoneAloneOrAnEmptyTableChangesNothing() {
        let rice: Candidates = [("rice", 0.6), ("couscous", 0.3)]
        XCTAssertEqual(ScannerMealContext.reranked([zone(rice)], table: table).first?.map(\.key), ["rice", "couscous"])
        XCTAssertEqual(ScannerMealContext.reranked([zone(rice)], table: table).first?.map(\.probability), [0.6, 0.3])
        let empty = MealContextTable(alpha: 0.5, cap: 0.7, tentativeWeight: 0.5, pairs: [])
        let two = ScannerMealContext.reranked([zone(rice), zone([("fish", 0.45), ("chicken", 0.44)])], table: empty)
        XCTAssertEqual(two[1].map(\.key), ["fish", "chicken"])
        XCTAssertEqual(two[1].map(\.probability), [0.45, 0.44])
    }

    func testEachZoneKeepsItsOwnFoodsAndItsTotalProbability() {
        let zones = [
            zone([("rice", 0.7), ("couscous", 0.2)]),
            zone([("fish", 0.40), ("chicken", 0.38), ("tofu", 0.1)]),
            zone([("coffee", 0.5), ("tea", 0.3)], tentative: true),
        ]
        let out = ScannerMealContext.reranked(zones, table: table)
        for (before, after) in zip(zones, out) {
            XCTAssertEqual(Set(after.map(\.key)), Set(before.candidates.map(\.key)), "Jamais un aliment que la zone ne propose pas")
            XCTAssertEqual(after.count, before.candidates.count)
            let massBefore = before.candidates.reduce(0) { $0 + $1.probability }
            let massAfter = after.reduce(0) { $0 + $1.probability }
            XCTAssertEqual(massAfter, massBefore, accuracy: 1e-9, "La zone garde sa probabilité totale")
            for candidate in after {
                let original = before.candidates.first { $0.key == candidate.key }!.probability
                XCTAssertLessThanOrEqual(candidate.probability / original, exp(2 * table.cap) + 1e-9, "Changement borné")
                XCTAssertGreaterThanOrEqual(candidate.probability / original, exp(-2 * table.cap) - 1e-9, "Changement borné")
            }
        }
    }

    func testTheContextNeverMakesAFoodSureOnItsOwn() {
        let zones = [zone([("rice", 0.95)]), zone([("chicken", 0.70), ("pork", 0.29)])]
        let chicken = ScannerMealContext.reranked(zones, table: table)[1].first!
        XCTAssertEqual(chicken.key, "chicken")
        XCTAssertLessThan(chicken.probability, ScanRecap.autoAddThreshold, "Seule l'image peut rendre un aliment assez sûr")
        // A food the image already made sure stays sure.
        let sure = ScannerMealContext.reranked([zone([("rice", 0.95)]), zone([("chicken", 0.9), ("pork", 0.05)])], table: table)
        XCTAssertGreaterThanOrEqual(sure[1].first!.probability, ScanRecap.autoAddThreshold)
    }

    func testAClearImageWinsOverTheUsualAssociations() {
        // Fish is not chicken: rice goes with both, chicken a little more, but the image is clear.
        let out = ScannerMealContext.reranked([zone([("rice", 0.9)]), zone([("fish", 0.85), ("chicken", 0.10)])], table: table)
        XCTAssertEqual(first(out[1]), "fish")
    }

    // MARK: The meals of the request (2026-11-23)

    func testRiceAndChicken() {
        // The zone next to the rice hesitates between chicken and pork: rice tips it to chicken, the rice is untouched.
        let out = ScannerMealContext.reranked([zone([("rice", 0.92)]), zone([("pork", 0.42), ("chicken", 0.40)])], table: table)
        XCTAssertEqual(first(out[1]), "chicken")
        XCTAssertEqual(first(out[0]), "rice")
        XCTAssertLessThan(out[1][0].probability, ScanRecap.autoAddThreshold, "Une hésitation reste à confirmer")
    }

    func testRiceAloneNeverAddsChicken() {
        let out = ScannerMealContext.reranked([zone([("rice", 0.92), ("couscous", 0.05)])], table: table)
        XCTAssertEqual(out.count, 1)
        XCTAssertFalse(out[0].contains { $0.key == "chicken" }, "Du riz ne fait jamais apparaître du poulet")
    }

    func testSteakMakesPotatoesMoreLikelyThanPopcorn() {
        // A side dish that looks like popcorn to the image, next to a steak: potatoes come first, and nothing is sure.
        let out = ScannerMealContext.reranked(
            [zone([("steak", 0.9)]), zone([("popcorn", 0.45), ("potato", 0.38), ("rice", 0.05)])], table: table
        )
        XCTAssertEqual(first(out[1]), "potato")
        XCTAssertTrue(out[1].contains { $0.key == "popcorn" }, "Le popcorn reste une hypothèse à un toucher")
        XCTAssertLessThan(out[1][0].probability, ScanRecap.autoAddThreshold)
    }

    func testSteakAndPasta() {
        let out = ScannerMealContext.reranked([zone([("steak", 0.85)]), zone([("rice", 0.40), ("pasta", 0.39)])], table: table)
        XCTAssertEqual(first(out[1]), "pasta", "Le steak va avec les pâtes, pas avec ce riz incertain")
    }

    func testChickenRiceAndVegetablesHoldTogether() {
        let out = ScannerMealContext.reranked([
            zone([("chicken", 0.6), ("pork", 0.3)]),
            zone([("rice", 0.5), ("couscous", 0.45)]),
            zone([("vegetables", 0.4), ("salad", 0.39)]),
        ], table: table)
        XCTAssertEqual(out.map { $0.first!.key }, ["chicken", "rice", "vegetables"], "Les trois s'appuient l'un sur l'autre")
    }

    func testFishAndPotatoes() {
        let out = ScannerMealContext.reranked([zone([("fish", 0.8)]), zone([("bread", 0.41), ("potato", 0.40)])], table: table)
        XCTAssertEqual(first(out[1]), "potato")
    }

    func testPastaWithSauceAndMeat() {
        // A sauce zone the segmenter is unsure of (« peut-être ») next to pasta: the tomato sauce wins over the curry, and
        // the zone stays a « maybe » (never added alone, see `ScanPendingTests`).
        let out = ScannerMealContext.reranked([
            zone([("pasta", 0.9)]),
            zone([("curry", 0.40), ("tomatosauce", 0.36)], tentative: true),
            zone([("beef", 0.5), ("lentils", 0.4)]),
        ], table: table)
        XCTAssertEqual(first(out[1]), "tomatosauce")
        XCTAssertEqual(first(out[2]), "beef")
    }

    func testMixedSaladKeepsItsIngredients() {
        let out = ScannerMealContext.reranked([
            zone([("lettuce", 0.7)]), zone([("tomato", 0.45), ("apple", 0.44)]), zone([("dressing", 0.5), ("yogurt", 0.45)]),
        ], table: table)
        XCTAssertEqual(first(out[1]), "tomato")
        XCTAssertEqual(first(out[2]), "dressing")
    }

    func testAHalfHiddenFoodIsHelpedButAClearOneIsNot() {
        // A food half hidden by the steak (low probabilities) moves; the steak itself never does.
        let out = ScannerMealContext.reranked([zone([("steak", 0.88), ("pork", 0.08)]), zone([("rice", 0.21), ("fries", 0.20)])], table: table)
        XCTAssertEqual(first(out[1]), "fries")
        XCTAssertEqual(first(out[0]), "steak")
    }

    // MARK: Reading of the photo

    private func food(_ id: String) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: 150, protein: 10, carbs: 10, fat: 5, fiber: 1,
                 servingGrams: 100, servingName: "1", source: .custom, barcode: nil)
    }

    private func modelZone(_ score: Double, _ foods: [(String, Double)]) -> FoodModelZone {
        FoodModelZone(
            score: score, box: CGRect(x: 0, y: 0, width: 10, height: 10), maskBounds: CGRect(x: 0, y: 0, width: 10, height: 10),
            cropRect: CGRect(x: 0, y: 0, width: 12, height: 12),
            classification: FoodModelClassification(
                foods: foods.map { FoodModelCandidate(key: $0.0, probability: $0.1) }, topLabel: "mfr:x",
                topProbability: foods.first?.1 ?? 0
            )
        )
    }

    func testTheRecapSaysWhenThePlateChangedTheChoiceAndKeepsTheImagesChoiceAsAnAlternative() {
        let foods = ["steak", "popcorn", "potato"].map(food)
        let resolve: (String) -> FoodItem? = { id in foods.first { $0.id == id } }
        let zones = [modelZone(0.9, [("steak", 0.9)]), modelZone(0.8, [("popcorn", 0.45), ("potato", 0.38)])]

        let plain = OnDeviceMealAnalyzer.modelReading(from: zones, learning: ScanLearning(), resolve: resolve)
        XCTAssertTrue(plain.proposals.contains { $0.food.id == "popcorn" }, "Sans la table, rien ne change")
        XCTAssertFalse(plain.proposals.contains { $0.fromMealContext })

        let reading = OnDeviceMealAnalyzer.modelReading(from: zones, learning: ScanLearning(), meal: table, resolve: resolve)
        let potato = reading.proposals.first { $0.food.id == "potato" }
        XCTAssertNotNil(potato)
        XCTAssertTrue(potato?.fromMealContext ?? false)
        XCTAssertFalse(reading.proposals.contains { $0.food.id == "popcorn" })
        XCTAssertEqual(reading.hints[1].alternatives.map(\.id), ["popcorn"], "Le choix de l'image reste à un toucher")
        XCTAssertFalse(reading.proposals.first { $0.food.id == "steak" }?.fromMealContext ?? true)

        let recap = MealAnalysis(proposals: reading.proposals, tentative: reading.tentative, zoneHints: reading.hints).recap
        XCTAssertFalse(recap.lines.contains { $0.food.id == "potato" }, "Choisi par le contexte : jamais ajouté d'office")
        XCTAssertTrue(recap.pending.contains { $0.food.id == "potato" && $0.fromMealContext })
    }

    // MARK: The table learned on real meals

    /// `Tests/Fixtures/MealContext/ArdaneFoodPairs.json`, written by `meal_context.py build`. Kept with the tests, not in the
    /// app: measured on 1 000 test photos, it does not make the scanner more precise yet (see `ScannerMealContext`).
    private func learnedTable() throws -> MealContextTable {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/MealContext/\(MealContextTable.resourceName).json")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("Tests/Fixtures/MealContext/ArdaneFoodPairs.json introuvable") }
        return try XCTUnwrap(MealContextTable(data: data), "Table illisible")
    }

    func testTheLearnedTableKnowsUsualMeals() throws {
        let real = try learnedTable()
        XCTAssertGreaterThan(real.score("builtin.rice", "builtin.chicken"), 0, "Riz et poulet")
        XCTAssertGreaterThan(real.score("builtin.steak", "builtin.fries"), 0, "Steak et frites")
        XCTAssertGreaterThan(real.score("builtin.steak", "builtin.potato"), 0, "Steak et pommes de terre")
        XCTAssertGreaterThan(real.score("builtin.pasta", "builtin.tomatosauce"), 0, "Pâtes et sauce tomate")
        XCTAssertGreaterThan(real.score("builtin.pasta", "builtin.parmesan"), 0, "Pâtes et parmesan")
        XCTAssertGreaterThan(real.score("builtin.salmon", "builtin.rice"), 0, "Saumon et riz")
        XCTAssertLessThan(real.score("builtin.rice", "builtin.coffee"), 0, "Un café n'est pas un accompagnement du riz")
        XCTAssertLessThan(real.score("builtin.steak", "builtin.popcorn"), real.score("builtin.steak", "builtin.potato"))
        XCTAssertEqual(real.score("builtin.rice", "builtin.rice"), 0)
        XCTAssertEqual(real.score("builtin.rice", "builtin.chicken"), real.score("builtin.chicken", "builtin.rice"))
    }

    // MARK: Same numbers as the Python that measured it

    private struct Parity: Decodable {
        struct Zone: Decodable {
            let tentative: Bool
            let candidates: [[String]]
        }
        struct Case: Decodable {
            let zones: [Zone]
            let expected: [[[String]]]
        }
        let cases: [Case]
    }

    private func candidates(_ rows: [[String]]) -> Candidates {
        rows.map { (key: $0[0], probability: Double($0[1]) ?? .nan) }
    }

    /// `Tests/Fixtures/MealContext/meal-context-parity.json`, written by `scripts/ml/meal_context.py fixture` from real zones of the test
    /// photos and the learned table: the Swift rule must give the Python's numbers.
    func testSameResultsAsThePythonReference() throws {
        let real = try learnedTable()
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/MealContext/meal-context-parity.json")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("Tests/Fixtures/MealContext/meal-context-parity.json introuvable") }
        let parity = try JSONDecoder().decode(Parity.self, from: data)
        XCTAssertGreaterThanOrEqual(parity.cases.count, 20)
        var changed = 0
        for (number, item) in parity.cases.enumerated() {
            let zones = item.zones.map { MealContextZone(candidates: candidates($0.candidates), isTentative: $0.tentative) }
            let out = ScannerMealContext.reranked(zones, table: real)
            XCTAssertEqual(out.count, item.expected.count)
            for (got, rows) in zip(out, item.expected) {
                let expected = candidates(rows)
                XCTAssertEqual(got.map(\.key), expected.map(\.key), "Cas \(number)")
                for (a, b) in zip(got, expected) {
                    XCTAssertEqual(a.probability, b.probability, accuracy: 1e-6, "Cas \(number), \(a.key)")
                }
            }
            if zip(zones, out).contains(where: { $0.0.candidates.first?.key != $0.1.first?.key }) { changed += 1 }
        }
        XCTAssertGreaterThan(changed, 0, "Le jeu de parité doit contenir des zones que le contexte réordonne")
    }
}
