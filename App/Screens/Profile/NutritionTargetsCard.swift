import SwiftUI

/// The daily needs of « Mes infos › Nutrition »: calculated from the body, the aim and the activity, each
/// one marked « Calculé » or « Personnalisé ». A touch on a value changes it by hand; a value typed by hand
/// stays as it is when the calculation changes, with the new recommendation shown beside it. Without
/// Premium, only the calories and the three macronutrients show; the others are marked Premium (their
/// values, typed by hand or not, are kept).
struct NutritionTargetsCard: View {
    @Environment(AppModel.self) private var model
    @State private var editing: NutritionTarget?
    @State private var paywall: PaywallContext?
    @State private var showsMicronutrients = false
    @State private var showsMethod = false
    @State private var showsPlan = false

    var body: some View {
        let profile = model.profile
        let auto = profile.followsNutritionCalculation
        let recommended = model.recommendedNutritionGoals()
        let followsPlan = auto && model.activeWeightPlan?.acceptedKcal != nil
        VStack(spacing: 12) {
        // An adjustment the weigh-ins call for: proposed, never applied without a touch.
        WeightPlanAdjustmentCard()
        QuestionCard(title: tr("Tes besoins par jour"), detail: auto
                     ? tr("Calculés à partir de ton corps, de ton objectif et de ton activité. Touche une valeur pour la personnaliser.")
                     : tr("Tes valeurs, gardées telles quelles. Le calcul reste proposé à côté.")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: Binding(get: { auto }, set: { model.setNutritionCalculation($0) })) {
                    Text(tr("Calcul automatique")).font(.subheadline.weight(.semibold))
                }
                .tint(Color(hex: MiniApp.nutrition.colorHex))
                .accessibilityIdentifier("nutrition-auto")
                if followsPlan {
                    Button { showsPlan = true } label: {
                        HStack(spacing: 6) {
                            Label(tr("Calculé d'après ton plan"), systemImage: "scalemass")
                                .font(.footnote.weight(.semibold))
                            Spacer(minLength: 4)
                            Text(tr("Voir le récapitulatif"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(tr("Ouvre le récapitulatif de ton objectif de poids"))
                    .accessibilityIdentifier("weightplan-link")
                }
                if auto, recommended == nil {
                    Label(tr("Ajoute \(Self.list(model.nutritionCalculationMissing)) : Ardane calcule tes besoins."), systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nutrition-missing")
                }
                rows(NutritionTarget.allCases.filter { $0.group == .energy }, recommended: recommended, auto: auto)
                groupTitle(NutritionTarget.Group.limits.title)
                    .padding(.top, 4)
                rows(NutritionTarget.allCases.filter { $0.group == .limits }, recommended: recommended, auto: auto)
                DisclosureGroup(isExpanded: $showsMicronutrients) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([NutritionTarget.Group.fats, .minerals, .vitamins], id: \.self) { group in
                            groupTitle(group.title)
                            rows(NutritionTarget.allCases.filter { $0.group == group }, recommended: recommended, auto: auto)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    HStack(spacing: 6) {
                        Text(tr("Acides gras, minéraux et vitamines")).font(.subheadline.weight(.semibold))
                        if !model.isPremium { PremiumBadge(compact: true) }
                    }
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
        // A container only shows up under its own identifier when it is an element (as « daily-section »).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nutrition-targets")
        .sheet(item: $editing) { target in
            NutritionTargetEditor(target: target)
                .presentationDetents([.medium])
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
        .sheet(isPresented: $showsPlan) {
            NavigationStack {
                ScrollView {
                    WeightPlanSummaryView(onEdit: { showsPlan = false })
                        .padding(20)
                }
                .background(.screenGradient)
                .navigationTitle(tr("Ton objectif de poids"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("OK")) { showsPlan = false }
                    }
                }
            }
            .presentationDetents([.large])
        }
        // Targets added by an update follow the calculation at once.
        .onAppear { model.followCalculatedNutritionGoals() }
        }
    }

    /// « À LIMITER », « MINÉRAUX »…
    private func groupTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
    }

    private func rows(_ targets: [NutritionTarget], recommended: NutritionGoals?, auto: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(targets.enumerated()), id: \.element) { index, target in
                let locked = target.isPremium && !model.isPremium
                Button {
                    if locked { paywall = .nutrients } else { editing = target }
                } label: {
                    if locked {
                        lockedRow(target)
                    } else {
                        row(target, recommended: recommended, auto: auto)
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("target-row-\(target.rawValue)")
                if index < targets.count - 1 { Divider() }
            }
        }
        .padding(.horizontal, 12)
        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// A target of Premium without it: its name and the badge, the value kept out of sight.
    private func lockedRow(_ target: NutritionTarget) -> some View {
        HStack(spacing: 8) {
            Text(target.isLimit ? tr("\(target.title) (max.)") : target.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 6)
            PremiumBadge(compact: true)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func row(_ target: NutritionTarget, recommended: NutritionGoals?, auto: Bool) -> some View {
        let profile = model.profile
        let isCustom = auto && profile.customTargets.contains(target)
        let value = model.shownNutritionTarget(target, recommended: recommended)
        let advice = recommended.map { $0[target] }
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(target.isLimit ? tr("\(target.title) (max.)") : target.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let advice, value != nil, abs(advice - (value ?? 0)) >= (target.decimals > 0 ? 0.05 : 0.5), isCustom || !auto {
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
        parts.append(tr("Gras trans : moins de 1 % des calories (OMS). Caféine : 400 mg au plus (Santé Canada). Oméga-3 et oméga-6 : apports suffisants (National Academies)."))
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

extension AppModel {
    /// A daily target in force for the person: calculated or typed. Nil (—) while nothing gave it, never the
    /// built-in default. The targets card and the nutrients page both show this one. `recommended` is
    /// `recommendedNutritionGoals()`, worked out once by the caller.
    func shownNutritionTarget(_ target: NutritionTarget, recommended: NutritionGoals?) -> Double? {
        let goals = nutrition.goals
        if profile.followsNutritionCalculation {
            if profile.customTargets.contains(target) { return goals[target] }
            return recommended == nil ? nil : goals[target]
        }
        if let fact = target.providedFact { return profile.knows(fact) ? goals[target] : nil }
        return goals[target]
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
