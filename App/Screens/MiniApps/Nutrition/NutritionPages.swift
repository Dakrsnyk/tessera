import Charts
import SwiftUI

// MARK: - A meal

/// One meal of a day: its foods (quantity, move, delete), then how to fill it quickly: add a food,
/// take back an earlier meal, log a saved meal, or save this one.
struct NutritionMealPage: View {
    let meal: MealType
    let day: Date
    @Environment(AppModel.self) private var model
    @State private var editing: FoodEntry?
    @State private var searching = false
    @State private var namingSave = false
    @State private var saveName = ""
    @State private var loggedSaved: SavedMeal?
    /// The earlier meals already taken again from this page: their button is off (a double tap is one meal).
    @State private var resumedMeals: Set<String> = []
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    private var accentHex: String { MiniApp.nutrition.colorHex }

    var body: some View {
        let state = model.nutrition
        let entries = NutritionMath.entries(state, on: day).filter { $0.meal == meal }
        let totals = entries.reduce(NutritionTotals()) { $0 + $1.totals }
        let previous = NutritionMath.previousMeals(meal, state, before: day, limit: 3)
        List {
            Section {
                HStack(spacing: 0) {
                    stat(tr("Calories"), TF.int(totals.kcal), "kcal")
                    stat(tr("Protéines"), totals.marked(TF.int(totals.protein), incomplete: totals.isIncomplete), "g")
                    stat(tr("Glucides"), totals.marked(TF.int(totals.carbs), incomplete: totals.isIncomplete), "g")
                    stat(tr("Lipides"), totals.marked(TF.int(totals.fat), incomplete: totals.isIncomplete), "g")
                }
                .padding(.vertical, 6)
            } header: {
                Text(DateMath.isSameDay(day, Date()) ? tr("Aujourd'hui") : Fmt.longDay(day))
            }

            Section {
                if entries.isEmpty {
                    Text(tr("Rien de noté pour ce repas."))
                        .foregroundStyle(Color.secondary)
                }
                ForEach(entries) { entry in
                    Button {
                        editing = entry
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.food.displayName).foregroundStyle(Color.primary).lineLimit(1)
                                let line = entry.totals
                                let mark = line.isIncomplete ? NutritionTotals.minimumMarker : ""
                                Text(tr("\(TF.int(entry.grams)) g · P \(mark)\(TF.int(line.protein)) · G \(mark)\(TF.int(line.carbs)) · L \(mark)\(TF.int(line.fat))"))
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Text(tr("\(TF.int(entry.totals.kcal)) kcal"))
                                .foregroundStyle(Color.secondary)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityIdentifier("entry-row")
                    .swipeActions {
                        Button(role: .destructive) {
                            model.update(\.nutrition) { $0.deleteEntry(entry.id) }
                        } label: {
                            Label(tr("Supprimer"), systemImage: "trash")
                        }
                        Button {
                            model.update(\.nutrition) { $0.toggleFavorite(entry.food) }
                        } label: {
                            Label(tr("Favori"), systemImage: "star")
                        }
                        .tint(palette.category("F08A24"))
                    }
                }
                Button {
                    searching = true
                } label: {
                    Label(tr("Ajouter un aliment"), systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .accessibilityIdentifier("meal-add")
            } header: {
                Text(tr("Aliments"))
            } footer: {
                if !entries.isEmpty {
                    Text(tr("Touche un aliment pour changer sa quantité ou le déplacer. Glisse-le pour le supprimer."))
                }
            }

            if !previous.isEmpty {
                Section {
                    ForEach(previous) { past in
                        Button {
                            guard resumedMeals.insert(past.id).inserted else { return }
                            Haptics.tap()
                            let items = past.items
                            model.update(\.nutrition) { $0.log(items, meal: meal, on: day) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Fmt.shortDay(past.day)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                                    Text(past.summary).font(.caption).foregroundStyle(Color.secondary).lineLimit(2)
                                }
                                Spacer()
                                Text(tr("\(TF.int(past.totals.kcal)) kcal")).font(.subheadline).foregroundStyle(Color.secondary).monospacedDigit()
                                Image(systemName: "plus.circle").foregroundStyle(.tint)
                            }
                        }
                    }
                } header: {
                    Text(tr("Reprendre un \(meal.title.lowercased()) précédent"))
                }
            }

            if !state.savedMeals.isEmpty {
                Section(tr("Mes repas")) {
                    ForEach(state.savedMeals) { saved in
                        Button {
                            loggedSaved = saved
                        } label: {
                            HStack {
                                Text(saved.name).foregroundStyle(Color.primary)
                                Spacer()
                                Text(tr("\(TF.int(saved.totals.kcal)) kcal")).foregroundStyle(Color.secondary).monospacedDigit()
                                Image(systemName: "plus.circle").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }

            if !entries.isEmpty {
                Section {
                    Button {
                        saveName = meal.title
                        namingSave = true
                    } label: {
                        Label(tr("Enregistrer ce repas"), systemImage: "bookmark")
                    }
                    .accessibilityIdentifier("meal-save")
                } footer: {
                    Text(tr("Il ira dans « Mes repas » pour le reprendre d'une touche."))
                }
            }
        }
        .styledList()
        .tint(palette.strong(accentHex))
        .navigationTitle(meal.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing) { entry in
            EntryEditor(entry: entry)
        }
        .sheet(isPresented: $searching) {
            FoodSearchView(presetMeal: meal, day: day)
        }
        .sheet(item: $loggedSaved) { saved in
            SavedMealLogSheet(saved: saved, presetMeal: meal, day: day)
        }
        .alert(tr("Enregistrer ce repas"), isPresented: $namingSave) {
            TextField(tr("Nom"), text: $saveName)
            Button(tr("Annuler"), role: .cancel) {}
            Button(tr("Enregistrer")) {
                let name = saveName
                model.update(\.nutrition) { $0.saveMeal(meal, on: day, name: name) }
                Haptics.success()
            }
        } message: {
            Text(tr("Donne-lui un nom : « Déjeuner du dimanche », « Bol protéiné »…"))
        }
    }

    private func stat(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).monospacedDigit()
            Text("\(title)").font(.caption2).foregroundStyle(.secondary)
            Text(unit).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Changes one food of a meal: its quantity, its meal, or removes it.
struct EntryEditor: View {
    let entry: FoodEntry
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 0
    @State private var meal: MealType = .lunch

    var body: some View {
        let totals = entry.food.nutrients(grams: grams)
        SheetForm(title: entry.food.name, canSave: grams > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Quantité"), value: $grams, unit: "g")
                    .accessibilityIdentifier("entry-grams")
                Stepper(tr("Ajuster de 10 g"), value: $grams, in: 0...NutritionState.maxGrams, step: 10)
                Picker(tr("Repas"), selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            }
            Section(tr("Apport")) {
                ValueRow(title: tr("Calories"), value: tr("\(TF.int(totals.kcal)) kcal"))
                ValueRow(title: tr("Protéines"), value: totals.marked("\(TF.decimal(totals.protein, 1)) g", incomplete: totals.isIncomplete))
                ValueRow(title: tr("Glucides"), value: totals.marked("\(TF.decimal(totals.carbs, 1)) g", incomplete: totals.isIncomplete))
                ValueRow(title: tr("Lipides"), value: totals.marked("\(TF.decimal(totals.fat, 1)) g", incomplete: totals.isIncomplete))
                if model.isPremium {
                    ValueRow(title: tr("Fibres"), value: totals.marked("\(TF.decimal(totals.fiber, 1)) g", incomplete: totals.isFiberIncomplete))
                } else {
                    NutrientLockRow()
                }
            }
            if model.isPremium {
                FoodNutrientSections(totals: totals)
            }
            Section {
                Button(role: .destructive) {
                    let id = entry.id
                    model.update(\.nutrition) { $0.deleteEntry(id) }
                    dismiss()
                } label: {
                    Label(tr("Retirer de ce repas"), systemImage: "trash")
                }
                .accessibilityIdentifier("entry-delete")
            }
        }
        .onAppear {
            grams = entry.grams
            meal = entry.meal
        }
        // The field takes anything typed: the quantity stays inside the limits of the log (1 to 5 000 g).
        .onChange(of: grams) { _, value in
            if value.isNaN {
                grams = 0
            } else if value > NutritionState.maxGrams {
                grams = NutritionState.maxGrams
            }
        }
    }

    private func save() {
        let id = entry.id
        let amount = grams
        let chosen = meal
        model.update(\.nutrition) { $0.updateEntry(id, grams: amount, meal: chosen) }
        Haptics.success()
    }
}

// MARK: - Nutrients

/// Every nutrient of a day against the person's targets and limits. A nutrient that some foods don't
/// give is marked as partial rather than shown as a complete figure. The calories and the three
/// macronutrients are free; the other nutrients are Premium (their values are kept either way).
struct NutritionNutrientsPage: View {
    let day: Date
    /// Inside « Bilan »: no title of its own.
    var embedded = false
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let state = model.nutrition
        let entries = NutritionMath.entries(state, on: day)
        let totals = NutritionMath.totals(state, on: day)
        let goals = state.goals
        let known = NutritionTiles.Targets(model.profile)
        let recommended = model.recommendedNutritionGoals()
        let premium = model.isPremium
        List {
            Section {
                row(tr("Calories"), totals.kcal, goal: known.kcal ? goals.kcal : nil, unit: "kcal", hex: NutritionColors.caloriesHex)
                row(tr("Protéines"), totals.protein, goal: known.protein ? goals.protein : nil, unit: "g", hex: NutritionColors.proteinHex, incomplete: totals.isIncomplete)
                row(tr("Glucides"), totals.carbs, goal: known.carbs ? goals.carbs : nil, unit: "g", hex: NutritionColors.carbsHex, incomplete: totals.isIncomplete)
                row(tr("Lipides"), totals.fat, goal: known.fat ? goals.fat : nil, unit: "g", hex: NutritionColors.fatHex, incomplete: totals.isIncomplete)
                if premium {
                    row(tr("Fibres"), totals.fiber, goal: model.shownNutritionTarget(.fiber, recommended: recommended), unit: "g", hex: "7FA33A", incomplete: totals.isFiberIncomplete)
                }
            } header: {
                Text(tr("Objectifs"))
            }
            if premium {
                Section {
                    ForEach(Nutrient.Group.limits.nutrients) { nutrient in
                        nutrientRow(nutrient, totals: totals, entries: entries, recommended: recommended)
                    }
                } header: {
                    Text(tr("À limiter"))
                } footer: {
                    Text(tr("Limites habituelles des guides de santé publique, modifiables dans Objectifs. Quand un aliment ne donne pas une valeur, le total est marqué « partiel »."))
                }
                ForEach([Nutrient.Group.fats, .minerals, .vitamins], id: \.self) { group in
                    Section {
                        ForEach(group.nutrients) { nutrient in
                            nutrientRow(nutrient, totals: totals, entries: entries, recommended: recommended)
                        }
                    } header: {
                        Text(group.title)
                    } footer: {
                        if group == .vitamins {
                            Text(tr("Des repères pour un adulte en bonne santé, pas un avis médical."))
                        }
                    }
                }
            } else {
                Section {
                    NutrientLockRow()
                }
            }
        }
        .styledList()
        .navigationTitle(embedded ? tr("Bilan") : tr("Nutriments"))
        .navigationBarTitleDisplayMode(.inline)
        // Targets added by an update follow the calculation at once.
        .onAppear { model.followCalculatedNutritionGoals() }
    }

    private func row(_ title: String, _ value: Double, goal: Double?, unit: String, hex: String, incomplete: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text((incomplete ? NutritionTotals.minimumMarker : "") + (goal.map { "\(TF.int(value)) / \(TF.int($0)) \(unit)" } ?? "\(TF.int(value)) \(unit)"))
                    .foregroundStyle(Color.secondary)
                    .monospacedDigit()
            }
            if let goal {
                BarView(progress: value / max(1, goal), color: palette.category(hex), track: palette.category(hex).opacity(0.15), height: 6)
            }
        }
        .padding(.vertical, 4)
    }

    /// A nutrient of Premium: against its target (a bar that fills) or its limit (red once over), or alone
    /// when no reference gives one (cholesterol, alcohol, mono- and polyunsaturated fats) or while the
    /// person's targets are unknown (the same « — » as in « Tes besoins par jour », never the default).
    private func nutrientRow(_ nutrient: Nutrient, totals: NutritionTotals, entries: [FoodEntry], recommended: NutritionGoals?) -> some View {
        let value = nutrient.value(in: totals)
        let goal = nutrient.target.flatMap { model.shownNutritionTarget($0, recommended: recommended) }
        let isLimit = nutrient.target?.isLimit ?? false
        let isOver = isLimit && value != nil && goal != nil && (value ?? 0) > (goal ?? 0)
        let isPartial = value != nil && nutrient.foodPath.map { !NutritionMath.coverage(entries, $0).isComplete } == true
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(nutrient.title)
                if isPartial {
                    Text(tr("partiel"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(palette.tintColor, in: Capsule())
                }
                Spacer()
                if let value {
                    Text(goal.map { "\(nutrient.number(value)) / \(nutrient.number($0)) \(nutrient.unit)" } ?? nutrient.format(value))
                        .foregroundStyle(isOver ? palette.strong(MiniStyle.alertHex) : Color.secondary)
                        .monospacedDigit()
                } else {
                    Text(tr("Non disponible")).foregroundStyle(Color.secondary)
                }
            }
            if let value, let goal, goal > 0 {
                let color = isLimit ? (isOver ? palette.category(MiniStyle.alertHex) : palette.category("6B7280")) : palette.category("7FA33A")
                BarView(progress: value / goal, color: color, track: (isLimit ? Color.secondary : color).opacity(0.15), height: 6)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ideas

/// Ideas for the rest of the day from what is really left: foods rich in protein or fibre that fit,
/// and dishes the size of what remains. General ideas from the built-in table, never presented as
/// the person's data.
struct NutritionIdeasPage: View {
    @Environment(AppModel.self) private var model
    @State private var selected: FoodItem?

    var body: some View {
        let now = Date()
        let known = NutritionTiles.Targets(model.profile)
        let remaining = NutritionMath.remaining(model.nutrition, on: now, knowsKcal: known.kcal, knowsProtein: known.protein)
        let kcalLeft = remaining.kcal.map { max(0, $0) }
        let nextMeal = MealType.next(after: now) ?? .snack
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if let kcalLeft {
                        Text(tr("Il te reste environ \(TF.int(kcalLeft)) kcal")).font(.title3.weight(.bold))
                    } else {
                        Text(tr("Des idées pour la suite de ta journée")).font(.title3.weight(.bold))
                    }
                    Text(remainingText(remaining))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
            if let kcalLeft, kcalLeft >= 250 {
                let dishes = NutritionMath.mealIdeas(for: kcalLeft)
                if !dishes.isEmpty {
                    section(tr("Un repas qui tient dans ce qu'il reste"), dishes)
                }
            }
            if (remaining.protein ?? 0) > 10 || remaining.protein == nil {
                section(tr("Riches en protéines"), NutritionMath.proteinIdeas(within: kcalLeft))
            }
            if (remaining.fiber ?? 0) > 5 {
                if model.isPremium {
                    section(tr("Riches en fibres"), NutritionMath.fiberIdeas(within: kcalLeft))
                } else {
                    Section(tr("Riches en fibres")) {
                        NutrientLockRow()
                    }
                }
            }
            Section {
            } footer: {
                Text(tr("Idées générales tirées de la table d'aliments d'Ardane, à adapter à tes goûts. Ce n'est pas un avis médical."))
            }
        }
        .styledList()
        .navigationTitle(tr("Idées"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { food in
            FoodLogSheet(food: food, presetMeal: nextMeal)
        }
    }

    private func remainingText(_ remaining: NutritionMath.Remaining) -> String {
        var parts: [String] = []
        if let protein = remaining.protein { parts.append(protein > 0 ? tr("\(TF.int(protein)) g de protéines") : tr("protéines atteintes")) }
        if model.isPremium, let fiber = remaining.fiber { parts.append(fiber > 0 ? tr("\(TF.int(fiber)) g de fibres") : tr("fibres atteintes")) }
        guard !parts.isEmpty else { return tr("Basé sur ce que tu as noté aujourd'hui.") }
        return tr("Encore ") + parts.joined(separator: tr(" et ")) + tr(" pour tes objectifs du jour.")
    }

    private func section(_ title: String, _ ideas: [NutritionMath.Idea]) -> some View {
        Section(title) {
            ForEach(ideas) { idea in
                Button {
                    selected = idea.food
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idea.food.name).foregroundStyle(Color.primary).lineLimit(1)
                            Text(model.isPremium
                                 ? tr("\(idea.food.servingName) · P \(TF.int(idea.totals.protein)) g · fibres \(TF.int(idea.totals.fiber)) g")
                                 : tr("\(idea.food.servingName) · P \(TF.int(idea.totals.protein)) g"))
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(tr("\(TF.int(idea.totals.kcal)) kcal")).foregroundStyle(Color.secondary).monospacedDigit()
                        Image(systemName: "plus.circle").foregroundStyle(.tint)
                    }
                }
            }
        }
    }
}

// MARK: - History

/// Averages, goal adherence and trends over a period, with the weight when it was given.
struct NutritionHistoryPage: View {
    enum Period: String, CaseIterable, Identifiable {
        case today, yesterday, week, month, custom
        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: tr("Aujourd'hui")
            case .yesterday: tr("Hier")
            case .week: tr("7 jours")
            case .month: tr("30 jours")
            case .custom: tr("Période")
            }
        }
    }

    /// Inside « Bilan » (its own title and segments): no title of its own. `showsWeek`: the free week of `day` on top.
    var embedded = false
    var showsWeek = false
    var day = Date()
    @Environment(AppModel.self) private var model
    @State private var period: Period = .week
    @State private var customStart = DateMath.calendar.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    private var accentHex: String { MiniApp.nutrition.colorHex }

    private var range: (Date, Date) {
        let now = Date()
        let calendar = DateMath.calendar
        switch period {
        case .today: return (now, now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return (yesterday, yesterday)
        case .week: return (calendar.date(byAdding: .day, value: -6, to: now) ?? now, now)
        case .month: return (calendar.date(byAdding: .day, value: -29, to: now) ?? now, now)
        case .custom: return (min(customStart, customEnd), max(customStart, customEnd))
        }
    }

    var body: some View {
        if embedded {
            scroll
        } else {
            scroll
                .navigationTitle(tr("Historique"))
                .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder private var scroll: some View {
        let bounds = range
        let state = model.nutrition
        let stats = NutritionMath.stats(state, from: bounds.0, to: bounds.1)
        let known = NutritionTiles.Targets(model.profile)
        let weights = model.profile.weights(from: bounds.0, to: bounds.1)
        MiniAppScroll {
            Picker(tr("Période"), selection: $period) {
                ForEach(Period.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("history-period")
            // The week stays free: shown while the periods below are a day or locked.
            if showsWeek && (!model.isPremium || period == .today || period == .yesterday) {
                NutritionWeekCard(day: day)
            }
            if period == .custom && model.isPremium {
                VStack(spacing: 8) {
                    DatePicker(tr("Du"), selection: $customStart, in: ...Date(), displayedComponents: .date)
                    DatePicker(tr("Au"), selection: $customEnd, in: ...Date(), displayedComponents: .date)
                }
                .card(padding: 14)
            }
            if !model.isPremium && (period == .week || period == .month || period == .custom) {
                // A day stays free (and the week on the Nutrition page); the trends and analyses are Premium.
                PremiumLockCard(symbol: "chart.line.uptrend.xyaxis", title: tr("L'historique détaillé est dans Premium"),
                                message: tr("7 jours, 30 jours ou la période de ton choix : moyennes, tendances, répartition des macros et poids. Tes repas restent enregistrés : tout s'affiche dès que tu passes à Premium."))
            } else if stats.trackedDays == 0 {
                EmptyStateView(symbol: "fork.knife", title: tr("Rien de noté"), message: tr("Aucun repas noté sur cette période."))
                    .card()
            } else {
                averages(stats, known: known, isSingleDay: stats.days.count == 1)
                if stats.days.count > 1 {
                    caloriesChart(stats, known: known)
                }
                macroSplit(stats.averages)
                if weights.count >= 2 {
                    NutritionWeightChart(points: weights)
                }
                if stats.days.count > 1 {
                    dayList(stats)
                }
            }
        }
        .onAppear { if !model.isPremium && period == .week { period = .today } }
    }

    private func averages(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets, isSingleDay: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: isSingleDay ? tr("Bilan") : tr("Moyennes", context: "averages"), detail: isSingleDay ? nil : Fmt.plural(stats.trackedDays, tr("jour noté"), tr("jours notés")))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MiniStat(title: tr("Calories"), value: TF.int(stats.averages.kcal), unit: "kcal", detail: known.kcal ? tr("objectif \(TF.int(stats.goal))") : nil, colorHex: accentHex)
                MiniStat(title: tr("Protéines"), value: stats.averages.marked(TF.int(stats.averages.protein), incomplete: stats.averages.isIncomplete), unit: "g")
                MiniStat(title: tr("Glucides"), value: stats.averages.marked(TF.int(stats.averages.carbs), incomplete: stats.averages.isIncomplete), unit: "g")
                MiniStat(title: tr("Lipides"), value: stats.averages.marked(TF.int(stats.averages.fat), incomplete: stats.averages.isIncomplete), unit: "g")
            }
            if known.kcal, !isSingleDay {
                Label(tr("\(Fmt.plural(stats.daysOnTarget, tr("jour"), tr("jours"))) sur \(stats.trackedDays) à moins de 10 % de ton objectif"), systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func caloriesChart(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Calories par jour"))
            Chart {
                ForEach(DayValue.list(stats.days, stats.kcalPerDay)) { item in
                    BarMark(x: .value("Jour", item.date, unit: .day), y: .value("kcal", item.value))
                        .foregroundStyle(palette.category(accentHex).gradient)
                        .cornerRadius(3)
                }
                if known.kcal {
                    RuleMark(y: .value("Objectif", stats.goal))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(tr("Objectif")).font(.caption2).foregroundStyle(.secondary)
                        }
                }
            }
            .accessibilityLabel(tr("Calories par jour"))
            .frame(height: 200)
            .card()
        }
    }

    private func macroSplit(_ averages: NutritionTotals) -> some View {
        let kcal = max(averages.protein * 4 + averages.carbs * 4 + averages.fat * 9, 1)
        let parts = [
            MacroShare(name: tr("Protéines"), share: averages.protein * 4 / kcal, hex: NutritionColors.proteinHex),
            MacroShare(name: tr("Glucides"), share: averages.carbs * 4 / kcal, hex: NutritionColors.carbsHex),
            MacroShare(name: tr("Lipides"), share: averages.fat * 9 / kcal, hex: NutritionColors.fatHex),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Répartition des calories"))
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(parts) { part in
                            Rectangle()
                                .fill(palette.category(part.hex))
                                .frame(width: max(2, (geo.size.width - 4) * part.share))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)
                HStack {
                    ForEach(parts) { part in
                        HStack(spacing: 5) {
                            Circle().fill(palette.category(part.hex)).frame(width: 8, height: 8)
                            Text("\(part.name) \(Fmt.percent(part.share))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .card()
        }
    }

    private func dayList(_ stats: NutritionMath.PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Jour par jour"))
            MiniRowsCard {
                let days = Array(zip(stats.days, stats.kcalPerDay).reversed().prefix(31))
                ForEach(Array(days.enumerated()), id: \.offset) { index, pair in
                    NavigationLink(value: HomeRoute.page(.nutritionDay(pair.0))) {
                        MiniRow(symbol: "calendar", colorHex: accentHex, title: Fmt.shortDay(pair.0), detail: pair.1 > 0 ? nil : tr("Rien de noté"), value: pair.1 > 0 ? tr("\(TF.int(pair.1)) kcal") : nil)
                    }
                    .buttonStyle(.pressable)
                    if index < days.count - 1 { MiniDivider() }
                }
            }
        }
    }
}

/// The weight curve of a period (saved in kg, shown in the chosen unit), with the target of the weight goal as a
/// line and the 7-day average as a smoother curve.
struct NutritionWeightChart: View {
    let points: [ValuePoint]
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }
    private var accentHex: String { MiniApp.nutrition.colorHex }

    var body: some View { chart }

    private var chart: some View {
        // Saved in kg; shown in the chosen unit.
        let system = model.settings.unitSystem
        let kilograms = points
        let weights = points.map { ValuePoint(date: $0.date, value: Units.weightValue(kilograms: $0.value, in: system)) }
        // With a weight goal: its target as a line, and the 7-day average as a smoother curve.
        var plannedTarget: Double?
        if let plan = model.activeWeightPlan {
            plannedTarget = Units.weightValue(kilograms: plan.targetKg, in: system)
        }
        let target: Double? = plannedTarget
        var smoothedPoints: [ValuePoint] = []
        if target != nil && kilograms.count >= 3 {
            for point in WeightPlanCalculator.movingAverage(kilograms) {
                smoothedPoints.append(ValuePoint(date: point.date, value: Units.weightValue(kilograms: point.value, in: system)))
            }
        }
        let smoothed: [ValuePoint] = smoothedPoints
        var values: [Double] = weights.map(\.value)
        if let target { values.append(target) }
        let low: Double = (values.min() ?? 0) - 1
        let high: Double = (values.max() ?? 0) + 1
        let change = (weights.last?.value ?? 0) - (weights.first?.value ?? 0)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Poids"), detail: "\(change >= 0 ? "+" : "−")\(TF.decimal(abs(change), 1)) \(system.weightUnit)")
            Chart {
                ForEach(weights, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value(system.weightUnit, point.value), series: .value("Série", "poids"))
                        .foregroundStyle(palette.category(accentHex))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value(system.weightUnit, point.value))
                        .foregroundStyle(palette.category(accentHex))
                        .symbolSize(20)
                }
                ForEach(smoothed, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value(system.weightUnit, point.value), series: .value("Série", "lissé"))
                        .foregroundStyle(Color.primary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                }
                if let target {
                    RuleMark(y: .value(tr("Cible"), target))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(tr("Cible")).font(.caption2).foregroundStyle(.secondary)
                        }
                }
            }
            .accessibilityIdentifier("nutrition-weight-chart")
            .chartYScale(domain: low...high)
            .frame(height: 160)
            .card()
            Text(tr("Le poids vient de « Mes informations » : chaque nouvelle valeur s'ajoute ici."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// A value of a day, for charts.
struct DayValue: Identifiable, Hashable {
    let date: Date
    let value: Double
    var id: Date { date }

    static func list(_ days: [Date], _ values: [Double]) -> [DayValue] {
        zip(days, values).map { DayValue(date: $0.0, value: $0.1) }
    }
}

private struct MacroShare: Identifiable {
    let name: String
    let share: Double
    let hex: String
    var id: String { name }
}

// MARK: - Saved meals

struct NutritionSavedMealsPage: View {
    @Environment(AppModel.self) private var model
    @State private var logged: SavedMeal?
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let saved = model.nutrition.savedMeals
        List {
            if saved.isEmpty {
                Section {
                    Text(tr("Aucun repas enregistré. Ouvre un repas de ta journée et touche « Enregistrer ce repas » : il sera ici, prêt à reprendre d'une touche."))
                        .foregroundStyle(Color.secondary)
                }
            }
            ForEach(saved) { meal in
                Section {
                    ForEach(Array(meal.items.enumerated()), id: \.offset) { _, item in
                        ValueRow(title: item.food.name, value: "\(TF.int(item.grams)) g")
                    }
                    Button {
                        logged = meal
                    } label: {
                        Label(tr("Ajouter à ma journée"), systemImage: "plus.circle.fill")
                    }
                    Button(role: .destructive) {
                        let id = meal.id
                        model.update(\.nutrition) { $0.savedMeals.removeAll { $0.id == id } }
                    } label: {
                        Label(tr("Supprimer ce repas"), systemImage: "trash")
                    }
                } header: {
                    HStack {
                        Text(meal.name)
                        Spacer()
                        Text(tr("\(TF.int(meal.totals.kcal)) kcal · P \(TF.int(meal.totals.protein)) g"))
                    }
                }
            }
        }
        .styledList()
        .tint(palette.strong(MiniApp.nutrition.colorHex))
        .navigationTitle(tr("Mes repas"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $logged) { meal in
            SavedMealLogSheet(saved: meal)
        }
    }
}

// MARK: - The calories of the week

/// The calories of the week of a day, one bar a day (the chosen one in full color), then the average and the days
/// on target. Free: the week was on the Nutrition page before it moved into « Bilan ».
struct NutritionWeekCard: View {
    let day: Date
    @Environment(AppModel.self) private var model

    private var accentHex: String { MiniApp.nutrition.colorHex }

    var body: some View {
        let state = model.nutrition
        let known = NutritionTiles.Targets(model.profile)
        let week = DateMath.week(containing: day)
        let stats = Self.stats(state, week)
        let values = week.map { NutritionMath.totals(state, on: $0).kcal }
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Calories de la semaine"))
            VStack(alignment: .leading, spacing: 12) {
                WeekBars(values: values, days: week, goal: known.kcal ? state.goals.kcal : nil, colorHex: accentHex,
                         highlighted: week.firstIndex { DateMath.isSameDay($0, day) })
                    .frame(height: 70)
                Text(Self.text(stats, known: known, empty: tr("Rien de noté cette semaine.")))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .miniCard()
        }
    }

    /// The days of the week up to today.
    static func stats(_ state: NutritionState, _ week: [Date]) -> NutritionMath.PeriodStats {
        let now = Date()
        let start = week.first ?? now
        let end = min(week.last ?? now, now)
        return NutritionMath.stats(state, from: start, to: max(start, end))
    }

    static func text(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets, empty: String) -> String {
        guard stats.trackedDays > 0 else { return empty }
        let average = tr("Moyenne \(TF.int(stats.averages.kcal)) kcal")
        guard known.kcal else { return tr("\(average) sur \(Fmt.plural(stats.trackedDays, tr("jour noté"), tr("jours notés"))).") }
        return tr("\(average) · \(Fmt.plural(stats.daysOnTarget, tr("jour"), tr("jours"))) sur \(stats.trackedDays) dans l'objectif")
    }
}

// MARK: - Review

/// « Bilan »: one page, three segments, for what the old pages held apart: « Calories » (the week, the periods,
/// the averages: the history), « Nutriments » (every nutrient of the day) and « Poids ». The locks of Premium are the
/// ones of the pages inside.
struct NutritionReviewPage: View {
    enum Segment: String, CaseIterable, Identifiable {
        case calories, nutrients, weight
        var id: String { rawValue }

        var title: String {
            switch self {
            case .calories: tr("Calories")
            case .nutrients: tr("Nutriments")
            case .weight: tr("Poids")
            }
        }
    }

    var day = Date()
    @State private var segment: Segment = .calories
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        VStack(spacing: 0) {
            Picker(tr("Bilan"), selection: $segment) {
                ForEach(Segment.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .accessibilityIdentifier("review-segment")
            switch segment {
            case .calories: NutritionHistoryPage(embedded: true, showsWeek: true, day: day)
            case .nutrients: NutritionNutrientsPage(day: day, embedded: true)
            case .weight: NutritionWeightSegment()
            }
        }
        .cristalScreen()
        .tint(palette.strong(MiniApp.nutrition.colorHex))
        .navigationTitle(tr("Bilan"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The weight segment of « Bilan »: the weight now and its change over 7 days, the curve of 30 days (Premium, as in the
/// history), the recap of the weight goal, the calorie goal and since when it holds.
struct NutritionWeightSegment: View {
    @Environment(AppModel.self) private var model
    @State private var showsInfo = false

    var body: some View {
        let now = Date()
        let start = DateMath.calendar.date(byAdding: .day, value: -29, to: now) ?? now
        let weights = model.profile.weights(from: start, to: now)
        let state = model.nutrition
        let known = NutritionTiles.Targets(model.profile)
        MiniAppScroll {
            if let last = weights.last {
                MiniHero(label: tr("Poids"), value: weightText(last.value), caption: changeText(weights, now: now))
                    .accessibilityIdentifier("review-weight")
            } else {
                EmptyStateView(symbol: "scalemass", title: tr("Pas encore de pesée"), message: tr("Ajoute ton poids : la courbe et ton plan se construisent à partir de là."))
                    .card()
            }
            if !model.isPremium {
                PremiumLockCard(symbol: "chart.line.uptrend.xyaxis", title: tr("L'historique détaillé est dans Premium"),
                                message: tr("7 jours, 30 jours ou la période de ton choix : moyennes, tendances, répartition des macros et poids. Tes repas restent enregistrés : tout s'affiche dès que tu passes à Premium."))
            } else if weights.count >= 2 {
                NutritionWeightChart(points: weights)
            }
            WeightPlanSummaryView()
            if known.kcal {
                Label(goalText(state), systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("review-goal-since")
            }
            Button {
                showsInfo = true
            } label: {
                Label(tr("Ajouter une pesée"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("review-add-weight")
        }
        .sheet(isPresented: $showsInfo) { MiniAppInfoSheet(app: .nutrition) }
    }

    private func weightText(_ kilograms: Double) -> String {
        let system = model.settings.unitSystem
        return "\(TF.decimal(Units.weightValue(kilograms: kilograms, in: system), 1)) \(system.weightUnit)"
    }

    /// « −0,5 kg en 7 jours »: the last weight against the first of the last 7 days (nothing with a single weight).
    private func changeText(_ weights: [ValuePoint], now: Date) -> String? {
        let weekAgo = DateMath.startOfDay(DateMath.calendar.date(byAdding: .day, value: -6, to: now) ?? now)
        let recent = weights.filter { $0.date >= weekAgo }
        guard recent.count >= 2, let first = recent.first, let last = recent.last else { return nil }
        let system = model.settings.unitSystem
        let change = Units.weightValue(kilograms: last.value, in: system) - Units.weightValue(kilograms: first.value, in: system)
        return tr("\(change >= 0 ? "+" : "−")\(TF.decimal(abs(change), 1)) \(system.weightUnit) en 7 jours")
    }

    /// « Objectif : 2 200 kcal par jour, depuis le 5 nov. »: the date only once the app has seen the goal change.
    private func goalText(_ state: NutritionState) -> String {
        guard let since = state.kcalGoalSince else { return tr("Objectif : \(TF.int(state.goals.kcal)) kcal par jour") }
        return tr("Objectif : \(TF.int(state.goals.kcal)) kcal par jour, depuis le \(Fmt.format(since, template: "dMMM"))")
    }
}

// MARK: - Library

/// « Ma bibliothèque »: what the person keeps, in three titled sections: the favorites, the saved meals (to add to the
/// day or to change) and the personal foods (only when there are some).
struct NutritionLibraryPage: View {
    @Environment(AppModel.self) private var model
    @State private var logged: SavedMeal?
    @State private var editing: SavedMeal?
    @State private var showsCustomFoods = false

    private var accentHex: String { MiniApp.nutrition.colorHex }

    var body: some View {
        let state = model.nutrition
        MiniAppScroll {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Favoris"), detail: state.favorites.isEmpty ? nil : "\(state.favorites.count)")
                if state.favorites.isEmpty {
                    Text(tr("Aucun favori. Glisse un aliment de ton repas vers la gauche pour l'ajouter ici."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    MiniRowsCard {
                        ForEach(Array(state.favorites.enumerated()), id: \.element.id) { index, food in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.displayName).font(.body.weight(.medium)).lineLimit(1)
                                    Text(FoodText.summary(food)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                Button(tr("Retirer")) {
                                    model.update(\.nutrition) { $0.toggleFavorite(food) }
                                }
                                .font(.subheadline.weight(.semibold))
                                .buttonStyle(.pressable)
                                .accessibilityIdentifier("library-unfavorite")
                            }
                            .padding(.vertical, 10)
                            if index < state.favorites.count - 1 { MiniDivider() }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Mes repas"), detail: state.savedMeals.isEmpty ? nil : "\(state.savedMeals.count)")
                if state.savedMeals.isEmpty {
                    Text(tr("Aucun repas enregistré. Ouvre un repas de ta journée et touche « Enregistrer ce repas » : il sera ici, prêt à reprendre d'une touche."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    MiniRowsCard {
                        ForEach(Array(state.savedMeals.enumerated()), id: \.element.id) { index, meal in
                            savedRow(meal)
                            if index < state.savedMeals.count - 1 { MiniDivider() }
                        }
                    }
                }
            }
            if !state.customFoods.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Mes aliments"), detail: "\(state.customFoods.count)")
                    MiniRowsCard {
                        Button {
                            showsCustomFoods = true
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(state.customFoods.enumerated()), id: \.element.id) { index, food in
                                    HStack {
                                        Text(food.displayName).font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                        Spacer(minLength: 8)
                                        Text(tr("\(TF.int(food.kcal)) kcal / 100 g")).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                                    }
                                    .padding(.vertical, 10)
                                    if index < state.customFoods.count - 1 { MiniDivider() }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("nutrition-custom-foods")
                    }
                    Text(tr("Corriger ou supprimer tes aliments personnels"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(tr("Ma bibliothèque"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $logged) { SavedMealLogSheet(saved: $0) }
        .sheet(item: $editing) { SavedMealEditor(saved: $0) }
        .sheet(isPresented: $showsCustomFoods) { CustomFoodsView() }
    }

    private func savedRow(_ meal: SavedMeal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(meal.name).font(.body.weight(.medium)).lineLimit(1)
                Spacer(minLength: 8)
                Text(tr("\(TF.int(meal.totals.kcal)) kcal")).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            Text(meal.items.map { $0.food.name }.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 16) {
                Button {
                    logged = meal
                } label: {
                    Label(tr("Ajouter à ma journée"), systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("library-log")
                Button {
                    editing = meal
                } label: {
                    Label(tr("Modifier"), systemImage: "pencil")
                }
                .accessibilityIdentifier("library-edit")
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.pressable)
            .padding(.top, 2)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Changes a saved meal: its name, the quantity of each food, and which foods it keeps (swipe to remove one). Adding
/// a new food is done from a day: log it, then « Enregistrer ce repas ».
struct SavedMealEditor: View {
    private struct Row: Identifiable {
        let id = UUID()
        let food: FoodItem
        var grams: Double
    }

    let saved: SavedMeal
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var rows: [Row] = []

    var body: some View {
        SheetForm(title: saved.name, canSave: !rows.isEmpty && rows.allSatisfy { $0.grams > 0 }, onSave: save) {
            Section(tr("Nom")) {
                TextField(tr("Nom"), text: $name)
                    .accessibilityIdentifier("saved-meal-name")
            }
            Section {
                ForEach($rows) { $row in
                    NumberRow(title: row.food.name, value: $row.grams, unit: "g")
                }
                .onDelete { rows.remove(atOffsets: $0) }
            } header: {
                Text(tr("Aliments"))
            } footer: {
                Text(tr("Glisse un aliment vers la gauche pour le retirer de ce repas."))
            }
            Section {
                Button(role: .destructive) {
                    let id = saved.id
                    model.update(\.nutrition) { $0.savedMeals.removeAll { $0.id == id } }
                    dismiss()
                } label: {
                    Label(tr("Supprimer ce repas"), systemImage: "trash")
                }
            }
        }
        .onAppear {
            guard rows.isEmpty else { return }
            name = saved.name
            rows = saved.items.map { Row(food: $0.food, grams: $0.grams) }
        }
    }

    private func save() {
        let id = saved.id
        let newName = name
        let items = rows.map { SavedMeal.Item(food: $0.food, grams: $0.grams) }
        model.update(\.nutrition) { $0.updateSavedMeal(id, name: newName, items: items) }
        Haptics.success()
    }
}
