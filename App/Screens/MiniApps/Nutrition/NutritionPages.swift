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

    private var accentHex: String { MiniApp.nutrition.colorHex }

    var body: some View {
        let state = model.nutrition
        let entries = NutritionMath.entries(state, on: day).filter { $0.meal == meal }
        let totals = entries.reduce(NutritionTotals()) { $0 + $1.totals }
        let previous = NutritionMath.previousMeals(meal, state, before: day, limit: 3)
        List {
            Section {
                HStack(spacing: 0) {
                    stat("Calories", TF.int(totals.kcal), "kcal")
                    stat("Protéines", TF.int(totals.protein), "g")
                    stat("Glucides", TF.int(totals.carbs), "g")
                    stat("Lipides", TF.int(totals.fat), "g")
                }
                .padding(.vertical, 6)
            } header: {
                Text(DateMath.isSameDay(day, Date()) ? "Aujourd'hui" : Fmt.longDay(day))
            }

            Section {
                if entries.isEmpty {
                    Text("Rien de noté pour ce repas.")
                        .foregroundStyle(Color.secondary)
                }
                ForEach(entries) { entry in
                    Button {
                        editing = entry
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.food.displayName).foregroundStyle(Color.primary).lineLimit(1)
                                Text("\(TF.int(entry.grams)) g · P \(TF.int(entry.totals.protein)) · G \(TF.int(entry.totals.carbs)) · L \(TF.int(entry.totals.fat))")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Text("\(TF.int(entry.totals.kcal)) kcal")
                                .foregroundStyle(Color.secondary)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityIdentifier("entry-row")
                    .swipeActions {
                        Button(role: .destructive) {
                            model.update(\.nutrition) { $0.deleteEntry(entry.id) }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                        Button {
                            model.update(\.nutrition) { $0.toggleFavorite(entry.food) }
                        } label: {
                            Label("Favori", systemImage: "star")
                        }
                        .tint(.orange)
                    }
                }
                Button {
                    searching = true
                } label: {
                    Label("Ajouter un aliment", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .accessibilityIdentifier("meal-add")
            } header: {
                Text("Aliments")
            } footer: {
                if !entries.isEmpty {
                    Text("Touche un aliment pour changer sa quantité ou le déplacer. Glisse-le pour le supprimer.")
                }
            }

            if !previous.isEmpty {
                Section {
                    ForEach(previous) { past in
                        Button {
                            Haptics.success()
                            let items = past.items
                            model.update(\.nutrition) { $0.log(items, meal: meal, on: day) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Fmt.shortDay(past.day)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                                    Text(past.summary).font(.caption).foregroundStyle(Color.secondary).lineLimit(2)
                                }
                                Spacer()
                                Text("\(TF.int(past.totals.kcal)) kcal").font(.subheadline).foregroundStyle(Color.secondary).monospacedDigit()
                                Image(systemName: "plus.circle").foregroundStyle(.tint)
                            }
                        }
                    }
                } header: {
                    Text("Reprendre un \(meal.title.lowercased()) précédent")
                }
            }

            if !state.savedMeals.isEmpty {
                Section("Mes repas") {
                    ForEach(state.savedMeals) { saved in
                        Button {
                            loggedSaved = saved
                        } label: {
                            HStack {
                                Text(saved.name).foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(TF.int(saved.totals.kcal)) kcal").foregroundStyle(Color.secondary).monospacedDigit()
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
                        Label("Enregistrer ce repas", systemImage: "bookmark")
                    }
                    .accessibilityIdentifier("meal-save")
                } footer: {
                    Text("Il ira dans « Mes repas » pour le reprendre d'une touche.")
                }
            }
        }
        .styledList()
        .tint(Color(hex: accentHex))
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
        .alert("Enregistrer ce repas", isPresented: $namingSave) {
            TextField("Nom", text: $saveName)
            Button("Annuler", role: .cancel) {}
            Button("Enregistrer") {
                let name = saveName
                model.update(\.nutrition) { $0.saveMeal(meal, on: day, name: name) }
                Haptics.success()
            }
        } message: {
            Text("Donne-lui un nom : « Déjeuner du dimanche », « Bol protéiné »…")
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
                NumberRow(title: "Quantité", value: $grams, unit: "g")
                    .accessibilityIdentifier("entry-grams")
                Stepper("Ajuster de 10 g", value: $grams, in: 0...5_000, step: 10)
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Apport") {
                ValueRow(title: "Calories", value: "\(TF.int(totals.kcal)) kcal")
                ValueRow(title: "Protéines", value: "\(TF.decimal(totals.protein, 1)) g")
                ValueRow(title: "Glucides", value: "\(TF.decimal(totals.carbs, 1)) g")
                ValueRow(title: "Lipides", value: "\(TF.decimal(totals.fat, 1)) g")
            }
            Section {
                Button(role: .destructive) {
                    let id = entry.id
                    model.update(\.nutrition) { $0.deleteEntry(id) }
                    dismiss()
                } label: {
                    Label("Retirer de ce repas", systemImage: "trash")
                }
                .accessibilityIdentifier("entry-delete")
            }
        }
        .onAppear {
            grams = entry.grams
            meal = entry.meal
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
/// give is marked as partial rather than shown as a complete figure.
struct NutritionNutrientsPage: View {
    let day: Date
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.nutrition
        let entries = NutritionMath.entries(state, on: day)
        let totals = NutritionMath.totals(state, on: day)
        let goals = state.goals
        let known = NutritionTiles.Targets(model.profile)
        List {
            Section {
                row("Calories", totals.kcal, goal: known.kcal ? goals.kcal : nil, unit: "kcal", hex: "F08A24")
                row("Protéines", totals.protein, goal: known.protein ? goals.protein : nil, unit: "g", hex: "E5484D")
                row("Glucides", totals.carbs, goal: known.carbs ? goals.carbs : nil, unit: "g", hex: "F2A33A")
                row("Lipides", totals.fat, goal: known.fat ? goals.fat : nil, unit: "g", hex: "3366FF")
                row("Fibres", totals.fiber, goal: goals.fiber, unit: "g", hex: "7FA33A")
            } header: {
                Text("Objectifs")
            }
            Section {
                limitRow("Sucres", totals.sugars, limit: goals.sugarsMax, unit: "g", coverage: NutritionMath.coverage(entries, \.sugars))
                limitRow("Gras saturés", totals.saturatedFat, limit: goals.saturatedFatMax, unit: "g", coverage: NutritionMath.coverage(entries, \.saturatedFat))
                limitRow("Sodium", totals.sodiumMg, limit: goals.sodiumMaxMg, unit: "mg", coverage: NutritionMath.coverage(entries, \.sodiumMg))
                limitRow("Cholestérol", totals.cholesterolMg, limit: nil, unit: "mg", coverage: NutritionMath.coverage(entries, \.cholesterolMg))
            } header: {
                Text("À limiter")
            } footer: {
                Text("Limites habituelles des guides de santé publique, modifiables dans Objectifs. Quand un aliment ne donne pas une valeur, le total est marqué « partiel ».")
            }
        }
        .styledList()
        .navigationTitle("Nutriments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: Double, goal: Double?, unit: String, hex: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(goal.map { "\(TF.int(value)) / \(TF.int($0)) \(unit)" } ?? "\(TF.int(value)) \(unit)")
                    .foregroundStyle(Color.secondary)
                    .monospacedDigit()
            }
            if let goal {
                BarView(progress: value / max(1, goal), color: Color(hex: hex), track: Color(hex: hex).opacity(0.15), height: 6)
            }
        }
        .padding(.vertical, 4)
    }

    private func limitRow(_ title: String, _ value: Double?, limit: Double?, unit: String, coverage: NutritionMath.Coverage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                if value != nil, !coverage.isComplete {
                    Text("partiel")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                Spacer()
                if let value {
                    Text(limit.map { "\(TF.int(value)) / \(TF.int($0)) \(unit)" } ?? "\(TF.int(value)) \(unit)")
                        .foregroundStyle(limit.map { value > $0 } == true ? Color(hex: "E5484D") : Color.secondary)
                        .monospacedDigit()
                } else {
                    Text("Non disponible").foregroundStyle(Color.secondary)
                }
            }
            if let value, let limit {
                BarView(progress: value / max(1, limit), color: value > limit ? Color(hex: "E5484D") : Color(hex: "8A8A8E"), track: Color.secondary.opacity(0.15), height: 6)
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
                        Text("Il te reste environ \(TF.int(kcalLeft)) kcal").font(.title3.weight(.bold))
                    } else {
                        Text("Des idées pour la suite de ta journée").font(.title3.weight(.bold))
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
                    section("Un repas qui tient dans ce qu'il reste", dishes)
                }
            }
            if (remaining.protein ?? 0) > 10 || remaining.protein == nil {
                section("Riches en protéines", NutritionMath.proteinIdeas(within: kcalLeft))
            }
            if (remaining.fiber ?? 0) > 5 {
                section("Riches en fibres", NutritionMath.fiberIdeas(within: kcalLeft))
            }
            Section {
            } footer: {
                Text("Idées générales tirées de la table d'aliments de Tessera, à adapter à tes goûts. Ce n'est pas un avis médical.")
            }
        }
        .styledList()
        .navigationTitle("Idées")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { food in
            FoodLogSheet(food: food, presetMeal: nextMeal)
        }
    }

    private func remainingText(_ remaining: NutritionMath.Remaining) -> String {
        var parts: [String] = []
        if let protein = remaining.protein { parts.append(protein > 0 ? "\(TF.int(protein)) g de protéines" : "protéines atteintes") }
        if let fiber = remaining.fiber { parts.append(fiber > 0 ? "\(TF.int(fiber)) g de fibres" : "fibres atteintes") }
        guard !parts.isEmpty else { return "Basé sur ce que tu as noté aujourd'hui." }
        return "Encore " + parts.joined(separator: " et ") + " pour tes objectifs du jour."
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
                            Text("\(idea.food.servingName) · P \(TF.int(idea.totals.protein)) g · fibres \(TF.int(idea.totals.fiber)) g")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(TF.int(idea.totals.kcal)) kcal").foregroundStyle(Color.secondary).monospacedDigit()
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
            case .today: "Aujourd'hui"
            case .yesterday: "Hier"
            case .week: "7 jours"
            case .month: "30 jours"
            case .custom: "Période"
            }
        }
    }

    @Environment(AppModel.self) private var model
    @State private var period: Period = .week
    @State private var customStart = DateMath.calendar.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var customEnd = Date()

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
        let bounds = range
        let state = model.nutrition
        let stats = NutritionMath.stats(state, from: bounds.0, to: bounds.1)
        let known = NutritionTiles.Targets(model.profile)
        let weights = model.profile.weights(from: bounds.0, to: bounds.1)
        MiniAppScroll {
            Picker("Période", selection: $period) {
                ForEach(Period.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("history-period")
            if period == .custom {
                VStack(spacing: 8) {
                    DatePicker("Du", selection: $customStart, in: ...Date(), displayedComponents: .date)
                    DatePicker("Au", selection: $customEnd, in: ...Date(), displayedComponents: .date)
                }
                .card(padding: 14)
            }
            if stats.trackedDays == 0 {
                EmptyStateView(symbol: "fork.knife", title: "Rien de noté", message: "Aucun repas noté sur cette période.")
                    .card()
            } else {
                averages(stats, known: known, isSingleDay: stats.days.count == 1)
                if stats.days.count > 1 {
                    caloriesChart(stats, known: known)
                }
                macroSplit(stats.averages)
                if weights.count >= 2 {
                    weightChart(weights)
                }
                if stats.days.count > 1 {
                    dayList(stats)
                }
            }
        }
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.large)
    }

    private func averages(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets, isSingleDay: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: isSingleDay ? "Bilan" : "Moyennes", detail: isSingleDay ? nil : "\(stats.trackedDays) jour\(stats.trackedDays > 1 ? "s" : "") noté\(stats.trackedDays > 1 ? "s" : "")")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MiniStat(title: "Calories", value: TF.int(stats.averages.kcal), unit: "kcal", detail: known.kcal ? "objectif \(TF.int(stats.goal))" : nil, colorHex: accentHex)
                MiniStat(title: "Protéines", value: TF.int(stats.averages.protein), unit: "g")
                MiniStat(title: "Glucides", value: TF.int(stats.averages.carbs), unit: "g")
                MiniStat(title: "Lipides", value: TF.int(stats.averages.fat), unit: "g")
            }
            if known.kcal, !isSingleDay {
                Label("\(stats.daysOnTarget) jour\(stats.daysOnTarget > 1 ? "s" : "") sur \(stats.trackedDays) à moins de 10 % de ton objectif", systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func caloriesChart(_ stats: NutritionMath.PeriodStats, known: NutritionTiles.Targets) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: "Calories par jour")
            Chart {
                ForEach(DayValue.list(stats.days, stats.kcalPerDay)) { item in
                    BarMark(x: .value("Jour", item.date, unit: .day), y: .value("kcal", item.value))
                        .foregroundStyle(Color(hex: accentHex).gradient)
                        .cornerRadius(3)
                }
                if known.kcal {
                    RuleMark(y: .value("Objectif", stats.goal))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Objectif").font(.caption2).foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 200)
            .card()
        }
    }

    private func macroSplit(_ averages: NutritionTotals) -> some View {
        let kcal = max(averages.protein * 4 + averages.carbs * 4 + averages.fat * 9, 1)
        let parts = [
            MacroShare(name: "Protéines", share: averages.protein * 4 / kcal, hex: "E5484D"),
            MacroShare(name: "Glucides", share: averages.carbs * 4 / kcal, hex: "F2A33A"),
            MacroShare(name: "Lipides", share: averages.fat * 9 / kcal, hex: "3366FF"),
        ]
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: "Répartition des calories")
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(parts) { part in
                            Rectangle()
                                .fill(Color(hex: part.hex))
                                .frame(width: max(2, (geo.size.width - 4) * part.share))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 12)
                HStack {
                    ForEach(parts) { part in
                        HStack(spacing: 5) {
                            Circle().fill(Color(hex: part.hex)).frame(width: 8, height: 8)
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

    private func weightChart(_ weights: [ValuePoint]) -> some View {
        let values = weights.map(\.value)
        let low = (values.min() ?? 0) - 1
        let high = (values.max() ?? 0) + 1
        let change = (values.last ?? 0) - (values.first ?? 0)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: "Poids", detail: "\(change >= 0 ? "+" : "")\(TF.decimal(change, 1)) kg")
            Chart {
                ForEach(weights, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("kg", point.value))
                        .foregroundStyle(Color(hex: accentHex))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value("kg", point.value))
                        .foregroundStyle(Color(hex: accentHex))
                        .symbolSize(20)
                }
            }
            .chartYScale(domain: low...high)
            .frame(height: 160)
            .card()
            Text("Le poids vient de « Mes informations » : chaque nouvelle valeur s'ajoute ici.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func dayList(_ stats: NutritionMath.PeriodStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: "Jour par jour")
            MiniRowsCard {
                let days = Array(zip(stats.days, stats.kcalPerDay).reversed().prefix(31))
                ForEach(Array(days.enumerated()), id: \.offset) { index, pair in
                    NavigationLink(value: HomeRoute.page(.nutritionDay(pair.0))) {
                        MiniRow(symbol: "calendar", colorHex: accentHex, title: Fmt.shortDay(pair.0), detail: pair.1 > 0 ? nil : "Rien de noté", value: pair.1 > 0 ? "\(TF.int(pair.1)) kcal" : nil)
                    }
                    .buttonStyle(.plain)
                    if index < days.count - 1 { MiniDivider() }
                }
            }
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

    var body: some View {
        let saved = model.nutrition.savedMeals
        List {
            if saved.isEmpty {
                Section {
                    Text("Aucun repas enregistré. Ouvre un repas de ta journée et touche « Enregistrer ce repas » : il sera ici, prêt à reprendre d'une touche.")
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
                        Label("Ajouter à ma journée", systemImage: "plus.circle.fill")
                    }
                    Button(role: .destructive) {
                        let id = meal.id
                        model.update(\.nutrition) { $0.savedMeals.removeAll { $0.id == id } }
                    } label: {
                        Label("Supprimer ce repas", systemImage: "trash")
                    }
                } header: {
                    HStack {
                        Text(meal.name)
                        Spacer()
                        Text("\(TF.int(meal.totals.kcal)) kcal · P \(TF.int(meal.totals.protein)) g")
                    }
                }
            }
        }
        .styledList()
        .tint(Color(hex: MiniApp.nutrition.colorHex))
        .navigationTitle("Mes repas")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $logged) { meal in
            SavedMealLogSheet(saved: meal)
        }
    }
}
