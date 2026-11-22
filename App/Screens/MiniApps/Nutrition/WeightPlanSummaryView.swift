import SwiftUI

// Objectif de poids (chantier 15): the recap shown before the user accepts the calories, and the card
// that proposes an adjustment. Nothing is applied here without a touch on « Appliquer ». An unsafe or an
// uncalculable goal never shows a calorie figure nor a button to apply one.

/// The recap of the weight goal. `onEdit`: the « Modifier l'objectif » button (nil: hidden, the inputs
/// are just above).
struct WeightPlanSummaryView: View {
    var onEdit: (() -> Void)?
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    private var palette: CristalPalette { CristalPalette.of(style.id) }
    /// The action color of the app (the strong version of its color, as in the other screens of the mini-app).
    private var accent: Color { palette.strong(MiniApp.nutrition.colorHex) }
    private var system: UnitSystem { model.settings.unitSystem }

    var body: some View {
        // Nothing is judged while a weight is still being typed (« 8 » on the way to « 85 »).
        if let plan = model.activeWeightPlan, plan.targetKg >= WeightPlanCalculator.weightRange.lowerBound,
           let outcome = model.evaluateWeightPlan() {
            VStack(alignment: .leading, spacing: 12) {
                switch outcome {
                case .ok(let numbers):
                    recap(numbers, plan: plan, remark: nil)
                case .adjusted(let numbers, let reason):
                    recap(numbers, plan: plan, remark: reason)
                case .unsafe(let reason, let weeks, let date, _):
                    unsafeView(reason: reason, weeks: weeks, date: date)
                case .referToProfessional(let reason):
                    if awaitsSituation {
                        situationPrompt(reason: reason)
                    } else {
                        refer(reason: reason)
                    }
                }
            }
            .card(padding: 14)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weightplan-summary")
        }
    }

    /// The question about pregnancy is shown (not a man) and still unanswered, for an adult.
    private var awaitsSituation: Bool {
        model.profile.lifeStage == nil && model.profile.sex != .male && !model.profile.isMinor(birthday: model.life.birthday)
    }

    /// The pregnancy question, asked here only (PDG, 2026-11-22: no longer on the first-launch pages): right where
    /// the plan needs it, with its answers, wherever the recap is shown.
    private func situationPrompt(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tr("Es-tu enceinte ou allaitante ?"), systemImage: "questionmark.circle")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("weightplan-needs-situation")
            Text(tr("Pendant la grossesse ou l'allaitement, Ardane ne calcule pas d'objectif de poids."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout {
                ForEach([LifeStage.adult, .pregnant, .breastfeeding, .preferNotToSay]) { stage in
                    ChoiceChip(title: stage.title, isSelected: model.profile.lifeStage == stage) {
                        model.update(\.profile) { $0.lifeStage = stage }
                    }
                    .accessibilityIdentifier("lifestage-\(stage.rawValue)")
                }
            }
        }
    }

    // MARK: Numbers

    private func recap(_ numbers: WeightPlanCalculator.Plan, plan: WeightPlan, remark: String?) -> some View {
        // The calories really in force: the plan's, not replaced by calories typed by hand.
        let followsCalculation = model.profile.followsNutritionCalculation
        let typedCalories = followsCalculation && model.profile.customTargets.contains(.kcal)
        let accepted = plan.acceptedKcal == numbers.targetKcal
        let applied = accepted && !typedCalories && abs(model.nutrition.goals.kcal - numbers.targetKcal) < 0.5
        return VStack(alignment: .leading, spacing: 12) {
            Label(tr("Ton objectif de poids"), systemImage: "scalemass")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                stat(tr("Poids actuel"), Units.weightText(kilograms: numbers.startKg, in: system))
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                stat(tr("Poids cible"), Units.weightText(kilograms: numbers.targetKg, in: system), highlighted: true)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                stat(tr("Durée"), duration(days: numbers.days))
                stat(tr("Rythme"), pace(numbers))
                stat(tr("Calories par jour"), tr("\(TF.int(numbers.targetKcal)) kcal"), highlighted: true)
                stat(tr("Date estimée"), Fmt.format(numbers.reachDate, template: "dMMMMyyyy"))
                stat(tr("Protéines"), tr("\(TF.int(numbers.goals.protein)) g"))
                stat(tr("Glucides"), tr("\(TF.int(numbers.goals.carbs)) g"))
                stat(tr("Lipides"), tr("\(TF.int(numbers.goals.fat)) g"))
            }
            if let remark {
                Label(remark, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightplan-remark")
            }
            Text(tr("Estimation, pas une garantie : ton corps réagit à son propre rythme. Ce n'est pas un avis médical."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if applied {
                Label(tr("Plan appliqué à tes besoins"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .accessibilityIdentifier("weightplan-applied")
            } else if typedCalories {
                Label(tr("Tes calories saisies restent prioritaires : reviens au calcul pour les remplacer par celles du plan."), systemImage: "hand.point.up.left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightplan-typed-priority")
            } else {
                if !followsCalculation {
                    Text(tr("Appliquer remplace tes valeurs saisies."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("weightplan-replaces-typed")
                }
                PlanButton(title: tr("Appliquer ce plan"), filled: true, accent: accent) {
                    model.acceptWeightPlan()
                }
                .accessibilityIdentifier("weightplan-accept")
            }
        }
    }

    private func stat(_ title: String, _ value: String, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(highlighted ? accent : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.wellColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func duration(days: Int) -> String {
        let weeks = max(1, Int((Double(days) / 7).rounded()))
        return Fmt.plural(weeks, tr("semaine"), tr("semaines"))
    }

    /// « −0,6 kg par semaine (−0,7 %) ».
    private func pace(_ numbers: WeightPlanCalculator.Plan) -> String {
        let sign = numbers.weeklyChangeKg < 0 ? "−" : "+"
        let amount = Units.loadText(kilograms: abs(numbers.weeklyChangeKg), in: system, digits: 2)
        let percent = TF.decimal(abs(numbers.weeklyPercent), 2)
        return tr("\(sign)\(amount) par semaine (\(sign)\(percent) %)")
    }

    // MARK: Unsafe and professional

    private func unsafeView(reason: String, weeks: Int, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(tr("Objectif impossible à atteindre de manière sûre"), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(palette.strong("F08A24"))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("weightplan-unsafe-title")
            Text(reason)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            stat(tr("Durée plus prudente"), tr("\(Fmt.plural(weeks, tr("semaine"), tr("semaines"))), vers le \(Fmt.format(date, template: "dMMMMyyyy"))"), highlighted: true)
            Text(tr("Aucune calorie n'est proposée pour le rythme demandé."))
                .font(.caption)
                .foregroundStyle(.secondary)
            PlanButton(title: tr("Utiliser cette durée"), filled: true, accent: accent) {
                model.setWeightPlanDate(date)
            }
            .accessibilityIdentifier("weightplan-use-suggested")
            if let onEdit {
                PlanButton(title: tr("Modifier l'objectif"), filled: false, accent: accent, action: onEdit)
                    .accessibilityIdentifier("weightplan-edit")
            }
        }
    }

    private func refer(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(tr("Parle à un professionnel de santé"), systemImage: "cross.case")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("weightplan-refer-title")
            Text(reason)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text(tr("Ardane ne propose pas de calories pour cet objectif."))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let onEdit {
                PlanButton(title: tr("Modifier l'objectif"), filled: false, accent: accent, action: onEdit)
                    .accessibilityIdentifier("weightplan-edit")
            }
        }
    }
}

/// A full-width button of the recap.
private struct PlanButton: View {
    let title: String
    let filled: Bool
    let accent: Color
    let action: () -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(filled ? AnyShapeStyle(.onAccent) : AnyShapeStyle(accent))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
                .background(filled ? AnyShapeStyle(accent) : AnyShapeStyle(CristalPalette.of(style.id).tintColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

/// An adjustment the weigh-ins call for: the user accepts it or leaves it for later (nothing changes alone).
struct WeightPlanAdjustmentCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    var body: some View {
        if let proposal = model.proposedAdjustment() {
            let accent = CristalPalette.of(style.id).strong(MiniApp.nutrition.colorHex)
            VStack(alignment: .leading, spacing: 10) {
                Label(tr("Ajustement proposé"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(proposal.reason)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tr("\(TF.int(proposal.previousKcal)) → \(TF.int(proposal.newKcal)) kcal par jour"))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("weightplan-adjustment-values")
                if proposal.limitedBySafety {
                    Text(tr("Le changement est limité par les bornes de sécurité d'Ardane."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    PlanButton(title: tr("Accepter"), filled: true, accent: accent) {
                        model.acceptAdjustment(proposal)
                    }
                    .accessibilityIdentifier("weightplan-adjustment-accept")
                    PlanButton(title: tr("Plus tard"), filled: false, accent: accent) {
                        model.dismissAdjustment()
                    }
                    .accessibilityIdentifier("weightplan-adjustment-later")
                }
            }
            .card(padding: 14)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weightplan-adjustment")
        }
    }
}
