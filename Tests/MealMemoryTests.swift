import XCTest
@testable import Tessera

/// Mémoire visuelle locale : distance entre empreintes, voisins, seuil, 2 repas concordants contre 1,
/// limite de 200 repas, anciennes données (sans la clé) et aller-retour d'encodage.
final class MealMemoryTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// A fingerprint of 8 numbers: `base` is the shape, `noise` a small shift of one number.
    private func print8(_ base: [Float], noise: Float = 0) -> [Float] {
        var v = base
        v[0] += noise
        return v
    }

    private let plate: [Float] = [1, 2, 3, 4, 5, 6, 7, 8]
    private let other: [Float] = [8, -7, 6, -5, 4, -3, 2, -1]

    private func item(_ id: String, _ grams: Double) -> MealMemoryItem { MealMemoryItem(foodID: id, grams: grams) }

    // MARK: Distance

    func testDistanceOfTheSameShapeIsZeroWhateverTheSize() throws {
        let d = try XCTUnwrap(MealMemory.distance(plate, plate.map { $0 * 3 }))
        XCTAssertEqual(d, 0, accuracy: 1e-6)
    }

    func testDistanceOfOppositeVectorsIsOne() throws {
        let d = try XCTUnwrap(MealMemory.distance(plate, plate.map { -$0 }))
        XCTAssertEqual(d, 1, accuracy: 1e-6)
    }

    func testDistanceIsSymmetricAndBounded() throws {
        let a = try XCTUnwrap(MealMemory.distance(plate, other))
        let b = try XCTUnwrap(MealMemory.distance(other, plate))
        XCTAssertEqual(a, b, accuracy: 1e-9)
        XCTAssertTrue((0...1).contains(a))
    }

    func testDistanceRefusesWhatCannotBeCompared() {
        XCTAssertNil(MealMemory.distance([], []))
        XCTAssertNil(MealMemory.distance(plate, [1, 2]))
        XCTAssertNil(MealMemory.distance([0, 0, 0], [1, 2, 3]))
        XCTAssertNil(MealMemory.distance([Float.nan, 1], [1, 1]))
    }

    // MARK: Enregistrement

    func testRecordRefusesAnUnusableFingerprintOrNoFood() {
        var memory = MealMemory()
        memory.record(date: start, featurePrint: [], items: [item("a", 100)])
        memory.record(date: start, featurePrint: [0, 0, 0], items: [item("a", 100)])
        memory.record(date: start, featurePrint: plate, items: [])
        memory.record(date: start, featurePrint: plate, items: [item("", 100), item("a", 0), item("b", .nan), item("c", 99_999)])
        XCTAssertTrue(memory.entries.isEmpty)
    }

    func testRecordAddsTheQuantitiesOfAFoodSeenTwice() throws {
        var memory = MealMemory()
        memory.record(date: start, featurePrint: plate, items: [item("a", 100), item("a", 50), item("b", 30)])
        let items = try XCTUnwrap(memory.entries.first?.items)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first { $0.foodID == "a" }?.grams, 150)
    }

    func testMemoryKeepsAtMostTwoHundredMealsTheOldestGoFirst() {
        var memory = MealMemory()
        for index in 0..<(MealMemory.maximumEntries + 25) {
            memory.record(date: start.addingTimeInterval(Double(index)), featurePrint: plate, items: [item("a", 100)])
        }
        XCTAssertEqual(memory.entries.count, 200)
        XCTAssertEqual(memory.entries.first?.date, start.addingTimeInterval(25))
    }

    // MARK: Voisins

    func testNearestSortsByDistanceAndAppliesTheThreshold() {
        var memory = MealMemory()
        memory.record(date: start, featurePrint: print8(plate, noise: 0.5), items: [item("near", 100)])
        memory.record(date: start, featurePrint: other, items: [item("far", 100)])
        memory.record(date: start, featurePrint: plate, items: [item("same", 100)])
        let found = memory.nearest(to: plate)
        XCTAssertEqual(found.map { $0.entry.items[0].foodID }, ["same", "near"], "Le repas éloigné dépasse le seuil")
        XCTAssertLessThan(found[0].distance, found[1].distance)
        XCTAssertTrue(found.allSatisfy { $0.distance <= MealMemory.maximumDistance })
    }

    func testNearestHonoursTheLimit() {
        var memory = MealMemory()
        for index in 0..<6 {
            memory.record(date: start.addingTimeInterval(Double(index)), featurePrint: plate, items: [item("a", 100)])
        }
        XCTAssertEqual(memory.nearest(to: plate, limit: 3).count, 3)
        XCTAssertTrue(memory.nearest(to: plate, limit: 0).isEmpty)
    }

    // MARK: Proposition

    func testNoSuggestionFromAnEmptyMemory() {
        XCTAssertNil(MealMemory().suggestion(for: plate))
    }

    func testOneSimilarMealIsNeverEnough() {
        var memory = MealMemory()
        memory.record(date: start, featurePrint: plate, items: [item("a", 100)])
        XCTAssertNil(memory.suggestion(for: plate))
    }

    func testTwoSimilarMealsWithAFoodInCommonMakeASuggestion() throws {
        var memory = MealMemory()
        memory.record(date: start, featurePrint: plate, items: [item("rice", 150), item("chicken", 120)])
        memory.record(date: start.addingTimeInterval(86_400), featurePrint: print8(plate, noise: 0.1), items: [item("rice", 250), item("peas", 40)])
        let result = try XCTUnwrap(memory.suggestionWithDate(for: plate))
        XCTAssertEqual(result.items.map(\.foodID), ["rice"], "Seul l'aliment des deux repas est proposé")
        XCTAssertEqual(result.items[0].grams, 200, "Médiane des deux quantités")
        XCTAssertEqual(result.date, start.addingTimeInterval(86_400), "Le repas le plus récent")
        XCTAssertEqual(memory.suggestion(for: plate)?.count, 1)
    }

    func testTwoSimilarMealsWithNothingInCommonGiveNothing() {
        var memory = MealMemory()
        memory.record(date: start, featurePrint: plate, items: [item("a", 100)])
        memory.record(date: start, featurePrint: print8(plate, noise: 0.1), items: [item("b", 100)])
        XCTAssertNil(memory.suggestion(for: plate), "Jamais d'invention")
    }

    func testAFarMealDoesNotCountAsAnAgreeingNeighbour() {
        var memory = MealMemory()
        memory.record(date: start, featurePrint: plate, items: [item("a", 100)])
        memory.record(date: start, featurePrint: other, items: [item("a", 100)])
        XCTAssertNil(memory.suggestion(for: plate))
    }

    // MARK: Anciennes données et encodage

    func testNutritionStateWithoutTheKeyHasAnEmptyMemory() throws {
        let old = Data(#"{"entries":[]}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(NutritionState.self, from: old).mealMemory.entries.isEmpty)
    }

    func testBrokenMemoryDecodesAsEmpty() throws {
        let broken = Data(#"{"entries":[],"mealMemory":"n'importe quoi"}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(NutritionState.self, from: broken).mealMemory.entries.isEmpty)
    }

    func testEntriesWithoutAUsableFingerprintAreDropped() throws {
        let json = Data(#"{"entries":[{"date":0,"items":[{"foodID":"a","grams":100}]},{"featurePrint":[1,2,3],"items":[]}]}"#.utf8)
        let memory = try JSONDecoder().decode(MealMemory.self, from: json)
        XCTAssertEqual(memory.entries.count, 1)
        XCTAssertEqual(memory.entries[0].featurePrint, [1, 2, 3], "Une liste simple de nombres est aussi lue")
    }

    func testEncodingRoundTripKeepsTheMealsAndTheDistances() throws {
        var state = NutritionState()
        state.mealMemory.record(date: start, featurePrint: plate, items: [item("rice", 150.5), item("chicken", 120)])
        state.mealMemory.record(date: start.addingTimeInterval(60), featurePrint: print8(plate, noise: 0.2), items: [item("rice", 200)])
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(NutritionState.self, from: data)
        XCTAssertEqual(decoded.mealMemory.entries.count, 2)
        XCTAssertEqual(decoded.mealMemory.entries[0].items, state.mealMemory.entries[0].items)
        XCTAssertEqual(decoded.mealMemory.entries[0].date, start)
        let before = try XCTUnwrap(MealMemory.distance(plate, state.mealMemory.entries[1].featurePrint))
        let after = try XCTUnwrap(MealMemory.distance(plate, decoded.mealMemory.entries[1].featurePrint))
        XCTAssertEqual(before, after, accuracy: 0.02, "L'empreinte est compactée : la distance bouge à peine")
        XCTAssertEqual(decoded.mealMemory.suggestion(for: plate)?.map(\.foodID), ["rice"])
    }
}
