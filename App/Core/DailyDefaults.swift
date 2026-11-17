import Foundation

/// The default layout of « Mon Quotidien », the same for everyone (PDG, 2026-11-17): Nutrition, Fitness,
/// Planning, Habitudes, Top 3 (all across the width), then the other cards at half width. The order is
/// fixed: it no longer follows the hour. Whatever the person arranged by hand is applied over it.
enum DailyDefaults {
    /// Bumped when the default layout changes: the settings of an older version are moved to it once.
    static let layoutVersion = 1

    /// The default order of the categories (every category appears once).
    static let order: [DailyBrief.Category] = [
        .nutrition, .workout, .planning, .habits, .priorities,
        .studies, .budget, .reminders, .steps, .business, .travel, .car
    ]

    /// The categories present for everyone, even without data (an empty card as wide as the filled one).
    static let alwaysPresent: Set<DailyBrief.Category> = [.nutrition, .workout, .planning, .habits, .priorities]

    /// The categories across the width by default (« moyen » and « grand »: the two are the same width here, the
    /// Planning card draws the week's table on it); the others are half width.
    static let wide: Set<DailyBrief.Category> = [.nutrition, .workout, .planning, .habits, .priorities]

    /// Moves the settings to the current default layout, once: the order and the sizes chosen before are
    /// dropped (the new default replaces them); the cards removed, the categories added and the pages
    /// chosen on the cards are kept. Returns whether anything was written; a second call changes nothing.
    @discardableResult
    static func migrate(_ settings: inout AppSettings) -> Bool {
        guard settings.dailyLayoutVersion < layoutVersion else { return false }
        settings.dailyOrder = []
        settings.dailyWide = [:]
        settings.dailyLayoutVersion = layoutVersion
        return true
    }
}

extension AppModel {
    /// Applies `DailyDefaults.migrate` through the usual way of saving the settings (once per install).
    func migrateDailyLayout() {
        guard settings.dailyLayoutVersion < DailyDefaults.layoutVersion else { return }
        updateSettings { _ = DailyDefaults.migrate(&$0) }
    }
}
