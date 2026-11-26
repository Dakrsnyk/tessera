import Foundation

/// The default layout of « Mon Quotidien », the same for everyone (PDG, 2026-11-17): Nutrition, Fitness,
/// Planning, Habitudes, À ne pas oublier (all across the width), then the other cards at half width. The order is
/// fixed: it no longer follows the hour. Whatever the person arranged by hand is applied over it.
enum DailyDefaults {
    /// Bumped when the default layout changes: the settings of an older version are moved to it once.
    static let layoutVersion = 2

    /// The default order of the categories (every category appears once).
    static let order: [DailyBrief.Category] = [
        .nutrition, .workout, .planning, .habits, .reminders,
        .studies, .budget, .steps, .business, .travel
    ]

    /// The categories present for everyone, even without data (an empty card as wide as the filled one).
    static let alwaysPresent: Set<DailyBrief.Category> = [.nutrition, .workout, .planning, .habits, .reminders]

    /// The categories across the width by default (« moyen » and « grand »: the two are the same width here, the
    /// Planning card draws the week's table on it); the others are half width.
    static let wide: Set<DailyBrief.Category> = [.nutrition, .workout, .planning, .habits, .reminders]

    /// Moves the settings to the current default layout, once: the order and the sizes chosen before are
    /// dropped (the new default replaces them); the cards removed, the categories added and the pages
    /// chosen on the cards are kept. Returns whether anything was written; a second call changes nothing.
    @discardableResult
    static func migrate(_ settings: inout AppSettings) -> Bool {
        guard settings.dailyLayoutVersion < layoutVersion else { return false }
        if settings.dailyLayoutVersion < 1 {
            settings.dailyOrder = []
            settings.dailyWide = [:]
        }
        if settings.dailyLayoutVersion < 2 {
            // Top 3 and Auto removed (PDG, 2026-11-25): « À ne pas oublier » (the person's tasks) takes the
            // place, the size and the hidden state of the Top 3; the order chosen by hand is kept.
            let topHidden = settings.dailyHidden.contains("priorities")
            settings.dailyHidden.removeAll { ["reminders", "priorities", "app-car"].contains($0) }
            if topHidden { settings.dailyHidden.append("reminders") }
            settings.dailyOrder.removeAll { $0 == "reminders" || $0 == "app-car" }
            settings.dailyOrder = settings.dailyOrder.map { $0 == "priorities" ? "reminders" : $0 }
            let topWide = settings.dailyWide.removeValue(forKey: "priorities")
            settings.dailyWide.removeValue(forKey: "reminders")
            settings.dailyWide.removeValue(forKey: "app-car")
            if let topWide { settings.dailyWide["reminders"] = topWide }
            settings.dailyAdded.removeAll { $0 == "car" || $0 == "cat-car" || $0 == "cat-priorities" }
            settings.dailyAdded = settings.dailyAdded.map { $0 == DailyCategories.productivityKey ? "cat-reminders" : $0 }
        }
        settings.dailyLayoutVersion = layoutVersion
        return true
    }
}

extension AppModel {
    /// Applies `DailyDefaults.migrate` through the usual way of saving the settings (once per install).
    func migrateDailyLayout() {
        migrateTopThree()
        guard settings.dailyLayoutVersion < DailyDefaults.layoutVersion else { return }
        updateSettings { _ = DailyDefaults.migrate(&$0) }
    }

    /// The Top 3 is gone (PDG, 2026-11-25): what was in it becomes tasks (done ones stay done). Emptied
    /// afterwards, so a second launch moves nothing.
    func migrateTopThree() {
        let old = productivity.priorities
        guard !old.isEmpty else { return }
        updateContent { content in
            for item in old where !content.tasks.contains(where: { $0.id == item.id }) {
                content.tasks.append(TaskItem(id: item.id, title: item.title, isDone: item.isCompleted, createdAt: item.createdAt ?? Date(), completedAt: item.completedAt))
            }
        }
        update(\.productivity) { $0.priorities = [] }
    }
}
