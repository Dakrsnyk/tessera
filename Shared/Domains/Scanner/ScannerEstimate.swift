import Foundation

// Pure logic of the food scanner (chantier 22): no UIKit, ARKit, Vision or Core ML, so that it is compiled in the
// widget extension too and tested without a device. See `ScannerArchitecture.swift` for the roles.

/// Where a piece of information of a scan comes from. An estimate carries the list of its sources, so the app can
/// say « mesuré » for a metric depth map and « estimation grossière » for a typical thickness.
enum EstimateSource: String, Codable, Hashable, Sendable {
    // How the footprint or the volume was obtained.
    /// A metric height map (LiDAR), integrated over the mask of the food.
    case heightMap
    /// The footprint comes from the known diameter of a plate.
    case plateReference
    /// The footprint comes from an object of known size (a card, a coin).
    case referenceObject
    /// The thickness is the typical one of this kind of food: a PRIOR, not a measure of this meal.
    case typicalThickness
    // Where the density came from.
    /// The density of the food itself, from a household measure of the Canadian Nutrient File.
    case measuredDensity
    /// The density of the family of the food (median of its measured foods): a PRIOR.
    case categoryDensity
    // What the person taught the app.
    case personalFactor
    // No measure of the meal at all.
    /// The usual portion of the food in the tables.
    case usualPortion
    /// A quantity typed or weighed by the person.
    case userEntered

    /// True for a source that is a guess about this kind of food, not a measure of this meal.
    var isPrior: Bool {
        switch self {
        case .typicalThickness, .categoryDensity, .usualPortion: true
        default: false
        }
    }

    /// The sources that say how the quantity was obtained (the key of the calibration of intervals).
    static let routes: [EstimateSource] = [.heightMap, .plateReference, .referenceObject, .usualPortion, .userEntered]
}

/// An interval for a quantity that is not exactly known: the central value (the median), the bounds that
/// contain it 9 times out of 10, and the mean (the one to add up when several foods make a meal).
struct ScanValueInterval: Hashable, Sendable {
    var low: Double
    var central: Double
    var high: Double
    var mean: Double

    init(low: Double, central: Double, high: Double, mean: Double? = nil) {
        self.low = low
        self.central = central
        self.high = high
        self.mean = mean ?? central
    }

    /// Half the width of the interval as a share of the central value (0 when the central value is 0).
    var relativeHalfWidth: Double {
        central > 0 ? (high - low) / (2 * central) : 0
    }
}

/// Helpers of the log-normal law used for every quantity of the scanner (volume, density, mass): an error that
/// multiplies (a plate 10 % too small gives an area 21 % too small) is an addition in the logarithm.
enum ScanLogNormal {
    /// The standard normal quantile of 95 %: [e^(−z·σ), e^(+z·σ)] around the median holds 90 % of the law.
    static let z90 = 1.6448536269514722

    /// The σ of ln(x) for a relative error taken as a coefficient of variation: σ² = ln(1 + e²). 0 for an error
    /// that is not a positive finite number.
    static func sigma(relativeError: Double) -> Double {
        guard relativeError.isFinite, relativeError > 0 else { return 0 }
        return log(1 + relativeError * relativeError).squareRoot()
    }

    /// The σ of a product of independent log-normal factors: σ² = Σ σᵢ².
    static func combined(_ sigmas: [Double]) -> Double {
        sigmas.reduce(0) { $0 + $1 * $1 }.squareRoot()
    }

    /// Φ(z), the standard normal distribution function.
    static func normalCDF(_ z: Double) -> Double {
        0.5 * (1 + erf(z / 2.0.squareRoot()))
    }
}

/// A positive quantity known up to a multiplicative error: a log-normal law, with its median, the σ of ln(x),
/// and where the information comes from. Used for areas (cm²), volumes (cm³ = ml), densities (g/ml) and masses (g).
///
/// An unknown quantity is NEVER an estimate of 0: the initializer returns nil for a value that is not a
/// positive finite number, and every operation returns nil when it cannot give a meaningful result.
struct ScanEstimate: Hashable, Sendable {
    /// exp(μ): the central value. One time out of two the real quantity is below it.
    let median: Double
    /// σ of the natural logarithm of the quantity. 0.2 means a typical error of ×/÷ 1.22.
    let sigmaLog: Double
    /// Where the information comes from, without duplicates, in the order they were added.
    let sources: [EstimateSource]

    init?(median: Double, sigmaLog: Double, sources: [EstimateSource] = []) {
        guard median.isFinite, median > 0, sigmaLog.isFinite, sigmaLog >= 0 else { return nil }
        self.median = median
        self.sigmaLog = sigmaLog
        self.sources = Self.unique(sources)
    }

    private static func unique(_ sources: [EstimateSource]) -> [EstimateSource] {
        var result: [EstimateSource] = []
        for source in sources where !result.contains(source) { result.append(source) }
        return result
    }

    /// μ of the law: ln(median).
    var mu: Double { log(median) }

    /// The mean of the law: median × e^(σ²/2). Larger than the median; it is the one to add up over foods.
    var mean: Double { median * exp(sigmaLog * sigmaLog / 2) }

    /// The interval holding 90 % of the law. `coverageFactor` (≥ 1 when weighed meals showed the intervals too
    /// narrow, see `ScanCalibrationTable`) widens it: the bounds are median × e^(±1.645·σ·factor).
    func interval(coverageFactor: Double = 1) -> ScanValueInterval {
        let factor = coverageFactor.isFinite && coverageFactor > 0 ? coverageFactor : 1
        let spread = ScanLogNormal.z90 * sigmaLog * factor
        return ScanValueInterval(low: median * exp(-spread), central: median, high: median * exp(spread), mean: mean)
    }

    /// The interval at 90 % with no recalibration.
    var interval90: ScanValueInterval { interval() }

    /// True when a source is a guess about this kind of food (typical thickness, family density, usual portion).
    var isPrior: Bool { sources.contains { $0.isPrior } }

    /// How the quantity was obtained: the first source that says so (nil when none does).
    var route: EstimateSource? {
        EstimateSource.routes.first { sources.contains($0) }
    }

    /// The same median with a σ multiplied by `factor` (a recalibrated, wider or narrower law). Nil for a factor
    /// that is not a positive finite number.
    func widened(by factor: Double) -> ScanEstimate? {
        guard factor.isFinite, factor > 0 else { return nil }
        return ScanEstimate(median: median, sigmaLog: sigmaLog * factor, sources: sources)
    }

    /// The median multiplied by `factor` (a personal correction); the spread is unchanged, as a correction
    /// learned from a few meals does not make the next one any more certain. Nil for a factor that is not a
    /// positive finite number.
    func scaled(by factor: Double, adding source: EstimateSource? = nil) -> ScanEstimate? {
        guard factor.isFinite, factor > 0 else { return nil }
        return ScanEstimate(median: median * factor, sigmaLog: sigmaLog, sources: sources + (source.map { [$0] } ?? []))
    }

    /// The product of two independent estimates (an area by a thickness, a volume by a density): the medians
    /// multiply and σ² = σ₁² + σ₂². Nil when the product is not a positive finite number.
    func multiplied(by other: ScanEstimate) -> ScanEstimate? {
        ScanEstimate(
            median: median * other.median, sigmaLog: ScanLogNormal.combined([sigmaLog, other.sigmaLog]),
            sources: sources + other.sources
        )
    }

    /// The same estimate with an independent error added to its σ.
    func adding(sigmaLog extra: Double) -> ScanEstimate? {
        guard extra.isFinite, extra >= 0 else { return nil }
        return ScanEstimate(median: median, sigmaLog: ScanLogNormal.combined([sigmaLog, extra]), sources: sources)
    }
}
