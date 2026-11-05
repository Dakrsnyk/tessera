import Foundation

/// The free dish analyses (photo of a plate) of the food scanner. Barcodes and the food search are never limited.
/// Pure, so that the rule can be tested; the count is kept in `NutritionState.photoScansUsed`.
enum PhotoScanQuota {
    /// Dish analyses a free plan can start, in total.
    static let freeLimit = 10

    /// How many free analyses are left (never below zero).
    static func remaining(used: Int) -> Int {
        max(0, freeLimit - max(0, used))
    }

    /// Whether a dish analysis can start: always with Premium, else while free ones are left.
    static func canAnalyze(used: Int, isPremium: Bool) -> Bool {
        isPremium || remaining(used: used) > 0
    }
}
