import Foundation

extension KeyedDecodingContainer {
    /// Decodes a value if present and valid, otherwise returns the fallback.
    /// Keeps saved data readable when fields are added in later versions.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    func optional<T: Decodable>(_ key: Key) -> T? {
        try? decodeIfPresent(T.self, forKey: key)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Double {
    /// "12 %" style percentage from a ratio, or nil when not computable.
    var finiteOrNil: Double? { isFinite ? self : nil }
}

enum Stats {
    static func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    /// Relative change from `previous` to `current`, or nil when there is no base.
    static func change(from previous: Double, to current: Double) -> Double? {
        guard previous != 0 else { return nil }
        return (current - previous) / abs(previous)
    }
}
