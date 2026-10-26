import XCTest
@testable import Ardane

/// Synonyms of the labels of the classifier, dishes cut into editable lines, several labels per photo,
/// no food found by the first letters of a word, cooked rather than raw. Realistic lists of labels, as
/// Vision gives them, on the real food table (`FoodDatabase`).
final class DishTemplatesTests: XCTestCase {
    private func score(_ label: String, _ confidence: Double) -> FoodLabelMatcher.LabelScore {
        FoodLabelMatcher.LabelScore(label: label, confidence: confidence)
    }

    private func named(_ id: String, _ name: String, serving: Double = 100) -> FoodItem {
        FoodItem(id: id, name: name, brand: nil, kcal: 150, protein: 8, carbs: 20, fat: 4, fiber: 1,
                 servingGrams: serving, servingName: "1", source: .builtin, barcode: nil)
    }

    // MARK: Realistic lists of labels

    func testPizzaWithAGenericFoodLabelGivesThePizza() {
        let proposals = FoodLabelMatcher.proposals(from: [score("pizza", 0.8), score("food", 0.9)])
        XCTAssertEqual(proposals.first?.food.id, "builtin.pizza")
        XCTAssertEqual(proposals.count, 1, "« food » ne nomme aucun aliment : \(proposals.map(\.food.id))")
        XCTAssertEqual(proposals.first?.dishName, DishTemplate.template(forLabel: "pizza")?.name)
        XCTAssertEqual(proposals.first?.isEstimate, true)
        XCTAssertEqual(proposals.first?.grams, 220)
    }

    func testSandwichBecomesEditableLines() {
        let proposals = FoodLabelMatcher.proposals(from: [score("sandwich", 0.6)])
        let ids = proposals.map(\.food.id)
        XCTAssertEqual(ids.first, "builtin.bread", "La base du plat d'abord : \(ids)")
        XCTAssertTrue(ids.contains("builtin.ham"))
        XCTAssertGreaterThanOrEqual(proposals.count, 4)
        XCTAssertEqual(Set(ids).count, ids.count, "Un aliment une seule fois")
        for proposal in proposals {
            XCTAssertTrue(proposal.isEstimate, "Jamais figé : \(proposal.food.id)")
            XCTAssertEqual(proposal.dishName, DishTemplate.template(forLabel: "sandwich")?.name)
            XCTAssertGreaterThan(proposal.grams, 0)
            XCTAssertLessThanOrEqual(proposal.confidence, 0.6)
        }
        let bread = proposals.first { $0.food.id == "builtin.bread" }
        XCTAssertEqual(bread?.grams, 60)
        XCTAssertEqual(bread?.isOptional, false)
        let mayo = proposals.first { $0.food.id == "builtin.mayo" }
        XCTAssertEqual(mayo?.isOptional, true)
        if let bread, let mayo { XCTAssertGreaterThan(bread.confidence, mayo.confidence, "Le facultatif est moins sûr") }
    }

    func testSaladWithAVegetableLabelGivesTheSalad() {
        let proposals = FoodLabelMatcher.proposals(from: [score("salad", 0.7), score("vegetable", 0.5)])
        XCTAssertEqual(proposals.first?.food.id, "builtin.gardensalad")
        XCTAssertFalse(proposals.contains { $0.label == "vegetable" }, "« vegetable » est trop vague")
        XCTAssertTrue(proposals.allSatisfy { $0.dishName != nil })
    }

    func testSeveralFoodsOfAPlateAreAllProposed() {
        let proposals = FoodLabelMatcher.proposals(from: [
            score("steak", 0.7), score("french_fries", 0.6), score("broccoli", 0.4), score("plate", 0.9), score("table", 0.8),
        ])
        let ids = proposals.map(\.food.id)
        XCTAssertEqual(ids, ["builtin.steak", "builtin.fries", "builtin.broccoli"])
    }

    func testLabelsOfTheSameFoodAreGroupedOnce() {
        let proposals = FoodLabelMatcher.proposals(from: [score("hamburger", 0.8), score("burger", 0.7), score("cheeseburger", 0.6)])
        let ids = proposals.map(\.food.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Les trois étiquettes désignent le même plat : \(ids)")
        XCTAssertEqual(proposals.first?.food.id, "builtin.beef")
        XCTAssertEqual(proposals.first?.confidence ?? 0, 0.8 * FoodLabelMatcher.templateFactor, accuracy: 0.0001)
    }

    func testADishWithNoFoodFoundProposesNothing() {
        // Nothing found in the tables for the components: the label falls back to its own words, then nothing.
        let proposals = FoodLabelMatcher.proposals(from: [score("tourtiere", 0.7)], search: { _ in [] })
        XCTAssertTrue(proposals.isEmpty, "Pas d'aliment inventé quand la table n'a rien")
    }

    // MARK: Synonyms

    func testSynonymsFindQuebecAndNorthAmericanFoods() {
        let expected: [String: String] = [
            "french_fries": "builtin.fries", "ice_cream": "builtin.icecream", "soda": "builtin.cola", "coffee": "builtin.coffee",
            "strawberry": "builtin.strawberries", "donut": "builtin.donut", "milk": "builtin.milk2", "pie": "builtin.applepie",
            "potato_chips": "builtin.chips", "fried_rice": "builtin.friedrice", "cheese": "builtin.cheddar",
        ]
        for (label, id) in expected {
            XCTAssertEqual(FoodLabelMatcher.proposals(from: [score(label, 0.7)]).first?.food.id, id, "« \(label) »")
        }
    }

    func testSynonymKeysAreCleanedAndPluralsAreRead() {
        XCTAssertEqual(FoodSynonyms.key(for: "Shepherd's_Pie"), "shepherds pie")
        XCTAssertEqual(FoodSynonyms.queries(forLabel: "Shepherd's_Pie"), ["pate chinois"])
        XCTAssertEqual(FoodSynonyms.queries(forLabel: "cucumbers"), FoodSynonyms.queries(forLabel: "cucumber"))
        XCTAssertFalse(FoodSynonyms.queries(forLabel: "cucumbers").isEmpty)
        XCTAssertTrue(FoodSynonyms.queries(forLabel: "xylophone").isEmpty)
        XCTAssertGreaterThan(FoodSynonyms.knownLabels.count, 200)
        for label in FoodSynonyms.knownLabels {
            XCTAssertEqual(FoodSynonyms.key(for: label), label, "Clé non nettoyée : \(label)")
            XCTAssertFalse(FoodSynonyms.queries(forLabel: label).isEmpty)
        }
    }

    // MARK: False positives by prefix

    func testAShortWordIsNotFoundInsideALongerOne() {
        let pied = named("pied", "Pied de porc")
        XCTAssertFalse(FoodLabelMatcher.accepts(pied, forQuery: "pie"))
        XCTAssertTrue(FoodLabelMatcher.accepts(named("eggs", "Eggs, boiled"), forQuery: "egg"), "Le pluriel est le même aliment")
        XCTAssertTrue(FoodLabelMatcher.accepts(named("pie", "Pie, apple"), forQuery: "pie"))
        XCTAssertTrue(FoodLabelMatcher.accepts(named("tarte", "Tarte aux pommes"), forQuery: "pie"), "Trouvé par un autre nom : gardé")
        XCTAssertFalse(FoodLabelMatcher.accepts(named("corned", "Corned beef"), forQuery: "corn"))
        // The stand-in search gives the wrong food first: it is dropped, the right one is taken.
        let proposals = FoodLabelMatcher.proposals(from: [score("pie", 0.8)], search: { _ in [pied, self.named("pie", "Pie, apple")] },
                                                    useDishKnowledge: false)
        XCTAssertEqual(proposals.map(\.food.id), ["pie"])
        let none = FoodLabelMatcher.proposals(from: [score("pie", 0.8)], search: { _ in [pied] }, useDishKnowledge: false)
        XCTAssertTrue(none.isEmpty, "« pie » ne doit pas donner « pied de porc »")
    }

    func testHamIsNotTakenForAnotherFood() {
        XCTAssertEqual(FoodLabelMatcher.proposals(from: [score("ham", 0.7)]).first?.food.id, "builtin.ham")
    }

    // MARK: Raw and cooked

    func testCookedIsProposedByDefaultAndRawKeptAsAlternative() {
        let raw = named("chicken.raw", "Poulet, poitrine, cru")
        let cooked = named("chicken.cooked", "Poulet, poitrine, rôti")
        let rawFirst = FoodLabelMatcher.proposals(from: [score("chicken", 0.8)], search: { _ in [raw, cooked] })
        XCTAssertEqual(rawFirst.first?.food.id, "chicken.cooked")
        XCTAssertEqual(rawFirst.first?.alternative?.id, "chicken.raw")
        let cookedFirst = FoodLabelMatcher.proposals(from: [score("chicken", 0.8)], search: { _ in [cooked, raw] })
        XCTAssertEqual(cookedFirst.first?.food.id, "chicken.cooked")
        XCTAssertEqual(cookedFirst.first?.alternative?.id, "chicken.raw")
    }

    func testTheCookedVersionIsSearchedWhenOnlyTheRawOneCameBack() {
        let raw = named("chicken.raw", "Poulet, poitrine, cru")
        let cooked = named("chicken.cooked", "Poulet, poitrine, rôti")
        let proposals = FoodLabelMatcher.proposals(from: [score("chicken", 0.8)], search: { $0.hasSuffix("cuit") ? [cooked] : [raw] })
        XCTAssertEqual(proposals.first?.food.id, "chicken.cooked")
        XCTAssertEqual(proposals.first?.alternative?.id, "chicken.raw")
    }

    func testAFoodWithoutACookingStateHasNoAlternative() {
        let proposals = FoodLabelMatcher.proposals(from: [score("bread", 0.8)])
        XCTAssertEqual(proposals.first?.food.id, "builtin.bread")
        XCTAssertNil(proposals.first?.alternative)
        XCTAssertEqual(FoodLabelMatcher.cookingState(of: named("a", "Carottes, crues")), .raw)
        XCTAssertEqual(FoodLabelMatcher.cookingState(of: named("b", "Carrots, boiled")), .cooked)
        XCTAssertNil(FoodLabelMatcher.cookingState(of: named("c", "Pain blanc")))
    }

    // MARK: Ten candidates

    func testUpToTenCandidatesAreKept() {
        let search: (String) -> [FoodItem] = { [self.named($0, $0)] }
        let labels = (1...12).map { score("thing\($0)", 0.3 + Double($0) / 40) }
        let proposals = FoodLabelMatcher.proposals(from: labels, search: search)
        XCTAssertEqual(proposals.count, 10)
        XCTAssertEqual(proposals.first?.food.id, "thing12")
    }

    // MARK: Tables

    func testEveryTemplateComponentIsFoundInTheBuiltInTable() {
        let missingOnPurpose: Set<String> = ["tourtiere"]
        var labels: Set<String> = []
        for template in DishTemplate.all {
            XCTAssertFalse(template.components.isEmpty, template.name)
            for label in template.labels {
                let key = FoodSynonyms.key(for: label)
                XCTAssertEqual(key, label, "Étiquette non nettoyée : \(label)")
                XCTAssertTrue(labels.insert(key).inserted, "Étiquette en double : \(key)")
            }
            for component in template.components where !missingOnPurpose.contains(component.foodQuery) {
                XCTAssertGreaterThan(component.grams, 0)
                let found = component.foodQuery.split(separator: "|").contains { !FoodDatabase.search(String($0)).isEmpty }
                XCTAssertTrue(found, "\(template.name) : « \(component.foodQuery) » introuvable")
            }
        }
    }

    // MARK: Measure (printed in the CI report)

    func testRecognitionMeasureOnTypicalLabels() {
        // The food or the dish proposed first for a label seen alone, and the one expected.
        let cases: [(String, String)] = [
            ("pizza", "builtin.pizza"), ("sandwich", "builtin.bread"), ("club_sandwich", "builtin.bread"),
            ("hamburger", "builtin.beef"), ("hot_dog", "builtin.bread"), ("french_fries", "builtin.fries"),
            ("spaghetti", "builtin.pasta"), ("pasta", "builtin.pasta"), ("lasagna", "builtin.lasagna"),
            ("caesar_salad", "builtin.caesar"), ("salad", "builtin.gardensalad"), ("rice", "builtin.rice"),
            ("fried_rice", "builtin.friedrice"), ("sushi", "builtin.sushi"), ("poutine", "builtin.poutine"),
            ("bacon_and_eggs", "builtin.egg"), ("pancake", "builtin.pancake"), ("soup", "builtin.soup"),
            ("shepherds_pie", "builtin.shepherd"), ("fish_and_chips", "builtin.cod"), ("chicken", "builtin.chicken"),
            ("steak", "builtin.steak"), ("salmon", "builtin.salmon"), ("egg", "builtin.egg"), ("bread", "builtin.bread"),
            ("banana", "builtin.banana"), ("apple", "builtin.apple"), ("strawberry", "builtin.strawberries"),
            ("coffee", "builtin.coffee"), ("ice_cream", "builtin.icecream"), ("pie", "builtin.applepie"),
            ("cheese", "builtin.cheddar"), ("yogurt", "builtin.yogurt"), ("milk", "builtin.milk2"),
            ("donut", "builtin.donut"), ("cookie", "builtin.cookie"), ("soda", "builtin.cola"), ("beer", "builtin.beer"),
            ("taco", "builtin.tacos"), ("bacon", "builtin.bacon"),
        ]
        var lines: [String] = []
        var correct = 0
        for (label, expected) in cases {
            let first = FoodLabelMatcher.proposals(from: [score(label, 0.7)]).first
            let ok = first?.food.id == expected
            if ok { correct += 1 }
            let dish = first?.dishName.map { " [\($0)]" } ?? ""
            lines.append("\(ok ? "OK " : "KO ") \(label) -> \(first?.food.name ?? "(rien)")\(dish)")
            XCTAssertEqual(first?.food.id, expected, "« \(label) »")
        }
        lines.append("\(correct) / \(cases.count) étiquettes avec l'aliment attendu en premier (table intégrée seule)")
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "RECO-ETIQUETTES"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
