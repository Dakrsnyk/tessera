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

    /// The bill or the fixed income or expense a payment comes from: it is changed or removed there.
    static func fixed(_ id: UUID, state: BudgetState, items: [MoneyItem]) -> FinanceSheet? {
        if let bill = state.bills.first(where: { $0.id == id }) { return .bill(bill) }
        return items.first { $0.id == id }.map { FinanceSheet.flow($0) }
    }
}

enum Finances {
    static var accentHex: String { MiniApp.finances.colorHex }
    static let overHex = MiniStyle.alertHex
    static let incomeHex = MiniStyle.goodHex
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
                Text(tr("Ce que tu te permets de dépenser chaque mois, factures comprises ou non : à toi de choisir, Ardane compte ce que tu notes."))
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
                Text(tr("Ce que ton compte affichait ce jour-là, avant ses opérations. Le graphique du solde part de ce montant, puis suit tes revenus et tes dépenses notés dans Ardane."))
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

/// The Finances mini-app, top to bottom, as in the « Signature » mock-up. On the band: the week selector, then
/// what is left of the month's budget as it stood at the end of the chosen day, with its trend. On the sheet:
/// the two actions, the chosen day (two tiles and its operations), « Ce mois-ci », the balance as it went, the
/// categories, the bills coming and the savings; then every operation, the evolution and the fixed expenses;
/// a note and the settings last. The figures of the month follow the chosen day (nothing noted after it counts).
struct FinancesAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: FinanceSheet?
    @State private var day = Date()

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Finances.accentHex }

    /// The moment the month's figures are read at: now for today, the end of the chosen day otherwise.
    private func reference(now: Date) -> Date {
        DateMath.isSameDay(day, now) ? now : DateMath.nextMidnight(after: day).addingTimeInterval(-1)
    }

    var body: some View {
        let now = Date()
        let at = reference(now: now)
        let state = model.budget
        MiniAppScaffold(colorHex: accentHex) {
            // The band: the only date selector (spending is logged, so it stops at today), then the budget left.
            WeekSelector(day: $day, colorHex: accentHex, allowsFuture: false, mark: { dayMark($0, state: state) })
            hero(state: state, now: now, at: at)
        } sheet: {
            // The sheet, by importance: the two actions, the chosen day, the month, then the balance and the rest.
            MiniAppToFillSection(app: .finances)
            // Grouped: a builder takes ten views at most.
            Group {
                actions
                dayCard(state: state, now: now)
            }
            month(state: state, now: now)
            BalanceChartCard(state: state, currency: currency, isPremium: model.isPremium) { sheet = .opening }
            categories(state: state, now: now)
            bills(state: state, now: now)
            savings(state: state)
            more(state: state, now: now)
            MiniFootnote(text: tr("Ardane ne se connecte à aucune banque : tout vient de ce que tu notes. Ce sont des repères, pas des conseils financiers."))
            MiniAppInfoSection(app: .finances)
        }
        .navigationTitle(tr("Finances"))
        .sheet(item: $sheet) { $0.editor }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            MiniActionButton(title: tr("Dépense"), symbol: "minus", colorHex: accentHex) { sheet = .expense(nil) }
                .accessibilityIdentifier("finances-add-expense")
            MiniActionButton(title: tr("Revenu"), symbol: "plus", colorHex: Finances.incomeHex, isProminent: false) { sheet = .income(nil) }
                .accessibilityIdentifier("finances-add-income")
        }
    }

    /// The categories of the chosen day's month with some spending (the section and the list below use it).
    private func categoryStatus(_ state: BudgetState, now: Date) -> [BudgetMath.CategoryStatus] {
        BudgetMath.categoryStatus(state, throughDay: day, now: now).filter { $0.spent > 0 }
    }

    /// What came in, from the start of the chosen day's month to the end of that day.
    private func monthEarned(_ state: BudgetState, now: Date) -> Double {
        BudgetMath.earned(state, throughDay: day, now: now)
    }

    // MARK: What is left

    /// The budget left at the end of the chosen day, straight on the band (no card): the budget of the month
    /// minus the spending from the 1st to that day. For today it is the usual figure of the month so far.
    private func hero(state: BudgetState, now: Date, at: Date) -> some View {
        let spent = BudgetMath.spentThisMonth(state, throughDay: day, now: now)
        let remaining = BudgetMath.remaining(state, throughDay: day, now: now)
        let over = remaining < 0
        let comparison = BudgetMath.monthToDate(state, at: at)
        return VStack(alignment: .leading, spacing: 10) {
            MiniHero(label: over ? tr("Dépassé ce mois-ci") : tr("Reste ce mois-ci"),
                     value: TF.money(abs(remaining), currency),
                     caption: heroDetail(state: state, spent: spent, remaining: remaining, now: now))
            trend(state: state, now: now, over: over)
            HStack {
                Button { sheet = .budget } label: {
                    Text(tr("Budget \(TF.money(state.monthlyBudget, currency))"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.primary.opacity(0.12), in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-budget")
                Spacer(minLength: 0)
            }
            if comparison.previous > 0, abs(comparison.current - comparison.previous) >= 1 {
                let difference = comparison.current - comparison.previous
                Label(difference > 0 ? tr("\(TF.money(abs(difference), currency)) de plus que le mois dernier à la même date") : tr("\(TF.money(abs(difference), currency)) de moins que le mois dernier à la même date"),
                      systemImage: difference > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .opacity(0.85)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finances-hero")
    }

    /// The small white curve under the figure: what was left of the budget at the end of each day of the month,
    /// up to the chosen day. Nothing is drawn until the budget has moved.
    @ViewBuilder
    private func trend(state: BudgetState, now: Date, over: Bool) -> some View {
        let values = remainingByDay(state, now: now)
        if values.count >= 2, let high = values.max(), let low = values.min(), high > low {
            Chart(Array(values.enumerated()), id: \.offset) { item in
                LineMark(x: .value("Jour", item.offset), y: .value("Reste", item.element))
                    .foregroundStyle(over ? Color(hex: Finances.overHex) : Color.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 40)
            .accessibilityHidden(true)
        }
    }

    /// The budget left at the end of each day, from the 1st of the chosen day's month to that day.
    private func remainingByDay(_ state: BudgetState, now: Date) -> [Double] {
        var values: [Double] = []
        var cursor = DateMath.startOfDay(BudgetMath.monthInterval(day).start)
        while cursor <= day && values.count < 31 {
            values.append(BudgetMath.remaining(state, throughDay: cursor, now: now))
            guard let next = DateMath.calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return values
    }

    /// What was spent, and what can be spent each day left once the chosen day is over. On the last day of the
    /// month there is nothing left to spread.
    private func heroDetail(state: BudgetState, spent: Double, remaining: Double, now: Date) -> String {
        if BudgetMath.daysLeftInMonth(day) <= 1 { return tr("\(TF.money(spent, currency)) dépensés · dernier jour du mois") }
        let days = BudgetMath.daysToCover(throughDay: day, now: now)
        let dayText = Fmt.plural(days, tr("jour"), tr("jours"))
        guard remaining > 0 else { return tr("\(TF.money(spent, currency)) dépensés · \(dayText) avant la fin du mois") }
        return tr("\(TF.money(spent, currency)) dépensés · \(TF.money(BudgetMath.perDayLeft(state, throughDay: day, now: now), currency)) par jour pendant \(dayText)")
    }

    // MARK: The day

    /// What came in and went out on the chosen day (the fixed payments of that day included), with the
    /// operations themselves; a tap opens one to change it.
    @ViewBuilder
    private func dayCard(state: BudgetState, now: Date) -> some View {
        let interval = DateInterval(start: DateMath.startOfDay(day), end: DateMath.nextMidnight(after: day))
        let expenses = BudgetMath.expenses(state, in: interval, now: now).sorted { $0.date > $1.date }
        let incomes = BudgetMath.incomes(state, in: interval, now: now).sorted { $0.date > $1.date }
        let spent = expenses.reduce(0) { $0 + $1.amount }
        let earned = incomes.reduce(0) { $0 + $1.amount }
        VStack(alignment: .leading, spacing: 10) {
            // The date of the chosen day (today included), as in the mock-up.
            MiniSectionTitle(title: Fmt.longDay(day).capitalizedFirst)
            HStack(spacing: 10) {
                MiniStat(title: tr("Dépenses du jour"), value: (spent > 0 ? "−" : "") + TF.money(spent, currency, decimals: 2))
                MiniStat(title: tr("Revenus du jour"), value: TF.money(earned, currency, decimals: 2), colorHex: earned > 0 ? Finances.incomeHex : nil)
            }
            if !expenses.isEmpty || !incomes.isEmpty {
                MiniRowsCard {
                    ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                        if index > 0 { MiniDivider() }
                        Button { open(expense, state: state) } label: { expenseRow(expense, state: state) }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("finances-day-row")
                    }
                    ForEach(Array(incomes.enumerated()), id: \.element.id) { index, income in
                        if index > 0 || !expenses.isEmpty { MiniDivider() }
                        Button { open(income, state: state) } label: { incomeRow(income) }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("finances-day-row")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finances-day")
    }

    private func expenseRow(_ expense: Expense, state: BudgetState) -> some View {
        let category = state.category(expense.categoryID)
        let name = category?.name ?? tr("Sans catégorie")
        return FinancesRow(symbol: category?.symbol ?? "square.grid.2x2", colorHex: category?.colorHex ?? "64748B",
                       title: expense.note.isEmpty ? (category?.name ?? tr("Dépense")) : expense.note,
                       detail: expense.fixedID == nil ? name : tr("Dépense fixe · \(name)"),
                       value: Fmt.signedMoney(-expense.amount, currency: currency))
    }

    private func incomeRow(_ income: IncomeEntry) -> some View {
        FinancesRow(symbol: "arrow.down.left", colorHex: Finances.incomeHex, title: income.label.isEmpty ? tr("Revenu") : income.label,
                detail: income.fixedID == nil ? tr("Revenu") : tr("Revenu fixe"),
                value: Fmt.signedMoney(income.amount, currency: currency))
    }

    /// An expense or an income opens where it comes from: itself, or the bill or fixed amount behind it.
    private func open(_ expense: Expense, state: BudgetState) {
        sheet = expense.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .expense(expense)
    }

    private func open(_ income: IncomeEntry, state: BudgetState) {
        sheet = income.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .income(income)
    }

    /// A day with at least one operation (noted or fixed) is marked on the selector.
    private func dayMark(_ date: Date, state: BudgetState) -> WeekDayMark {
        let interval = DateInterval(start: DateMath.startOfDay(date), end: DateMath.nextMidnight(after: date))
        let now = Date()
        let holdsSomething = !BudgetMath.expenses(state, in: interval, now: now).isEmpty
            || !BudgetMath.incomes(state, in: interval, now: now).isEmpty
        return WeekDayMark(isPlanned: holdsSomething)
    }

    // MARK: The month

    /// What came in this month (the expenses are in the budget above and the balance in the chart: neither is
    /// repeated); it opens the evolution.
    @ViewBuilder
    private func month(state: BudgetState, now: Date) -> some View {
        let earned = monthEarned(state, now: now)
        let expected = model.profile.monthlyIncome
        if earned > 0 || expected != nil {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Ce mois-ci"))
                NavigationLink(value: HomeRoute.page(.financesTrends)) {
                    VStack(spacing: 0) {
                        if earned > 0 {
                            FinancesRow(symbol: "arrow.down.left", colorHex: Finances.incomeHex, title: tr("Revenus"), detail: tr("ce mois-ci"),
                                        value: TF.money(earned, currency))
                        } else if let expected {
                            FinancesRow(symbol: "arrow.down.left", colorHex: Finances.incomeHex, title: tr("Revenus"), detail: tr("prévus (Mes informations)"),
                                        value: TF.money(expected, currency))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .miniCard()
                }
                .buttonStyle(.pressable)
                // The « Évolution » row of the list below is only there when this row is not.
                .accessibilityIdentifier("finances-trends")
            }
        }
    }

    // MARK: Categories

    @ViewBuilder
    private func categories(state: BudgetState, now: Date) -> some View {
        let status = categoryStatus(state, now: now)
        if !status.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Catégories"), detail: Fmt.monthYear(day).capitalizedFirst)
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
                .buttonStyle(.pressable)
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
                            FinancesRow(symbol: item.bill.symbol, colorHex: item.days <= 2 ? Finances.overHex : accentHex, title: item.bill.name,
                                    detail: TF.relativeDay(item.due, from: now).capitalizedFirst,
                                    value: TF.money(item.bill.amount, currency, decimals: 2), showsChevron: false)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .miniCard()
                }
                .buttonStyle(.pressable)
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
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-savings")
            }
        }
    }

    // MARK: More

    /// The list under the sections. A destination already shown above (a section or the month row) is not
    /// repeated; its row comes back only when that section or that row is hidden (nothing to show yet),
    /// so every page stays reachable. The identifiers move with the link.
    private func more(state: BudgetState, now: Date) -> some View {
        let showsCategories = !categoryStatus(state, now: now).isEmpty
        let showsBills = !BudgetMath.upcomingBills(state, at: now, within: 14).isEmpty
        let showsSavings = !state.goals.isEmpty
        let showsMonth = monthEarned(state, now: now) > 0 || model.profile.monthlyIncome != nil
        return MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.financesTransactions)) {
                FinancesRow(symbol: "list.bullet.rectangle", colorHex: accentHex, title: tr("Opérations"), detail: tr("Dépenses et revenus, mois par mois"))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("finances-transactions")
            if !showsCategories {
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesCategories)) {
                    FinancesRow(symbol: "chart.pie.fill", colorHex: "8C6CFF", title: tr("Catégories"), detail: tr("Répartition et limites"), value: "\(state.categories.count)")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-categories")
            }
            if !showsBills {
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesBills)) {
                    FinancesRow(symbol: "doc.text.fill", colorHex: "F2A33A", title: tr("Factures et abonnements"),
                            detail: state.bills.isEmpty ? tr("Loyer, Internet, abonnements…") : tr("\(TF.money(BudgetMath.billsMonthly(state), currency)) par mois"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-bills")
            }
            if !showsSavings {
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesSavings)) {
                    FinancesRow(symbol: "banknote.fill", colorHex: Finances.incomeHex, title: tr("Épargne et comptes"),
                            detail: state.accounts.isEmpty ? tr("Objectifs et valeur nette") : tr("Valeur nette \(TF.money(BudgetMath.netWorth(state), currency))"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-savings")
            }
            if !showsMonth {
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesTrends)) {
                    FinancesRow(symbol: "chart.bar.xaxis", colorHex: "3366FF", title: tr("Évolution"), detail: tr("Six mois, moyennes et comparaisons"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-trends")
            }
            MiniDivider()
            // The fixed expenses of « Revenus et dépenses fixes » (rent, insurance, phone…), counted on their dates.
            NavigationLink { MoneyView() } label: {
                let monthly = BudgetMath.fixedExpensesMonthly(state)
                FinancesRow(symbol: "repeat", colorHex: "D6409F", title: tr("Dépenses fixes"),
                        detail: monthly > 0 ? tr("\(TF.money(monthly, currency)) par mois") : tr("Loyer, assurances, forfaits…"))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("finances-fixed")
        }
    }
}

// MARK: - Shared pieces

/// A row of the Signature style: an icon in a tinted rounded square, a title, a detail, a value and a chevron.
private struct FinancesRow: View {
    let symbol: String
    let colorHex: String
    let title: String
    var detail: String?
    var value: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 36, height: 36)
                .background(Color(hex: colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
    /// The month stays free; three months and the year are part of the detailed statistics.
    let isPremium: Bool
    /// Opens « Solde de départ ».
    let onEditOpening: () -> Void
    @State private var period: Period = .month
    @State private var paywall: PaywallContext?

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
        let statement = HomeRoute.page(.financesStatement(period.start(now)))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // The balance opens the statement: every movement, day by day, like a bank account.
                NavigationLink(value: statement) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(state.openingBalance == nil ? tr("Solde") : tr("Solde du compte"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        Text(TF.money(balance, currency))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(balance < 0 ? color : Color.primary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-statement")
                Spacer(minLength: 8)
                Picker(tr("Période"), selection: Binding(get: { period }, set: { choice in
                    if choice == .month || isPremium {
                        withAnimation(.snappy) { period = choice }
                    } else {
                        paywall = .financesHistory
                    }
                })) {
                    ForEach(Period.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
            }
            NavigationLink(value: statement) {
                chart(points, color: color, dayFormat: dayFormat)
            }
            .buttonStyle(.pressable)
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
            .buttonStyle(.pressable)
            .accessibilityIdentifier("finances-opening")
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finances-balance")
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    private func chart(_ points: [BudgetMath.BalancePoint], color: Color, dayFormat: Date.FormatStyle) -> some View {
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
    }

    /// Where the balance starts from, and what it counts.
    private func caption(_ points: [BudgetMath.BalancePoint]) -> String {
        if let amount = state.openingBalance, let date = state.openingDate {
            return tr("À partir de \(TF.money(amount, currency)) le \(Fmt.format(date, template: "dMMM")), puis tes revenus et tes dépenses, factures et montants fixes compris.")
        }
        guard let first = points.first, points.contains(where: { $0.balance != 0 }) else {
            return tr("Note tes revenus et tes dépenses : ton solde s'affichera ici.")
        }
        return tr("Revenus moins dépenses depuis le \(Fmt.format(first.date, template: "dMMM")), factures et montants fixes compris.")
    }
}
