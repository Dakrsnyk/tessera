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

    var id: String {
        switch self {
        case let .sale(sale): "sale-\(sale?.id.uuidString ?? "new")"
        case let .cost(cost): "cost-\(cost?.id.uuidString ?? "new")"
        case .recurring: "recurring"
        case .kpis: "kpis"
        case let .metric(metric): "metric-\(metric.id)"
        case let .metricValue(metric): "value-\(metric.id)"
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
    static let goodHex = MiniStyle.goodHex
    static let badHex = MiniStyle.alertHex

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

/// The Business mini-app, top to bottom, in the « Hybride » layout (direction 5, 2026-11-17): the month first, the
/// two entries under the thumb. On the band: the week selector, then the revenue of the period around the chosen
/// day (what is counted, the variation, the goal gauge), with the period choice just above it. On the sheet: the
/// indicators the person chose (tiles), the revenue curve, the four pages with a summary each, the sources, the
/// settings last. « Vente » and « Dépense » float above the tab bar. With nothing noted yet, the start card holds
/// the two entries and the sources come right after it.
struct BusinessAppView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var period: BusinessPeriod = .month
    @State private var sheet: BusinessSheet?
    @State private var day = Date()

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { BusinessFormat.accentHex }

    /// The moment the figures are read at: now for today, the end of the chosen day otherwise, so the period
    /// around that day is counted up to it.
    private func reference(now: Date) -> Date {
        DateMath.isSameDay(day, now) ? now : DateMath.nextMidnight(after: day).addingTimeInterval(-1)
    }

    var body: some View {
        let now = Date()
        let at = reference(now: now)
        let state = model.business
        let isEmpty = state.sales.isEmpty && state.expenses.isEmpty && state.subscriptions.isEmpty
        MiniAppScaffold(colorHex: accentHex) {
            // The band: the only date selector (sales and costs are real, so it stops at today), then the
            // revenue (its period is a granularity, not a date), straight on the band.
            WeekSelector(day: $day, colorHex: accentHex, allowsFuture: false, mark: { dayMark($0, state: state) })
            if isEmpty {
                start
            } else {
                hero(state: state, now: at)
            }
        } sheet: {
            // The sheet, by importance: the goal to set, the indicators, the curve, the pages, the sources, the
            // settings last. Nothing noted yet: the sources come right after the start card, no empty tiles.
            MiniAppToFillSection(app: .business)
            if isEmpty {
                BusinessSourcesCard()
                more(state: state, now: at)
            } else {
                kpis(state: state, now: at)
                curve(state: state, now: at)
                more(state: state, now: at)
                BusinessSourcesCard()
            }
            MiniAppInfoSection(app: .business)
            // Room for the floating actions.
            if !isEmpty { Color.clear.frame(height: 80) }
        }
        .overlay(alignment: .bottom) {
            if !isEmpty {
                BusinessFloatingActions(colorHex: accentHex, sale: { sheet = .sale(nil) }, cost: { sheet = .cost(nil) })
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle(tr("Business"))
        .sheet(item: $sheet) { $0.editor }
    }

    private var start: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "briefcase.fill").font(.system(size: 28))
            Text(tr("Ton activité, chiffres à l'appui")).font(.title3.weight(.bold))
            Text(tr("Note tes ventes (le total du jour suffit) et tes dépenses : chiffre d'affaires, bénéfice, panier moyen et comparaisons se calculent tout seuls."))
                .font(.subheadline)
                .opacity(0.8)
                .fixedSize(horizontal: false, vertical: true)
            // First opening: the two entries are in the card (the floating ones come with the first figures).
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Vente"), symbol: "plus", colorHex: accentHex) { sheet = .sale(nil) }
                    .accessibilityIdentifier("business-add-sale")
                MiniActionButton(title: tr("Dépense"), symbol: "minus", colorHex: accentHex, isProminent: false) { sheet = .cost(nil) }
                    .accessibilityIdentifier("business-add-cost")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Revenue

    /// A day holding at least one sale or one cost is marked on the selector.
    private func dayMark(_ date: Date, state: BusinessState) -> WeekDayMark {
        let holdsSomething = state.sales.contains { DateMath.isSameDay($0.date, date) }
            || state.expenses.contains { DateMath.isSameDay($0.date, date) }
        return WeekDayMark(isPlanned: holdsSomething)
    }

    private func hero(state: BusinessState, now: Date) -> some View {
        let comparison = BusinessMath.compare(.revenue, state, period.math, at: now)
        let change = BusinessFormat.change(comparison.change, higherIsBetter: true)
        // The variation against the previous period (or its absence), then the progress to the month's goal.
        var lines: [String] = []
        if let change {
            lines.append("\(change.text) \(period.comparisonText)")
        } else if let previous = comparison.previous, previous == 0 {
            lines.append(tr("Rien \(period.previousText)"))
        }
        let revenue = comparison.current ?? 0
        let caption: String? = lines.isEmpty ? nil : lines.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 10) {
            // The period is how far the revenue reaches (a day, a week…) around the chosen day.
            Picker(tr("Période"), selection: $period) {
                ForEach(BusinessPeriod.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("business-period")
            BusinessHeroCard(value: TF.money(revenue, currency), periodText: periodText(now: now), caption: caption,
                             goal: period == .month ? state.monthlyGoal : 0, revenue: revenue, currency: currency,
                             // The pace « par jour d'ici la fin du mois » only makes sense for the month in progress.
                             perDay: DateMath.calendar.isDate(now, equalTo: Date(), toGranularity: .month)
                                 ? BusinessMath.neededPerDay(goal: state.monthlyGoal, revenue: revenue, at: now) : nil)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("business-hero")
    }

    /// What the figure counts: « Du 1er au 12 nov. » (just the day for « Jour »).
    private func periodText(now: Date) -> String {
        func dayMonth(_ date: Date) -> String { Fmt.firstOfMonth(Fmt.format(date, template: "dMMM"), date) }
        if period == .day { return dayMonth(now) }
        return tr("Du \(dayMonth(BusinessMath.interval(period.math, containing: now).start)) au \(dayMonth(now))")
    }

    // MARK: Indicators

    private func kpis(state: BusinessState, now: Date) -> some View {
        let shown = state.pinnedKPIs.filter { $0 != .revenue }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                MiniSectionTitle(title: tr("Indicateurs"))
                Button { sheet = .kpis } label: {
                    Label(tr("Choisir"), systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(minHeight: 44)
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
                            .foregroundStyle(CristalPalette.of(style.id).category(accentHex))
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .accessibilityLabel(tr("Chiffre d'affaires cumulé"))
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
                .stroke(CristalPalette.of(style.id).category(hex), style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
                .frame(width: 18, height: 2)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: More

    /// The four pages, always in the same place, each with a summary line. « Suivis à la main » stays here whether
    /// there are metrics or not.
    private func more(state: BusinessState, now: Date) -> some View {
        let month = BusinessMath.interval(.month, containing: now)
        let year = BusinessMath.interval(.year, containing: now)
        let salesCount = BusinessMath.sales(state, in: month).count
        let costsCount = state.expenses.filter { month.holds($0.date) }.count
        let yearProfit = BusinessMath.revenue(state, in: year) - BusinessMath.costs(state, in: year)
        let metricNames = state.metrics.prefix(3).map(\.name).joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Pages"))
            MiniRowsCard {
                NavigationLink(value: HomeRoute.page(.businessSales)) {
                    BusinessRow(symbol: "list.bullet.rectangle", colorHex: accentHex, title: tr("Ventes et dépenses"),
                                detail: tr("\(Fmt.plural(salesCount, tr("vente"), tr("ventes"))) · \(Fmt.plural(costsCount, tr("dépense"), tr("dépenses"))) ce mois-ci"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("business-sales")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.businessResults)) {
                    BusinessRow(symbol: "chart.bar.xaxis", colorHex: "3366FF", title: tr("Résultats"),
                                detail: tr("Depuis le 1er janvier : bénéfice de \(TF.money(yearProfit, currency))"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("business-results")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.businessRecurring)) {
                    BusinessRow(symbol: "arrow.triangle.2.circlepath", colorHex: MiniStyle.goodHex, title: tr("Revenu récurrent"),
                                detail: tr("MRR, abonnés, ARR"), value: BusinessMath.recurring(state).map { TF.money($0.mrr, currency) })
                }
                .buttonStyle(.pressable)
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.businessMetrics)) {
                    BusinessRow(symbol: "gauge.with.dots.needle.33percent", colorHex: "F2A33A", title: tr("Suivis à la main"),
                                detail: metricNames.isEmpty ? tr("Tes propres indicateurs") : metricNames)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("business-metrics")
            }
        }
    }
}

// MARK: - Hero and floating actions

/// The revenue of the period on a glass card: a small caps label with what is counted on its right, the big figure,
/// the variation, then the gauge of the monthly goal (« Mois » only, and only once a goal is set).
private struct BusinessHeroCard: View {
    let value: String
    let periodText: String
    let caption: String?
    let goal: Double
    let revenue: Double
    let currency: String
    let perDay: Double?
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(tr("Chiffre d'affaires").uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.secondary)
                Spacer(minLength: 8)
                Text(periodText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 54, weight: .heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let caption {
                Text(caption)
                    .font(.subheadline)
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if goal > 0 {
                goalBlock(palette)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cristalGlass(in: RoundedRectangle(cornerRadius: palette.radius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func goalBlock(_ palette: CristalPalette) -> some View {
        let share = BusinessMath.goalShare(revenue: revenue, goal: goal)
        return VStack(alignment: .leading, spacing: 7) {
            Text(tr("\(Fmt.percent(share)) de l'objectif de \(TF.money(goal, currency))"))
                .font(.subheadline.weight(.semibold))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.trackColor)
                    Capsule().fill(palette.category(BusinessFormat.accentHex))
                        .frame(width: max(10, proxy.size.width * min(1, share)))
                        .opacity(revenue > 0 ? 1 : 0)
                }
            }
            .frame(height: 10)
            if let perDay {
                Text(tr("Il reste \(TF.money(goal - revenue, currency)) : environ \(TF.money(perDay, currency)) par jour d'ici la fin du mois."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if revenue >= goal {
                Text(tr("Objectif atteint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The two main actions, floating above the tab bar: « Vente » (filled) and « Dépense » (glass). A double tap
/// runs an action once.
private struct BusinessFloatingActions: View {
    let colorHex: String
    let sale: () -> Void
    let cost: () -> Void
    @State private var tapGuard = TapGuard()
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strong = CristalPalette.of(style.id).strongHex(colorHex)
        let hex = scheme == .dark ? strong.dark : strong.light
        HStack(spacing: 10) {
            Button {
                tapGuard.run(sale)
            } label: {
                Label(tr("Vente"), systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Color.readableInk(on: hex))
                    .padding(.horizontal, 24)
                    .frame(minHeight: 50)
                    .background(Color(hex: hex), in: Capsule())
                    .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("business-add-sale")
            Button {
                tapGuard.run(cost)
            } label: {
                Label(tr("Dépense"), systemImage: "minus")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 50)
                    .cristalGlass(in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("business-add-cost")
        }
    }
}

// MARK: - Shared pieces

/// A row of the Signature style: an icon in a tinted rounded square, a title, a detail, a value and a chevron.
private struct BusinessRow: View {
    @Environment(\.appStyle) private var style
    let symbol: String
    let colorHex: String
    let title: String
    var detail: String?
    var value: String?
    var showsChevron = true

    var body: some View {
        let tint = CristalPalette.of(style.id).category(colorHex)
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// An indicator: its value for the period and how it moved.
struct KPITile: View {
    @Environment(\.appStyle) private var style
    let kpi: BusinessKPI
    let comparison: BusinessMath.Comparison
    let currency: String
    var note: String?

    var body: some View {
        let change = BusinessFormat.change(comparison.change, higherIsBetter: kpi.higherIsBetter)
        VStack(alignment: .leading, spacing: 5) {
            Text(kpi.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(BusinessFormat.value(comparison.current, kpi, currency: currency))
                .font(.title2.weight(.heavy))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let change {
                Text(change.text).font(.caption.weight(.semibold)).foregroundStyle(CristalPalette.of(style.id).strong(change.hex))
            } else {
                Text(note ?? (comparison.current == nil ? tr("pas encore de données") : tr("rien avant"))).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .miniTile()
    }
}

/// A metric followed by hand: its latest value, its change and its target.
struct MetricRow: View {
    @Environment(\.appStyle) private var style
    let metric: CustomMetric

    var body: some View {
        let tint = CristalPalette.of(style.id).category("F2A33A")
        HStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: Circle())
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
                    Text(change.text).font(.caption.weight(.semibold)).foregroundStyle(CristalPalette.of(style.id).strong(change.hex))
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
    @Environment(\.appStyle) private var style
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
                                Image(systemName: kpi.symbol).frame(width: 24).foregroundStyle(CristalPalette.of(style.id).category(BusinessFormat.accentHex))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kpi.title).foregroundStyle(Color.primary)
                                    Text(kpi == .revenue ? tr("Déjà affiché en haut") : explanation(kpi)).font(.caption).foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                // The revenue is always at the top: a fixed line, not a choice.
                                let isOn = kpi == .revenue || model.business.pinnedKPIs.contains(kpi)
                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(isOn ? CristalPalette.of(style.id).strong(BusinessFormat.accentHex) : Color.secondary)
                            }
                        }
                        .disabled(kpi == .revenue)
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
