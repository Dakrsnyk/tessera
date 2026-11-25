import Foundation

/// « Mon Quotidien » as the person chooses it: any mini-app can be added. A mini-app with its own
/// card (Nutrition, the session, classes, budget, the agenda…) shows that card; the others show a
/// card with one figure from their data, or an invitation to fill them in. Nothing is made up.
@MainActor
enum DailyCategories {
    /// The mini-apps that can be put in Mon Quotidien (the photos stay out of it; Auto is removed).
    static var choices: [MiniApp] { MiniApp.offered.filter { $0 != .photos } }

    /// Cards of removed features (Top 3, Auto): never shown.
    /// Old settings may still name them (order, sizes, hidden): `DailyDefaults.migrate` moves them once.
    static let removedTileIDs: Set<String> = ["priorities", "app-car"]

    /// The cards of Mon Quotidien that already stand for a mini-app.
    static func cardIDs(_ app: MiniApp) -> [String] {
        switch app {
        case .nutrition: ["nutrition"]
        case .fitness: ["workout"]
        case .planning: ["planning", "reminders", "habits"]
        case .finances: ["budget"]
        default: []
        }
    }

    /// The cards of the brief, plus a card for each mini-app added that has none on screen.
    static func adding(_ added: [String], to tiles: [DailyBrief.Tile], model: AppModel, now: Date) -> [DailyBrief.Tile] {
        let ids = Set(tiles.map(\.id))
        let extra = added.compactMap(MiniApp.init(rawValue:)).filter { app in
            choices.contains(app) && !cardIDs(app).contains(where: ids.contains)
        }
        .map { DailyBrief.Tile.miniApp($0.rawValue, caption: MiniAppSummary.caption($0, model, now: now)) }
        let invites = tiles.filter { if case .invite = $0 { true } else { false } }
        let cards = tiles.filter { tile in !invites.contains(tile) }
        return cards + extra + invites
    }

    /// The cards of Mon Quotidien before what the person hid or ordered: the cards with data (always), and
    /// an empty dotted card for each category they chose without data yet (see `wanted` and
    /// `DailyBrief.completing`). A category neither chosen nor filled is not here: the « + » at the bottom
    /// of Home offers it. Whatever is hidden or ordered is applied afterwards (`DailyBrief.arranged`), by
    /// the same ids, so a removed category stays removed whether it is empty or filled.
    static func home(model: AppModel, now: Date, steps: Int?) -> [DailyBrief.Tile] {
        let input = DailyBrief.Input(model: model, now: now, steps: steps)
        let brief = DailyBrief.tiles(input)
        var captions: [DailyBrief.Category: String] = [:]
        for category in DailyBrief.Category.allCases {
            if let app = category.app, let caption = MiniAppSummary.caption(app, model, now: now) { captions[category] = caption }
        }
        let tiles = DailyBrief.completing(brief, appCaptions: captions,
                                          empty: wanted(input: input, settings: model.settings))
        // Top 3 and Auto are gone (PDG, 2026-11-25): never a card of theirs, whatever an old setting says.
        let kept = tiles.filter { !Self.removedTileIDs.contains($0.id) }
        return DailyBrief.inDefaultOrder(withWeekSchedule(kept))
    }

    /// The week's schedule shows for everyone, Planning chosen at the start or not (PDG, 2026-11-16): without
    /// anything planned, the Planning card is the week table itself (not a dotted invitation). Always exactly one
    /// Planning card (an empty one is replaced); its place is the default order's. Removed by the person, it
    /// stays off (`DailyBrief.arranged`).
    static func withWeekSchedule(_ tiles: [DailyBrief.Tile]) -> [DailyBrief.Tile] {
        var tiles = tiles.filter { tile in
            if case .empty(.planning) = tile { return false }
            return true
        }
        guard !tiles.contains(where: { $0.id == DailyBrief.Category.planning.tileID }) else { return tiles }
        let after = tiles.lastIndex { $0.id == "nutrition" || $0.id == "workout" }.map { $0 + 1 } ?? 0
        tiles.insert(.planning(items: []), at: min(after, tiles.count))
        return tiles
    }

    // MARK: Which categories show

    /// Entry of `dailyAdded` for a category added with the « + » of Home (`cat-` and its name).
    static let categoryPrefix = "cat-"

    static func addedKey(_ category: DailyBrief.Category) -> String { categoryPrefix + category.rawValue }

    /// The categories the person added: with the « + » (`cat-…`), or before it existed (a mini-app
    /// added from the editor, the Productivité quick add). Unknown entries are ignored.
    static func added(_ settings: AppSettings) -> Set<DailyBrief.Category> {
        Set(settings.dailyAdded.compactMap(category(ofEntry:)))
    }

    /// The category a `dailyAdded` entry stands for, in any of its forms (nil for an unknown entry).
    static func category(ofEntry entry: String) -> DailyBrief.Category? {
        if entry == productivityKey { return .reminders }
        if entry.hasPrefix(categoryPrefix) { return DailyBrief.Category(rawValue: String(entry.dropFirst(categoryPrefix.count))) }
        return MiniApp(rawValue: entry).flatMap { DailyBrief.Category(app: $0) }
    }

    /// The categories shown even without data: the five of every account (`DailyDefaults.alwaysPresent`), the
    /// interests chosen in the first form (no cap) and the categories added by hand, in the default order. A category the
    /// person removed is left out of the display later (`DailyBrief.arranged`), whatever it holds.
    static func wanted(input: DailyBrief.Input, settings: AppSettings) -> [DailyBrief.Category] {
        var chosen = Set(input.interests.compactMap(DailyBrief.Category.init(space:)))
        chosen.formUnion(added(settings))
        // Present for everyone, even empty (PDG, 2026-11-17); the classes of a student make Études a card too.
        chosen.formUnion(DailyDefaults.alwaysPresent)
        if !input.student.courses.isEmpty { chosen.insert(.studies) }
        return DailyBrief.Category.defaultOrder.filter(chosen.contains)
    }

    /// The categories missing from Mon Quotidien (never chosen, or removed): what the « + » offers. `shown`
    /// are the cards on screen, hidden ones already left out. Empty once everything is there.
    static func addable(shown: [DailyBrief.Tile]) -> [DailyBrief.Category] {
        let ids = Set(shown.map(\.id))
        return DailyBrief.Category.defaultOrder.filter { !ids.contains($0.tileID) }
    }

    /// Puts the category on Mon Quotidien (empty if nothing is filled): remembered as added, and no longer hidden.
    static func add(_ category: DailyBrief.Category, in settings: inout AppSettings) {
        let key = addedKey(category)
        if !settings.dailyAdded.contains(key) { settings.dailyAdded.append(key) }
        settings.dailyHidden.removeAll { $0 == category.tileID }
    }

    /// Takes the card off Mon Quotidien: it stays off even when it receives data, and goes back to the list of
    /// the « + ». Nothing is deleted from the mini-app. `tileID` is the id of the card.
    static func remove(tileID: String, in settings: inout AppSettings) {
        if !settings.dailyHidden.contains(tileID) { settings.dailyHidden.append(tileID) }
        // Every form of the entry that stands for this category (`cat-…`, an old mini-app, the Productivité
        // quick add), so that no door brings it back.
        if let category = DailyBrief.Category(tileID: tileID) {
            settings.dailyAdded.removeAll { Self.category(ofEntry: $0) == category }
        }
    }

    /// Old entry of `dailyAdded` (the removed Productivité quick add): it stands for « À ne pas oublier ».
    static let productivityKey = "quick-productivity"

    /// Whether the mini-app is on Mon Quotidien: one of its cards shows and isn't hidden, or it was added.
    static func isShown(_ app: MiniApp, available: [DailyBrief.Tile], settings: AppSettings) -> Bool {
        let shown = available.map(\.id).filter { !settings.dailyHidden.contains($0) }
        return shown.contains("app-\(app.rawValue)") || cardIDs(app).contains(where: shown.contains)
            || settings.dailyAdded.contains(app.rawValue)
    }

    /// Adds the mini-app (its cards come back if they were hidden), or takes it off Mon Quotidien.
    static func set(_ app: MiniApp, shown: Bool, in settings: inout AppSettings) {
        let ids = cardIDs(app) + ["app-\(app.rawValue)"]
        if shown {
            if !settings.dailyAdded.contains(app.rawValue) { settings.dailyAdded.append(app.rawValue) }
            settings.dailyHidden.removeAll { ids.contains($0) }
        } else {
            settings.dailyAdded.removeAll { $0 == app.rawValue }
            for id in ids where !settings.dailyHidden.contains(id) { settings.dailyHidden.append(id) }
        }
    }
}
