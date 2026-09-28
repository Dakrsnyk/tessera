import Foundation

enum NutritionTiles {
    static let hint = "Note ton premier repas dans Tessera, espace Nutrition."

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.nutrition
        switch context.design.kind {
        case .caloriesLeft: return caloriesLeft(state, now: now)
        case .macros: return macros(state, now: now, compact: context.isSmall)
        case .proteinLeft: return proteinLeft(state, now: now)
        case .mealsToday: return mealsToday(state, now: now)
        case .nutritionWeek: return week(state, now: now)
        case .nutritionStreak: return streak(state, now: now)
        case .quickFood: return quickFood(state, now: now)
        case .nextMeal: return nextMeal(state, now: now)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    /// `compact` drops the unit so the macro names stay readable in small widgets.
    static func macroRows(_ totals: NutritionTotals, goals: NutritionGoals, compact: Bool = false) -> [TileRow] {
        func value(_ eaten: Double, _ goal: Double) -> String {
            compact ? "\(TF.int(eaten))/\(TF.int(goal))" : "\(TF.int(eaten)) / \(TF.int(goal)) g"
        }
        return [
            TileRow(id: "p", title: "Protéines", value: value(totals.protein, goals.protein), colorHex: "E5484D", progress: totals.protein / max(1, goals.protein)),
            TileRow(id: "c", title: "Glucides", value: value(totals.carbs, goals.carbs), colorHex: "F2A33A", progress: totals.carbs / max(1, goals.carbs)),
            TileRow(id: "f", title: "Lipides", value: value(totals.fat, goals.fat), colorHex: "3366FF", progress: totals.fat / max(1, goals.fat)),
        ]
    }

    static func caloriesLeft(_ state: NutritionState, now: Date) -> Tile {
        let totals = NutritionMath.totals(state, on: now)
        let goal = max(1, state.goals.kcal)
        let left = goal - totals.kcal
        var tile = Tile(title: "Calories", symbol: "flame")
        tile.value = TF.int(abs(left))
        tile.unit = "kcal"
        tile.caption = left >= 0 ? "restantes sur \(TF.int(goal))" : "au-dessus de l'objectif"
        tile.trend = left >= 0 ? nil : false
        tile.detail = "Mangé : \(TF.int(totals.kcal)) kcal"
        tile.visual = .ring(totals.kcal / goal)
        tile.rows = macroRows(totals, goals: state.goals)
        tile.gauge = totals.kcal / goal
        tile.shortValue = TF.int(left)
        tile.inline = left >= 0 ? "\(TF.int(left)) kcal restantes" : "+\(TF.int(-left)) kcal"
        return tile
    }

    static func macros(_ state: NutritionState, now: Date, compact: Bool) -> Tile {
        let totals = NutritionMath.totals(state, on: now)
        var tile = Tile(title: "Macros", symbol: "chart.bar.xaxis")
        tile.value = TF.int(totals.kcal)
        tile.unit = "kcal"
        tile.caption = "sur \(TF.int(state.goals.kcal)) · fibres \(TF.int(totals.fiber)) g"
        tile.rows = macroRows(totals, goals: state.goals, compact: compact)
        tile.compactRows = true
        tile.visual = .segments([
            TileSegment(label: "Protéines", value: totals.protein * 4, colorHex: "E5484D"),
            TileSegment(label: "Glucides", value: totals.carbs * 4, colorHex: "F2A33A"),
            TileSegment(label: "Lipides", value: totals.fat * 9, colorHex: "3366FF"),
        ])
        tile.inline = "P \(TF.int(totals.protein)) · G \(TF.int(totals.carbs)) · L \(TF.int(totals.fat))"
        return tile
    }

    static func proteinLeft(_ state: NutritionState, now: Date) -> Tile {
        let totals = NutritionMath.totals(state, on: now)
        let goal = max(1, state.goals.protein)
        let left = max(0, goal - totals.protein)
        var tile = Tile(title: "Protéines", symbol: "bolt.heart")
        tile.value = TF.int(left)
        tile.unit = "g"
        tile.caption = left == 0 ? "Objectif atteint" : "à trouver sur \(TF.int(goal)) g"
        tile.visual = .ring(totals.protein / goal)
        tile.gauge = totals.protein / goal
        tile.shortValue = TF.int(left)
        tile.inline = "\(TF.int(left)) g de protéines restantes"
        return tile
    }

    static func mealsToday(_ state: NutritionState, now: Date) -> Tile {
        let entries = NutritionMath.entries(state, on: now)
        let totals = NutritionMath.totals(state, on: now)
        var tile = Tile(title: "Repas du jour", symbol: "list.bullet.rectangle")
        tile.value = TF.int(totals.kcal)
        tile.unit = "kcal"
        tile.caption = entries.isEmpty ? "Rien de noté pour l'instant" : Fmt.plural(entries.count, "aliment noté", "aliments notés")
        tile.rows = MealType.allCases.map { meal -> TileRow in
            let items = entries.filter { $0.meal == meal }
            let kcal = items.reduce(0) { $0 + $1.totals.kcal }
            let names = items.map(\.food.name).joined(separator: ", ")
            return TileRow(id: meal.rawValue, title: meal.title, value: items.isEmpty ? "—" : "\(TF.int(kcal)) kcal", detail: names.isEmpty ? nil : names, symbol: meal.symbol, isHighlighted: meal == MealType.current(at: now))
        }
        tile.compactRows = true
        tile.inline = "\(TF.int(totals.kcal)) kcal aujourd'hui"
        return tile
    }

    static func week(_ state: NutritionState, now: Date) -> Tile {
        let days = NutritionMath.dailyCalories(state, days: 7, until: now)
        guard days.contains(where: { $0 > 0 }) else { return .empty("Semaine nutrition", symbol: "chart.bar", message: hint) }
        var tile = Tile(title: "7 derniers jours", symbol: "chart.bar")
        let average = NutritionMath.average(state, days: 7, until: now) ?? 0
        tile.value = TF.int(average)
        tile.unit = "kcal/j"
        tile.caption = "moyenne · objectif \(TF.int(state.goals.kcal))"
        if let month = NutritionMath.average(state, days: 30, until: now) {
            tile.detail = "Sur 30 jours : \(TF.int(month)) kcal/j"
        }
        let labels = (0..<7).map { offset -> String in
            let date = DateMath.calendar.date(byAdding: .day, value: offset - 6, to: now) ?? now
            return String(Fmt.format(date, template: "EEEEE").prefix(1)).uppercased()
        }
        tile.visual = .bars(days, labels: labels, highlight: 6)
        tile.inline = "Moyenne \(TF.int(average)) kcal"
        return tile
    }

    static func streak(_ state: NutritionState, now: Date) -> Tile {
        let streak = NutritionMath.trackingStreak(state, until: now)
        let keys = Set(state.entries.map { DateMath.dayKey($0.date) })
        var tile = Tile(title: "Série de suivi", symbol: "flame.fill")
        tile.value = Fmt.number(streak)
        tile.unit = TF.days(streak)
        tile.caption = keys.contains(DateMath.dayKey(now)) ? "repas noté aujourd'hui" : "note un repas pour continuer"
        tile.visual = .week(DateMath.week(containing: now).map { day -> Bool? in
            day > now && !DateMath.isSameDay(day, now) ? nil : keys.contains(DateMath.dayKey(day))
        })
        tile.gauge = min(1, Double(streak) / 30)
        tile.shortValue = Fmt.number(streak)
        tile.inline = "Suivi : \(Fmt.plural(streak, "jour", "jours"))"
        return tile
    }

    static func quickFood(_ state: NutritionState, now: Date) -> Tile {
        let foods = Array((state.favorites.isEmpty ? state.recentFoods : state.favorites).prefix(3))
        guard !foods.isEmpty else {
            return .empty("Ajout rapide", symbol: "plus.app", message: "Ajoute des favoris dans Tessera, espace Nutrition.")
        }
        let totals = NutritionMath.totals(state, on: now)
        var tile = Tile(title: "Ajout rapide", symbol: "plus.app")
        tile.value = TF.int(totals.kcal)
        tile.unit = "kcal"
        tile.caption = "aujourd'hui · touche pour ajouter"
        tile.buttons = foods.map { food in
            TileButton(title: TF.shortName(food.name, words: 1), symbol: "plus", action: .logFood(food.id))
        }
        tile.rows = foods.map { food -> TileRow in
            let serving = food.nutrients(grams: food.servingGrams)
            return TileRow(id: food.id, title: food.name, value: "\(TF.int(serving.kcal)) kcal", detail: food.servingName, symbol: "plus.circle.fill", action: .logFood(food.id))
        }
        return tile
    }

    static func nextMeal(_ state: NutritionState, now: Date) -> Tile {
        var tile = Tile(title: "Prochain repas", symbol: "clock.badge.checkmark")
        if let budget = NutritionMath.nextMealBudget(state, at: now) {
            tile.value = TF.int(budget.kcal)
            tile.unit = "kcal"
            tile.caption = "pour le \(budget.meal.title.lowercased())"
            tile.detail = "dont \(TF.int(budget.protein)) g de protéines"
            tile.symbol = budget.meal.symbol
            tile.inline = "\(budget.meal.title) : \(TF.int(budget.kcal)) kcal"
        } else {
            let left = max(0, state.goals.kcal - NutritionMath.totals(state, on: now).kcal)
            tile.value = TF.int(left)
            tile.unit = "kcal"
            tile.caption = "restantes pour la soirée"
            tile.inline = "\(TF.int(left)) kcal restantes"
        }
        return tile
    }
}
