import XCTest
@testable import Ardane

/// The food base of the app (`ardane-food.sqlite`, built by `scripts/food_db/build.py` from the Canadian Nutrient File
/// 2026 and USDA SR Legacy): the identifiers of the earlier edition, the search, where each value comes from, portions,
/// densities, cooking yields, unknown values that stay unknown and the energy check.
///
/// The expected numbers are the ones of the files of the sources (see `docs/scanner/food-db-report.md`).
final class FoodRepositoryTests: XCTestCase {
    private func repository(file: StaticString = #filePath, line: UInt = #line) throws -> FoodRepository {
        try XCTUnwrap(NutrientFile.foodRepository, "ardane-food.sqlite missing from the app", file: file, line: line)
    }

    // MARK: Identifiers

    func testTheIdentifiersOfTheEarlierEditionAreResolved() throws {
        let repo = try repository()
        // 4779 and 2213 are Food_Code too: the same food under the same number.
        XCTAssertEqual(repo.item(id: "cnf.4779", preferFrench: false)?.id, "cnf.4779")
        XCTAssertEqual(repo.item(id: "cnf.2213", preferFrench: false)?.name, "Spinach, raw")
        XCTAssertEqual(repo.resolvedID(of: "cnf.2213"), "cnf.2213")
        // 501098 was an internal FoodID of the 2015 edition: it is Food_Code 6304 (alias table).
        let napa = try XCTUnwrap(repo.item(id: "cnf.501098", preferFrench: false))
        XCTAssertEqual(napa.id, "cnf.6304")
        XCTAssertEqual(napa.name, "Cabbage, napa, raw")
        XCTAssertEqual(repo.resolvedID(of: "cnf.501098"), "cnf.6304")
        XCTAssertEqual(repo.item(id: "cnf.501898", preferFrench: false)?.id, "cnf.6675", "Steamed rice, by the FoodCode of 2015")
        // What is not in the base stays absent: a food removed from the file, a table of the app, a malformed identifier.
        XCTAssertNil(repo.item(id: "cnf.117"), "Retired from the file")
        XCTAssertNil(repo.resolvedID(of: "cnf.117"))
        XCTAssertNil(repo.item(id: "builtin.apple"))
        XCTAssertNil(repo.item(id: "off.3017620422003"))
        XCTAssertNil(repo.item(id: "cnf.abc"))
        XCTAssertNil(repo.item(id: "cnf."))
        XCTAssertNil(repo.item(id: "cnf.999999999999"))
        // The identifiers are written and read the same way.
        XCTAssertEqual(SQLiteFoodRepository.databaseID(ofIdentifier: "cnf.6304"), 6304)
        XCTAssertEqual(SQLiteFoodRepository.databaseID(ofIdentifier: "usda.1029"), 101_029)
        XCTAssertNil(SQLiteFoodRepository.databaseID(ofIdentifier: "cnf.501098"), "Not a Food_Code: only the alias knows it")
        XCTAssertNil(SQLiteFoodRepository.databaseID(ofIdentifier: "custom.soup"))
        XCTAssertEqual(SQLiteFoodRepository.identifier(ofDatabaseID: 101_029), "usda.1029")
        XCTAssertEqual(SQLiteFoodRepository.identifier(ofDatabaseID: 6304), "cnf.6304")
    }

    func testTheAppSearchAndLookupUseTheNewBase() throws {
        _ = try repository()
        XCTAssertFalse(NutrientFile.isEmpty)
        XCTAssertTrue(NutrientFile.search("poutine").contains { $0.id == "cnf.6772" })
        XCTAssertEqual(NutrientFile.item(id: "cnf.501098")?.id, "cnf.6304")
        XCTAssertFalse(NutrientFile.attribution.isEmpty)
    }

    // MARK: Search

    func testPoutineIsThere() throws {
        let repo = try repository()
        let poutine = try XCTUnwrap(repo.search("poutine", limit: 10, preferFrench: true).first)
        XCTAssertEqual(poutine.id, "cnf.6772")
        XCTAssertEqual(poutine.name, "Poutine")
        XCTAssertEqual(poutine.source, .nutrientFile)
        XCTAssertEqual(poutine.kcal, 226)
        XCTAssertEqual(poutine.servingGrams, 195, "The serving the file gives in grams")
        XCTAssertEqual(poutine.servingName, "195 g")
    }

    func testTheSearchIgnoresAccentsAndFindsBothLanguages() throws {
        let repo = try repository()
        let withAccent = repo.search("épinard cru", limit: 50, preferFrench: true).map(\.id)
        let without = repo.search("epinard cru", limit: 50, preferFrench: true).map(\.id)
        XCTAssertEqual(withAccent, without)
        XCTAssertTrue(withAccent.contains("cnf.2213"))
        XCTAssertTrue(repo.search("spinach raw", limit: 50, preferFrench: true).contains { $0.id == "cnf.2213" }, "English words find it in French too")
        XCTAssertTrue(repo.search("coke", limit: 50, preferFrench: false).contains { $0.id == "cnf.2920" }, "An alternate name of the file")
        XCTAssertTrue(repo.search("", limit: 10, preferFrench: true).isEmpty)
        XCTAssertTrue(repo.search("   ", limit: 10, preferFrench: true).isEmpty)
        XCTAssertTrue(repo.search("zzzzqqqq", limit: 10, preferFrench: true).isEmpty)
        XCTAssertLessThanOrEqual(repo.search("a", limit: 7, preferFrench: false).count, 7)
    }

    func testTheNamesFollowTheLanguageAndTheUSDAFoodsStayEnglish() throws {
        let repo = try repository()
        XCTAssertEqual(repo.item(id: "cnf.2213", preferFrench: true)?.name, "Épinard, cru")
        XCTAssertEqual(repo.item(id: "cnf.2213", preferFrench: false)?.name, "Spinach, raw")
        let french = try XCTUnwrap(repo.item(id: "usda.1029", preferFrench: true))
        XCTAssertEqual(french.name, "Cheese, mozzarella, low moisture, part-skim", "Never translated automatically")
        XCTAssertEqual(french.source, .nutrientFile)
        XCTAssertEqual(french.servingGrams, 132)
        XCTAssertEqual(french.servingName, "1 cup, diced")
        XCTAssertTrue(repo.search("mozzarella low moisture", limit: 50, preferFrench: true).contains { $0.id == "usda.1029" })
    }

    func testTheSearchKeyDropsAccentsCaseAndLigatures() {
        XCTAssertEqual(FoodSearchKey.normalized("Œuf Épinard"), "oeuf epinard")
        XCTAssertEqual(FoodSearchKey.normalized("Crème brûlée"), "creme brulee")
        XCTAssertEqual(FoodSearchKey.words("Crème d'été 2 %"), ["creme", "d", "ete", "2"])
        XCTAssertEqual(FoodSearchKey.words("  "), [])
    }

    // MARK: Provenance

    func testEveryValueKeepsItsProvenance() throws {
        let repo = try repository()
        let protein = try XCTUnwrap(repo.provenance(id: "cnf.2213", nutrient: FoodNutrientCode.protein))
        XCTAssertEqual(protein.sourceCode, 0, "No change from USDA")
        XCTAssertEqual(protein.kind, .usda)
        XCTAssertEqual(protein.observations, 9)
        XCTAssertEqual(try XCTUnwrap(protein.standardError), 0.112, accuracy: 0.00001)
        XCTAssertFalse((protein.label ?? "").isEmpty)
        XCTAssertFalse(protein.isDerived)

        // The omega-3 total is not in the file: Ardane adds the fatty acids up, and says so.
        let omega3 = try XCTUnwrap(repo.provenance(id: "cnf.2213", nutrient: FoodNutrientCode.omega3))
        XCTAssertTrue(omega3.isDerived)
        XCTAssertNil(omega3.observations)
        XCTAssertNil(omega3.standardError)

        // A value taken from the scientific literature in the Canadian file (napa cabbage, potassium).
        let potassium = try XCTUnwrap(repo.provenance(id: "cnf.6304", nutrient: FoodNutrientCode.potassium))
        XCTAssertEqual(potassium.sourceCode, 10)
        XCTAssertEqual(potassium.kind, .other)

        // The old identifier works for the provenance too, and a USDA food has the provenance of its own file.
        XCTAssertEqual(repo.provenance(id: "cnf.501098", nutrient: FoodNutrientCode.potassium)?.sourceCode, 10)
        XCTAssertNotNil(repo.provenance(id: "usda.1029", nutrient: FoodNutrientCode.protein))
    }

    func testAnUnknownValueIsNeverAZero() throws {
        let repo = try repository()
        // The sum of omega-6 has a missing part for these two foods: no total, not 0.
        XCTAssertNil(repo.provenance(id: "cnf.2213", nutrient: FoodNutrientCode.omega6))
        XCTAssertNil(repo.provenance(id: "cnf.4779", nutrient: FoodNutrientCode.omega6))
        XCTAssertNil(repo.provenance(id: "cnf.2213", nutrient: 99_999), "Not a nutrient of the base")
        XCTAssertNil(try XCTUnwrap(repo.item(id: "cnf.4779")).micros?.omega6Fat)
        XCTAssertEqual(try XCTUnwrap(repo.item(id: "cnf.4779")).micros?.alcohol, 0, "A zero the file gives is a known zero")

        // Across many foods: a micronutrient is known exactly when the base has a value (and so a provenance) for it.
        let fields: [(String, KeyPath<Micronutrients, Double?>, Int)] = [
            ("potassium", \.potassiumMg, 306), ("calcium", \.calciumMg, 301), ("iron", \.ironMg, 303), ("vitamin K", \.vitaminKMcg, 430),
            ("caffeine", \.caffeineMg, 262), ("alcohol", \.alcohol, 221), ("zinc", \.zincMg, 309), ("omega-3", \.omega3Fat, 10_001),
            ("omega-6", \.omega6Fat, 10_002), ("trans fat", \.transFat, 605),
        ]
        let foods = repo.search("a", limit: 250, preferFrench: false) + repo.search("chicken", limit: 60, preferFrench: false)
        XCTAssertGreaterThan(foods.count, 100)
        for food in foods {
            for (name, path, code) in fields {
                let known = food.micros?[keyPath: path] != nil
                XCTAssertEqual(known, repo.provenance(id: food.id, nutrient: code) != nil, "\(food.id) \(name)")
            }
        }
    }

    // MARK: Portions, densities, yields

    func testPortionsAreAllThere() throws {
        let repo = try repository()
        let apple = try XCTUnwrap(repo.item(id: "cnf.7215", preferFrench: false))
        XCTAssertEqual(apple.servingGrams, 167)
        XCTAssertEqual(apple.servingName, "1 medium")
        XCTAssertEqual(repo.item(id: "cnf.7215", preferFrench: true)?.servingName, "1 moyen")

        let portions = repo.portions(id: "cnf.7215", preferFrench: false)
        XCTAssertEqual(portions.filter(\.isDefault).count, 1)
        XCTAssertEqual(portions.first { $0.isDefault }?.label, "1 medium")
        XCTAssertTrue(portions.contains { $0.label == "1 small" && $0.grams == 144 && $0.kind == .household })
        XCTAssertTrue(portions.contains { $0.label == "1 large" && $0.grams == 206 && $0.kind == .household })
        XCTAssertEqual(portions.first { $0.label == "250 ml slices" }?.milliliters, 250)
        XCTAssertTrue(portions.contains { $0.kind == .refuse && $0.grams == 11 }, "The core and stem: 11 % of the apple")
        XCTAssertGreaterThan(portions.filter { $0.kind == .household }.count, 5, "More than the single portion the earlier file kept")
        XCTAssertEqual(repo.portions(id: "cnf.501098", preferFrench: false).first { $0.isDefault }?.label, "85 g", "By the old identifier")
        XCTAssertTrue(repo.portions(id: "builtin.apple", preferFrench: false).isEmpty)
    }

    func testDensitiesAreWhatTheMeasuresInMillilitresSay() throws {
        let repo = try repository()
        let water = try XCTUnwrap(repo.density(id: "cnf.2933"), "Water, municipal")
        XCTAssertEqual(water.gPerMl, 1.0, accuracy: 0.05)
        XCTAssertEqual(water.kind, .plain)
        let espresso = try XCTUnwrap(repo.density(id: "cnf.4779"))
        XCTAssertEqual(espresso.gPerMl, 1.0, accuracy: 0.02)
        let napa = try XCTUnwrap(repo.density(id: "cnf.6304"))
        XCTAssertEqual(napa.gPerMl, 0.31, accuracy: 0.03, "A cup of shredded napa weighs 79 g")
        // Raw spinach: 0.13 g/ml, under the filter (0.2 to 2.0): no density, rather than a doubtful one.
        XCTAssertTrue(repo.densities(id: "cnf.2213").isEmpty)
        XCTAssertNil(repo.density(id: "builtin.apple"))

        for id in ["cnf.2933", "cnf.4779", "cnf.6304", "cnf.7215", "cnf.6772", "usda.1029"] {
            let densities = repo.densities(id: id)
            XCTAssertFalse(densities.isEmpty, id)
            for density in densities {
                XCTAssertTrue((0.2...2.0).contains(density.gPerMl), "\(id) \(density.measure): \(density.gPerMl)")
                XCTAssertGreaterThan(density.milliliters, 0)
                XCTAssertEqual(density.gPerMl, density.measureGrams / density.milliliters, accuracy: 1e-9, "\(id) \(density.measure)")
            }
        }
        // Slices of apple are pieces, with air between them: lighter than the apple.
        let apple = try XCTUnwrap(repo.density(id: "cnf.7215"))
        XCTAssertEqual(apple.kind, .pieces)
        XCTAssertLessThan(apple.gPerMl, 0.6)
    }

    func testCookingYieldsAreLinkedByTheNDBCode() throws {
        let repo = try repository()
        let gizzard = repo.cookingYields(id: "cnf.575")
        XCTAssertEqual(gizzard.count, 1)
        XCTAssertEqual(gizzard.first?.method, "Poached, Simmered or Stewed")
        XCTAssertEqual(gizzard.first?.percent, 55)
        XCTAssertEqual(try XCTUnwrap(gizzard.first).factor, 0.55, accuracy: 1e-9)
        XCTAssertEqual(gizzard.first?.rawFoodID, "cnf.574", "The raw gizzard")
        XCTAssertNotNil(gizzard.first?.moistureChangePercent)

        let drumstick = repo.cookingYields(id: "usda.5676")
        XCTAssertEqual(drumstick.first?.percent, 77)
        XCTAssertEqual(drumstick.first?.method, "Braised")
        XCTAssertTrue(repo.cookingYields(id: "cnf.2213").isEmpty, "No yield for a vegetable: nothing made up")
    }

    // MARK: Preparation and checks

    func testRawAndCookedAreDeducedFromTheNames() throws {
        let repo = try repository()
        XCTAssertEqual(repo.preparationState(id: "cnf.2213"), .raw)
        XCTAssertEqual(repo.preparationState(id: "cnf.4523"), .cooked, "Rice, cooked")
        XCTAssertEqual(repo.preparationState(id: "cnf.6772"), .notStated, "Poutine")
        XCTAssertNil(repo.preparationState(id: "builtin.rice"))
    }

    func testTheEnergyCheckIsTheOneOfTheBuild() throws {
        // 4 kcal/g protein and carbohydrate, 9 kcal/g fat, 7 kcal/g alcohol; flagged beyond max(15 kcal, 15 %).
        XCTAssertTrue(FoodEnergyCheck.isConsistent(kcal: 52, protein: 0.3, carbs: 14, fat: 0.2))
        XCTAssertFalse(FoodEnergyCheck.isConsistent(kcal: 0, protein: 0, carbs: 100, fat: 0))
        XCTAssertTrue(FoodEnergyCheck.isConsistent(kcal: 95, protein: 10, carbs: 10, fat: 0), "15 kcal off: at the limit")
        XCTAssertFalse(FoodEnergyCheck.isConsistent(kcal: 96, protein: 10, carbs: 10, fat: 0))
        XCTAssertTrue(FoodEnergyCheck.isConsistent(kcal: 500, protein: nil, carbs: 10, fat: 5), "A macro unknown: nothing to compare")
        XCTAssertEqual(try XCTUnwrap(FoodEnergyCheck.energyFromMacros(protein: 0, carbs: 0, fat: 0, alcohol: 10)), 70, accuracy: 1e-9)

        let repo = try repository()
        XCTAssertEqual(repo.qualityFlags(id: "cnf.2213")?.rawValue, 0)
        XCTAssertEqual(repo.qualityFlags(id: "cnf.7245")?.contains(.energy), true, "Stevia: 0 kcal published, 400 from the macros")
        XCTAssertNil(repo.qualityFlags(id: "builtin.rice"))

        // The rule of the app and the flags of the build agree on every food seen, and few foods are flagged.
        let foods = repo.search("a", limit: 400, preferFrench: false)
        XCTAssertGreaterThan(foods.count, 100)
        var flagged = 0
        for food in foods {
            let flags = try XCTUnwrap(repo.qualityFlags(id: food.id), food.id)
            XCTAssertEqual(flags.contains(.energy), !FoodEnergyCheck.isConsistent(food), "\(food.id) \(food.name)")
            if flags.contains(.energy) { flagged += 1 }
        }
        XCTAssertLessThan(Double(flagged), Double(foods.count) * 0.10, "About 2 % of the foods are flagged")
    }

    func testTheFoodsHaveTheirMacrosAndTheFileStaysSmall() throws {
        let repo = try repository()
        for id in ["cnf.7215", "cnf.4523", "cnf.6772", "cnf.2213", "usda.1029"] {
            let food = try XCTUnwrap(repo.item(id: id, preferFrench: false), id)
            XCTAssertGreaterThan(food.kcal, 0, id)
            XCTAssertFalse(food.hasUnknownMacros, id)
            XCTAssertGreaterThan(food.servingGrams, 0, id)
        }
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ardane-food", withExtension: "sqlite"))
        let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber).intValue
        XCTAssertLessThan(size, 12 * 1_048_576, "The base stays under 12 MB")
    }
}
