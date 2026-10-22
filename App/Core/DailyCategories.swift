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

    /// Reserved entry of `dailyAdded` for the Productivité card (not a mini-app: ignored when reading the mini-apps).
    static let productivityKey = "quick-productivity"

    /// Whether the Productivité entry is on: it was added and its card isn't hidden.
    static func isProductivityShown(settings: AppSettings) -> Bool {
        settings.dailyAdded.contains(productivityKey) && !settings.dailyHidden.contains("priorities")
    }

    /// Adds the Productivité card (back if it was hidden), or takes it off Mon Quotidien. Taken off, the
    /// settings go back to what they were: the Top 3 is hidden for real only if it would still show
    /// without the entry (`hasTasks`), so a Top 3 filled later in Planning isn't hidden without a word.
    static func setProductivity(shown: Bool, hasTasks: Bool, in settings: inout AppSettings) {
        if shown {
            if !settings.dailyAdded.contains(productivityKey) { settings.dailyAdded.append(productivityKey) }
            settings.dailyHidden.removeAll { $0 == "priorities" }
        } else {
            settings.dailyAdded.removeAll { $0 == productivityKey }
            if hasTasks, !settings.dailyHidden.contains("priorities") { settings.dailyHidden.append("priorities") }
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
