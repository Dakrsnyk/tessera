import XCTest
@testable import Tessera

/// Labels of a photo (what an image classifier sees) turned into foods of the tables: the real food
/// table for common words, a stand-in search for the exact rules (threshold, limit, duplicates).
final class FoodLabelMatcherTests: XCTestCase {
    private func score(_ label: String, _ confidence: Double) -> FoodLabelMatcher.LabelScore {
        FoodLabelMatcher.LabelScore(label: label, confidence: confidence)
    }

    private func food(_ id: String, serving: Double = 100) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: 150, protein: 8, carbs: 20, fat: 4, fiber: 1,
                 servingGrams: serving, servingName: "1", source: .builtin, barcode: nil)
    }

    // MARK: With the real food table

    func testCommonDishesFindAFoodOfTheTable() {
        for label in ["pizza", "salad", "banana", "rice"] {
            let proposals = FoodLabelMatcher.proposals(from: [score(label, 0.8)])
            XCTAssertFalse(proposals.isEmpty, "« \(label) » devrait trouver un aliment de la base")
            for proposal in proposals {
                XCTAssertNotNil(FoodDatabase.item(proposal.food.id), "Pas de donnée inventée : l'aliment vient de la base")
            }
        }
    }

    func testProposalsAreEstimatesInTheUsualPortion() {
        let proposals = FoodLabelMatcher.proposals(from: [score("pizza", 0.7), score("salad", 0.5)])
        XCTAssertFalse(proposals.isEmpty)
        for proposal in proposals {
            XCTAssertTrue(proposal.isEstimate)
            XCTAssertEqual(proposal.grams, proposal.food.servingGrams)
            XCTAssertGreaterThan(proposal.grams, 0)
            XCTAssertGreaterThanOrEqual(proposal.confidence, FoodLabelMatcher.minimumConfidence)
            XCTAssertLessThanOrEqual(proposal.confidence, 1)
        }
    }

    func testTheValuesForTheEstimatedQuantityComeFromTheFood() {
        guard let proposal = FoodLabelMatcher.proposals(from: [score("pizza", 0.9)]).first else {
            return XCTFail("« pizza » devrait trouver un aliment")
        }
        let expected = proposal.food.kcal * proposal.grams / 100
        XCTAssertEqual(proposal.totals.kcal, expected, accuracy: 0.001)
    }

    func testLabelsOfThingsAroundTheFoodAreIgnored() {
        let labels = ["plate", "table", "person", "bowl", "fork", "kitchen", "tableware", "cup", "pan", "bar", "fruit", "food"]
        let proposals = FoodLabelMatcher.proposals(from: labels.map { score($0, 0.95) })
        XCTAssertTrue(proposals.isEmpty, "Rien ne doit être proposé : \(proposals.map(\.food.id))")
    }

    // MARK: Cleaning

    func testLabelCleaningAndIgnoredWords() {
        XCTAssertEqual(FoodLabelMatcher.cleaned("Hot_Dog"), "hot dog")
        XCTAssertEqual(FoodLabelMatcher.cleaned("ice-cream"), "ice cream")
        XCTAssertTrue(FoodLabelMatcher.isIgnored("plate"))
        XCTAssertTrue(FoodLabelMatcher.isIgnored("dining_table"))
        XCTAssertTrue(FoodLabelMatcher.isIgnored(""))
        XCTAssertTrue(FoodLabelMatcher.isIgnored("it"), "Un mot trop court ne cherche rien")
        XCTAssertFalse(FoodLabelMatcher.isIgnored("pizza"))
        XCTAssertEqual(FoodLabelMatcher.usefulWords(of: "rice_bowl"), ["rice"])
    }

    // MARK: Rules, with a stand-in search

    func testUnderTheThresholdNothingIsProposed() {
        let search: (String) -> [FoodItem] = { [self.food($0)] }
        XCTAssertTrue(FoodLabelMatcher.proposals(from: [score("pizza", 0.05)], search: search).isEmpty)
        XCTAssertEqual(FoodLabelMatcher.proposals(from: [score("pizza", 0.5)], search: search).count, 1)
        XCTAssertTrue(FoodLabelMatcher.proposals(from: [score("pizza", 0.5)], minimumConfidence: 0.6, search: search).isEmpty)
        XCTAssertTrue(FoodLabelMatcher.proposals(from: [score("pizza", .nan)], search: search).isEmpty)
    }

    func testAFoodIsProposedOnceWithItsBestConfidence() {
        let search: (String) -> [FoodItem] = { _ in [self.food("same")] }
        let proposals = FoodLabelMatcher.proposals(from: [score("margherita", 0.3), score("pizza", 0.8), score("flatbread", 0.4)], search: search)
        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].confidence, 0.8, accuracy: 0.0001)
    }

    func testAtMostFiveProposalsTheMostConfidentFirst() {
        let search: (String) -> [FoodItem] = { [self.food($0)] }
        let labels = (1...9).map { score("item\($0)", 0.2 + Double($0) / 20) }
        let proposals = FoodLabelMatcher.proposals(from: labels, search: search)
        XCTAssertEqual(proposals.count, FoodLabelMatcher.maximumProposals)
        XCTAssertEqual(proposals.map(\.food.id), ["item9", "item8", "item7", "item6", "item5"])
        XCTAssertEqual(proposals.map(\.confidence), proposals.map(\.confidence).sorted(by: >))
        XCTAssertEqual(FoodLabelMatcher.proposals(from: labels, limit: 2, search: search).count, 2)
        XCTAssertTrue(FoodLabelMatcher.proposals(from: labels, limit: 0, search: search).isEmpty)
    }

    func testThePortionIsTheUsualServingOrOneHundredGrams() {
        let foods = ["small": food("small", serving: 45), "none": food("none", serving: 0)]
        let search: (String) -> [FoodItem] = { query in foods[query].map { [$0] } ?? [] }
        let proposals = FoodLabelMatcher.proposals(from: [score("small", 0.9), score("none", 0.8)], search: search)
        XCTAssertEqual(proposals.first { $0.food.id == "small" }?.grams, 45)
        XCTAssertEqual(proposals.first { $0.food.id == "none" }?.grams, 100)
        XCTAssertTrue(proposals.allSatisfy(\.isEstimate))
    }

    func testALongLabelFallsBackToItsLastWordWithLessConfidence() {
        var asked: [String] = []
        let search: (String) -> [FoodItem] = { query in
            asked.append(query)
            return query == "rice" ? [self.food("rice")] : []
        }
        let proposals = FoodLabelMatcher.proposals(from: [score("fried_rice", 0.8)], search: search)
        XCTAssertEqual(asked, ["fried rice", "rice"])
        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].confidence, 0.8 * FoodLabelMatcher.partialMatchFactor, accuracy: 0.0001)
    }

    func testAnUnknownLabelProposesNothing() {
        let search: (String) -> [FoodItem] = { _ in [] }
        XCTAssertTrue(FoodLabelMatcher.proposals(from: [score("xylophone", 0.9)], search: search).isEmpty)
        XCTAssertTrue(FoodLabelMatcher.proposals(from: [], search: search).isEmpty)
    }
}
