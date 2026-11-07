import Foundation

extension KeyedDecodingContainer {
    /// Decodes a value if present and valid, otherwise returns the fallback.
    /// Keeps saved data readable when fields are added in later versions.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    /// Arrays: when the list does not decode as a whole, it is read element by element. An element that
    /// can't be read is skipped and reported (`LossyDecoding`) instead of emptying the whole list, which
    /// the next save would then write over the file.
    func value<E: Decodable>(_ key: Key, _ fallback: [E]) -> [E] {
        do {
            return try decodeIfPresent([E].self, forKey: key) ?? fallback
        } catch {}
        guard var list = try? nestedUnkeyedContainer(forKey: key) else {
            // Present but not a list at all: unreadable data, reported like a lost element.
            if contains(key), (try? decodeNil(forKey: key)) != true { LossyDecoding.noteLoss() }
            return fallback
        }
        var elements: [E] = []
        while !list.isAtEnd {
            if let element = try? list.decode(E.self) {
                elements.append(element)
            } else {
                LossyDecoding.noteLoss()
                // A failed element is not consumed: skip it with a value that accepts anything.
                if (try? list.decode(SkippedValue.self)) == nil { break }
            }
        }
        return elements
    }

    func optional<T: Decodable>(_ key: Key) -> T? {
        try? decodeIfPresent(T.self, forKey: key)
    }
}

/// Accepts any JSON value, to move past an element that can't be decoded.
private struct SkippedValue: Decodable {
    init(from decoder: Decoder) throws {}
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
