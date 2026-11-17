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
    /// The guide of the automatic Apple Pay expenses (the Shortcuts automation).
    case applePay
    /// « Ajouter »: the one sheet for a new expense or a new income (hybrid layout, 2026-11-16).
    case add(isIncome: Bool)
    /// The card of an expense or an income noted, read before it is changed (« Modifier » opens its editor).
    case detailExpense(Expense)
    case detailIncome(IncomeEntry)

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
        case .applePay: "applepay"
        case let .add(isIncome): "add-\(isIncome)"
        case let .detailExpense(expense): "detail-e-\(expense.id.uuidString)"
        case let .detailIncome(income): "detail-i-\(income.id.uuidString)"
        }
    }

    @ViewBuilder
    var editor: some View {
        switch self {
        case let .expense(expense):
            // An expense received from Apple Pay (or with a merchant) teaches Ardane its category when changed.
            if let expense, expense.source == .applePay || expense.merchant != nil || expense.needsReview == true {
                MerchantExpenseEditor(expense: expense)
            } else {
                ExpenseEditor(expense: expense)
            }
        case let .income(income): IncomeEditor(income: income)
        case let .bill(bill): BillEditor(bill: bill)
        case let .goal(goal): GoalEditor(goal: goal)
        case let .account(account): AccountEditor(account: account)
        case let .category(category): CategoryEditor(category: category)
        case let .flow(item): MoneyItemEditor(item: item, isNew: false)
        case .budget: MonthlyBudgetEditor()
        case .opening: OpeningBalanceEditor()
        case .applePay: ApplePayGuideView()
        case let .add(isIncome): FinanceAddSheet(isIncome: isIncome)
        case let .detailExpense(expense): FinanceOperationSheet(expense: expense)
        case let .detailIncome(income): FinanceOperationSheet(income: income)
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

/// The Finances mini-app, top to bottom, as in the hybrid layout the CEO chose on 2026-11-16 (direction 5). On the
/// band: the week selector, then what is left of the month's budget at the end of the chosen day, what that leaves
/// per day, the bar of the budget with the mark of the month's pace, and what is left once the bills still to come
/// are paid. On the page: income, spending and balance in three tiles; what comes back in the next 14 days; the
/// operations of the chosen day; the categories against their pace; then every page in a list that never changes;
/// a note and the settings last. One floating action, « Ajouter », opens the sheet for an expense or an income.
/// The figures of the month follow the chosen day (nothing noted after it counts).
struct FinancesAppView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var sheet: FinanceSheet?
    @State private var day = Date()

    private var currency: String { model.settings.currencyCode }
    private var accentHex: String { Finances.accentHex }
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    /// The moment the month's figures are read at: now for today, the end of the chosen day otherwise.
    private func reference(now: Date) -> Date {
        DateMath.isSameDay(day, now) ? now : DateMath.nextMidnight(after: day).addingTimeInterval(-1)
    }

    var body: some View {
        let now = Date()
        let at = reference(now: now)
        let state = model.budget
        MiniAppScaffold(colorHex: accentHex,
                        action: MiniFloatingAction(title: tr("Ajouter"), symbol: "plus", colorHex: accentHex, identifier: "finances-add") {
                            sheet = .add(isIncome: false)
                        }) {
            // The band: the only date selector (spending is logged, so it stops at today), then the budget left.
            WeekSelector(day: $day, colorHex: accentHex, allowsFuture: false, mark: { dayMark($0, state: state) })
            hero(state: state, now: now)
        } sheet: {
            // The page, by importance: where the month stands, what comes soon, the chosen day, the categories, then
            // every page in the same list each time.
            MiniAppToFillSection(app: .finances)
            Group {
                tiles(state: state, now: now, at: at)
                upcoming(state: state, now: now)
                dayCard(state: state, now: now)
            }
            categories(state: state, now: now)
            pages(state: state)
            MiniFootnote(text: tr("Ardane ne se connecte à aucune banque : tout vient de ce que tu notes. Ce sont des repères, pas des conseils financiers."))
            MiniAppInfoSection(app: .finances)
        }
        .navigationTitle(tr("Finances"))
        .sheet(item: $sheet) { $0.editor }
    }

    // MARK: What is left

    /// The glass card of the band: what is left of the month's budget at the end of the chosen day (the budget minus
    /// the spending from the 1st to that day), what it leaves per day, the bar of the budget with the mark of the
    /// month's pace, and what is left once the bills and fixed expenses still to come this month are paid. Without a
    /// budget given, what was spent and a button to set one (the default 2 000 is not the person's budget).
    private func hero(state: BudgetState, now: Date) -> some View {
        let spent = BudgetMath.spentThisMonth(state, throughDay: day, now: now)
        let remaining = BudgetMath.remaining(state, throughDay: day, now: now)
        let knowsBudget = model.profile.knows(.monthlyBudget)
        let over = knowsBudget && remaining < 0
        let label = !knowsBudget ? tr("Dépensé ce mois-ci") : (over ? tr("Dépassé ce mois-ci") : tr("Reste ce mois-ci"))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(label.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                if knowsBudget { budgetButton(state) }
            }
            if knowsBudget {
                figure(state: state, remaining: remaining, over: over, now: now)
                pace(state: state, spent: spent)
                afterBills(state: state, now: now)
            } else {
                Text(TF.money(spent, currency))
                    .font(.system(size: 54, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(tr("Budget à définir pour savoir ce qu'il te reste"))
                    .font(.subheadline)
                    .opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                budgetButton(state)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cristalGlass(in: RoundedRectangle(cornerRadius: palette.radius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finances-hero")
    }

    /// « Budget 1 200 $ » (or « Définir mon budget »): opens the month's budget.
    private func budgetButton(_ state: BudgetState) -> some View {
        let knowsBudget = model.profile.knows(.monthlyBudget)
        return Button { sheet = .budget } label: {
            Label(knowsBudget ? tr("Budget \(TF.money(state.monthlyBudget, currency))") : tr("Définir mon budget"),
                  systemImage: knowsBudget ? "pencil" : "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(palette.tintColor, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("finances-budget")
    }

    /// The big figure, with what it leaves per day beside it (under it when the text is large).
    private func figure(state: BudgetState, remaining: Double, over: Bool, now: Date) -> some View {
        let amount = Text(TF.money(abs(remaining), currency))
            .font(.system(size: 54, weight: .heavy))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                amount
                perDay(state: state, remaining: remaining, over: over, now: now)
            }
            VStack(alignment: .leading, spacing: 4) {
                amount
                perDay(state: state, remaining: remaining, over: over, now: now)
            }
        }
    }

    /// « 21,68 $ / par jour pendant 19 jours »; on the last day of the month, « dernier jour du mois »; nothing once
    /// the budget is spent.
    @ViewBuilder
    private func perDay(state: BudgetState, remaining: Double, over: Bool, now: Date) -> some View {
        if BudgetMath.daysLeftInMonth(day) <= 1 {
            Text(tr("dernier jour du mois"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .fixedSize()
        } else if !over, remaining > 0 {
            let days = BudgetMath.daysToCover(throughDay: day, now: now)
            VStack(alignment: .leading, spacing: 1) {
                Text(TF.money(BudgetMath.perDayLeft(state, throughDay: day, now: now), currency, decimals: 2))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(tr("par jour pendant \(Fmt.plural(days, tr("jour"), tr("jours")))"))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .fixedSize()
            .accessibilityElement(children: .combine)
        }
    }

    /// The bar of the budget with the mark of the month's pace, and the two figures under it.
    private func pace(state: BudgetState, spent: Double) -> some View {
        let fraction = BudgetMath.monthFraction(throughDay: day)
        let budget = state.monthlyBudget
        let share = budget > 0 ? spent / budget : 0
        let dayNumber = Fmt.firstOfMonth(" " + Fmt.format(day, template: "d") + " ", day).trimmingCharacters(in: .whitespaces)
        return VStack(alignment: .leading, spacing: 6) {
            FinancesPaceBar(spent: spent, budget: budget, fraction: fraction)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(tr("\(TF.money(spent, currency)) dépensés · \(Fmt.percent(share))"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                Text(tr("repère du \(dayNumber) : \(TF.money(budget * fraction, currency))"))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption.monospacedDigit())
        }
    }

    /// « Après les factures à venir : 218 $, soit 11,47 $ par jour »: what is left once the bills and fixed expenses
    /// still to come this month are paid. Nothing when none is left to pay.
    @ViewBuilder
    private func afterBills(state: BudgetState, now: Date) -> some View {
        if BudgetMath.dueRestOfMonth(state, afterDay: day) > 0 {
            let after = BudgetMath.leftAfterDue(state, throughDay: day, now: now)
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                Text(after.left >= 0
                     ? tr("Après les factures à venir : \(TF.money(after.left, currency)), soit \(TF.money(after.perDay, currency, decimals: 2)) par jour")
                     : tr("Les factures à venir dépassent le reste de \(TF.money(-after.left, currency))"))
                    .font(.footnote)
                    .foregroundStyle(after.left >= 0 ? Color.secondary : palette.strong(Finances.overHex))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("finances-after-bills")
        }
    }

    // MARK: The month in three tiles

    /// What came in, what went out and the balance, at the end of the chosen day. Income and spending open
    /// « Revenus et dépenses », the balance opens « Opérations et relevé » (with its chart).
    private func tiles(state: BudgetState, now: Date, at: Date) -> some View {
        let earned = BudgetMath.earned(state, throughDay: day, now: now)
        let expected = model.profile.monthlyIncome
        let spent = BudgetMath.spentThisMonth(state, throughDay: day, now: now)
        let comparison = BudgetMath.monthToDate(state, at: at)
        let balance = balanceAtDay(state, now: now)
        let isToday = DateMath.isSameDay(day, now)
        let incomeValue = earned > 0 ? "+" + TF.money(earned, currency) : TF.money(expected ?? 0, currency)
        return HStack(alignment: .top, spacing: 8) {
            NavigationLink(value: HomeRoute.page(.financesMonth)) {
                FinancesFigureTile(symbol: "arrow.down.left", title: tr("Revenus"), value: incomeValue,
                                   detail: earned > 0 || expected == nil ? tr("ce mois-ci") : tr("prévus"),
                                   valueHex: earned > 0 ? Finances.incomeHex : nil)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("finances-kpi-income")
            NavigationLink(value: HomeRoute.page(.financesMonth)) {
                FinancesFigureTile(symbol: "arrow.up.right", title: tr("Dépenses"),
                                   value: (spent > 0 ? "−" : "") + TF.money(spent, currency),
                                   detail: comparisonText(comparison, at: at))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("finances-kpi-spent")
            NavigationLink(value: HomeRoute.page(.financesTransactions)) {
                FinancesFigureTile(symbol: "creditcard", title: tr("Solde"),
                                   value: (balance < 0 ? "−" : "") + TF.money(abs(balance), currency),
                                   detail: isToday ? tr("aujourd'hui") : Fmt.format(day, template: "dMMM"),
                                   valueHex: balance < 0 ? Finances.overHex : nil)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("finances-kpi-balance")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("finances-balance")
    }

    /// « −96 $ vs oct. »: this month's spending against last month up to the same moment; « ce mois-ci » otherwise.
    private func comparisonText(_ comparison: (current: Double, previous: Double), at: Date) -> String {
        let difference = comparison.current - comparison.previous
        guard comparison.previous > 0, abs(difference) >= 1 else { return tr("ce mois-ci") }
        let lastMonth = DateMath.calendar.date(byAdding: .month, value: -1, to: at) ?? at
        let amount = (difference > 0 ? "+" : "−") + TF.money(abs(difference), currency)
        return tr("\(amount) vs \(Fmt.format(lastMonth, template: "MMM"))")
    }

    /// The balance at the end of the chosen day, counted as on the chart of « Opérations et relevé » (from the
    /// « Solde de départ » when there is one, otherwise from the start of the month).
    private func balanceAtDay(_ state: BudgetState, now: Date) -> Double {
        let points = BudgetMath.balanceHistory(state, from: BudgetMath.monthInterval(day).start, now: now)
        return points.last(where: { DateMath.startOfDay($0.date) <= DateMath.startOfDay(day) })?.balance ?? points.last?.balance ?? 0
    }

    // MARK: What comes soon

    /// The bills and fixed amounts of the next 14 days (three at most), the total of what will go out, and a link to
    /// « Budget et récurrents ». A tap opens the bill or the fixed amount to change it.
    private func upcoming(state: BudgetState, now: Date) -> some View {
        let items = BudgetMath.upcoming(state, at: now, within: 14)
        let total = items.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("À venir"), detail: total > 0 ? tr("\(TF.money(total, currency, decimals: 2)) en 14 jours") : nil)
            MiniRowsCard {
                if items.isEmpty {
                    Text(tr("Rien à payer dans les 14 prochains jours"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                        if index > 0 { MiniDivider() }
                        Button { open(item) } label: { FinancesDueRow(item: item, now: now, currency: currency) }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("finances-upcoming-row")
                    }
                }
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesBills)) {
                    linkRow(items.count > 3 ? tr("Les \(items.count) échéances") : tr("Tout voir"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-upcoming")
            }
        }
    }

    /// A bill opens its editor; a fixed income or expense opens the one of « Revenus et dépenses fixes ».
    private func open(_ item: BudgetMath.UpcomingItem) {
        switch item.source {
        case let .bill(bill):
            sheet = .bill(bill)
        case let .fixed(flow):
            sheet = .flow(model.content.money.items.first(where: { $0.id == flow.id }) ?? flow)
        }
    }

    // MARK: The day

    /// The operations of the chosen day (the fixed payments of that day included), with the day's total; a tap
    /// opens one to read it (a fixed payment opens the bill or the fixed amount behind it).
    private func dayCard(state: BudgetState, now: Date) -> some View {
        let interval = DateInterval(start: DateMath.startOfDay(day), end: DateMath.nextMidnight(after: day))
        let expenses = BudgetMath.expenses(state, in: interval, now: now).sorted { $0.date > $1.date }
        let incomes = BudgetMath.incomes(state, in: interval, now: now).sorted { $0.date > $1.date }
        let spent = expenses.reduce(0) { $0 + $1.amount }
        let earned = incomes.reduce(0) { $0 + $1.amount }
        let totals = [spent > 0 ? "−" + TF.money(spent, currency, decimals: 2) : nil,
                      earned > 0 ? "+" + TF.money(earned, currency, decimals: 2) : nil].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: DateMath.isSameDay(day, now) ? tr("Aujourd'hui") : Fmt.longDay(day).capitalizedFirst,
                             detail: totals.isEmpty ? nil : totals.joined(separator: " · "))
            MiniRowsCard {
                if expenses.isEmpty && incomes.isEmpty {
                    Text(tr("Aucune opération ce jour-là."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
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
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesTransactions)) { linkRow(tr("Tout voir")) }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("finances-day-all")
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
                           value: Fmt.signedMoney(-expense.amount, currency: currency),
                           isApplePay: expense.source == .applePay, needsReview: expense.needsReview == true)
    }

    private func incomeRow(_ income: IncomeEntry) -> some View {
        FinancesRow(symbol: "arrow.down.left", colorHex: Finances.incomeHex, title: income.label.isEmpty ? tr("Revenu") : income.label,
                    detail: income.fixedID == nil ? tr("Revenu") : tr("Revenu fixe"),
                    value: Fmt.signedMoney(income.amount, currency: currency))
    }

    /// An expense or an income opens its card; a payment of a bill or of a fixed amount opens where it comes from.
    private func open(_ expense: Expense, state: BudgetState) {
        sheet = expense.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .detailExpense(expense)
    }

    private func open(_ income: IncomeEntry, state: BudgetState) {
        sheet = income.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .detailIncome(income)
    }

    /// A day with at least one operation (noted or fixed) is marked on the selector.
    private func dayMark(_ date: Date, state: BudgetState) -> WeekDayMark {
        let interval = DateInterval(start: DateMath.startOfDay(date), end: DateMath.nextMidnight(after: date))
        let now = Date()
        let holdsSomething = !BudgetMath.expenses(state, in: interval, now: now).isEmpty
            || !BudgetMath.incomes(state, in: interval, now: now).isEmpty
        return WeekDayMark(isPlanned: holdsSomething)
    }

    // MARK: Categories

    /// The three categories that spent the most this month (or, before any spending, the first three with a limit),
    /// each against the mark of the month's pace; one clearly ahead of it, or over its limit, says so in words.
    private func categories(state: BudgetState, now: Date) -> some View {
        let all = BudgetMath.categoryStatus(state, throughDay: day, now: now)
        let spending = all.filter { $0.spent > 0 }
        let shown = Array((spending.isEmpty ? all.filter { $0.limit > 0 } : spending).prefix(3))
        let fraction = BudgetMath.monthFraction(throughDay: day)
        let days = BudgetMath.daysToCover(throughDay: day, now: now)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Catégories"), detail: Fmt.monthYear(day).capitalizedFirst)
            VStack(spacing: 12) {
                ForEach(shown) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        CategoryBar(status: item, currency: currency, pace: fraction)
                        if item.isOver {
                            Text(tr("Dépassé de \(TF.money(item.spent - item.limit, currency))"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.strong(Finances.overHex))
                        } else if BudgetMath.isAheadOfPace(item, fraction: fraction) {
                            Text(tr("Au-dessus du rythme · \(TF.money(item.limit - item.spent, currency)) pour \(Fmt.plural(days, tr("jour"), tr("jours")))"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if !shown.isEmpty { Divider() }
                NavigationLink(value: HomeRoute.page(.financesCategories)) {
                    linkRow(tr("Les \(state.categories.count) catégories"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-categories")
            }
            .padding(.horizontal, 14)
            .padding(.top, shown.isEmpty ? 2 : 14)
            .padding(.bottom, 2)
            .miniCard()
        }
    }

    // MARK: Every page

    /// Every page of Finances, always the same five lines in the same order, whatever is noted.
    private func pages(state: BudgetState) -> some View {
        let recurring = BudgetMath.billsMonthly(state) + BudgetMath.fixedExpensesMonthly(state)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Tout Finance"))
            MiniRowsCard {
                NavigationLink(value: HomeRoute.page(.financesTransactions)) {
                    FinancesRow(symbol: "list.bullet.rectangle", colorHex: accentHex, title: tr("Opérations et relevé"),
                                detail: tr("Solde après chaque opération"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-transactions")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesBills)) {
                    FinancesRow(symbol: "repeat", colorHex: "D6409F", title: tr("Budget et récurrents"),
                                detail: recurring > 0 ? tr("\(TF.money(recurring, currency)) reviennent chaque mois") : tr("Loyer, Internet, abonnements…"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-bills")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesSavings)) {
                    FinancesRow(symbol: "banknote.fill", colorHex: Finances.incomeHex, title: tr("Épargne et comptes"),
                                detail: state.accounts.isEmpty ? tr("Objectifs et valeur nette") : tr("Valeur nette \(TF.money(BudgetMath.netWorth(state), currency))"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-savings")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.financesTrends)) {
                    FinancesRow(symbol: "chart.bar.xaxis", colorHex: "3366FF", title: tr("Analyse"),
                                detail: tr("Comparaisons, six mois, constats"), showsPremium: !model.isPremium)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-trends")
                MiniDivider()
                Button { sheet = .applePay } label: {
                    FinancesRow(symbol: "wave.3.right.circle", colorHex: ApplePayStatus.hex, title: tr("Dépenses Apple Pay automatiques"),
                                detail: ApplePayStatus.subtitle(state))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("finances-applepay")
            }
        }
    }

    /// A link at the bottom of a card: the words in the action color, a chevron.
    private func linkRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// One of the three tiles under the band: an icon and a title, the figure, a short line under it.
private struct FinancesFigureTile: View {
    let symbol: String
    let title: String
    let value: String
    var detail: String?
    var valueHex: String?
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(valueHex.map { palette.strong($0) } ?? Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .padding(12)
        .miniTile()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Shared pieces

/// A row of the Signature style: an icon in a tinted rounded square, a title, a detail, a value and a chevron.
struct FinancesRow: View {
    @Environment(\.appStyle) private var style
    let symbol: String
    let colorHex: String
    let title: String
    var detail: String?
    var value: String?
    var showsChevron = true
    /// An expense received through the Apple Pay automation, and one whose category is still to check.
    var isApplePay = false
    var needsReview = false
    /// A page reserved to Premium, for an account without it: the golden « Premium » badge before the chevron.
    var showsPremium = false

    var body: some View {
        let tint = CristalPalette.of(style.id).category(colorHex)
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isApplePay { ApplePayMark() }
                    if needsReview { ReviewBadge() }
                }
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
            if showsPremium { PremiumBadge() }
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
    @Environment(\.appStyle) private var style
    let status: BudgetMath.CategoryStatus
    let currency: String
    /// The share of the month gone by: a thin mark on the bar shows where the spending would be at an even pace.
    var pace: Double? = nil

    var body: some View {
        let palette = CristalPalette.of(style.id)
        let hex = status.category.colorHex
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: status.category.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.category(hex))
                    .frame(width: 18)
                Text(status.category.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Spacer()
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(status.isOver ? palette.strong(Finances.overHex) : Color.primary)
                    .monospacedDigit()
            }
            if let ratio = status.ratio {
                ProgressView(value: min(1, ratio))
                    .accessibilityLabel(tr("Progression"))
                    .accessibilityValue(Fmt.percent(min(1, ratio)))
                    .tint(status.isOver ? palette.category(Finances.overHex) : palette.category(hex))
                    .overlay {
                        if let pace {
                            GeometryReader { proxy in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.primary.opacity(0.55))
                                    .frame(width: 2, height: 12)
                                    .position(x: min(max(1, proxy.size.width * min(1, pace)), proxy.size.width - 1), y: proxy.size.height / 2)
                            }
                            .accessibilityHidden(true)
                        }
                    }
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
    @Environment(\.appStyle) private var style
    let goal: SavingsGoal
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Spacer()
                Text(Fmt.percent(goal.progress)).font(.subheadline.weight(.bold)).foregroundStyle(CristalPalette.of(style.id).strong(Finances.incomeHex)).monospacedDigit()
            }
            ProgressView(value: goal.progress).tint(CristalPalette.of(style.id).category(Finances.incomeHex))
                .accessibilityLabel(goal.name)
                .accessibilityValue(Fmt.percent(goal.progress))
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
struct BalanceChartCard: View {
    @Environment(\.appStyle) private var style
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
        let color = CristalPalette.of(style.id).category(balance < 0 ? Finances.overHex : Finances.incomeHex)
        let dayFormat: Date.FormatStyle = period == .month ? .dateTime.day().month(.abbreviated) : .dateTime.month(.abbreviated)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // The card heads « Opérations et relevé », where the statement itself is: no link to the same page.
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
                .accessibilityElement(children: .combine)
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
            chart(points, color: color, dayFormat: dayFormat)
            if !isPremium {
                // The lock is said, not discovered by touching the segment.
                Label(tr("3 mois et Année avec Premium"), systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(caption(points))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onEditOpening) {
                Label(state.openingBalance == nil ? tr("Ajouter ton solde de départ") : tr("Modifier le solde de départ"),
                      systemImage: state.openingBalance == nil ? "plus.circle.fill" : "pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
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
        .accessibilityLabel(tr("Solde"))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(CristalPalette.of(style.id).gridColor)
                AxisValueLabel(format: dayFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(CristalPalette.of(style.id).gridColor)
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
