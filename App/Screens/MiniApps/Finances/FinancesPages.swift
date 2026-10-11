import Charts
import SwiftUI

/// Moves between months without leaving the screen.
struct MonthSwitcher: View {
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
        .foregroundStyle(Color(hex: colorHex))
        .background(.cardFill, in: Capsule())
    }

    private func move(_ months: Int) {
        guard let next = DateMath.calendar.date(byAdding: .month, value: months, to: month) else { return }
        Haptics.tap()
        month = min(next, Date())
    }
}

// MARK: - Operations

/// Every expense or income of a month, day by day, each one editable.
struct FinancesTransactionsPage: View {
    enum Kind: String, CaseIterable, Identifiable {
        case expenses, incomes
        var id: String { rawValue }
        var title: String { self == .expenses ? tr("Dépenses") : tr("Revenus") }
    }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var month = Date()
    @State private var kind: Kind = .expenses
    @State private var categoryID: UUID?
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.budget
        let interval = BudgetMath.monthInterval(month)
        List {
            Section {
                MonthSwitcher(month: $month, earliest: model.isPremium ? nil : PremiumHistory.earliestFreeDay()) { router.showPaywall(.financesHistory) }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                Picker(tr("Type"), selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            if kind == .expenses {
                expenses(state: state, interval: interval)
            } else {
                incomes(state: state, interval: interval)
            }
        }
        .styledList()
        .tint(Color(hex: Finances.accentHex))
        .navigationTitle(tr("Opérations"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { sheet = kind == .expenses ? FinanceSheet.expense(nil) : FinanceSheet.income(nil) } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text(kind == .expenses ? tr("Nouvelle dépense") : tr("Nouveau revenu")))
                    .accessibilityIdentifier("transactions-add")
            }
        }
        .sheet(item: $sheet) { $0.editor }
    }

    @ViewBuilder
    private func expenses(state: BudgetState, interval: DateInterval) -> some View {
        let all = BudgetMath.expenses(state, in: interval).filter { categoryID == nil || $0.categoryID == categoryID }.sorted { $0.date > $1.date }
        Section {
            Menu {
                Button(tr("Toutes les catégories")) { categoryID = nil }
                ForEach(state.categories) { category in
                    Button { categoryID = category.id } label: { Label(category.name, systemImage: category.symbol) }
                }
            } label: {
                HStack {
                    Label(state.category(categoryID)?.name ?? tr("Toutes les catégories"), systemImage: "line.3.horizontal.decrease.circle")
                    Spacer()
                    Text(TF.money(all.reduce(0) { $0 + $1.amount }, currency, decimals: 2)).font(.headline).monospacedDigit().foregroundStyle(.primary)
                }
            }
        }
        if all.isEmpty {
            Section { Text(tr("Aucune dépense notée pour ce mois.")).foregroundStyle(.secondary) }
        }
        ForEach(days(all.map(\.date)), id: \.self) { day in
            let items = all.filter { DateMath.isSameDay($0.date, day) }
            Section(Fmt.longDay(day)) {
                ForEach(items) { expense in
                    // A payment of a fixed expense opens the fixed expense, and is changed or removed there.
                    Button { sheet = expense.fixedID.flatMap { fixedSheet($0, state: state) } ?? .expense(expense) } label: { expenseRow(expense, state: state) }
                        .accessibilityIdentifier(expense.fixedID == nil ? "expense-row" : "fixed-expense-row")
                        .deleteDisabled(expense.fixedID != nil)
                }
                .onDelete { offsets in
                    let ids = offsets.map { items[$0] }.filter { $0.fixedID == nil }.map(\.id)
                    model.update(\.budget) { $0.expenses.removeAll { ids.contains($0.id) } }
                }
            }
        }
    }

    @ViewBuilder
    private func incomes(state: BudgetState, interval: DateInterval) -> some View {
        let all = BudgetMath.incomes(state, in: interval).sorted { $0.date > $1.date }
        Section {
            HStack {
                Text(tr("Total du mois"))
                Spacer()
                Text(TF.money(all.reduce(0) { $0 + $1.amount }, currency, decimals: 2)).font(.headline).monospacedDigit().foregroundStyle(Color(hex: Finances.incomeHex))
            }
            if all.isEmpty {
                Text(model.profile.monthlyIncome.map { tr("Aucun revenu noté ce mois-ci. Revenu mensuel indiqué dans « Mes informations » : \(TF.money($0, currency)).") } ?? tr("Aucun revenu noté ce mois-ci."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        if !all.isEmpty {
            Section {
                ForEach(all) { income in
                    Button { sheet = income.fixedID.flatMap { fixedSheet($0, state: state) } ?? .income(income) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(income.label).foregroundStyle(.primary)
                                Text(income.fixedID == nil ? Fmt.shortDay(income.date) : tr("\(Fmt.shortDay(income.date)) · revenu fixe"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("+\(TF.money(income.amount, currency, decimals: 2))").monospacedDigit().foregroundStyle(Color(hex: Finances.incomeHex))
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { all[$0] }.filter { $0.fixedID == nil }.map(\.id)
                    model.update(\.budget) { $0.incomes.removeAll { ids.contains($0.id) } }
                }
            }
        }
    }

    private func expenseRow(_ expense: Expense, state: BudgetState) -> some View {
        let category = state.category(expense.categoryID)
        return HStack(spacing: 12) {
            Image(systemName: category?.symbol ?? "square.grid.2x2")
                .foregroundStyle(Color(hex: category?.colorHex ?? "64748B"))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.note.isEmpty ? (category?.name ?? tr("Dépense")) : expense.note).foregroundStyle(.primary)
                if expense.fixedID != nil {
                    Label(tr("Dépense fixe · \(category?.name ?? tr("Sans catégorie"))"), systemImage: "repeat")
                        .font(.caption).foregroundStyle(.secondary)
                } else if !expense.note.isEmpty, let category {
                    Text(category.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(TF.money(expense.amount, currency, decimals: 2)).monospacedDigit().foregroundStyle(.primary)
        }
    }

    /// The bill or the fixed income or expense a payment comes from.
    private func fixedSheet(_ id: UUID, state: BudgetState) -> FinanceSheet? {
        if let bill = state.bills.first(where: { $0.id == id }) { return .bill(bill) }
        return model.content.money.items.first { $0.id == id }.map { FinanceSheet.flow($0) }
    }

    /// The distinct days, most recent first.
    private func days(_ dates: [Date]) -> [Date] {
        Array(Set(dates.map(DateMath.startOfDay))).sorted(by: >)
    }
}

// MARK: - Categories

struct FinancesCategoriesPage: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
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
                        .foregroundStyle(Color(hex: spend.colorHex))
                        .cornerRadius(3)
                }
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
                                .foregroundStyle(category.monthlyLimit > 0 && spent > category.monthlyLimit ? Color(hex: Finances.overHex) : Color.secondary)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Divider()
                Button { sheet = .category(BudgetCategory(name: "", symbol: "tag", colorHex: "3366FF")) } label: {
                    Label(tr("Nouvelle catégorie"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: Finances.accentHex))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

// MARK: - Bills

struct FinancesBillsPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.budget
        let now = Date()
        let all = BudgetMath.upcomingBills(state, at: now, within: 400)
        List {
            if !state.bills.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        MiniStat(title: tr("Par mois"), value: TF.money(BudgetMath.billsMonthly(state), currency), detail: Fmt.plural(state.bills.count, tr("facture"), tr("factures")))
                        MiniStat(title: tr("Abonnements"), value: TF.money(BudgetMath.subscriptionsMonthly(state), currency), detail: tr("par mois"))
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            Section {
                ForEach(all) { item in
                    Button { sheet = .bill(item.bill) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.bill.symbol).frame(width: 24).foregroundStyle(item.days <= 2 ? Color(hex: Finances.overHex) : Color(hex: Finances.accentHex))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.bill.name).foregroundStyle(.primary)
                                Text("\(item.bill.isSubscription ? tr("Abonnement · ") : "")\(item.bill.period.title.lowercased()) · \(TF.relativeDay(item.due, from: now))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(TF.money(item.bill.amount, currency, decimals: 2)).monospacedDigit().foregroundStyle(.primary)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { all[$0].bill.id }
                    model.update(\.budget) { $0.bills.removeAll { ids.contains($0.id) } }
                }
                Button { sheet = .bill(Bill(name: "", amount: 0, anchorDate: Date())) } label: { Label(tr("Nouvelle facture"), systemImage: "plus") }
                    .accessibilityIdentifier("bills-new")
            } header: {
                Text(tr("Prochaines échéances"))
            } footer: {
                Text(tr("Loyer, électricité, Internet, abonnements : Ardane te rappelle la prochaine date et le total par mois."))
            }
        }
        .styledList()
        .tint(Color(hex: Finances.accentHex))
        .navigationTitle(tr("Factures"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }
}

// MARK: - Savings and accounts

struct FinancesSavingsPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: FinanceSheet?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let state = model.budget
        MiniAppScroll {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Objectifs d'épargne"), detail: state.goals.isEmpty ? nil : TF.money(state.goals.reduce(0) { $0 + $1.saved }, currency))
                VStack(spacing: 0) {
                    ForEach(Array(state.goals.enumerated()), id: \.element.id) { index, goal in
                        if index > 0 { Divider() }
                        Button { sheet = .goal(goal) } label: {
                            GoalProgressRow(goal: goal, currency: currency)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                model.update(\.budget) { $0.goals.removeAll { $0.id == goal.id } }
                            } label: {
                                Label(tr("Supprimer"), systemImage: "trash")
                            }
                        }
                    }
                    if !state.goals.isEmpty { Divider() }
                    Button { sheet = .goal(SavingsGoal(name: "", target: 1_000, saved: 0, deadline: nil)) } label: {
                        Label(tr("Nouvel objectif"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: Finances.incomeHex))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("goals-new")
                }
                .padding(.horizontal, 14)
                .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                if !state.goals.isEmpty {
                    Text(tr("Touche un objectif pour y ajouter un versement ou le supprimer.")).font(.footnote).foregroundStyle(.secondary)
                }
            }
            accounts(state: state)
        }
        .navigationTitle(tr("Épargne"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func accounts(state: BudgetState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Comptes"), detail: state.accounts.isEmpty ? nil : tr("valeur nette \(TF.money(BudgetMath.netWorth(state), currency))"))
            if state.netWorthHistory.count >= 2 {
                Chart(state.netWorthHistory, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Valeur nette", point.value))
                        .foregroundStyle(Color(hex: Finances.accentHex))
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", point.date), y: .value("Valeur nette", point.value))
                        .foregroundStyle(Color(hex: Finances.accentHex).opacity(0.12).gradient)
                        .interpolationMethod(.catmullRom)
                }
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
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            model.update(\.budget) { $0.removeAccount(account.id) }
                        } label: {
                            Label(tr("Supprimer"), systemImage: "trash")
                        }
                    }
                }
                if !state.accounts.isEmpty { MiniDivider() }
                Button { sheet = .account(Account(name: "", balance: 0)) } label: {
                    Label(tr("Nouveau compte ou dette"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: Finances.accentHex))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            Text(tr("Saisis tes soldes à la main : Ardane ne se connecte à aucune banque. Touche un compte pour le modifier ou le supprimer.")).font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Evolution

/// Six months of money in and out, the averages, and this month against the last one.
struct FinancesTrendsPage: View {
    @Environment(AppModel.self) private var model

    private var currency: String { model.settings.currencyCode }

    private struct Bar: Identifiable {
        let month: Date
        let series: String
        let value: Double
        var id: String { "\(series)-\(month.timeIntervalSince1970)" }
    }

    private struct CategoryChange: Identifiable {
        let name: String
        let colorHex: String
        let current: Double
        let previous: Double
        var id: String { name }
    }

    var body: some View {
        if model.isPremium {
            trends
        } else {
            MiniAppScroll {
                PremiumLockCard(symbol: "chart.bar.xaxis", title: tr("L'évolution est dans Premium"),
                                message: tr("Six mois d'un coup d'œil, tes moyennes et la comparaison avec le mois dernier. Tes opérations restent enregistrées : tout s'affiche dès que tu passes à Premium."))
            }
            .navigationTitle(tr("Évolution"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder private var trends: some View {
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
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: months.count >= 6 ? tr("Six derniers mois") : tr("Par mois"))
                Chart(bars(months)) { bar in
                    BarMark(x: .value("Mois", bar.month, unit: .month), y: .value("Montant", bar.value))
                        .foregroundStyle(by: .value("Type", bar.series))
                        .position(by: .value("Type", bar.series))
                        .cornerRadius(3)
                }
                .chartForegroundStyleScale([tr("Revenus"): Color(hex: Finances.incomeHex), tr("Dépenses"): Color(hex: Finances.accentHex).opacity(0.55)])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .frame(height: 210)
                .card()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("trends-chart")
            }
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
                            MiniStat(title: tr("Mis de côté"), value: TF.money(earned - spent, currency), detail: earned > 0 ? Fmt.percent(max(0, (earned - spent) / earned)) + tr(" des revenus") : nil,
                                     colorHex: earned - spent < 0 ? Finances.overHex : Finances.incomeHex)
                        }
                    }
                }
            }
            changes(state: state, now: now)
            Text(tr("Moyennes calculées sur les mois terminés où tu as noté quelque chose."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(tr("Évolution"))
        .navigationBarTitleDisplayMode(.large)
    }

    private func bars(_ months: [BudgetMath.MonthSummary]) -> [Bar] {
        months.flatMap { [Bar(month: $0.start, series: tr("Revenus"), value: $0.earned), Bar(month: $0.start, series: tr("Dépenses"), value: $0.spent)] }
    }

    @ViewBuilder
    private func changes(state: BudgetState, now: Date) -> some View {
        let month = BudgetMath.monthInterval(now)
        let elapsed = max(1, now.timeIntervalSince(month.start))
        let previousStart = DateMath.calendar.date(byAdding: .month, value: -1, to: month.start) ?? month.start
        let current = BudgetMath.byCategory(state, in: DateInterval(start: month.start, duration: elapsed))
        let previous = BudgetMath.byCategory(state, in: DateInterval(start: previousStart, end: min(previousStart.addingTimeInterval(elapsed), month.start)))
        let names = Array(Set(current.map(\.name) + previous.map(\.name)))
        let rows = names.map { name -> CategoryChange in
            let thisMonth = current.first(where: { $0.name == name })
            let lastMonth = previous.first(where: { $0.name == name })
            return CategoryChange(name: name, colorHex: (thisMonth ?? lastMonth)?.colorHex ?? "64748B", current: thisMonth?.amount ?? 0, previous: lastMonth?.amount ?? 0)
        }
        .sorted { abs($0.current - $0.previous) > abs($1.current - $1.previous) }
        if !rows.isEmpty && !previous.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Par rapport au mois dernier"), detail: tr("à la même date"))
                MiniRowsCard {
                    ForEach(Array(rows.prefix(6).enumerated()), id: \.element.id) { index, row in
                        if index > 0 { MiniDivider() }
                        let difference = row.current - row.previous
                        MiniRow(symbol: difference > 0 ? "arrow.up.right" : (difference < 0 ? "arrow.down.right" : "equal"),
                                colorHex: difference > 0 ? Finances.overHex : (difference < 0 ? Finances.incomeHex : "8A8A8E"),
                                title: row.name, detail: "\(TF.money(row.previous, currency)) → \(TF.money(row.current, currency))",
                                value: (difference > 0 ? "+" : difference < 0 ? "−" : "") + TF.money(abs(difference), currency), showsChevron: false)
                    }
                }
            }
        }
    }
}
