import Charts
import SwiftUI

// MARK: - Sales and costs

struct BusinessSalesPage: View {
    enum Kind: String, CaseIterable, Identifiable {
        case sales, costs
        var id: String { rawValue }
        var title: String { self == .sales ? "Ventes" : "Dépenses" }
    }

    @Environment(AppModel.self) private var model
    @State private var kind: Kind = .sales
    @State private var sheet: BusinessSheet?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.business
        List {
            Section {
                Picker("Type", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            if kind == .sales {
                sales(state: state)
            } else {
                costs(state: state)
            }
        }
        .styledList()
        .tint(Color(hex: BusinessFormat.accentHex))
        .navigationTitle("Ventes et dépenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = kind == .sales ? BusinessSheet.sale(nil) : BusinessSheet.cost(nil) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text(kind == .sales ? "Nouvelle vente" : "Nouvelle dépense"))
            }
        }
        .sheet(item: $sheet) { $0.editor }
    }

    @ViewBuilder
    private func sales(state: BusinessState) -> some View {
        let sorted = state.sales.sorted { $0.date > $1.date }
        if sorted.isEmpty {
            Section { Text("Aucune vente notée pour l'instant.").foregroundStyle(.secondary) }
        }
        ForEach(monthStarts(sorted.map(\.date)), id: \.self) { month in
            let items = sorted.filter { DateMath.calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            Section {
                ForEach(items) { sale in
                    Button { sheet = .sale(sale) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Fmt.shortDay(sale.date)).foregroundStyle(.primary)
                                Text(saleDetail(sale)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(TF.money(sale.amount, currency, decimals: 2)).monospacedDigit().foregroundStyle(.primary)
                        }
                    }
                    .accessibilityIdentifier("sale-row")
                }
                .onDelete { offsets in
                    let ids = offsets.map { items[$0].id }
                    model.update(\.business) { $0.sales.removeAll { ids.contains($0.id) } }
                }
            } header: {
                HStack {
                    Text(Fmt.monthYear(month).capitalizedFirst)
                    Spacer()
                    Text(TF.money(items.reduce(0) { $0 + $1.amount }, currency))
                }
            }
        }
    }

    @ViewBuilder
    private func costs(state: BusinessState) -> some View {
        let sorted = state.expenses.sorted { $0.date > $1.date }
        if sorted.isEmpty {
            Section { Text("Aucune dépense notée pour l'instant.").foregroundStyle(.secondary) }
        }
        ForEach(monthStarts(sorted.map(\.date)), id: \.self) { month in
            let items = sorted.filter { DateMath.calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            Section {
                ForEach(items) { cost in
                    Button { sheet = .cost(cost) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cost.label).foregroundStyle(.primary)
                                Text(Fmt.shortDay(cost.date)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("−\(TF.money(cost.amount, currency, decimals: 2))").monospacedDigit().foregroundStyle(.primary)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { items[$0].id }
                    model.update(\.business) { $0.expenses.removeAll { ids.contains($0.id) } }
                }
            } header: {
                HStack {
                    Text(Fmt.monthYear(month).capitalizedFirst)
                    Spacer()
                    Text(TF.money(items.reduce(0) { $0 + $1.amount }, currency))
                }
            }
        }
    }

    private func saleDetail(_ sale: SalesEntry) -> String {
        var parts = [Fmt.plural(sale.orders, "commande", "commandes")]
        if sale.newCustomers > 0 { parts.append(Fmt.plural(sale.newCustomers, "nouveau client", "nouveaux clients")) }
        if !sale.note.isEmpty { parts.append(sale.note) }
        return parts.joined(separator: " · ")
    }

    /// The first day of each month present, most recent first.
    private func monthStarts(_ dates: [Date]) -> [Date] {
        Array(Set(dates.map { BusinessMath.interval(.month, containing: $0).start })).sorted(by: >)
    }
}

// MARK: - Results

/// Revenue, costs and profit month by month, with the margin and the year so far.
struct BusinessResultsPage: View {
    @Environment(AppModel.self) private var model

    private var currency: String { model.settings.currencyCode }

    private struct Bar: Identifiable {
        let month: Date
        let series: String
        let value: Double
        var id: String { "\(series)-\(month.timeIntervalSince1970)" }
    }

    var body: some View {
        let state = model.business
        let now = Date()
        // From the first month with something noted: no empty months before the data starts.
        let months = Array(BusinessMath.months(state, count: 6, at: now).drop(while: { $0.revenue == 0 && $0.costs == 0 }))
        let year = BusinessMath.interval(.year, containing: now)
        let revenue = BusinessMath.revenue(state, in: year)
        let costs = BusinessMath.costs(state, in: year)
        MiniAppScroll {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: months.count >= 6 ? "Six derniers mois" : "Par mois")
                Chart {
                    ForEach(bars(months)) { bar in
                        BarMark(x: .value("Mois", bar.month, unit: .month), y: .value("Montant", bar.value))
                            .foregroundStyle(by: .value("Type", bar.series))
                            .position(by: .value("Type", bar.series))
                            .cornerRadius(3)
                    }
                    ForEach(months) { month in
                        LineMark(x: .value("Mois", month.start, unit: .month), y: .value("Bénéfice", month.profit))
                            .foregroundStyle(by: .value("Type", "Bénéfice"))
                            .symbol(.circle)
                    }
                }
                .chartForegroundStyleScale(["Chiffre d'affaires": Color(hex: BusinessFormat.accentHex), "Dépenses": Color(hex: "8A8A8E").opacity(0.5), "Bénéfice": Color(hex: BusinessFormat.goodHex)])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .frame(height: 220)
                .card()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("results-chart")
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: "Depuis le 1er janvier")
                HStack(spacing: 10) {
                    MiniStat(title: "Chiffre d'affaires", value: TF.money(revenue, currency))
                    MiniStat(title: "Bénéfice", value: TF.money(revenue - costs, currency),
                             detail: revenue > 0 ? "marge \(Fmt.percent((revenue - costs) / revenue))" : nil,
                             colorHex: revenue - costs < 0 ? BusinessFormat.badHex : BusinessFormat.goodHex)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: "Mois par mois")
                MiniRowsCard {
                    ForEach(Array(months.reversed().enumerated()), id: \.element.id) { index, month in
                        if index > 0 { MiniDivider() }
                        MiniRow(symbol: "calendar", colorHex: BusinessFormat.accentHex, title: Fmt.monthYear(month.start).capitalizedFirst,
                                detail: "\(TF.money(month.revenue, currency)) − \(TF.money(month.costs, currency))",
                                value: TF.money(month.profit, currency), showsChevron: false)
                    }
                }
            }
            Text("Le bénéfice ici, c'est tes ventes moins les dépenses que tu as notées : un repère, pas un résultat comptable.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Résultats")
        .navigationBarTitleDisplayMode(.large)
    }

    private func bars(_ months: [BusinessMath.MonthResult]) -> [Bar] {
        months.flatMap { [Bar(month: $0.start, series: "Chiffre d'affaires", value: $0.revenue), Bar(month: $0.start, series: "Dépenses", value: $0.costs)] }
    }
}

// MARK: - Recurring revenue

struct BusinessRecurringPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: BusinessSheet?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.business
        let snapshots = state.subscriptions.sorted { $0.month < $1.month }
        MiniAppScroll {
            if let recurring = BusinessMath.recurring(state) {
                HStack(spacing: 10) {
                    MiniStat(title: "MRR", value: TF.money(recurring.mrr, currency),
                             detail: recurring.growth.map { "\(Fmt.signedPercent($0 * 100)) sur un mois" }, colorHex: "1E9E75")
                    MiniStat(title: "ARR", value: TF.money(recurring.arr, currency), detail: "MRR × 12")
                    MiniStat(title: "Abonnés", value: Fmt.number(recurring.subscribers),
                             detail: recurring.subscribers > 0 ? "\(TF.money(recurring.mrr / Double(recurring.subscribers), currency, decimals: 2)) chacun" : nil)
                }
            } else {
                Text("Si tu vends des abonnements, note ton revenu mensuel récurrent chaque mois : Tessera en suit la croissance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            MiniActionButton(title: "Mettre à jour le MRR", symbol: "arrow.triangle.2.circlepath", colorHex: "1E9E75") { sheet = .recurring }
                .accessibilityIdentifier("recurring-update")
            if snapshots.count >= 2 {
                Chart(snapshots) { snapshot in
                    LineMark(x: .value("Mois", snapshot.month, unit: .month), y: .value("MRR", snapshot.mrr))
                        .foregroundStyle(Color(hex: "1E9E75"))
                        .symbol(.circle)
                    AreaMark(x: .value("Mois", snapshot.month, unit: .month), y: .value("MRR", snapshot.mrr))
                        .foregroundStyle(Color(hex: "1E9E75").opacity(0.12).gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .frame(height: 180)
                .card()
            }
            if !snapshots.isEmpty {
                MiniRowsCard {
                    ForEach(Array(snapshots.reversed().enumerated()), id: \.element.id) { index, snapshot in
                        if index > 0 { MiniDivider() }
                        MiniRow(symbol: "calendar", colorHex: "1E9E75", title: Fmt.monthYear(snapshot.month).capitalizedFirst,
                                detail: Fmt.plural(snapshot.subscribers, "abonné", "abonnés"), value: TF.money(snapshot.mrr, currency), showsChevron: false)
                            .contextMenu {
                                Button(role: .destructive) {
                                    model.update(\.business) { $0.subscriptions.removeAll { $0.id == snapshot.id } }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Revenu récurrent")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }
}

// MARK: - Metrics followed by hand

struct BusinessMetricsPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: BusinessSheet?

    var body: some View {
        let metrics = model.business.metrics
        MiniAppScroll {
            MiniActionButton(title: "Nouvel indicateur", symbol: "plus", colorHex: BusinessFormat.accentHex) {
                sheet = .metric(CustomMetric(name: ""))
            }
            .accessibilityIdentifier("metrics-new")
            if metrics.isEmpty {
                Text("Abonnés, devis envoyés, avis clients, NPS… Crée les indicateurs qui comptent pour toi et note leur valeur quand tu veux : Tessera trace leur évolution.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            ForEach(metrics) { metric in
                card(metric)
            }
        }
        .navigationTitle("Suivis à la main")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func card(_ metric: CustomMetric) -> some View {
        let values = metric.sortedValues
        return VStack(alignment: .leading, spacing: 10) {
            Button { sheet = .metric(metric) } label: { MetricRow(metric: metric) }
                .buttonStyle(.plain)
            if values.count >= 2 {
                Chart(values, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value(metric.name, point.value))
                        .foregroundStyle(Color(hex: "F2A33A"))
                        .symbol(.circle)
                    if let target = metric.target {
                        RuleMark(y: .value("Objectif", target))
                            .foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 120)
            }
            Button { sheet = .metricValue(metric) } label: {
                Label("Noter une valeur", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: BusinessFormat.accentHex))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("metric-add-value")
        }
        .card(padding: 14)
    }
}
