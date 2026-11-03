import Foundation

/// A binary segmentation mask (true = the pixel belongs to the food), stored row by row.
struct BinaryMask: Equatable {
    let width: Int
    let height: Int
    let pixels: [Bool]

    /// Nil when the size is not positive or does not match the number of pixels.
    init?(width: Int, height: Int, pixels: [Bool]) {
        guard width > 0, height > 0, pixels.count == width * height else { return nil }
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// A mask drawn as text, one string per row: « . » or a space is an empty pixel, any other character a lit one.
    /// Nil when there is no row or the rows are not all of the same, non-zero, length.
    init?(rows: [String]) {
        guard let first = rows.first, !first.isEmpty, rows.allSatisfy({ $0.count == first.count }) else { return nil }
        self.width = first.count
        self.height = rows.count
        self.pixels = rows.flatMap { row in row.map { $0 != "." && $0 != " " } }
    }

    /// The number of lit pixels.
    var area: Int { pixels.reduce(0) { $0 + ($1 ? 1 : 0) } }
}

/// Pure measurement functions of the food scanner (recognition, segmentation, quantities, calibration, speed).
/// No Vision, no UIKit, no model: the same functions measure the current pipeline and any pipeline that replaces it.
/// Every function returns nil when the quantity is not defined (nothing to average, a division by zero, sizes
/// that do not match): a number is never made up. Ratios are fractions (0.25 is 25 %), not percentages.
enum ScanMetrics {

    // MARK: - Recognition (top-k)

    /// True when one of the `k` first ranked identifiers is accepted. False when `k` is not positive or nothing is accepted.
    static func topK(ranked: [String], accepted: Set<String>, k: Int) -> Bool {
        guard k > 0, !accepted.isEmpty else { return false }
        return ranked.prefix(k).contains { accepted.contains($0) }
    }

    /// For each expected food (the set of identifiers that count as that food), the rank in `ranked` of the proposal
    /// that found it, or nil. Greedy: the proposals are taken in rank order and each one serves the first still-free
    /// expected food it matches, so a proposal never counts for two foods and two proposals never share one food.
    static func match(ranked: [String], expected: [Set<String>]) -> [Int?] {
        var found = [Int?](repeating: nil, count: expected.count)
        for (rank, identifier) in ranked.enumerated() {
            if let slot = expected.indices.first(where: { found[$0] == nil && expected[$0].contains(identifier) }) {
                found[slot] = rank
            }
        }
        return found
    }

    /// The share of the expected foods found among the `k` first proposals. Nil when nothing is expected.
    static func recall(ranked: [String], expected: [Set<String>], k: Int) -> Double? {
        guard !expected.isEmpty else { return nil }
        guard k > 0 else { return 0 }
        let found = match(ranked: Array(ranked.prefix(k)), expected: expected).compactMap { $0 }.count
        return Double(found) / Double(expected.count)
    }

    /// The share of `true` values (a top-k rate over many photos). Nil for an empty list.
    static func rate(_ flags: [Bool]) -> Double? {
        guard !flags.isEmpty else { return nil }
        return Double(flags.filter { $0 }.count) / Double(flags.count)
    }

    /// The 95 % Wilson score interval (z = 1.96) of a rate `successes / total`: how far the true rate can lie from the one
    /// measured on `total` photos. 5 of 10 gives about 0.237 to 0.763. Nil when `total` is not positive or `successes`
    /// is outside 0...total.
    static func wilsonInterval(successes: Int, total: Int, z: Double = 1.96) -> (low: Double, high: Double)? {
        guard total > 0, successes >= 0, successes <= total, z.isFinite, z > 0 else { return nil }
        let n = Double(total)
        let p = Double(successes) / n
        let z2 = z * z
        let denominator = 1 + z2 / n
        let center = (p + z2 / (2 * n)) / denominator
        let half = z * (p * (1 - p) / n + z2 / (4 * n * n)).squareRoot() / denominator
        return (low: max(0, center - half), high: min(1, center + half))
    }

    // MARK: - Segmentation (binary masks)

    /// Intersection over union of two masks. Nil when their sizes differ or both are empty (the union is empty).
    static func intersectionOverUnion(_ a: BinaryMask, _ b: BinaryMask) -> Double? {
        guard a.width == b.width, a.height == b.height else { return nil }
        var intersection = 0
        var union = 0
        for (left, right) in zip(a.pixels, b.pixels) {
            if left && right { intersection += 1 }
            if left || right { union += 1 }
        }
        guard union > 0 else { return nil }
        return Double(intersection) / Double(union)
    }

    /// Dice coefficient (2 × intersection / (area A + area B)). Nil when their sizes differ or both are empty.
    static func dice(_ a: BinaryMask, _ b: BinaryMask) -> Double? {
        guard a.width == b.width, a.height == b.height else { return nil }
        var intersection = 0
        for (left, right) in zip(a.pixels, b.pixels) where left && right { intersection += 1 }
        let total = a.area + b.area
        guard total > 0 else { return nil }
        return 2 * Double(intersection) / Double(total)
    }

    // MARK: - Quantities (grams, kcal, macros)

    /// The pairs (predicted, truth) whose two values are finite. Nil when the lists differ in length.
    private static func finitePairs(_ predicted: [Double], _ truth: [Double]) -> [(predicted: Double, truth: Double)]? {
        guard predicted.count == truth.count else { return nil }
        return zip(predicted, truth).filter { $0.0.isFinite && $0.1.isFinite }.map { (predicted: $0.0, truth: $0.1) }
    }

    /// The mean of the finite values. Nil when there is none.
    static func mean(_ values: [Double]) -> Double? {
        let finite = values.filter(\.isFinite)
        guard !finite.isEmpty else { return nil }
        return finite.reduce(0, +) / Double(finite.count)
    }

    /// Mean absolute error, in the unit of the values (grams, kcal). Nil when nothing can be compared.
    static func meanAbsoluteError(predicted: [Double], truth: [Double]) -> Double? {
        guard let pairs = finitePairs(predicted, truth) else { return nil }
        return mean(pairs.map { abs($0.predicted - $0.truth) })
    }

    /// Bias: the mean of (predicted − truth). Positive = the scanner over-estimates, negative = it under-estimates.
    static func bias(predicted: [Double], truth: [Double]) -> Double? {
        guard let pairs = finitePairs(predicted, truth) else { return nil }
        return mean(pairs.map { $0.predicted - $0.truth })
    }

    /// Root mean squared error. Nil when nothing can be compared.
    static func rootMeanSquaredError(predicted: [Double], truth: [Double]) -> Double? {
        guard let pairs = finitePairs(predicted, truth), let squares = mean(pairs.map { ($0.predicted - $0.truth) * ($0.predicted - $0.truth) }) else { return nil }
        return squares.squareRoot()
    }

    /// |predicted − truth| / truth. Nil when the truth is not a positive number.
    static func relativeError(predicted: Double, truth: Double) -> Double? {
        guard predicted.isFinite, truth.isFinite, truth > 0 else { return nil }
        return abs(predicted - truth) / truth
    }

    /// (predicted − truth) / truth: negative when under-estimated. Nil when the truth is not a positive number.
    static func signedRelativeError(predicted: Double, truth: Double) -> Double? {
        guard predicted.isFinite, truth.isFinite, truth > 0 else { return nil }
        return (predicted - truth) / truth
    }

    /// Mean of the relative errors of the pairs whose truth is positive. Nil when none is.
    static func meanRelativeError(predicted: [Double], truth: [Double]) -> Double? {
        guard let pairs = finitePairs(predicted, truth) else { return nil }
        return mean(pairs.compactMap { relativeError(predicted: $0.predicted, truth: $0.truth) })
    }

    /// The share of the pairs (with a positive truth) whose relative error is at most `tolerance`.
    static func shareWithin(relativeTolerance tolerance: Double, predicted: [Double], truth: [Double]) -> Double? {
        guard tolerance.isFinite, tolerance >= 0, let pairs = finitePairs(predicted, truth) else { return nil }
        let errors = pairs.compactMap { relativeError(predicted: $0.predicted, truth: $0.truth) }
        return rate(errors.map { $0 <= tolerance })
    }

    // MARK: - Calibration of intervals

    /// The share of the truths that lie inside their interval, bounds included (the coverage rate of the ranges shown).
    /// An interval with low > high contains nothing. Nil when the lists differ in length or are empty.
    static func coverage(intervals: [(low: Double, high: Double)], truths: [Double]) -> Double? {
        guard intervals.count == truths.count, !intervals.isEmpty else { return nil }
        let inside = zip(intervals, truths).map { interval, truth in interval.low <= truth && truth <= interval.high }
        return rate(inside)
    }

    /// The mean width (high − low) of the intervals, in the unit of the values. Nil for an empty list.
    static func meanWidth(intervals: [(low: Double, high: Double)]) -> Double? {
        mean(intervals.map { $0.high - $0.low })
    }

    /// The mean of (high − low) / truth over the pairs with a positive truth. A coverage is only meaningful next to
    /// this width: an enormous interval always covers.
    static func meanRelativeWidth(intervals: [(low: Double, high: Double)], truths: [Double]) -> Double? {
        guard intervals.count == truths.count else { return nil }
        return mean(zip(intervals, truths).compactMap { interval, truth in
            truth.isFinite && truth > 0 ? (interval.high - interval.low) / truth : nil
        })
    }

    // MARK: - Speed

    /// The percentile `p` (0 to 100) by linear interpolation between the closest ranks (the method of the spreadsheets'
    /// PERCENTILE.INC): [1, 2, 3, 4, 5] gives 3 for p = 50 and 4.8 for p = 95. Values that are not finite are ignored.
    /// Nil when nothing is left or `p` is outside 0...100.
    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty, p.isFinite, p >= 0, p <= 100 else { return nil }
        let rank = p / 100 * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (rank - Double(lower))
    }

    /// The median (50th percentile).
    static func median(_ values: [Double]) -> Double? { percentile(values, 50) }
}
