import SwiftUI

// Pièces communes de la refonte de Finances (direction 5 « hybride », choisie par le PDG le 2026-11-16) :
// la barre du budget avec le repère du rythme, et la ligne d'une échéance (facture, abonnement, montant fixe).

extension Finances {
    /// What went out, in charts and figures: a dark slate ink, distinct from the green of what came in. Red stays for
    /// an overspent budget only, and a state never rests on the color alone (a sign, a word).
    static let spentHex = "45566E"
}

/// The month's budget as a bar: what was spent, and a mark where the spending would be if it followed the month
/// evenly (the share of the month gone by). Past the mark: spending faster than planned; over the end: overspent.
struct FinancesPaceBar: View {
    let spent: Double
    let budget: Double
    /// The share of the month gone by at the end of the chosen day (`BudgetMath.monthFraction`).
    let fraction: Double
    var height: CGFloat = 10
    @Environment(\.appStyle) private var style

    private var ratio: Double { budget > 0 ? max(0, spent / budget) : 0 }

    var body: some View {
        let palette = CristalPalette.of(style.id)
        let fill = ratio > 1 ? palette.category(Finances.overHex) : palette.category(Finances.spentHex)
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(palette.trackColor).frame(height: height)
                Capsule().fill(fill).frame(width: max(height, width * min(1, ratio)), height: height)
                    .opacity(spent > 0 ? 1 : 0)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary)
                    .frame(width: 2, height: height + 8)
                    .offset(x: min(max(0, width * min(1, fraction) - 1), width - 2))
            }
            .frame(height: height + 8)
        }
        .frame(height: height + 8)
        .accessibilityElement()
        .accessibilityLabel(Text(tr("Budget du mois")))
        .accessibilityValue(Text(tr("\(Fmt.percent(min(ratio, 9.99))) dépensé, \(Fmt.percent(fraction)) du mois écoulé")))
    }
}

/// A date that comes back: the day in a small block (weekday and number), the name, what it is and when, the amount.
/// Due tomorrow or today, the block turns red, with the word « Demain » or « Aujourd'hui » written beside it.
struct FinancesDueRow: View {
    let item: BudgetMath.UpcomingItem
    let now: Date
    let currency: String
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        let isSoon = !item.isIncome && item.days <= 1
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(Fmt.format(item.due, template: "EEE").uppercased())
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(Fmt.format(item.due, template: "d"))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSoon ? palette.strong(Finances.overHex) : Color.primary)
            .frame(width: 40)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(kind) · \(TF.relativeDay(item.due, from: now).capitalizedFirst)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text((item.isIncome ? "+" : "") + TF.money(item.amount, currency, decimals: 2))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.isIncome ? palette.strong(Finances.incomeHex) : Color.primary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var kind: String {
        switch item.source {
        case let .bill(bill): bill.isSubscription ? tr("Abonnement") : tr("Facture")
        case let .fixed(flow): flow.isIncome ? tr("Revenu fixe") : tr("Dépense fixe")
        }
    }
}
