import Charts
import SwiftUI

/// Everything the Finances mini-app edits in a sheet.
enum FinanceSheet: Identifiable {
    case expense(Expense?)
    case income(IncomeEntry?)
    case bill(Bill)
    case goal(SavingsGoal)
    case account(Account)
    case category(BudgetCategory)
    /// A fixed income or expense of « Revenus et dépenses fixes ».
    case flow(MoneyItem)
    case budget
    /// « Solde de départ », for the balance chart.
    case opening

    var id: String {
        switch self {
        case let .expense(expense): "expense-\(expense?.id.uuidString ?? "new")"
        case let .income(income): "income-\(income?.id.uuidString ?? "new")"
        case let .bill(bill): "bill-\(bill.id)"
        case let .goal(goal): "goal-\(goal.id)"
        case let .account(account): "account-\(account.id)"
        case let .category(category): "category-\(category.id)"
        case let .flow(item): "flow-\(item.id)"
        case .budget: "budget"
        case .opening: "opening"
        }
    }

    @ViewBuilder
    var editor: some View {
        switch self {
        case let .expense(expense): ExpenseEditor(expense: expense)
        case let .income(income): IncomeEditor(income: income)
        case let .bill(bill): BillEditor(bill: bill)
        case let .goal(goal): GoalEditor(goal: goal)
        case let .account(account): AccountEditor(account: account)
        case let .category(category): CategoryEditor(category: category)
        case let .flow(item): MoneyItemEditor(item: item, isNew: false)
        case .budget: MonthlyBudgetEditor()
        case .opening: OpeningBalanceEditor()
        }
    }
}

enum Finances {
    static var accentHex: String { MiniApp.finances.colorHex }
    static let overHex = "E5484D"
    static let incomeHex = "1E9E75"
}

/// The monthly budget, on its own.
struct MonthlyBudgetEditor: View {
    @Environment(AppModel.self) private var model
    @State private var amount: Double = 0

    var body: some View {
        SheetForm(title: tr("Budget du mois"), canSave: amount >= 0, onSave: { model.setMonthlyBudget(amount) }) {
            Section {
                NumberRow(title: tr("Budget"), value: $amount, unit: model.settings.currencyCode)
            } footer: {
                Text(tr("Ce que tu te permets de dépenser chaque mois, factures comprises ou non : à toi de choisir, Tessera compte ce que tu notes."))
            }
        }
        .onAppear { amount = model.budget.monthlyBudget }
    }
}

/// « Solde de départ »: what the account held at the start of a day. The balance chart starts from it,
/// then follows what is noted; without it, the chart shows what came in minus what went out.
struct OpeningBalanceEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double?
    @State private var date = Date()

    var body: some View {
        SheetForm(title: tr("Solde de départ"), canSave: amount != nil, onSave: { model.setOpeningBalance(amount, on: date) }) {
            Section {
                HStack {
                    Text(tr("Montant"))
                    Spacer()
                    // A balance can be negative (an overdraft): a keyboard with the minus sign.
                    TextField(tr("À renseigner"), value: $amount, format: .number.locale(Fmt.locale))
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        .accessibilityIdentifier("opening-amount")
                    Text(UnitText.display(model.settings.currencyCode)).foregroundStyle(Color.secondary)
                }
                DatePicker(tr("Au début du"), selection: $date, in: ...Date(), displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
            } footer: {
                Text(tr("Ce que ton compte affichait ce jour-là, avant ses opérations. Le graphique du solde part de ce montant, puis suit tes revenus et tes dépenses notés dans Tessera."))
            }
            if model.budget.openingBalance != nil {
                Section {
                    Button(tr("Retirer le solde de départ"), role: .destructive) {
                        model.setOpeningBalance(nil, on: date)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            amount = model.budget.openingBalance
            date = model.budget.openingDate ?? Date()
        }
    }
}

/// The Finances mini-app: the balance as it went (a chart), what is left this month, what came in and
/// went out, the categories, the bills coming and the savings; then every operation, the evolution
/// and the accounts.
struct FinancesAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Finances.accentHex }

    var body: some View {
        let now = Date()
        let state = model.budget
        MiniAppScroll {
            BalanceChartCard(state: state, currency: currency) { sheet = .opening }
            hero(state: state, now: now)
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Dépense"), symbol: "minus", colorHex: accentHex) { sheet = .expense(nil) }
                    .accessibilityIdentifier("finances-add-expense")
                MiniActionButton(title: tr("Revenu"), symbol: "plus", colorHex: Finances.incomeHex, isProminent: false) { sheet = .income(nil) }
                    .accessibilityIdentifier("finances-add-income")
            }
            month(state: state, now: now)
            categories(state: state, now: now)
            bills(state: state, now: now)
            savings(state: state)
            more(state: state)
            Text(tr("Tessera ne se connecte à aucune banque : tout vient de ce que tu notes. Ce sont des repères, pas des conseils financiers."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            MiniAppSettingsSection(app: .finances)
        }
        .navigationTitle(tr("Finances"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    // MARK: What is left

    private func hero(state: BudgetState, now: Date) -> some View {
        let spent = BudgetMath.spentThisMonth(state, at: now)
        let remaining = BudgetMath.remaining(state, at: now)
        let over = remaining < 0
        let comparison = BudgetMath.monthToDate(state, at: now)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(over ? tr("Dépassé ce mois-ci") : tr("Reste ce mois-ci"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { sheet = .budget } label: {
                    Text(tr("Budget \(TF.money(state.monthlyBudget, currency))"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("finances-budget")
            }
            Text(TF.money(abs(remaining), currency))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(over ? Color(hex: Finances.overHex) : Color.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
            ProgressView(value: min(spent, max(1, state.monthlyBudget)), total: max(1, state.monthlyBudget))
                .tint(over ? Color(hex: Finances.overHex) : Color(hex: accentHex))
            Text(heroDetail(state: state, spent: spent, now: now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if comparison.previous > 0, abs(comparison.current - comparison.previous) >= 1 {
                let difference = comparison.current - comparison.previous
                Label(difference > 0 ? tr("\(TF.money(abs(difference), currency)) de plus que le mois dernier à la même date") : tr("\(TF.money(abs(difference), currency)) de moins que le mois dernier à la même date"),
                      systemImage: difference > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(difference > 0 ? Color(hex: Finances.overHex) : Color(hex: Finances.incomeHex))
            }
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finances-hero")
    }

    private func heroDetail(state: BudgetState, spent: Double, now: Date) -> String {
        let days = BudgetMath.daysLeftInMonth(now)
        let dayText = Fmt.plural(days, tr("jour"), tr("jours"))
        if days <= 1 { return tr("\(TF.money(spent, currency)) dépensés · dernier jour du mois") }
        guard BudgetMath.remaining(state, at: now) > 0 else { return tr("\(TF.money(spent, currency)) dépensés · \(dayText) avant la fin du mois") }
        return tr("\(TF.money(spent, currency)) dépensés · \(TF.money(BudgetMath.perDayLeft(state, at: now), currency)) par jour pendant \(dayText)")
    }

    // MARK: The month

    @ViewBuilder
    private func month(state: BudgetState, now: Date) -> some View {
        let interval = BudgetMath.monthInterval(now)
        let earned = BudgetMath.earned(state, in: interval)
        let expected = model.profile.monthlyIncome
        let spent = BudgetMath.spentThisMonth(state, at: now)
        if earned > 0 || expected != nil {
            NavigationLink(value: HomeRoute.page(.financesTrends)) {
                HStack(spacing: 10) {
                    if earned > 0 {
                        MiniStat(title: tr("Revenus"), value: TF.money(earned, currency), detail: tr("ce mois-ci"), colorHex: Finances.incomeHex)
                    } else if let expected {
                        MiniStat(title: tr("Revenus"), value: TF.money(expected, currency), detail: tr("prévus (Mes informations)"))
                    }
                    MiniStat(title: tr("Dépenses"), value: TF.money(spent, currency), detail: tr("ce mois-ci"))
                    let balance = (earned > 0 ? earned : (expected ?? 0)) - spent
                    MiniStat(title: tr("Solde"), value: TF.money(balance, currency), detail: earned > 0 ? tr("jusqu'ici") : tr("estimé"),
                             colorHex: balance < 0 ? Finances.overHex : Finances.incomeHex)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("finances-month")
        }
    }

    // MARK: Categories

    @ViewBuilder
    private func categories(state: BudgetState, now: Date) -> some View {
        let status = BudgetMath.categoryStatus(state, at: now).filter { $0.spent > 0 }
        if !status.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Catégories"), detail: Fmt.monthYear(now).capitalizedFirst)
                NavigationLink(value: HomeRoute.page(.financesCategories)) {
                    VStack(spacing: 12) {
                        ForEach(status.prefix(4)) { item in
                            CategoryBar(status: item, currency: currency)
                        }
                        HStack {
                            Text(status.count > 4 ? tr("Les \(status.count) catégories") : tr("Détail des catégories"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: accentHex))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                    }
                    .card(padding: 14)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("finances-categories")
            }
        }
    }

    // MARK: Bills

    @ViewBuilder
    private func bills(state: BudgetState, now: Date) -> some View {
        let upcoming = BudgetMath.upcomingBills(state, at: now, within: 14)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Factures à venir"), detail: tr("\(TF.money(upcoming.reduce(0) { $0 + $1.bill.amount }, currency, decimals: 2)) en 14 jours"))
                NavigationLink(value: HomeRoute.page(.financesBills)) {
                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.prefix(3).enumerated()), id: \.element.id) { index, item in
                            if index > 0 { MiniDivider() }
                            MiniRow(symbol: item.bill.symbol, colorHex: item.days <= 2 ? Finances.overHex : accentHex, title: item.bill.name,
                                    detail: TF.relativeDay(item.due, from: now).capitalizedFirst,
                                    value: TF.money(item.bill.amount, currency, decimals: 2), showsChevron: false)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("finances-bills")
            }
        }
    }

    // MARK: Savings

    @ViewBuilder
    private func savings(state: BudgetState) -> some View {
        if !state.goals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Épargne"))
                NavigationLink(value: HomeRoute.page(.financesSavings)) {
                    VStack(spacing: 14) {
                        ForEach(state.goals.prefix(2)) { goal in
                            GoalProgressRow(goal: goal, currency: currency)
                        }
                    }
                    .card(padding: 14)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("finances-savings")
            }
        }
    }

    // MARK: More

    private func more(state: BudgetState) -> some View {
        MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.financesTransactions)) {
                MiniRow(symbol: "list.bullet.rectangle", colorHex: accentHex, title: tr("Opérations"), detail: tr("Dépenses et revenus, mois par mois"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("finances-transactions")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesCategories)) {
                MiniRow(symbol: "chart.pie.fill", colorHex: "8C6CFF", title: tr("Catégories"), detail: tr("Répartition et limites"), value: "\(state.categories.count)")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesBills)) {
                MiniRow(symbol: "doc.text.fill", colorHex: "F2A33A", title: tr("Factures et abonnements"),
                        detail: state.bills.isEmpty ? tr("Loyer, Internet, abonnements…") : tr("\(TF.money(BudgetMath.billsMonthly(state), currency)) par mois"))
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesSavings)) {
                MiniRow(symbol: "banknote.fill", colorHex: Finances.incomeHex, title: tr("Épargne et comptes"),
                        detail: state.accounts.isEmpty ? tr("Objectifs et valeur nette") : tr("Valeur nette \(TF.money(BudgetMath.netWorth(state), currency))"))
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesTrends)) {
                MiniRow(symbol: "chart.bar.xaxis", colorHex: "3366FF", title: tr("Évolution"), detail: tr("Six mois, moyennes et comparaisons"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("finances-trends")
        }
    }
}

// MARK: - Shared pieces

/// A category of the month: what was spent, against its limit when it has one.
struct CategoryBar: View {
    let status: BudgetMath.CategoryStatus
    let currency: String

    var body: some View {
        let hex = status.category.colorHex
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: status.category.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: hex))
                    .frame(width: 18)
                Text(status.category.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status.isOver ? Color(hex: Finances.overHex) : Color.primary)
                    .monospacedDigit()
            }
            if let ratio = status.ratio {
                ProgressView(value: min(1, ratio))
                    .tint(status.isOver ? Color(hex: Finances.overHex) : Color(hex: hex))
            }
        }
    }

    private var amountText: String {
        guard status.limit > 0 else { return TF.money(status.spent, currency) }
        return "\(TF.money(status.spent, currency)) / \(TF.money(status.limit, currency))"
    }
}

/// A savings goal: how far along, and what it takes each month to get there in time.
struct GoalProgressRow: View {
    let goal: SavingsGoal
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                Text(Fmt.percent(goal.progress)).font(.subheadline.weight(.bold)).foregroundStyle(Color(hex: Finances.incomeHex)).monospacedDigit()
            }
            ProgressView(value: goal.progress).tint(Color(hex: Finances.incomeHex))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        var parts = [tr("\(TF.money(goal.saved, currency)) sur \(TF.money(goal.target, currency))")]
        if let monthly = BudgetMath.monthlyToReach(goal, at: Date()), let deadline = goal.deadline {
            parts.append(tr("\(TF.money(monthly, currency)) / mois d'ici \(Fmt.monthYear(deadline))"))
        } else if goal.saved >= goal.target {
            parts.append(tr("atteint"))
        }
        return parts.joined(separator: " · ")
    }
}

/// The balance as it went, at the top of Finances: what came in minus what went out, day by day, over
/// the month, three months or the year: from the « Solde de départ » when there is one, otherwise from
/// zero at the start of the period.
private struct BalanceChartCard: View {
    let state: BudgetState
    let currency: String
    /// Opens « Solde de départ ».
    let onEditOpening: () -> Void
    @State private var period: Period = .month

    enum Period: String, CaseIterable, Identifiable {
        case month, quarter, year

        var id: String { rawValue }

        var title: String {
            switch self {
            case .month: tr("Mois")
            case .quarter: tr("3 mois")
            case .year: tr("Année")
            }
        }

        func start(_ now: Date) -> Date {
            let month = BudgetMath.monthInterval(now).start
            switch self {
            case .month: return month
            case .quarter: return DateMath.calendar.date(byAdding: .month, value: -2, to: month) ?? month
            case .year: return DateMath.calendar.date(byAdding: .month, value: -11, to: month) ?? month
            }
        }
    }

    var body: some View {
        let now = Date()
        let points = BudgetMath.balanceHistory(state, from: period.start(now), now: now)
        let balance = points.last?.balance ?? 0
        let color = Color(hex: balance < 0 ? Finances.overHex : Finances.incomeHex)
        let dayFormat: Date.FormatStyle = period == .month ? .dateTime.day().month(.abbreviated) : .dateTime.month(.abbreviated)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.openingBalance == nil ? tr("Solde") : tr("Solde du compte"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(TF.money(balance, currency))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(balance < 0 ? color : Color.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                Picker(tr("Période"), selection: $period.animation(.snappy)) {
                    ForEach(Period.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
            }
            Chart {
                ForEach(points) { point in
                    AreaMark(x: .value("Jour", point.date), y: .value("Solde", point.balance))
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.28), color.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Jour", point.date), y: .value("Solde", point.balance))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("Zéro", 0.0))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if let last = points.last {
                    PointMark(x: .value("Jour", last.date), y: .value("Solde", last.balance))
                        .foregroundStyle(color)
                        .symbolSize(70)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel(format: dayFormat)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(TF.money(amount, currency))
                        }
                    }
                }
            }
            .frame(height: 170)
            .accessibilityLabel(Text(tr("Évolution du solde")))
            Text(caption(points))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onEditOpening) {
                Label(state.openingBalance == nil ? tr("Ajouter ton solde de départ") : tr("Modifier le solde de départ"),
                      systemImage: state.openingBalance == nil ? "plus.circle.fill" : "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: Finances.accentHex))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("finances-opening")
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finances-balance")
    }

    /// Where the balance starts from, and what it counts.
    private func caption(_ points: [BudgetMath.BalancePoint]) -> String {
        if let amount = state.openingBalance, let date = state.openingDate {
            return tr("À partir de \(TF.money(amount, currency)) le \(Fmt.shortDay(date)), puis tes revenus et tes dépenses, factures et montants fixes compris.")
        }
        guard let first = points.first, points.contains(where: { $0.balance != 0 }) else {
            return tr("Note tes revenus et tes dépenses : ton solde s'affichera ici.")
        }
        return tr("Revenus moins dépenses depuis le \(Fmt.shortDay(first.date)), factures et montants fixes compris.")
    }
}
