import SwiftUI

/// « Mes aliments »: the personal foods of the person, to correct or delete. A food deleted here leaves the
/// lists (and the barcode scan); the meals already logged keep their own copy of it.
struct CustomFoodsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var editing: FoodItem?
    @State private var pendingDelete: FoodItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if model.nutrition.customFoods.isEmpty {
                        Text(tr("Aucun aliment personnel."))
                            .foregroundStyle(Color.secondary)
                    }
                    ForEach(model.nutrition.customFoods) { food in
                        Button {
                            editing = food
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.displayName).foregroundStyle(Color.primary).lineLimit(1)
                                    Text(tr("pour 100 g · P \(TF.int(food.protein)) · G \(TF.int(food.carbs)) · L \(TF.int(food.fat))"))
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                Text(tr("\(TF.int(food.kcal)) kcal"))
                                    .foregroundStyle(Color.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .accessibilityIdentifier("custom-food-row")
                        .swipeActions {
                            Button(role: .destructive) {
                                pendingDelete = food
                            } label: {
                                Label(tr("Supprimer"), systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    if !model.nutrition.customFoods.isEmpty {
                        Text(tr("Touche un aliment pour le corriger. Glisse-le pour le supprimer : les repas déjà notés le gardent."))
                    }
                }
            }
            .styledList()
            .navigationTitle(tr("Mes aliments"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
        .sheet(item: $editing) { food in
            CustomFoodEditForm(food: food)
        }
        .confirmationDialog(
            tr("Supprimer cet aliment ?"), isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible, presenting: pendingDelete
        ) { food in
            Button(tr("Supprimer"), role: .destructive) {
                let id = food.id
                model.update(\.nutrition) { $0.deleteCustomFood(id) }
                Haptics.success()
            }
            Button(tr("Annuler"), role: .cancel) {}
        } message: { food in
            Text(food.displayName)
        }
    }
}

/// Corrects a personal food: name, portion and the four values per 100 g. Negative or impossible values are
/// refused; 0 kcal or an energy far from the macros asks for a confirmation.
struct CustomFoodEditForm: View {
    let food: FoodItem
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var serving: Double = 100
    @State private var kcal: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var loaded = false
    @State private var confirming = false

    private var blocking: CustomFoodValidation.Problem? {
        if !serving.isFinite || serving <= 0 || serving > NutritionState.maxGrams { return .outOfRange }
        return CustomFoodValidation.blockingProblem(kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: food.fiber)
    }

    private var warning: CustomFoodValidation.Problem? {
        CustomFoodValidation.warning(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    var body: some View {
        SheetForm(title: tr("Aliment perso"), canSave: !name.trimmed.isEmpty && blocking == nil, dismissesOnSave: false, onSave: save) {
            Section {
                TextField(tr("Nom"), text: $name)
                NumberRow(title: tr("Portion"), value: $serving, unit: "g")
            }
            Section {
                NumberRow(title: tr("Calories"), value: $kcal, unit: "kcal")
                NumberRow(title: tr("Protéines"), value: $protein, unit: "g")
                NumberRow(title: tr("Glucides"), value: $carbs, unit: "g")
                NumberRow(title: tr("Lipides"), value: $fat, unit: "g")
            } header: {
                Text(tr("Pour 100 g"))
            } footer: {
                if let message = Self.message(for: blocking) ?? Self.message(for: warning) {
                    Text(message).foregroundStyle(blocking == nil ? Color.secondary : Color.red)
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            name = food.name
            serving = food.servingGrams
            kcal = food.kcal
            protein = food.protein
            carbs = food.carbs
            fat = food.fat
        }
        .alert(tr("Enregistrer quand même ?"), isPresented: $confirming) {
            Button(tr("Annuler"), role: .cancel) {}
            Button(tr("Enregistrer")) { commit() }
        } message: {
            Text(Self.message(for: warning) ?? "")
        }
    }

    static func message(for problem: CustomFoodValidation.Problem?) -> String? {
        switch problem {
        case .none: nil
        case .negative: tr("Une valeur est négative ou illisible.")
        case .outOfRange: tr("Une valeur est impossible : 900 kcal et 100 g au maximum pour 100 g, portion de 5 000 g au maximum.")
        case .zeroEnergy: tr("Cet aliment est à 0 kcal. C'est normal pour de l'eau, pas pour le reste.")
        case .energyMismatch: tr("Les calories ne correspondent pas aux protéines, glucides et lipides : vérifie l'étiquette.")
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
        var updated = food
        updated.name = name.trimmed
        updated.servingGrams = max(1, serving)
        updated.servingName = "\(TF.int(serving)) g"
        updated.kcal = kcal
        updated.protein = protein
        updated.carbs = carbs
        updated.fat = fat
        updated.unknownMacros = nil
        let saved = updated
        model.update(\.nutrition) { $0.updateCustomFood(saved) }
        Haptics.success()
        dismiss()
    }
}
