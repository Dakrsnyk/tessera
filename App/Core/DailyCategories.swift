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

    /// Every card Mon Quotidien can show, complete from the first launch: the person's own cards, then
    /// an empty dotted card for each category without data (see `DailyBrief.completing`). Whatever
    /// is hidden or ordered is applied afterwards (`DailyBrief.arranged`), by the same ids, so a
    /// hidden category stays hidden whether it is empty or filled, and a new one shows.
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
        return DailyBrief.completing(base, weather: input.weather, appCaptions: captions)
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
