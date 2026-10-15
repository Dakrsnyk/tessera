import SwiftUI

/// The daily needs of « Mes infos › Nutrition »: calculated from the body, the aim and the activity, each
/// one marked « Calculé » or « Personnalisé ». A touch on a value changes it by hand; a value typed by hand
/// stays as it is when the calculation changes, with the new recommendation shown beside it.
struct NutritionTargetsCard: View {
    @Environment(AppModel.self) private var model
    @State private var editing: NutritionTarget?
    @State private var showsMicronutrients = false
    @State private var showsMethod = false

    var body: some View {
        let profile = model.profile
        let auto = profile.followsNutritionCalculation
        let recommended = model.recommendedNutritionGoals()
        QuestionCard(title: tr("Tes besoins par jour"), detail: auto
                     ? tr("Calculés à partir de ton corps, de ton objectif et de ton activité. Touche une valeur pour la personnaliser.")
                     : tr("Tes valeurs, gardées telles quelles. Le calcul reste proposé à côté.")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(get: { auto }, set: { model.setNutritionCalculation($0) })) {
                    Text(tr("Calcul automatique")).font(.subheadline.weight(.semibold))
                }
                .tint(Color(hex: MiniApp.nutrition.colorHex))
                .accessibilityIdentifier("nutrition-auto")
                if auto, recommended == nil {
                    Label(tr("Ajoute \(Self.list(model.nutritionCalculationMissing)) : Ardane calcule tes besoins."), systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nutrition-missing")
                }
                rows(NutritionTarget.allCases.filter { $0.group == .energy }, recommended: recommended, auto: auto)
                Text(tr("À limiter").uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                rows(NutritionTarget.allCases.filter { $0.group == .limits }, recommended: recommended, auto: auto)
                DisclosureGroup(isExpanded: $showsMicronutrients) {
                    rows(NutritionTarget.allCases.filter { $0.group == .micronutrients }, recommended: recommended, auto: auto)
                        .padding(.top, 6)
                } label: {
                    Text(tr("Minéraux et vitamines")).font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("nutrition-micronutrients")
                DisclosureGroup(isExpanded: $showsMethod) {
                    Text(method)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                } label: {
                    Text(tr("Comment c'est calculé")).font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("nutrition-method")
                Text(tr("Des repères pour un adulte en bonne santé, pas un avis médical."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Color(hex: MiniApp.nutrition.colorHex))
        .accessibilityIdentifier("nutrition-targets")
        .sheet(item: $editing) { target in
            NutritionTargetEditor(target: target)
                .presentationDetents([.medium])
        }
    }

    private func rows(_ targets: [NutritionTarget], recommended: NutritionGoals?, auto: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(targets.enumerated()), id: \.element) { index, target in
                Button {
                    editing = target
                } label: {
                    row(target, recommended: recommended, auto: auto)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("target-row-\(target.rawValue)")
                if index < targets.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 12)
        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ target: NutritionTarget, recommended: NutritionGoals?, auto: Bool) -> some View {
        let profile = model.profile
        let isCustom = auto && profile.customTargets.contains(target)
        let value = shownValue(target, auto: auto, recommended: recommended)
        let advice = recommended.map { $0[target] }
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(target.isLimit ? tr("\(target.title) (max.)") : target.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let advice, value != nil, abs(advice - (value ?? 0)) >= 0.5, isCustom || !auto {
                    Text(tr("Recommandé : \(Self.format(advice, target))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if target == .sodium, let value {
                    Text(tr("Soit \(TF.decimal(value * 2.5 / 1_000, 1)) g de sel"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 6)
            Text(value.map { Self.format($0, target) } ?? "—")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            if value != nil, auto {
                Text(isCustom ? tr("Personnalisé") : tr("Calculé"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isCustom ? Color.white : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(isCustom ? AnyShapeStyle(Color(hex: MiniApp.nutrition.colorHex)) : AnyShapeStyle(Color.secondary.opacity(0.15)), in: Capsule())
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    /// The value in force: calculated or typed. Unknown (—) while nothing gave it.
    private func shownValue(_ target: NutritionTarget, auto: Bool, recommended: NutritionGoals?) -> Double? {
        let goals = model.nutrition.goals
        if auto {
            if model.profile.customTargets.contains(target) { return goals[target] }
            return recommended == nil ? nil : goals[target]
        }
        if let fact = target.providedFact { return model.profile.knows(fact) ? goals[target] : nil }
        return goals[target]
    }

    /// The steps with the person's own numbers.
    private var method: String {
        var parts: [String] = []
        if let steps = model.nutritionBreakdown {
            parts.append(tr("Métabolisme de base (formule de Mifflin-St Jeor, selon ton âge, ta taille, ton poids et ton genre) : \(TF.int(steps.restingKcal)) kcal."))
            parts.append(tr("× activité « \(model.nutritionActivity.title) » (\(TF.decimal(model.nutritionActivity.rawValue, 3))) : \(TF.int(steps.dailyKcal)) kcal dépensées par jour."))
            let adjustment = Int((steps.goalAdjustment * 100).rounded())
            if adjustment != 0 {
                let change = adjustment > 0 ? "+\(adjustment)" : "−\(abs(adjustment))"
                parts.append(tr("Ton objectif « \(model.nutritionGoal.title) » : \(change) %."))
            }
            parts.append(tr("Protéines : \(TF.decimal(steps.proteinPerKg, 1)) g par kg de poids. Lipides : 28 % des calories. Glucides : le reste."))
        } else {
            parts.append(tr("Calories : formule de Mifflin-St Jeor (âge, taille, poids, genre) × ton niveau d'activité, ajustée selon ton objectif (−15 % pour perdre, +10 % pour prendre du muscle)."))
        }
        parts.append(tr("Fibres : 14 g par 1 000 kcal. Sucres et gras saturés : moins de 10 % des calories chacun (OMS). Sodium : moins de 2 300 mg."))
        parts.append(tr("Minéraux et vitamines : apports de référence pour les adultes (National Academies), selon ton âge et ton genre."))
        if model.profile.calculatedActivity == nil {
            parts.append(model.activityFromWorkouts == nil
                         ? tr("Activité : légère par défaut, choisis la tienne ci-dessus.")
                         : tr("Activité : d'après tes séances par semaine."))
        }
        return parts.joined(separator: "\n")
    }

    static func format(_ value: Double, _ target: NutritionTarget) -> String {
        let number = target.decimals > 0 ? TF.decimal(value, target.decimals) : TF.int(value)
        return "\(number) \(target.unit)"
    }

    /// « ton âge, ta taille et ton poids ».
    static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return tr("\(items.dropLast().joined(separator: ", ")) et \(last)")
    }
}

/// One target typed by hand, or given back to the calculation.
struct NutritionTargetEditor: View {
    let target: NutritionTarget
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        let auto = model.profile.followsNutritionCalculation
        let recommended = model.recommendedNutritionGoals(followingTypedCalories: target != .kcal)?[target]
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(tr("Valeur"), text: $text)
                            .keyboardType(target.decimals > 0 ? .decimalPad : .numberPad)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .accessibilityIdentifier("target-editor-field")
                        Text(target.unit).foregroundStyle(.secondary)
                    }
                } header: {
                    Text(target.isLimit ? tr("\(target.title) (max.)") : target.title)
                } footer: {
                    if let recommended {
                        Text(tr("Recommandé pour toi : \(NutritionTargetsCard.format(recommended, target))."))
                    }
                }
                if auto, model.profile.customTargets.contains(target), recommended != nil {
                    Section {
                        Button(tr("Revenir au calcul")) {
                            model.resetNutritionTarget(target)
                            dismiss()
                        }
                        .accessibilityIdentifier("target-reset")
                    } footer: {
                        Text(tr("La valeur suivra de nouveau ton corps, ton objectif et ton activité."))
                    }
                }
            }
            .styledList()
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Enregistrer")) {
                        model.setNutritionTarget(target, ProfileNumberField.parse(text))
                        dismiss()
                    }
                    .disabled(ProfileNumberField.parse(text) == nil)
                    .accessibilityIdentifier("target-save")
                }
            }
        }
        .onAppear {
            text = ProfileNumberField.format(model.nutrition.goals[target].rounded(toPlaces: target.decimals))
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
