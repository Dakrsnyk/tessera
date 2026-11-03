import XCTest
@testable import Ardane

/// The measurement functions of the scanner (`Tests/Support/ScanMetrics.swift`), checked against values computed by hand.
/// They are pure: a wrong function here would make every precision report wrong without any other test noticing.
final class ScanMetricsTests: XCTestCase {

    // MARK: - top-k and recall

    func testTopKLooksOnlyAtTheFirstK() {
        let ranked = ["a", "b", "c"]
        XCTAssertFalse(ScanMetrics.topK(ranked: ranked, accepted: ["c"], k: 1))
        XCTAssertFalse(ScanMetrics.topK(ranked: ranked, accepted: ["c"], k: 2))
        XCTAssertTrue(ScanMetrics.topK(ranked: ranked, accepted: ["c"], k: 3))
        XCTAssertTrue(ScanMetrics.topK(ranked: ranked, accepted: ["c"], k: 10), "k beyond the list: the whole list")
        XCTAssertTrue(ScanMetrics.topK(ranked: ranked, accepted: ["x", "a"], k: 1), "any accepted identifier counts")
    }

    func testTopKEdgeCases() {
        XCTAssertFalse(ScanMetrics.topK(ranked: ["a"], accepted: ["a"], k: 0))
        XCTAssertFalse(ScanMetrics.topK(ranked: ["a"], accepted: ["a"], k: -1))
        XCTAssertFalse(ScanMetrics.topK(ranked: [], accepted: ["a"], k: 3), "no proposal: not recognised")
        XCTAssertFalse(ScanMetrics.topK(ranked: ["a"], accepted: [], k: 3), "nothing expected: nothing can be found")
    }

    func testMatchGivesTheRankOfEachExpectedFood() {
        let expected: [Set<String>] = [["rice"], ["chicken", "poulet"], ["broccoli"]]
        // rice is first, chicken (under its other id) third, broccoli not proposed.
        let found = ScanMetrics.match(ranked: ["rice", "egg", "poulet"], expected: expected)
        XCTAssertEqual(found.count, 3)
        XCTAssertEqual(found[0], 0)
        XCTAssertEqual(found[1], 2)
        XCTAssertNil(found[2])
    }

    func testAProposalServesOnlyOneExpectedFood() {
        // Two expected portions of rice but one proposal of rice: one is found, the other is not.
        let found = ScanMetrics.match(ranked: ["rice"], expected: [["rice"], ["rice"]])
        XCTAssertEqual(found[0], 0)
        XCTAssertNil(found[1])
    }

    func testRecallAtK() throws {
        let expected: [Set<String>] = [["rice"], ["chicken"], ["broccoli"]]
        let ranked = ["rice", "egg", "chicken", "broccoli"]
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.recall(ranked: ranked, expected: expected, k: 1)), 1.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.recall(ranked: ranked, expected: expected, k: 3)), 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.recall(ranked: ranked, expected: expected, k: 4)), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.recall(ranked: ranked, expected: expected, k: 0)), 0, accuracy: 1e-9)
        XCTAssertNil(ScanMetrics.recall(ranked: ranked, expected: [], k: 3), "nothing expected: the recall is not defined")
    }

    func testRateOfFlags() throws {
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.rate([true, false, true, true])), 0.75, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.rate([false, false])), 0, accuracy: 1e-9)
        XCTAssertNil(ScanMetrics.rate([]))
    }

    func testWilsonIntervalOfAHalfRate() throws {
        // 5 of 10: centre 0.5, half-width 1.96 x sqrt(0.025 + 0.009604) / 1.38416 = 0.2634.
        let interval = try XCTUnwrap(ScanMetrics.wilsonInterval(successes: 5, total: 10))
        XCTAssertEqual(interval.low, 0.2366, accuracy: 1e-4)
        XCTAssertEqual(interval.high, 0.7634, accuracy: 1e-4)
    }

    func testWilsonIntervalStaysInsideZeroAndOneAtTheExtremes() throws {
        let none = try XCTUnwrap(ScanMetrics.wilsonInterval(successes: 0, total: 10))
        XCTAssertEqual(none.low, 0, accuracy: 1e-9, "no success never gives a negative bound")
        XCTAssertEqual(none.high, 0.2775, accuracy: 1e-4, "yet 0 of 10 does not prove the rate is 0")
        let all = try XCTUnwrap(ScanMetrics.wilsonInterval(successes: 10, total: 10))
        XCTAssertEqual(all.low, 0.7225, accuracy: 1e-4)
        XCTAssertEqual(all.high, 1, accuracy: 1e-9)
    }

    func testWilsonIntervalNarrowsWithMorePhotos() throws {
        let small = try XCTUnwrap(ScanMetrics.wilsonInterval(successes: 15, total: 30))
        let large = try XCTUnwrap(ScanMetrics.wilsonInterval(successes: 150, total: 300))
        XCTAssertLessThan(large.high - large.low, small.high - small.low, "ten times more photos: a tighter interval")
        XCTAssertEqual(small.low + small.high, 1, accuracy: 1e-9, "symmetric around 0.5 for a rate of one half")
    }

    func testWilsonIntervalIsNotDefinedForImpossibleCounts() {
        XCTAssertNil(ScanMetrics.wilsonInterval(successes: 0, total: 0))
        XCTAssertNil(ScanMetrics.wilsonInterval(successes: 11, total: 10))
        XCTAssertNil(ScanMetrics.wilsonInterval(successes: -1, total: 10))
        XCTAssertNil(ScanMetrics.wilsonInterval(successes: 5, total: 10, z: 0))
    }

    // MARK: - IoU and Dice

    func testMaskFromRows() throws {
        let mask = try XCTUnwrap(BinaryMask(rows: ["##..", "#..."]))
        XCTAssertEqual(mask.width, 4)
        XCTAssertEqual(mask.height, 2)
        XCTAssertEqual(mask.area, 3)
        XCTAssertNil(BinaryMask(rows: []))
        XCTAssertNil(BinaryMask(rows: ["##", "#"]), "rows of different lengths")
        XCTAssertNil(BinaryMask(width: 2, height: 2, pixels: [true, false, true]), "3 pixels for a 2 x 2 mask")
        XCTAssertNil(BinaryMask(width: 0, height: 2, pixels: []))
    }

    func testIoUAndDiceOfPartiallyOverlappingMasks() throws {
        // A lights columns 0-1, B columns 1-2, on 2 rows of 4: intersection 2 pixels (column 1), union 6 pixels
        // (columns 0, 1, 2), 4 pixels each.
        let a = try XCTUnwrap(BinaryMask(rows: ["##..", "##.."]))
        let b = try XCTUnwrap(BinaryMask(rows: [".##.", ".##."]))
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.intersectionOverUnion(a, b)), 2.0 / 6.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.dice(a, b)), 2.0 * 2.0 / 8.0, accuracy: 1e-9)
        XCTAssertEqual(ScanMetrics.intersectionOverUnion(a, b), ScanMetrics.intersectionOverUnion(b, a), "symmetric")
    }

    func testIoUAndDiceOfIdenticalDisjointAndNestedMasks() throws {
        let a = try XCTUnwrap(BinaryMask(rows: ["##..", "##.."]))
        let far = try XCTUnwrap(BinaryMask(rows: ["..##", "..##"]))
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.intersectionOverUnion(a, a)), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.dice(a, a)), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.intersectionOverUnion(a, far)), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.dice(a, far)), 0, accuracy: 1e-9)
        // Nested: B (1 pixel) inside A (4 pixels): IoU 1/4, Dice 2 x 1 / (4 + 1).
        let small = try XCTUnwrap(BinaryMask(rows: ["#...", "...."]))
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.intersectionOverUnion(a, small)), 0.25, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.dice(a, small)), 0.4, accuracy: 1e-9)
    }

    func testIoUAndDiceAreNotDefinedForEmptyMasksOrDifferentSizes() throws {
        let empty = try XCTUnwrap(BinaryMask(rows: ["....", "...."]))
        let lit = try XCTUnwrap(BinaryMask(rows: ["#...", "...."]))
        let other = try XCTUnwrap(BinaryMask(rows: ["#..", "..."]))
        XCTAssertNil(ScanMetrics.intersectionOverUnion(empty, empty), "two empty masks: no union")
        XCTAssertNil(ScanMetrics.dice(empty, empty))
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.intersectionOverUnion(empty, lit)), 0, accuracy: 1e-9, "a miss is a real 0")
        XCTAssertNil(ScanMetrics.intersectionOverUnion(lit, other), "different sizes")
        XCTAssertNil(ScanMetrics.dice(lit, other))
    }

    // MARK: - Errors on quantities

    func testMeanAbsoluteErrorBiasAndRMSE() throws {
        // Errors +10, -10, +50 on truths 100, 100, 150.
        let predicted = [110.0, 90, 200]
        let truth = [100.0, 100, 150]
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.meanAbsoluteError(predicted: predicted, truth: truth)), 70.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.bias(predicted: predicted, truth: truth)), 50.0 / 3.0, accuracy: 1e-9)
        // sqrt((100 + 100 + 2500) / 3) = sqrt(900) = 30
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.rootMeanSquaredError(predicted: predicted, truth: truth)), 30, accuracy: 1e-9)
    }

    func testBiasKeepsTheSignAndTheMAEDoesNot() throws {
        // A scanner that always under-estimates by 20 g: MAE 20, bias -20.
        let predicted = [80.0, 180, 280]
        let truth = [100.0, 200, 300]
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.meanAbsoluteError(predicted: predicted, truth: truth)), 20, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.bias(predicted: predicted, truth: truth)), -20, accuracy: 1e-9)
    }

    func testErrorsAreNotDefinedForMismatchedOrEmptyLists() {
        XCTAssertNil(ScanMetrics.meanAbsoluteError(predicted: [1, 2], truth: [1]))
        XCTAssertNil(ScanMetrics.meanAbsoluteError(predicted: [], truth: []))
        XCTAssertNil(ScanMetrics.bias(predicted: [], truth: []))
        XCTAssertNil(ScanMetrics.rootMeanSquaredError(predicted: [1], truth: []))
        XCTAssertNil(ScanMetrics.meanRelativeError(predicted: [1, 2, 3], truth: [1, 2]))
    }

    func testPairsWithANonFiniteValueAreIgnored() throws {
        let mae = try XCTUnwrap(ScanMetrics.meanAbsoluteError(predicted: [110, .nan, 90], truth: [100, 50, .infinity]))
        XCTAssertEqual(mae, 10, accuracy: 1e-9, "only the first pair is usable")
        XCTAssertNil(ScanMetrics.meanAbsoluteError(predicted: [.nan], truth: [1]))
    }

    func testRelativeError() throws {
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.relativeError(predicted: 150, truth: 200)), 0.25, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.relativeError(predicted: 250, truth: 200)), 0.25, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.signedRelativeError(predicted: 150, truth: 200)), -0.25, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.signedRelativeError(predicted: 250, truth: 200)), 0.25, accuracy: 1e-9)
        XCTAssertNil(ScanMetrics.relativeError(predicted: 10, truth: 0), "division by a zero truth")
        XCTAssertNil(ScanMetrics.relativeError(predicted: 10, truth: -5))
        XCTAssertNil(ScanMetrics.signedRelativeError(predicted: .nan, truth: 5))
    }

    func testMeanRelativeErrorSkipsAZeroTruth() throws {
        // Relative errors 0.1, 0.1, 1/3 on the three first pairs; the fourth truth is 0 and is skipped.
        let predicted = [110.0, 90, 200, 7]
        let truth = [100.0, 100, 150, 0]
        let expected = (0.1 + 0.1 + 1.0 / 3.0) / 3.0
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.meanRelativeError(predicted: predicted, truth: truth)), expected, accuracy: 1e-9)
        XCTAssertNil(ScanMetrics.meanRelativeError(predicted: [5], truth: [0]), "no usable pair")
    }

    func testShareWithinATolerance() throws {
        // Relative errors 0.1, 0.1, 1/3 (the zero truth is skipped): 2 of 3 are within 15 %.
        let predicted = [110.0, 90, 200, 7]
        let truth = [100.0, 100, 150, 0]
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.shareWithin(relativeTolerance: 0.15, predicted: predicted, truth: truth)), 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.shareWithin(relativeTolerance: 0.5, predicted: predicted, truth: truth)), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.shareWithin(relativeTolerance: 0.05, predicted: predicted, truth: truth)), 0, accuracy: 1e-9)
        XCTAssertNil(ScanMetrics.shareWithin(relativeTolerance: -0.1, predicted: predicted, truth: truth))
    }

    // MARK: - Coverage of intervals

    func testCoverageCountsTheBoundsAsInside() throws {
        let intervals: [(low: Double, high: Double)] = [(90, 110), (0, 50), (100, 200), (10, 20)]
        let truths = [100.0, 60, 200, 15]
        // Inside, outside, on the upper bound, inside: 3 of 4.
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.coverage(intervals: intervals, truths: truths)), 0.75, accuracy: 1e-9)
    }

    func testCoverageOfAMalformedOrMismatchedInput() throws {
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.coverage(intervals: [(low: 120, high: 80)], truths: [100])), 0, accuracy: 1e-9,
                       "low above high contains nothing")
        XCTAssertNil(ScanMetrics.coverage(intervals: [(low: 0, high: 1)], truths: []))
        XCTAssertNil(ScanMetrics.coverage(intervals: [], truths: []))
    }

    func testIntervalWidths() throws {
        let intervals: [(low: Double, high: Double)] = [(90, 110), (0, 50), (100, 200), (10, 20)]
        let truths = [100.0, 60, 200, 15]
        // Widths 20, 50, 100, 10.
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.meanWidth(intervals: intervals)), 45, accuracy: 1e-9)
        // 20/100, 50/60, 100/200, 10/15 = 0.2 + 0.8333 + 0.5 + 0.6667 = 2.2, over 4.
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.meanRelativeWidth(intervals: intervals, truths: truths)), 0.55, accuracy: 1e-9)
        XCTAssertNil(ScanMetrics.meanWidth(intervals: []))
        XCTAssertNil(ScanMetrics.meanRelativeWidth(intervals: [(low: 0, high: 1)], truths: [0]), "a zero truth has no relative width")
    }

    func testCoverageOfTheRangesTheScannerShows() throws {
        // A photo estimate of 500 kcal is shown as 300 to 700 (+-40 %, ScanUncertainty.photoEstimate). Four meals with the
        // same estimate and truths 301 and 699 (inside), 299 and 701 (just outside): half of the ranges cover.
        let range = ScanUncertainty.range(of: 500, ratio: ScanUncertainty.photoEstimate)
        let intervals = [(low: Double, high: Double)](repeating: (low: range.low, high: range.high), count: 4)
        let covered = try XCTUnwrap(ScanMetrics.coverage(intervals: intervals, truths: [301, 699, 299, 701]))
        XCTAssertEqual(covered, 0.5, accuracy: 1e-9)
    }

    // MARK: - Percentiles

    func testPercentilesByLinearInterpolation() throws {
        let values = [1.0, 2, 3, 4, 5]
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.percentile(values, 0)), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.percentile(values, 25)), 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.percentile(values, 50)), 3, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.percentile(values, 95)), 4.8, accuracy: 1e-9, "rank 0.95 x 4 = 3.8: 4 + 0.8 x (5 - 4)")
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.percentile(values, 100)), 5, accuracy: 1e-9)
    }

    func testMedianOfAnEvenAndAnUnsortedList() throws {
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.median([4, 1, 3, 2])), 2.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.median([9, 1, 5])), 5, accuracy: 1e-9)
    }

    func testP95OfTwentyTimings() throws {
        let timings = (1...20).map(Double.init)
        // rank 0.95 x 19 = 18.05: the 19th value (19) + 0.05 x (20 - 19).
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.percentile(timings, 95)), 19.05, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.median(timings)), 10.5, accuracy: 1e-9)
    }

    func testPercentileEdgeCases() throws {
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.percentile([7], 95)), 7, accuracy: 1e-9, "one value is every percentile")
        XCTAssertNil(ScanMetrics.percentile([], 50))
        XCTAssertNil(ScanMetrics.percentile([1, 2, 3], 101))
        XCTAssertNil(ScanMetrics.percentile([1, 2, 3], -1))
        XCTAssertNil(ScanMetrics.percentile([1, 2, 3], .nan))
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.median([1, .nan, 3])), 2, accuracy: 1e-9, "a value that is not a number is ignored")
        XCTAssertNil(ScanMetrics.median([.nan, .infinity]))
    }

    func testMean() throws {
        XCTAssertEqual(try XCTUnwrap(ScanMetrics.mean([1, 2, 6])), 3, accuracy: 1e-9)
        XCTAssertNil(ScanMetrics.mean([]))
    }
}
