import Foundation

enum NutritionTiles {
    static let hint = tr("Note ton premier repas dans Tessera, espace Nutrition.")

    /// Nutrition widgets that open the scanner from their medium and large sizes.
    static let scanKinds: Set<WidgetKind> = [.caloriesLeft, .macros, .proteinLeft, .mealsToday, .nextMeal, .nutritionWeek, .nutritionStreak]

    /// Which daily targets the user actually gave (« Mes informations »). The others are never shown as theirs.
    struct Targets {
        var kcal: Bool
        var protein: Bool
        var carbs: Bool
        var fat: Bool

        init(_ domains: DomainData) {
            kcal = domains.knows(.kcalTarget)
            protein = domains.knows(.proteinTarget)
            carbs = domains.knows(.carbsTarget)
            fat = domains.knows(.fatTarget)
        }

        init(_ profile: UserProfile) {
            kcal = profile.knows(.kcalTarget)
            protein = profile.knows(.proteinTarget)
            carbs = profile.knows(.carbsTarget)
            fat = profile.knows(.fatTarget)
        }

        init(all: Bool) {
            kcal = all
            protein = all
            carbs = all
            fat = all
        }
    }

    static let targetHint = tr("Objectif à définir dans Tessera")

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.nutrition
        let known = Targets(context.payload.domains)
        var tile: Tile
        switch context.design.kind {
        case .caloriesLeft: tile = caloriesLeft(state, now: now, known: known)
        case .macros: tile = macros(state, now: now, compact: context.isSmall, known: known)
        case .proteinLeft: tile = proteinLeft(state, now: now, known: known.protein)
        case .mealsToday: tile = mealsToday(state, now: now)
        case .nutritionWeek: tile = week(state, now: now, knowsGoal: known.kcal)
        case .nutritionStreak: tile = streak(state, now: now)
        case .quickFood: tile = quickFood(state, now: now)
        case .nextMeal: tile = known.kcal ? nextMeal(state, now: now) : .empty(tr("Prochain repas"), symbol: "clock.badge.checkmark", message: tr("Donne ton objectif calorique dans Tessera pour savoir ce qu'il te reste par repas."))
        default: tile = TileFactory.placeholder(context.design.kind)
        }
        // Adding a food in two taps: the widget opens the app right on the camera.
        if scanKinds.contains(context.design.kind) {
            tile.headerButton = TileButton(title: tr("Scanner"), symbol: "barcode.viewfinder", action: .scanFood)
        }
        return tile
    }

    /// `compact` drops the unit so the macro names stay readable in small widgets. A macro without a target
    /// shows what was eaten, with no bar.
    static func macroRows(_ totals: NutritionTotals, goals: NutritionGoals, compact: Bool = false, known: Targets = Targets(all: true)) -> [TileRow] {
        func value(_ eaten: Double, _ goal: Double, _ knowsGoal: Bool) -> String {
            guard knowsGoal else { return compact ? TF.int(eaten) : "\(TF.int(eaten)) g" }
            return compact ? "\(TF.int(eaten))/\(TF.int(goal))" : "\(TF.int(eaten)) / \(TF.int(goal)) g"
        }
        func progress(_ eaten: Double, _ goal: Double, _ knowsGoal: Bool) -> Double? {
            knowsGoal ? eaten / max(1, goal) : nil
        }
        return [
            TileRow(id: "p", title: tr("Protéines"), value: value(totals.protein, goals.protein, known.protein), colorHex: "E5484D", progress: progress(totals.protein, goals.protein, known.protein)),
            TileRow(id: "c", title: tr("Glucides"), value: value(totals.carbs, goals.carbs, known.carbs), colorHex: "F2A33A", progress: progress(totals.carbs, goals.carbs, known.carbs)),
            TileRow(id: "f", title: tr("Lipides"), value: value(totals.fat, goals.fat, known.fat), colorHex: "3366FF", progress: progress(totals.fat, goals.fat, known.fat)),
        ]
    }

    static func caloriesLeft(_ state: NutritionState, now: Date, known: Targets = Targets(all: true)) -> Tile {
        let totals = NutritionMath.totals(state, on: now)
        guard known.kcal else {
            // No target given: what was eaten, never a remainder computed from a made-up goal.
            var tile = Tile(title: tr("Calories"), symbol: "flame")
            tile.value = TF.int(totals.kcal)
            tile.unit = "kcal"
            tile.caption = tr("mangées aujourd'hui")
            tile.detail = targetHint
            tile.rows = macroRows(totals, goals: state.goals, known: known)
            tile.shortValue = TF.int(totals.kcal)
            tile.inline = tr("\(TF.int(totals.kcal)) kcal aujourd'hui")
            return tile
        }
        let goal = max(1, state.goals.kcal)
        let left = goal - totals.kcal
        var tile = Tile(title: tr("Calories"), symbol: "flame")
        tile.value = TF.int(abs(left))
        tile.unit = "kcal"
        tile.caption = left >= 0 ? tr("restantes sur \(TF.int(goal))") : tr("au-dessus de l'objectif")
        tile.trend = left >= 0 ? nil : false
        tile.detail = tr("Mangé : \(TF.int(totals.kcal)) kcal")
        tile.visual = .ring(totals.kcal / goal)
        tile.rows = macroRows(totals, goals: state.goals, known: known)
        tile.gauge = totals.kcal / goal
        tile.shortValue = TF.int(left)
        tile.inline = left >= 0 ? tr("\(TF.int(left)) kcal restantes") : tr("+\(TF.int(-left)) kcal")
        return tile
    }

    static func macros(_ state: NutritionState, now: Date, compact: Bool, known: Targets = Targets(all: true)) -> Tile {
        let totals = NutritionMath.totals(state, on: now)
        var tile = Tile(title: tr("Macros"), symbol: "chart.bar.xaxis")
        tile.value = TF.int(totals.kcal)
        tile.unit = "kcal"
        tile.caption = known.kcal ? tr("sur \(TF.int(state.goals.kcal)) · fibres \(TF.int(totals.fiber)) g") : tr("aujourd'hui · fibres \(TF.int(totals.fiber)) g")
        tile.rows = macroRows(totals, goals: state.goals, compact: compact, known: known)
        tile.compactRows = true
        tile.visual = .segments([
            TileSegment(label: tr("Protéines"), value: totals.protein * 4, colorHex: "E5484D"),
            TileSegment(label: tr("Glucides"), value: totals.carbs * 4, colorHex: "F2A33A"),
            TileSegment(label: tr("Lipides"), value: totals.fat * 9, colorHex: "3366FF"),
        ])
        tile.inline = "P \(TF.int(totals.protein)) · G \(TF.int(totals.carbs)) · L \(TF.int(totals.fat))"
        return tile
    }

    static func proteinLeft(_ state: NutritionState, now: Date, known: Bool = true) -> Tile {
        let totals = NutritionMath.totals(state, on: now)
        guard known else {
            var tile = Tile(title: tr("Protéines"), symbol: "bolt.heart")
            tile.value = TF.int(totals.protein)
            tile.unit = "g"
            tile.caption = tr("mangées aujourd'hui")
            tile.detail = targetHint
            tile.shortValue = TF.int(totals.protein)
            tile.inline = tr("\(TF.int(totals.protein)) g de protéines aujourd'hui")
            return tile
        }
        let goal = max(1, state.goals.protein)
        let left = max(0, goal - totals.protein)
        var tile = Tile(title: tr("Protéines"), symbol: "bolt.heart")
        tile.value = TF.int(left)
        tile.unit = "g"
        tile.caption = left == 0 ? tr("Objectif atteint") : tr("à trouver sur \(TF.int(goal)) g")
        tile.visual = .ring(totals.protein / goal)
        tile.gauge = totals.protein / goal
        tile.shortValue = TF.int(left)
        tile.inline = tr("\(TF.int(left)) g de protéines restantes")
        return tile
    }

    static func mealsToday(_ state: NutritionState, now: Date) -> Tile {
        let entries = NutritionMath.entries(state, on: now)
        let totals = NutritionMath.totals(state, on: now)
        var tile = Tile(title: tr("Repas du jour"), symbol: "list.bullet.rectangle")
        tile.value = TF.int(totals.kcal)
        tile.unit = "kcal"
        tile.caption = entries.isEmpty ? tr("Rien de noté pour l'instant") : Fmt.plural(entries.count, tr("aliment noté"), tr("aliments notés"))
        tile.rows = MealType.allCases.map { meal -> TileRow in
            let items = entries.filter { $0.meal == meal }
            let kcal = items.reduce(0) { $0 + $1.totals.kcal }
            let names = items.map(\.food.name).joined(separator: ", ")
            return TileRow(id: meal.rawValue, title: meal.title, value: items.isEmpty ? "—" : tr("\(TF.int(kcal)) kcal"), detail: names.isEmpty ? nil : names, symbol: meal.symbol, isHighlighted: meal == MealType.current(at: now))
        }
        tile.compactRows = true
        tile.inline = tr("\(TF.int(totals.kcal)) kcal aujourd'hui")
        return tile
    }

    static func week(_ state: NutritionState, now: Date, knowsGoal: Bool = true) -> Tile {
        let days = NutritionMath.dailyCalories(state, days: 7, until: now)
        guard days.contains(where: { $0 > 0 }) else { return .empty(tr("Semaine nutrition"), symbol: "chart.bar", message: hint) }
        var tile = Tile(title: tr("7 derniers jours"), symbol: "chart.bar")
        let average = NutritionMath.average(state, days: 7, until: now) ?? 0
        tile.value = TF.int(average)
        tile.unit = "kcal/j"
        tile.caption = knowsGoal ? tr("moyenne · objectif \(TF.int(state.goals.kcal))") : tr("moyenne par jour")
        if let month = NutritionMath.average(state, days: 30, until: now) {
            tile.detail = tr("Sur 30 jours : \(TF.int(month)) kcal/j")
        }
        let labels = (0..<7).map { offset -> String in
            let date = DateMath.calendar.date(byAdding: .day, value: offset - 6, to: now) ?? now
            return String(Fmt.format(date, template: "EEEEE").prefix(1)).uppercased()
        }
        tile.visual = .bars(days, labels: labels, highlight: 6)
        tile.inline = tr("Moyenne \(TF.int(average)) kcal")
        return tile
    }

    static func streak(_ state: NutritionState, now: Date) -> Tile {
        let streak = NutritionMath.trackingStreak(state, until: now)
        let keys = Set(state.entries.map { DateMath.dayKey($0.date) })
        var tile = Tile(title: tr("Série de suivi"), symbol: "flame.fill")
        tile.value = Fmt.number(streak)
        tile.unit = TF.days(streak)
        tile.caption = keys.contains(DateMath.dayKey(now)) ? tr("repas noté aujourd'hui") : tr("note un repas pour continuer")
        tile.visual = .week(DateMath.week(containing: now).map { day -> Bool? in
            day > now && !DateMath.isSameDay(day, now) ? nil : keys.contains(DateMath.dayKey(day))
        })
        tile.gauge = min(1, Double(streak) / 30)
        tile.shortValue = Fmt.number(streak)
        tile.inline = tr("Suivi : \(Fmt.plural(streak, tr("jour"), tr("jours")))")
        return tile
    }

    static func quickFood(_ state: NutritionState, now: Date) -> Tile {
        let foods = Array((state.favorites.isEmpty ? state.recentFoods : state.favorites).prefix(3))
        guard !foods.isEmpty else {
            return .empty(tr("Ajout rapide"), symbol: "plus.app", message: tr("Ajoute des favoris dans Tessera, espace Nutrition."))
        }
        let totals = NutritionMath.totals(state, on: now)
        var tile = Tile(title: tr("Ajout rapide"), symbol: "plus.app")
        tile.value = TF.int(totals.kcal)
        tile.unit = "kcal"
        tile.caption = tr("aujourd'hui · touche pour ajouter")
        tile.buttons = foods.map { food in
            TileButton(title: TF.shortName(food.name, words: 1), symbol: "plus", action: .logFood(food.id))
        }
        tile.rows = foods.map { food -> TileRow in
            let serving = food.nutrients(grams: food.servingGrams)
            return TileRow(id: food.id, title: food.name, value: tr("\(TF.int(serving.kcal)) kcal"), detail: food.servingName, symbol: "plus.circle.fill", action: .logFood(food.id))
        }
        return tile
    }

    static func nextMeal(_ state: NutritionState, now: Date) -> Tile {
        var tile = Tile(title: tr("Prochain repas"), symbol: "clock.badge.checkmark")
        if let budget = NutritionMath.nextMealBudget(state, at: now) {
            tile.value = TF.int(budget.kcal)
            tile.unit = "kcal"
            tile.caption = tr("pour le \(budget.meal.title.lowercased())")
            tile.detail = tr("dont \(TF.int(budget.protein)) g de protéines")
            tile.symbol = budget.meal.symbol
            tile.inline = tr("\(budget.meal.title) : \(TF.int(budget.kcal)) kcal")
        } else {
            let left = max(0, state.goals.kcal - NutritionMath.totals(state, on: now).kcal)
            tile.value = TF.int(left)
            tile.unit = "kcal"
            tile.caption = tr("restantes pour la soirée")
            tile.inline = tr("\(TF.int(left)) kcal restantes")
        }
        return tile
    }
}
