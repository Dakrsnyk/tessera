import SwiftUI

struct BudgetSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let now = Date()
        let state = model.budget
        let month = BudgetMath.monthInterval(now)
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(TF.money(BudgetMath.remaining(state, at: now), currency))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(tr("restent ce mois-ci, soit \(TF.money(BudgetMath.perDayLeft(state, at: now), currency)) par jour"))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                ProgressView(value: min(1, BudgetMath.spentThisMonth(state, at: now) / max(1, state.monthlyBudget)))
                    .tint(Color(hex: "2F8F7A"))
            }
            .padding(.vertical, 4)
            NumberRow(title: tr("Budget du mois"), value: Binding(get: { state.monthlyBudget }, set: { value in model.setMonthlyBudget(value) }), unit: currency)
            Button {
                sheets?.open { ExpenseEditor() }
            } label: {
                Label(tr("Noter une dépense"), systemImage: "plus.circle.fill").font(.headline)
            }
        } header: {
            Text(Fmt.monthYear(now))
        }

        Section(tr("Dépenses du mois")) {
            let expenses = BudgetMath.expenses(state, in: month).sorted { $0.date > $1.date }
            ForEach(expenses.prefix(40)) { expense in
                let category = state.category(expense.categoryID)
                HStack {
                    Image(systemName: category?.symbol ?? "square.grid.2x2")
                        .foregroundStyle(Color(hex: category?.colorHex ?? "64748B"))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(expense.note.isEmpty ? (category?.name ?? tr("Dépense")) : expense.note)
                        Text(Fmt.shortDay(expense.date)).font(.caption).foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    Text(TF.money(expense.amount, currency, decimals: 2)).monospacedDigit()
                }
                .swipeActions {
                    Button(role: .destructive) {
                        model.update(\.budget) { $0.expenses.removeAll { $0.id == expense.id } }
                    } label: {
                        Label(tr("Supprimer"), systemImage: "trash")
                    }
                }
            }
            if expenses.isEmpty {
                HintRow(text: tr("Aucune dépense notée ce mois-ci."))
            }
        }

        Section {
            ForEach(state.quickExpenses) { quick in
                Button {
                    sheets?.open { QuickExpenseEditor(quick: quick) }
                } label: {
                    ValueRow(title: quick.name, value: TF.money(quick.amount, currency, decimals: 2), symbol: quick.symbol)
                }
                .tint(.primary)
            }
            .onDelete { offsets in model.update(\.budget) { $0.quickExpenses.remove(atOffsets: offsets) } }
            Button {
                sheets?.open { QuickExpenseEditor(quick: QuickExpense(name: "", amount: 5, categoryID: BudgetState.fixedID(2))) }
            } label: {
                Label(tr("Nouvelle dépense rapide"), systemImage: "plus")
            }
        } header: {
            Text(tr("Dépenses rapides"))
        } footer: {
            Text(tr("Café, bus, lunch… Le widget Dépense rapide les note d'une touche."))
        }

        Section(tr("Factures et abonnements")) {
            ForEach(BudgetMath.upcomingBills(state, at: now, within: 400)) { item in
                Button {
                    sheets?.open { BillEditor(bill: item.bill) }
                } label: {
                    HStack {
                        Image(systemName: item.bill.symbol).frame(width: 22).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.bill.name).foregroundStyle(Color.primary)
                            Text("\(item.bill.isSubscription ? tr("Abonnement · ") : "")\(Fmt.shortDay(item.due))").font(.caption).foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        Text(TF.money(item.bill.amount, currency, decimals: 2)).foregroundStyle(Color.secondary).monospacedDigit()
                    }
                }
            }
            Button {
                sheets?.open { BillEditor(bill: Bill(name: "", amount: 0, anchorDate: Date())) }
            } label: {
                Label(tr("Nouvelle facture"), systemImage: "plus")
            }
            if !state.bills.isEmpty {
                ValueRow(title: tr("Abonnements"), value: tr("\(TF.money(BudgetMath.subscriptionsMonthly(state), currency, decimals: 2)) / mois"), symbol: "repeat.circle")
            }
        }

        Section(tr("Épargne")) {
            ForEach(state.goals) { goal in
                Button {
                    sheets?.open { GoalEditor(goal: goal) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.name).foregroundStyle(Color.primary)
                            Spacer()
                            Text("\(TF.money(goal.saved, currency)) / \(TF.money(goal.target, currency))").foregroundStyle(Color.secondary).monospacedDigit()
                        }
                        ProgressView(value: goal.progress)
                    }
                }
            }
            .onDelete { offsets in model.update(\.budget) { $0.goals.remove(atOffsets: offsets) } }
            Button {
                sheets?.open { GoalEditor(goal: SavingsGoal(name: "", target: 1_000, saved: 0, deadline: nil)) }
            } label: {
                Label(tr("Nouvel objectif"), systemImage: "plus")
            }
        }

        Section {
            ForEach(state.accounts) { account in
                Button {
                    sheets?.open { AccountEditor(account: account) }
                } label: {
                    ValueRow(title: account.name, value: (account.isLiability ? "−" : "") + TF.money(account.balance, currency), symbol: account.isLiability ? "creditcard" : "building.columns")
                }
                .tint(.primary)
            }
            .onDelete { offsets in model.update(\.budget) { $0.accounts.remove(atOffsets: offsets) } }
            Button {
                sheets?.open { AccountEditor(account: Account(name: "", balance: 0)) }
            } label: {
                Label(tr("Nouveau compte ou dette"), systemImage: "plus")
            }
            if !state.accounts.isEmpty {
                ValueRow(title: tr("Valeur nette"), value: TF.money(BudgetMath.netWorth(state), currency), symbol: "sum")
            }
        } header: {
            Text(tr("Comptes"))
        } footer: {
            Text(tr("Saisis tes soldes à la main : Tessera ne se connecte à aucune banque."))
        }

        Section(tr("Catégories")) {
            ForEach(state.categories) { category in
                Button {
                    sheets?.open { CategoryEditor(category: category) }
                } label: {
                    ValueRow(title: category.name, value: category.monthlyLimit > 0 ? tr("\(TF.money(category.monthlyLimit, currency)) / mois") : tr("Sans limite"), symbol: category.symbol, colorHex: category.colorHex)
                }
                .tint(.primary)
            }
            Button {
                sheets?.open { CategoryEditor(category: BudgetCategory(name: "", symbol: "tag", colorHex: "3366FF")) }
            } label: {
                Label(tr("Nouvelle catégorie"), systemImage: "plus")
            }
        }
    }
}

extension BudgetMath.UpcomingBill: Identifiable {
    var id: UUID { bill.id }
}

struct ExpenseEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var expense: Expense
    private let isNew: Bool

    /// A new expense, or an existing one to change or delete.
    init(expense: Expense? = nil, categoryID: UUID? = nil) {
        _expense = State(initialValue: expense ?? Expense(amount: 0, categoryID: categoryID ?? BudgetState.fixedID(1)))
        isNew = expense == nil
    }

    var body: some View {
        SheetForm(title: isNew ? tr("Dépense") : tr("Modifier la dépense"), canSave: expense.amount > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Montant"), value: $expense.amount, unit: model.settings.currencyCode)
                    .accessibilityIdentifier("expense-amount")
                Picker(tr("Catégorie"), selection: $expense.categoryID) {
                    ForEach(model.budget.categories) { category in
                        Label(category.name, systemImage: category.symbol).tag(Optional(category.id))
                    }
                }
                TextField(tr("Note (facultatif)"), text: $expense.note)
                DatePicker(tr("Date"), selection: $expense.date, displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
            }
            if !isNew {
                Section {
                    Button(tr("Supprimer la dépense"), role: .destructive) {
                        let id = expense.id
                        model.update(\.budget) { $0.expenses.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        var saved = expense
        saved.note = saved.note.trimmed
        model.update(\.budget) { $0.save(saved) }
        Haptics.success()
    }
}

/// Money coming in: a pay, a contract, a refund.
struct IncomeEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var income: IncomeEntry
    private let isNew: Bool

    init(income: IncomeEntry? = nil) {
        _income = State(initialValue: income ?? IncomeEntry(amount: 0))
        isNew = income == nil
    }

    var body: some View {
        SheetForm(title: isNew ? tr("Revenu") : tr("Modifier le revenu"), canSave: income.amount > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Montant"), value: $income.amount, unit: model.settings.currencyCode)
                TextField(tr("Source (salaire, contrat, remboursement…)"), text: $income.label)
                DatePicker(tr("Date"), selection: $income.date, displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
            }
            if !isNew {
                Section {
                    Button(tr("Supprimer le revenu"), role: .destructive) {
                        let id = income.id
                        model.update(\.budget) { $0.incomes.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        var saved = income
        saved.label = saved.label.trimmed.isEmpty ? tr("Revenu") : saved.label.trimmed
        model.update(\.budget) { $0.save(saved) }
        Haptics.success()
    }
}

struct QuickExpenseEditor: View {
    @Environment(AppModel.self) private var model
    @State var quick: QuickExpense

    private let symbols = ["cup.and.saucer.fill", "bus.fill", "takeoutbag.and.cup.and.straw.fill", "cart.fill", "fuelpump.fill", "parkingsign.circle.fill", "gift.fill", "tram.fill"]

    var body: some View {
        SheetForm(title: tr("Dépense rapide"), canSave: !quick.name.trimmed.isEmpty && quick.amount > 0, onSave: save) {
            TextField(tr("Nom (café, bus…)"), text: $quick.name)
            NumberRow(title: tr("Montant"), value: $quick.amount, unit: model.settings.currencyCode)
            Picker(tr("Catégorie"), selection: $quick.categoryID) {
                ForEach(model.budget.categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            Picker(tr("Icône"), selection: $quick.symbol) {
                ForEach(symbols, id: \.self) { Image(systemName: $0).tag($0) }
            }
        }
    }

    private func save() {
        var saved = quick
        saved.name = saved.name.trimmed
        model.update(\.budget) { state in
            if let index = state.quickExpenses.firstIndex(where: { $0.id == saved.id }) {
                state.quickExpenses[index] = saved
            } else {
                state.quickExpenses.append(saved)
            }
        }
    }
}

struct BillEditor: View {
    @Environment(AppModel.self) private var model
    @State var bill: Bill

    var body: some View {
        SheetForm(title: tr("Facture"), canSave: !bill.name.trimmed.isEmpty && bill.amount > 0, onSave: save) {
            TextField(tr("Nom (loyer, Hydro, Netflix…)"), text: $bill.name)
            NumberRow(title: tr("Montant"), value: $bill.amount, unit: model.settings.currencyCode)
            Picker(tr("Fréquence"), selection: $bill.period) {
                ForEach(BillPeriod.allCases) { Text($0.title).tag($0) }
            }
            DatePicker(tr("Prochaine échéance"), selection: $bill.anchorDate, displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
            Toggle(tr("C'est un abonnement"), isOn: $bill.isSubscription)
        }
    }

    private func save() {
        var saved = bill
        saved.name = saved.name.trimmed
        saved.symbol = saved.isSubscription ? "repeat.circle.fill" : (saved.symbol == "repeat.circle.fill" ? "doc.text" : saved.symbol)
        model.update(\.budget) { state in
            if let index = state.bills.firstIndex(where: { $0.id == saved.id }) {
                state.bills[index] = saved
            } else {
                state.bills.append(saved)
            }
        }
    }
}

struct GoalEditor: View {
    @Environment(AppModel.self) private var model
    @State var goal: SavingsGoal
    @State private var deposit: Double = 0

    var body: some View {
        SheetForm(title: tr("Objectif d'épargne"), canSave: !goal.name.trimmed.isEmpty && goal.target > 0, onSave: save) {
            Section {
                TextField(tr("Nom (voyage, fonds d'urgence…)"), text: $goal.name)
                NumberRow(title: tr("Objectif"), value: $goal.target, unit: model.settings.currencyCode)
                NumberRow(title: tr("Déjà épargné"), value: $goal.saved, unit: model.settings.currencyCode)
                Toggle(tr("Date limite"), isOn: Binding(get: { goal.deadline != nil }, set: { goal.deadline = $0 ? (goal.deadline ?? Date().addingTimeInterval(180 * 86_400)) : nil }))
                if goal.deadline != nil {
                    DatePicker(tr("Pour le"), selection: Binding(get: { goal.deadline ?? Date() }, set: { goal.deadline = $0 }), displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }
            }
            Section(tr("Ajouter un versement")) {
                NumberRow(title: tr("Montant"), value: $deposit, unit: model.settings.currencyCode)
                Button(tr("Ajouter au montant épargné")) {
                    goal.saved += deposit
                    deposit = 0
                }
                .disabled(deposit <= 0)
            }
        }
    }

    private func save() {
        var saved = goal
        saved.name = saved.name.trimmed
        model.update(\.budget) { state in
            if let index = state.goals.firstIndex(where: { $0.id == saved.id }) {
                state.goals[index] = saved
            } else {
                state.goals.append(saved)
            }
        }
    }
}

struct AccountEditor: View {
    @Environment(AppModel.self) private var model
    @State var account: Account

    var body: some View {
        SheetForm(title: tr("Compte"), canSave: !account.name.trimmed.isEmpty, onSave: save) {
            TextField(tr("Nom (compte chèque, CELI, prêt auto…)"), text: $account.name)
            NumberRow(title: tr("Solde"), value: $account.balance, unit: model.settings.currencyCode)
            Toggle(tr("C'est une dette"), isOn: $account.isLiability)
        }
    }

    private func save() {
        var saved = account
        saved.name = saved.name.trimmed
        model.update(\.budget) { state in
            if let index = state.accounts.firstIndex(where: { $0.id == saved.id }) {
                state.accounts[index] = saved
            } else {
                state.accounts.append(saved)
            }
            state.snapshotNetWorth()
        }
    }
}

struct CategoryEditor: View {
    @Environment(AppModel.self) private var model
    @State var category: BudgetCategory

    private let symbols = ["cart", "fork.knife", "bus", "ticket", "house", "square.grid.2x2", "tag", "heart", "gamecontroller", "tshirt", "pawprint", "graduationcap", "cross.case", "gift"]

    var body: some View {
        SheetForm(title: tr("Catégorie"), canSave: !category.name.trimmed.isEmpty, onSave: save) {
            TextField(tr("Nom"), text: $category.name)
            Picker(tr("Icône"), selection: $category.symbol) {
                ForEach(symbols, id: \.self) { Image(systemName: $0).tag($0) }
            }
            ColorChoiceRow(hex: $category.colorHex)
            NumberRow(title: tr("Limite par mois"), value: $category.monthlyLimit, unit: model.settings.currencyCode)
        }
    }

    private func save() {
        var saved = category
        saved.name = saved.name.trimmed
        model.update(\.budget) { state in
            if let index = state.categories.firstIndex(where: { $0.id == saved.id }) {
                state.categories[index] = saved
            } else {
                state.categories.append(saved)
            }
        }
    }
}
