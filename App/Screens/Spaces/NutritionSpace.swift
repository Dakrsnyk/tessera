import SwiftUI
import Vision
import VisionKit

struct NutritionSpaceSections: View {
    @Environment(AppModel.self) private var model
    @State private var showsFoodSearch = false
    @State private var showsGoals = false

    var body: some View {
        let now = Date()
        let state = model.nutrition
        let totals = NutritionMath.totals(state, on: now)
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(TF.int(max(0, state.goals.kcal - totals.kcal)))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("kcal restantes").foregroundStyle(Color.secondary)
                    Spacer()
                    Text("\(TF.int(totals.kcal)) / \(TF.int(state.goals.kcal))")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .monospacedDigit()
                }
                ProgressView(value: min(1, totals.kcal / max(1, state.goals.kcal)))
                    .tint(Color(hex: "FF6B57"))
                ForEach(NutritionTiles.macroRows(totals, goals: state.goals)) { row in
                    HStack {
                        Circle().fill(Color(hex: row.colorHex ?? "999999")).frame(width: 8, height: 8)
                        Text(row.title).font(.subheadline)
                        Spacer()
                        Text(row.value ?? "").font(.subheadline).foregroundStyle(Color.secondary).monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)
            Button {
                showsFoodSearch = true
            } label: {
                Label("Ajouter un aliment", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
        } header: {
            Text("Aujourd'hui")
        }
        .sheet(isPresented: $showsFoodSearch) {
            FoodSearchView()
        }
        .sheet(isPresented: $showsGoals) {
            NutritionGoalsEditor(goals: state.goals)
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
                            Text("\(TF.int(entry.totals.kcal)) kcal").foregroundStyle(Color.secondary).monospacedDigit()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                model.update(\.nutrition) { $0.entries.removeAll { $0.id == entry.id } }
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                            Button {
                                toggleFavorite(entry.food)
                            } label: {
                                Label("Favori", systemImage: "star")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
        }

        Section {
            ForEach(state.favorites) { food in
                ValueRow(title: food.displayName, value: "\(TF.int(food.nutrients(grams: food.servingGrams).kcal)) kcal", symbol: "star.fill", colorHex: "F2A33A")
            }
            .onDelete { offsets in
                model.update(\.nutrition) { $0.favorites.remove(atOffsets: offsets) }
            }
            if state.favorites.isEmpty {
                HintRow(text: "Glisse un aliment vers la gauche pour l'ajouter aux favoris. Le widget Ajout rapide les propose d'une touche.")
            }
        } header: {
            Text("Favoris")
        }

        Section {
            Button {
                showsGoals = true
            } label: {
                ValueRow(title: "Objectifs du jour", value: "\(TF.int(state.goals.kcal)) kcal · \(TF.int(state.goals.protein)) g prot.", symbol: "target")
            }
            .tint(.primary)
            if let average = NutritionMath.average(state, days: 7, until: now) {
                ValueRow(title: "Moyenne sur 7 jours", value: "\(TF.int(average)) kcal", symbol: "chart.bar")
            }
            ValueRow(title: "Série de suivi", value: Fmt.plural(NutritionMath.trackingStreak(state, until: now), "jour", "jours"), symbol: "flame.fill")
        } header: {
            Text("Objectifs")
        } footer: {
            Text("Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL).")
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
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var online: [FoodItem] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var selected: FoodItem?
    @State private var showsScanner = false
    @State private var showsCustom = false

    private var local: [FoodItem] {
        let recent = model.nutrition.favorites + model.nutrition.recentFoods + model.nutrition.customFoods
        var seen = Set<String>()
        let mine = recent.filter { seen.insert($0.id).inserted }
        let q = FoodDatabase.normalized(query)
        let filteredMine = q.isEmpty ? mine : mine.filter { FoodDatabase.normalized($0.name).contains(q) }
        let builtin = FoodDatabase.search(query).filter { !seen.contains($0.id) }
        return filteredMine + builtin
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        if DataScannerViewController.isSupported {
                            Button {
                                showsScanner = true
                            } label: {
                                Label("Scanner", systemImage: "barcode.viewfinder")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            showsCustom = true
                        } label: {
                            Label("Aliment perso", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                Section(query.trimmed.isEmpty ? "Suggestions" : "Résultats") {
                    ForEach(local.prefix(60)) { food in
                        foodRow(food)
                    }
                }
                if !query.trimmed.isEmpty {
                    Section {
                        if isSearching {
                            HStack { ProgressView(); Text("Recherche sur Open Food Facts…").foregroundStyle(Color.secondary) }
                        } else if let searchError {
                            HintRow(text: searchError)
                        } else if online.isEmpty {
                            Button("Chercher « \(query.trimmed) » dans les produits emballés") {
                                Task { await searchOnline() }
                            }
                        }
                        ForEach(online) { food in
                            foodRow(food)
                        }
                    } header: {
                        Text("Produits emballés")
                    } footer: {
                        Text("Données Open Food Facts (ODbL), saisies par la communauté : vérifie l'étiquette.")
                    }
                }
            }
            .styledList()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Pomme, poulet, yogourt…")
            .onSubmit(of: .search) { Task { await searchOnline() } }
            .onChange(of: query) { _, _ in
                online = []
                searchError = nil
            }
            .navigationTitle("Ajouter un aliment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $selected) { food in
                FoodLogSheet(food: food) { dismiss() }
            }
            .sheet(isPresented: $showsScanner) {
                BarcodeScannerView { code in
                    showsScanner = false
                    Task { await lookup(code) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showsCustom) {
                CustomFoodEditor { food in
                    selected = food
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
                    Text("\(TF.int(food.kcal)) kcal / 100 g · P \(TF.int(food.protein)) · G \(TF.int(food.carbs)) · L \(TF.int(food.fat))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(.tint)
            }
        }
    }

    private func searchOnline() async {
        let text = query.trimmed
        guard text.count >= 2 else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            online = try await OpenFoodFacts.search(text)
            if online.isEmpty { searchError = "Aucun produit trouvé pour « \(text) »." }
        } catch {
            searchError = "Open Food Facts ne répond pas. Réessaie dans un instant."
        }
    }

    private func lookup(_ code: String) async {
        isSearching = true
        defer { isSearching = false }
        if let food = try? await OpenFoodFacts.product(barcode: code) {
            selected = food
        } else {
            query = code
            searchError = "Produit \(code) introuvable. Crée-le comme aliment perso."
        }
    }
}

/// Grams and meal for a food, then saves the entry.
struct FoodLogSheet: View {
    let food: FoodItem
    var onDone: () -> Void = {}
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 100
    @State private var meal: MealType = .current()

    var body: some View {
        let totals = food.nutrients(grams: grams)
        SheetForm(title: food.name, canSave: grams > 0, onSave: save) {
            Section {
                NumberRow(title: "Quantité", value: $grams, unit: "g")
                if !food.servingName.isEmpty {
                    Button("Portion : \(food.servingName) (\(TF.int(food.servingGrams)) g)") {
                        grams = food.servingGrams
                    }
                }
                Picker("Repas", selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Apport") {
                ValueRow(title: "Calories", value: "\(TF.int(totals.kcal)) kcal")
                ValueRow(title: "Protéines", value: "\(TF.decimal(totals.protein, 1)) g")
                ValueRow(title: "Glucides", value: "\(TF.decimal(totals.carbs, 1)) g")
                ValueRow(title: "Lipides", value: "\(TF.decimal(totals.fat, 1)) g")
                ValueRow(title: "Fibres", value: "\(TF.decimal(totals.fiber, 1)) g")
            }
        }
        .onAppear { grams = food.servingGrams > 0 ? food.servingGrams : 100 }
    }

    private func save() {
        let amount = grams
        let chosen = meal
        model.update(\.nutrition) { $0.log(food, grams: amount, meal: chosen) }
        Haptics.success()
        onDone()
    }
}

struct CustomFoodEditor: View {
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
        SheetForm(title: "Aliment perso", canSave: !name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField("Nom", text: $name)
                NumberRow(title: "Portion", value: $serving, unit: "g")
            }
            Section("Pour 100 g") {
                NumberRow(title: "Calories", value: $kcal, unit: "kcal")
                NumberRow(title: "Protéines", value: $protein, unit: "g")
                NumberRow(title: "Glucides", value: $carbs, unit: "g")
                NumberRow(title: "Lipides", value: $fat, unit: "g")
                NumberRow(title: "Fibres", value: $fiber, unit: "g")
            }
        }
    }

    private func save() {
        let food = FoodItem(id: "custom.\(UUID().uuidString)", name: name.trimmed, brand: nil, kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber,
                            servingGrams: max(1, serving), servingName: "\(TF.int(serving)) g", source: .custom, barcode: nil)
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

    var body: some View {
        SheetForm(title: "Objectifs", onSave: save) {
            Section("Par jour") {
                NumberRow(title: "Calories", value: $goals.kcal, unit: "kcal")
                NumberRow(title: "Protéines", value: $goals.protein, unit: "g")
                NumberRow(title: "Glucides", value: $goals.carbs, unit: "g")
                NumberRow(title: "Lipides", value: $goals.fat, unit: "g")
                NumberRow(title: "Fibres", value: $goals.fiber, unit: "g")
            }
            Section {
                Picker("Sexe", selection: $sex) {
                    Text("Femme").tag(NutritionCalculator.Sex.female)
                    Text("Homme").tag(NutritionCalculator.Sex.male)
                }
                Stepper("Âge : \(age) ans", value: $age, in: 16...90)
                NumberRow(title: "Taille", value: $height, unit: "cm")
                NumberRow(title: "Poids", value: $weight, unit: "kg")
                Picker("Activité", selection: $activity) {
                    ForEach(NutritionCalculator.Activity.allCases) { Text($0.title).tag($0) }
                }
                Picker("But", selection: $goal) {
                    ForEach(NutritionCalculator.Goal.allCases) { Text($0.title).tag($0) }
                }
                Button("Calculer mes objectifs") {
                    goals = NutritionCalculator.goals(sex: sex, age: age, heightCm: height, weightKg: weight, activity: activity, goal: goal)
                }
            } header: {
                Text("Calculateur")
            } footer: {
                Text("Estimation Mifflin-St Jeor, à ajuster selon tes sensations. Ce n'est pas un avis médical.")
            }
        }
    }

    private func save() {
        let saved = goals
        model.update(\.nutrition) { $0.goals = saved }
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
