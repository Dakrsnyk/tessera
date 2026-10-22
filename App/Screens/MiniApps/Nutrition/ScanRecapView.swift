import SwiftUI

/// Where the foods of a recap come from.
enum ScanRecapSource {
    /// A product found from its barcode.
    case barcode
    /// The foods guessed from the photo of a dish.
    case photo
}

/// The recap of a scan, editable before anything is logged: each food with its quantity, whether its
/// values are the ones of a table (« Vérifié ») or an estimate from a photo (« Estimation », with how sure
/// the analysis is), the meal, the totals, and « Ajouter au journal ». The logic is `ScanRecap`.
struct ScanRecapView: View {
    @Binding var recap: ScanRecap
    let source: ScanRecapSource
    /// The meal the food goes to (chosen from a meal of the Nutrition mini-app), else the current one.
    var presetMeal: MealType? = nil
    /// The day the food is added to (today, or a day browsed in the mini-app).
    var day: Date = Date()
    /// Called once the foods are in the journal.
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var meal: MealType = .current()
    @State private var picker: FoodPickPurpose?
    @State private var isSaving = false

    /// Why the food search is opened: one more food, or another food for a line.
    private enum FoodPickPurpose: Identifiable {
        case add
        case replace(UUID)

        var id: String {
            switch self {
            case .add: "add"
            case .replace(let id): "replace-\(id.uuidString)"
            }
        }
    }

    var body: some View {
        let state = model.nutrition
        let known = NutritionTiles.Targets(model.profile)
        let totals = recap.totals
        let approximate = recap.hasEstimate ? "≈ " : ""
        let left = state.goals.kcal - NutritionMath.totals(state, on: day).kcal - totals.kcal
        List {
            Section {
                ForEach(recap.lines) { line in
                    ScanLineRow(
                        line: line,
                        onGrams: { recap.setGrams(line.id, $0) },
                        onReplace: { picker = .replace(line.id) },
                        onRemove: { recap.remove(line.id) }
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            recap.remove(line.id)
                        } label: {
                            Label(tr("Supprimer"), systemImage: "trash")
                        }
                        Button {
                            picker = .replace(line.id)
                        } label: {
                            Label(tr("Remplacer"), systemImage: "arrow.triangle.2.circlepath")
                        }
                        .tint(.orange)
                    }
                }
                Button {
                    picker = .add
                } label: {
                    Label(tr("Ajouter un aliment"), systemImage: "plus.circle.fill")
                        .frame(minHeight: 44, alignment: .leading)
                }
            } header: {
                Text(tr("Aliments"))
            } footer: {
                linesFooter
            }

            Section {
                Picker(tr("Repas"), selection: $meal) {
                    ForEach(MealType.allCases) { Text($0.title).tag($0) }
                }
            }

            Section {
                ValueRow(title: tr("Calories"), value: approximate + tr("\(TF.int(totals.kcal)) kcal"))
                ValueRow(title: tr("Protéines"), value: "\(approximate)\(TF.decimal(totals.protein, 1)) g")
                ValueRow(title: tr("Glucides"), value: "\(approximate)\(TF.decimal(totals.carbs, 1)) g")
                ValueRow(title: tr("Lipides"), value: "\(approximate)\(TF.decimal(totals.fat, 1)) g")
            } header: {
                Text(tr("Total"))
            } footer: {
                if known.kcal {
                    Text(left >= 0 ? tr("Après ajout, il te restera \(TF.int(left)) kcal.") : tr("Après ajout, tu dépasseras ton objectif de \(TF.int(-left)) kcal."))
                }
            }

            if known.kcal || known.protein || known.carbs || known.fat {
                Section(tr("Objectifs")) {
                    goalRows(state: state, known: known, added: totals)
                }
            }
        }
        .styledList()
        .scrollDismissesKeyboard(.interactively)
        .onAppear { meal = presetMeal ?? .current() }
        .safeAreaInset(edge: .bottom) { confirmBar }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(tr("OK")) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .sheet(item: $picker) { purpose in
            FoodSearchView(presetMeal: presetMeal, day: day, onPick: { food in
                switch purpose {
                case .add: _ = recap.add(food)
                case .replace(let id): recap.replace(id, with: food)
                }
            })
        }
    }

    // MARK: Pieces

    /// The day's calories and macros once the recap is added, against the targets the person gave.
    @ViewBuilder
    private func goalRows(state: NutritionState, known: NutritionTiles.Targets, added: NutritionTotals) -> some View {
        let after = NutritionMath.totals(state, on: day) + added
        if known.kcal {
            ValueRow(title: tr("Calories"), value: "\(TF.int(after.kcal)) / \(TF.int(state.goals.kcal)) kcal")
        }
        ForEach(NutritionTiles.macroRows(after, goals: state.goals, known: known)) { row in
            HStack {
                Circle().fill(Color(hex: row.colorHex ?? "999999")).frame(width: 8, height: 8)
                Text(row.title)
                Spacer()
                Text(row.value ?? "").foregroundStyle(Color.secondary).monospacedDigit()
            }
        }
    }

    /// What the recap rests on: the estimates are not measures, and the sources of the values.
    @ViewBuilder
    private var linesFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            if source == .photo {
                Text(tr("Estimé d'après la photo, analysée sur ton iPhone sans être enregistrée."))
            }
            if recap.hasEstimate {
                Text(tr("Les portions estimées d'après une photo ne sont pas des mesures : ajuste-les."))
            }
            if recap.lines.contains(where: { $0.food.source == .openFoodFacts }) {
                Text(tr("Données Open Food Facts (ODbL), saisies par la communauté : vérifie l'étiquette."))
                HStack(spacing: 12) {
                    Link(destination: FoodSourceLinks.openFoodFacts) { Text(verbatim: "openfoodfacts.org") }
                    Link(destination: FoodSourceLinks.odbl) { Text(verbatim: "ODbL") }
                }
            }
            if recap.lines.contains(where: { $0.food.source == .nutrientFile }) {
                Text(NutrientFile.attribution)
            }
        }
    }

    private var confirmBar: some View {
        Button {
            confirm()
        } label: {
            Text(tr("Ajouter au journal"))
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!recap.canConfirm || isSaving)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Logging

    /// Every line in one update of the journal; a second tap, or the same barcode scanned again within
    /// two seconds, adds nothing more. The button stays off once pressed.
    private func confirm() {
        guard recap.canConfirm, !isSaving else { return }
        isSaving = true
        let chosen = meal
        let date = NutritionMath.entryDate(for: chosen, on: day)
        // On another day every entry gets the same usual time of the meal: the double-tap window would
        // block a second portion of the same food for good, so only the button guards that case.
        let window: TimeInterval = DateMath.isSameDay(day, Date()) ? NutritionState.quickAddWindow : 0
        let snapshot = recap
        var logged = 0
        model.update(\.nutrition) { logged = snapshot.commit(into: &$0, meal: chosen, at: date, window: window) }
        if logged > 0 { Haptics.tap() }
        onDone()
    }
}

// MARK: - One food

private struct ScanLineRow: View {
    let line: ScanLine
    let onGrams: (Double) -> Void
    let onReplace: () -> Void
    let onRemove: () -> Void

    var body: some View {
        let totals = line.totals
        let grams = Binding<Double>(get: { line.grams }, set: { onGrams($0) })
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(line.food.displayName)
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        ScanBadge(isEstimate: line.isEstimate)
                        if let word = line.confidenceWord {
                            Text(word)
                                .font(.caption)
                                .foregroundStyle(line.isLowConfidence ? Color.orange : Color.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
                Menu {
                    Button(action: onReplace) {
                        Label(tr("Remplacer"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive, action: onRemove) {
                        Label(tr("Supprimer"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(tr("Options de \(line.food.name)"))
            }
            Text(tr("\(TF.int(totals.kcal)) kcal · P \(TF.decimal(totals.protein, 1)) · G \(TF.decimal(totals.carbs, 1)) · L \(TF.decimal(totals.fat, 1))"))
                .font(.footnote)
                .foregroundStyle(Color.secondary)
                .monospacedDigit()
            HStack(spacing: 8) {
                TextField("0", value: grams, format: .number.locale(Fmt.locale))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 84, height: 44)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel(tr("Quantité"))
                Text(verbatim: "g").foregroundStyle(Color.secondary)
                Spacer(minLength: 0)
                Stepper(tr("Quantité"), value: grams, in: ScanRecap.minGrams...ScanRecap.maxGrams, step: line.grams < 50 ? 5 : 10)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 4)
    }
}

/// « Vérifié » (the values of a table, of a product or of the person) or « Estimation » (a guess from a
/// photo). A word and a symbol, never only a colour.
private struct ScanBadge: View {
    let isEstimate: Bool

    var body: some View {
        let tint: Color = isEstimate ? .orange : .green
        Label(isEstimate ? tr("Estimation") : tr("Vérifié"), systemImage: isEstimate ? "questionmark.circle" : "checkmark.seal.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
