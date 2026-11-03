import XCTest
@testable import Ardane

/// Volume d'un aliment (Shared/Domains/Scanner/ScannerVolume.swift) : l'intégrateur de carte de hauteur (voie
/// LiDAR future) et le volume sans profondeur (aire × épaisseur type). Données SYNTHÉTIQUES : un disque de riz de
/// 12 cm de diamètre et 2 cm de haut posé sur une assiette dont la surface est à 1 cm (référence arbitraire).
/// Volume attendu : π × 6² × 2 = 226,19 cm³. Cellules de 2,5 mm (0,25 cm), carte de 160 × 160 cellules (40 cm).
final class ScannerVolumeTests: XCTestCase {
    private let size = 160
    private let cell = 0.25
    private let planeCm = 1.0
    private let riceTopCm = 3.0
    private let analytic = Double.pi * 36 * 2

    /// Le carré de la distance en cm du centre de la cellule au centre du disque (20 cm, 20 cm).
    private func squaredDistance(_ x: Int, _ y: Int) -> Double {
        let dx = (Double(x) + 0.5) * cell - 20
        let dy = (Double(y) + 0.5) * cell - 20
        return dx * dx + dy * dy
    }

    private var riceMask: FoodMask {
        FoodMask(width: size, height: size) { x, y in self.squaredDistance(x, y) <= 36 }
    }

    /// L'anneau libre de l'assiette : entre 7 et 10 cm du centre.
    private var ringMask: FoodMask {
        FoodMask(width: size, height: size) { x, y in
            let d2 = self.squaredDistance(x, y)
            return d2 >= 49 && d2 <= 100
        }
    }

    /// Un générateur congruentiel linéaire à graine fixe : des "mesures" bruitées mais toujours les mêmes.
    private struct FixedNoise {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
    }

    /// La carte : le plateau à `planeCm`, le riz à `riceTop`, un bruit uniforme de ±`noise` cm, et une confiance
    /// basse (avec une hauteur absurde de 40 cm) là où `spike` répond vrai.
    private func heightMap(noise: Double = 0, riceTop: Double? = nil, spike: (Int, Int) -> Bool = { _, _ in false }) -> HeightMap {
        var generator = FixedNoise(state: 12_345)
        var heights: [Double] = []
        var confidence: [DepthConfidence] = []
        for y in 0..<size {
            for x in 0..<size {
                let base = squaredDistance(x, y) <= 36 ? (riceTop ?? riceTopCm) : planeCm
                let jitter = noise > 0 ? (generator.next() - 0.5) * 2 * noise : 0
                if spike(x, y) {
                    heights.append(40)
                    confidence.append(.low)
                } else {
                    heights.append(base + jitter)
                    confidence.append(.high)
                }
            }
        }
        return HeightMap(width: size, height: size, cellSizeCm: cell, heightsCm: heights, confidence: confidence)
    }

    // MARK: Intégrateur

    func testDiscOfRiceGivesTheVolumeOfACylinder() throws {
        let map = heightMap()
        let rice = riceMask
        XCTAssertTrue(map.isConsistent)
        XCTAssertTrue((1_790...1_820).contains(rice.count), "π × 6² / 0,25² = 1 809 cellules, \(rice.count)")

        let plane = try XCTUnwrap(HeightMapIntegrator.fitPlane(in: map, ring: ringMask, excluding: [rice]))
        XCTAssertEqual(plane.offsetCm, 1.0, accuracy: 1e-9)
        XCTAssertEqual(plane.noiseSigmaCm, 0, accuracy: 1e-9)

        let integration = try XCTUnwrap(HeightMapIntegrator.integrate(map, mask: rice, plane: plane))
        // V = Σ (h − h0) ΔA = cellules × 0,0625 cm² × 2 cm, exactement.
        XCTAssertEqual(integration.measuredVolumeCm3, Double(rice.count) * 0.0625 * 2.0, accuracy: 1e-9)
        XCTAssertEqual(integration.volumeCm3, integration.measuredVolumeCm3, accuracy: 1e-9)
        XCTAssertEqual(integration.coverage, 1, accuracy: 1e-12)
        XCTAssertEqual(integration.meanHeightCm, 2.0, accuracy: 1e-9)
        XCTAssertEqual(integration.usedCells, integration.maskCells)
        // Et la valeur analytique du cylindre, à la discrétisation près (0,3 %).
        XCTAssertEqual(integration.volumeCm3, analytic, accuracy: analytic * 0.015)
    }

    func testNoisyPlaneIsRecoveredByTheRobustMedian() throws {
        let map = heightMap(noise: 0.1)
        let rice = riceMask
        let plane = try XCTUnwrap(HeightMapIntegrator.fitPlane(in: map, ring: ringMask, excluding: [rice]))
        XCTAssertEqual(plane.offsetCm, 1.0, accuracy: 0.02)
        // Bruit uniforme de ±0,1 cm : écart absolu médian 0,05 cm, donc 1,4826 × 0,05 = 0,074 cm (la mesure robuste
        // est calée sur une loi normale ; l'écart-type d'un bruit uniforme est 0,058).
        XCTAssertEqual(plane.noiseSigmaCm, 0.074, accuracy: 0.006)
        XCTAssertLessThan(plane.standardErrorCm, 0.005)
        let integration = try XCTUnwrap(HeightMapIntegrator.integrate(map, mask: rice, plane: plane))
        XCTAssertEqual(integration.volumeCm3, analytic, accuracy: analytic * 0.03)
    }

    func testLowConfidenceCellsAreRejectedAndTheirSpikesNeverCount() throws {
        // Une cellule sur dix (en diagonale), du riz comme de l'anneau, est à confiance basse avec 40 cm de haut.
        let spiked = heightMap(spike: { x, y in (x + y) % 10 == 0 })
        let rice = riceMask
        let plane = try XCTUnwrap(HeightMapIntegrator.fitPlane(in: spiked, ring: ringMask, excluding: [rice]))
        XCTAssertEqual(plane.offsetCm, 1.0, accuracy: 1e-9, "les pics du plateau sont rejetés")

        let integration = try XCTUnwrap(HeightMapIntegrator.integrate(spiked, mask: rice, plane: plane))
        XCTAssertLessThan(integration.usedCells, integration.maskCells)
        XCTAssertEqual(integration.coverage, Double(integration.usedCells) / Double(integration.maskCells), accuracy: 1e-12)
        XCTAssertGreaterThan(integration.coverage, 0.85)
        XCTAssertLessThan(integration.measuredVolumeCm3, integration.volumeCm3)
        // Les cellules lues sont toutes à 2 cm : le volume complété est exactement celui du disque entier.
        XCTAssertEqual(integration.volumeCm3, Double(rice.count) * 0.0625 * 2.0, accuracy: 1e-9)
        XCTAssertLessThan(integration.volumeCm3, 300, "un pic de 40 cm accepté ferait plusieurs centaines de cm³")
    }

    func testTooFewReadableCellsGiveNoVolume() throws {
        // Une cellule sur deux illisible : 50 % lues, sous le seuil de 60 % → repli sur la voie sans profondeur.
        let halfBlind = heightMap(spike: { x, y in (x + y) % 2 == 0 })
        let rice = riceMask
        let plane = try XCTUnwrap(HeightMapIntegrator.fitPlane(in: halfBlind, ring: ringMask, excluding: [rice]))
        XCTAssertNil(HeightMapIntegrator.integrate(halfBlind, mask: rice, plane: plane))
        XCTAssertNil(HeightMapIntegrator.estimate(map: halfBlind, mask: rice, ring: ringMask))
    }

    func testFoodCellsInTheRingAreLeftOutOfThePlane() throws {
        // Un "anneau" qui contient le riz (disque de 7 cm) : le riz est 73 % de ses cellules.
        let wide = FoodMask(width: size, height: size) { x, y in self.squaredDistance(x, y) <= 49 }
        let rice = riceMask
        let map = heightMap()
        let fooled = try XCTUnwrap(HeightMapIntegrator.fitPlane(in: map, ring: wide))
        XCTAssertEqual(fooled.offsetCm, 3.0, accuracy: 1e-9, "sans exclusion, la médiane est celle du riz")
        let right = try XCTUnwrap(HeightMapIntegrator.fitPlane(in: map, ring: wide, excluding: [rice]))
        XCTAssertEqual(right.offsetCm, 1.0, accuracy: 1e-9, "avec l'exclusion, c'est le plateau")
    }

    func testAFoodThinnerThanThreeMillimetresIsNotMeasured() {
        let thin = heightMap(riceTop: 1.1)
        XCTAssertNil(HeightMapIntegrator.estimate(map: thin, mask: riceMask, ring: ringMask), "1 mm au-dessus du plateau : dans le bruit")
        let sunk = heightMap(riceTop: 0.5)
        XCTAssertNil(HeightMapIntegrator.estimate(map: sunk, mask: riceMask, ring: ringMask), "sous le plan : zéro, donc inconnu")
    }

    func testPlaneNeedsEnoughRingCellsAndMatchingGrids() {
        let map = heightMap()
        let tinyRing = FoodMask(width: size, height: size) { x, y in x < 3 && y < 3 }
        XCTAssertNil(HeightMapIntegrator.fitPlane(in: map, ring: tinyRing), "9 cellules : pas de plan")
        let otherGrid = FoodMask(width: 10, height: 10) { _, _ in true }
        XCTAssertNil(HeightMapIntegrator.fitPlane(in: map, ring: otherGrid))
        XCTAssertNil(HeightMapIntegrator.fitPlane(in: map, ring: ringMask, excluding: [otherGrid]))
        XCTAssertNil(HeightMapIntegrator.estimate(map: map, mask: otherGrid, ring: ringMask))

        let broken = HeightMap(width: 4, height: 4, cellSizeCm: 0.25, heightsCm: [1, 2, 3], confidence: [.high])
        XCTAssertFalse(broken.isConsistent)
        XCTAssertNil(broken.heightCm(x: 0, y: 0))
        XCTAssertEqual(broken.confidenceAt(x: 0, y: 0), .low)
        XCTAssertNil(HeightMapIntegrator.fitPlane(in: broken, ring: FoodMask(width: 4, height: 4) { _, _ in true }))
    }

    func testVolumeEstimateCarriesItsSourceAndItsSpread() throws {
        let map = heightMap()
        let rice = riceMask
        let estimate = try XCTUnwrap(HeightMapIntegrator.estimate(map: map, mask: rice, ring: ringMask))
        let volume = Double(rice.count) * 0.0625 * 2.0
        XCTAssertEqual(estimate.median, volume, accuracy: 1e-9)
        XCTAssertEqual(estimate.sources, [.heightMap])
        XCTAssertFalse(estimate.isPrior, "une carte de hauteur est une mesure, pas un a priori")

        // Plateau sans bruit : il reste l'erreur systématique du plan (A × 0,15 cm) et celle des bords (5 % de V).
        let area = Double(rice.count) * 0.0625
        let sd = (pow(area * HeightMapIntegrator.planeSystematicSigmaCm, 2) + pow(volume * HeightMapIntegrator.edgeRelativeSigma, 2)).squareRoot()
        XCTAssertEqual(estimate.sigmaLog, ScanLogNormal.sigma(relativeError: sd / volume), accuracy: 1e-9)
        XCTAssertEqual(estimate.sigmaLog, 0.09, accuracy: 0.005)
    }

    func testHeightMapEstimatorUsesTheMaskOfItsFood() throws {
        let rice = riceMask
        let capture = HeightMapCapture(map: heightMap(), foodMasks: [rice], plateRing: ringMask)
        let estimator = HeightMapVolumeEstimator()
        let found = try XCTUnwrap(estimator.estimateVolume(FoodVolumeInput(heightMap: capture, maskIndex: 0)))
        XCTAssertEqual(found.median, Double(rice.count) * 0.125, accuracy: 1e-9)
        XCTAssertNil(estimator.estimateVolume(FoodVolumeInput()), "sans carte de hauteur : pas de volume")
        XCTAssertNil(estimator.estimateVolume(FoodVolumeInput(heightMap: capture, maskIndex: 3)), "un aliment qui n'existe pas")
    }

    // MARK: Sans profondeur : aire × épaisseur

    func testVolumeFromAreaAndThickness() throws {
        let area = try XCTUnwrap(ScanEstimate(median: 113.1, sigmaLog: 0.2, sources: [.plateReference]))
        let thickness = ThicknessPrior(medianCm: 2.0, sigmaLog: 0.4, status: .toMeasure)
        let volume = try XCTUnwrap(ThicknessVolume.volume(area: area, thickness: thickness))
        // V = A × h = 226,2 ; σ² = 0,2² + 0,4² = 0,2 → σ = 0,4472 ; 90 % : × e^(±1,645 × 0,4472) = × 0,4792 / × 2,0868.
        XCTAssertEqual(volume.median, 226.2, accuracy: 1e-9)
        XCTAssertEqual(volume.sigmaLog, 0.2.squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(volume.sources, [.plateReference, .typicalThickness])
        XCTAssertTrue(volume.isPrior, "une épaisseur type est un a priori : jamais présenté comme mesuré")
        let interval = volume.interval90
        XCTAssertEqual(interval.low, 108.4, accuracy: 0.1)
        XCTAssertEqual(interval.high, 472.0, accuracy: 0.1)
        XCTAssertEqual(interval.central, 226.2, accuracy: 1e-9)
    }

    func testEveryFirstThicknessIsMarkedToMeasureWithAWideSpread() {
        XCTAssertFalse(FoodThicknessTable.rules.isEmpty)
        for rule in FoodThicknessTable.rules {
            XCTAssertEqual(rule.prior.status, .toMeasure, "aucune épaisseur n'est mesurée pour l'instant")
            XCTAssertGreaterThan(rule.prior.medianCm, 0)
            XCTAssertLessThan(rule.prior.medianCm, 10)
            XCTAssertGreaterThanOrEqual(rule.prior.sigmaLog, FoodThicknessTable.defaultSigmaLog, "écart large : ×/÷ 1,5 au moins")
        }
        // Les deux formes existent pour chaque famille et pour le cas général.
        for family in FoodCategory.allCases where family != .drinks {
            for shape in [FoodShape.flat, FoodShape.heap] {
                XCTAssertNotNil(FoodThicknessTable.prior(family: family, preparation: .unknown, shape: shape), "\(family) \(shape)")
            }
        }
    }

    func testThicknessLookupPrefersTheMostSpecificLine() throws {
        func median(_ family: FoodCategory?, _ preparation: FoodPreparation, _ shape: FoodShape) -> Double? {
            FoodThicknessTable.prior(family: family, preparation: preparation, shape: shape)?.medianCm
        }
        XCTAssertEqual(try XCTUnwrap(median(.vegetables, .raw, .heap)), 3.5, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(median(.vegetables, .cooked, .heap)), 2.5, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(median(.vegetables, .unknown, .heap)), 3.0, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(median(.vegetables, .raw, .flat)), 1.5, accuracy: 1e-12, "pas de ligne crue à plat : celle de la famille")
        XCTAssertEqual(try XCTUnwrap(median(nil, .cooked, .heap)), 2.5, accuracy: 1e-12, "sans famille : la ligne générale")
        XCTAssertEqual(try XCTUnwrap(median(nil, .unknown, .flat)), 1.5, accuracy: 1e-12)
        XCTAssertNil(median(.drinks, .unknown, .heap), "un liquide prend la forme de son contenant : demander le bol, ne pas mesurer")
    }

    func testThicknessEstimatorNeedsAFootprintAndAFoodThatHasAThickness() throws {
        let estimator = ThicknessVolumeEstimator()
        XCTAssertNil(estimator.estimateVolume(FoodVolumeInput(family: .starches, shape: .heap)), "sans aire : inconnu")
        let area = try XCTUnwrap(ScanEstimate(median: 113.1, sigmaLog: 0.2, sources: [.plateReference]))
        XCTAssertNil(estimator.estimateVolume(FoodVolumeInput(family: .drinks, shape: .heap, area: area)))
        let rice = try XCTUnwrap(estimator.estimateVolume(FoodVolumeInput(family: .starches, shape: .heap, area: area)))
        XCTAssertEqual(rice.median, 113.1 * 2.0, accuracy: 1e-9, "féculents en tas : 2 cm (à mesurer)")
        XCTAssertTrue(rice.isPrior)
    }
}
