import Foundation

/// « Mon Quotidien » as the person chooses it: any mini-app can be added. A mini-app with its own
/// card (Nutrition, the session, classes, budget, the agenda…) shows that card; the others show a
/// card with one figure from their data, or an invitation to fill them in. Nothing is made up.
@MainActor
enum DailyCategories {
    /// The mini-apps that can be put in Mon Quotidien (the weather stays out of it).
    static var choices: [MiniApp] { MiniApp.allCases.filter { $0 != .weather } }

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
        let invites = tiles.filter { if case .invite = $0 { true } else { false } }
        let cards = tiles.filter { tile in !invites.contains(tile) }
        return cards + extra + invites
    }

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
