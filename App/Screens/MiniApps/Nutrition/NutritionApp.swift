import SwiftUI
import VisionKit

/// What a sheet of the Nutrition mini-app opens: the food search (for a meal), the scanner, « Mes infos »
/// (the daily needs, calculated).
enum NutritionSheet: Identifiable {
    case search(MealType?, Date)
    case scan(Date)
    case goals
    case customFoods

    var id: String {
        switch self {
        case let .search(meal, day): "search-\(meal?.rawValue ?? "any")-\(DateMath.dayKey(day))"
        case let .scan(day): "scan-\(DateMath.dayKey(day))"
        case .goals: "goals"
        case .customFoods: "custom-foods"
        }
    }
}

/// The Nutrition mini-app, short like a day: the week, the ring (what is left, what is eaten, the three macros),
/// the card « Maintenant » (the next useful thing), the four meals, then two doors, « Bilan » and « Ma bibliothèque »,
/// and « Mes paramètres ». The two main actions float: « Scanner » and « Rechercher » (one « Ajouter un aliment »
/// without a camera).
struct NutritionAppView: View {
    @Environment(AppModel.self) private var model
    @State private var day: Date
    @State private var sheet: NutritionSheet?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }
    @Environment(\.colorScheme) private var scheme
    /// The day the screen was last active: when the app wakes on a later day and the screen showed that day, it follows.
    @State private var activeOn = Date()

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
            // The figure of the day floats on glass, like the essential figure of the other mini-apps.
            VStack(alignment: .leading, spacing: 12) {
                CalorieHero(totals: totals, goals: state.goals, known: known, accentHex: accentHex)
                if known.kcal {
                    Text(tr("\(TF.int(totals.kcal)) mangées sur \(TF.int(state.goals.kcal)) kcal"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityIdentifier("nutrition-eaten")
                }
            }
            .padding(16)
            .cristalGlass(in: RoundedRectangle(cornerRadius: palette.radius, style: .continuous))
            .tourAnchor(.nutrition, 1)
        } sheet: {
            // The sheet, by importance: the goal to set (while it is unknown), the meals, then the card « Maintenant »
            // with its meal ideas under them (PDG, 2026-11-26), the two doors, the note, the settings last.
            if !known.kcal { goalCard }
            MiniAppToFillSection(app: .nutrition)
            meals(entries: entries)
            if isToday && known.kcal { nowCard(state: state, totals: totals, known: known, hasEntries: !entries.isEmpty) }
            doors(state: state, known: known)
            MiniFootnote(text: tr("Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL)."))
            MiniAppInfoSection(app: .nutrition)
            // Room for the floating actions.
            Color.clear.frame(height: 80)
        }
        .overlay(alignment: .bottom) {
            NutritionFloatingActions(canScan: canScan, colorHex: accentHex,
                                     scan: { sheet = .scan(day) }, search: { sheet = .search(nil, day) })
                .tourAnchor(.nutrition, 0)
                .padding(.bottom, 12)
        }
        .navigationTitle(tr("Nutrition"))
        .miniAppTour(.nutrition)
        .onAppear { trackGoal(known: known) }
        .onChange(of: model.nutrition.goals.kcal) { _, _ in trackGoal(known: known) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if DateMath.isSameDay(day, activeOn), !DateMath.isSameDay(activeOn, Date()) { day = Date() }
            activeOn = Date()
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case let .search(meal, day): FoodSearchView(presetMeal: meal, day: day)
            case let .scan(day): FoodSearchView(startsWithScanner: true, day: day)
            case .goals: MiniAppInfoSheet(app: .nutrition)
            case .customFoods: CustomFoodsView()
            }
        }
    }

    /// The simulator has no camera to scan with: an ad capture launched with `-screenshotScanButtons YES` shows the
    /// page as a real iPhone does (« Scanner » and « Rechercher »). The UI tests keep the simulator's own page.
    private var canScan: Bool {
        #if DEBUG
        if ScreenshotMode.isActive && UserDefaults.standard.bool(forKey: "screenshotScanButtons") { return true }
        #endif
        return DataScannerViewController.isSupported
    }

    /// Dates the calorie goal once it is seen to change (« depuis le … » in « Bilan », Poids). Only a goal the
    /// person's own information gives is followed, never the default.
    private func trackGoal(known: NutritionTiles.Targets) {
        guard known.kcal else { return }
        let state = model.nutrition
        guard state.kcalGoalSeen == nil || abs((state.kcalGoalSeen ?? 0) - state.goals.kcal) >= 0.5 else { return }
        model.update(\.nutrition) { $0.trackGoalChange() }
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
                                .foregroundStyle(Color.accentColor)
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

    // MARK: Goal and « Maintenant »

    /// The goal to set: shown first while the person's needs are unknown; « Maintenant » stays silent then.
    private var goalCard: some View {
        Button {
            sheet = .goals
        } label: {
            insightCard(symbol: "target", title: tr("Calcule tes besoins du jour"), message: tr("Ton âge, ta taille, ton poids et ton objectif suffisent : Ardane calcule tes calories et tes nutriments, puis te dit ce qu'il te reste."), action: tr("Calculer"))
        }
        .buttonStyle(.pressable)
    }

    /// What the card says, by order: the next meal ahead (what is left, the protein of it), the ideas for the rest
    /// of the evening, a goal passed, a goal reached. The figures of the day are in the ring above.
    @ViewBuilder
    private func nowCard(state: NutritionState, totals: NutritionTotals, known: NutritionTiles.Targets, hasEntries: Bool) -> some View {
        let left = state.goals.kcal - totals.kcal
        if left > 150 {
            if let next = MealType.next() {
                let remaining = NutritionMath.remaining(state, on: day, knowsKcal: known.kcal, knowsProtein: known.protein)
                let proteinLeft = remaining.protein ?? 0
                let protein: String? = proteinLeft > 0 ? tr("dont \(TF.int(proteinLeft)) g de protéines") : nil
                NavigationLink(value: HomeRoute.page(.nutritionIdeas)) {
                    insightCard(
                        symbol: "fork.knife",
                        title: tr("Prochain repas : \(next.title.lowercased()), environ \(TF.int(left)) kcal"),
                        message: protein,
                        action: tr("Voir des idées")
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-insight")
            } else if hasEntries {
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
            }
        } else if hasEntries {
            if left < -50 {
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
                .foregroundStyle(palette.category(accentHex))
                .frame(width: 36, height: 36)
                .background(palette.category(accentHex).opacity(scheme == .dark ? 0.20 : 0.13), in: Circle())
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
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .miniCard()
    }

    // MARK: Week mark

    /// What a day of the selector holds: nothing when no meal is noted, a ring of how far it got toward the
    /// calorie goal, a check when it is on target (within 10 %).
    private func weekMark(_ date: Date, state: NutritionState, known: NutritionTiles.Targets) -> WeekDayMark {
        guard !NutritionMath.entries(state, on: date).isEmpty else { return WeekDayMark() }
        let goal = state.goals.kcal
        let kcal = NutritionMath.totals(state, on: date).kcal
        guard known.kcal, goal > 0 else { return WeekDayMark(progress: 1) }
        return WeekDayMark(progress: kcal / goal, isDone: abs(kcal - goal) <= goal * 0.1)
    }

    // MARK: Doors

    /// « Bilan » (the week, the nutrients, the weight) and « Ma bibliothèque » (favorites, saved meals, own foods).
    private func doors(state: NutritionState, known: NutritionTiles.Targets) -> some View {
        let stats = NutritionWeekCard.stats(state, DateMath.week(containing: day))
        let reviewDetail = reviewText(stats, known: known)
        let savedText = Fmt.plural(state.savedMeals.count, tr("repas", context: "one"), tr("repas"))
        let foodsText = Fmt.plural(state.customFoods.count, tr("aliment"), tr("aliments"))
        let favoritesText = Fmt.plural(state.favorites.count, tr("favori"), tr("favoris"))
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Aller plus loin"))
            MiniRowsCard {
                NavigationLink(value: HomeRoute.page(.nutritionReview(day))) {
                    MiniRow(symbol: "chart.bar.xaxis", colorHex: accentHex, title: tr("Bilan"), detail: reviewDetail)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-review")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.nutritionLibrary)) {
                    MiniRow(symbol: "books.vertical.fill", colorHex: accentHex, title: tr("Ma bibliothèque"), detail: "\(savedText) · \(foodsText) · \(favoritesText)")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-library")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.nutritionIdeas)) {
                    MiniRow(symbol: "lightbulb.fill", colorHex: accentHex, title: tr("Idées"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-ideas-row")
            }
        }
    }

    private func reviewText(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets) -> String {
        guard stats.trackedDays > 0 else { return tr("Calories, nutriments et poids") }
        guard known.kcal else { return tr("Moyenne \(TF.int(stats.averages.kcal)) kcal") }
        return tr("Cette semaine : \(Fmt.plural(stats.daysOnTarget, tr("jour"), tr("jours"))) sur \(stats.trackedDays) dans l'objectif")
    }
}

/// The two main actions, floating above the tab bar: « Scanner » (filled) and « Rechercher » (glass). Without a
/// camera, one filled « Ajouter un aliment ». A double tap runs an action once.
private struct NutritionFloatingActions: View {
    let canScan: Bool
    let colorHex: String
    let scan: () -> Void
    let search: () -> Void
    @State private var tapGuard = TapGuard()
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strong = CristalPalette.of(style.id).strongHex(colorHex)
        let hex = scheme == .dark ? strong.dark : strong.light
        HStack(spacing: 10) {
            if canScan {
                Button {
                    tapGuard.run(scan)
                } label: {
                    Label(tr("Scanner"), systemImage: "barcode.viewfinder")
                        .font(.headline)
                        .foregroundStyle(Color.readableInk(on: hex))
                        .padding(.horizontal, 22)
                        .frame(minHeight: 50)
                        .background(Color(hex: hex), in: Capsule())
                        .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-scan")
                Button {
                    tapGuard.run(search)
                } label: {
                    Label(tr("Rechercher"), systemImage: "magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 50)
                        .cristalGlass(in: Capsule())
                        .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-search")
            } else {
                Button {
                    tapGuard.run(search)
                } label: {
                    Label(tr("Ajouter un aliment"), systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(Color.readableInk(on: hex))
                        .padding(.horizontal, 24)
                        .frame(minHeight: 50)
                        .background(Color(hex: hex), in: Capsule())
                        .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("nutrition-search")
            }
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
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let left = goals.kcal - totals.kcal
        HStack(spacing: 20) {
            ZStack {
                RingView(progress: known.kcal ? totals.kcal / max(1, goals.kcal) : 0, lineWidth: 10, color: left < 0 && known.kcal ? palette.category(MiniStyle.alertHex) : palette.category(NutritionColors.caloriesHex), track: NutritionColors.track)
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
                MacroGauge(name: tr("Protéines"), eaten: totals.protein, goal: known.protein ? goals.protein : nil, hex: NutritionColors.proteinHex, incomplete: totals.isIncomplete)
                MacroGauge(name: tr("Glucides"), eaten: totals.carbs, goal: known.carbs ? goals.carbs : nil, hex: NutritionColors.carbsHex, incomplete: totals.isIncomplete)
                MacroGauge(name: tr("Lipides"), eaten: totals.fat, goal: known.fat ? goals.fat : nil, hex: NutritionColors.fatHex, incomplete: totals.isIncomplete)
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
    /// True when a food of the total lacks this macro: the figure is a minimum, shown with « ≥ ».
    var incomplete = false
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text((incomplete ? NutritionTotals.minimumMarker : "") + (goal.map { "\(TF.int(eaten)) / \(TF.int($0)) g" } ?? "\(TF.int(eaten)) g"))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            BarView(progress: goal.map { eaten / max(1, $0) } ?? 0, color: palette.category(hex), track: NutritionColors.track, height: 4)
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
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.category(colorHex))
                .frame(width: 36, height: 36)
                .background(palette.category(colorHex).opacity(scheme == .dark ? 0.20 : 0.13), in: Circle())
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
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

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
                                .fill(palette.category(colorHex).opacity(index == (highlighted ?? values.count - 1) ? 1 : 0.45))
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
