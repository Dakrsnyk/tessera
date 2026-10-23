import SwiftUI
import VisionKit

/// What a sheet of the Nutrition mini-app opens: the food search (for a meal), the scanner, « Mes infos »
/// (the daily needs, calculated).
enum NutritionSheet: Identifiable {
    case search(MealType?, Date)
    case scan(Date)
    case goals

    var id: String {
        switch self {
        case let .search(meal, day): "search-\(meal?.rawValue ?? "any")-\(DateMath.dayKey(day))"
        case let .scan(day): "scan-\(DateMath.dayKey(day))"
        case .goals: "goals"
        }
    }
}

/// The Nutrition mini-app: the day at a glance (calories, macros, meals), one main action (add a
/// food), then everything else one tap away (meals, nutrients, ideas, history, saved meals, goals).
struct NutritionAppView: View {
    @Environment(AppModel.self) private var model
    @State private var day: Date
    @State private var sheet: NutritionSheet?

    init(day: Date = Date()) {
        _day = State(initialValue: day)
    }

    private var isToday: Bool { DateMath.isSameDay(day, Date()) }
    private var accentHex: String { MiniApp.nutrition.colorHex }

    var body: some View {
        let state = model.nutrition
        let known = NutritionTiles.Targets(model.profile)
        let totals = NutritionMath.totals(state, on: day)
        let entries = NutritionMath.entries(state, on: day)
        MiniAppScaffold(colorHex: accentHex) {
            // The band: the week selector (the only day picker of the screen), then the essential figure of the
            // chosen day, calories left and macros, straight on the band.
            WeekSelector(day: $day, colorHex: accentHex, allowsFuture: false, mark: { weekMark($0, state: state, known: known) })
            CalorieHero(totals: totals, goals: state.goals, known: known, accentHex: accentHex)
        } sheet: {
            // The sheet, by importance: the two actions, the meals, the idea of the moment, the week's
            // calories, history and saved meals, the note, the settings last.
            MiniAppToFillSection(app: .nutrition)
            actions
            meals(entries: entries)
            nutrientsRow(totals: totals)
            if isToday { insight(state: state, known: known, totals: totals, hasEntries: !entries.isEmpty) }
            weekTrend(state: state, known: known)
            more(state: state, known: known)
            MiniFootnote(text: tr("Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL)."))
            MiniAppInfoSection(app: .nutrition)
        }
        .navigationTitle(tr("Nutrition"))
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .search(meal, day): FoodSearchView(presetMeal: meal, day: day)
            case let .scan(day): FoodSearchView(startsWithScanner: true, day: day)
            case .goals: MiniAppInfoSheet(app: .nutrition)
            }
        }
    }

    // MARK: Main action

    private var canScan: Bool { DataScannerViewController.isSupported }

    private var actions: some View {
        HStack(spacing: 10) {
            if canScan {
                MiniActionButton(title: tr("Scanner"), symbol: "barcode.viewfinder", colorHex: accentHex) {
                    sheet = .scan(day)
                }
                .accessibilityIdentifier("nutrition-scan")
            }
            MiniActionButton(title: canScan ? tr("Rechercher") : tr("Ajouter un aliment"), symbol: canScan ? "magnifyingglass" : "plus", colorHex: accentHex, isProminent: !canScan) {
                sheet = .search(nil, day)
            }
            .accessibilityIdentifier("nutrition-search")
        }
    }

    // MARK: Meals

    private func meals(entries: [FoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Repas"))
            MiniRowsCard {
                ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, meal in
                    let items = entries.filter { $0.meal == meal }
                    let kcal = items.reduce(0) { $0 + $1.totals.kcal }
                    HStack(spacing: 0) {
                        NavigationLink(value: HomeRoute.page(.nutritionMeal(meal, day))) {
                            MealRow(
                                symbol: meal.symbol, colorHex: accentHex, title: meal.title,
                                detail: items.isEmpty ? tr("Rien noté") : Fmt.plural(items.count, tr("aliment"), tr("aliments")),
                                value: items.isEmpty ? nil : tr("\(TF.int(kcal)) kcal")
                            )
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("meal-\(meal.rawValue)")
                        // A discreet « + » beside the row: adds a food straight to this meal.
                        Button {
                            sheet = .search(meal, day)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                                .foregroundStyle(Color(hex: accentHex).opacity(0.85))
                                .frame(width: 40, height: 44)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(Text(tr("Ajouter au \(meal.title.lowercased())")))
                    }
                    if index < MealType.allCases.count - 1 { MiniDivider() }
                }
            }
        }
    }

    // MARK: Nutrients

    /// The fibres and the way to every nutrient, moved off the band into the sheet (the figures are Premium).
    private func nutrientsRow(totals: NutritionTotals) -> some View {
        let sugars = totals.sugars.map { tr(" · sucres \(TF.int($0)) g") } ?? ""
        let sodium = totals.sodiumMg.map { tr(" · sodium \(TF.int($0)) mg") } ?? ""
        let fibres = tr("Fibres \(TF.int(totals.fiber)) g\(sugars)\(sodium)")
        let detail: String? = model.isPremium ? fibres : nil
        return MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.nutritionNutrients(day))) {
                HStack(spacing: 8) {
                    MiniRow(
                        symbol: "leaf.fill", colorHex: accentHex, title: tr("Tous les nutriments"),
                        detail: detail,
                        showsChevron: false
                    )
                    if !model.isPremium { PremiumBadge(compact: true) }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("nutrition-nutrients")
        }
    }

    // MARK: Idea of the moment

    @ViewBuilder
    private func insight(state: NutritionState, known: NutritionTiles.Targets, totals: NutritionTotals, hasEntries: Bool) -> some View {
        if !known.kcal {
            Button {
                sheet = .goals
            } label: {
                insightCard(symbol: "target", title: tr("Calcule tes besoins du jour"), message: tr("Ton âge, ta taille, ton poids et ton objectif suffisent : Ardane calcule tes calories et tes nutriments, puis te dit ce qu'il te reste."), action: tr("Calculer"))
            }
            .buttonStyle(.pressable)
        } else if hasEntries {
            let left = state.goals.kcal - totals.kcal
            // The figures (left, over, macros) are in the hero above: the card only says what to do.
            if left > 150 {
                NavigationLink(value: HomeRoute.page(.nutritionIdeas)) {
                    insightCard(
                        symbol: "lightbulb.fill",
                        title: tr("Des idées pour la suite de ta journée"),
                        message: nil,
                        action: tr("Voir des idées")
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-insight")
            } else if left < -50 {
                insightCard(symbol: "info.circle.fill", title: tr("Objectif dépassé"), message: tr("Rien de grave : c'est la moyenne sur plusieurs jours qui compte. L'historique te la montre."), action: nil)
            } else {
                insightCard(symbol: "checkmark.seal.fill", title: tr("Objectif atteint"), message: tr("Tu es dans ta cible de calories aujourd'hui."), action: nil)
            }
        }
    }

    private func insightCard(symbol: String, title: String, message: String?, action: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color(hex: accentHex))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let action {
                    Text(action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(hex: accentHex).opacity(0.1), in: RoundedRectangle(cornerRadius: MiniStyle.cardRadius, style: .continuous))
    }

    // MARK: Trend

    /// What a day of the selector holds: nothing when no meal is noted, a ring of how far it got toward the
    /// calorie goal, a check when it is on target (within 10 %).
    private func weekMark(_ date: Date, state: NutritionState, known: NutritionTiles.Targets) -> WeekDayMark {
        guard !NutritionMath.entries(state, on: date).isEmpty else { return WeekDayMark() }
        let goal = state.goals.kcal
        let kcal = NutritionMath.totals(state, on: date).kcal
        guard known.kcal, goal > 0 else { return WeekDayMark(progress: 1) }
        return WeekDayMark(progress: kcal / goal, isDone: abs(kcal - goal) <= goal * 0.1)
    }

    /// The calories of the week of the chosen day, one bar a day (the chosen one in full color), then the
    /// average and the days on target.
    private func weekTrend(state: NutritionState, known: NutritionTiles.Targets) -> some View {
        let week = DateMath.week(containing: day)
        let stats = weekStats(state, week)
        let values = week.map { NutritionMath.totals(state, on: $0).kcal }
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Calories de la semaine"))
            VStack(alignment: .leading, spacing: 12) {
                WeekBars(values: values, days: week, goal: known.kcal ? state.goals.kcal : nil, colorHex: accentHex,
                         highlighted: week.firstIndex { DateMath.isSameDay($0, day) })
                    .frame(height: 70)
                Text(trendText(stats, known: known, empty: tr("Rien de noté cette semaine.")))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .miniCard()
        }
    }

    /// The days of the week up to today.
    private func weekStats(_ state: NutritionState, _ week: [Date]) -> NutritionMath.PeriodStats {
        let now = Date()
        let start = week.first ?? now
        let end = min(week.last ?? now, now)
        return NutritionMath.stats(state, from: start, to: max(start, end))
    }

    private func trendText(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets, empty: String) -> String {
        guard stats.trackedDays > 0 else { return empty }
        let average = tr("Moyenne \(TF.int(stats.averages.kcal)) kcal")
        guard known.kcal else { return tr("\(average) sur \(Fmt.plural(stats.trackedDays, tr("jour noté"), tr("jours notés"))).") }
        return tr("\(average) · \(Fmt.plural(stats.daysOnTarget, tr("jour"), tr("jours"))) sur \(stats.trackedDays) dans l'objectif")
    }

    // MARK: More

    private func more(state: NutritionState, known: NutritionTiles.Targets) -> some View {
        MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.nutritionHistory)) {
                MiniRow(symbol: "chart.bar.xaxis", colorHex: accentHex, title: tr("Historique"), detail: tr("Moyennes, tendances et poids"))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("nutrition-history")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.nutritionSavedMeals)) {
                MiniRow(symbol: "bookmark.fill", colorHex: accentHex, title: tr("Mes repas"), detail: tr("Des repas enregistrés, à reprendre d'une touche"), value: state.savedMeals.isEmpty ? nil : "\(state.savedMeals.count)")
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("nutrition-saved")
        }
    }
}

// MARK: - Calories and macros

/// The day at a glance, drawn straight on the colored band of the screen (no card): the calorie ring on the left
/// (calories left or over at its center), the three macros as thin gauges on the right. The fibres and the other
/// nutrients (Premium) are in the sheet. The text takes the screen's own color, so it reads on the band.
struct CalorieHero: View {
    let totals: NutritionTotals
    let goals: NutritionGoals
    let known: NutritionTiles.Targets
    let accentHex: String

    var body: some View {
        let left = goals.kcal - totals.kcal
        HStack(spacing: 20) {
            ZStack {
                RingView(progress: known.kcal ? totals.kcal / max(1, goals.kcal) : 0, lineWidth: 10, color: left < 0 && known.kcal ? Color(hex: MiniStyle.alertHex) : Color.primary, track: Color.primary.opacity(0.18))
                VStack(spacing: 0) {
                    Text(TF.int(known.kcal ? abs(left) : totals.kcal))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(known.kcal ? (left >= 0 ? tr("kcal restantes") : tr("kcal en trop")) : tr("kcal mangées"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .minimumScaleFactor(0.7)
                .padding(14)
            }
            .frame(width: 112, height: 112)
            VStack(spacing: 12) {
                MacroGauge(name: tr("Protéines"), eaten: totals.protein, goal: known.protein ? goals.protein : nil, hex: accentHex)
                MacroGauge(name: tr("Glucides"), eaten: totals.carbs, goal: known.carbs ? goals.carbs : nil, hex: accentHex)
                MacroGauge(name: tr("Lipides"), eaten: totals.fat, goal: known.fat ? goals.fat : nil, hex: accentHex)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nutrition-hero")
    }
}

/// One macro on the band: its name on the left, « eaten / goal g » on the right, a thin gauge under them.
struct MacroGauge: View {
    let name: String
    let eaten: Double
    let goal: Double?
    let hex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(goal.map { "\(TF.int(eaten)) / \(TF.int($0)) g" } ?? "\(TF.int(eaten)) g")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            BarView(progress: goal.map { eaten / max(1, $0) } ?? 0, color: Color(hex: hex), track: Color.primary.opacity(0.15), height: 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A meal row of the sheet: its icon in a tinted rounded square, the name, how much is noted, the calories and a chevron.
private struct MealRow: View {
    let symbol: String
    let colorHex: String
    let title: String
    var detail: String?
    var value: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 36, height: 36)
                .background(Color(hex: colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Seven bars (today last) with the goal as a dashed line.
struct WeekBars: View {
    let values: [Double]
    let days: [Date]
    let goal: Double?
    let colorHex: String
    /// The bar drawn in full color (the last one by default).
    var highlighted: Int?

    var body: some View {
        let top = max(values.max() ?? 0, goal ?? 0, 1)
        GeometryReader { geo in
            let height = geo.size.height - 16
            ZStack(alignment: .bottomLeading) {
                if let goal {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(height: 1)
                        .offset(y: -16 - height * goal / top)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: colorHex).opacity(index == (highlighted ?? values.count - 1) ? 1 : 0.45))
                                .frame(height: max(3, height * value / top))
                            Text(days.indices.contains(index) ? String(Fmt.weekday(days[index]).prefix(1)) : "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(height: 12)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tr("Calories de la semaine")))
    }
}
