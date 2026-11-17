import Charts
import SwiftUI

/// Moves between months without leaving the screen.
struct MonthSwitcher: View {
    @Environment(\.appStyle) private var style
    @Binding var month: Date
    var colorHex = Finances.accentHex
    /// The oldest day shown (the free plan: the last seven days); earlier months open Premium.
    var earliest: Date?
    var onLocked: (() -> Void)?

    private var isCurrent: Bool { DateMath.calendar.isDate(month, equalTo: Date(), toGranularity: .month) }
    private var isLocked: Bool {
        guard let earliest else { return false }
        return BudgetMath.monthInterval(month).start <= earliest
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if isLocked { onLocked?() } else { move(-1) }
            } label: {
                Image(systemName: isLocked ? "lock.fill" : "chevron.left").font(.subheadline.weight(.bold)).frame(width: 40, height: 36)
            }
            .accessibilityLabel(Text(isLocked ? tr("Mois précédents avec Premium") : tr("Mois précédent")))
            .accessibilityIdentifier("month-previous")
            Text(Fmt.monthYear(month).capitalizedFirst)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            Button { move(1) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).frame(width: 40, height: 36)
            }
            .disabled(isCurrent)
            .accessibilityLabel(Text(tr("Mois suivant")))
        }
        .foregroundStyle(CristalPalette.of(style.id).strong(colorHex))
        .cristalGlass(in: Capsule())
    }

    private func move(_ months: Int) {
        guard let next = DateMath.calendar.date(byAdding: .month, value: months, to: month) else { return }
        Haptics.tap()
        month = min(next, Date())
    }
}

// MARK: - Operations and statement

/// « Opérations » : every movement of a month, like a bank statement (refonte du 2026-11-16, « Opérations » and
/// « Relevé » on one page). At the top the balance and its chart (month, three months, year), then a search, the
/// filters and what is still to check; then the days, newest first, each with its total, and each line with its
/// signed amount and the balance once it is counted. A line opens its card (a fixed payment opens its bill or
/// fixed amount, the « Solde de départ » its editor). The free plan keeps the month in progress and the last
/// seven days.
struct FinancesTransactionsPage: View {
    enum Filter: Hashable {
        case all, expenses, incomes, review
    }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme
    @State private var month: Date
    @State private var filter: Filter = .all
    @State private var categoryID: UUID?
    @State private var query = ""
    @State private var sheet: FinanceSheet?

    init(month: Date = Date()) {
        _month = State(initialValue: min(month, Date()))
    }

    private var currency: String { model.settings.currencyCode }

    /// The lines of one day, newest first.
    private struct Day: Identifiable {
        let date: Date
        var lines: [BudgetMath.StatementLine]
        var id: Date { date }
    }

    var body: some View {
        let state = model.budget
        let now = Date()
        let interval = BudgetMath.monthInterval(month)
        let earliest: Date? = model.isPremium ? nil : PremiumHistory.earliestFreeDay(now: now)
        // From the start of the month shown: the balance runs from the « Solde de départ » when there is one,
        // otherwise from zero on the 1st, as the chart's caption says.
        let lines = BudgetMath.statement(state, from: interval.start, now: now).filter { interval.holds($0.date) }
        let shown = lines.filter { keeps($0, state: state) }
        let toReview = ApplePayStatus.reviewCount(state)
        MiniAppScroll {
            BalanceChartCard(state: state, currency: currency, isPremium: model.isPremium) { sheet = .opening }
            VStack(alignment: .leading, spacing: 10) {
                search
                filters(state: state, toReview: toReview)
            }
            if toReview > 0 && filter != .review {
                reviewBanner(state: state, count: toReview)
            }
            MonthSwitcher(month: $month, earliest: earliest) { router.showPaywall(.financesHistory) }
            if lines.isEmpty {
                Text(tr("Aucune opération pour l'instant. Note une dépense ou un revenu : il s'affichera ici, avec ton solde après chaque opération."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
            } else if shown.isEmpty {
                Text(tr("Aucune opération ne correspond."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
            }
            ForEach(Self.days(shown)) { day in
                dayBlock(day, state: state, now: now)
            }
            if let earliest, hasOlder(state, than: interval.start), interval.start <= BudgetMath.monthInterval(earliest).start {
                Button { router.showPaywall(.financesHistory) } label: {
                    Label(tr("Opérations plus anciennes avec Premium"), systemImage: "lock.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("transactions-older")
            }
        }
        .tint(palette.strong(Finances.accentHex))
        .navigationTitle(tr("Opérations"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .add(isIncome: filter == .incomes) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text(filter == .incomes ? tr("Nouveau revenu") : tr("Nouvelle dépense")))
                    .accessibilityIdentifier("transactions-add")
            }
        }
        .sheet(item: $sheet) { $0.editor }
    }

    private var palette: CristalPalette { CristalPalette.of(style.id) }

    // MARK: Search and filters

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(tr("Rechercher"), text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityIdentifier("transactions-search")
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.secondary).frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(tr("Effacer")))
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .cristalGlass(in: Capsule())
    }

    private func filters(state: BudgetState, toReview: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(tr("Tout"), isOn: filter == .all) { filter = .all }
                chip(tr("Dépenses"), isOn: filter == .expenses) { filter = .expenses }
                chip(tr("Revenus"), isOn: filter == .incomes) { filter = .incomes; categoryID = nil }
                if toReview > 0 || filter == .review {
                    chip(tr("À vérifier"), isOn: filter == .review) { filter = .review }
                }
                Menu {
                    Button(tr("Toutes les catégories")) { categoryID = nil }
                    ForEach(state.categories) { category in
                        Button {
                            categoryID = category.id
                            if filter == .incomes { filter = .all }
                        } label: { Label(category.name, systemImage: category.symbol) }
                    }
                } label: {
                    chipLabel(HStack(spacing: 4) {
                        Text(state.category(categoryID)?.name ?? tr("Catégorie"))
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }, isOn: categoryID != nil)
                }
                .accessibilityIdentifier("transactions-category")
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
            Haptics.tap()
        } label: {
            chipLabel(Text(title), isOn: isOn)
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func chipLabel(_ content: some View, isOn: Bool) -> some View {
        let strong = palette.strongHex(Finances.accentHex)
        let fill = scheme == .dark ? strong.dark : strong.light
        return content
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isOn ? Color.readableInk(on: fill) : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background {
                if isOn {
                    Capsule().fill(Color(hex: fill))
                } else {
                    Capsule().fill(palette.panelSolidColor.opacity(scheme == .dark ? 0.84 : 0.85))
                        .overlay(Capsule().strokeBorder(palette.ruleColor, lineWidth: 1))
                }
            }
            .contentShape(Capsule())
            .padding(.vertical, 4)
    }

    /// What is still to check: the payments Apple Pay sent whose category was guessed.
    private func reviewBanner(state: BudgetState, count: Int) -> some View {
        let first = state.expenses.filter { $0.source == .applePay && $0.needsReview == true }.max { $0.date < $1.date }
        return HStack(spacing: 12) {
            Image(systemName: "wave.3.right.circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.category(ApplePayStatus.hex))
                .frame(width: 36, height: 36)
                .background(palette.category(ApplePayStatus.hex).opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.plural(count, tr("achat Apple Pay à vérifier"), tr("achats Apple Pay à vérifier")))
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let first {
                    Text("\(first.merchant ?? first.note) · \(TF.money(first.amount, currency, decimals: 2))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button(tr("Vérifier")) { withAnimation(.snappy) { filter = .review } }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("transactions-review")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .miniCard()
        .accessibilityElement(children: .contain)
    }

    /// Whether a line passes the filters and the search.
    private func keeps(_ line: BudgetMath.StatementLine, state: BudgetState) -> Bool {
        switch line.kind {
        case .opening:
            return filter == .all && categoryID == nil && query.trimmed.isEmpty
        case let .expense(expense):
            guard filter != .incomes else { return false }
            if filter == .review && expense.needsReview != true { return false }
            if let categoryID, expense.categoryID != categoryID { return false }
            return BudgetMath.matches(expense, query: query, state: state)
        case let .income(income):
            guard filter == .all || filter == .incomes, categoryID == nil else { return false }
            return BudgetMath.matches(income, query: query)
        }
    }

    // MARK: Days and lines

    private func dayBlock(_ day: Day, state: BudgetState, now: Date) -> some View {
        let total = day.lines.filter { $0.kind != .opening }.reduce(0) { $0 + $1.amount }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayTitle(day.date, now: now))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if day.lines.contains(where: { $0.kind != .opening }) {
                    Text(Fmt.signedMoney(total, currency: currency))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 4)
            MiniRowsCard {
                ForEach(Array(day.lines.enumerated()), id: \.element.id) { index, line in
                    if index > 0 { MiniDivider() }
                    Button { open(line, state: state) } label: { row(line, state: state) }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier(identifier(line))
                }
            }
        }
    }

    private func identifier(_ line: BudgetMath.StatementLine) -> String {
        if case let .expense(expense) = line.kind { return expense.fixedID == nil ? "expense-row" : "fixed-expense-row" }
        return "statement-row"
    }

    private func row(_ line: BudgetMath.StatementLine, state: BudgetState) -> some View {
        let look = appearance(line, state: state)
        let isOpening = line.kind == .opening
        var expense: Expense?
        if case let .expense(value) = line.kind { expense = value }
        return HStack(spacing: 12) {
            Image(systemName: look.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.category(look.hex))
                .frame(width: 36, height: 36)
                .background(palette.category(look.hex).opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(look.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if expense?.source == .applePay { ApplePayMark() }
                    if expense?.needsReview == true { ReviewBadge() }
                }
                Text(look.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(isOpening ? TF.money(line.amount, currency, decimals: 2) : Fmt.signedMoney(line.amount, currency: currency))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(!isOpening && line.amount > 0 ? palette.strong(Finances.incomeHex) : Color.primary)
                    .lineLimit(1)
                // The balance once this line is counted, as on a bank statement.
                Text(tr("solde \(TF.money(line.balance, currency, decimals: 2))"))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(line.balance < 0 ? palette.strong(Finances.overHex) : Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func appearance(_ line: BudgetMath.StatementLine, state: BudgetState) -> (symbol: String, hex: String, title: String, detail: String) {
        switch line.kind {
        case .opening:
            return ("flag.fill", Finances.accentHex, tr("Solde de départ"), tr("Ce que ton compte affichait"))
        case let .expense(expense):
            let category = state.category(expense.categoryID)
            let name = category?.name ?? tr("Sans catégorie")
            return (category?.symbol ?? "square.grid.2x2", category?.colorHex ?? "64748B",
                    expense.note.isEmpty ? (category?.name ?? tr("Dépense")) : expense.note,
                    expense.fixedID == nil ? name : tr("Dépense fixe · \(name)"))
        case let .income(income):
            return ("arrow.down.left", Finances.incomeHex, income.label.isEmpty ? tr("Revenu") : income.label,
                    income.fixedID == nil ? tr("Revenu") : tr("Revenu fixe"))
        }
    }

    /// Opens what the line comes from: the card of the expense or the income, the bill or the fixed amount behind
    /// a payment, or the « Solde de départ ».
    private func open(_ line: BudgetMath.StatementLine, state: BudgetState) {
        switch line.kind {
        case .opening:
            sheet = .opening
        case let .expense(expense):
            sheet = expense.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .detailExpense(expense)
        case let .income(income):
            sheet = income.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .detailIncome(income)
        }
    }

    private func dayTitle(_ day: Date, now: Date) -> String {
        if DateMath.isSameDay(day, now) { return tr("Aujourd'hui") }
        if let yesterday = DateMath.calendar.date(byAdding: .day, value: -1, to: now), DateMath.isSameDay(day, yesterday) { return tr("Hier") }
        return Fmt.longDay(day).capitalizedFirst
    }

    /// Something noted before `start`: the months the free plan doesn't show.
    private func hasOlder(_ state: BudgetState, than start: Date) -> Bool {
        state.expenses.contains { $0.date < start } || state.incomes.contains { $0.date < start }
            || state.bills.contains { $0.anchorDate < start } || (state.openingDate.map { $0 < start } ?? false)
    }

    /// The lines grouped by day (they come newest first, so each day's lines follow each other).
    private static func days(_ lines: [BudgetMath.StatementLine]) -> [Day] {
        var result: [Day] = []
        for line in lines {
            let day = DateMath.startOfDay(line.date)
            if let last = result.last, last.date == day {
                result[result.count - 1].lines.append(line)
            } else {
                result.append(Day(date: day, lines: [line]))
            }
        }
        return result
    }
}

/// The account statement, opened from the balance: since the redesign of 2026-11-16 it is the « Opérations »
/// page, which shows the balance after each movement. `start` (where the chart's period begins) is kept for the
/// routes that pass it; the page opens on the month in progress.
struct FinancesStatementPage: View {
    let start: Date

    var body: some View {
        FinancesTransactionsPage()
    }
}

// MARK: - Categories

struct FinancesCategoriesPage: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appStyle) private var style
    @State private var month = Date()
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.budget
        let interval = BudgetMath.monthInterval(month)
        let spends = BudgetMath.byCategory(state, in: interval)
        let total = spends.reduce(0) { $0 + $1.amount }
        MiniAppScroll {
            MonthSwitcher(month: $month, earliest: model.isPremium ? nil : PremiumHistory.earliestFreeDay()) { router.showPaywall(.financesHistory) }
            if total > 0 {
                Chart(spends, id: \.name) { spend in
                    SectorMark(angle: .value("Montant", spend.amount), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(CristalPalette.of(style.id).category(spend.colorHex))
                        .cornerRadius(3)
                }
                .accessibilityLabel(tr("Dépenses"))
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text(TF.money(total, currency)).font(.title2.weight(.bold)).monospacedDigit()
                        Text(tr("dépensés")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 220)
                .card()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("categories-chart")
            }
            VStack(spacing: 0) {
                ForEach(Array(state.categories.enumerated()), id: \.element.id) { index, category in
                    if index > 0 { Divider() }
                    let spent = spends.first { $0.category?.id == category.id }?.amount ?? 0
                    Button { sheet = .category(category) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            CategoryBar(status: BudgetMath.CategoryStatus(category: category, spent: spent), currency: currency)
                            Text(limitText(category: category, spent: spent, total: total))
                                .font(.caption)
                                .foregroundStyle(category.monthlyLimit > 0 && spent > category.monthlyLimit ? CristalPalette.of(style.id).strong(Finances.overHex) : Color.secondary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                }
                Divider()
                Button { sheet = .category(BudgetCategory(name: "", symbol: "tag", colorHex: "3366FF")) } label: {
                    Label(tr("Nouvelle catégorie"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CristalPalette.of(style.id).strong(Finances.accentHex))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.pressable)
            }
            .padding(.horizontal, 14)
            .cristalPanel(radius: 20)
            Text(tr("Touche une catégorie pour changer son nom, sa couleur ou sa limite par mois."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(tr("Catégories"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func limitText(category: BudgetCategory, spent: Double, total: Double) -> String {
        let share = total > 0 ? tr(" · \(Fmt.percent(spent / total)) du mois") : ""
        guard category.monthlyLimit > 0 else { return tr("Sans limite\(share)") }
        let left = category.monthlyLimit - spent
        return (left >= 0 ? tr("\(TF.money(left, currency)) restants") : tr("Dépassé de \(TF.money(-left, currency))")) + share
    }
}

// MARK: - Income and spending of a month

/// « Revenus et dépenses » (refonte du 2026-11-16): where the balance of a month comes from, as a cascade (the
/// balance on the 1st, what came in, what went out, the balance at the end or today), then the spending by
/// category and the incomes, each on its own side.
struct FinancesMonthPage: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appStyle) private var style
    @State private var month = Date()
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    /// One bar of the cascade, from `low` to `high`.
    private struct Step: Identifiable {
        let label: String
        let low: Double
        let high: Double
        let color: Color
        let text: String
        var id: String { label }
    }

    var body: some View {
        let state = model.budget
        let now = Date()
        let interval = BudgetMath.monthInterval(month)
        let isCurrent = interval.holds(now)
        let start = BudgetMath.balance(atStartOf: interval.start, state, now: now)
        let earned = BudgetMath.earned(state, in: interval, now: now)
        let spent = BudgetMath.spent(state, in: interval, now: now)
        let end = start + earned - spent
        let spends = BudgetMath.byCategory(state, in: interval, now: now)
        let incomes = BudgetMath.incomes(state, in: interval, now: now).sorted { $0.date > $1.date }
        MiniAppScroll {
            MonthSwitcher(month: $month, earliest: model.isPremium ? nil : PremiumHistory.earliestFreeDay(now: now)) { router.showPaywall(.financesHistory) }
            cascade(start: start, earned: earned, spent: spent, end: end, isCurrent: isCurrent, state: state)
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Dépenses"), detail: TF.money(spent, currency))
                if spends.isEmpty {
                    Text(tr("Aucune dépense notée pour ce mois."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                } else {
                    NavigationLink(value: HomeRoute.page(.financesCategories)) {
                        VStack(spacing: 12) {
                            ForEach(spends.prefix(3), id: \.name) { spend in
                                FinancesShareBar(spend: spend, total: spent, largest: spends.first?.amount ?? spent, currency: currency)
                            }
                            HStack {
                                Text(tr("Les \(state.categories.count) catégories"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 30)
                        }
                        .card(padding: 14)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("month-categories")
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Revenus"), detail: earned > 0 ? "+" + TF.money(earned, currency) : nil)
                if incomes.isEmpty {
                    Text(tr("Aucun revenu noté ce mois-ci."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                } else {
                    MiniRowsCard {
                        ForEach(Array(incomes.enumerated()), id: \.element.id) { index, income in
                            if index > 0 { MiniDivider() }
                            Button { open(income, state: state) } label: {
                                FinancesRow(symbol: "arrow.down.left", colorHex: Finances.incomeHex, title: income.label.isEmpty ? tr("Revenu") : income.label,
                                            detail: "\(income.fixedID == nil ? tr("Revenu") : tr("Revenu fixe")) · \(Fmt.longDay(income.date))",
                                            value: "+" + TF.money(income.amount, currency, decimals: 2), showsChevron: false)
                            }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("month-income-row")
                        }
                    }
                }
            }
        }
        .tint(palette.strong(Finances.accentHex))
        .navigationTitle(tr("Revenus et dépenses"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = .add(isIncome: false) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text(tr("Nouvelle dépense")))
                    .accessibilityIdentifier("month-add")
            }
        }
        .sheet(item: $sheet) { $0.editor }
    }

    /// « D'où vient ton solde »: the four bars and the line saying what the balance counts.
    private func cascade(start: Double, earned: Double, spent: Double, end: Double, isCurrent: Bool, state: BudgetState) -> some View {
        let ink = palette.category(Finances.spentHex)
        let steps = [
            Step(label: tr("Le 1er"), low: min(0, start), high: max(0, start), color: Color.secondary.opacity(0.45), text: TF.money(start, currency)),
            Step(label: tr("Revenus"), low: start, high: start + earned, color: palette.category(Finances.incomeHex), text: "+" + TF.money(earned, currency)),
            Step(label: tr("Dépenses"), low: start + earned - spent, high: start + earned, color: ink, text: "−" + TF.money(spent, currency)),
            Step(label: isCurrent ? tr("Aujourd'hui") : tr("Fin du mois"), low: min(0, end), high: max(0, end), color: Color.primary.opacity(0.85), text: TF.money(end, currency)),
        ]
        let caption = state.openingBalance == nil
            ? tr("Sans solde de départ, le mois part de 0 : tes revenus moins tes dépenses, factures et montants fixes compris.")
            : tr("Le solde au 1er du mois, puis tes revenus et tes dépenses notés, factures et montants fixes compris.")
        return VStack(alignment: .leading, spacing: 12) {
            Text(tr("D'où vient ton solde"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Chart {
                ForEach(steps) { step in
                    BarMark(x: .value("Étape", step.label), yStart: .value("Montant", step.low), yEnd: .value("Montant", step.high), width: .ratio(0.55))
                        .foregroundStyle(step.color)
                        .cornerRadius(6)
                        .annotation(position: .top, spacing: 4) {
                            Text(step.text)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                }
                RuleMark(y: .value("Zéro", 0.0))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
            .padding(.top, 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(tr("D'où vient ton solde")))
            .accessibilityValue(Text(steps.map { "\($0.label) \($0.text)" }.joined(separator: ", ")))
            .accessibilityIdentifier("month-cascade")
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func open(_ income: IncomeEntry, state: BudgetState) {
        sheet = income.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .detailIncome(income)
    }
}

/// A category's part of the month: its icon and name, the amount and its share, a bar as long as the amount
/// against the biggest category.
private struct FinancesShareBar: View {
    @Environment(\.appStyle) private var style
    let spend: BudgetMath.CategorySpend
    let total: Double
    let largest: Double
    let currency: String

    var body: some View {
        let tint = CristalPalette.of(style.id).category(spend.colorHex)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: spend.category?.symbol ?? "square.grid.2x2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                Text(spend.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Text("\(TF.money(spend.amount, currency)) · \(Fmt.percent(total > 0 ? spend.amount / total : 0))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            ProgressView(value: largest > 0 ? min(1, spend.amount / largest) : 0)
                .tint(tint)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Budget and what comes back

/// « Budget et récurrents » (refonte du 2026-11-16, « Factures » and « Dépenses fixes » on one page): the month's
/// budget with its pace, the limits of the categories, the monthly cost of the bills and subscriptions, then one
/// schedule of everything that comes back (bills, subscriptions, fixed incomes and expenses), soonest first.
struct FinancesBillsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let state = model.budget
        let now = Date()
        let items = BudgetMath.upcoming(state, at: now, within: 400)
        MiniAppScroll {
            budget(state: state, now: now)
            if !state.bills.isEmpty {
                HStack(spacing: 10) {
                    MiniStat(title: tr("Par mois"), value: TF.money(BudgetMath.billsMonthly(state), currency), detail: Fmt.plural(state.bills.count, tr("facture"), tr("factures")))
                    MiniStat(title: tr("Abonnements"), value: TF.money(BudgetMath.subscriptionsMonthly(state), currency), detail: tr("par mois"))
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Échéancier"),
                                 detail: tr("\(TF.money(BudgetMath.billsMonthly(state) + BudgetMath.fixedExpensesMonthly(state), currency)) par mois"))
                MiniRowsCard {
                    if items.isEmpty {
                        Text(tr("Aucune facture ni montant fixe pour l'instant."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { MiniDivider() }
                        Button { open(item) } label: { FinancesDueRow(item: item, now: now, currency: currency) }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("bills-row")
                    }
                    MiniDivider()
                    Button { sheet = .bill(Bill(name: "", amount: 0, anchorDate: Date())) } label: {
                        Label(tr("Nouvelle facture"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.strong(Finances.accentHex))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("bills-new")
                }
            }
            MiniRowsCard {
                NavigationLink { MoneyView() } label: {
                    let monthly = BudgetMath.fixedExpensesMonthly(state)
                    FinancesRow(symbol: "repeat", colorHex: "D6409F", title: tr("Revenus et dépenses fixes"),
                                detail: monthly > 0 ? tr("\(TF.money(monthly, currency)) par mois") : tr("Loyer, assurances, forfaits…"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("bills-fixed")
                MiniDivider()
                // The reminder the day before each bill: its switch lives with the other smart reminders.
                NavigationLink { SmartRemindersView() } label: {
                    FinancesRow(symbol: "bell.badge", colorHex: ApplePayStatus.hex, title: tr("Rappel des factures"),
                                detail: model.settings.remindsBills ? tr("La veille") : tr("Désactivé"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("bills-reminder")
            }
            MiniFootnote(text: tr("Loyer, électricité, Internet, abonnements : Ardane te rappelle la prochaine date et le total par mois."))
        }
        .tint(palette.strong(Finances.accentHex))
        .navigationTitle(tr("Budget et récurrents"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    /// The month's budget: what is left and per day, the pace bar, and the way to the categories' limits.
    private func budget(state: BudgetState, now: Date) -> some View {
        let knowsBudget = model.profile.knows(.monthlyBudget)
        let spent = BudgetMath.spentThisMonth(state, throughDay: now, now: now)
        let remaining = BudgetMath.remaining(state, throughDay: now, now: now)
        let perDay = BudgetMath.perDayLeft(state, throughDay: now, now: now)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Budget du mois"))
                    .font(.headline)
                Spacer(minLength: 8)
                Button { sheet = .budget } label: {
                    Label(knowsBudget ? TF.money(state.monthlyBudget, currency) : tr("Définir mon budget"), systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("bills-budget")
            }
            if knowsBudget {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(TF.money(abs(remaining), currency))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(remaining < 0 ? palette.strong(Finances.overHex) : Color.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(remaining < 0 ? tr("Dépassé ce mois-ci") : tr("restent ce mois-ci, soit \(TF.money(perDay, currency, decimals: 2)) par jour"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FinancesPaceBar(spent: spent, budget: state.monthlyBudget, fraction: BudgetMath.monthFraction(throughDay: now))
            } else {
                Text(tr("Dépensé ce mois-ci"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(TF.money(spent, currency))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Divider()
            NavigationLink(value: HomeRoute.page(.financesCategories)) {
                HStack {
                    Text(tr("Limites des \(state.categories.count) catégories"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("bills-limits")
        }
        .card(padding: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bills-budget-card")
    }

    /// A bill opens its editor; a fixed income or expense opens the editor of « Revenus et dépenses fixes ».
    private func open(_ item: BudgetMath.UpcomingItem) {
        switch item.source {
        case let .bill(bill):
            sheet = .bill(bill)
        case let .fixed(flow):
            sheet = .flow(model.content.money.items.first { $0.id == flow.id } ?? flow)
        }
    }
}

// MARK: - Savings and accounts

struct FinancesSavingsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var sheet: FinanceSheet?
    @State private var pendingGoal: UUID?
    @State private var pendingAccount: UUID?

    private var currency: String { model.settings.currencyCode }
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let state = model.budget
        MiniAppScroll {
            keptThisMonth(state: state)
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Objectifs d'épargne"), detail: state.goals.isEmpty ? nil : TF.money(state.goals.reduce(0) { $0 + $1.saved }, currency))
                VStack(spacing: 0) {
                    if !state.goals.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .center, spacing: 18) {
                            ForEach(state.goals) { goal in
                                Button { sheet = .goal(goal) } label: { GoalRing(goal: goal, currency: currency) }
                                    .buttonStyle(.pressable)
                                    .accessibilityIdentifier("goal-ring")
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            pendingGoal = goal.id
                                        } label: {
                                            Label(tr("Supprimer"), systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 14)
                        Divider()
                    }
                    Button { sheet = .goal(SavingsGoal(name: "", target: 1_000, saved: 0, deadline: nil)) } label: {
                        Label(tr("Nouvel objectif"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.strong(Finances.incomeHex))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("goals-new")
                }
                .padding(.horizontal, 14)
                .cristalPanel(radius: 20)
                if !state.goals.isEmpty {
                    Text(tr("Touche un objectif pour y ajouter un versement ou le supprimer.")).font(.footnote).foregroundStyle(.secondary)
                }
            }
            accounts(state: state)
        }
        .navigationTitle(tr("Épargne"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
        .confirmDelete($pendingGoal, title: tr("Supprimer cet objectif ?"), button: tr("Supprimer l'objectif"),
                       message: tr("Cette action ne peut pas être annulée.")) { id in
            model.update(\.budget) { $0.goals.removeAll { $0.id == id } }
        }
        .confirmDelete($pendingAccount, title: tr("Supprimer ce compte ?"), button: tr("Supprimer le compte"),
                       message: tr("Cette action ne peut pas être annulée.")) { id in
            model.update(\.budget) { $0.removeAccount(id) }
        }
    }

    /// What the month left so far (what came in minus what went out), against the « Épargne visée » of
    /// « Mes informations » when there is one.
    private func keptThisMonth(state: BudgetState) -> some View {
        let now = Date()
        let interval = BudgetMath.monthInterval(now)
        let kept = BudgetMath.earned(state, in: interval, now: now) - BudgetMath.spent(state, in: interval, now: now)
        let target = model.profile.monthlySavingsGoal.flatMap { $0 > 0 ? $0 : nil }
        return VStack(alignment: .leading, spacing: 6) {
            Text(tr("Mis de côté en \(Fmt.format(now, template: "MMMM"))").uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Fmt.signedMoney(kept, currency: currency, decimals: 0))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(kept < 0 ? palette.strong(Finances.overHex) : palette.strong(Finances.incomeHex))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(target.map { tr("sur \(TF.money($0, currency)) visés par mois") } ?? tr("revenus moins dépenses"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let target {
                if kept >= target {
                    Label(tr("Épargne visée atteinte"), systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.strong(Finances.incomeHex))
                } else {
                    Text(tr("Encore \(TF.money(target - max(0, kept), currency)) pour ton épargne visée"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .miniCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("savings-kept")
    }

    private func accounts(state: BudgetState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Comptes"), detail: state.accounts.isEmpty ? nil : tr("valeur nette \(TF.money(BudgetMath.netWorth(state), currency))"))
            if state.netWorthHistory.count >= 2 {
                Chart(state.netWorthHistory, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Valeur nette", point.value))
                        .foregroundStyle(palette.category(Finances.accentHex))
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", point.date), y: .value("Valeur nette", point.value))
                        .foregroundStyle(palette.category(Finances.accentHex).opacity(0.12).gradient)
                        .interpolationMethod(.catmullRom)
                }
                .accessibilityLabel(tr("Valeur nette"))
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 150)
                .card()
            }
            MiniRowsCard {
                ForEach(Array(state.accounts.enumerated()), id: \.element.id) { index, account in
                    if index > 0 { MiniDivider() }
                    Button { sheet = .account(account) } label: {
                        MiniRow(symbol: account.isLiability ? "creditcard.fill" : "building.columns.fill",
                                colorHex: account.isLiability ? Finances.overHex : Finances.accentHex,
                                title: account.name, detail: account.isLiability ? tr("Dette") : nil,
                                value: (account.isLiability ? "−" : "") + TF.money(account.balance, currency), showsChevron: false)
                    }
                    .buttonStyle(.pressable)
                    .contextMenu {
                        Button(role: .destructive) {
                            pendingAccount = account.id
                        } label: {
                            Label(tr("Supprimer"), systemImage: "trash")
                        }
                    }
                }
                if !state.accounts.isEmpty { MiniDivider() }
                Button { sheet = .account(Account(name: "", balance: 0)) } label: {
                    Label(tr("Nouveau compte ou dette"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.strong(Finances.accentHex))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.pressable)
            }
            Text(tr("Saisis tes soldes à la main : Ardane ne se connecte à aucune banque. Touche un compte pour le modifier ou le supprimer.")).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// A savings goal as a ring: the share saved in its middle, the name, what is saved, and what it takes each month
/// to get there by its date.
private struct GoalRing: View {
    @Environment(\.appStyle) private var style
    let goal: SavingsGoal
    let currency: String

    var body: some View {
        let palette = CristalPalette.of(style.id)
        let tint = palette.category(Finances.incomeHex)
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(palette.trackColor, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(0.001, goal.progress))
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Fmt.percent(goal.progress))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .frame(width: 92, height: 92)
            .accessibilityHidden(true)
            Text(goal.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(goal.name))
        .accessibilityValue(Text("\(Fmt.percent(goal.progress)), \(detail)"))
    }

    private var detail: String {
        var parts = [tr("\(TF.money(goal.saved, currency)) sur \(TF.money(goal.target, currency))")]
        if let monthly = BudgetMath.monthlyToReach(goal, at: Date()), let deadline = goal.deadline {
            parts.append(tr("\(TF.money(monthly, currency)) / mois d'ici \(Fmt.monthYear(deadline))"))
        } else if goal.saved >= goal.target {
            parts.append(tr("atteint"))
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - Analysis

/// « Analyse » (Premium; the « Évolution » page, enriched on 2026-11-16): this month against the last one day after
/// day and against the budget's pace, six months of money in and out, the averages, the categories against last
/// month, and short findings written from what was noted.
struct FinancesTrendsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    private var currency: String { model.settings.currencyCode }
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    private struct Bar: Identifiable {
        let month: Date
        let series: String
        let value: Double
        let isCurrent: Bool
        var id: String { "\(series)-\(month.timeIntervalSince1970)" }
    }

    /// One point of a cumulative curve: the total spent at the end of a day of the month.
    private struct DayPoint: Identifiable {
        let series: String
        let day: Int
        let value: Double
        var id: String { "\(series)-\(day)" }
    }

    var body: some View {
        if model.isPremium {
            analysis
        } else {
            MiniAppScroll {
                PremiumLockCard(symbol: "chart.bar.xaxis", title: tr("L'analyse est dans Premium"),
                                message: tr("Six mois d'un coup d'œil, tes moyennes et la comparaison avec le mois dernier. Tes opérations restent enregistrées : tout s'affiche dès que tu passes à Premium."))
            }
            .navigationTitle(tr("Analyse"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder private var analysis: some View {
        let state = model.budget
        let now = Date()
        // From the first month with something noted: no empty months before the data starts.
        let months = Array(BudgetMath.months(state, count: 6, at: now).drop(while: { $0.spent == 0 && $0.earned == 0 }))
        let past = months.dropLast().filter { $0.spent > 0 || $0.earned > 0 }
        MiniAppScroll {
            if months.isEmpty {
                Text(tr("Rien de noté pour l'instant : les mois apparaîtront ici dès la première opération."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            } else {
                comparison(state: state, now: now)
                sixMonths(months)
            }
            if !past.isEmpty {
                let spent = past.reduce(0) { $0 + $1.spent } / Double(past.count)
                let earned = past.reduce(0) { $0 + $1.earned } / Double(past.count)
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Moyenne par mois"), detail: tr("sur \(Fmt.plural(past.count, tr("mois complet"), tr("mois complets")))"))
                    HStack(spacing: 10) {
                        MiniStat(title: tr("Dépenses"), value: TF.money(spent, currency))
                        if earned > 0 {
                            MiniStat(title: tr("Revenus"), value: TF.money(earned, currency), colorHex: Finances.incomeHex)
                            MiniStat(title: tr("Mis de côté"), value: TF.money(earned - spent, currency), detail: Fmt.percent(max(0, (earned - spent) / earned)) + tr(" des revenus"),
                                     colorHex: earned - spent < 0 ? Finances.overHex : Finances.incomeHex)
                        }
                    }
                }
            }
            changes(state: state, now: now)
            findings(state: state, now: now)
            Text(tr("Moyennes calculées sur les mois terminés où tu as noté quelque chose."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(tr("Analyse"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: This month against the last one

    /// The spending of this month added up day after day (ink, with a light area), last month's in grey, and the
    /// budget's pace as a dashed line from 0 to the budget.
    @ViewBuilder
    private func comparison(state: BudgetState, now: Date) -> some View {
        let month = BudgetMath.monthInterval(now)
        let previousStart = DateMath.calendar.date(byAdding: .month, value: -1, to: month.start) ?? month.start
        let current = BudgetMath.cumulativeSpending(state, month: now, through: now, now: now)
        let previous = BudgetMath.cumulativeSpending(state, month: previousStart, now: now)
        let days = max(1, DateMath.daysBetween(month.start, month.end))
        let budget: Double? = model.profile.knows(.monthlyBudget) && state.monthlyBudget > 0 ? state.monthlyBudget : nil
        let thisName = Fmt.format(now, template: "MMMM").capitalizedFirst
        let lastName = Fmt.format(previousStart, template: "MMMM")
        let toDate = BudgetMath.monthToDate(state, at: now)
        let ink = palette.category(Finances.spentHex)
        let grey = Color.secondary.opacity(0.55)
        let currentPoints = current.enumerated().map { DayPoint(series: "current", day: $0.offset + 1, value: $0.element) }
        let previousPoints = previous.enumerated().map { DayPoint(series: "previous", day: $0.offset + 1, value: $0.element) }
        if !current.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("\(thisName) face à \(lastName)"), detail: tr("cumulé"))
                VStack(alignment: .leading, spacing: 12) {
                    Chart {
                        if let budget {
                            LineMark(x: .value("Jour", 1), y: .value("Montant", 0.0), series: .value("Série", "pace"))
                                .foregroundStyle(Color.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                            LineMark(x: .value("Jour", days), y: .value("Montant", budget), series: .value("Série", "pace"))
                                .foregroundStyle(Color.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
                        }
                        ForEach(previousPoints) { point in
                            LineMark(x: .value("Jour", point.day), y: .value("Montant", point.value), series: .value("Série", point.series))
                                .foregroundStyle(grey)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                        }
                        ForEach(currentPoints) { point in
                            AreaMark(x: .value("Jour", point.day), y: .value("Montant", point.value))
                                .foregroundStyle(ink.opacity(0.12))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("Jour", point.day), y: .value("Montant", point.value), series: .value("Série", point.series))
                                .foregroundStyle(ink)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.monotone)
                        }
                        if let last = currentPoints.last {
                            PointMark(x: .value("Jour", last.day), y: .value("Montant", last.value))
                                .foregroundStyle(ink)
                                .symbolSize(60)
                        }
                    }
                    .chartXScale(domain: 1...max(days, previous.count))
                    .chartLegend(.hidden)
                    .chartXAxis {
                        AxisMarks(values: [1, 10, 20, days]) { _ in
                            AxisGridLine().foregroundStyle(palette.gridColor)
                            AxisValueLabel()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine().foregroundStyle(palette.gridColor)
                            AxisValueLabel {
                                if let amount = value.as(Double.self) { Text(TF.money(amount, currency)) }
                            }
                        }
                    }
                    .frame(height: 170)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(tr("\(thisName) face à \(lastName)")))
                    .accessibilityValue(Text(comparisonSentence(toDate)))
                    .accessibilityIdentifier("trends-comparison")
                    HStack(spacing: 14) {
                        legend(tr("Ce mois-ci"), color: ink, dashed: false)
                        legend(tr("Mois dernier"), color: grey, dashed: false)
                        if budget != nil { legend(tr("Rythme du budget"), color: .secondary, dashed: true) }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(comparisonSentence(toDate))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .card()
            }
        }
    }

    private func comparisonSentence(_ toDate: (current: Double, previous: Double)) -> String {
        let difference = toDate.current - toDate.previous
        guard toDate.previous > 0, abs(difference) >= 1 else {
            return tr("\(TF.money(toDate.current, currency)) dépensés depuis le 1er du mois.")
        }
        return difference > 0
            ? tr("\(TF.money(abs(difference), currency)) de plus que le mois dernier à la même date")
            : tr("\(TF.money(abs(difference), currency)) de moins que le mois dernier à la même date")
    }

    private func legend(_ title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 1.5))
                path.addLine(to: CGPoint(x: 16, y: 1.5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: dashed ? [3, 3] : []))
            .frame(width: 16, height: 3)
            .accessibilityHidden(true)
            Text(title)
        }
    }

    // MARK: Six months

    private func sixMonths(_ months: [BudgetMath.MonthSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: months.count >= 6 ? tr("Six derniers mois") : tr("Par mois"))
            VStack(alignment: .leading, spacing: 10) {
                Chart(bars(months)) { bar in
                    BarMark(x: .value("Mois", bar.month, unit: .month), y: .value("Montant", bar.value))
                        .foregroundStyle(by: .value("Type", bar.series))
                        .position(by: .value("Type", bar.series))
                        .opacity(bar.isCurrent ? 0.45 : 1)
                        .cornerRadius(3)
                }
                .accessibilityLabel(tr("Par mois"))
                .chartForegroundStyleScale([tr("Revenus"): palette.category(Finances.incomeHex), tr("Dépenses"): palette.category(Finances.spentHex)])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .frame(height: 200)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("trends-chart")
                Text(tr("Le mois en cours, plus pâle, n'est pas fini."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .card()
        }
    }

    private func bars(_ months: [BudgetMath.MonthSummary]) -> [Bar] {
        let current = BudgetMath.monthInterval(Date()).start
        return months.flatMap {
            [Bar(month: $0.start, series: tr("Revenus"), value: $0.earned, isCurrent: $0.start == current),
             Bar(month: $0.start, series: tr("Dépenses"), value: $0.spent, isCurrent: $0.start == current)]
        }
    }

    // MARK: Categories against last month

    @ViewBuilder
    private func changes(state: BudgetState, now: Date) -> some View {
        let rows = BudgetMath.categoryChanges(state, at: now)
        if !rows.isEmpty && rows.contains(where: { $0.previous > 0 }) {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Par rapport au mois dernier"), detail: tr("à la même date"))
                MiniRowsCard {
                    ForEach(Array(rows.prefix(6).enumerated()), id: \.element.id) { index, row in
                        if index > 0 { MiniDivider() }
                        let difference = row.difference
                        MiniRow(symbol: difference > 0 ? "arrow.up.right" : (difference < 0 ? "arrow.down.right" : "equal"),
                                colorHex: difference > 0 ? Finances.overHex : (difference < 0 ? Finances.incomeHex : "8A8A8E"),
                                title: row.name, detail: "\(TF.money(row.previous, currency)) → \(TF.money(row.current, currency))",
                                value: (difference > 0 ? "+" : difference < 0 ? "−" : "") + TF.money(abs(difference), currency), showsChevron: false)
                    }
                }
            }
        }
    }

    // MARK: Findings

    @ViewBuilder
    private func findings(state: BudgetState, now: Date) -> some View {
        let found = BudgetMath.insights(state, at: now)
        if !found.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Constats"))
                MiniRowsCard {
                    ForEach(Array(found.enumerated()), id: \.offset) { index, insight in
                        if index > 0 { MiniDivider() }
                        finding(insight)
                    }
                }
                .accessibilityIdentifier("trends-findings")
            }
        }
    }

    private func finding(_ insight: BudgetMath.Insight) -> some View {
        let look: (symbol: String, hex: String, text: String)
        switch insight {
        case let .onlyRise(name, symbol, colorHex, current, previous):
            look = (symbol, colorHex, tr("\(name) est la seule catégorie en hausse : \(TF.money(current, currency)) contre \(TF.money(previous, currency)) le mois dernier à la même date."))
        case let .biggestRise(name, symbol, colorHex, difference):
            look = (symbol, colorHex, tr("\(name) est la plus forte hausse : \(TF.money(difference, currency)) de plus que le mois dernier à la même date."))
        case let .allDown(saved):
            look = ("arrow.down.right", Finances.incomeHex, tr("Toutes tes catégories sont en baisse : \(TF.money(saved, currency)) de moins que le mois dernier à la même date."))
        case let .heavyDay(date, share):
            look = ("calendar", Finances.spentHex, tr("Le \(Fmt.format(date, template: "dMMMM")) pèse \(Fmt.percent(share)) de tes dépenses du mois."))
        }
        let tint = palette.category(look.hex)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: look.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Text(look.text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }
}
