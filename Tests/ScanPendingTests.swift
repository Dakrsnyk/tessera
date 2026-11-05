import XCTest
@testable import Ardane

/// The photo recap in two groups: a proposal that is sure enough (or from the person's habits) is a line, the others wait
/// « À confirmer » in `pending` and are never logged until the person confirms them; a « maybe » zone is never added alone.
final class ScanPendingTests: XCTestCase {
    private func food(_ id: String, serving: Double = 100) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: 200, protein: 10, carbs: 20, fat: 5, fiber: 1,
                 servingGrams: serving, servingName: "1", source: .custom, barcode: nil)
    }

    private func proposal(_ id: String, grams: Double = 100, confidence: Double, habit: Bool = false) -> MealProposal {
        MealProposal(food: food(id), grams: grams, confidence: confidence, label: "mfr:\(id)", detectedFoodID: id, usesHabit: habit)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testTheThresholdSplitsLinesFromPending() {
        let recap = ScanRecap(photoProposals: [
            proposal("sure", confidence: 0.80), proposal("almost", confidence: 0.79), proposal("weak", confidence: 0.55),
        ])
        XCTAssertEqual(recap.lines.map(\.food.id), ["sure"])
        XCTAssertEqual(recap.pending.map(\.food.id), ["almost", "weak"], "Du plus sûr au moins sûr")
        XCTAssertTrue(recap.pending.allSatisfy { !$0.isTentative })
        XCTAssertTrue(recap.isPhoto)
        XCTAssertEqual(ScanRecap.autoAddThreshold, 0.80)
    }

    func testHabitsAreKeptAsLinesWhateverTheConfidence() {
        let recap = ScanRecap(photoProposals: [proposal("habit", confidence: 0.3, habit: true), proposal("weak", confidence: 0.3)])
        XCTAssertEqual(recap.lines.map(\.food.id), ["habit"])
        XCTAssertEqual(recap.pending.map(\.food.id), ["weak"])
    }

    func testATentativeFoodIsNeverAddedAlone() {
        let recap = ScanRecap(
            photoProposals: [proposal("sure", confidence: 0.9)],
            tentative: [proposal("maybe", confidence: 0.95), proposal("maybe-habit", confidence: 0.9, habit: true)]
        )
        XCTAssertEqual(recap.lines.map(\.food.id), ["sure"])
        XCTAssertEqual(Set(recap.pending.map(\.food.id)), ["maybe", "maybe-habit"])
        XCTAssertTrue(recap.pending.allSatisfy { $0.isTentative })
    }

    func testATentativeFoodAlreadyProposedIsNotDuplicated() {
        let recap = ScanRecap(
            photoProposals: [proposal("sure", confidence: 0.9), proposal("weak", confidence: 0.5)],
            tentative: [proposal("sure", confidence: 0.4), proposal("weak", confidence: 0.4), proposal("maybe", confidence: 0.4),
                        proposal("maybe", confidence: 0.3)]
        )
        XCTAssertEqual(recap.lines.map(\.food.id), ["sure"])
        XCTAssertEqual(recap.pending.map(\.food.id), ["weak", "maybe"])
        XCTAssertEqual(recap.pending.map(\.isTentative), [false, true])
    }

    func testConfirmMakesAnEstimateLineLikeAnAddedProposal() throws {
        var recap = ScanRecap(photoProposals: [proposal("weak", grams: 140, confidence: 0.6)])
        XCTAssertTrue(recap.lines.isEmpty)
        let item = try XCTUnwrap(recap.pending.first)
        let lineID = try XCTUnwrap(recap.confirm(item.id))
        XCTAssertTrue(recap.pending.isEmpty)
        let line = try XCTUnwrap(recap.lines.first { $0.id == lineID })
        XCTAssertEqual(line.food.id, "weak")
        XCTAssertEqual(line.grams, 140)
        XCTAssertTrue(line.isEstimate)
        XCTAssertEqual(line.confidence, 0.6)
        XCTAssertEqual(line.detectedFoodID, "weak")
        XCTAssertEqual(line.initialGrams, 140)
        XCTAssertTrue(recap.canConfirm)
    }

    func testConfirmWithAnAlternativeUsesItsUsualPortionAndKeepsTheDetectedFood() throws {
        var recap = ScanRecap(photoProposals: [proposal("weak", grams: 140, confidence: 0.6)])
        let item = try XCTUnwrap(recap.pending.first)
        recap.confirm(item.id, with: food("other", serving: 75))
        let line = try XCTUnwrap(recap.lines.first)
        XCTAssertEqual(line.food.id, "other")
        XCTAssertEqual(line.grams, 75)
        XCTAssertTrue(line.quantityIsUsual)
        XCTAssertEqual(line.detectedFoodID, "weak", "La correction s'apprend à la validation")
        XCTAssertEqual(line.initialGrams, 140)
        XCTAssertNil(line.confidence)
        XCTAssertTrue(recap.pending.isEmpty)
    }

    func testConfirmOfAnUnknownItemChangesNothing() {
        var recap = ScanRecap(photoProposals: [proposal("weak", confidence: 0.6)])
        XCTAssertNil(recap.confirm(UUID()))
        XCTAssertEqual(recap.pending.count, 1)
        XCTAssertTrue(recap.lines.isEmpty)
    }

    func testDismissOnlyRemovesTheItem() throws {
        var recap = ScanRecap(photoProposals: [proposal("sure", confidence: 0.9), proposal("weak", confidence: 0.6)])
        let item = try XCTUnwrap(recap.pending.first)
        recap.dismiss(item.id)
        XCTAssertTrue(recap.pending.isEmpty)
        XCTAssertEqual(recap.lines.map(\.food.id), ["sure"])
    }

    func testCommitNeverLogsWhatIsStillPending() {
        let recap = ScanRecap(photoProposals: [proposal("sure", confidence: 0.9), proposal("weak", confidence: 0.6)],
                              tentative: [proposal("maybe", confidence: 0.5)])
        var state = NutritionState()
        XCTAssertEqual(recap.commit(into: &state, meal: .lunch, at: now), 1)
        XCTAssertEqual(state.entries.map(\.food.id), ["sure"])
        XCTAssertEqual(state.scanLearning.corrections.count, 1)
        XCTAssertEqual(recap.merged.pending.count, 2, "La fusion garde les éléments à confirmer")
    }

    func testOnlyPendingMeansNothingToLogYet() {
        let recap = ScanRecap(photoProposals: [proposal("weak", confidence: 0.6)])
        XCTAssertFalse(recap.canConfirm)
        XCTAssertTrue(recap.isEmpty)
    }

    func testTheBarcodeRecapHasNoPending() {
        let recap = ScanRecap(food: food("code"))
        XCTAssertTrue(recap.pending.isEmpty)
        XCTAssertEqual(recap.lines.count, 1)
    }

    // MARK: Zones of the models

    private func zone(_ score: Double, _ foods: [(String, Double)]) -> FoodModelZone {
        FoodModelZone(
            score: score, box: CGRect(x: 0, y: 0, width: 10, height: 10), maskBounds: CGRect(x: 0, y: 0, width: 10, height: 10),
            cropRect: CGRect(x: 0, y: 0, width: 12, height: 12),
            classification: FoodModelClassification(
                foods: foods.map { FoodModelCandidate(key: $0.0, probability: $0.1) }, topLabel: "mfr:x",
                topProbability: foods.first?.1 ?? 0
            )
        )
    }

    func testMaybeZonesAreSeparatedAndNotRepeatedFromSureZones() {
        let apple = food("builtin.apple"), rice = food("builtin.rice"), egg = food("builtin.egg")
        let resolve: (String) -> FoodItem? = { id in [apple, rice, egg].first { $0.id == id } }
        let zones = [
            zone(0.9, [("builtin.rice", 0.7)]),
            zone(0.25, [("builtin.rice", 0.9)]),
            zone(0.22, [("builtin.apple", 0.6), ("builtin.egg", 0.2)]),
        ]
        XCTAssertFalse(zones[0].isTentative)
        XCTAssertTrue(zones[1].isTentative)
        let reading = OnDeviceMealAnalyzer.modelReading(from: zones, learning: ScanLearning(), resolve: resolve)
        XCTAssertEqual(reading.proposals.map(\.food.id), ["builtin.rice"])
        XCTAssertEqual(reading.tentative.map(\.food.id), ["builtin.apple"], "Le riz est déjà proposé par une zone sûre")
        XCTAssertEqual(reading.hints.count, 3, "Les zones « peut-être » ont aussi leurs alternatives")
        XCTAssertEqual(reading.hints[2].alternatives.map(\.id), ["builtin.egg"])

        let analysis = MealAnalysis(proposals: reading.proposals, tentative: reading.tentative, zoneHints: reading.hints)
        let recap = analysis.recap
        XCTAssertEqual(recap.lines.count, 0, "0,70 < 0,80 : le riz attend aussi")
        XCTAssertEqual(recap.pending.map(\.food.id), ["builtin.rice", "builtin.apple"])
    }
}
