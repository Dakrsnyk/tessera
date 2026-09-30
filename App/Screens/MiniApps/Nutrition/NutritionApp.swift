import SwiftUI
import VisionKit

/// What a sheet of the Nutrition mini-app opens: the food search (for a meal), the scanner, the goals.
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
        MiniAppScroll {
            DaySwitcher(day: $day, colorHex: accentHex)
            CalorieHero(totals: totals, goals: state.goals, known: known, day: day)
            actions
            meals(entries: entries)
            if isToday { insight(state: state, known: known, totals: totals, hasEntries: !entries.isEmpty) }
            if !state.entries.isEmpty { weekTrend(state: state, known: known) }
            more(state: state, known: known)
            Text("Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL).")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .search(meal, day): FoodSearchView(presetMeal: meal, day: day)
            case let .scan(day): FoodSearchView(startsWithScanner: true, day: day)
            case .goals: NutritionGoalsEditor(goals: model.nutrition.goals)
            }
        }
    }

    // MARK: Main action

    private var canScan: Bool { DataScannerViewController.isSupported }

    private var actions: some View {
        HStack(spacing: 10) {
            if canScan {
                MiniActionButton(title: "Scanner", symbol: "barcode.viewfinder", colorHex: accentHex) {
                    sheet = .scan(day)
                }
                .accessibilityIdentifier("nutrition-scan")
            }
            MiniActionButton(title: canScan ? "Rechercher" : "Ajouter un aliment", symbol: canScan ? "magnifyingglass" : "plus", colorHex: accentHex, isProminent: !canScan) {
                sheet = .search(nil, day)
            }
            .accessibilityIdentifier("nutrition-search")
        }
    }

    // MARK: Meals

    private func meals(entries: [FoodEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: "Repas", detail: entries.isEmpty ? nil : Fmt.plural(entries.count, "aliment", "aliments"))
            MiniRowsCard {
                ForEach(Array(MealType.allCases.enumerated()), id: \.element) { index, meal in
                    let items = entries.filter { $0.meal == meal }
                    let kcal = items.reduce(0) { $0 + $1.totals.kcal }
                    HStack(spacing: 0) {
                        NavigationLink(value: HomeRoute.page(.nutritionMeal(meal, day))) {
                            MiniRow(
                                symbol: meal.symbol, colorHex: accentHex, title: meal.title,
                                detail: items.isEmpty ? "Rien noté" : items.map(\.food.name).joined(separator: ", "),
                                value: items.isEmpty ? nil : "\(TF.int(kcal)) kcal"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("meal-\(meal.rawValue)")
                        Button {
                            sheet = .search(meal, day)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color(hex: accentHex))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Ajouter au \(meal.title.lowercased())"))
                    }
                    if index < MealType.allCases.count - 1 { MiniDivider() }
                }
            }
        }
    }

    // MARK: Idea of the moment

    @ViewBuilder
    private func insight(state: NutritionState, known: NutritionTiles.Targets, totals: NutritionTotals, hasEntries: Bool) -> some View {
        if !known.kcal {
            Button {
                sheet = .goals
            } label: {
                insightCard(symbol: "target", title: "Définis ton objectif du jour", message: "Avec ton objectif, Tessera te dit ce qu'il te reste et te propose des idées de repas.", action: "Définir")
            }
            .buttonStyle(.plain)
        } else if hasEntries {
            let left = state.goals.kcal - totals.kcal
            let proteinLeft = known.protein ? state.goals.protein - totals.protein : nil
            if left > 150 {
                NavigationLink(value: HomeRoute.page(.nutritionIdeas)) {
                    insightCard(
                        symbol: "lightbulb.fill",
                        title: "Il te reste environ \(TF.int(left)) kcal",
                        message: proteinLeft.map { $0 > 10 ? "Et \(TF.int($0)) g de protéines pour atteindre ton objectif." : "Tes protéines sont presque atteintes." } ?? "Des idées pour la suite de ta journée.",
                        action: "Voir des idées"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nutrition-insight")
            } else if left < -50 {
                insightCard(symbol: "info.circle.fill", title: "Objectif dépassé de \(TF.int(-left)) kcal", message: "Rien de grave : c'est la moyenne sur plusieurs jours qui compte. L'historique te la montre.", action: nil)
            } else {
                insightCard(symbol: "checkmark.seal.fill", title: "Objectif atteint", message: "Tu es dans ta cible de calories aujourd'hui.", action: nil)
            }
        }
    }

    private func insightCard(symbol: String, title: String, message: String, action: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color(hex: accentHex))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
        .background(Color(hex: accentHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Trend

    private func weekTrend(state: NutritionState, known: NutritionTiles.Targets) -> some View {
        let end = Date()
        let start = DateMath.calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let stats = NutritionMath.stats(state, from: start, to: end)
        return NavigationLink(value: HomeRoute.page(.nutritionHistory)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("7 derniers jours").font(.headline)
                    Spacer()
                    Text("Historique")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                WeekBars(values: stats.kcalPerDay, days: stats.days, goal: known.kcal ? stats.goal : nil, colorHex: accentHex)
                    .frame(height: 70)
                Text(trendText(stats, known: known))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .card()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nutrition-trend")
    }

    private func trendText(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets) -> String {
        guard stats.trackedDays > 0 else { return "Rien de noté ces 7 derniers jours." }
        let average = "Moyenne \(TF.int(stats.averages.kcal)) kcal"
        guard known.kcal else { return "\(average) sur \(Fmt.plural(stats.trackedDays, "jour noté", "jours notés"))." }
        return "\(average) · \(stats.daysOnTarget) jour\(stats.daysOnTarget > 1 ? "s" : "") sur \(stats.trackedDays) dans l'objectif"
    }

    // MARK: More

    private func more(state: NutritionState, known: NutritionTiles.Targets) -> some View {
        MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.nutritionSavedMeals)) {
                MiniRow(symbol: "bookmark.fill", colorHex: accentHex, title: "Mes repas", detail: "Des repas enregistrés, à reprendre d'une touche", value: state.savedMeals.isEmpty ? nil : "\(state.savedMeals.count)")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nutrition-saved")
            MiniDivider()
            Button {
                sheet = .goals
            } label: {
                MiniRow(symbol: "target", colorHex: accentHex, title: "Objectifs", detail: known.kcal ? "\(TF.int(state.goals.kcal)) kcal · \(TF.int(state.goals.protein)) g de protéines" : "À définir")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nutrition-goals")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.nutritionHistory)) {
                MiniRow(symbol: "chart.bar.xaxis", colorHex: accentHex, title: "Historique", detail: "Moyennes, tendances et poids")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nutrition-history")
        }
    }
}

// MARK: - Calories and macros

/// The day in one card: the calorie ring, what is eaten, left or over, then the three macros.
struct CalorieHero: View {
    let totals: NutritionTotals
    let goals: NutritionGoals
    let known: NutritionTiles.Targets
    let day: Date

    private let accent = Color(hex: MiniApp.nutrition.colorHex)

    var body: some View {
        let left = goals.kcal - totals.kcal
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    RingView(progress: known.kcal ? totals.kcal / max(1, goals.kcal) : 0, lineWidth: 14, color: left < 0 && known.kcal ? Color(hex: "E5484D") : accent, track: accent.opacity(0.15))
                    VStack(spacing: 0) {
                        Text(TF.int(known.kcal ? abs(left) : totals.kcal))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(known.kcal ? (left >= 0 ? "kcal restantes" : "kcal en trop") : "kcal mangées")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .minimumScaleFactor(0.7)
                    .padding(18)
                }
                .frame(width: 150, height: 150)
                VStack(alignment: .leading, spacing: 12) {
                    figure("Mangé", "\(TF.int(totals.kcal)) kcal")
                    if known.kcal {
                        figure("Objectif", "\(TF.int(goals.kcal)) kcal")
                        figure(left >= 0 ? "Restant" : "Dépassé", "\(TF.int(abs(left))) kcal", color: left >= 0 ? nil : Color(hex: "E5484D"))
                    } else {
                        Text("Pas encore d'objectif : ajoute-le dans Objectifs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                MacroGauge(name: "Protéines", eaten: totals.protein, goal: known.protein ? goals.protein : nil, hex: "E5484D")
                MacroGauge(name: "Glucides", eaten: totals.carbs, goal: known.carbs ? goals.carbs : nil, hex: "F2A33A")
                MacroGauge(name: "Lipides", eaten: totals.fat, goal: known.fat ? goals.fat : nil, hex: "3366FF")
            }
            NavigationLink(value: HomeRoute.page(.nutritionNutrients(day))) {
                HStack {
                    Text("Fibres \(TF.int(totals.fiber)) g\(totals.sugars.map { " · sucres \(TF.int($0)) g" } ?? "")\(totals.sodiumMg.map { " · sodium \(TF.int($0)) mg" } ?? "")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text("Tous les nutriments")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(accent)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("nutrition-nutrients")
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nutrition-hero")
    }

    private func figure(_ title: String, _ value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color ?? .primary)
                .monospacedDigit()
        }
    }
}

struct MacroGauge: View {
    let name: String
    let eaten: Double
    let goal: Double?
    let hex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(goal.map { "\(TF.int(eaten))/\(TF.int($0)) g" } ?? "\(TF.int(eaten)) g")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            BarView(progress: goal.map { eaten / max(1, $0) } ?? 0, color: Color(hex: hex), track: Color(hex: hex).opacity(0.15), height: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Seven bars (today last) with the goal as a dashed line.
struct WeekBars: View {
    let values: [Double]
    let days: [Date]
    let goal: Double?
    let colorHex: String

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
                                .fill(Color(hex: colorHex).opacity(index == values.count - 1 ? 1 : 0.45))
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
        .accessibilityLabel(Text("Calories des 7 derniers jours"))
    }
}
