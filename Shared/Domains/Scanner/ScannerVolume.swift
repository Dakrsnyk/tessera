import Foundation

// Volume of a food, by two routes:
// (a) with a metric height map (LiDAR, future, experimental): V = Σ max(h − h0, 0) · ΔA over the mask of the food;
// (b) without depth: V = area × typical thickness, with a log-normal law, the thickness being a PRIOR to measure.
// Volumes are in cm³ (1 cm³ = 1 ml), heights in cm.

/// Statistics of a plain list of numbers, for the robust fit of the plane of the table.
private enum ScanStatistics {
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

// MARK: - (a) Height map

/// The plane of the table seen by the depth sensor: the height of the plate where there is no food.
struct ScanPlane: Hashable, Sendable {
    /// h0: the median height of the free cells of the ring, in cm.
    var offsetCm: Double
    /// The robust spread of those heights (1.4826 × median absolute deviation): the noise of one cell.
    var noiseSigmaCm: Double
    /// The uncertainty of h0 itself: the noise divided by √n.
    var standardErrorCm: Double
    var cellCount: Int
}

/// The result of the integration of a height map over the mask of one food.
struct ScanIntegration: Hashable, Sendable {
    /// Σ max(h − h0, 0) · ΔA over the cells that could be read, in cm³.
    var measuredVolumeCm3: Double
    /// The same, completed for the cells of the mask that could not be read (low confidence, no measure): the
    /// measured volume divided by the share of cells read. Equal to `measuredVolumeCm3` when all were read.
    var volumeCm3: Double
    /// The mean height of the food above the plane, over the cells read, in cm.
    var meanHeightCm: Double
    var maskCells: Int
    var usedCells: Int
    /// The share of the cells of the mask that could be read.
    var coverage: Double
    /// The standard deviation of the volume, in cm³ (plane, noise, edges, cells filled in).
    var sigmaCm3: Double
}

enum HeightMapIntegrator {
    /// Cells below this confidence are not read. ARKit's `high` is rare close to a plate, `low` is not usable.
    static let minimumConfidence = DepthConfidence.medium
    /// Under this share of cells read the volume is not given (the route falls back on the area and the thickness).
    /// À MESURER.
    static let minimumCoverage = 0.6
    /// A plane needs at least this many free cells of ring.
    static let minimumRingCells = 30
    /// A food lower than this above the plate (3 mm) cannot be told from the noise of the sensor: no volume.
    static let minimumMeanHeightCm = 0.3
    /// Cells further than this many robust σ from the median of the ring are not used to place the plane.
    static let outlierSigmas = 3.0
    /// À MESURER: the error of the plane that the noise of the ring does not show (a plate is not perfectly flat,
    /// the sensor drifts a little). 1.5 mm is a guess to replace by the measure on objects of known volume.
    static let planeSystematicSigmaCm = 0.15
    /// À MESURER: the error on the volume from the edges of the mask, as a share of the volume.
    static let edgeRelativeSigma = 0.05
    /// À MESURER: the error on the part of the volume that was filled in, as a share of that part.
    static let filledInRelativeSigma = 0.30

    /// The plane of the table: the median height of the cells of `ring` that are in no food mask and were read with
    /// enough confidence, after one pass that drops the cells further than 3 robust σ. Nil when the grids differ or
    /// there are too few cells.
    static func fitPlane(
        in map: HeightMap, ring: FoodMask, excluding foods: [FoodMask] = [],
        minimumConfidence: DepthConfidence = HeightMapIntegrator.minimumConfidence
    ) -> ScanPlane? {
        guard map.isConsistent, ring.width == map.width, ring.height == map.height,
              foods.allSatisfy({ $0.width == map.width && $0.height == map.height }) else { return nil }
        var values: [Double] = []
        ring.forEachCell { x, y in
            if foods.contains(where: { $0.contains(x: x, y: y) }) { return }
            guard map.confidenceAt(x: x, y: y) >= minimumConfidence, let h = map.heightCm(x: x, y: y) else { return }
            values.append(h)
        }
        guard values.count >= minimumRingCells, var center = ScanStatistics.median(values) else { return nil }
        func spread(_ list: [Double], around center: Double) -> Double {
            1.4826 * (ScanStatistics.median(list.map { abs($0 - center) }) ?? 0)
        }
        var sigma = spread(values, around: center)
        if sigma > 0 {
            let kept = values.filter { abs($0 - center) <= outlierSigmas * sigma }
            if kept.count >= minimumRingCells, let refined = ScanStatistics.median(kept) {
                center = refined
                sigma = spread(kept, around: refined)
                values = kept
            }
        }
        return ScanPlane(
            offsetCm: center, noiseSigmaCm: sigma, standardErrorCm: sigma / Double(values.count).squareRoot(),
            cellCount: values.count
        )
    }

    /// The volume above `plane` over the cells of `mask`. Cells with a confidence under `minimumConfidence` or no
    /// measure are left out (a spike of the sensor never counts), and the volume is completed for them by the share
    /// of cells read. Nil when the grids differ, nothing could be read or the share read is under `minimumCoverage`.
    static func integrate(
        _ map: HeightMap, mask: FoodMask, plane: ScanPlane,
        minimumConfidence: DepthConfidence = HeightMapIntegrator.minimumConfidence,
        minimumCoverage: Double = HeightMapIntegrator.minimumCoverage
    ) -> ScanIntegration? {
        guard map.isConsistent, mask.width == map.width, mask.height == map.height else { return nil }
        let cellArea = map.cellSizeCm * map.cellSizeCm
        var total = 0
        var used = 0
        var sumHeights = 0.0
        mask.forEachCell { x, y in
            total += 1
            guard map.confidenceAt(x: x, y: y) >= minimumConfidence, let h = map.heightCm(x: x, y: y) else { return }
            used += 1
            // KNOWN BIAS, not corrected: the rectification max(h − h0, 0) keeps the positive noise and drops the
            // negative one. For a cell where the food is really at the height of the plane, the expected value is
            // not 0 but σ/√(2π) ≈ +0.4 σ, σ being the noise of one cell (`ScanPlane.noiseSigmaCm`). Negligible for
            // a thick food (a heap of 2 cm over a noise of 2 mm), but for a thin one (a layer of sauce, a slice
            // near `minimumMeanHeightCm`) the volume is overestimated by about 0.4 σ × area, a share that grows as
            // the food gets thinner. `sigmaCm3` does not include it: it is a bias, not a spread. A signed sum
            // would have no such bias but would let a hole of the sensor under the plane take volume away: which
            // of the two is better is to be decided on objects of known volume, like `planeSystematicSigmaCm`.
            sumHeights += max(h - plane.offsetCm, 0)
        }
        guard total > 0, used > 0 else { return nil }
        let coverage = Double(used) / Double(total)
        guard coverage >= minimumCoverage else { return nil }
        let measured = sumHeights * cellArea
        let completed = measured / coverage
        let area = Double(total) * cellArea
        let planeSigma = (plane.standardErrorCm * plane.standardErrorCm + planeSystematicSigmaCm * planeSystematicSigmaCm).squareRoot()
        let noiseSigma = plane.noiseSigmaCm / Double(used).squareRoot()
        let terms = [
            area * planeSigma,
            area * noiseSigma,
            completed * edgeRelativeSigma,
            completed * (1 - coverage) * filledInRelativeSigma,
        ]
        return ScanIntegration(
            measuredVolumeCm3: measured, volumeCm3: completed, meanHeightCm: sumHeights / Double(used),
            maskCells: total, usedCells: used, coverage: coverage,
            sigmaCm3: terms.reduce(0) { $0 + $1 * $1 }.squareRoot()
        )
    }

    /// The volume of one food as an estimate (median = the integral, σ from the error terms), or nil to fall back
    /// on the route without depth: no plane, too few cells read, or a food lower than 3 mm.
    static func estimate(
        map: HeightMap, mask: FoodMask, ring: FoodMask, excluding foods: [FoodMask] = []
    ) -> ScanEstimate? {
        guard let plane = fitPlane(in: map, ring: ring, excluding: foods + [mask]),
              let integration = integrate(map, mask: mask, plane: plane),
              integration.meanHeightCm >= minimumMeanHeightCm, integration.volumeCm3 > 0 else { return nil }
        let sigma = ScanLogNormal.sigma(relativeError: integration.sigmaCm3 / integration.volumeCm3)
        return ScanEstimate(median: integration.volumeCm3, sigmaLog: sigma, sources: [.heightMap])
    }
}

// MARK: - (b) No depth: area × thickness

/// Whether a food is eaten raw or cooked; the thickness of a pile of salad is not that of a pile of cooked greens.
enum FoodPreparation: String, Hashable, Sendable {
    case raw, cooked, unknown
}

/// The shape of a food on the plate: a layer that lies flat (a fillet, a slice, a spread) or a pile (rice, salad).
enum FoodShape: String, Hashable, Sendable {
    case flat, heap
}

/// Whether a figure of the scanner has been measured or is a first guess waiting for weighed meals.
enum PriorStatus: String, Hashable, Sendable {
    /// À MESURER: a plausible first value, never presented as measured.
    case toMeasure
    case measured
}

/// A typical thickness of a food: the mean height of the food over its footprint (volume / area), in cm.
struct ThicknessPrior: Hashable, Sendable {
    var medianCm: Double
    var sigmaLog: Double
    var status: PriorStatus
}

/// One line of the table of typical thicknesses. A nil `family` or `preparation` matches any.
struct ThicknessRule: Hashable, Sendable {
    var family: FoodCategory?
    var preparation: FoodPreparation?
    var shape: FoodShape
    var prior: ThicknessPrior
}

enum FoodThicknessTable {
    /// À MESURER: the spread of the first values. ×/÷ 1.5 at one σ is prudent: the thickness of a serving varies
    /// a lot, and it is the main source of error of the route without depth.
    static let defaultSigmaLog = 0.40
    static let genericSigmaLog = 0.50

    private static func rule(
        _ family: FoodCategory?, _ shape: FoodShape, _ medianCm: Double,
        preparation: FoodPreparation? = nil, sigma: Double = FoodThicknessTable.defaultSigmaLog
    ) -> ThicknessRule {
        ThicknessRule(
            family: family, preparation: preparation, shape: shape,
            prior: ThicknessPrior(medianCm: medianCm, sigmaLog: sigma, status: .toMeasure)
        )
    }

    /// The first values, ALL TO MEASURE (à mesurer): round figures chosen as the middle of what a serving of this
    /// kind plausibly is, with a wide spread. They are to be replaced by the thickness measured on weighed meals
    /// (`Tests/WeighedMeals`), then by what each person corrects. A line with a preparation is tried first.
    static let rules: [ThicknessRule] = [
        rule(.vegetables, .heap, 3.5, preparation: .raw, sigma: 0.50),
        rule(.vegetables, .heap, 2.5, preparation: .cooked, sigma: 0.45),
        rule(.fruits, .flat, 2.0), rule(.fruits, .heap, 3.0),
        rule(.vegetables, .flat, 1.5), rule(.vegetables, .heap, 3.0),
        rule(.starches, .flat, 1.2), rule(.starches, .heap, 2.0),
        rule(.proteins, .flat, 1.8), rule(.proteins, .heap, 2.5),
        rule(.dairy, .flat, 1.5), rule(.dairy, .heap, 2.5),
        rule(.fats, .flat, 0.8), rule(.fats, .heap, 1.5),
        rule(.dishes, .flat, 2.0), rule(.dishes, .heap, 3.0),
        rule(.snacks, .flat, 1.0), rule(.snacks, .heap, 2.0),
        rule(.condiments, .flat, 0.4), rule(.condiments, .heap, 1.0),
        rule(nil, .flat, 1.5, sigma: FoodThicknessTable.genericSigmaLog),
        rule(nil, .heap, 2.5, sigma: FoodThicknessTable.genericSigmaLog),
    ]

    /// The typical thickness of a food. A drink (a liquid has the shape of its container, not of a plate) has none:
    /// nil, and the app asks for the size of the bowl and its level instead of pretending to measure.
    static func prior(family: FoodCategory?, preparation: FoodPreparation, shape: FoodShape) -> ThicknessPrior? {
        if family == .drinks { return nil }
        let candidates = rules.filter { $0.shape == shape }
        if let family {
            if let exact = candidates.first(where: { $0.family == family && $0.preparation == preparation && preparation != .unknown }) {
                return exact.prior
            }
            if let ofFamily = candidates.first(where: { $0.family == family && $0.preparation == nil }) { return ofFamily.prior }
        }
        return candidates.first { $0.family == nil && $0.preparation == nil }?.prior
    }
}

enum ThicknessVolume {
    /// V = A × h: the medians multiply and σ² = σ_A² + σ_h². The result says it rests on a typical thickness.
    static func volume(area: ScanEstimate, thickness: ThicknessPrior) -> ScanEstimate? {
        guard let thicknessEstimate = ScanEstimate(
            median: thickness.medianCm, sigmaLog: thickness.sigmaLog, sources: [.typicalThickness]
        ) else { return nil }
        return area.multiplied(by: thicknessEstimate)
    }
}
