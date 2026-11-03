import Foundation

// Confidence and uncertainty of a scan: the intervals are recalibrated on weighed meals (empty until there are
// some), the recognition of the food is mixed in, and the calories and macros come from the existing deterministic
// formula `FoodItem.nutrients(grams:)` applied to the bounds of the mass. An unknown value stays unknown.

/// How far a scan can be trusted, for the words shown to the person.
enum ScanConfidenceLevel: String, Hashable, Sendable {
    case low, medium, high
}

/// The recalibration of the intervals on weighed meals, by split conformal prediction (Angelopoulos & Bates,
/// arXiv 2107.07511). EMPTY BY DEFAULT: until enough weighed meals have been recorded the factor is 1 and the
/// intervals are those of the model, which are guesses.
///
/// Each weighed meal gives a score per route (how the quantity was obtained): |ln(real) − ln(median)| / σ, with the
/// σ of the estimate BEFORE any recalibration. The 90 % interval that holds 9 times out of 10 on those meals is
/// median × e^(±q·σ), where q is the score of rank ⌈(n + 1) × 0.9⌉ among the n smallest; the coverage factor is
/// q / 1.645 (1 if the model was right, 1.5 if its intervals were a third too narrow).
struct ScanCalibrationTable: Codable, Hashable, Sendable {
    /// Under this many weighed meals for a route, no recalibration (factor 1). À MESURER.
    static let minimumScores = 20
    /// Only the most recent scores of each route are kept.
    static let maximumScores = 200
    /// The factor is kept between these bounds.
    static let factorBounds = 0.5...4.0

    /// Normalized scores by route (`EstimateSource.rawValue`), oldest first.
    var scores: [String: [Double]] = [:]

    enum CodingKeys: String, CodingKey { case scores }

    /// |ln(real) − ln(median)| / σ, nil when the real value is not a positive finite number or σ is 0.
    static func score(estimate: ScanEstimate, trueValue: Double) -> Double? {
        guard trueValue.isFinite, trueValue > 0, estimate.sigmaLog > 1e-9 else { return nil }
        return abs(log(trueValue) - log(estimate.median)) / estimate.sigmaLog
    }

    /// Records a weighed meal: the estimate AS THE MODEL MADE IT (not recalibrated) and the real weight, in the
    /// unit of the estimate. Nothing is recorded for an estimate with no route or a value that cannot be scored.
    mutating func record(estimate: ScanEstimate, trueValue: Double) {
        guard let route = estimate.route, let score = Self.score(estimate: estimate, trueValue: trueValue) else { return }
        record(score: score, route: route)
    }

    mutating func record(score: Double, route: EstimateSource) {
        guard score.isFinite, score >= 0 else { return }
        var list = scores[route.rawValue] ?? []
        list.append(score)
        if list.count > Self.maximumScores { list.removeFirst(list.count - Self.maximumScores) }
        scores[route.rawValue] = list
    }

    func count(for route: EstimateSource?) -> Int {
        route.flatMap { scores[$0.rawValue]?.count } ?? 0
    }

    /// How much to widen (> 1) or narrow (< 1) the 90 % intervals of a route; 1 until there are enough weighed meals.
    func coverageFactor(for route: EstimateSource?) -> Double {
        guard let route, let list = scores[route.rawValue], list.count >= Self.minimumScores else { return 1 }
        let sorted = list.sorted()
        // Rank ⌈(n + 1) × 0.9⌉ (the small subtraction keeps 27.000000000000004 from rounding up to 28).
        let rank = Int((Double(sorted.count + 1) * 0.9 - 1e-9).rounded(.up))
        let index = min(max(rank, 1), sorted.count) - 1
        let factor = sorted[index] / ScanLogNormal.z90
        return min(Self.factorBounds.upperBound, max(Self.factorBounds.lowerBound, factor))
    }

    /// The estimate with its σ recalibrated for its route.
    func calibrated(_ estimate: ScanEstimate) -> ScanEstimate {
        estimate.widened(by: coverageFactor(for: estimate.route)) ?? estimate
    }
}

extension ScanCalibrationTable {
    /// Tolerant: a missing table is empty, a score that is not a finite positive number is dropped, and each route
    /// keeps its most recent `maximumScores`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw: [String: [Double]] = c.value(.scores, [:])
        var cleaned: [String: [Double]] = [:]
        for (route, list) in raw {
            let kept = list.filter { $0.isFinite && $0 >= 0 }
            cleaned[route] = Array(kept.suffix(Self.maximumScores))
        }
        scores = cleaned
    }
}

/// What gives a measure of how much a scan can be trusted.
protocol FoodScanConfidence {
    /// The estimate with its spread recalibrated on weighed meals (unchanged while there are none).
    func calibrated(_ estimate: ScanEstimate) -> ScanEstimate
    /// A level for the words shown to the person: low, medium or high.
    func level(of estimate: ScanEstimate, recognitionProbability: Double?) -> ScanConfidenceLevel
}

/// The confidence by the recalibrated spread of the quantity and the probability of the food.
struct CalibratedScanConfidence: FoodScanConfidence {
    /// À MESURER: the first thresholds. σ of 0.25 is ×/÷ 1.28 at one σ; 0.50 is ×/÷ 1.65.
    static let highSigmaLog = 0.25
    static let mediumSigmaLog = 0.50
    static let highRecognition = 0.80
    static let mediumRecognition = 0.50

    var calibration: ScanCalibrationTable

    init(calibration: ScanCalibrationTable = ScanCalibrationTable()) {
        self.calibration = calibration
    }

    func calibrated(_ estimate: ScanEstimate) -> ScanEstimate {
        calibration.calibrated(estimate)
    }

    /// Low when the quantity is very uncertain or the food unlikely; high only for a quantity that is measured
    /// (not a prior), fairly certain, of a food that is likely; medium otherwise.
    func level(of estimate: ScanEstimate, recognitionProbability: Double?) -> ScanConfidenceLevel {
        let sigma = calibrated(estimate).sigmaLog
        let probability = recognitionProbability ?? 1
        if sigma > Self.mediumSigmaLog || probability < Self.mediumRecognition { return .low }
        if sigma > Self.highSigmaLog || probability < Self.highRecognition || estimate.isPrior { return .medium }
        return .high
    }
}

// MARK: - Calories and macros with an interval

/// The calories and macronutrients of a scanned food, each with its interval at 90 %.
struct ScanNutrition: Hashable, Sendable {
    var grams: ScanEstimate
    var kcal: ScanValueInterval
    /// Nil when a food that could be the one has no known value for it: never shown as 0.
    var protein: ScanValueInterval?
    var carbs: ScanValueInterval?
    var fat: ScanValueInterval?
    /// The probability of the most likely food, between 0 and 1.
    var topProbability: Double
    /// The probability the candidates add up to (capped at 1). Under 1: the food could be something else.
    var coveredProbability: Double
    /// True when a candidate has a macronutrient its source did not give.
    var isIncomplete: Bool
}

/// Turns the foods that could be on the plate and the mass of the portion into calories and macros with intervals.
protocol NutritionResolving {
    func resolve(candidates: [FoodCandidate], grams: ScanEstimate) -> ScanNutrition?
}

/// Calories and macros as a mixture over the candidate foods: with probability p the food is f, and its value is
/// the one `FoodItem.nutrients(grams:)` gives for a mass drawn from the log-normal law of the portion. One certain
/// food gives median × per-gram value with bounds at ±1.645 σ; several foods with different values widen the
/// interval, which is the honest way to say « I am not sure what it is ».
struct MixtureNutritionResolver: NutritionResolving {
    /// The most likely foods taken into account.
    var maximumCandidates: Int

    init(maximumCandidates: Int = 5) {
        self.maximumCandidates = maximumCandidates
    }

    func resolve(candidates: [FoodCandidate], grams: ScanEstimate) -> ScanNutrition? {
        let ranked = candidates.filter { $0.probability.isFinite && $0.probability > 0 }.sorted { $0.probability > $1.probability }
        let usable = Array(ranked.prefix(max(1, maximumCandidates)))
        guard let top = usable.first else { return nil }
        let total = usable.reduce(0) { $0 + $1.probability }
        let weights = usable.map { $0.probability / total }
        let foods = usable.map { $0.food }

        guard let kcal = Self.interval(perGram: foods.map { $0.nutrients(grams: 1).kcal }, weights: weights, grams: grams) else { return nil }
        func macro(_ known: (FoodItem) -> Double?) -> ScanValueInterval? {
            let values = foods.map(known)
            guard values.allSatisfy({ $0 != nil }) else { return nil }
            return Self.interval(perGram: values.compactMap { $0 }, weights: weights, grams: grams)
        }
        return ScanNutrition(
            grams: grams, kcal: kcal,
            protein: macro { $0.knownProtein == nil ? nil : $0.nutrients(grams: 1).protein },
            carbs: macro { $0.knownCarbs == nil ? nil : $0.nutrients(grams: 1).carbs },
            fat: macro { $0.knownFat == nil ? nil : $0.nutrients(grams: 1).fat },
            topProbability: min(1, top.probability), coveredProbability: min(1, total),
            isIncomplete: foods.contains { $0.hasUnknownMacros }
        )
    }

    /// The 5 %, 50 % and 95 % points of the value (per-gram value of the food × mass), a mixture of log-normal laws
    /// with the weights of the foods. A single food has a closed form.
    static func interval(perGram: [Double], weights: [Double], grams: ScanEstimate) -> ScanValueInterval? {
        guard !perGram.isEmpty, perGram.count == weights.count, perGram.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        let median = grams.median
        var weightedPerGram = 0.0
        for (perGramValue, weight) in zip(perGram, weights) { weightedPerGram += perGramValue * weight }
        let mean = weightedPerGram * grams.mean
        guard (perGram.max() ?? 0) > 0 else { return ScanValueInterval(low: 0, central: 0, high: 0, mean: 0) }
        if perGram.count == 1 {
            let spread = ScanLogNormal.z90 * grams.sigmaLog
            let central = perGram[0] * median
            return ScanValueInterval(low: central * exp(-spread), central: central, high: central * exp(spread), mean: mean)
        }
        let sigma = max(grams.sigmaLog, 1e-9)
        return ScanValueInterval(
            low: quantile(0.05, perGram: perGram, weights: weights, median: median, sigma: sigma),
            central: quantile(0.5, perGram: perGram, weights: weights, median: median, sigma: sigma),
            high: quantile(0.95, perGram: perGram, weights: weights, median: median, sigma: sigma),
            mean: mean
        )
    }

    /// The value x such that P(value ≤ x) = p, by bisection on the distribution function of the mixture.
    private static func quantile(_ p: Double, perGram: [Double], weights: [Double], median: Double, sigma: Double) -> Double {
        func cdf(_ x: Double) -> Double {
            var total = 0.0
            for (perGramValue, weight) in zip(perGram, weights) {
                if perGramValue <= 0 {
                    total += weight
                } else if x > 0 {
                    total += weight * ScanLogNormal.normalCDF((log(x / perGramValue) - log(median)) / sigma)
                }
            }
            return total
        }
        if cdf(0) >= p { return 0 }
        var low = 0.0
        var high = (perGram.max() ?? 0) * median * exp(10 * sigma) + 1e-9
        for _ in 0..<200 {
            let middle = (low + high) / 2
            if cdf(middle) < p { low = middle } else { high = middle }
        }
        return (low + high) / 2
    }
}
