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
                sheets?.open { NutritionGoalsEditor(goals: model.nutrition.goals) }
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
    @Environment(AppModel.self) private var model
    @State private var category: FoodCategory?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var online: [FoodItem] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var selected: FoodItem?
    @State private var showsScanner = false
    @State private var showsCustom = false
    @State private var scannedCode: String?
    @State private var createdFood: FoodItem?
    @State private var didOfferScanner = false
    /// What became of the last barcode scanned, shown at the top of the list.
    @State private var scan: ScanState?
    /// A custom food prefilled from a barcode (and the product's name when Open Food Facts has it).
    @State private var customDraft: FoodItem?

    private enum ScanState: Equatable {
        case looking(String)
        case notFound(String)
        case offline(String)
    }

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
        return filteredMine + builtin
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
                    HStack(spacing: 12) {
                        if DataScannerViewController.isSupported {
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
                if let scan {
                    Section {
                        scanRow(scan)
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
                if category == nil, !savedMeals.isEmpty {
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
                Section(category.map(\.title) ?? (query.trimmed.isEmpty ? tr("Suggestions") : tr("Résultats"))) {
                    ForEach(local.prefix(80)) { food in
                        foodRow(food)
                    }
                }
                if !query.trimmed.isEmpty {
                    Section {
                        if isSearching {
                            HStack { ProgressView(); Text(tr("Recherche sur Open Food Facts…")).foregroundStyle(Color.secondary) }
                        } else if let searchError {
                            HintRow(text: searchError)
                        } else if online.isEmpty {
                            Button(tr("Chercher « \(query.trimmed) » dans les produits emballés")) {
                                Task { await searchOnline() }
                            }
                        }
                        ForEach(online) { food in
                            foodRow(food)
                        }
                    } header: {
                        Text(tr("Produits emballés"))
                    } footer: {
                        Text(tr("Données Open Food Facts (ODbL), saisies par la communauté : vérifie l'étiquette."))
                    }
                }
            }
            .styledList()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Pomme, poulet, yogourt…"))
            .onSubmit(of: .search) { Task { await searchOnline() } }
            .onChange(of: query) { _, _ in
                online = []
                searchError = nil
            }
            .navigationTitle(tr("Ajouter un aliment"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if startsWithScanner && !didOfferScanner {
                    didOfferScanner = true
                    showsScanner = DataScannerViewController.isSupported && DataScannerViewController.isAvailable
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
            // The quantity sheet opens once the scanner or the new food has closed:
            // a sheet asked for while another one is still closing would not open.
            .sheet(isPresented: $showsScanner, onDismiss: lookupScanned) {
                NavigationStack {
                    BarcodeScannerView { code in
                        scannedCode = code
                        showsScanner = false
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(tr("Scanner un aliment"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(tr("Annuler")) { showsScanner = false }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        // No barcode, or a product the database doesn't know: the search is one tap away.
                        Button {
                            showsScanner = false
                        } label: {
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
            .sheet(isPresented: $showsCustom, onDismiss: logCreatedFood) {
                CustomFoodEditor(draft: customDraft) { food in
                    createdFood = food
                }
            }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        Button {
            selected = food
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

    private func searchOnline() async {
        let text = query.trimmed
        guard text.count >= 2 else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            online = try await OpenFoodFacts.search(text)
            if online.isEmpty { searchError = tr("Aucun produit trouvé pour « \(text) ».") }
        } catch {
            searchError = tr("Open Food Facts ne répond pas. Réessaie dans un instant.")
        }
    }

    private func lookupScanned() {
        guard let code = scannedCode else { return }
        scannedCode = nil
        Task { await lookup(code) }
    }

    private func logCreatedFood() {
        customDraft = nil
        guard let food = createdFood else { return }
        createdFood = nil
        selected = food
    }

    /// A scanned barcode: a food already saved with it (no connection needed), else Open Food Facts.
    /// Every outcome shows something: the food, a custom food to complete, or what to do next.
    private func lookup(_ code: String) async {
        let mine = model.nutrition.customFoods + model.nutrition.favorites + model.nutrition.recentFoods
        if let known = mine.first(where: { $0.barcode.map(OpenFoodFacts.barcodeForms)?.contains(code) == true }) {
            scan = nil
            selected = known
            return
        }
        scan = .looking(code)
        do {
            switch try await OpenFoodFacts.lookup(barcode: code) {
            case .food(let food):
                scan = nil
                selected = food
            case .partial(let draft):
                scan = nil
                customDraft = draft
                showsCustom = true
            case .unknown:
                scan = .notFound(code)
            }
        } catch {
            scan = .offline(code)
        }
    }

    @ViewBuilder
    private func scanRow(_ state: ScanState) -> some View {
        switch state {
        case .looking(let code):
            HStack(spacing: 10) {
                ProgressView()
                Text(tr("Recherche du produit \(code)…")).foregroundStyle(Color.secondary)
            }
        case .notFound(let code), .offline(let code):
            let offline = state == .offline(code)
            VStack(alignment: .leading, spacing: 10) {
                Label(offline ? tr("Pas de connexion : le produit \(code) n'a pas pu être cherché.")
                              : tr("Le produit \(code) n'est pas encore dans Open Food Facts."),
                      systemImage: offline ? "wifi.slash" : "barcode")
                    .font(.subheadline)
                Text(tr("Crée-le avec les valeurs de l'étiquette : le prochain scan le retrouvera."))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                HStack(spacing: 10) {
                    Button(tr("Créer cet aliment")) {
                        customDraft = FoodItem(id: "custom.draft", name: "", brand: nil, kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0,
                                               servingGrams: 100, servingName: "100 g", source: .custom, barcode: code)
                        showsCustom = true
                    }
                    .buttonStyle(.borderedProminent)
                    if offline {
                        Button(tr("Réessayer")) { Task { await lookup(code) } }
                            .buttonStyle(.bordered)
                    } else {
                        Button(tr("Scanner à nouveau")) {
                            scan = nil
                            showsScanner = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 4)
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
        SheetForm(title: food.name, canSave: grams > 0, dismissesOnSave: onDone == nil, onSave: save) {
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
                ValueRow(title: tr("Protéines"), value: "\(TF.decimal(totals.protein, 1)) g")
                ValueRow(title: tr("Glucides"), value: "\(TF.decimal(totals.carbs, 1)) g")
                ValueRow(title: tr("Lipides"), value: "\(TF.decimal(totals.fat, 1)) g")
                ValueRow(title: tr("Fibres"), value: "\(TF.decimal(totals.fiber, 1)) g")
                if let sugars = totals.sugars { ValueRow(title: tr("Sucres"), value: "\(TF.decimal(sugars, 1)) g") }
                if let saturated = totals.saturatedFat { ValueRow(title: tr("Gras saturés"), value: "\(TF.decimal(saturated, 1)) g") }
                if let sodium = totals.sodiumMg { ValueRow(title: tr("Sodium"), value: tr("\(TF.int(sodium)) mg")) }
                if let cholesterol = totals.cholesterolMg { ValueRow(title: tr("Cholestérol"), value: tr("\(TF.int(cholesterol)) mg")) }
            }
        }
        .onAppear {
            grams = food.servingGrams > 0 ? food.servingGrams : 100
            meal = presetMeal ?? .current()
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
        Haptics.success()
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
        Haptics.success()
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
    @State private var name = ""
    @State private var kcal: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var fiber: Double = 0
    @State private var serving: Double = 100

    var body: some View {
        SheetForm(title: tr("Aliment perso"), canSave: !name.trimmed.isEmpty, onSave: save) {
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
            Section(tr("Pour 100 g")) {
                NumberRow(title: tr("Calories"), value: $kcal, unit: "kcal")
                NumberRow(title: tr("Protéines"), value: $protein, unit: "g")
                NumberRow(title: tr("Glucides"), value: $carbs, unit: "g")
                NumberRow(title: tr("Lipides"), value: $fat, unit: "g")
                NumberRow(title: tr("Fibres"), value: $fiber, unit: "g")
            }
        }
        .onAppear {
            if let draft, name.isEmpty { name = draft.name }
        }
    }

    private func save() {
        let food = FoodItem(id: "custom.\(UUID().uuidString)", name: name.trimmed, brand: draft?.brand, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber,
                            servingGrams: max(1, serving), servingName: "\(TF.int(serving)) g", source: .custom, barcode: draft?.barcode)
        model.update(\.nutrition) { $0.customFoods.insert(food, at: 0) }
        onCreate(food)
    }
}

struct NutritionGoalsEditor: View {
    @Environment(AppModel.self) private var model
    @State var goals: NutritionGoals
    @State private var sex: NutritionCalculator.Sex = .female
    @State private var age = 30
    @State private var height: Double = 168
    @State private var weight: Double = 65
    @State private var activity: NutritionCalculator.Activity = .light
    @State private var goal: NutritionCalculator.Goal = .maintain
    @State private var usedCalculator = false

    var body: some View {
        SheetForm(title: tr("Objectifs"), onSave: save) {
            Section(tr("Par jour")) {
                NumberRow(title: tr("Calories"), value: $goals.kcal, unit: "kcal")
                NumberRow(title: tr("Protéines"), value: $goals.protein, unit: "g")
                NumberRow(title: tr("Glucides"), value: $goals.carbs, unit: "g")
                NumberRow(title: tr("Lipides"), value: $goals.fat, unit: "g")
                NumberRow(title: tr("Fibres"), value: $goals.fiber, unit: "g")
            }
            Section {
                Picker(tr("Référence"), selection: $sex) {
                    ForEach(NutritionCalculator.Sex.allCases) { Text($0.title).tag($0) }
                }
                Stepper(tr("Âge : \(age) ans"), value: $age, in: 16...90)
                NumberRow(title: tr("Taille", context: "height"), value: $height, unit: tr("cm"))
                NumberRow(title: tr("Poids"), value: $weight, unit: tr("kg"))
                Picker(tr("Activité"), selection: $activity) {
                    ForEach(NutritionCalculator.Activity.allCases) { Text($0.title).tag($0) }
                }
                Picker(tr("But"), selection: $goal) {
                    ForEach(NutritionCalculator.Goal.allCases) { Text($0.title).tag($0) }
                }
                Button(tr("Calculer mes objectifs")) {
                    goals = NutritionCalculator.goals(sex: sex, age: age, heightCm: height, weightKg: weight, activity: activity, goal: goal)
                    usedCalculator = true
                }
            } header: {
                Text(tr("Calculateur"))
            } footer: {
                Text(tr("Estimation Mifflin-St Jeor, à ajuster selon tes sensations. Ce n'est pas un avis médical. Âge, taille et poids viennent de « Mes informations » et y sont gardés."))
            }
        }
        .onAppear(perform: prefill)
    }

    /// The calculator starts from what the user already gave in « Mes informations ».
    private func prefill() {
        let profile = model.profile
        if let known = profile.calculatorSex { sex = known }
        if let known = model.age { age = min(90, max(16, known)) }
        if let known = profile.heightCm { height = known }
        if let known = profile.weightKg { weight = known }
        if let known = model.activityFromWorkouts { activity = known }
        if let aim = profile.nutritionAim ?? profile.fitnessGoal?.nutritionAim { goal = aim.calculatorGoal }
    }

    private func save() {
        model.setNutritionGoals(goals, calculatedWith: usedCalculator ? activity : nil)
        // Values used for a calculation are the user's own: every widget gets them.
        guard usedCalculator else { return }
        let aim: NutritionAim = switch goal {
        case .lose: .lose
        case .maintain: .maintain
        case .gain: .gain
        }
        model.update(\.profile) { profile in
            // The gender stays the user's own words; only the formula's reference changes.
            if let current = profile.sex, !current.isBinary {
                profile.calculationSex = sex == .neutral ? nil : sex
            } else {
                switch sex {
                case .female: profile.sex = .female
                case .male: profile.sex = .male
                case .neutral: if profile.sex == nil { profile.sex = .undisclosed }
                }
            }
            profile.heightCm = height
            if profile.weightKg != weight { profile.recordWeight(weight) }
            profile.nutritionAim = aim
        }
        if model.life.birthday == nil { model.setAge(age) }
    }
}

// MARK: - Barcode scanner

/// Live barcode scanning with VisionKit (devices with a camera and iOS 16+).
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                    didScan = true
                    dataScanner.stopScanning()
                    onScan(value)
                    return
                }
            }
        }
    }
}
