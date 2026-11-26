import SwiftUI
import Charts

/// The deep part of « Analyse » (2026-11-26): savings rate, end-of-month projection, categories against their
/// average, recurring spending and the days of the week. Every figure comes from `BudgetAnalysis` and has its
/// formula written under it; figures only, no advice. Too little noted: an honest empty state.
struct FinancesDeepAnalysis: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    private var currency: String { model.settings.currencyCode }
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let state = model.budget
        let now = Date()
        let savings = BudgetAnalysis.savings(state, at: now)
        let projection = BudgetAnalysis.projection(state, at: now)
        let trends = BudgetAnalysis.categoryTrends(state, at: now)
        let recurring = BudgetAnalysis.recurring(state, at: now)
        let weekdays = BudgetAnalysis.weekdays(state, at: now)
        let hasAverage = trends.contains { $0.average != nil && ($0.average ?? 0) + $0.current > 0 }
        VStack(alignment: .leading, spacing: 22) {
            if savings == nil && projection == nil && recurring.isEmpty && weekdays == nil && !hasAverage {
                Text(tr("Pas encore assez d'opérations pour une analyse détaillée : elle apparaît dès que tu as noté quelques dépenses et revenus."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            if let savings { savingsCard(savings) }
            if let projection { projectionCard(projection, now: now) }
            if hasAverage { averageSection(trends) }
            if !recurring.isEmpty { recurringSection(recurring) }
            if let weekdays, let top = BudgetAnalysis.priciestWeekday(weekdays) { weekdaySection(weekdays, top: top) }
        }
        .accessibilityIdentifier("trends-deep")
    }

    /// A line under a figure that says how it is computed.
    private func formula(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Savings rate

    private func savingsCard(_ savings: BudgetAnalysis.Savings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Taux d'épargne"), detail: Fmt.monthYear(Date()).capitalizedFirst)
            VStack(alignment: .leading, spacing: 10) {
                if let rate = savings.rate {
                    HStack(spacing: 10) {
                        MiniStat(title: tr("Part des revenus gardée"), value: Fmt.percent(rate),
                                 colorHex: rate < 0 ? Finances.overHex : Finances.incomeHex)
                        MiniStat(title: tr("Revenus"), value: TF.money(savings.earned, currency), colorHex: Finances.incomeHex)
                        MiniStat(title: tr("Dépenses"), value: TF.money(savings.spent, currency))
                    }
                    formula(tr("(revenus − dépenses) ÷ revenus, du 1er du mois à aujourd'hui : (\(TF.money(savings.earned, currency)) − \(TF.money(savings.spent, currency))) ÷ \(TF.money(savings.earned, currency))."))
                } else {
                    Text(tr("Aucun revenu noté ce mois-ci : le taux d'épargne ne peut pas être calculé. \(TF.money(savings.spent, currency)) dépensés."))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("trends-savings-rate")
        }
    }

    // MARK: Projection

    private func projectionCard(_ projection: BudgetAnalysis.Projection, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Projection de fin de mois"), detail: Fmt.monthYear(now).capitalizedFirst)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    MiniStat(title: tr("Fin de mois"), value: TF.money(projection.projected, currency))
                    MiniStat(title: tr("Rythme par jour"), value: TF.money(projection.perDay, currency))
                    MiniStat(title: tr("Déjà noté à venir"), value: TF.money(projection.plannedAhead, currency))
                }
                formula(tr("Dépensé à ce jour + (dépensé ÷ jours écoulés) × jours restants + ce qui est déjà noté pour la suite : \(TF.money(projection.spentToDate, currency)) + (\(TF.money(projection.spentToDate, currency)) ÷ \(projection.daysElapsed)) × \(projection.daysLeft) + \(TF.money(projection.plannedAhead, currency))."))
                if model.profile.knows(.monthlyBudget), model.budget.monthlyBudget > 0 {
                    let gap = projection.projected - model.budget.monthlyBudget
                    Text(gap > 0
                         ? tr("\(TF.money(gap, currency)) de plus que ton budget de \(TF.money(model.budget.monthlyBudget, currency)).")
                         : tr("\(TF.money(-gap, currency)) de moins que ton budget de \(TF.money(model.budget.monthlyBudget, currency))."))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .card()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("trends-projection")
        }
    }

    // MARK: Categories against their average

    private func averageSection(_ trends: [BudgetAnalysis.CategoryTrend]) -> some View {
        let rows = trends.filter { $0.average != nil && $0.current + ($0.average ?? 0) > 0 }
        let months = rows.first?.averageMonths ?? 0
        let rises = BudgetAnalysis.biggestRises(trends)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Catégories face à leur moyenne"), detail: tr("à la même date"))
            MiniRowsCard {
                ForEach(Array(rows.prefix(6).enumerated()), id: \.element.id) { index, row in
                    if index > 0 { MiniDivider() }
                    let difference = row.differenceFromAverage ?? 0
                    MiniRow(symbol: row.symbol, colorHex: row.colorHex, title: row.name,
                            detail: tr("\(TF.money(row.current, currency)) · moyenne \(TF.money(row.average ?? 0, currency)) · mois dernier \(TF.money(row.previous, currency))"),
                            value: (difference >= 1 ? "+" : difference <= -1 ? "−" : "") + TF.money(abs(difference), currency),
                            showsChevron: false)
                }
            }
            .accessibilityIdentifier("trends-averages")
            formula(tr("Écart = dépensé ce mois-ci − moyenne des \(Fmt.plural(months, tr("mois précédent"), tr("mois précédents"))) où tu as noté des dépenses, tous mesurés jusqu'au même moment du mois."))
            if !rises.isEmpty {
                MiniSectionTitle(title: tr("Plus grosses hausses"))
                MiniRowsCard {
                    ForEach(Array(rises.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { MiniDivider() }
                        MiniRow(symbol: "arrow.up.right", colorHex: Finances.overHex, title: row.name,
                                detail: tr("moyenne \(TF.money(row.average ?? 0, currency)) → \(TF.money(row.current, currency))"),
                                value: "+" + TF.money(row.differenceFromAverage ?? 0, currency), showsChevron: false)
                    }
                }
                formula(tr("Les trois catégories dont l'écart avec la moyenne est le plus grand vers le haut."))
            }
        }
    }

    // MARK: Recurring spending

    private func recurringSection(_ items: [BudgetAnalysis.Recurring]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Dépenses récurrentes détectées"), detail: tr("6 derniers mois"))
            MiniRowsCard {
                ForEach(Array(items.prefix(6).enumerated()), id: \.element.id) { index, item in
                    if index > 0 { MiniDivider() }
                    MiniRow(symbol: "arrow.triangle.2.circlepath", colorHex: Finances.accentHex, title: item.label,
                            detail: tr("\(item.months) mois sur 6"), value: TF.money(item.amount, currency), showsChevron: false)
                }
            }
            .accessibilityIdentifier("trends-recurring")
            formula(tr("Même libellé noté dans au moins 3 mois différents, à des montants à 10 % près de leur médiane. Les factures et dépenses fixes déjà déclarées sont à part."))
        }
    }

    // MARK: Days of the week

    private func weekdaySection(_ days: [BudgetAnalysis.WeekdaySpend], top: BudgetAnalysis.WeekdaySpend) -> some View {
        let symbols = DateMath.calendar.standaloneWeekdaySymbols
        func name(_ day: BudgetAnalysis.WeekdaySpend) -> String { symbols[(day.weekday - 1) % 7].capitalizedFirst }
        let ink = palette.category(Finances.spentHex)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Jours de la semaine"), detail: tr("dépense moyenne par jour"))
            VStack(alignment: .leading, spacing: 10) {
                Chart(days) { day in
                    BarMark(x: .value("Jour", name(day)), y: .value("Moyenne", day.average))
                        .foregroundStyle(day.weekday == top.weekday ? ink : ink.opacity(0.35))
                        .cornerRadius(3)
                }
                .chartXScale(domain: days.map(name))
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let text = value.as(String.self) { Text(String(text.prefix(3))) }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(tr("Dépense moyenne par jour de la semaine")))
                .accessibilityValue(Text(tr("\(name(top)) : \(TF.money(top.average, currency)) en moyenne")))
                Text(tr("Le \(name(top).lowercased()) est ton jour le plus dépensier : \(TF.money(top.average, currency)) en moyenne."))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                formula(tr("Total dépensé ce jour de la semaine ÷ nombre de ces jours, sur les 12 dernières semaines (ou depuis ta première dépense)."))
            }
            .card()
            .accessibilityIdentifier("trends-weekdays")
        }
    }
}
