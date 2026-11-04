import XCTest
import CoreGraphics
@testable import Ardane

/// The personal visual memory of the scanner and the soft context (pure logic, cases worked out by hand). The vectors used
/// are on the axes or built from a known cosine, so the numbers are exact up to the one-byte quantisation (about 0.01).
final class ScannerPersonalMemoryTests: XCTestCase {

    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    private func probability(_ list: [(key: String, probability: Double)], _ key: String) -> Double? {
        list.first { $0.key == key }?.probability
    }

    // MARK: Caps

    func testAtMostTwentyFiveEntriesPerFoodAndTheOldestGoFirst() {
        var memory = PersonalFoodMemory()
        for index in 0..<30 {
            memory.record(foodKey: "builtin.apple", embedding: [1, 0, 0], date: day.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(memory.entries.count, PersonalFoodMemory.maximumPerFood)
        let oldest = memory.entries.map(\.date).min() ?? day
        XCTAssertEqual(oldest.timeIntervalSince(day), 5, accuracy: 1e-9, "les cinq plus anciennes sont parties")
    }

    func testAtMostFourHundredEntriesInAllAndTheOldestGoFirst() {
        var memory = PersonalFoodMemory()
        for index in 0..<500 {
            memory.record(foodKey: "food.\(index % 20)", embedding: [1, 0, 0], date: day.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(memory.entries.count, PersonalFoodMemory.maximumEntries)
        let oldest = memory.entries.map(\.date).min() ?? day
        XCTAssertEqual(oldest.timeIntervalSince(day), 100, accuracy: 1e-9)
    }

    func testUnusableEmbeddingsAndEmptyKeysAreIgnored() {
        var memory = PersonalFoodMemory()
        memory.record(foodKey: "a", embedding: [], date: day)
        memory.record(foodKey: "a", embedding: [0, 0, 0], date: day)
        memory.record(foodKey: "a", embedding: [1, .nan, 0], date: day)
        memory.record(foodKey: "", embedding: [1, 0, 0], date: day)
        XCTAssertTrue(memory.isEmpty)
    }

    // MARK: Fusion

    func testWithoutNeighbourTheModelAnswerIsUnchanged() {
        var memory = PersonalFoodMemory()
        let model: [(key: String, probability: Double)] = [("a", 0.6), ("b", 0.4)]
        XCTAssertEqual(memory.fused(model: model, embedding: [1, 0, 0]).map(\.key), ["a", "b"], "mémoire vide")
        memory.record(foodKey: "c", embedding: [0, 1, 0], date: day)
        // Orthogonal (similarity 0) and a cosine of 0.6: both under 0.80.
        memory.record(foodKey: "d", embedding: [0.6, 0.8, 0], date: day)
        let result = memory.fused(model: model, embedding: [1, 0, 0])
        XCTAssertEqual(result.map(\.key), ["a", "b"])
        XCTAssertEqual(result.map(\.probability), [0.6, 0.4])
    }

    func testIdenticalNeighboursGiveTheMemoryItsFullWeight() {
        var memory = PersonalFoodMemory()
        memory.record(foodKey: "apple", embedding: [1, 0, 0], date: day)
        memory.record(foodKey: "pear", embedding: [1, 0, 0], date: day)
        let result = memory.fused(model: [("pear", 0.6), ("kiwi", 0.4)], embedding: [1, 0, 0])
        // α = 0.7; p_mem = 0.5 for apple and pear. pear = 0.3 × 0.6 + 0.7 × 0.5, kiwi = 0.3 × 0.4, apple = 0.7 × 0.5.
        XCTAssertEqual(result.map(\.key), ["pear", "apple", "kiwi"])
        XCTAssertEqual(probability(result, "pear") ?? 0, 0.53, accuracy: 1e-6)
        XCTAssertEqual(probability(result, "apple") ?? 0, 0.35, accuracy: 1e-6)
        XCTAssertEqual(probability(result, "kiwi") ?? 0, 0.12, accuracy: 1e-6)
    }

    func testTheWeightGrowsWithTheSimilarityOfTheBestNeighbour() {
        var memory = PersonalFoodMemory()
        // Cosine 0.9 with the query: α = 0.7 × (0.9 − 0.8) / 0.2 = 0.35, and a remembered food the model did not list appears.
        memory.record(foodKey: "b", embedding: [0.9, 0.43589, 0], date: day)
        let result = memory.fused(model: [("a", 1.0)], embedding: [1, 0, 0])
        XCTAssertEqual(probability(result, "b") ?? 0, 0.35, accuracy: 0.02)
        XCTAssertEqual(probability(result, "a") ?? 0, 0.65, accuracy: 0.02)
        XCTAssertEqual(result.first?.key, "a")
    }

    func testOnlyTheFiveNearestNeighboursCount() {
        var memory = PersonalFoodMemory()
        for _ in 0..<5 { memory.record(foodKey: "near", embedding: [1, 0, 0], date: day) }
        for _ in 0..<5 { memory.record(foodKey: "far", embedding: [0.9, 0.43589, 0], date: day) }
        let result = memory.fused(model: [("x", 1.0)], embedding: [1, 0, 0])
        XCTAssertNil(probability(result, "far"), "les cinq plus proches sont tous « near »")
        XCTAssertEqual(probability(result, "near") ?? 0, 0.7, accuracy: 1e-6)
    }

    func testAnEmbeddingOfAnotherSizeIsIgnoredAndNeverCrashes() {
        var memory = PersonalFoodMemory()
        memory.record(foodKey: "apple", embedding: [1, 0, 0], date: day)
        let model: [(key: String, probability: Double)] = [("a", 1.0)]
        XCTAssertEqual(memory.fused(model: model, embedding: [1, 0, 0, 0]).map(\.key), ["a"])
        XCTAssertEqual(memory.fused(model: model, embedding: []).map(\.key), ["a"])
        // A new model: the old entries can never be compared again, so they are dropped when a new one is recorded.
        memory.record(foodKey: "pear", embedding: [1, 0, 0, 0], date: day)
        XCTAssertEqual(memory.entries.map(\.foodKey), ["pear"])
    }

    // MARK: Saved data

    func testCodableRoundTripAndTolerantDecoding() throws {
        var memory = PersonalFoodMemory()
        memory.record(foodKey: "builtin.apple", embedding: [0.3, -0.5, 0.8], date: day)
        memory.record(foodKey: "builtin.rice", embedding: [-0.1, 0.2, 0.9], date: day.addingTimeInterval(60))
        let data = try JSONEncoder().encode(memory)
        let back = try JSONDecoder().decode(PersonalFoodMemory.self, from: data)
        XCTAssertEqual(back, memory)
        XCTAssertEqual(try JSONDecoder().decode(PersonalFoodMemory.self, from: Data("{}".utf8)).entries.count, 0)
        XCTAssertEqual(try JSONDecoder().decode(PersonalFoodMemory.self, from: Data(#"{"entries":"oops"}"#.utf8)).entries.count, 0)
    }

    func testStoreSavesLoadsAndClearsAFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ardane-memory-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(PersonalFoodMemoryStore.load(directory: directory).isEmpty)
        PersonalFoodMemoryStore.record([(foodKey: "apple", embedding: [1, 0, 0])], date: day, directory: directory)
        PersonalFoodMemoryStore.record([(foodKey: "pear", embedding: [0, 1, 0])], date: day, directory: directory)
        XCTAssertEqual(PersonalFoodMemoryStore.load(directory: directory).entries.map(\.foodKey), ["apple", "pear"])
        PersonalFoodMemoryStore.clear(directory: directory)
        XCTAssertTrue(PersonalFoodMemoryStore.load(directory: directory).isEmpty)
    }

    // MARK: Context

    func testContextCountsOnlyTheLastSixtyDays() {
        let now = day
        let entries: [(foodID: String, date: Date)] = [
            ("a", now.addingTimeInterval(-86_400)), ("a", now.addingTimeInterval(-59 * 86_400)),
            ("a", now.addingTimeInterval(-61 * 86_400)), ("b", now.addingTimeInterval(-3_600)),
        ]
        let priors = ScannerContextPriors(entries: entries, now: now)
        XCTAssertEqual(priors.counts, ["a": 2, "b": 1])
    }

    func testContextReweightsThenKeepsTheTotalAndAddsNothing() {
        let priors = ScannerContextPriors(counts: ["a": 3])
        let result = priors.reweighted([("a", 0.3), ("b", 0.3)])
        XCTAssertEqual(Set(result.map(\.key)), ["a", "b"], "aucun aliment ajouté")
        XCTAssertEqual(result.map(\.probability).reduce(0, +), 0.6, accuracy: 1e-12, "le total est conservé")
        // w(a) = 1 + 0.15 × ln 4 ≈ 1.2079; a' = 0.3 × 1.2079 / (0.3 × 1.2079 + 0.3) × 0.6 ≈ 0.3282.
        XCTAssertEqual(result.first?.key, "a")
        XCTAssertEqual(probability(result, "a") ?? 0, 0.3282, accuracy: 1e-3)
        XCTAssertEqual(probability(result, "b") ?? 0, 0.2718, accuracy: 1e-3)
    }

    func testContextWithoutHistoryOrWithoutLoggedCandidatesChangesNothing() {
        let candidates: [(key: String, probability: Double)] = [("a", 0.5), ("b", 0.2)]
        XCTAssertEqual(ScannerContextPriors().reweighted(candidates).map(\.probability), [0.5, 0.2])
        let elsewhere = ScannerContextPriors(counts: ["z": 10]).reweighted(candidates)
        XCTAssertEqual(elsewhere.map(\.key), ["a", "b"])
        XCTAssertEqual(elsewhere.map(\.probability), [0.5, 0.2])
    }

    // MARK: The analyzer

    func testModelReadingUsesTheMemoryAndGivesAlternatives() {
        func food(_ id: String) -> FoodItem {
            FoodItem(id: id, name: id, brand: nil, kcal: 150, protein: 8, carbs: 20, fat: 4, fiber: 1,
                     servingGrams: 100, servingName: "1", source: .builtin, barcode: nil)
        }
        let apple = food("builtin.apple"), pear = food("builtin.pear")
        let resolve: (String) -> FoodItem? = { id in [apple, pear].first { $0.id == id } }
        let zone = FoodModelZone(
            score: 0.9, box: CGRect(x: 0, y: 0, width: 10, height: 10), maskBounds: CGRect(x: 0, y: 0, width: 10, height: 10),
            cropRect: CGRect(x: 0, y: 0, width: 12, height: 12),
            classification: FoodModelClassification(
                foods: [FoodModelCandidate(key: "builtin.apple", probability: 0.5), FoodModelCandidate(key: "builtin.pear", probability: 0.3)],
                topLabel: "mfr:apple", topProbability: 0.5, embedding: [1, 0, 0]
            )
        )
        // Nothing remembered: the model's choice, and the pear as a replacement.
        let plain = OnDeviceMealAnalyzer.modelReading(from: [zone], learning: ScanLearning(), resolve: resolve)
        XCTAssertEqual(plain.proposals.map { $0.food.id }, ["builtin.apple"])
        XCTAssertEqual(plain.hints.first?.alternatives.map(\.id), ["builtin.pear"])
        XCTAssertEqual(plain.hints.first?.detectedFoodID, "builtin.apple")
        // The person always said « pear » for this look: it wins.
        var memory = PersonalFoodMemory()
        for _ in 0..<3 { memory.record(foodKey: "builtin.pear", embedding: [1, 0, 0], date: day) }
        let learned = OnDeviceMealAnalyzer.modelReading(from: [zone], learning: ScanLearning(), memory: memory, resolve: resolve)
        XCTAssertEqual(learned.proposals.map { $0.food.id }, ["builtin.pear"])
        XCTAssertEqual(learned.hints.first?.alternatives.map(\.id), ["builtin.apple"])
    }
}
