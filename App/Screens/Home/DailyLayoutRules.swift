import Foundation

/// The rules of the edit mode of « Mon Quotidien » (the Home screen way: long press, drag, + and −),
/// as pure functions so they are tested without any screen. Nothing here is saved by itself: the
/// results go to `AppSettings.dailyOrder` and `dailyWide`, the same settings as the layout editor.
enum DailyLayoutRules {
    /// The two sizes of a card: half of the width (two side by side) or the full width.
    enum Size: Equatable {
        case half, wide
    }

    /// The sizes a card accepts. Every card of Mon Quotidien accepts both, except an invitation
    /// (always across the dashboard, after the cards).
    static func allowedSizes(for tile: DailyBrief.Tile) -> [Size] {
        if case .invite = tile { return [.wide] }
        return [.half, .wide]
    }

    /// The size on screen: the person's choice, else the card's own.
    static func size(of tile: DailyBrief.Tile, wide: [String: Bool]) -> Size {
        (wide[tile.id] ?? tile.isWide) ? .wide : .half
    }

    /// A « + » for a card at half width that can be wider.
    static func canGrow(_ tile: DailyBrief.Tile, wide: [String: Bool]) -> Bool {
        size(of: tile, wide: wide) == .half && allowedSizes(for: tile).contains(.wide)
    }

    /// A « − » for a wide card that can be narrower.
    static func canShrink(_ tile: DailyBrief.Tile, wide: [String: Bool]) -> Bool {
        size(of: tile, wide: wide) == .wide && allowedSizes(for: tile).contains(.half)
    }

    /// The `dailyWide` after the card changed size (unchanged when the size is not allowed).
    static func resized(_ wide: [String: Bool], tile: DailyBrief.Tile, to size: Size) -> [String: Bool] {
        guard allowedSizes(for: tile).contains(size) else { return wide }
        var result = wide
        result[tile.id] = (size == .wide)
        return result
    }

    /// An invitation stays last: only the real cards are moved by hand.
    static func isMovable(_ tile: DailyBrief.Tile) -> Bool {
        if case .invite = tile { return false }
        return true
    }

    /// Can the card at `id` move by `delta` ranks (-1 before, +1 after) among the ids?
    static func canMove(_ ids: [String], id: String, by delta: Int) -> Bool {
        guard let index = ids.firstIndex(of: id) else { return false }
        return ids.indices.contains(index + delta)
    }

    /// The ids with `id` moved by `delta` ranks, stopped at the ends (unknown id: unchanged).
    static func moved(_ ids: [String], id: String, by delta: Int) -> [String] {
        guard let index = ids.firstIndex(of: id) else { return ids }
        let target = min(max(0, index + delta), ids.count - 1)
        guard target != index else { return ids }
        var result = ids
        result.remove(at: index)
        result.insert(id, at: target)
        return result
    }

    /// The ids with `id` put at the rank `target` currently has (the card dragged onto another one takes
    /// its place and the others shift). Unknown ids or the same id: unchanged.
    static func moved(_ ids: [String], id: String, onto target: String) -> [String] {
        guard id != target, let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return ids }
        var result = ids
        result.remove(at: from)
        result.insert(id, at: to)
        return result
    }

    /// The id whose frame holds the point (the card under the finger), leaving out the one dragged.
    static func target(at point: CGPoint, frames: [String: CGRect], excluding dragged: String) -> String? {
        frames.first { $0.key != dragged && $0.value.contains(point) }?.key
    }

    /// The rows of a dashboard from the width of each card (true: across), as indices: a wide card alone,
    /// the others two by two. Same pairing as `DailyBrief.rows`.
    static func rows(wides: [Bool]) -> [[Int]] {
        var rows: [[Int]] = []
        var waiting: Int?
        for (index, wide) in wides.enumerated() {
            if wide {
                rows.append([index])
            } else if let first = waiting {
                rows.append([first, index])
                waiting = nil
            } else {
                waiting = index
            }
        }
        if let waiting { rows.append([waiting]) }
        return rows
    }

    /// The cards sorted by `ids` while a drag is going (nil: as they are). A card not in `ids` goes last,
    /// in its own order.
    static func ordered(_ tiles: [DailyBrief.Tile], by ids: [String]?) -> [DailyBrief.Tile] {
        guard let ids else { return tiles }
        return tiles.enumerated().sorted { lhs, rhs in
            let l = ids.firstIndex(of: lhs.element.id) ?? ids.count + lhs.offset
            let r = ids.firstIndex(of: rhs.element.id) ?? ids.count + rhs.offset
            return l < r
        }.map(\.element)
    }
}
