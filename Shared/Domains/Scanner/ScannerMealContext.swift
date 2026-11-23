import Foundation

// The context of the meal for the food scanner (2026-11-23): the foods of one plate inform each other. Rice makes chicken or
// a curry more likely in the zone next to it, a steak makes potatoes or a gravy more likely, pasta a tomato sauce or parmesan;
// a steak makes popcorn LESS likely. The reasoning has five levels, each kept in its place:
//   1. what is visible: the segmenter and the classifier, zone by zone (`FoodModelRecognizer`), unchanged;
//   2. the context: every other zone of the photo, weighted by how sure the segmenter is that it is a food;
//   3. the associations: how often two foods are photographed together in real meals (`MealContextTable`, learned from the
//      ~38 000 annotated meals of MyFoodRepo by `scripts/ml/meal_context.py`), never a rule written by hand;
//   4. the check: a zone's foods are only ever the ones its own classifier proposes (its first `foodsPerZone`); the context
//      reorders them and moves their probabilities by a bounded factor, it never adds a food, never removes a zone, and the
//      total probability of the zone stays what the image gave;
//   5. the result: no food crosses the threshold of automatic adding (`ScanRecap.autoAddThreshold`) thanks to the context
//      alone; a food the context put first, or made less sure, waits in « À confirmer » with the others as one-tap choices.
// Measured before / after on 1 000 test photos never used to tune it: `scripts/ml/meal_context.py eval`.
//
// Pure logic, Foundation only (this folder is also compiled in the widget extension). The Python of `meal_context.py`
// (`rerank`) is the reference: `ScannerMealContextTests` replays its outputs, so a change here must be a change there.

/// How much two foods go together in real meals: S(a, b) = ln((n_ab + k) / (n_a n_b / N + k)) over the photos of meals
/// (positive: seen together more often than chance; negative: less; 0: no evidence either way, or a pair too rare to say).
struct MealContextTable: Sendable {
    /// How strongly the context moves a probability: p' = p × exp(bound(alpha × s, ±cap)).
    var alpha: Double
    /// The largest change of a probability by the context, in log: ±0.7 is a factor of 0.50 to 2.0.
    var cap: Double
    /// A « maybe » zone (`FoodModelZone.isTentative`) informs the others this much (a sure zone: 1).
    var tentativeWeight: Double
    private var scores: [String: [String: Double]]

    init(alpha: Double, cap: Double, tentativeWeight: Double, pairs: [(String, String, Double)]) {
        self.alpha = alpha
        self.cap = cap
        self.tentativeWeight = tentativeWeight
        var scores: [String: [String: Double]] = [:]
        for (a, b, s) in pairs where a != b && s.isFinite {
            scores[a, default: [:]][b] = s
            scores[b, default: [:]][a] = s
        }
        self.scores = scores
    }

    /// The association of two foods (by key: a food identifier or a `mfr:` label). Two zones of the same food do not
    /// strengthen each other: a plate rarely shows the same food twice as two zones.
    func score(_ a: String, _ b: String) -> Double {
        a == b ? 0 : scores[a]?[b] ?? 0
    }

    var isEmpty: Bool { scores.isEmpty }

    // MARK: File

    private struct File: Decodable {
        struct Parameters: Decodable {
            let alpha: Double
            let cap: Double
            let tentative_weight: Double
        }
        let parameters: Parameters
        let keys: [String]
        /// [index of a, index of b, S × 1000].
        let pairs: [[Int]]
    }

    /// The table written by `meal_context.py build` (`ArdaneFoodPairs.json`). Nil when the data does not fit.
    init?(data: Data) {
        guard let file = try? JSONDecoder().decode(File.self, from: data) else { return nil }
        var pairs: [(String, String, Double)] = []
        pairs.reserveCapacity(file.pairs.count)
        for triple in file.pairs {
            guard triple.count == 3, file.keys.indices.contains(triple[0]), file.keys.indices.contains(triple[1]) else { return nil }
            pairs.append((file.keys[triple[0]], file.keys[triple[1]], Double(triple[2]) / 1000))
        }
        self.init(
            alpha: file.parameters.alpha, cap: file.parameters.cap, tentativeWeight: file.parameters.tentative_weight, pairs: pairs
        )
    }

    static let resourceName = "ArdaneFoodPairs"

    /// The table of the app, read once. Nil where the file is absent (the widget extension): the scanner then reads each
    /// zone alone, as before.
    static let bundled: MealContextTable? = {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return MealContextTable(data: data)
    }()
}

/// One zone of the photo as the context sees it: the foods its classifier proposes (most likely first) and whether the
/// segmenter was unsure there was a food.
struct MealContextZone: Sendable {
    var candidates: [(key: String, probability: Double)]
    var isTentative: Bool

    init(candidates: [(key: String, probability: Double)], isTentative: Bool) {
        self.candidates = candidates
        self.isTentative = isTentative
    }
}

enum ScannerMealContext {
    /// The candidates of every zone after the context of the others (same order as `zones`). A zone alone on its photo, or
    /// an empty table, is returned unchanged. Each zone keeps exactly its own foods, the most likely first (a tie keeps the
    /// order of the classifier), and its total probability.
    static func reranked(_ zones: [MealContextZone], table: MealContextTable) -> [[(key: String, probability: Double)]] {
        guard zones.count > 1, !table.isEmpty, table.alpha > 0 else { return zones.map(\.candidates) }
        return zones.indices.map { index in
            let zone = zones[index]
            let mass = zone.candidates.reduce(0) { $0 + $1.probability }
            guard mass.isFinite, mass > 0 else { return zone.candidates }
            var boosted: [Double] = []
            for candidate in zone.candidates {
                var support = 0.0
                for other in zones.indices where other != index {
                    let weight = zones[other].isTentative ? table.tentativeWeight : 1
                    var expected = 0.0
                    for neighbour in zones[other].candidates where neighbour.probability.isFinite {
                        expected += neighbour.probability * table.score(candidate.key, neighbour.key)
                    }
                    support += weight * expected
                }
                let factor = exp(min(table.cap, max(-table.cap, table.alpha * support)))
                boosted.append(candidate.probability.isFinite ? candidate.probability * factor : 0)
            }
            let total = boosted.reduce(0, +)
            guard total.isFinite, total > 0 else { return zone.candidates }
            var ranked: [(key: String, probability: Double, position: Int)] = []
            for (position, candidate) in zone.candidates.enumerated() {
                var probability = boosted[position] / total * mass
                // Never added on its own because of the context: only the image can make a food sure enough.
                if candidate.probability < ScanRecap.autoAddThreshold, probability >= ScanRecap.autoAddThreshold {
                    probability = ScanRecap.autoAddThreshold - 0.001
                }
                ranked.append((candidate.key, probability, position))
            }
            ranked.sort { $0.probability != $1.probability ? $0.probability > $1.probability : $0.position < $1.position }
            return ranked.map { (key: $0.key, probability: $0.probability) }
        }
    }
}
