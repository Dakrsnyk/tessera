import Foundation

// A soft context for the food scanner (chantier 22.3): among the foods the models already propose for a zone, the ones the
// person logged more often in the last 60 days weigh a little more. It never adds a food, and without history it changes
// nothing. Pure logic; Foundation only (this folder is also compiled in the widget extension).

struct ScannerContextPriors: Hashable, Sendable {
    /// Only the foods logged during this many days count.
    static let windowDays = 60
    /// p'(f) ∝ p(f) × (1 + strength × ln(1 + n_f)). Réglage initial, non mesuré.
    static let strength = 0.15

    /// How many times each food (by identifier) was logged in the window.
    var counts: [String: Int]

    init(counts: [String: Int] = [:]) {
        self.counts = counts
    }

    /// The counts of the foods logged in the `windowDays` days before `now`.
    init(entries: [(foodID: String, date: Date)], now: Date) {
        let start = now.addingTimeInterval(-Double(Self.windowDays) * 86_400)
        var counts: [String: Int] = [:]
        for entry in entries where entry.date >= start && !entry.foodID.isEmpty {
            counts[entry.foodID, default: 0] += 1
        }
        self.counts = counts
    }

    var isEmpty: Bool { counts.isEmpty }

    func weight(of key: String) -> Double {
        let n = counts[key] ?? 0
        return n > 0 ? 1 + Self.strength * log(1 + Double(n)) : 1
    }

    /// The candidates with their probabilities reweighted by the frequency of each food, then scaled back so that their total
    /// stays what it was (the confidence of a zone keeps its meaning). Only the candidates given are returned, the most
    /// likely first (a tie keeps the order given). Unchanged when no candidate was ever logged.
    func reweighted(_ candidates: [(key: String, probability: Double)]) -> [(key: String, probability: Double)] {
        guard !counts.isEmpty, candidates.contains(where: { (counts[$0.key] ?? 0) > 0 }) else { return candidates }
        let mass = candidates.reduce(0) { $0 + $1.probability }
        let weighted = candidates.reduce(0) { $0 + $1.probability * weight(of: $1.key) }
        guard mass.isFinite, weighted.isFinite, mass > 0, weighted > 0 else { return candidates }
        var ranked: [(key: String, probability: Double, position: Int)] = []
        for (position, candidate) in candidates.enumerated() {
            ranked.append((candidate.key, candidate.probability * weight(of: candidate.key) / weighted * mass, position))
        }
        ranked.sort { $0.probability != $1.probability ? $0.probability > $1.probability : $0.position < $1.position }
        return ranked.map { (key: $0.key, probability: $0.probability) }
    }
}
