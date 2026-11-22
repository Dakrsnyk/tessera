import SwiftUI

/// The order of the exercises of a session: only the position changes, every item stays as it is.
enum ExerciseReorder {
    /// The items with the one at `from` put at `to` (both out of range are brought back to the nearest end;
    /// a `from` out of range changes nothing).
    static func move<T>(_ items: [T], from: Int, to: Int) -> [T] {
        guard items.indices.contains(from) else { return items }
        var result = items
        let item = result.remove(at: from)
        result.insert(item, at: min(max(to, 0), result.count))
        return result
    }
}

/// The height of every exercise of the editor (sum of its rows, by id), to know when the held exercise passes
/// its neighbour.
struct ExerciseHeightsKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: +)
    }
}

extension View {
    /// Reports the height of this row as part of the exercise `id`.
    func exerciseHeight(_ id: UUID) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: ExerciseHeightsKey.self, value: [id: proxy.size.height])
        })
    }
}
