import Charts
import SwiftUI

/// Everything the Business mini-app edits in a sheet.
enum BusinessSheet: Identifiable {
    case sale(SalesEntry?)
    case cost(BusinessExpense?)
    case recurring
    case kpis
    case metric(CustomMetric)
    case metricValue(CustomMetric)
    case settings

    var id: String {
        switch self {
        case let .sale(sale): "sale-\(sale?.id.uuidString ?? "new")"
        case let .cost(cost): "cost-\(cost?.id.uuidString ?? "new")"
        case .recurring: "recurring"
        case .kpis: "kpis"
        case let .metric(metric): "metric-\(metric.id)"
        case let .metricValue(metric): "value-\(metric.id)"
        case .settings: "settings"
        }
    }

    @ViewBuilder
    var editor: some View {
        switch self {
        case let .sale(sale): SaleEditor(sale: sale)
        case let .cost(cost): BusinessCostEditor(cost: cost)
        case .recurring: MRREditor()
        case .kpis: KPIPicker()
        case let .metric(metric): MetricEditor(metric: metric)
        case let .metricValue(metric): MetricValueEditor(metric: metric)
        case .settings: BusinessSettingsEditor()
        }
    }
}

enum BusinessPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: tr("Jour")
        case .week: tr("Semaine")
        case .month: tr("Mois")
        case .year: tr("Année")
        }
    }

    /// « par rapport à hier / la semaine dernière… »
    var previousText: String {
        switch self {
        case .day: tr("hier à la même heure")
        case .week: tr("la semaine dernière à la même date")
        case .month: tr("le mois dernier à la même date")
        case .year: tr("l'an dernier à la même date")
        }
    }

    /// « par rapport au mois dernier… »
    var comparisonText: String {
        switch self {
        case .day: tr("par rapport à hier à la même heure")
        case .week: tr("par rapport à la semaine dernière à la même date")
        case .month: tr("par rapport au mois dernier à la même date")
        case .year: tr("par rapport à l'an dernier à la même date")
        }
    }

    var math: BusinessMath.Period {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }
}

enum BusinessFormat {
    static var accentHex: String { MiniApp.business.colorHex }
    static let goodHex = "1E9E75"
    static let badHex = "E5484D"

    static func value(_ value: Double?, _ kpi: BusinessKPI, currency: String) -> String {
        guard let value else { return "–" }
        switch kpi.unit {
        case .money: return TF.money(value, currency)
        case .percent: return Fmt.percent(value, decimals: 1)
        case .count: return Fmt.number(Int(value.rounded()))
        }
    }

    static func number(_ value: Double, unit: String) -> String {
        let text = value.rounded() == value ? Fmt.number(Int(value)) : TF.decimal(value, 1)
        return unit.isEmpty ? text : "\(text) \(unit)"
    }

    /// "+12,5 %" in green when it goes the good way, red otherwise.
    static func change(_ change: Double?, higherIsBetter: Bool) -> (text: String, hex: String)? {
        guard let change, change.isFinite else { return nil }
        let good = higherIsBetter ? change >= 0 : change <= 0
        return (Fmt.signedPercent(change * 100, decimals: 1), good ? goodHex : badHex)
    }
}

/// The Business mini-app: the period's revenue against the previous one, the indicators the person
/// chose, their own metrics and the revenue curve; then sales and costs, results, recurring revenue.
struct BusinessAppView: View {
    @Environment(AppModel.self) private var model
    @State private var period: BusinessPeriod = .month
    @State private var sheet: BusinessSheet?

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { BusinessFormat.accentHex }

    var body: some View {
        let now = Date()
        let state = model.business
        MiniAppScroll {
            Picker(tr("Période"), selection: $period) {
                ForEach(BusinessPeriod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("business-period")
            if state.sales.isEmpty && state.expenses.isEmpty && state.subscriptions.isEmpty {
                start
            } else {
                hero(state: state, now: now)
            }
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Vente"), symbol: "plus", colorHex: accentHex) { sheet = .sale(nil) }
                    .accessibilityIdentifier("business-add-sale")
                MiniActionButton(title: tr("Dépense"), symbol: "minus", colorHex: accentHex, isProminent: false) { sheet = .cost(nil) }
                    .accessibilityIdentifier("business-add-cost")
            }
            kpis(state: state, now: now)
            metrics(state: state)
            curve(state: state, now: now)
            more(state: state)
            MiniAppSettingsSection(app: .business)
        }
        .navigationTitle(state.name.isEmpty ? tr("Business") : state.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel(Text(tr("Nom et objectif")))
            }
        }
        .sheet(item: $sheet) { $0.editor }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "briefcase.fill").font(.system(size: 28)).foregroundStyle(Color(hex: accentHex))
            Text(tr("Ton activité, chiffres à l'appui")).font(.title3.weight(.bold))
            Text(tr("Note tes ventes (le total du jour suffit) et tes dépenses : chiffre d'affaires, bénéfice, panier moyen et comparaisons se calculent tout seuls."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Revenue

    private func hero(state: BusinessState, now: Date) -> some View {
        let comparison = BusinessMath.compare(.revenue, state, period.math, at: now)
        let change = BusinessFormat.change(comparison.change, higherIsBetter: true)
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr("Chiffre d'affaires")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text(TF.money(comparison.current ?? 0, currency))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            if let change {
                Label("\(change.text) \(period.comparisonText)", systemImage: (comparison.change ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: change.hex))
            } else if let previous = comparison.previous, previous == 0 {
                Text(tr("Rien \(period.previousText)")).font(.subheadline).foregroundStyle(.secondary)
            }
            if period == .month && state.monthlyGoal > 0 {
                let progress = BusinessMath.goalProgress(state, at: now)
                ProgressView(value: min(1, progress)).tint(Color(hex: progress >= 1 ? BusinessFormat.goodHex : accentHex))
                Text(tr("\(Fmt.percent(progress)) de l'objectif de \(TF.money(state.monthlyGoal, currency))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("business-hero")
    }

    // MARK: Indicators

    private func kpis(state: BusinessState, now: Date) -> some View {
        let shown = state.pinnedKPIs.filter { $0 != .revenue }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                MiniSectionTitle(title: tr("Mes indicateurs"))
                Button { sheet = .kpis } label: {
                    Text(tr("Choisir")).font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: accentHex))
                }
                .accessibilityIdentifier("business-choose-kpis")
            }
            if shown.isEmpty {
                Text(tr("Choisis les indicateurs à suivre ici : bénéfice, marge, panier moyen, conversion, MRR…"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(stride(from: 0, to: shown.count, by: 2)), id: \.self) { start in
                        HStack(spacing: 10) {
                            ForEach(shown[start..<min(start + 2, shown.count)]) { kpi in
                                KPITile(kpi: kpi, comparison: BusinessMath.compare(kpi, state, period.math, at: now), currency: currency,
                                        note: kpi.isSnapshot ? tr("ce mois-ci") : nil)
                            }
                            if start + 1 >= shown.count { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("business-kpis")
            }
        }
    }

    @ViewBuilder
    private func metrics(state: BusinessState) -> some View {
        if !state.metrics.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Suivis à la main"))
                NavigationLink(value: HomeRoute.page(.businessMetrics)) {
                    VStack(spacing: 0) {
                        ForEach(Array(state.metrics.prefix(3).enumerated()), id: \.element.id) { index, metric in
                            if index > 0 { MiniDivider() }
                            MetricRow(metric: metric)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("business-metrics")
            }
        }
    }

    // MARK: Curve

    @ViewBuilder
    private func curve(state: BusinessState, now: Date) -> some View {
        let points = BusinessMath.cumulative(state, period.math, at: now)
        if points.contains(where: { ($0.current ?? 0) > 0 || $0.previous > 0 }) {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Chiffre d'affaires cumulé"), detail: period == .day ? tr("cette semaine") : nil)
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value("Jour", point.index), y: .value("Précédent", point.previous), series: .value("Série", tr("Précédent")))
                            .foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                    ForEach(points.filter { $0.current != nil }) { point in
                        LineMark(x: .value("Jour", point.index), y: .value("Actuel", point.current ?? 0), series: .value("Série", tr("Actuel")))
                            .foregroundStyle(Color(hex: accentHex))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartXAxisLabel(period == .year ? tr("Mois") : tr("Jour"))
                .frame(height: 180)
                .card()
                HStack(spacing: 14) {
                    legend(tr("Cette période"), hex: accentHex, dashed: false)
                    legend(tr("Période précédente"), hex: "8A8A8E", dashed: true)
                }
            }
        }
    }

    private func legend(_ title: String, hex: String, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(Color(hex: hex), style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
                .frame(width: 18, height: 2)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: More

    private func more(state: BusinessState) -> some View {
        MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.businessSales)) {
                MiniRow(symbol: "list.bullet.rectangle", colorHex: accentHex, title: tr("Ventes et dépenses"), detail: tr("Tout ce que tu as noté, modifiable"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("business-sales")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.businessResults)) {
                MiniRow(symbol: "chart.bar.xaxis", colorHex: "3366FF", title: tr("Résultats"), detail: tr("Chiffre d'affaires, dépenses et bénéfice par mois"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("business-results")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.businessRecurring)) {
                MiniRow(symbol: "arrow.triangle.2.circlepath", colorHex: "1E9E75", title: tr("Revenu récurrent"),
                        detail: BusinessMath.recurring(state).map { tr("MRR \(TF.money($0.mrr, currency))") } ?? tr("MRR, abonnés, ARR"))
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.businessMetrics)) {
                MiniRow(symbol: "gauge.with.dots.needle.33percent", colorHex: "F2A33A", title: tr("Suivis à la main"),
                        detail: tr("Tes propres indicateurs"), value: state.metrics.isEmpty ? nil : "\(state.metrics.count)")
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Shared pieces

/// An indicator: its value for the period and how it moved.
struct KPITile: View {
    let kpi: BusinessKPI
    let comparison: BusinessMath.Comparison
    let currency: String
    var note: String?

    var body: some View {
        let change = BusinessFormat.change(comparison.change, higherIsBetter: kpi.higherIsBetter)
        VStack(alignment: .leading, spacing: 5) {
            Label(kpi.title, systemImage: kpi.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(BusinessFormat.value(comparison.current, kpi, currency: currency))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let change {
                Text(change.text).font(.caption.weight(.semibold)).foregroundStyle(Color(hex: change.hex))
            } else {
                Text(note ?? (comparison.current == nil ? tr("pas encore de données") : tr("rien avant"))).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A metric followed by hand: its latest value, its change and its target.
struct MetricRow: View {
    let metric: CustomMetric

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "F2A33A"))
                .frame(width: 34, height: 34)
                .background(Color(hex: "F2A33A").opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name).font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(metric.latest.map { BusinessFormat.number($0.value, unit: metric.unit) } ?? "–")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                if let change = BusinessFormat.change(metric.change, higherIsBetter: metric.higherIsBetter) {
                    Text(change.text).font(.caption.weight(.semibold)).foregroundStyle(Color(hex: change.hex))
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var detail: String {
        var parts: [String] = []
        if let latest = metric.latest { parts.append(Fmt.shortDay(latest.date)) }
        if let target = metric.target, let latest = metric.latest, target > 0 {
            parts.append(tr("objectif \(BusinessFormat.number(target, unit: metric.unit)) · \(Fmt.percent(latest.value / target))"))
        }
        return parts.isEmpty ? tr("Aucune valeur") : parts.joined(separator: " · ")
    }
}

/// Which indicators the dashboard shows.
struct KPIPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BusinessKPI.allCases) { kpi in
                        Button {
                            Haptics.tap()
                            model.update(\.business) { $0.togglePinned(kpi) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: kpi.symbol).frame(width: 24).foregroundStyle(Color(hex: BusinessFormat.accentHex))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kpi.title).foregroundStyle(.primary)
                                    Text(explanation(kpi)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: model.business.pinnedKPIs.contains(kpi) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(model.business.pinnedKPIs.contains(kpi) ? Color(hex: BusinessFormat.accentHex) : Color.secondary)
                            }
                        }
                        .accessibilityIdentifier("kpi-\(kpi.rawValue)")
                    }
                } footer: {
                    Text(tr("Le chiffre d'affaires reste toujours en haut. Chaque indicateur est comparé à la période précédente, arrêtée au même moment."))
                }
            }
            .styledList()
            .navigationTitle(tr("Mes indicateurs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
    }

    private func explanation(_ kpi: BusinessKPI) -> String {
        switch kpi {
        case .revenue: tr("Le total de tes ventes")
        case .costs: tr("Le total de tes dépenses")
        case .profit: tr("Ventes moins dépenses")
        case .margin: tr("Le bénéfice rapporté aux ventes")
        case .orders: tr("Le nombre de commandes")
        case .averageBasket: tr("Ventes divisées par les commandes")
        case .newCustomers: tr("Les clients arrivés sur la période")
        case .visitors: tr("Les visites notées avec tes ventes")
        case .conversion: tr("Commandes divisées par les visiteurs")
        case .mrr: tr("Revenu mensuel récurrent (abonnements)")
        case .subscribers: tr("Clients abonnés")
        }
    }
}

/// The business name and the monthly revenue goal.
struct BusinessSettingsEditor: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var goal: Double = 0

    var body: some View {
        SheetForm(title: tr("Mon activité"), canSave: true, onSave: save) {
            Section {
                TextField(tr("Nom de l'entreprise"), text: $name)
                NumberRow(title: tr("Objectif du mois"), value: $goal, unit: model.settings.currencyCode)
            } footer: {
                Text(tr("L'objectif sert à la barre de progression du mois."))
            }
        }
        .onAppear {
            name = model.business.name
            goal = model.business.monthlyGoal
        }
    }

    private func save() {
        model.setBusinessName(name.trimmed.isEmpty ? tr("Mon entreprise") : name.trimmed)
        model.setBusinessGoal(max(0, goal))
    }
}

/// A metric followed by hand: its name, unit, direction and target.
struct MetricEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var metric: CustomMetric
    @State private var hasTarget = false
    @State private var target: Double = 0
    @State private var firstValue: Double = 0

    private var isNew: Bool { !model.business.metrics.contains { $0.id == metric.id } }

    var body: some View {
        SheetForm(title: isNew ? tr("Nouvel indicateur") : metric.name, canSave: !metric.name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField(tr("Nom (abonnés, devis envoyés, NPS…)"), text: $metric.name)
                    .accessibilityIdentifier("metric-name")
                TextField(tr("Unité (facultatif)"), text: $metric.unit)
                Toggle(tr("Plus c'est haut, mieux c'est"), isOn: $metric.higherIsBetter)
                Toggle(tr("Objectif"), isOn: $hasTarget)
                if hasTarget {
                    NumberRow(title: tr("Valeur visée"), value: $target)
                }
            }
            if isNew {
                Section(tr("Valeur d'aujourd'hui (facultatif)")) {
                    NumberRow(title: tr("Valeur"), value: $firstValue)
                }
            } else {
                Section {
                    Button(tr("Supprimer l'indicateur"), role: .destructive) {
                        let id = metric.id
                        model.update(\.business) { $0.metrics.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            hasTarget = metric.target != nil
            target = metric.target ?? 0
        }
    }

    private func save() {
        var saved = metric
        saved.name = saved.name.trimmed
        saved.unit = saved.unit.trimmed
        saved.target = hasTarget && target > 0 ? target : nil
        if isNew && firstValue != 0 { saved.record(firstValue) }
        model.update(\.business) { state in
            if let index = state.metrics.firstIndex(where: { $0.id == saved.id }) { state.metrics[index] = saved } else { state.metrics.append(saved) }
        }
        Haptics.success()
    }
}

/// Today's value of a metric (a value the same day replaces it).
struct MetricValueEditor: View {
    let metric: CustomMetric
    @Environment(AppModel.self) private var model
    @State private var value: Double = 0
    @State private var date = Date()

    var body: some View {
        SheetForm(title: metric.name, canSave: true, onSave: save) {
            Section {
                NumberRow(title: tr("Valeur"), value: $value, unit: metric.unit.isEmpty ? nil : metric.unit)
                    .accessibilityIdentifier("metric-value")
                DatePicker(tr("Date"), selection: $date, in: ...Date(), displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
            } footer: {
                if let latest = metric.latest {
                    Text(tr("Dernière valeur : \(BusinessFormat.number(latest.value, unit: metric.unit)), \(Fmt.shortDay(latest.date))."))
                }
            }
        }
        .onAppear { value = metric.latest?.value ?? 0 }
    }

    private func save() {
        let id = metric.id
        let recorded = value
        let day = date
        model.update(\.business) { state in
            guard let index = state.metrics.firstIndex(where: { $0.id == id }) else { return }
            state.metrics[index].record(recorded, at: day)
        }
        Haptics.success()
    }
}
