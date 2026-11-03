import XCTest
@testable import Ardane

/// Masse d'un aliment (Shared/Domains/Scanner/ScannerMass.swift) : la table de densités fabriquée par
/// scripts/build_food_densities.py à partir du Fichier canadien (App/Resources/food-densities.json), la densité de
/// repli d'une famille avec un écart large, la masse = volume × densité, et le facteur personnel appris des
/// corrections. Les valeurs attendues sont calculées à la main : spaghetti cuit 74 g pour 125 ml = 0,592 g/ml, riz
/// blanc vapeur 69,7 g pour 125 ml = 0,558, mesclun 30,7 g pour 125 ml = 0,246.
final class ScannerMassTests: XCTestCase {
    private func food(_ id: String, kcal: Double = 130) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: kcal, protein: 2.7, carbs: 28, fat: 0.3, fiber: 0.4,
                 servingGrams: 150, servingName: "1", source: .nutrientFile, barcode: nil)
    }

    /// La table telle que le script l'a écrite : lue dans les sources du dépôt (comme les autres tests qui lisent
    /// un fichier du dépôt), sinon dans l'application.
    private func sourceTable() throws -> FoodDensityTable {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/food-densities.json")
        if let data = try? Data(contentsOf: url), let table = FoodDensityTable.decode(data) { return table }
        if !FoodDensityTable.bundled.isEmpty { return FoodDensityTable.bundled }
        throw XCTSkip("App/Resources/food-densities.json is not readable from here")
    }

    // MARK: Densités du script

    func testDensitiesOfKnownFoodsAreTheGramsOfTheMeasureOver125Millilitres() throws {
        let table = try sourceTable()
        let known: [(id: String, grams: Double, name: String)] = [
            ("cnf.4469", 74.0, "spaghetti cuit"),
            ("cnf.501898", 69.7, "riz blanc vapeur"),
            ("cnf.501839", 30.7, "mesclun"),
            ("cnf.4523", 83.5, "riz blanc à long grain cuit"),
        ]
        for item in known {
            let found = try XCTUnwrap(table.lookup(for: food(item.id), isSolidPiece: false), item.name)
            XCTAssertEqual(found.estimate.median, item.grams / 125, accuracy: 0.0006, item.name)
            XCTAssertEqual(found.estimate.sigmaLog, FoodDensityTable.measuredSigmaLog, item.name)
            XCTAssertEqual(found.estimate.sources, [.measuredDensity], item.name)
            XCTAssertFalse(found.estimate.isPrior, item.name)
            XCTAssertEqual(found.provenance, .measured(foodID: item.id, measure: "125ml", measureGrams: item.grams), item.name)
        }
        XCTAssertEqual(try XCTUnwrap(table.lookup(for: food("cnf.4469"), isSolidPiece: false)).estimate.median, 0.592, accuracy: 0.0006)
        XCTAssertEqual(try XCTUnwrap(table.lookup(for: food("cnf.501898"), isSolidPiece: false)).estimate.median, 0.558, accuracy: 0.0006)
        XCTAssertEqual(try XCTUnwrap(table.lookup(for: food("cnf.501839"), isSolidPiece: false)).estimate.median, 0.246, accuracy: 0.0006)
    }

    func testTheContentsOfAContainerIsATrueDensity() throws {
        // Soupe en conserve : 301,4 g pour une boîte de 284 ml = 1,061 g/ml, écart plus serré.
        let found = try XCTUnwrap(try sourceTable().lookup(for: food("cnf.923"), isSolidPiece: false))
        XCTAssertEqual(found.estimate.median, 301.4 / 284, accuracy: 0.0006)
        XCTAssertEqual(found.estimate.sigmaLog, FoodDensityTable.containerSigmaLog)
        if case let .measured(_, measure, grams) = found.provenance {
            XCTAssertEqual(measure, "1 can (284 ml)")
            XCTAssertEqual(grams, 301.4, accuracy: 1e-9)
        } else {
            XCTFail("la provenance doit être la mesure du fichier")
        }
    }

    func testEveryDensityOfTheTableMatchesItsMeasure() throws {
        let table = try sourceTable()
        XCTAssertGreaterThan(table.measures.count, 2_500)
        XCTAssertNotNil(table.measures[4469])
        var checked = 0
        for (id, measured) in table.measures {
            XCTAssertTrue(FoodDensityTable.densityRange.contains(measured.gPerMl), "cnf.\(id) : \(measured.gPerMl) g/ml hors du filtre")
            XCTAssertGreaterThan(measured.measureGrams, 0, "cnf.\(id)")
            if measured.kind == .plain, measured.measure.hasSuffix("ml"), let millilitres = Double(measured.measure.dropLast(2)) {
                XCTAssertEqual(measured.gPerMl, measured.measureGrams / millilitres, accuracy: 0.0006, "cnf.\(id) \(measured.measure)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 1_500)
    }

    func testEveryFamilyOfFoodsHasAPriorFromManyMeasuredFoods() throws {
        let table = try sourceTable()
        for family in FoodCategory.allCases {
            let prior = try XCTUnwrap(table.families[family.rawValue], family.rawValue)
            XCTAssertGreaterThanOrEqual(prior.sampleCount, 50, family.rawValue)
            XCTAssertTrue(FoodDensityTable.densityRange.contains(prior.gPerMl), family.rawValue)
            XCTAssertLessThanOrEqual(prior.p25, prior.gPerMl, family.rawValue)
            XCTAssertGreaterThanOrEqual(prior.p75, prior.gPerMl, family.rawValue)
        }
        let overall = try XCTUnwrap(table.overall)
        XCTAssertGreaterThan(overall.sampleCount, 2_000)
        XCTAssertFalse(table.familyOfOtherFoods.isEmpty)
    }

    // MARK: Repli : la famille, avec un écart large

    func testAFoodWithoutMeasureGetsTheDensityOfItsFamilyWithAWideSigma() throws {
        let table = try sourceTable()
        // Un aliment du fichier canadien classé dans une famille mais sans mesure en ml.
        let other = try XCTUnwrap(table.familyOfOtherFoods.first { table.measures[$0.key] == nil && table.families[$0.value] != nil })
        let found = try XCTUnwrap(table.lookup(for: food("cnf.\(other.key)"), isSolidPiece: false))
        let prior = try XCTUnwrap(table.families[other.value])
        XCTAssertEqual(found.estimate.median, prior.gPerMl, accuracy: 1e-12)
        XCTAssertGreaterThanOrEqual(found.estimate.sigmaLog, FoodDensityTable.familySigmaFloor, "écart large : jamais une valeur précise")
        XCTAssertEqual(found.estimate.sources, [.categoryDensity])
        XCTAssertTrue(found.estimate.isPrior)
        XCTAssertEqual(found.provenance, .family(name: other.value, sampleCount: prior.sampleCount))
    }

    func testBuiltInAndExplicitFamiliesAndTheWholeFileAsLastResort() throws {
        let table = try sourceTable()
        let starches = try XCTUnwrap(table.families["starches"])
        let vegetables = try XCTUnwrap(table.families["vegetables"])
        let overall = try XCTUnwrap(table.overall)

        let rice = try XCTUnwrap(FoodDatabase.item("builtin.rice"))
        let fromBuiltIn = try XCTUnwrap(table.lookup(for: rice, isSolidPiece: false))
        XCTAssertEqual(fromBuiltIn.provenance, DensityProvenance.family(name: "starches", sampleCount: starches.sampleCount))

        let explicit = try XCTUnwrap(table.lookup(for: food("custom.1"), family: .vegetables, isSolidPiece: false))
        XCTAssertEqual(explicit.estimate.median, vegetables.gPerMl, accuracy: 1e-12)

        let unknown = try XCTUnwrap(table.lookup(for: food("custom.2"), isSolidPiece: false))
        XCTAssertEqual(unknown.provenance, DensityProvenance.overall(sampleCount: overall.sampleCount))
        XCTAssertGreaterThanOrEqual(unknown.estimate.sigmaLog, FoodDensityTable.familySigmaFloor)
        XCTAssertTrue(unknown.estimate.isPrior)
    }

    func testFamilySigmaIsNeverUnderTheFloor() throws {
        let narrow = FamilyDensityPrior(family: "starches", sampleCount: 100, gPerMl: 0.5, p25: 0.49, p75: 0.51, spreadLog: 0.05)
        let wide = FamilyDensityPrior(family: "starches", sampleCount: 100, gPerMl: 0.5, p25: 0.2, p75: 0.8, spreadLog: 0.66)
        let rice = try XCTUnwrap(FoodDatabase.item("builtin.rice"))
        let narrowSigma = try XCTUnwrap(FoodDensityTable(families: ["starches": narrow]).lookup(for: rice, isSolidPiece: false)).estimate.sigmaLog
        let wideSigma = try XCTUnwrap(FoodDensityTable(families: ["starches": wide]).lookup(for: rice, isSolidPiece: false)).estimate.sigmaLog
        XCTAssertEqual(narrowSigma, 0.30, accuracy: 1e-12)
        XCTAssertEqual(wideSigma, 0.66, accuracy: 1e-12)
    }

    func testWithoutATableThereIsNoDensityAndNoMass() throws {
        XCTAssertNil(FoodDensityTable.empty.lookup(for: food("cnf.4469"), isSolidPiece: false), "jamais une valeur inventée")
        XCTAssertTrue(FoodDensityTable.empty.isEmpty)
        let volume = try XCTUnwrap(ScanEstimate(median: 200, sigmaLog: 0.3, sources: [.heightMap]))
        XCTAssertNil(DensityMassEstimator(table: .empty).estimateMass(volume: volume, food: food("cnf.4469"), family: nil, isSolidPiece: false))
    }

    func testASolidPieceGetsNoCupDensity() throws {
        // Les mesures en ml de la table sont des tasses d'aliment en vrac ou en morceaux : trop basses pour un steak
        // ou un fruit entier. Pour une pièce pleine, seul le contenu d'un contenant (densité vraie) est proposé.
        let table = try sourceTable()
        XCTAssertNil(table.lookup(for: food("cnf.4469"), isSolidPiece: true))
        let rice = try XCTUnwrap(FoodDatabase.item("builtin.rice"))
        XCTAssertNil(table.lookup(for: rice, isSolidPiece: true), "pas de densité de famille non plus")
        XCTAssertNotNil(table.lookup(for: food("cnf.923"), isSolidPiece: true))
        XCTAssertNotNil(table.lookup(for: food("cnf.4469"), isSolidPiece: false))
    }

    // MARK: Tas ou pièce pleine : l'appelant décide

    /// Une table à la main (pas de dépendance au contenu du fichier) : un poulet en dés et un riz en tasse, des
    /// pommes en tranches, une soupe en conserve, et les familles aux valeurs du fichier canadien (protéines
    /// 0,57 g/ml, féculents 0,467, fruits 1,023).
    private func handTable() -> FoodDensityTable {
        func family(_ name: String, _ gPerMl: Double, _ spreadLog: Double) -> FamilyDensityPrior {
            FamilyDensityPrior(family: name, sampleCount: 200, gPerMl: gPerMl, p25: gPerMl, p75: gPerMl, spreadLog: spreadLog)
        }
        return FoodDensityTable(
            measures: [
                1: MeasuredDensity(gPerMl: 0.566, measure: "250ml diced", measureGrams: 141.5, kind: .pieces),
                2: MeasuredDensity(gPerMl: 0.558, measure: "125ml", measureGrams: 69.7, kind: .plain),
                3: MeasuredDensity(gPerMl: 0.72, measure: "250ml sliced", measureGrams: 180, kind: .pieces),
                4: MeasuredDensity(gPerMl: 301.4 / 284, measure: "1 can (284 ml)", measureGrams: 301.4, kind: .container),
            ],
            families: ["proteins": family("proteins", 0.57, 0.228), "starches": family("starches", 0.467, 0.657),
                       "fruits": family("fruits", 1.023, 0.318)]
        )
    }

    func testASteakIsNeverGivenTheDensityOfACupOfMeat() throws {
        // Un steak n'a pas de mesure en ml : sans garde-fou il hériterait de la famille des protéines (0,57 g/ml,
        // des tasses de morceaux) au lieu d'environ 1,05 g/ml, et sa masse serait sous-estimée d'environ 45 %.
        let table = handTable()
        let steak = food("custom.steak")
        XCTAssertNil(table.lookup(for: steak, family: .proteins, isSolidPiece: true), "pièce pleine : pas de densité de tasse")
        let volume = try XCTUnwrap(ScanEstimate(median: 200, sigmaLog: 0.3, sources: [.plateReference, .typicalThickness]))
        let estimator = DensityMassEstimator(table: table)
        XCTAssertNil(estimator.estimateMass(volume: volume, food: steak, family: .proteins, isSolidPiece: true),
                     "pas de masse : la quantité vient de la portion usuelle")
        // Un filet qui a une mesure en tasse (viande hachée, en dés) : même refus pour une pièce pleine.
        XCTAssertNil(table.lookup(for: food("cnf.1"), family: .proteins, isSolidPiece: true))
        XCTAssertNil(estimator.estimateMass(volume: volume, food: food("cnf.1"), family: .proteins, isSolidPiece: true))
    }

    func testAHeapGetsTheLooseDensityOfItsFamilyOrOfItsOwnMeasure() throws {
        let table = handTable()
        let estimator = DensityMassEstimator(table: table)
        let volume = try XCTUnwrap(ScanEstimate(median: 200, sigmaLog: 0.3, sources: [.plateReference, .typicalThickness]))

        // Un tas de riz sans mesure propre : le prior de la famille (des tasses, de l'air compris), écart large.
        let heap = try XCTUnwrap(table.lookup(for: food("custom.rice"), family: .starches, isSolidPiece: false))
        XCTAssertEqual(heap.estimate.median, 0.467, accuracy: 1e-12)
        XCTAssertEqual(heap.estimate.sigmaLog, 0.657, accuracy: 1e-12)
        XCTAssertEqual(heap.provenance, .family(name: "starches", sampleCount: 200))
        XCTAssertTrue(heap.estimate.isPrior)
        let mass = try XCTUnwrap(estimator.estimateMass(volume: volume, food: food("custom.rice"), family: .starches, isSolidPiece: false))
        XCTAssertEqual(mass.median, 200 * 0.467, accuracy: 1e-9)

        // De la viande en dés ou hachée (tas) : la tasse de la table, 0,566 g/ml, c'est bien ce qu'elle décrit.
        let diced = try XCTUnwrap(table.lookup(for: food("cnf.1"), family: .proteins, isSolidPiece: false))
        XCTAssertEqual(diced.estimate.median, 0.566, accuracy: 1e-12)
        XCTAssertEqual(diced.estimate.sources, [.measuredDensity])
        // Un riz avec sa mesure propre (« 125ml ») : cette mesure, pas la famille.
        let cup = try XCTUnwrap(table.lookup(for: food("cnf.2"), family: .starches, isSolidPiece: false))
        XCTAssertEqual(cup.estimate.median, 0.558, accuracy: 1e-12)
    }

    func testWholeFruitAndCutFruitAreNotTheSameThing() throws {
        // Des pommes en tranches (une tasse de morceaux, 0,72 g/ml) sont un tas ; une pomme entière est une pièce
        // pleine : la tasse de tranches ne la décrit pas, ni le prior des fruits (des conserves, 1,023 g/ml).
        let table = handTable()
        let apple = food("cnf.3")
        let sliced = try XCTUnwrap(table.lookup(for: apple, family: .fruits, isSolidPiece: false))
        XCTAssertEqual(sliced.estimate.median, 0.72, accuracy: 1e-12)
        XCTAssertNil(table.lookup(for: apple, family: .fruits, isSolidPiece: true), "pomme entière : pas la tasse de tranches")
        XCTAssertNil(table.lookup(for: food("custom.fruit"), family: .fruits, isSolidPiece: true), "ni le prior de la famille")
        XCTAssertNotNil(table.lookup(for: food("custom.fruit"), family: .fruits, isSolidPiece: false), "des fruits coupés en tas : le prior")
    }

    func testOnlyTheContentsOfAContainerDescribesASolidPiece() throws {
        let table = handTable()
        // Une soupe en conserve : densité vraie, valable pour un tas comme pour une pièce, écart plus serré.
        let heap = try XCTUnwrap(table.lookup(for: food("cnf.4"), isSolidPiece: false))
        let solid = try XCTUnwrap(table.lookup(for: food("cnf.4"), isSolidPiece: true))
        XCTAssertEqual(heap, solid)
        XCTAssertEqual(solid.estimate.sigmaLog, FoodDensityTable.containerSigmaLog)
        XCTAssertTrue(DensityMeasureKind.container.isTrueDensity)
        XCTAssertFalse(DensityMeasureKind.plain.isTrueDensity, "« plain » n'est pas « plein » : une tasse de viande cuite fait 0,57 g/ml")
        XCTAssertFalse(DensityMeasureKind.pieces.isTrueDensity)
    }

    func testOnTheRealTableASolidPieceGetsADensityOnlyFromAContainer() throws {
        let table = try sourceTable()
        for (id, measured) in table.measures {
            let found = table.lookup(for: food("cnf.\(id)"), isSolidPiece: true)
            XCTAssertEqual(found != nil, measured.kind == .container, "cnf.\(id) \(measured.measure)")
        }
        // Aucun aliment sans mesure propre n'a de densité de pièce pleine : ni famille, ni moyenne du fichier.
        for family in FoodCategory.allCases {
            XCTAssertNil(table.lookup(for: food("custom.none"), family: family, isSolidPiece: true), family.rawValue)
        }
        XCTAssertNil(table.lookup(for: food("custom.none"), isSolidPiece: true))
        // Le même aliment, en tas : un prior de famille, jamais rien.
        XCTAssertNotNil(table.lookup(for: food("custom.none"), family: .proteins, isSolidPiece: false))
    }

    func testDecodingSkipsWhatIsNotAsExpected() throws {
        let json = """
        {"foods":[[1,0.5,"125ml",62.5,"plain"],[2,18.36,"125ml",2295,"plain"],[3,0.02,"250ml",5,"plain"],
                  ["x",0.5,"125ml",1],[4,0.9,"125ml",112.5],[5,0.6,5,3],[6,1.0,"15ml",15,"zzz"]],
         "categories":{"starches":{"n":10,"gPerMl":0.5,"p25":0.4,"p75":0.6,"spreadLog":0.1},"broken":{"n":"x"}},
         "overall":{"n":50,"gPerMl":0.7},
         "familyOfOtherFoods":{"proteins":[10,11,"z"]}}
        """
        let table = try XCTUnwrap(FoodDensityTable.decode(Data(json.utf8)))
        XCTAssertEqual(Set(table.measures.keys), [1, 4, 6], "18,36 et 0,02 g/ml sont rejetés, les lignes mal formées sautées")
        XCTAssertEqual(table.measures[4]?.kind, .plain, "une colonne manquante : le cas simple")
        XCTAssertEqual(table.measures[6]?.kind, .plain, "un genre inconnu : le cas simple")
        XCTAssertEqual(Set(table.families.keys), ["starches"])
        XCTAssertEqual(try XCTUnwrap(table.overall).spreadLog, 0, "sans écart donné : 0 (le plancher de 0,30 s'applique ensuite)")
        XCTAssertEqual(table.familyOfOtherFoods, [10: "proteins", 11: "proteins"])

        XCTAssertNil(FoodDensityTable.decode(Data("pas du JSON".utf8)))
        XCTAssertTrue(try XCTUnwrap(FoodDensityTable.decode(Data("{}".utf8))).isEmpty)
        XCTAssertEqual(FoodDensityTable.cnfIdentifier(of: "cnf.4464"), 4464)
        XCTAssertNil(FoodDensityTable.cnfIdentifier(of: "builtin.rice"))
        XCTAssertNil(FoodDensityTable.cnfIdentifier(of: "cnf.abc"))
    }

    func testBundledTableIsTheFileWhenTheAppIsThere() throws {
        try XCTSkipIf(FoodDensityTable.bundled.isEmpty, "le test ne tourne pas dans l'application : pas de fichier embarqué")
        XCTAssertEqual(FoodDensityTable.bundled.measures.count, try sourceTable().measures.count)
    }

    // MARK: Masse = volume × densité

    func testMassOfADiscOfRiceIsTheVolumeTimesTheDensity() throws {
        // 226,19 ml de riz blanc vapeur à 0,558 g/ml = 126,2 g ; σ² = 0,3² + 0,2² = 0,13 → 0,3606.
        let volume = try XCTUnwrap(ScanEstimate(median: Double.pi * 36 * 2, sigmaLog: 0.3, sources: [.heightMap]))
        let estimator = DensityMassEstimator(table: try sourceTable())
        let mass = try XCTUnwrap(estimator.estimateMass(volume: volume, food: food("cnf.501898"), family: nil, isSolidPiece: false))
        XCTAssertEqual(mass.median, 126.2, accuracy: 0.1)
        XCTAssertEqual(mass.sigmaLog, 0.13.squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(mass.sources, [.heightMap, .measuredDensity])
        XCTAssertFalse(mass.isPrior)

        let viaProtocol: FoodMassEstimating = estimator
        XCTAssertEqual(try XCTUnwrap(viaProtocol.estimateMass(volume: volume, food: food("cnf.501898"), family: nil, isSolidPiece: false)).median, mass.median, accuracy: 1e-12)
    }

    func testMassWithAFamilyDensityIsAPriorAndWider() throws {
        let table = try sourceTable()
        let volume = try XCTUnwrap(ScanEstimate(median: 200, sigmaLog: 0.3, sources: [.plateReference, .typicalThickness]))
        let rice = try XCTUnwrap(FoodDatabase.item("builtin.rice"))
        let mass = try XCTUnwrap(DensityMassEstimator(table: table).estimateMass(volume: volume, food: rice, family: nil, isSolidPiece: false))
        XCTAssertGreaterThan(mass.sigmaLog, (0.3 * 0.3 + 0.3 * 0.3).squareRoot() - 1e-12)
        XCTAssertTrue(mass.isPrior)
        XCTAssertTrue(mass.sources.contains(.categoryDensity))
    }

    // MARK: Facteur personnel

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Des corrections de `foodID` : le scanner proposait `base` g et la personne a gardé `base × ratio`.
    private func learned(_ ratios: [Double], foodID: String = "cnf.1", base: Double = 100, into learning: ScanLearning = ScanLearning()) -> ScanLearning {
        var result = learning
        for (index, ratio) in ratios.enumerated() {
            result.record(
                ScanCorrection(date: start.addingTimeInterval(Double(index) * 60), labels: ["rice"], detectedFoodID: foodID,
                               initialGrams: base, validatedFoodID: foodID, validatedGrams: base * ratio, quarantined: false),
                plausibleGramsRange: 1...2_000
            )
        }
        return result
    }

    func testNoCorrectionMeansNoFactor() throws {
        let none = PersonalQuantityFactor.learn(from: ScanLearning(), foodID: "cnf.1")
        XCTAssertEqual(none.factor, 1)
        XCTAssertEqual(none.scope, .unlearned)
        XCTAssertEqual(none.sampleCount, 0)
        let estimate = try XCTUnwrap(ScanEstimate(median: 100, sigmaLog: 0.3, sources: [.heightMap]))
        XCTAssertEqual(none.applying(to: estimate), estimate, "pas de facteur : l'estimation est rendue telle quelle")
        XCTAssertEqual(PersonalQuantityFactor.learn(from: learned([1.5]), foodID: "cnf.1").scope, .unlearned, "une correction ne décide jamais")
    }

    func testFactorShrinksTowardOneWithFewCorrections() {
        // n corrections toutes à ×1,5 : poids n / (n + 3), facteur = 1,5 ^ poids.
        let three = PersonalQuantityFactor.learn(from: learned([1.5, 1.5, 1.5]), foodID: "cnf.1")
        XCTAssertEqual(three.factor, 1.5.squareRoot(), accuracy: 1e-9, "3 corrections : la moitié de la correction")
        XCTAssertEqual(three.scope, .food)
        XCTAssertEqual(three.sampleCount, 3)

        let nine = PersonalQuantityFactor.learn(from: learned([Double](repeating: 1.5, count: 9)), foodID: "cnf.1")
        XCTAssertEqual(nine.factor, pow(1.5, 0.75), accuracy: 1e-9, "9 corrections : les trois quarts")
        XCTAssertGreaterThan(nine.factor, three.factor)

        let smaller = PersonalQuantityFactor.learn(from: learned([0.5, 0.5, 0.5]), foodID: "cnf.1")
        XCTAssertEqual(smaller.factor, 0.5.squareRoot(), accuracy: 1e-9, "il corrige aussi vers le bas")
    }

    func testFactorUsesTheMedianOfTheRatios() {
        // Ratios 1,2 / 1,5 / 3 : la médiane est 1,5, pas la moyenne ; 3 corrections → ×1,5^0,5.
        let factor = PersonalQuantityFactor.learn(from: learned([1.2, 3.0, 1.5]), foodID: "cnf.1")
        XCTAssertEqual(factor.factor, 1.5.squareRoot(), accuracy: 1e-9)
    }

    func testAberrantCorrectionsAreIgnored() {
        // Une quantité 12 fois plus grande que la proposition (hors du facteur 10), une quantité hors des
        // quantités plausibles (mise en quarantaine par ScanLearning) : ni l'une ni l'autre ne compte.
        var learning = learned([1.5, 1.5, 1.5])
        learning = learned([12], into: learning)
        learning.record(
            ScanCorrection(date: start.addingTimeInterval(9_000), labels: ["rice"], detectedFoodID: "cnf.1", initialGrams: 100,
                           validatedFoodID: "cnf.1", validatedGrams: 5_000, quarantined: false),
            plausibleGramsRange: 1...2_000
        )
        XCTAssertEqual(learning.corrections.filter { $0.quarantined }.count, 1)
        XCTAssertEqual(PersonalQuantityFactor.ratios(of: learning.corrections).count, 3)
        let factor = PersonalQuantityFactor.learn(from: learning, foodID: "cnf.1")
        XCTAssertEqual(factor.factor, 1.5.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(factor.sampleCount, 3)

        // Une proposition sans quantité de départ ne donne pas de rapport.
        var noInitial = ScanLearning()
        for index in 0..<4 {
            noInitial.record(
                ScanCorrection(date: start.addingTimeInterval(Double(index)), labels: ["rice"], detectedFoodID: nil, initialGrams: nil,
                               validatedFoodID: "cnf.1", validatedGrams: 150, quarantined: false),
                plausibleGramsRange: 1...2_000
            )
        }
        XCTAssertTrue(PersonalQuantityFactor.ratios(of: noInitial.corrections).isEmpty)
    }

    func testGlobalFactorNeedsFiveCorrectionsAndTheFoodOwnFactorWins() {
        var learning = ScanLearning()
        for index in 0..<4 { learning = learned([2.0], foodID: "cnf.\(10 + index)", into: learning) }
        XCTAssertEqual(PersonalQuantityFactor.learn(from: learning, foodID: "cnf.99").scope, .unlearned, "4 corrections : pas encore")
        learning = learned([2.0], foodID: "cnf.14", into: learning)
        let global = PersonalQuantityFactor.learn(from: learning, foodID: "cnf.99")
        XCTAssertEqual(global.scope, .global)
        XCTAssertEqual(global.sampleCount, 5)
        XCTAssertEqual(global.factor, pow(2.0, 5.0 / 8.0), accuracy: 1e-9, "poids 5 / 8")

        learning = learned([1.5, 1.5, 1.5], foodID: "cnf.1", into: learning)
        let own = PersonalQuantityFactor.learn(from: learning, foodID: "cnf.1")
        XCTAssertEqual(own.scope, .food)
        XCTAssertEqual(own.factor, 1.5.squareRoot(), accuracy: 1e-9)
    }

    func testFactorIsKeptBetweenHalfAndDouble() {
        let huge = PersonalQuantityFactor.learn(from: learned([Double](repeating: 9, count: 40), base: 100), foodID: "cnf.1")
        XCTAssertEqual(huge.factor, 2.0, accuracy: 1e-12)
        let tiny = PersonalQuantityFactor.learn(from: learned([Double](repeating: 0.12, count: 40), base: 1_000), foodID: "cnf.1")
        XCTAssertEqual(tiny.factor, 0.5, accuracy: 1e-12)
    }

    func testFactorMultipliesTheMedianAndLeavesTheSpread() throws {
        let factor = PersonalQuantityFactor.learn(from: learned([1.5, 1.5, 1.5]), foodID: "cnf.1")
        let estimate = try XCTUnwrap(ScanEstimate(median: 100, sigmaLog: 0.3, sources: [.heightMap, .measuredDensity]))
        let corrected = factor.applying(to: estimate)
        XCTAssertEqual(corrected.median, 100 * 1.5.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(corrected.sigmaLog, 0.3, accuracy: 1e-12, "quelques corrections ne rendent pas le prochain repas plus sûr")
        XCTAssertTrue(corrected.sources.contains(.personalFactor))

        let table = try sourceTable()
        let volume = try XCTUnwrap(ScanEstimate(median: 200, sigmaLog: 0.3, sources: [.heightMap]))
        let plain = try XCTUnwrap(DensityMassEstimator(table: table).estimateMass(volume: volume, food: food("cnf.501898"), family: nil, isSolidPiece: false))
        let personal = try XCTUnwrap(DensityMassEstimator(table: table, personalFactor: factor).estimateMass(volume: volume, food: food("cnf.501898"), family: nil, isSolidPiece: false))
        XCTAssertEqual(personal.median / plain.median, 1.5.squareRoot(), accuracy: 1e-9)
    }
}
