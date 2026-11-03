import XCTest
@testable import Ardane

/// Confiance et incertitude du scanner (Shared/Domains/Scanner/ScannerEstimate.swift et ScannerConfidence.swift) :
/// loi log-normale (σ² = somme des variances des logarithmes, intervalle à 90 % = m × e^(±1,645 σ)), calories et
/// macros avec intervalle par la formule `FoodItem.nutrients(grams:)`, incertitude de reconnaissance, valeur
/// inconnue jamais ramenée à 0, recalage conforme sur repas pesés (vide par défaut). Valeurs attendues calculées
/// à la main : e^(−1,6449 × 0,3) = 0,6104 et e^(+1,6449 × 0,3) = 1,6382.
final class ScannerConfidenceTests: XCTestCase {
    private func food(_ id: String = "cnf.1", kcal: Double = 130, protein: Double = 2.7, carbs: Double = 28, fat: Double = 0.3,
                      unknown: Set<MacroField>? = nil) -> FoodItem {
        FoodItem(id: id, name: id, brand: nil, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: 0.4,
                 servingGrams: 150, servingName: "1", source: .nutrientFile, barcode: nil, unknownMacros: unknown)
    }

    private func estimate(_ median: Double, _ sigma: Double, _ sources: [EstimateSource] = []) throws -> ScanEstimate {
        try XCTUnwrap(ScanEstimate(median: median, sigmaLog: sigma, sources: sources))
    }

    // MARK: Loi log-normale

    func testIntervalAt90PercentIsTheMedianTimesExponentialOfPlusOrMinus1645Sigma() throws {
        let e = try estimate(150, 0.3)
        let interval = e.interval90
        XCTAssertEqual(interval.low, 91.58, accuracy: 0.01)
        XCTAssertEqual(interval.central, 150, accuracy: 1e-12)
        XCTAssertEqual(interval.high, 245.70, accuracy: 0.01)
        XCTAssertEqual(interval.mean, 156.90, accuracy: 0.01, "moyenne = médiane × e^(σ²/2)")
        XCTAssertEqual(e.mu, log(150), accuracy: 1e-12)
        XCTAssertEqual(interval.low * interval.high, 150 * 150, accuracy: 1e-6, "l'intervalle est symétrique dans le logarithme")
        XCTAssertEqual(ScanLogNormal.z90, 1.6448536, accuracy: 1e-6)

        let wider = e.interval(coverageFactor: 1.5)
        XCTAssertEqual(wider.low, 71.55, accuracy: 0.01)
        XCTAssertEqual(wider.high, 314.45, accuracy: 0.01)
        for bad in [0.0, -1.0, Double.nan, Double.infinity] {
            XCTAssertEqual(e.interval(coverageFactor: bad).high, interval.high, accuracy: 1e-9, "un facteur absurde est ignoré")
        }
    }

    func testVariancesOfTheLogarithmsAddUp() throws {
        // Aire (0,2) × épaisseur (0,3) × densité (0,4) : σ² = 0,04 + 0,09 + 0,16 = 0,29.
        XCTAssertEqual(ScanLogNormal.combined([0.2, 0.3, 0.4]), 0.29.squareRoot(), accuracy: 1e-12)
        let area = try estimate(100, 0.2, [.plateReference])
        let thickness = try estimate(2, 0.3, [.typicalThickness])
        let density = try estimate(0.5, 0.4, [.measuredDensity])
        let mass = try XCTUnwrap(area.multiplied(by: thickness)?.multiplied(by: density))
        XCTAssertEqual(mass.median, 100, accuracy: 1e-9, "100 × 2 × 0,5")
        XCTAssertEqual(mass.sigmaLog, 0.29.squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(mass.sources, [.plateReference, .typicalThickness, .measuredDensity])
        XCTAssertEqual(mass.route, .plateReference)
        XCTAssertTrue(mass.isPrior)

        XCTAssertEqual(ScanLogNormal.sigma(relativeError: 0.10), 0.0997513, accuracy: 1e-6)
        XCTAssertEqual(ScanLogNormal.sigma(relativeError: 0), 0)
        XCTAssertEqual(ScanLogNormal.sigma(relativeError: -0.3), 0)
        XCTAssertEqual(ScanLogNormal.sigma(relativeError: Double.nan), 0)
        XCTAssertEqual(ScanLogNormal.normalCDF(0), 0.5, accuracy: 1e-12)
        XCTAssertEqual(ScanLogNormal.normalCDF(ScanLogNormal.z90), 0.95, accuracy: 1e-9)
    }

    func testAnUnknownQuantityIsNeverAnEstimateOfZero() throws {
        XCTAssertNil(ScanEstimate(median: 0, sigmaLog: 0.2, sources: []))
        XCTAssertNil(ScanEstimate(median: -5, sigmaLog: 0.2, sources: []))
        XCTAssertNil(ScanEstimate(median: Double.nan, sigmaLog: 0.2, sources: []))
        XCTAssertNil(ScanEstimate(median: Double.infinity, sigmaLog: 0.2, sources: []))
        XCTAssertNil(ScanEstimate(median: 10, sigmaLog: -0.1, sources: []))
        XCTAssertNil(ScanEstimate(median: 10, sigmaLog: Double.nan, sources: []))
        let e = try estimate(100, 0.2, [.heightMap, .heightMap])
        XCTAssertEqual(e.sources, [.heightMap], "les sources sont sans doublon")
        XCTAssertNil(e.scaled(by: 0))
        XCTAssertNil(e.scaled(by: -2))
        XCTAssertNil(e.widened(by: 0))
        XCTAssertNil(e.adding(sigmaLog: -1))
        XCTAssertEqual(try XCTUnwrap(e.adding(sigmaLog: 0.15)).sigmaLog, 0.25, accuracy: 1e-12, "0,2² + 0,15² = 0,25²")
        XCTAssertFalse(e.isPrior)
        XCTAssertTrue(try estimate(100, 0.2, [.usualPortion]).isPrior)
    }

    // MARK: Calories et macros

    func testKcalAndMacrosOfOneFoodUseTheDeterministicFormulaOnTheBoundsOfTheMass() throws {
        let rice = food()
        let grams = try estimate(150, 0.3, [.plateReference])
        let result = try XCTUnwrap(MixtureNutritionResolver().resolve(candidates: [FoodCandidate(food: rice, probability: 0.9)], grams: grams))
        // 130 kcal pour 100 g × 150 g = 195 kcal ; bornes × 0,6104 et × 1,6382.
        XCTAssertEqual(result.kcal.central, rice.nutrients(grams: 150).kcal, accuracy: 1e-9, "même formule que le reste de l'app")
        XCTAssertEqual(result.kcal.central, 195, accuracy: 1e-9)
        XCTAssertEqual(result.kcal.low, 119.05, accuracy: 0.01)
        XCTAssertEqual(result.kcal.high, 319.40, accuracy: 0.01)
        XCTAssertEqual(result.kcal.mean, 203.98, accuracy: 0.01)
        let protein = try XCTUnwrap(result.protein)
        XCTAssertEqual(protein.central, 4.05, accuracy: 1e-9)
        XCTAssertEqual(protein.low, 2.47, accuracy: 0.01)
        XCTAssertEqual(protein.high, 6.63, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(result.carbs).central, 42, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(result.fat).central, 0.45, accuracy: 1e-9)
        XCTAssertFalse(result.isIncomplete)
        XCTAssertEqual(result.topProbability, 0.9, accuracy: 1e-12)
        XCTAssertEqual(result.coveredProbability, 0.9, accuracy: 1e-12, "10 % de chances que ce soit autre chose")
        XCTAssertEqual(result.grams, grams)
    }

    func testAMacroTheSourceDoesNotGiveStaysUnknownNeverZero() throws {
        let partial = food(unknown: [.protein])
        let grams = try estimate(150, 0.3)
        let result = try XCTUnwrap(MixtureNutritionResolver().resolve(candidates: [FoodCandidate(food: partial, probability: 1)], grams: grams))
        XCTAssertNil(result.protein, "inconnu n'est pas 0")
        XCTAssertNotNil(result.carbs)
        XCTAssertNotNil(result.fat)
        XCTAssertTrue(result.isIncomplete)
        XCTAssertGreaterThan(result.kcal.central, 0)

        // Un candidat moins probable qui ne donne pas la valeur suffit à la laisser inconnue.
        let mixed = try XCTUnwrap(MixtureNutritionResolver().resolve(
            candidates: [FoodCandidate(food: food(), probability: 0.8), FoodCandidate(food: partial, probability: 0.2)], grams: grams
        ))
        XCTAssertNil(mixed.protein)
        XCTAssertTrue(mixed.isIncomplete)
    }

    func testAFoodWithNoCaloriesIsAKnownZero() throws {
        let water = food(kcal: 0, protein: 0, carbs: 0, fat: 0)
        let grams = try estimate(250, 0.2)
        let result = try XCTUnwrap(MixtureNutritionResolver().resolve(candidates: [FoodCandidate(food: water, probability: 1)], grams: grams))
        XCTAssertEqual(result.kcal.low, 0)
        XCTAssertEqual(result.kcal.central, 0)
        XCTAssertEqual(result.kcal.high, 0)
        XCTAssertNotNil(result.protein, "0 g pour 100 g est une valeur connue")
    }

    func testNoPossibleFoodGivesNothing() throws {
        let grams = try estimate(150, 0.3)
        let resolver = MixtureNutritionResolver()
        XCTAssertNil(resolver.resolve(candidates: [], grams: grams))
        XCTAssertNil(resolver.resolve(candidates: [FoodCandidate(food: food(), probability: 0)], grams: grams))
        XCTAssertNil(resolver.resolve(candidates: [FoodCandidate(food: food(), probability: Double.nan)], grams: grams))
        XCTAssertNil(resolver.resolve(candidates: [FoodCandidate(food: food(), probability: -0.5)], grams: grams))
    }

    func testTwoCandidatesWithTheSameValuesGiveTheSameIntervalAsOne() throws {
        let grams = try estimate(150, 0.3)
        let one = try XCTUnwrap(MixtureNutritionResolver().resolve(candidates: [FoodCandidate(food: food("a"), probability: 1)], grams: grams))
        let two = try XCTUnwrap(MixtureNutritionResolver().resolve(
            candidates: [FoodCandidate(food: food("a"), probability: 0.5), FoodCandidate(food: food("b"), probability: 0.5)], grams: grams
        ))
        XCTAssertEqual(two.kcal.low, one.kcal.low, accuracy: one.kcal.low * 1e-6)
        XCTAssertEqual(two.kcal.central, one.kcal.central, accuracy: one.kcal.central * 1e-6)
        XCTAssertEqual(two.kcal.high, one.kcal.high, accuracy: one.kcal.high * 1e-6)
    }

    func testAnUncertainRecognitionWidensTheInterval() throws {
        // A : 100 kcal pour 100 g (60 %), B : 400 kcal pour 100 g (40 %), 100 g presque exacts (σ = 0,01).
        // La médiane reste sur A (60 % > 50 %), mais la borne haute monte jusqu'à B : 100 × 4 = 400 kcal.
        let grams = try estimate(100, 0.01)
        let a = FoodCandidate(food: food("a", kcal: 100), probability: 0.6)
        let b = FoodCandidate(food: food("b", kcal: 400), probability: 0.4)
        let result = try XCTUnwrap(MixtureNutritionResolver().resolve(candidates: [a, b], grams: grams))
        XCTAssertEqual(result.kcal.low, 98.6, accuracy: 1.0)
        XCTAssertEqual(result.kcal.central, 101.0, accuracy: 1.5)
        XCTAssertEqual(result.kcal.high, 404.6, accuracy: 4.0)
        XCTAssertEqual(result.kcal.mean, 0.6 * 100 + 0.4 * 400, accuracy: 1.0, "moyenne = Σ p × valeur = 220 kcal")
        XCTAssertEqual(result.coveredProbability, 1, accuracy: 1e-12)

        let onlyA = try XCTUnwrap(MixtureNutritionResolver().resolve(candidates: [a], grams: grams))
        XCTAssertLessThan(onlyA.kcal.high, 105)
        XCTAssertGreaterThan(result.kcal.high, 3 * onlyA.kcal.high)

        let cut = try XCTUnwrap(MixtureNutritionResolver(maximumCandidates: 1).resolve(candidates: [b, a], grams: grams))
        XCTAssertLessThan(cut.kcal.high, 105, "un seul candidat retenu : le plus probable")
        XCTAssertEqual(cut.topProbability, 0.6, accuracy: 1e-12)
    }

    // MARK: Chaîne complète

    func testFromPlateToCaloriesTheUncertaintyAddsUpInTheLogarithm() throws {
        // Disque de riz de 12 cm × 2 cm : aire π × 36, épaisseur 2 cm, densité 0,558 g/ml.
        // σ² = 0,19² + 0,4² + 0,2² = 0,2361 → σ = 0,4859 ; masse 126,2 g ; 130 kcal / 100 g → 164,1 kcal.
        let area = try estimate(Double.pi * 36, 0.19, [.plateReference])
        let volume = try XCTUnwrap(ThicknessVolume.volume(area: area, thickness: ThicknessPrior(medianCm: 2.0, sigmaLog: 0.4, status: .toMeasure)))
        let density = try estimate(0.558, 0.2, [.measuredDensity])
        let mass = try XCTUnwrap(ScanMass.mass(volume: volume, density: density))
        XCTAssertEqual(mass.median, 126.2, accuracy: 0.1)
        XCTAssertEqual(mass.sigmaLog, 0.4859, accuracy: 0.0005)

        let result = try XCTUnwrap(MixtureNutritionResolver().resolve(candidates: [FoodCandidate(food: food(), probability: 1)], grams: mass))
        XCTAssertEqual(result.kcal.central, 164.1, accuracy: 0.1)
        XCTAssertEqual(result.kcal.low, 73.8, accuracy: 0.1)
        XCTAssertEqual(result.kcal.high, 364.9, accuracy: 0.2)
        XCTAssertTrue(mass.isPrior, "tant que l'épaisseur est un a priori, tout le résultat en est un")
    }

    // MARK: Recalage conforme

    func testCalibrationIsEmptyByDefaultAndChangesNothing() throws {
        let table = ScanCalibrationTable()
        XCTAssertTrue(table.scores.isEmpty)
        for route in EstimateSource.routes { XCTAssertEqual(table.coverageFactor(for: route), 1) }
        XCTAssertEqual(table.coverageFactor(for: nil), 1)
        let e = try estimate(100, 0.3, [.plateReference])
        XCTAssertEqual(table.calibrated(e), e)
        XCTAssertEqual(table.count(for: .plateReference), 0)
    }

    func testCalibrationNeedsTwentyWeighedMeals() {
        var table = ScanCalibrationTable()
        for _ in 0..<19 { table.record(score: 5, route: .plateReference) }
        XCTAssertEqual(table.coverageFactor(for: .plateReference), 1, "19 repas pesés : pas encore")
        table.record(score: 5, route: .plateReference)
        XCTAssertNotEqual(table.coverageFactor(for: .plateReference), 1)
        XCTAssertEqual(table.coverageFactor(for: .heightMap), 1, "une autre voie n'est pas touchée")
    }

    func testCoverageFactorIsTheScoreOfRankNinetyPercentOverZ() {
        // Scores 0,1 ; 0,2 ; … ; 2,0 (n = 20) : rang ⌈21 × 0,9⌉ = 19, donc 1,9, et 1,9 / 1,6449 = 1,1551.
        var table = ScanCalibrationTable()
        for step in 1...20 { table.record(score: Double(step) / 10, route: .plateReference) }
        XCTAssertEqual(table.coverageFactor(for: .plateReference), 1.9 / ScanLogNormal.z90, accuracy: 1e-9)
        XCTAssertEqual(table.coverageFactor(for: .plateReference), 1.1551, accuracy: 0.0001)

        // Des scores d'un modèle trop sûr (tous à 10) ou trop prudent (tous à 0) sont bornés.
        var overconfident = ScanCalibrationTable()
        var cautious = ScanCalibrationTable()
        for _ in 0..<25 {
            overconfident.record(score: 10, route: .heightMap)
            cautious.record(score: 0, route: .heightMap)
        }
        XCTAssertEqual(overconfident.coverageFactor(for: .heightMap), 4.0)
        XCTAssertEqual(cautious.coverageFactor(for: .heightMap), 0.5)
    }

    func testRecordingAWeighedMealMakesTheScoreOfItsError() throws {
        // Estimation 100 g (σ 0,2) ; pesée 150 g : ln(1,5) / 0,2 = 2,0273.
        var table = ScanCalibrationTable()
        let e = try estimate(100, 0.2, [.plateReference, .typicalThickness])
        table.record(estimate: e, trueValue: 150)
        XCTAssertEqual(try XCTUnwrap(table.scores["plateReference"]).first ?? 0, 2.0273, accuracy: 0.0001)
        table.record(estimate: e, trueValue: 100 / 1.5)
        XCTAssertEqual(try XCTUnwrap(table.scores["plateReference"]).last ?? 0, 2.0273, accuracy: 0.0001, "trop haut ou trop bas : même score")

        let before = table.count(for: .plateReference)
        table.record(estimate: e, trueValue: 0)
        table.record(estimate: e, trueValue: -3)
        table.record(estimate: e, trueValue: Double.nan)
        table.record(estimate: try estimate(100, 0, [.plateReference]), trueValue: 120)
        table.record(estimate: try estimate(100, 0.2, [.typicalThickness]), trueValue: 120)
        XCTAssertEqual(table.count(for: .plateReference), before, "rien n'est enregistré pour une pesée absurde, un σ nul ou une estimation sans voie")
    }

    func testOnlyTheMostRecentScoresAreKept() {
        var table = ScanCalibrationTable()
        for index in 0..<250 { table.record(score: Double(index), route: .referenceObject) }
        let kept = table.scores["referenceObject"] ?? []
        XCTAssertEqual(kept.count, ScanCalibrationTable.maximumScores)
        XCTAssertEqual(kept.first, 50)
        XCTAssertEqual(kept.last, 249)
    }

    func testCalibratedEstimateWidensItsIntervalByTheFactor() throws {
        var table = ScanCalibrationTable()
        for _ in 0..<20 { table.record(score: 2.0, route: .plateReference) }
        let e = try estimate(100, 0.22, [.plateReference])
        let calibrated = table.calibrated(e)
        // facteur = 2,0 / 1,6449 : l'intervalle devient médiane × e^(±2,0 × σ).
        XCTAssertEqual(calibrated.sigmaLog, 0.22 * 2.0 / ScanLogNormal.z90, accuracy: 1e-12)
        XCTAssertEqual(calibrated.median, 100)
        XCTAssertEqual(calibrated.interval90.high, 100 * exp(2.0 * 0.22), accuracy: 1e-9)
        XCTAssertEqual(calibrated.interval90.low, 100 * exp(-2.0 * 0.22), accuracy: 1e-9)
        XCTAssertEqual(calibrated.sources, [.plateReference])
    }

    func testCalibrationSurvivesAnOldOrDamagedFile() throws {
        var table = ScanCalibrationTable()
        for step in 1...25 { table.record(score: Double(step) / 10, route: .heightMap) }
        let data = try JSONEncoder().encode(table)
        XCTAssertEqual(try JSONDecoder().decode(ScanCalibrationTable.self, from: data), table)

        XCTAssertTrue(try JSONDecoder().decode(ScanCalibrationTable.self, from: Data("{}".utf8)).scores.isEmpty)
        XCTAssertTrue(try JSONDecoder().decode(ScanCalibrationTable.self, from: Data("{\"scores\":5}".utf8)).scores.isEmpty)
        XCTAssertTrue(try JSONDecoder().decode(ScanCalibrationTable.self, from: Data("{\"scores\":{\"heightMap\":[1,\"x\"]}}".utf8)).scores.isEmpty)
        let negative = try JSONDecoder().decode(ScanCalibrationTable.self, from: Data("{\"scores\":{\"heightMap\":[1,-3,2]}}".utf8))
        XCTAssertEqual(negative.scores["heightMap"], [1, 2], "un score négatif est écarté")
    }

    // MARK: Niveau de confiance

    func testConfidenceLevelFollowsTheSpreadTheRecognitionAndWhetherItIsMeasured() throws {
        let confidence = CalibratedScanConfidence()
        let measured = try estimate(100, 0.2, [.heightMap])
        XCTAssertEqual(confidence.level(of: measured, recognitionProbability: 0.9), .high)
        XCTAssertEqual(confidence.level(of: measured, recognitionProbability: nil), .high, "aliment choisi par la personne : sûr")
        XCTAssertEqual(confidence.level(of: measured, recognitionProbability: 0.7), .medium)
        XCTAssertEqual(confidence.level(of: measured, recognitionProbability: 0.4), .low)
        XCTAssertEqual(confidence.level(of: try estimate(100, 0.4, [.heightMap]), recognitionProbability: 0.9), .medium)
        XCTAssertEqual(confidence.level(of: try estimate(100, 0.6, [.heightMap]), recognitionProbability: 0.9), .low)
        let prior = try estimate(100, 0.2, [.plateReference, .typicalThickness])
        XCTAssertEqual(confidence.level(of: prior, recognitionProbability: 0.95), .medium, "un a priori n'est jamais « sûr »")
    }

    func testCalibrationCanLowerTheLevel() throws {
        var table = ScanCalibrationTable()
        for _ in 0..<20 { table.record(score: 2.0, route: .heightMap) }
        let measured = try estimate(100, 0.22, [.heightMap])
        XCTAssertEqual(CalibratedScanConfidence().level(of: measured, recognitionProbability: 0.9), .high)
        // 0,22 × 2,0 / 1,6449 = 0,2675 : le modèle se trompait plus qu'il ne le disait.
        let calibrated = CalibratedScanConfidence(calibration: table)
        XCTAssertEqual(calibrated.level(of: measured, recognitionProbability: 0.9), .medium)
        XCTAssertEqual(calibrated.calibrated(measured).sigmaLog, 0.2675, accuracy: 0.0001)
        let viaProtocol: FoodScanConfidence = calibrated
        XCTAssertEqual(viaProtocol.calibrated(measured), calibrated.calibrated(measured))
    }
}
