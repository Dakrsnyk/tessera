import SwiftUI

struct BudgetSpaceSections: View {
    @Environment(AppModel.self) private var model
    @State private var showsExpense = false
    @State private var editingQuick: QuickExpense?
    @State private var editingBill: Bill?
    @State private var editingGoal: SavingsGoal?
    @State private var editingAccount: Account?
    @State private var editingCategory: BudgetCategory?

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
                Text("restent ce mois-ci, soit \(TF.money(BudgetMath.perDayLeft(state, at: now), currency)) par jour")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: min(1, BudgetMath.spentThisMonth(state, at: now) / max(1, state.monthlyBudget)))
                    .tint(Color(hex: "2F8F7A"))
            }
            .padding(.vertical, 4)
            NumberRow(title: "Budget du mois", value: Binding(get: { state.monthlyBudget }, set: { value in model.update(\.budget) { $0.monthlyBudget = max(0, value) } }), unit: currency)
            Button {
                showsExpense = true
            } label: {
                Label("Noter une dépense", systemImage: "plus.circle.fill").font(.headline)
            }
        } header: {
            Text(Fmt.monthYear(now))
        }
        .sheet(isPresented: $showsExpense) { ExpenseEditor() }
        .sheet(item: $editingQuick) { QuickExpenseEditor(quick: $0) }
        .sheet(item: $editingBill) { BillEditor(bill: $0) }
        .sheet(item: $editingGoal) { GoalEditor(goal: $0) }
        .sheet(item: $editingAccount) { AccountEditor(account: $0) }
        .sheet(item: $editingCategory) { CategoryEditor(category: $0) }

        Section("Dépenses du mois") {
            let expenses = BudgetMath.expenses(state, in: month).sorted { $0.date > $1.date }
            ForEach(expenses.prefix(40)) { expense in
                let category = state.category(expense.categoryID)
                HStack {
                    Image(systemName: category?.symbol ?? "square.grid.2x2")
                        .foregroundStyle(Color(hex: category?.colorHex ?? "64748B"))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(expense.note.isEmpty ? (category?.name ?? "Dépense") : expense.note)
                        Text(Fmt.shortDay(expense.date)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(TF.money(expense.amount, currency, decimals: 2)).monospacedDigit()
                }
                .swipeActions {
                    Button(role: .destructive) {
                        model.update(\.budget) { $0.expenses.removeAll { $0.id == expense.id } }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
            if expenses.isEmpty {
                HintRow(text: "Aucune dépense notée ce mois-ci.")
            }
        }

        Section {
            ForEach(state.quickExpenses) { quick in
                Button {
                    editingQuick = quick
                } label: {
                    ValueRow(title: quick.name, value: TF.money(quick.amount, currency, decimals: 2), symbol: quick.symbol)
                }
                .tint(.primary)
            }
            .onDelete { offsets in model.update(\.budget) { $0.quickExpenses.remove(atOffsets: offsets) } }
            Button {
                editingQuick = QuickExpense(name: "", amount: 5, categoryID: BudgetState.fixedID(2))
            } label: {
                Label("Nouvelle dépense rapide", systemImage: "plus")
            }
        } header: {
            Text("Dépenses rapides")
        } footer: {
            Text("Café, bus, lunch… Le widget Dépense rapide les note d'une touche.")
        }

        Section("Factures et abonnements") {
            ForEach(BudgetMath.upcomingBills(state, at: now, within: 400)) { item in
                Button {
                    editingBill = item.bill
                } label: {
                    HStack {
                        Image(systemName: item.bill.symbol).frame(width: 22).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.bill.name).foregroundStyle(.primary)
                            Text("\(item.bill.isSubscription ? "Abonnement · " : "")\(Fmt.shortDay(item.due))").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(TF.money(item.bill.amount, currency, decimals: 2)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
            Button {
                editingBill = Bill(name: "", amount: 0, anchorDate: Date())
            } label: {
                Label("Nouvelle facture", systemImage: "plus")
            }
            if !state.bills.isEmpty {
                ValueRow(title: "Abonnements", value: "\(TF.money(BudgetMath.subscriptionsMonthly(state), currency, decimals: 2)) / mois", symbol: "repeat.circle")
            }
        }

        Section("Épargne") {
            ForEach(state.goals) { goal in
                Button {
                    editingGoal = goal
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.name).foregroundStyle(.primary)
                            Spacer()
                            Text("\(TF.money(goal.saved, currency)) / \(TF.money(goal.target, currency))").foregroundStyle(.secondary).monospacedDigit()
                        }
                        ProgressView(value: goal.progress)
                    }
                }
            }
            .onDelete { offsets in model.update(\.budget) { $0.goals.remove(atOffsets: offsets) } }
            Button {
                editingGoal = SavingsGoal(name: "", target: 1_000, saved: 0, deadline: nil)
            } label: {
                Label("Nouvel objectif", systemImage: "plus")
            }
        }

        Section {
            ForEach(state.accounts) { account in
                Button {
                    editingAccount = account
                } label: {
                    ValueRow(title: account.name, value: (account.isLiability ? "−" : "") + TF.money(account.balance, currency), symbol: account.isLiability ? "creditcard" : "building.columns")
                }
                .tint(.primary)
            }
            .onDelete { offsets in model.update(\.budget) { $0.accounts.remove(atOffsets: offsets) } }
            Button {
                editingAccount = Account(name: "", balance: 0)
            } label: {
                Label("Nouveau compte ou dette", systemImage: "plus")
            }
            if !state.accounts.isEmpty {
                ValueRow(title: "Valeur nette", value: TF.money(BudgetMath.netWorth(state), currency), symbol: "sum")
            }
        } header: {
            Text("Comptes")
        } footer: {
            Text("Saisis tes soldes à la main : Tessera ne se connecte à aucune banque.")
        }

        Section("Catégories") {
            ForEach(state.categories) { category in
                Button {
                    editingCategory = category
                } label: {
                    ValueRow(title: category.name, value: category.monthlyLimit > 0 ? "\(TF.money(category.monthlyLimit, currency)) / mois" : "Sans limite", symbol: category.symbol, colorHex: category.colorHex)
                }
                .tint(.primary)
            }
            Button {
                editingCategory = BudgetCategory(name: "", symbol: "tag", colorHex: "3366FF")
            } label: {
                Label("Nouvelle catégorie", systemImage: "plus")
            }
        }
    }
}

extension BudgetMath.UpcomingBill: Identifiable {
    var id: UUID { bill.id }
}

struct ExpenseEditor: View {
    @Environment(AppModel.self) private var model
    @State private var amount: Double = 0
    @State private var categoryID: UUID? = BudgetState.fixedID(1)
    @State private var note = ""
    @State private var date = Date()

    var body: some View {
        SheetForm(title: "Dépense", canSave: amount > 0, onSave: save) {
            NumberRow(title: "Montant", value: $amount, unit: model.settings.currencyCode)
            Picker("Catégorie", selection: $categoryID) {
                ForEach(model.budget.categories) { category in
                    Label(category.name, systemImage: category.symbol).tag(Optional(category.id))
                }
            }
            TextField("Note (facultatif)", text: $note)
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
        }
    }

    private func save() {
        let expense = Expense(amount: amount, categoryID: categoryID, note: note.trimmed, date: date)
        model.update(\.budget) { $0.add(expense) }
        Haptics.success()
    }
}

struct QuickExpenseEditor: View {
    @Environment(AppModel.self) private var model
    @State var quick: QuickExpense

    private let symbols = ["cup.and.saucer.fill", "bus.fill", "takeoutbag.and.cup.and.straw.fill", "cart.fill", "fuelpump.fill", "parkingsign.circle.fill", "gift.fill", "tram.fill"]

    var body: some View {
        SheetForm(title: "Dépense rapide", canSave: !quick.name.trimmed.isEmpty && quick.amount > 0, onSave: save) {
            TextField("Nom (café, bus…)", text: $quick.name)
            NumberRow(title: "Montant", value: $quick.amount, unit: model.settings.currencyCode)
            Picker("Catégorie", selection: $quick.categoryID) {
                ForEach(model.budget.categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            Picker("Icône", selection: $quick.symbol) {
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
        SheetForm(title: "Facture", canSave: !bill.name.trimmed.isEmpty && bill.amount > 0, onSave: save) {
            TextField("Nom (loyer, Hydro, Netflix…)", text: $bill.name)
            NumberRow(title: "Montant", value: $bill.amount, unit: model.settings.currencyCode)
            Picker("Fréquence", selection: $bill.period) {
                ForEach(BillPeriod.allCases) { Text($0.title).tag($0) }
            }
            DatePicker("Prochaine échéance", selection: $bill.anchorDate, displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
            Toggle("C'est un abonnement", isOn: $bill.isSubscription)
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
        SheetForm(title: "Objectif d'épargne", canSave: !goal.name.trimmed.isEmpty && goal.target > 0, onSave: save) {
            Section {
                TextField("Nom (voyage, fonds d'urgence…)", text: $goal.name)
                NumberRow(title: "Objectif", value: $goal.target, unit: model.settings.currencyCode)
                NumberRow(title: "Déjà épargné", value: $goal.saved, unit: model.settings.currencyCode)
                Toggle("Date limite", isOn: Binding(get: { goal.deadline != nil }, set: { goal.deadline = $0 ? (goal.deadline ?? Date().addingTimeInterval(180 * 86_400)) : nil }))
                if goal.deadline != nil {
                    DatePicker("Pour le", selection: Binding(get: { goal.deadline ?? Date() }, set: { goal.deadline = $0 }), displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                }
            }
            Section("Ajouter un versement") {
                NumberRow(title: "Montant", value: $deposit, unit: model.settings.currencyCode)
                Button("Ajouter au montant épargné") {
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
        SheetForm(title: "Compte", canSave: !account.name.trimmed.isEmpty, onSave: save) {
            TextField("Nom (compte chèque, CELI, prêt auto…)", text: $account.name)
            NumberRow(title: "Solde", value: $account.balance, unit: model.settings.currencyCode)
            Toggle("C'est une dette", isOn: $account.isLiability)
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
        SheetForm(title: "Catégorie", canSave: !category.name.trimmed.isEmpty, onSave: save) {
            TextField("Nom", text: $category.name)
            Picker("Icône", selection: $category.symbol) {
                ForEach(symbols, id: \.self) { Image(systemName: $0).tag($0) }
            }
            ColorChoiceRow(hex: $category.colorHex)
            NumberRow(title: "Limite par mois", value: $category.monthlyLimit, unit: model.settings.currencyCode)
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
