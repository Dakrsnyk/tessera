import SwiftUI
import WidgetKit

extension AppModel {
    /// Whether the user has entered anything in a space yet (otherwise its widgets show example data).
    func hasData(in space: Space) -> Bool {
        switch space {
        case .productivity: !content.tasks.isEmpty || !productivity.priorities.isEmpty || !productivity.projects.isEmpty
        case .habits: !content.habits.isEmpty
        case .nutrition: !nutrition.entries.isEmpty
        case .fitness: !fitness.routines.isEmpty
        case .budget: !budget.expenses.isEmpty
        case .investing: !portfolio.holdings.isEmpty
        case .business: !business.sales.isEmpty
        case .markets: !companies.isEmpty
        case .student: !student.courses.isEmpty
        case .travel: !travel.trips.isEmpty
        case .car: !car.fills.isEmpty
        case .life: life.birthday != nil
        }
    }
}

struct SpaceExample {
    let design: WidgetDesign
    let family: WidgetFamily
}

enum SpaceCatalog {
    /// A widget of a kind as the space creator and the Créer tab start it: its template, named, on the theme's look.
    static func design(for kind: WidgetKind) -> WidgetDesign {
        var design = TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind)
        design.name = kind.title
        design.background = .theme
        design.font = .theme
        return design
    }

    /// The small widget Créer opens on: the first free one among the interests' spaces (in order), else
    /// the calories left. Without Premium, its look is made free too.
    static func proposal(for spaces: [Space], isPremium: Bool) -> WidgetDesign {
        let kind = spaces.compactMap { preset(for: $0, format: .small).first }.first { !$0.isPremium } ?? .caloriesLeft
        var proposed = Self.design(for: kind)
        proposed.format = .small
        return isPremium ? proposed : proposed.downgradedForFree()
    }

    /// What the space creator selects first for each size: the key widget in small, two widgets that
    /// complete each other in medium, a dashboard of the space in large (one of them takes a whole row).
    static func preset(for space: Space, format: WidgetFormat) -> [WidgetKind] {
        let pair: (medium: [WidgetKind], large: [WidgetKind])
        switch space {
        case .productivity: pair = ([.tasks, .deadline], [.tasks, .deadline, .project])
        case .habits: pair = ([.habitStreak, .habits], [.habitStreak, .habitRate, .habits])
        case .nutrition: pair = ([.caloriesLeft, .macros], [.caloriesLeft, .macros, .mealsToday])
        case .fitness: pair = ([.todaysWorkout, .trainingStreak], [.todaysWorkout, .trainingStreak, .nextSet])
        case .budget: pair = ([.budgetLeft, .savingsGoal], [.budgetLeft, .savingsGoal, .spendingByCategory])
        case .investing: pair = ([.portfolio, .allocation], [.allocation, .topMover, .portfolio])
        case .business: pair = ([.revenueToday, .revenueGoal], [.revenueToday, .revenueGoal, .revenueTrend])
        case .markets: pair = ([.companySnapshot, .companyStock], [.companySnapshot, .companyStock, .companyRevenue])
        case .student: pair = ([.nextClass, .nextExam], [.nextClass, .nextExam, .timetable])
        case .travel: pair = ([.tripCountdown, .localTime], [.tripCountdown, .localTime, .flight])
        case .car: pair = ([.nextService, .mileage], [.nextService, .mileage, .carCost])
        case .life: pair = ([.birthday, .holiday], [.birthday, .holiday, .ageProgress])
        }
        let available = kinds(in: space)
        switch format {
        case .small:
            let small = available.filter { $0.families.contains(.systemSmall) }
            return [small.first(where: { !$0.isPremium }) ?? small.first ?? available.first ?? .note]
        case .medium: return pair.medium.filter { available.contains($0) }
        case .large: return pair.large.filter { available.contains($0) }
        }
    }

    /// A few widgets of a space, small and medium, shown in the list of spaces.
    static func examples(for space: Space) -> [SpaceExample] {
        let picks: [(WidgetKind, WidgetFamily)]
        switch space {
        case .productivity: picks = [(.deadline, .systemSmall), (.tasks, .systemMedium)]
        case .habits: picks = [(.habits, .systemMedium), (.habitStreak, .systemSmall)]
        case .nutrition: picks = [(.caloriesLeft, .systemSmall), (.macros, .systemSmall), (.nextMeal, .systemSmall)]
        case .fitness: picks = [(.todaysWorkout, .systemMedium), (.trainingStreak, .systemSmall)]
        case .budget: picks = [(.budgetLeft, .systemSmall), (.spendingByCategory, .systemMedium)]
        case .investing: picks = [(.portfolio, .systemMedium), (.allocation, .systemSmall)]
        case .business: picks = [(.revenueToday, .systemSmall), (.revenueGoal, .systemSmall), (.mrr, .systemSmall)]
        case .markets: picks = [(.companySnapshot, .systemSmall), (.companyCompare, .systemMedium)]
        case .student: picks = [(.nextClass, .systemSmall), (.timetable, .systemMedium)]
        case .travel: picks = [(.flight, .systemMedium), (.tripCountdown, .systemSmall)]
        case .car: picks = [(.nextService, .systemSmall), (.carCost, .systemMedium)]
        case .life: picks = [(.birthday, .systemSmall), (.ageProgress, .systemSmall), (.holiday, .systemSmall)]
        }
        return picks.map { kind, family in
            SpaceExample(design: TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind), family: family)
        }
    }


    /// The widgets fed by a space.
    static func kinds(in space: Space) -> [WidgetKind] {
        var kinds = WidgetKind.offered.filter { $0.space == space }
        switch space {
        case .life: kinds += [.birthday, .ageProgress, .holiday].filter { !kinds.contains($0) }
        case .productivity: kinds += [.aiProductivity].filter { !kinds.contains($0) }
        default: break
        }
        return kinds
    }
}

// MARK: - Départ de Créer

extension SpaceCatalog {
    /// The medium widget « Pour toi » offers for a space: what the space creator selects first at that size,
    /// built the way it builds it (`Composer`, one `ComboPart` per widget), on the look of the space's first
    /// widget. Without Premium its look is made free too. When the pair doesn't fit, the space's small widget.
    static func startDesign(for space: Space, isPremium: Bool) -> WidgetDesign {
        let first = preset(for: space, format: .small).first ?? .note
        let base = Self.design(for: first)
        var result: WidgetDesign
        switch Composer.plan(preset(for: space, format: .medium), format: .medium) {
        case let .single(kind):
            result = Self.design(for: kind)
            result.themeID = base.themeID
            result.accentHex = base.accentHex
            result.format = .medium
        case let .combo(slots):
            var options = DesignOptions()
            options.parts = slots.map { slot in
                let part = Self.design(for: slot.kind)
                return ComboPart(kind: slot.kind, options: part.options, name: part.name, size: slot.size)
            }
            result = WidgetDesign(
                name: slots.map { Self.design(for: $0.kind).name }.joined(separator: " + "),
                kind: slots[0].kind, themeID: base.themeID, accentHex: base.accentHex,
                options: options, format: .medium
            )
        case .invalid:
            result = base
            result.format = .small
        }
        return isPremium ? result : result.downgradedForFree()
    }
}
