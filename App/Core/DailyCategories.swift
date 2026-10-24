import Foundation

/// « Mon Quotidien » as the person chooses it: any mini-app can be added. A mini-app with its own
/// card (Nutrition, the session, classes, budget, the agenda…) shows that card; the others show a
/// card with one figure from their data, or an invitation to fill them in. Nothing is made up.
@MainActor
enum DailyCategories {
    /// The mini-apps that can be put in Mon Quotidien (the weather and the photos stay out of it).
    static var choices: [MiniApp] { MiniApp.allCases.filter { $0 != .weather && $0 != .photos } }

    /// The cards of Mon Quotidien that already stand for a mini-app.
    static func cardIDs(_ app: MiniApp) -> [String] {
        switch app {
        case .nutrition: ["nutrition"]
        case .fitness: ["workout"]
        case .planning: ["planning", "priorities", "reminders", "habits"]
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
        // « Productivité » added by the person: the Top 3 card with its quick add, even with no task yet.
        var productivity: [DailyBrief.Tile] = []
        if added.contains(productivityKey) && !ids.contains("priorities") {
            productivity = [.priorities(DailyBrief.priorityChecks(model.productivity, now: now))]
        }
        let invites = tiles.filter { if case .invite = $0 { true } else { false } }
        let cards = tiles.filter { tile in !invites.contains(tile) }
        return cards + extra + productivity + invites
    }

    /// The cards of Mon Quotidien before what the person hid or ordered: the cards with data (always), and
    /// an empty dotted card for each category they chose without data yet (see `wanted` and
    /// `DailyBrief.completing`). A category neither chosen nor filled is not here: the « + » at the bottom
    /// of Home offers it. Whatever is hidden or ordered is applied afterwards (`DailyBrief.arranged`), by
    /// the same ids, so a removed category stays removed whether it is empty or filled.
    static func home(model: AppModel, now: Date, steps: Int?) -> [DailyBrief.Tile] {
        let input = DailyBrief.Input(model: model, now: now, steps: steps)
        let brief = DailyBrief.tiles(input)
        // Only the Productivité quick add still adds a card by hand: the mini-apps are all there already.
        let quick = model.settings.dailyAdded.filter { $0 == productivityKey }
        let base = adding(quick, to: brief, model: model, now: now)
        var captions: [DailyBrief.Category: String] = [:]
        for category in DailyBrief.Category.allCases {
            if let app = category.app, let caption = MiniAppSummary.caption(app, model, now: now) { captions[category] = caption }
        }
        return DailyBrief.completing(base, weather: input.weather, appCaptions: captions,
                                     empty: wanted(input: input, settings: model.settings))
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
        if entry == productivityKey { return .priorities }
        if entry.hasPrefix(categoryPrefix) { return DailyBrief.Category(rawValue: String(entry.dropFirst(categoryPrefix.count))) }
        return MiniApp(rawValue: entry).flatMap { DailyBrief.Category(app: $0) }
    }

    /// The categories shown even without data: the interests chosen in the first form (no cap), the weather
    /// when it was one of them, and the categories added by hand, in the default order. A category the
    /// person removed is left out of the display later (`DailyBrief.arranged`), whatever it holds.
    static func wanted(input: DailyBrief.Input, settings: AppSettings) -> [DailyBrief.Category] {
        var chosen = Set(input.interests.compactMap(DailyBrief.Category.init(space:)))
        if input.interestedInWeather { chosen.insert(.weather) }
        chosen.formUnion(added(settings))
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

    /// Reserved entry of `dailyAdded` for the Productivité card (not a mini-app: ignored when reading the mini-apps).
    static let productivityKey = "quick-productivity"

    /// Whether the Productivité entry is on: it was added and its card isn't hidden.
    static func isProductivityShown(settings: AppSettings) -> Bool {
        settings.dailyAdded.contains(productivityKey) && !settings.dailyHidden.contains("priorities")
    }

    /// Adds the Productivité card (back if it was hidden), or takes it off Mon Quotidien. Taken off, the Top 3
    /// card is always hidden for real: it is never missing any more (an empty dotted card is its default), so
    /// without this the switch would read off while the empty card stayed. `hasTasks` is kept for callers
    /// but no longer changes the result.
    static func setProductivity(shown: Bool, hasTasks: Bool, in settings: inout AppSettings) {
        if shown {
            if !settings.dailyAdded.contains(productivityKey) { settings.dailyAdded.append(productivityKey) }
            settings.dailyHidden.removeAll { $0 == "priorities" }
        } else {
            settings.dailyAdded.removeAll { $0 == productivityKey }
            if !settings.dailyHidden.contains("priorities") { settings.dailyHidden.append("priorities") }
        }
    }

    /// The cards a mini-app owns. While « Productivité » is added, the Top 3 belongs to it, not to Planning:
    /// turning one on or off doesn't move the other.
    private static func ownCardIDs(_ app: MiniApp, settings: AppSettings) -> [String] {
        let ids = cardIDs(app)
        guard app == .planning, settings.dailyAdded.contains(productivityKey) else { return ids }
        return ids.filter { $0 != "priorities" }
    }

    /// Whether the mini-app is on Mon Quotidien: one of its cards shows and isn't hidden, or it was added.
    static func isShown(_ app: MiniApp, available: [DailyBrief.Tile], settings: AppSettings) -> Bool {
        let shown = available.map(\.id).filter { !settings.dailyHidden.contains($0) }
        return shown.contains("app-\(app.rawValue)") || ownCardIDs(app, settings: settings).contains(where: shown.contains)
            || settings.dailyAdded.contains(app.rawValue)
    }

    /// Adds the mini-app (its cards come back if they were hidden), or takes it off Mon Quotidien.
    static func set(_ app: MiniApp, shown: Bool, in settings: inout AppSettings) {
        let ids = ownCardIDs(app, settings: settings) + ["app-\(app.rawValue)"]
        if shown {
            if !settings.dailyAdded.contains(app.rawValue) { settings.dailyAdded.append(app.rawValue) }
            settings.dailyHidden.removeAll { ids.contains($0) }
        } else {
            settings.dailyAdded.removeAll { $0 == app.rawValue }
            for id in ids where !settings.dailyHidden.contains(id) { settings.dailyHidden.append(id) }
        }
    }
}
