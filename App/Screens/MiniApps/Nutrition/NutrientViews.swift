import SwiftUI

extension PaywallContext {
    /// Every nutrient but the calories, protein, carbohydrates and fat.
    static var nutrients: PaywallContext {
        let count = Nutrient.allCases.filter(\.isPremium).count
        return PaywallContext(
            symbol: "leaf.fill",
            title: tr("Tous les nutriments"),
            detail: tr("\(count) nutriments en plus des calories, protéines, glucides et lipides, avec tes besoins calculés. Ce que tu notes est gardé : tout s'affiche dès que tu passes à Premium.")
        )
    }
}

/// In place of the nutrients of Premium: what they are, one touch from the paywall. The values of the foods
/// and the targets typed by hand are kept, and shown again with Premium.
struct NutrientLockRow: View {
    @State private var paywall: PaywallContext?

    var body: some View {
        Button {
            paywall = .nutrients
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Tous les nutriments"))
                        .foregroundStyle(Color.primary)
                    Text(tr("Fibres, sucres, gras, minéraux, vitamines, caféine…"))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                PremiumBadge()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nutrients-premium")
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }
}

/// The nutrients of Premium in an amount of food, group by group: only the values the food gives.
struct FoodNutrientSections: View {
    let totals: NutritionTotals

    var body: some View {
        ForEach(Nutrient.Group.allCases.filter { $0 != .energy }, id: \.self) { group in
            let known = group.nutrients.filter { Self.shows($0, in: totals) }
            if !known.isEmpty {
                Section(group.title) {
                    ForEach(known) { nutrient in
                        ValueRow(title: nutrient.title, value: nutrient.formatAmount(nutrient.value(in: totals) ?? 0))
                    }
                }
            }
        }
    }

    /// A value the food gives. No « Caféine 0 mg » or « Alcool 0 g » on the many foods that have none (the
    /// zero stays known in the data and in the day's totals).
    static func shows(_ nutrient: Nutrient, in totals: NutritionTotals) -> Bool {
        guard let value = nutrient.value(in: totals) else { return false }
        return value > 0 || (nutrient != .caffeine && nutrient != .alcohol)
    }
}
