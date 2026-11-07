import SwiftUI
import Vision
import VisionKit

struct NutritionSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    var body: some View {
        let now = Date()
        let state = model.nutrition
        let totals = NutritionMath.totals(state, on: now)
        let known = NutritionTiles.Targets(model.profile)
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(TF.int(known.kcal ? max(0, state.goals.kcal - totals.kcal) : totals.kcal))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(known.kcal ? tr("kcal restantes") : tr("kcal mangées")).foregroundStyle(Color.secondary)
                    Spacer()
                    if known.kcal {
                        Text("\(TF.int(totals.kcal)) / \(TF.int(state.goals.kcal))")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                            .monospacedDigit()
                    }
                }
                if known.kcal {
                    ProgressView(value: min(1, totals.kcal / max(1, state.goals.kcal)))
                        .accessibilityLabel(tr("Calories"))
                        .accessibilityValue(Fmt.percent(min(1, totals.kcal / max(1, state.goals.kcal))))
                        .tint(Color(hex: "FF6B57"))
                }
                ForEach(NutritionTiles.macroRows(totals, goals: state.goals, known: known)) { row in
                    HStack {
                        Circle().fill(Color(hex: row.colorHex ?? "999999")).frame(width: 8, height: 8)
                        Text(row.title).font(.subheadline)
                        Spacer()
                        Text(row.value ?? "").font(.subheadline).foregroundStyle(Color.secondary).monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)
            if DataScannerViewController.isSupported {
                Button {
                    sheets?.open { FoodSearchView(startsWithScanner: true) }
                } label: {
                    Label(tr("Scanner un code-barres"), systemImage: "barcode.viewfinder")
                }
            }
            Button {
                sheets?.open { FoodSearchView() }
            } label: {
                Label(tr("Ajouter un aliment"), systemImage: "plus.circle.fill")
                    .font(.headline)
            }
        } header: {
            Text(tr("Aujourd'hui"))
        }

        ForEach(MealType.allCases) { meal in
            let entries = NutritionMath.entries(state, on: now).filter { $0.meal == meal }
            if !entries.isEmpty {
                Section(meal.title) {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.food.displayName).lineLimit(1)
                                Text("\(TF.int(entry.grams)) g").font(.caption).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Text(tr("\(TF.int(entry.totals.kcal)) kcal")).foregroundStyle(Color.secondary).monospacedDigit()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                model.update(\.nutrition) { $0.entries.removeAll { $0.id == entry.id } }
                            } label: {
                                Label(tr("Supprimer"), systemImage: "trash")
                            }
                            Button {
                                toggleFavorite(entry.food)
                            } label: {
                                Label(tr("Favori"), systemImage: "star")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }

        Section {
            ForEach(state.favorites) { food in
                ValueRow(title: food.displayName, value: tr("\(TF.int(food.nutrients(grams: food.servingGrams).kcal)) kcal"), symbol: "star.fill", colorHex: "F2A33A")
            }
            .onDelete { offsets in
                model.update(\.nutrition) { $0.favorites.remove(atOffsets: offsets) }
            }
            if state.favorites.isEmpty {
                HintRow(text: tr("Glisse un aliment vers la gauche pour l'ajouter aux favoris. Le widget Ajout rapide les propose d'une touche."))
            }
        } header: {
            Text(tr("Favoris"))
        }

        Section {
            Button {
                sheets?.open { TopicEditorSheet(topic: .nutrition) }
            } label: {
                ValueRow(title: tr("Objectifs du jour"), value: known.kcal ? tr("\(TF.int(state.goals.kcal)) kcal · \(TF.int(state.goals.protein)) g prot.") : tr("À définir"), symbol: "target")
            }
            .tint(.primary)
            if let average = NutritionMath.average(state, days: 7, until: now) {
                ValueRow(title: tr("Moyenne sur 7 jours"), value: tr("\(TF.int(average)) kcal"), symbol: "chart.bar")
            }
            ValueRow(title: tr("Série de suivi"), value: Fmt.plural(NutritionMath.trackingStreak(state, until: now), tr("jour"), tr("jours")), symbol: "flame.fill")
        } header: {
            Text(tr("Objectifs"))
        } footer: {
            Text(tr("Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL)."))
        }
    }

    private func toggleFavorite(_ food: FoodItem) {
        model.update(\.nutrition) { state in
            if state.favorites.contains(where: { $0.id == food.id }) {
                state.favorites.removeAll { $0.id == food.id }
            } else {
                state.favorites.insert(food, at: 0)
            }
        }
    }
}

// MARK: - Food search

struct FoodSearchView: View {
    /// Opens the camera at once (from a Nutrition widget). Without a camera, the search is shown.
    var startsWithScanner = false
    /// The meal the food goes to (chosen from a meal of the Nutrition mini-app), else the current one.
    var presetMeal: MealType? = nil
    /// The day the food is added to (today, or a day browsed in the mini-app).
    var day: Date = Date()
    /// Selection mode (from the recap of a scan): the food touched is handed back instead of being logged,
    /// and the search closes. No scanner and no saved meals then.
    var onPick: ((FoodItem) -> Void)? = nil
    @Environment(AppModel.self) private var model
    @State private var category: FoodCategory?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var online: [FoodItem] = []
    /// The online search in flight (nil when none): cancelled as soon as the words change, so that a new search is
    /// never ignored while the old one waits for the service (up to its 15 s timeout).
    @State private var searchTask: Task<Void, Never>?
    /// The words of the search in flight (nil when none): a second tap on the same words does not ask again.
    @State private var searchingText: String?
    /// The number of the last search started or dropped: an old one that ends late touches nothing on screen.
    @State private var searchNumber = 0
    private var isSearching: Bool { searchingText != nil }
    @State private var searchError: String?
    /// The last online search failed (busy service, no answer): a button offers to ask again.
    @State private var canRetrySearch = false
    @State private var selected: FoodItem?
    @State private var showsScanner = false
    @State private var showsCustom = false
    /// How the scanner closed, handled once its sheet is gone.
    @State private var scanOutcome: FoodScanOutcome?
    @State private var createdFood: FoodItem?
    @State private var didOfferScanner = false
    /// A custom food prefilled from a barcode (and the product's name when Open Food Facts has it).
    @State private var customDraft: FoodItem?

    private var local: [FoodItem] {
        if let category, query.trimmed.isEmpty {
            return FoodDatabase.foods(in: category)
        }
        let recent = model.nutrition.favorites + model.nutrition.recentFoods + model.nutrition.customFoods
        var seen = Set<String>()
        let mine = recent.filter { seen.insert($0.id).inserted }
        let q = FoodDatabase.normalized(query)
        let filteredMine = q.isEmpty ? mine : mine.filter { FoodDatabase.normalized($0.name).contains(q) }
        let builtin = FoodDatabase.search(query).filter { !seen.contains($0.id) }
        // Thousands of generic foods (Canadian Nutrient File) after the everyday ones.
        let generic = q.isEmpty ? [] : NutrientFile.search(query)
        return filteredMine + builtin + generic
    }

    /// Saved meals, offered first when nothing is typed: a whole meal in one tap.
    private var savedMeals: [SavedMeal] {
        let q = FoodDatabase.normalized(query)
        return model.nutrition.savedMeals.filter { q.isEmpty || FoodDatabase.normalized($0.name).contains(q) }
    }

    @State private var loggedMeal: SavedMeal?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if DataScannerViewController.isSupported, onPick == nil {
                            Button {
                                showsScanner = true
                            } label: {
                                Label(tr("Scanner"), systemImage: "barcode.viewfinder")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            customDraft = nil
                            showsCustom = true
                        } label: {
                            Label(tr("Aliment perso"), systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                    }
                }
                if query.trimmed.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: tr("Pour toi"), isSelected: category == nil) { category = nil }
                                ForEach(FoodCategory.allCases) { item in
                                    FilterChip(title: item.title, symbol: item.symbol, isSelected: category == item) {
                                        category = category == item ? nil : item
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listRowBackground(Color.clear)
                }
                if category == nil, onPick == nil, !savedMeals.isEmpty {
                    Section(tr("Mes repas")) {
                        ForEach(savedMeals) { saved in
                            Button {
                                loggedMeal = saved
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(saved.name).foregroundStyle(Color.primary).lineLimit(1)
                                        Text(saved.items.map(\.food.name).joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(tr("\(TF.int(saved.totals.kcal)) kcal")).font(.subheadline).foregroundStyle(Color.secondary).monospacedDigit()
                                    Image(systemName: "plus.circle").foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
                Section {
                    ForEach(local.prefix(80)) { food in
                        foodRow(food)
                    }
                } header: {
                    Text(category.map(\.title) ?? (query.trimmed.isEmpty ? tr("Suggestions") : tr("Résultats")))
                } footer: {
                    if !query.trimmed.isEmpty, local.contains(where: { $0.source == .nutrientFile }) {
                        Text(NutrientFile.attribution)
                    }
                }
                if !query.trimmed.isEmpty {
                    Section {
                        if isSearching {
                            HStack { ProgressView(); Text(tr("Recherche sur Open Food Facts…")).foregroundStyle(Color.secondary) }
                        } else if let searchError {
                            HintRow(text: searchError)
                            if canRetrySearch {
                                Button(tr("Réessayer")) { startSearch() }
                            }
                        } else if online.isEmpty {
                            Button(tr("Chercher « \(query.trimmed) » dans les produits emballés")) {
                                startSearch()
                            }
                        }
                        ForEach(online) { food in
                            foodRow(food)
                        }
                    } header: {
                        Text(tr("Produits emballés"))
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tr("Données Open Food Facts (ODbL), saisies par la communauté : vérifie l'étiquette."))
                            HStack(spacing: 12) {
                                Link(destination: FoodSourceLinks.openFoodFacts) { Text(verbatim: "openfoodfacts.org") }
                                Link(destination: FoodSourceLinks.odbl) { Text(verbatim: "ODbL") }
                            }
                        }
                    }
                }
            }
            .styledList()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Pomme, poulet, yogourt…"))
            // The packaged products are searched on Open Food Facts only when the person asks: the button of the
            // « Produits emballés » section, or the keyboard's search key. Never while typing (Open Food Facts
            // forbids search-as-you-type and limits searches per address).
            .onSubmit(of: .search) { startSearch() }
            .onChange(of: query) { _, _ in
                // Other words: the search in flight is for the old ones. It is dropped now, not at the end of its
                // timeout, so that the next search leaves at once.
                if let searchingText, searchingText != query.trimmed { cancelSearch() }
                online = []
                searchError = nil
                canRetrySearch = false
            }
            .navigationTitle(tr("Ajouter un aliment"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if startsWithScanner && !didOfferScanner {
                    didOfferScanner = true
                    // Not `isAvailable`: it is false until the camera is allowed, and the scanner screen
                    // explains the permission first.
                    showsScanner = onPick == nil && DataScannerViewController.isSupported
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Fermer")) { dismiss() }
                }
            }
            .sheet(item: $selected) { food in
                FoodLogSheet(food: food, presetMeal: presetMeal, day: day) { dismiss() }
            }
            .sheet(item: $loggedMeal) { saved in
                SavedMealLogSheet(saved: saved, presetMeal: presetMeal, day: day) { dismiss() }
            }
            // The scanner (barcode or dish, then the recap) is one screen. A food to create opens once it has
            // closed: a sheet asked for while another one is still closing would not open.
            .sheet(isPresented: $showsScanner, onDismiss: afterScan) {
                FoodScanView(presetMeal: presetMeal, day: day) { outcome in
                    if case .logged = outcome {
                        // The foods are in the journal: this search closes with the scanner, in one motion.
                        dismiss()
                    } else {
                        scanOutcome = outcome
                        showsScanner = false
                    }
                }
            }
            .sheet(isPresented: $showsCustom, onDismiss: logCreatedFood) {
                CustomFoodEditor(draft: customDraft) { food in
                    createdFood = food
                }
            }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        Button {
            if let onPick {
                onPick(food)
                dismiss()
            } else {
                selected = food
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.displayName).foregroundStyle(Color.primary).lineLimit(1)
                    Text(FoodText.summary(food))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(.tint)
            }
        }
        .accessibilityIdentifier("food-row")
    }

    /// Asks Open Food Facts for the words typed. The search in flight is dropped first (it can only be for other
    /// words: for the same ones, nothing starts again).
    private func startSearch() {
        let text = query.trimmed
        guard text.count >= 2, searchingText != text else { return }
        cancelSearch()
        let number = searchNumber
        searchingText = text
        searchError = nil
        canRetrySearch = false
        searchTask = Task { await searchOnline(text, number: number) }
    }

    /// Drops the search in flight: its answer would be for words that are no longer on screen.
    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchNumber += 1
        searchingText = nil
    }

    @MainActor
    private func searchOnline(_ text: String, number: Int) async {
        // Still the search the screen waits for: not cancelled, no newer search, the words did not change.
        func isCurrent() -> Bool { !Task.isCancelled && searchNumber == number && query.trimmed == text }
        defer { if searchNumber == number { searchingText = nil } }
        do {
            let found = try await OpenFoodFacts.search(text)
            // A stale answer is for other words: it is thrown away.
            guard isCurrent() else { return }
            online = found
            if online.isEmpty { searchError = tr("Aucun produit trouvé pour « \(text) ».") }
        } catch OpenFoodFacts.Failure.busy {
            guard isCurrent() else { return }
            searchError = tr("Open Food Facts reçoit trop de demandes en ce moment. Réessaie dans un instant.")
            canRetrySearch = true
        } catch {
            guard isCurrent() else { return }
            searchError = tr("Open Food Facts ne répond pas. Réessaie dans un instant.")
            canRetrySearch = true
        }
    }

    /// The scanner closed without logging: a food to create opens now (a product the database doesn't know,
    /// with its barcode). Back to the search otherwise.
    private func afterScan() {
        guard let outcome = scanOutcome else { return }
        scanOutcome = nil
        if case .create(let draft) = outcome {
            customDraft = draft
            showsCustom = true
        }
    }

    private func logCreatedFood() {
        customDraft = nil
        guard let food = createdFood else { return }
        createdFood = nil
        if let onPick {
            onPick(food)
            dismiss()
        } else {
            selected = food
        }
    }
}

/// A food's nutrition, then the quantity and the meal, then it's added: the scanner and the search
/// both end here.
struct FoodLogSheet: View {
    let food: FoodItem
    var presetMeal: MealType? = nil
    var day: Date = Date()
    /// Closes the food search too, when logging from it: one motion instead of two sheets closing in turn.
    var onDone: (() -> Void)?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 100
    @State private var meal: MealType = .current()

    var body: some View {
        let totals = food.nutrients(grams: grams)
        let known = NutritionTiles.Targets(model.profile)
        let left = model.nutrition.goals.kcal - NutritionMath.totals(model.nutrition, on: day).kcal - totals.kcal
        SheetForm(title: food.name, canSave: grams > 0 && grams <= NutritionState.maxGrams, dismissesOnSave: onDone == nil, onSave: save) {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    if let brand = food.brand, !brand.isEmpty {
                        Text(brand).font(.subheadline.weight(.semibold)).foregroundStyle(Color.secondary)
                    }
                    Text(tr("Pour 100 g : \(TF.int(food.kcal)) kcal · protéines \(TF.decimal(food.protein, 1)) g · glucides \(TF.decimal(food.carbs, 1)) g · lipides \(TF.decimal(food.fat, 1)) g"))
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section {
                NumberRow(title: tr("Quantité"), value: $grams, unit: "g")
                    .accessibilityIdentifier("food-grams")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(portions) { portion in
                            FilterChip(title: portion.title, isSelected: abs(grams - portion.grams) < 0.5) { grams = portion.grams }
                        }
                    }
                }
                Picker(tr("Repas"), selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            } footer: {
                if known.kcal {
                    Text(left >= 0 ? tr("Après ajout, il te restera \(TF.int(left)) kcal.") : tr("Après ajout, tu dépasseras ton objectif de \(TF.int(-left)) kcal."))
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
            // Sugars, fats, sodium, minerals, vitamins…: only the values the food gives (Premium).
            if model.isPremium {
                FoodNutrientSections(totals: totals)
            }
        }
        .onAppear {
            grams = food.servingGrams > 0 ? food.servingGrams : 100
            meal = presetMeal ?? .current()
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

    private struct Portion: Identifiable {
        let title: String
        let grams: Double
        var id: String { title }
    }

    /// Quick quantities: half, one or two usual portions, and 100 g.
    private var portions: [Portion] {
        let serving = food.servingGrams > 0 ? food.servingGrams : 100
        var list = [
            Portion(title: tr("½ portion"), grams: (serving / 2).rounded()),
            Portion(title: food.servingName.isEmpty ? tr("1 portion") : food.servingName, grams: serving),
            Portion(title: tr("2 portions"), grams: serving * 2),
        ]
        if abs(serving - 100) > 1 { list.append(Portion(title: "100 g", grams: 100)) }
        return list
    }

    private func save() {
        let amount = grams
        let chosen = meal
        let date = NutritionMath.entryDate(for: chosen, on: day)
        model.update(\.nutrition) { $0.log(food, grams: amount, meal: chosen, at: date) }
        Haptics.tap()
        onDone?()
    }
}

/// A saved meal logged in one go, into the meal chosen.
struct SavedMealLogSheet: View {
    let saved: SavedMeal
    var presetMeal: MealType? = nil
    var day: Date = Date()
    var onDone: (() -> Void)?
    @Environment(AppModel.self) private var model
    @State private var meal: MealType = .current()

    var body: some View {
        let totals = saved.totals
        SheetForm(title: saved.name, dismissesOnSave: onDone == nil, onSave: save) {
            Section {
                Picker(tr("Repas"), selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            }
            Section(tr("Aliments")) {
                ForEach(Array(saved.items.enumerated()), id: \.offset) { _, item in
                    ValueRow(title: item.food.name, value: "\(TF.int(item.grams)) g")
                }
            }
            Section(tr("Apport")) {
                ValueRow(title: tr("Calories"), value: tr("\(TF.int(totals.kcal)) kcal"))
                ValueRow(title: tr("Protéines"), value: "\(TF.decimal(totals.protein, 1)) g")
                ValueRow(title: tr("Glucides"), value: "\(TF.decimal(totals.carbs, 1)) g")
                ValueRow(title: tr("Lipides"), value: "\(TF.decimal(totals.fat, 1)) g")
            }
        }
        .onAppear { meal = presetMeal ?? .current() }
    }

    private func save() {
        let chosen = meal
        let items = saved.items
        let target = day
        model.update(\.nutrition) { $0.log(items, meal: chosen, on: target) }
        Haptics.tap()
        onDone?()
    }
}

enum FoodText {
    /// "165 kcal / 100 g · P 31 · G 0 · L 4": the line under a food in lists.
    static func summary(_ food: FoodItem) -> String {
        tr("\(TF.int(food.kcal)) kcal / 100 g · P \(TF.int(food.protein)) · G \(TF.int(food.carbs)) · L \(TF.int(food.fat))")
    }

    /// "1 portion · 120 g · 198 kcal"
    static func portion(_ food: FoodItem, grams: Double) -> String {
        tr("\(TF.int(grams)) g · \(TF.int(food.nutrients(grams: grams).kcal)) kcal")
    }
}

struct CustomFoodEditor: View {
    /// Prefill from a scan: the barcode, and the product's name and brand when they are known.
    var draft: FoodItem? = nil
    var onCreate: (FoodItem) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kcal: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double = 0
    @State private var serving: Double = 100
    // The other lines of a nutrition label (Premium): left empty, a value stays unknown.
    @State private var sugars: Double?
    @State private var saturatedFat: Double?
    @State private var transFat: Double?
    @State private var cholesterolMg: Double?
    @State private var sodiumMg: Double?
    @State private var potassiumMg: Double?
    @State private var calciumMg: Double?
    @State private var ironMg: Double?
    @State private var confirming = false

    /// What forbids saving (a negative or impossible value), if anything.
    private var blocking: CustomFoodValidation.Problem? {
        if !serving.isFinite || serving <= 0 || serving > NutritionState.maxGrams { return .outOfRange }
        return CustomFoodValidation.blockingProblem(kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber)
    }

    /// What the person has to confirm (0 kcal, an energy far from the macros), if anything.
    private var warning: CustomFoodValidation.Problem? {
        CustomFoodValidation.warning(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    var body: some View {
        SheetForm(title: tr("Aliment perso"), canSave: !name.trimmed.isEmpty && blocking == nil, dismissesOnSave: false, onSave: save) {
            Section {
                TextField(tr("Nom"), text: $name)
                NumberRow(title: tr("Portion"), value: $serving, unit: "g")
            } footer: {
                if let draft, draft.barcode != nil {
                    Text(draft.name.isEmpty
                         ? tr("Le code-barres est retenu : le prochain scan retrouvera cet aliment.")
                         : tr("Open Food Facts connaît ce produit, mais pas ses valeurs nutritives : recopie-les depuis l'étiquette."))
                }
            }
            Section {
                NumberRow(title: tr("Calories"), value: $kcal, unit: "kcal")
                NumberRow(title: tr("Protéines"), value: $protein, unit: "g")
                NumberRow(title: tr("Glucides"), value: $carbs, unit: "g")
                NumberRow(title: tr("Lipides"), value: $fat, unit: "g")
                if model.isPremium {
                    NumberRow(title: tr("Fibres"), value: $fiber, unit: "g")
                    OptionalNumberRow(title: Nutrient.sugars.title, value: $sugars, unit: Nutrient.sugars.unit)
                    OptionalNumberRow(title: Nutrient.saturatedFat.title, value: $saturatedFat, unit: Nutrient.saturatedFat.unit)
                    OptionalNumberRow(title: Nutrient.transFat.title, value: $transFat, unit: Nutrient.transFat.unit)
                    OptionalNumberRow(title: Nutrient.cholesterol.title, value: $cholesterolMg, unit: Nutrient.cholesterol.unit)
                    OptionalNumberRow(title: Nutrient.sodium.title, value: $sodiumMg, unit: Nutrient.sodium.unit)
                    OptionalNumberRow(title: Nutrient.potassium.title, value: $potassiumMg, unit: Nutrient.potassium.unit)
                    OptionalNumberRow(title: Nutrient.calcium.title, value: $calciumMg, unit: Nutrient.calcium.unit)
                    OptionalNumberRow(title: Nutrient.iron.title, value: $ironMg, unit: Nutrient.iron.unit)
                } else {
                    NutrientLockRow()
                }
            } header: {
                Text(tr("Pour 100 g"))
            } footer: {
                if let message = CustomFoodEditForm.message(for: blocking) {
                    Text(message).foregroundStyle(Color.red)
                }
            }
        }
        .onAppear {
            if let draft, name.isEmpty { name = draft.name }
        }
        .alert(tr("Enregistrer quand même ?"), isPresented: $confirming) {
            Button(tr("Annuler"), role: .cancel) {}
            Button(tr("Enregistrer")) { commit() }
        } message: {
            Text(CustomFoodEditForm.message(for: warning) ?? "")
        }
    }

    private func save() {
        guard blocking == nil, !name.trimmed.isEmpty else { return }
        if warning != nil {
            confirming = true
        } else {
            commit()
        }
    }

    private func commit() {
        guard blocking == nil else { return }
        let micros = Micronutrients(potassiumMg: potassiumMg, calciumMg: calciumMg, ironMg: ironMg, transFat: transFat)
        let food = FoodItem(id: "custom.\(UUID().uuidString)", name: name.trimmed, brand: draft?.brand, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber,
                            servingGrams: max(1, serving), servingName: "\(TF.int(serving)) g", source: .custom, barcode: draft?.barcode,
                            sugars: sugars, saturatedFat: saturatedFat, sodiumMg: sodiumMg, cholesterolMg: cholesterolMg,
                            micros: micros.isEmpty ? nil : micros)
        model.update(\.nutrition) { $0.customFoods.insert(food, at: 0) }
        onCreate(food)
        dismiss()
    }
}

// MARK: - Barcode scanner

/// The aiming rectangle (photo format 3:4, 16 pt margins), the camera dimmed around it; what is inside is
/// what gets analysed (also used by `FoodScanView`). It is laid out in the area the overlay gets, which is
/// already the space between the navigation bar and the bottom controls (`safeAreaInset`): as tall as the
/// photo format allows there, 16 pt from each edge. The veil alone goes on under the bottom controls, so the
/// camera is dimmed evenly down to the bottom of the screen.
struct ScanFrame: View {
    private let margin: CGFloat = 16
    private let radius: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width - margin * 2, 120)
            let height = max(min(width * 4 / 3, geo.size.height - margin * 2), 160)
            let rect = CGRect(x: (geo.size.width - width) / 2, y: margin, width: width, height: height)
            ZStack {
                // Only the bottom edge goes further: the top-left corner stays the one of `geo`, so `rect` holds.
                ScanVeil(hole: rect, radius: radius)
                    .fill(Color.black.opacity(0.30), style: FillStyle(eoFill: true))
                    .ignoresSafeArea(edges: .bottom)
                ScanCorners(radius: radius)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                HStack(spacing: 8) {
                    Image(systemName: "barcode")
                    Image(systemName: "fork.knife")
                    Text(tr("Vise un code-barres ou ton assiette"))
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.45), in: Capsule())
                .frame(maxWidth: rect.width - 40)
                .position(x: rect.midX, y: rect.minY + 12 + 22)
                .accessibilityElement(children: .combine)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The round grey cross that replaces « Annuler » on the camera step.
struct ScanCloseLabel: View {
    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.secondary)
            .frame(width: 32, height: 32)
            .background(Color.secondary.opacity(0.18), in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

#if DEBUG
/// Test builds (`-screenshotScreen scan-frame`): the barcode scanner as it opens on an iPhone, built
/// like the scanner sheet of `FoodSearchView` (same title, « Annuler », aiming square and search button,
/// same modifiers), with a plain camera area since the simulator has no camera: black, or white with
/// `-marketingScreen white` (the two captures give the overlay's transparency by difference). The ad
/// films put a product behind it.
struct ScanFrameScreenshot: View {
    var body: some View {
        NavigationStack {
            cameraArea
                .ignoresSafeArea(edges: .bottom)
                .overlay { ScanFrame() }
                .navigationTitle(tr("Code-barres ou aliments"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {} label: { ScanCloseLabel() }
                            .accessibilityLabel(tr("Annuler"))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button {} label: {
                        Label(tr("Chercher ou créer l'aliment"), systemImage: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .padding(.bottom, 12)
                }
        }
    }

    private var cameraArea: Color {
        UserDefaults.standard.string(forKey: "marketingScreen") == "white" ? .white : .black
    }
}

/// `-screenshotScreen scan-frame`: « Ajouter un aliment » opened over the Nutrition mini-app, then the
/// scanner over it, as on an iPhone where « Scanner » opens the camera at once.
struct ScanFrameScreenshotStage: View {
    @State private var showsSearch = false
    @State private var showsScanner = false

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .sheet(isPresented: $showsSearch) {
                FoodSearchView(startsWithScanner: true)
                    .sheet(isPresented: $showsScanner) {
                        ScanFrameScreenshot()
                    }
            }
            .task {
                // After the mini-app is pushed (ScreenshotMode opens it at 0.7 s), one sheet at a time.
                try? await Task.sleep(for: .milliseconds(1_600))
                showsSearch = true
                try? await Task.sleep(for: .milliseconds(1_200))
                showsScanner = true
            }
    }
}
#endif

/// The dimmed camera around the aiming rectangle: all of its own frame, less `hole` (even-odd fill).
private struct ScanVeil: Shape {
    let hole: CGRect
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return path
    }
}

/// The four rounded corners of the scanning square.
private struct ScanCorners: Shape {
    var radius: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        let radius = self.radius
        let arm = min(44, max(radius, min(rect.width, rect.height) / 2 - 4))
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * arm))
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + dy * radius))
            path.addQuadCurve(to: CGPoint(x: corner.x + dx * radius, y: corner.y), control: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * arm, y: corner.y))
        }
        return path
    }
}
