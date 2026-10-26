import XCTest
@testable import Ardane

/// The recap of a scan: add, remove, replace, quantities kept in range, totals, a food on two lines
/// merged, the journal written once (a double tap or the same barcode again adds nothing), and
/// estimates kept apart from verified values.
final class ScanRecapTests: XCTestCase {
    private func food(_ id: String, kcal: Double = 200, serving: Double = 100) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: kcal, protein: 10, carbs: 20, fat: 5, fiber: 1,
                 servingGrams: serving, servingName: "1", source: .custom, barcode: nil)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Editing

    func testAddUsesTheUsualPortionAndIsNotAnEstimate() {
        var recap = ScanRecap()
        recap.add(food("a", serving: 120))
        XCTAssertEqual(recap.lines.count, 1)
        XCTAssertEqual(recap.lines[0].grams, 120)
        XCTAssertFalse(recap.lines[0].isEstimate)
        XCTAssertNil(recap.lines[0].confidence)
    }

    func testRemoveAndReplace() {
        var recap = ScanRecap()
        let first = recap.add(food("a"))
        let second = recap.add(food("b"))
        recap.replace(first, with: food("c"))
        XCTAssertEqual(recap.lines.map(\.food.id), ["c", "b"])
        XCTAssertEqual(recap.lines[0].id, first, "La ligne remplacée garde sa place")
        recap.remove(second)
        XCTAssertEqual(recap.lines.map(\.food.id), ["c"])
        recap.remove(UUID())
        XCTAssertEqual(recap.lines.count, 1)
    }

    func testReplaceKeepsTheQuantityAndDropsTheOldConfidence() {
        var recap = ScanRecap()
        let id = recap.add(food("a"), grams: 250, isEstimate: true, confidence: 0.8)
        recap.replace(id, with: food("b"))
        XCTAssertEqual(recap.lines[0].grams, 250)
        XCTAssertTrue(recap.lines[0].isEstimate, "La quantité reste une estimation")
        XCTAssertNil(recap.lines[0].confidence, "La confiance concernait l'ancien aliment")
    }

    func testReplaceByAFoodAlreadyThereMergesTheLines() {
        var recap = ScanRecap()
        let first = recap.add(food("a"), grams: 100)
        recap.add(food("b"), grams: 50)
        recap.replace(first, with: food("b"))
        XCTAssertEqual(recap.lines.count, 1)
        XCTAssertEqual(recap.lines[0].grams, 150)
    }

    func testGramsStayBetweenOneAndFiveThousand() {
        var recap = ScanRecap()
        let id = recap.add(food("a"))
        recap.setGrams(id, 0)
        XCTAssertEqual(recap.lines[0].grams, 1)
        recap.setGrams(id, -40)
        XCTAssertEqual(recap.lines[0].grams, 1)
        recap.setGrams(id, 9_999)
        XCTAssertEqual(recap.lines[0].grams, 5_000)
        recap.setGrams(id, 275)
        XCTAssertEqual(recap.lines[0].grams, 275)
        recap.setGrams(id, .nan)
        XCTAssertEqual(recap.lines[0].grams, 275, "Une valeur qui n'est pas un nombre est ignorée")
        recap.setGrams(id, .infinity)
        XCTAssertEqual(recap.lines[0].grams, 275)
        recap.setGrams(UUID(), 10)
        XCTAssertEqual(recap.lines.count, 1)
    }

    func testAddingAHugeQuantityIsClamped() {
        var recap = ScanRecap()
        recap.add(food("a"), grams: 80_000)
        XCTAssertEqual(recap.lines[0].grams, 5_000)
    }

    // MARK: Totals

    func testTotalsFollowTheQuantities() {
        var recap = ScanRecap()
        let a = recap.add(food("a", kcal: 200), grams: 150)
        recap.add(food("b", kcal: 100), grams: 100)
        // 200 kcal/100 g × 150 g + 100 kcal/100 g × 100 g = 400.
        XCTAssertEqual(recap.totals.kcal, 400, accuracy: 0.001)
        XCTAssertEqual(recap.totals.protein, 10 * 1.5 + 10, accuracy: 0.001)
        recap.setGrams(a, 50)
        XCTAssertEqual(recap.totals.kcal, 200, accuracy: 0.001)
        XCTAssertEqual(ScanRecap().totals.kcal, 0)
    }

    func testCanConfirmNeedsALine() {
        var recap = ScanRecap()
        XCTAssertFalse(recap.canConfirm)
        XCTAssertTrue(recap.isEmpty)
        let id = recap.add(food("a"))
        XCTAssertTrue(recap.canConfirm)
        recap.remove(id)
        XCTAssertFalse(recap.canConfirm)
    }

    // MARK: Merge

    func testTheSameFoodTwiceIsOneLine() {
        var recap = ScanRecap()
        let id = recap.add(food("a"), grams: 100)
        let again = recap.add(food("a"), grams: 60)
        XCTAssertEqual(recap.lines.count, 1)
        XCTAssertEqual(again, id)
        XCTAssertEqual(recap.lines[0].grams, 160)
    }

    func testMergedKeepsTheFirstLineAndTheLowestConfidence() {
        let one = ScanLine(food: food("a"), grams: 100, isEstimate: false)
        let two = ScanLine(food: food("b"), grams: 30, isEstimate: true, confidence: 0.7)
        let three = ScanLine(food: food("a"), grams: 50, isEstimate: true, confidence: 0.4)
        let four = ScanLine(food: food("b"), grams: 20, isEstimate: true, confidence: 0.3)
        let merged = ScanRecap(lines: [one, two, three, four]).merged
        XCTAssertEqual(merged.lines.map(\.food.id), ["a", "b"])
        XCTAssertEqual(merged.lines[0].id, one.id)
        XCTAssertEqual(merged.lines[0].grams, 150)
        XCTAssertTrue(merged.lines[0].isEstimate, "Une ligne estimée rend la fusion estimée")
        XCTAssertEqual(merged.lines[0].confidence, 0.4)
        XCTAssertEqual(merged.lines[1].grams, 50)
        XCTAssertEqual(merged.lines[1].confidence, 0.3)
    }

    // MARK: Estimate and verified

    func testProposalsBecomeEstimatesAndAProductStaysVerified() {
        let proposal = MealProposal(food: food("pizza", serving: 110), grams: 110, confidence: 0.42)
        let photo = ScanRecap(proposals: [proposal])
        XCTAssertTrue(photo.lines[0].isEstimate)
        XCTAssertEqual(photo.lines[0].confidence, 0.42)
        XCTAssertEqual(photo.lines[0].grams, 110)
        XCTAssertTrue(photo.hasEstimate)
        XCTAssertTrue(photo.lines[0].isLowConfidence)
        XCTAssertEqual(photo.lines[0].confidenceWord, tr("peu sûr"))

        let product = ScanRecap(food: food("barcode"))
        XCTAssertFalse(product.lines[0].isEstimate)
        XCTAssertFalse(product.hasEstimate)
        XCTAssertNil(product.lines[0].confidenceWord)
    }

    func testEditingKeepsTheEstimateFlag() {
        var recap = ScanRecap(proposals: [MealProposal(food: food("a"), grams: 100, confidence: 0.9)])
        recap.add(food("v"), grams: 100)
        let estimated = recap.lines[0].id
        let verified = recap.lines[1].id
        recap.setGrams(estimated, 180)
        recap.setGrams(verified, 40)
        XCTAssertTrue(recap.lines[0].isEstimate)
        XCTAssertFalse(recap.lines[1].isEstimate)
        XCTAssertFalse(recap.lines[0].isLowConfidence, "0,9 n'est pas « peu sûr »")
        XCTAssertEqual(recap.lines[0].confidenceWord, tr("assez sûr"))
        recap.replace(verified, with: food("w"))
        XCTAssertFalse(recap.lines[1].isEstimate)
    }

    // MARK: Journal

    func testCommitWritesEveryLineOnceInTheJournal() {
        var recap = ScanRecap()
        recap.add(food("a"), grams: 150)
        recap.add(food("b"), grams: 80)
        var state = NutritionState()
        let logged = recap.commit(into: &state, meal: .lunch, at: now)
        XCTAssertEqual(logged, 2)
        XCTAssertEqual(state.entries.count, 2)
        XCTAssertEqual(Set(state.entries.map(\.food.id)), ["a", "b"])
        XCTAssertTrue(state.entries.allSatisfy { $0.meal == .lunch && $0.date == now })
        XCTAssertEqual(state.entries.first { $0.food.id == "a" }?.grams, 150)
        XCTAssertEqual(Set(state.recentFoods.map(\.id)), ["a", "b"])
    }

    func testASecondQuickCommitAddsNothing() {
        var recap = ScanRecap()
        recap.add(food("a"))
        var state = NutritionState()
        XCTAssertEqual(recap.commit(into: &state, meal: .lunch, at: now), 1)
        XCTAssertEqual(recap.commit(into: &state, meal: .lunch, at: now.addingTimeInterval(1)), 0, "Deuxième appui : rien de plus")
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(recap.commit(into: &state, meal: .lunch, at: now.addingTimeInterval(3)), 1, "Plus de deux secondes après : un nouvel ajout")
        XCTAssertEqual(state.entries.count, 2)
    }

    func testAnotherFoodIsNotADoubleTap() {
        var first = ScanRecap()
        first.add(food("a"))
        var second = ScanRecap()
        second.add(food("b"))
        var state = NutritionState()
        first.commit(into: &state, meal: .snack, at: now)
        XCTAssertEqual(second.commit(into: &state, meal: .snack, at: now.addingTimeInterval(0.5)), 1)
        XCTAssertEqual(state.entries.count, 2)
    }

    func testWithoutTheWindowTheSameFoodCanBeLoggedAgain() {
        var recap = ScanRecap()
        recap.add(food("a"))
        var state = NutritionState()
        recap.commit(into: &state, meal: .dinner, at: now, window: 0)
        recap.commit(into: &state, meal: .dinner, at: now, window: 0)
        XCTAssertEqual(state.entries.count, 2)
    }

    func testCommitMergesAFoodOnTwoLines() {
        let lines = [ScanLine(food: food("a"), grams: 100), ScanLine(food: food("a"), grams: 40)]
        var state = NutritionState()
        XCTAssertEqual(ScanRecap(lines: lines).commit(into: &state, meal: .breakfast, at: now), 1)
        XCTAssertEqual(state.entries.count, 1)
        XCTAssertEqual(state.entries[0].grams, 140)
    }

    func testCommitOfAnEmptyRecapAddsNothing() {
        var state = NutritionState()
        XCTAssertEqual(ScanRecap().commit(into: &state, meal: .lunch, at: now), 0)
        XCTAssertTrue(state.entries.isEmpty)
    }

    func testTheJournalTotalsFollowTheRecap() {
        var recap = ScanRecap()
        recap.add(food("a", kcal: 200), grams: 150)
        var state = NutritionState()
        recap.commit(into: &state, meal: .lunch, at: now)
        XCTAssertEqual(NutritionMath.totals(state, on: now).kcal, 300, accuracy: 0.001)
    }
}
