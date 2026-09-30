import SwiftUI

/// Everything the Finances mini-app edits in a sheet.
enum FinanceSheet: Identifiable {
    case expense(Expense?)
    case income(IncomeEntry?)
    case bill(Bill)
    case goal(SavingsGoal)
    case account(Account)
    case category(BudgetCategory)
    case budget

    var id: String {
        switch self {
        case let .expense(expense): "expense-\(expense?.id.uuidString ?? "new")"
        case let .income(income): "income-\(income?.id.uuidString ?? "new")"
        case let .bill(bill): "bill-\(bill.id)"
        case let .goal(goal): "goal-\(goal.id)"
        case let .account(account): "account-\(account.id)"
        case let .category(category): "category-\(category.id)"
        case .budget: "budget"
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
        case .budget: MonthlyBudgetEditor()
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
        SheetForm(title: "Budget du mois", canSave: amount >= 0, onSave: { model.setMonthlyBudget(amount) }) {
            Section {
                NumberRow(title: "Budget", value: $amount, unit: model.settings.currencyCode)
            } footer: {
                Text("Ce que tu te permets de dépenser chaque mois, factures comprises ou non : à toi de choisir, Tessera compte ce que tu notes.")
            }
        }
        .onAppear { amount = model.budget.monthlyBudget }
    }
}

/// The Finances mini-app: what is left this month, what came in and went out, the categories, the
/// bills coming and the savings; then every operation, the evolution and the accounts.
struct FinancesAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Finances.accentHex }

    var body: some View {
        let now = Date()
        let state = model.budget
        MiniAppScroll {
            hero(state: state, now: now)
            HStack(spacing: 10) {
                MiniActionButton(title: "Dépense", symbol: "minus", colorHex: accentHex) { sheet = .expense(nil) }
                    .accessibilityIdentifier("finances-add-expense")
                MiniActionButton(title: "Revenu", symbol: "plus", colorHex: Finances.incomeHex, isProminent: false) { sheet = .income(nil) }
                    .accessibilityIdentifier("finances-add-income")
            }
            month(state: state, now: now)
            categories(state: state, now: now)
            bills(state: state, now: now)
            savings(state: state)
            more(state: state)
            Text("Tessera ne se connecte à aucune banque : tout vient de ce que tu notes. Ce sont des repères, pas des conseils financiers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .navigationTitle("Finances")
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
                Text(over ? "Dépassé ce mois-ci" : "Reste ce mois-ci")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { sheet = .budget } label: {
                    Text("Budget \(TF.money(state.monthlyBudget, currency))")
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
            if comparison.previous > 0 {
                let difference = comparison.current - comparison.previous
                Label("\(TF.money(abs(difference), currency)) de \(difference > 0 ? "plus" : "moins") que le mois dernier à la même date",
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
        let dayText = Fmt.plural(days, "jour", "jours")
        guard BudgetMath.remaining(state, at: now) > 0 else { return "\(TF.money(spent, currency)) dépensés · \(dayText) avant la fin du mois" }
        return "\(TF.money(spent, currency)) dépensés · \(TF.money(BudgetMath.perDayLeft(state, at: now), currency)) par jour pendant \(dayText)"
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
                        MiniStat(title: "Revenus", value: TF.money(earned, currency), detail: "ce mois-ci", colorHex: Finances.incomeHex)
                    } else if let expected {
                        MiniStat(title: "Revenus", value: TF.money(expected, currency), detail: "prévus (Mes informations)")
                    }
                    MiniStat(title: "Dépenses", value: TF.money(spent, currency), detail: "ce mois-ci")
                    let balance = (earned > 0 ? earned : (expected ?? 0)) - spent
                    MiniStat(title: "Solde", value: TF.money(balance, currency), detail: earned > 0 ? "jusqu'ici" : "estimé",
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
                MiniSectionTitle(title: "Catégories", detail: Fmt.monthYear(now).capitalizedFirst)
                NavigationLink(value: HomeRoute.page(.financesCategories)) {
                    VStack(spacing: 12) {
                        ForEach(status.prefix(4)) { item in
                            CategoryBar(status: item, currency: currency)
                        }
                        HStack {
                            Text(status.count > 4 ? "Les \(status.count) catégories" : "Détail des catégories")
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
                MiniSectionTitle(title: "Factures à venir", detail: "\(TF.money(upcoming.reduce(0) { $0 + $1.bill.amount }, currency, decimals: 2)) en 14 jours")
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
                MiniSectionTitle(title: "Épargne")
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
                MiniRow(symbol: "list.bullet.rectangle", colorHex: accentHex, title: "Opérations", detail: "Dépenses et revenus, mois par mois")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("finances-transactions")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesCategories)) {
                MiniRow(symbol: "chart.pie.fill", colorHex: "8C6CFF", title: "Catégories", detail: "Répartition et limites", value: "\(state.categories.count)")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesBills)) {
                MiniRow(symbol: "doc.text.fill", colorHex: "F2A33A", title: "Factures et abonnements",
                        detail: state.bills.isEmpty ? "Loyer, Internet, abonnements…" : "\(TF.money(BudgetMath.billsMonthly(state), currency)) par mois")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesSavings)) {
                MiniRow(symbol: "banknote.fill", colorHex: Finances.incomeHex, title: "Épargne et comptes",
                        detail: state.accounts.isEmpty ? "Objectifs et valeur nette" : "Valeur nette \(TF.money(BudgetMath.netWorth(state), currency))")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.financesTrends)) {
                MiniRow(symbol: "chart.bar.xaxis", colorHex: "3366FF", title: "Évolution", detail: "Six mois, moyennes et comparaisons")
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
        var parts = ["\(TF.money(goal.saved, currency)) sur \(TF.money(goal.target, currency))"]
        if let monthly = BudgetMath.monthlyToReach(goal, at: Date()), let deadline = goal.deadline {
            parts.append("\(TF.money(monthly, currency)) / mois d'ici \(Fmt.monthYear(deadline))")
        } else if goal.saved >= goal.target {
            parts.append("atteint")
        }
        return parts.joined(separator: " · ")
    }
}
