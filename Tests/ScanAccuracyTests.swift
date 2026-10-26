import XCTest
@testable import Ardane

/// Précision du scan : cohérence de la table intégrée, parsing Open Food Facts, fourchettes d'incertitude,
/// et jeu de repas « pesés » synthétiques pour mesurer l'erreur d'un scan estimé avant/après personnalisation.
final class ScanAccuracyTests: XCTestCase {
    private func v(_ x: Double?) -> Double { x ?? 0 }

    private func attach(_ name: String, _ text: String) {
        print("=== \(name) ===\n\(text)")
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pct(_ x: Double) -> String { String(format: "%.1f %%", x) }

    // MARK: - (1) Table intégrée

    /// Aliments dont les kcal ne suivent pas 4P+4G+9L : l'alcool apporte 7 kcal/g sans être un macronutriment.
    private let alcoholWhitelist: Set<String> = ["builtin.wine", "builtin.spirits", "builtin.beer"]

    func testBuiltInTableIsCoherent() {
        var lines: [(Double, String)] = []
        var seen = Set<String>()
        for food in FoodDatabase.all {
            let calc = 4 * v(food.protein) + 4 * v(food.carbs) + 9 * v(food.fat)
            let diff = food.kcal - calc
            lines.append((abs(diff), String(format: "%@ | kcal %.0f | 4P+4G+9L %.0f | écart %+.0f%@", food.id, food.kcal, calc, diff,
                                            alcoholWhitelist.contains(food.id) ? " | liste blanche (alcool)" : "")))

            XCTAssertTrue(seen.insert(food.id).inserted, "Identifiant en double : \(food.id)")
            XCTAssertGreaterThanOrEqual(food.kcal, 0, food.id)
            XCTAssertGreaterThanOrEqual(v(food.protein), 0, food.id)
            XCTAssertGreaterThanOrEqual(v(food.carbs), 0, food.id)
            XCTAssertGreaterThanOrEqual(v(food.fat), 0, food.id)
            XCTAssertGreaterThanOrEqual(v(food.fiber), 0, food.id)
            XCTAssertGreaterThan(food.servingGrams, 0, "\(food.id) : portion nulle")
            XCTAssertLessThanOrEqual(food.kcal, 900, "\(food.id) : plus de 900 kcal/100 g")
            // Plus de 100 g de nutriments dans 100 g d'aliment est impossible (0,5 g de marge d'arrondi).
            XCTAssertLessThanOrEqual(v(food.protein) + v(food.carbs) + v(food.fat), 100.5, "\(food.id) : macros > 100 g")
            XCTAssertLessThanOrEqual(v(food.fiber), v(food.carbs) + 0.5, "\(food.id) : fibres > glucides")
            if let sugars = food.sugars {
                XCTAssertGreaterThanOrEqual(sugars, 0, food.id)
                XCTAssertLessThanOrEqual(sugars, v(food.carbs) + 0.5, "\(food.id) : sucres > glucides")
            }

            if alcoholWhitelist.contains(food.id) {
                XCTAssertGreaterThan(diff, 0, "\(food.id) : l'alcool doit ajouter des kcal")
            } else {
                // Les glucides comptent les fibres (≈ 2 kcal/g au lieu de 4) et les valeurs sont arrondies.
                let tolerance = max(30, 0.25 * food.kcal)
                XCTAssertLessThanOrEqual(abs(diff), tolerance, "\(food.id) : kcal \(food.kcal) contre \(calc) calculées")
            }
        }
        XCTAssertGreaterThan(FoodDatabase.all.count, 100)
        let report = lines.sorted { $0.0 > $1.0 }.map(\.1).joined(separator: "\n")
        attach("SCAN-TABLE-ECARTS", "Aliments: \(FoodDatabase.all.count). Triés par écart décroissant.\n" + report)
    }

    // MARK: - (2) Parsing Open Food Facts (sans réseau)

    private func parse(nutriments: String, serving: String = "") -> FoodItem? {
        let json = """
        {"code":"3000000000001","product_name":"Produit test"\(serving),"nutriments":\(nutriments)}
        """
        return OpenFoodFacts.food(fromProductJSON: Data(json.utf8))
    }

    func testOpenFoodFactsKilojoulesBecomeKilocalories() throws {
        let item = try XCTUnwrap(parse(nutriments: #"{"energy-kj_100g":1046,"proteins_100g":10,"carbohydrates_100g":20,"fat_100g":5}"#))
        XCTAssertEqual(item.kcal, 1046 / 4.184, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(item.knownProtein), 10, accuracy: 0.001)
        XCTAssertFalse(item.hasUnknownMacros)
        XCTAssertNil(item.unknownMacros)
    }

    func testOpenFoodFactsKcalWinsOverKilojoules() throws {
        let item = try XCTUnwrap(parse(nutriments: #"{"energy-kcal_100g":300,"energy-kj_100g":1046,"proteins_100g":1,"carbohydrates_100g":1,"fat_100g":1}"#))
        XCTAssertEqual(item.kcal, 300, accuracy: 0.001)
    }

    func testOpenFoodFactsPerServingBecomesPer100g() throws {
        let item = try XCTUnwrap(parse(
            nutriments: #"{"energy-kcal_serving":150,"proteins_serving":6,"carbohydrates_serving":15,"fat_serving":3}"#,
            serving: #","serving_quantity":30"#))
        XCTAssertEqual(item.kcal, 500, accuracy: 0.001, "150 kcal pour 30 g = 500 kcal/100 g")
        XCTAssertEqual(try XCTUnwrap(item.knownProtein), 20, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.knownCarbs), 50, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.knownFat), 10, accuracy: 0.001)
        XCTAssertEqual(item.servingGrams, 30)
    }

    func testOpenFoodFactsMissingMacrosAreUnknownNotZero() throws {
        let item = try XCTUnwrap(parse(nutriments: #"{"energy-kcal_100g":250,"proteins_100g":10}"#))
        XCTAssertEqual(try XCTUnwrap(item.knownProtein), 10, accuracy: 0.001)
        XCTAssertNil(item.knownCarbs, "Glucides absents de la fiche : inconnus, pas 0")
        XCTAssertNil(item.knownFat, "Lipides absents de la fiche : inconnus, pas 0")
        XCTAssertEqual(item.unknownMacros, [.carbs, .fat])
        XCTAssertTrue(item.hasUnknownMacros)
        XCTAssertTrue(item.nutrients(grams: 100).isIncomplete, "Les totaux d'un produit incomplet sont marqués incomplets")
    }

    func testOpenFoodFactsKnownZeroIsNotUnknown() throws {
        let item = try XCTUnwrap(parse(nutriments: #"{"energy-kcal_100g":0,"proteins_100g":0,"carbohydrates_100g":0,"fat_100g":0}"#))
        XCTAssertEqual(item.knownFat, 0, "Un 0 écrit sur l'étiquette est une vraie valeur")
        XCTAssertFalse(item.hasUnknownMacros)
    }

    func testOpenFoodFactsTextNumbersWithCommaAreRead() throws {
        let item = try XCTUnwrap(parse(nutriments: #"{"energy-kcal_100g":"250,5","proteins_100g":"12,5"}"#))
        XCTAssertEqual(item.kcal, 250.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.knownProtein), 12.5, accuracy: 0.001)
    }

    func testOpenFoodFactsWithoutEnergyNorMacrosGivesNoFood() {
        XCTAssertNil(parse(nutriments: "{}"))
        XCTAssertNil(OpenFoodFacts.food(fromProductJSON: Data("pas du json".utf8)))
    }

    func testOpenFoodFactsBarcodeBecomesTheIdentifier() throws {
        let json = Data(#"{"product_name":"X","nutriments":{"energy-kcal_100g":100}}"#.utf8)
        let item = try XCTUnwrap(OpenFoodFacts.food(fromProductJSON: json, barcode: "123"))
        XCTAssertEqual(item.id, "off.123")
        XCTAssertEqual(item.source, .openFoodFacts)
    }

    // MARK: - Totaux incomplets

    func testIncompleteFlagFollowsTheFoodsOfTheRecap() throws {
        let incomplete = try XCTUnwrap(parse(nutriments: #"{"energy-kcal_100g":250,"proteins_100g":10}"#))
        var recap = ScanRecap()
        recap.add(try table("rice"), grams: 150)
        XCTAssertFalse(recap.isIncomplete)
        XCTAssertFalse(recap.totals.isIncomplete)
        recap.add(incomplete, grams: 50)
        XCTAssertTrue(recap.isIncomplete)
        XCTAssertTrue(recap.totals.isIncomplete, "Un aliment incomplet rend le total incomplet")
        XCTAssertFalse(try table("rice").nutrients(grams: 150).isIncomplete)
    }

    // MARK: - (3) Fourchettes d'incertitude

    private func packed(kcal: Double = 400) -> FoodItem {
        FoodItem(id: "off.test.bar", name: "Barre", brand: nil, kcal: kcal, protein: 8, carbs: 62, fat: 15, fiber: 4,
                 servingGrams: 25, servingName: "1 barre", source: .openFoodFacts, barcode: "999")
    }

    private func table(_ id: String) throws -> FoodItem {
        try XCTUnwrap(FoodDatabase.item("builtin.\(id)"))
    }

    private func bounds(_ range: NutrientRange?) throws -> (low: Double, high: Double) {
        let r = try XCTUnwrap(range)
        return (r.low, r.high)
    }

    func testPackagedProductRangeIsFivePercent() throws {
        let line = ScanLine(food: packed(), grams: 50)
        let kcal = line.totals.kcal
        let b = try bounds(line.kcalRange)
        XCTAssertEqual(b.low, kcal * 0.95, accuracy: 0.5)
        XCTAssertEqual(b.high, kcal * 1.05, accuracy: 0.5)
    }

    func testTableUsualPortionRangeIsThirtyPercent() throws {
        let rice = try table("rice")
        let line = ScanLine(food: rice, grams: rice.servingGrams, quantityIsUsual: true)
        let kcal = line.totals.kcal
        let b = try bounds(line.kcalRange)
        XCTAssertEqual(b.low, kcal * 0.7, accuracy: 0.5)
        XCTAssertEqual(b.high, kcal * 1.3, accuracy: 0.5)
    }

    func testPhotoEstimateRangeIsFortyPercent() throws {
        let pizza = try table("pizza")
        let line = ScanLine(food: pizza, grams: pizza.servingGrams, isEstimate: true, confidence: 0.6)
        let kcal = line.totals.kcal
        let b = try bounds(line.kcalRange)
        XCTAssertEqual(b.low, kcal * 0.6, accuracy: 0.5)
        XCTAssertEqual(b.high, kcal * 1.4, accuracy: 0.5)
    }

    func testLevelsAreOrderedAndAlwaysContainTheValue() throws {
        let pizza = try table("pizza")
        let estimate = ScanLine(food: pizza, grams: 110, isEstimate: true, confidence: 0.6)
        let usual = ScanLine(food: pizza, grams: 110, quantityIsUsual: true)
        let product = ScanLine(food: packed(), grams: 25)
        let widths = try [product, usual, estimate].map { line -> Double in
            let b = try bounds(line.kcalRange)
            XCTAssertLessThanOrEqual(b.low, line.totals.kcal)
            XCTAssertGreaterThanOrEqual(b.high, line.totals.kcal)
            return (b.high - b.low) / max(line.totals.kcal, 1)
        }
        XCTAssertLessThan(widths[0], widths[1], "Un emballé est plus précis qu'une portion de table")
        XCTAssertLessThan(widths[1], widths[2], "Une portion de table est plus précise qu'une photo")
    }

    func testRecapRangeIsTheSumOfTheLines() throws {
        var recap = ScanRecap()
        recap.add(packed(), grams: 50)
        recap.add(try table("pizza"), grams: 110, isEstimate: true, confidence: 0.5)
        let lines = try recap.lines.map { try bounds($0.kcalRange) }
        let total = try bounds(recap.kcalRange)
        XCTAssertEqual(total.low, lines.map(\.low).reduce(0, +), accuracy: 0.5)
        XCTAssertEqual(total.high, lines.map(\.high).reduce(0, +), accuracy: 0.5)
        XCTAssertLessThanOrEqual(total.low, recap.totals.kcal)
        XCTAssertGreaterThanOrEqual(total.high, recap.totals.kcal)
    }

    func testZeroCalorieFoodHasNoNegativeRange() throws {
        let water = try table("water")
        let b = try bounds(ScanLine(food: water, grams: 355, isEstimate: true).kcalRange)
        XCTAssertGreaterThanOrEqual(b.low, 0)
        XCTAssertGreaterThanOrEqual(b.high, b.low)
    }

    func testQuantitySetByThePersonBecomesWeighed() throws {
        var recap = ScanRecap()
        let id = recap.add(try table("rice"))
        XCTAssertEqual(recap.lines[0].uncertainty, ScanUncertainty.usualPortion)
        XCTAssertTrue(recap.showsRange)
        recap.setGrams(id, 200)
        XCTAssertEqual(recap.lines[0].uncertainty, ScanUncertainty.weighed)
        XCTAssertFalse(recap.showsRange, "Une quantité pesée s'affiche comme un chiffre")
    }

    func testRangeConstantsAndRounding() {
        XCTAssertEqual(ScanUncertainty.weighed, 0.05)
        XCTAssertEqual(ScanUncertainty.usualPortion, 0.30)
        XCTAssertEqual(ScanUncertainty.photoEstimate, 0.40)
        let r = ScanUncertainty.range(of: 100, ratio: 0.4).rounded(to: 10)
        XCTAssertEqual(r.low, 60)
        XCTAssertEqual(r.high, 140)
        let odd = NutrientRange(low: 423, high: 557).rounded(to: 10)
        XCTAssertEqual(odd.low, 420)
        XCTAssertEqual(odd.high, 560)
    }

    // MARK: - Suggestions (huile, beurre, sauce)

    private func photoRecap(_ name: String) -> ScanRecap {
        let item = FoodItem(id: "test.\(name)", name: name, brand: nil, kcal: 150, protein: 5, carbs: 20, fat: 5, fiber: 1,
                            servingGrams: 150, servingName: "1", source: .custom, barcode: nil)
        return ScanRecap(proposals: [MealProposal(food: item, grams: 150, confidence: 0.7)])
    }

    func testSuggestionsAreOfferedForAPhotoNeverAddedAlone() throws {
        let recap = photoRecap("Fried rice")
        let suggestions = recap.suggestions()
        let oil = try XCTUnwrap(suggestions.first { $0.kind == .oil })
        XCTAssertEqual(oil.food.id, "builtin.oliveoil")
        XCTAssertEqual(oil.grams, 10)
        XCTAssertEqual(oil.totals.kcal, 88.4, accuracy: 0.1)
        XCTAssertEqual(recap.lines.count, 1, "Une suggestion n'est jamais ajoutée en silence")
    }

    func testAcceptingASuggestionAddsAnEstimateLineOnce() throws {
        var recap = photoRecap("Fried rice")
        let oil = try XCTUnwrap(recap.suggestions().first { $0.kind == .oil })
        recap.accept(oil)
        XCTAssertEqual(recap.lines.count, 2)
        let line = try XCTUnwrap(recap.lines.first { $0.food.id == "builtin.oliveoil" })
        XCTAssertEqual(line.grams, 10)
        XCTAssertTrue(line.isEstimate)
        XCTAssertFalse(recap.suggestions().contains { $0.kind == .oil }, "Déjà ajoutée : plus proposée")
    }

    func testNoSuggestionForABarcodeProductOrAnUnlikelyDish() {
        XCTAssertTrue(ScanRecap(food: packed()).suggestions().isEmpty)
        XCTAssertTrue(photoRecap("Banana").suggestions().isEmpty)
        XCTAssertTrue(ScanRecap().suggestions().isEmpty)
    }

    func testSuggestionNeedsTheFoodOfTheTable() {
        XCTAssertTrue(photoRecap("Fried rice").suggestions(foodByID: { _ in nil }).isEmpty)
    }

    func testButterAndSauceSuggestions() {
        XCTAssertTrue(photoRecap("Toast").suggestions().contains { $0.kind == .butter && $0.food.id == "builtin.butter" })
        let sauce = photoRecap("Pasta").suggestions().first { $0.kind == .sauce }
        XCTAssertEqual(sauce?.food.id, "builtin.mayo")
        XCTAssertEqual(sauce?.grams, 15)
    }


    // MARK: - (5) Repas de référence « pesés » (synthétiques)

    private struct Meal {
        let name: String
        /// (aliment, grammes réellement pesés)
        let items: [(id: String, grams: Double)]
    }

    private let packagedBar = FoodItem(id: "off.test.bar", name: "Barre emballée", brand: nil, kcal: 420, protein: 8, carbs: 62, fat: 15, fiber: 4,
                                       servingGrams: 25, servingName: "1 barre", source: .openFoodFacts, barcode: "999")

    /// Douze repas d'une même personne qui mange plus que les portions de la table (aliments répétés à +40 % ou plus,
    /// à ±8 % près d'un repas à l'autre) : toutes les erreurs ont le même signe, donc apprendre ses quantités ne peut
    /// pas aggraver l'erreur. Les grammes pesés sont inventés ; les valeurs nutritives viennent de la table.
    private var meals: [Meal] {
        [
            Meal(name: "Poulet, riz, brocoli (1)", items: [("builtin.rice", 240), ("builtin.chicken", 175), ("builtin.broccoli", 130)]),
            Meal(name: "Poulet, riz, brocoli (2)", items: [("builtin.rice", 250), ("builtin.chicken", 185), ("builtin.broccoli", 140)]),
            Meal(name: "Saumon, riz, brocoli", items: [("builtin.rice", 260), ("builtin.salmon", 150), ("builtin.broccoli", 135)]),
            Meal(name: "Riz, œufs, huile", items: [("builtin.rice", 245), ("builtin.egg", 100), ("builtin.oliveoil", 20)]),
            Meal(name: "Pâtes, sauce tomate, poulet", items: [("builtin.pasta", 210), ("builtin.tomatosauce", 150), ("builtin.chicken", 180)]),
            Meal(name: "Pizza et banane", items: [("builtin.pizza", 180), ("builtin.banana", 120)]),
            Meal(name: "Pizza et pomme", items: [("builtin.pizza", 190), ("builtin.apple", 180)]),
            Meal(name: "Pizza et barre emballée", items: [("builtin.pizza", 185), ("off.test.bar", 25)]),
            Meal(name: "Pizza et salade", items: [("builtin.pizza", 175), ("builtin.gardensalad", 150)]),
            Meal(name: "Pâtes à l'huile (1)", items: [("builtin.pasta", 220), ("builtin.oliveoil", 21)]),
            Meal(name: "Pâtes à l'huile (2)", items: [("builtin.pasta", 215), ("builtin.oliveoil", 20)]),
            Meal(name: "Plat composé : spaghetti bolognaise", items: [("builtin.spaghetti", 450)]),
        ]
    }

    private func resolve(_ id: String) throws -> FoodItem {
        if id == packagedBar.id { return packagedBar }
        return try XCTUnwrap(FoodDatabase.item(id), id)
    }

    private struct Measure {
        var weight = 0.0, kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        var all: [Double] { [weight, kcal, protein, carbs, fat] }
    }

    private func totals(_ pairs: [(FoodItem, Double)]) -> NutritionTotals {
        pairs.reduce(NutritionTotals()) { $0 + $1.0.nutrients(grams: $1.1) }
    }

    private func relativeError(_ estimate: Double, _ truth: Double) -> Double {
        truth > 0 ? abs(estimate - truth) / truth * 100 : 0
    }

    private func errors(estimated: [(FoodItem, Double)], truth: [(FoodItem, Double)]) -> Measure {
        let e = totals(estimated), t = totals(truth)
        return Measure(
            weight: relativeError(estimated.map(\.1).reduce(0, +), truth.map(\.1).reduce(0, +)),
            kcal: relativeError(e.kcal, t.kcal),
            protein: relativeError(v(e.protein), v(t.protein)),
            carbs: relativeError(v(e.carbs), v(t.carbs)),
            fat: relativeError(v(e.fat), v(t.fat)))
    }

    private func summarize(_ title: String, _ list: [Measure]) -> (mean: Measure, worst: Measure, text: String) {
        func column(_ key: KeyPath<Measure, Double>) -> [Double] { list.map { $0[keyPath: key] } }
        func mean(_ key: KeyPath<Measure, Double>) -> Double { column(key).reduce(0, +) / Double(max(list.count, 1)) }
        func worst(_ key: KeyPath<Measure, Double>) -> Double { column(key).max() ?? 0 }
        let m = Measure(weight: mean(\.weight), kcal: mean(\.kcal), protein: mean(\.protein), carbs: mean(\.carbs), fat: mean(\.fat))
        let w = Measure(weight: worst(\.weight), kcal: worst(\.kcal), protein: worst(\.protein), carbs: worst(\.carbs), fat: worst(\.fat))
        let text = """
        \(title)
          moyenne : poids \(pct(m.weight)) | kcal \(pct(m.kcal)) | P \(pct(m.protein)) | G \(pct(m.carbs)) | L \(pct(m.fat))
          pire cas: poids \(pct(w.weight)) | kcal \(pct(w.kcal)) | P \(pct(w.protein)) | G \(pct(w.carbs)) | L \(pct(w.fat))
        """
        return (m, w, text)
    }

    func testReferenceMealsErrorBeforeAndAfterPersonalization() throws {
        let meals = self.meals
        XCTAssertEqual(meals.count, 12)
        var before: [Measure] = []
        var after: [Measure] = []
        var detail: [String] = []

        for (index, meal) in meals.enumerated() {
            let foods = try meal.items.map { try resolve($0.id) }
            let truth = Array(zip(foods, meal.items.map(\.grams)))
            let usual = foods.map { $0.servingGrams > 0 ? $0.servingGrams : 100 }

            // Repas appris : tous les AUTRES repas (validation croisée, jamais le repas évalué).
            var learning = ScanLearning()
            var day = 0.0
            for (otherIndex, other) in meals.enumerated() where otherIndex != index {
                for item in other.items {
                    let food = try resolve(item.id)
                    day += 1
                    learning.record(
                        ScanCorrection(date: Date(timeIntervalSince1970: 1_800_000_000 + day * 3_600), labels: [food.name],
                                       detectedFoodID: food.id, initialGrams: food.servingGrams, validatedFoodID: food.id,
                                       validatedGrams: item.grams, quarantined: false),
                        plausibleGramsRange: 1...5_000)
                }
            }
            let personalized = zip(foods, usual).map { food, fallback in learning.usualGrams(forFoodID: food.id) ?? fallback }

            let scanned = errors(estimated: Array(zip(foods, usual)), truth: truth)
            let learned = errors(estimated: Array(zip(foods, personalized)), truth: truth)
            before.append(scanned)
            after.append(learned)
            detail.append("\(meal.name): kcal \(pct(scanned.kcal)) -> \(pct(learned.kcal)) | poids \(pct(scanned.weight)) -> \(pct(learned.weight))")

            // Pour ce jeu (erreurs toutes du même signe), apprendre ne peut pas aggraver un repas.
            for (a, b) in zip(scanned.all, learned.all) {
                XCTAssertLessThanOrEqual(b, a + 0.001, "\(meal.name) : la personnalisation aggrave l'erreur")
            }
        }

        let b = summarize("AVANT personnalisation (portions usuelles de la table)", before)
        let a = summarize("APRÈS personnalisation (quantités habituelles apprises, validation croisée)", after)
        let gain = b.mean.kcal - a.mean.kcal
        attach("SCAN-ERREURS", """
        12 repas de référence synthétiques, erreur relative du scan estimé contre la vérité pesée.
        Aliments supposés bien reconnus : seule la quantité est estimée.

        \(b.text)

        \(a.text)

        Gain sur l'erreur moyenne en kcal : \(String(format: "%.1f", gain)) points
        \nDétail par repas :
        \(detail.joined(separator: "\n"))
        """)

        // Le scan estimé a bien une erreur (sinon le jeu ne mesure rien), et la personnalisation ne l'aggrave pas.
        XCTAssertGreaterThan(b.mean.kcal, 5)
        for (x, y) in zip(b.mean.all, a.mean.all) { XCTAssertLessThanOrEqual(y, x + 0.001) }
        for (x, y) in zip(b.worst.all, a.worst.all) { XCTAssertLessThanOrEqual(y, x + 0.001) }
    }

    func testPackagedProductInReferenceMealsHasNoWeightError() throws {
        let food = try resolve("off.test.bar")
        let measure = errors(estimated: [(food, food.servingGrams)], truth: [(food, 25)])
        XCTAssertEqual(measure.kcal, 0, accuracy: 0.001)
        XCTAssertEqual(measure.weight, 0, accuracy: 0.001)
    }
}
