import SwiftUI

// Les deux feuilles de la refonte de Finances (direction 5 « hybride », choisie par le PDG le 2026-11-16) :
// « Ajouter » (une seule feuille pour une dépense ou un revenu) et la fiche d'une opération, lue avant l'éditeur.

// MARK: - « Ajouter »

/// « Ajouter »: the one sheet for a new expense or a new income. The amount first, typed on the decimal pad; then,
/// for an expense, the quick expenses of the widget (a touch fills the amount, the category and the note), the
/// category and the day as chips, a note; for an income, its source and the day. Saved like `ExpenseEditor` and
/// `IncomeEditor` save.
struct FinanceAddSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme
    @State private var isIncome: Bool
    @State private var amount: Double?
    @State private var categoryID: UUID? = BudgetState.fixedID(1)
    @State private var note = ""
    @State private var source = ""
    @State private var day: DayChoice = .today
    @State private var otherDate = Date()
    @State private var newQuick: QuickExpense?
    @State private var tapGuard = TapGuard()
    @FocusState private var amountFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 48

    /// The day of the operation: today and yesterday in one touch, any other date with the date picker.
    private enum DayChoice: Hashable {
        case today, yesterday, other
    }

    init(isIncome: Bool) {
        _isIncome = State(initialValue: isIncome)
    }

    private var currency: String { model.settings.currencyCode }
    private var palette: CristalPalette { CristalPalette.of(style.id) }
    /// The action color of Finances, readable with its ink (white in light mode, dark on the lighter color of dark mode).
    private var actionHex: String {
        let strong = palette.strongHex(Finances.accentHex)
        return scheme == .dark ? strong.dark : strong.light
    }

    /// The amount rounded to the cent, nil until something above zero is typed.
    private var value: Double? {
        guard let amount, amount.isFinite else { return nil }
        let cents = (amount * 100).rounded() / 100
        return cents > 0 ? cents : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker(tr("Type"), selection: $isIncome) {
                        Text(tr("Dépense")).tag(false)
                        Text(tr("Revenu")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("add-kind")
                    amountField
                    if isIncome {
                        field {
                            TextField(tr("Source (salaire, contrat, remboursement…)"), text: $source)
                                .textInputAutocapitalization(.sentences)
                        }
                    } else {
                        quickExpenses
                        section(tr("Catégorie")) {
                            FlowLayout(spacing: 8) {
                                ForEach(model.budget.categories) { category in
                                    chip(category.name, symbol: category.symbol, isOn: categoryID == category.id) {
                                        categoryID = category.id
                                    }
                                }
                            }
                        }
                    }
                    days
                    if !isIncome {
                        field {
                            TextField(tr("Note (facultatif)"), text: $note)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .cristalScreen()
            .tint(palette.strong(Finances.accentHex))
            .navigationTitle(tr("Ajouter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
            }
            .sheet(item: $newQuick) { QuickExpenseEditor(quick: $0) }
            .task {
                // After the sheet has risen: the keyboard comes up on the amount.
                try? await Task.sleep(for: .milliseconds(450))
                amountFocused = true
            }
        }
        .accessibilityIdentifier("add-sheet")
    }

    // MARK: Pieces

    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            TextField("0", value: $amount, format: .number.precision(.fractionLength(0...2)).locale(Fmt.locale))
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(tr("Montant")))
                .accessibilityIdentifier("add-amount")
            Text(UnitText.display(currency))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    /// The quick expenses of the widget « Dépense rapide », in a row that scrolls; « + » creates one.
    private var quickExpenses: some View {
        section(tr("Dépenses rapides")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.budget.quickExpenses) { quick in
                        Button { apply(quick) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: quick.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.category(model.budget.category(quick.categoryID)?.colorHex ?? Finances.accentHex))
                                Text(quick.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(TF.money(quick.amount, currency, decimals: 2))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(palette.wellColor, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityHint(Text(tr("Remplit le montant, la catégorie et la note")))
                    }
                    Button {
                        newQuick = QuickExpense(name: "", amount: 5, categoryID: BudgetState.fixedID(2))
                    } label: {
                        Label(tr("Nouvelle dépense rapide"), systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.strong(Finances.accentHex))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(palette.wellColor, in: Capsule())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("add-new-quick")
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    private var days: some View {
        section(tr("Date")) {
            VStack(alignment: .leading, spacing: 10) {
                FlowLayout(spacing: 8) {
                    chip(tr("Aujourd'hui"), symbol: nil, isOn: day == .today) { day = .today }
                    chip(tr("Hier"), symbol: nil, isOn: day == .yesterday) { day = .yesterday }
                    chip(tr("Autre date"), symbol: "calendar", isOn: day == .other) { day = .other }
                }
                if day == .other {
                    field {
                        DatePicker(tr("Date"), selection: $otherDate, displayedComponents: .date)
                            .environment(\.locale, Fmt.locale)
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        let canSave = value != nil
        return Button { tapGuard.run(save) } label: {
            Text(isIncome ? tr("Enregistrer le revenu") : tr("Enregistrer la dépense"))
                .font(.headline)
                .foregroundStyle(Color.readableInk(on: actionHex))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color(hex: actionHex), in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.45)
        .padding(.top, 4)
        .accessibilityIdentifier("add-save")
    }

    /// A small capital title over a group of choices.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// A text field on the well color, as the fields of the mock-up.
    private func field<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.body)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(palette.wellColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A choice: on the well color, or full in the action color with a check mark once chosen (never the color alone).
    private func chip(_ title: String, symbol: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                if isOn {
                    Image(systemName: "checkmark").font(.subheadline.weight(.bold))
                } else if let symbol {
                    Image(systemName: symbol).font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? Color.readableInk(on: actionHex) : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(isOn ? Color(hex: actionHex) : palette.wellColor, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Actions

    private func apply(_ quick: QuickExpense) {
        Haptics.tap()
        amount = quick.amount
        if let id = quick.categoryID, model.budget.category(id) != nil { categoryID = id }
        note = quick.name
    }

    private var chosenDate: Date {
        let now = Date()
        switch day {
        case .today: return now
        case .yesterday: return DateMath.calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .other: return otherDate
        }
    }

    private func save() {
        guard let value else { return }
        let date = chosenDate
        if isIncome {
            let label = source.trimmed
            let income = IncomeEntry(amount: value, label: label.isEmpty ? tr("Revenu") : label, date: date)
            model.update(\.budget) { $0.save(income) }
        } else {
            let expense = Expense(amount: value, categoryID: categoryID, note: note.trimmed, date: date)
            model.update(\.budget) { $0.save(expense) }
        }
        Haptics.success()
        dismiss()
    }
}

// MARK: - The card of an operation

/// The card of an expense or an income, read before it is changed: the amount, what it is, when, where it came from;
/// a guessed category to confirm in one touch; the weight of the expense in its category this month. « Modifier »
/// opens the usual editor on top, « Supprimer » deletes it. It follows the operation as saved (after a change it
/// shows the new values) and closes when the operation is deleted.
struct FinanceOperationSheet: View {
    private enum Subject {
        case expense(Expense)
        case income(IncomeEntry)
    }

    private let subject: Subject
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme
    @State private var editor: FinanceSheet?
    @State private var tapGuard = TapGuard()
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 44

    init(expense: Expense) {
        subject = .expense(expense)
    }

    init(income: IncomeEntry) {
        subject = .income(income)
    }

    private var currency: String { model.settings.currencyCode }
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    /// The expense as saved now (the one given when it is not, or no longer, in the budget).
    private var expense: Expense? {
        guard case let .expense(given) = subject else { return nil }
        return model.budget.expenses.first { $0.id == given.id } ?? given
    }

    private var income: IncomeEntry? {
        guard case let .income(given) = subject else { return nil }
        return model.budget.incomes.first { $0.id == given.id } ?? given
    }

    /// Whether the operation is in the budget: when it leaves it (deleted from its editor), the card closes.
    private var isSaved: Bool {
        switch subject {
        case let .expense(given): model.budget.expenses.contains { $0.id == given.id }
        case let .income(given): model.budget.incomes.contains { $0.id == given.id }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let expense {
                        expenseContent(expense)
                    } else if let income {
                        incomeContent(income)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cristalScreen()
            .tint(palette.strong(Finances.accentHex))
            .navigationTitle(income == nil ? tr("Dépense") : tr("Revenu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text(tr("Fermer")))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(item: $editor) { $0.editor }
        .onChange(of: isSaved) { wasSaved, saved in
            if wasSaved && !saved { dismiss() }
        }
        .accessibilityIdentifier("operation-sheet")
    }

    // MARK: Expense

    @ViewBuilder
    private func expenseContent(_ expense: Expense) -> some View {
        let state = model.budget
        let category = state.category(expense.categoryID)
        let title = expense.note.isEmpty ? (category?.name ?? tr("Dépense")) : expense.note
        header(symbol: category?.symbol ?? "square.grid.2x2", colorHex: category?.colorHex ?? "64748B",
               amount: Fmt.signedMoney(-expense.amount, currency: currency), amountHex: nil,
               title: title, date: expense.date, isApplePay: expense.source == .applePay)
        if expense.needsReview == true {
            reviewBanner(expense, categoryName: category?.name)
        }
        VStack(spacing: 0) {
            Button { edit() } label: {
                infoRow(tr("Catégorie")) {
                    HStack(spacing: 6) {
                        if let category {
                            Image(systemName: category.symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.category(category.colorHex))
                        }
                        Text(category?.name ?? tr("Sans catégorie"))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.pressable)
            if let merchant = expense.merchant, !merchant.isEmpty, merchant != title {
                MiniDivider().padding(.leading, -46)
                infoRow(tr("Commerçant")) { Text(merchant) }
            }
            if expense.fixedID != nil, let category {
                MiniDivider().padding(.leading, -46)
                infoRow(tr("Type")) { Text(tr("Dépense fixe · \(category.name)")) }
            }
            if let status = BudgetMath.categoryStatus(state, at: Date()).first(where: { $0.category.id == expense.categoryID }) {
                MiniDivider().padding(.leading, -46)
                infoRow(tr("\(status.category.name) ce mois-ci")) {
                    Text(monthText(status)).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .miniCard()
        actions(deleteTitle: tr("Supprimer la dépense"), canDelete: expense.fixedID == nil)
    }

    /// What the category weighs this month: spent, against its limit when it has one.
    private func monthText(_ status: BudgetMath.CategoryStatus) -> String {
        let spent = TF.money(status.spent, currency)
        guard status.limit > 0 else { return spent }
        return tr("\(spent) sur \(TF.money(status.limit, currency))") + " · " + Fmt.percent(status.spent / status.limit)
    }

    /// « À vérifier »: the category was guessed from the shop (or is missing); « Oui » confirms it and teaches it.
    private func reviewBanner(_ expense: Expense, categoryName: String?) -> some View {
        let amber = palette.strong(ApplePayStatus.hex)
        let text: String = {
            guard let categoryName else { return tr("À vérifier : choisis sa catégorie avec « Modifier ».") }
            return expense.merchant == nil
                ? tr("À vérifier : c'est bien « \(categoryName) » ?")
                : tr("À vérifier : c'est bien « \(categoryName) » ? Ardane s'en souviendra pour ce commerçant.")
        }()
        return HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(amber)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if categoryName != nil {
                Button { tapGuard.run { confirm(expense) } } label: {
                    Text(tr("Oui"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.readableInk(on: actionHex))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Color(hex: actionHex), in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("operation-confirm")
            }
        }
        .padding(12)
        .background(palette.category(ApplePayStatus.hex).opacity(scheme == .dark ? 0.20 : 0.14),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func confirm(_ expense: Expense) {
        model.update(\.budget) { state in
            if expense.merchant != nil && expense.categoryID != nil { state.learnMerchantCategory(for: expense) }
            if let index = state.expenses.firstIndex(where: { $0.id == expense.id }) { state.expenses[index].needsReview = false }
        }
        Haptics.success()
    }

    // MARK: Income

    @ViewBuilder
    private func incomeContent(_ income: IncomeEntry) -> some View {
        let now = Date()
        let month = BudgetMath.earned(model.budget, in: BudgetMath.monthInterval(now), now: now)
        let incomes = tr("Revenus")
        header(symbol: "arrow.down.left", colorHex: Finances.incomeHex,
               amount: Fmt.signedMoney(income.amount, currency: currency), amountHex: Finances.incomeHex,
               title: income.label.isEmpty ? tr("Revenu") : income.label, date: income.date, isApplePay: false)
        VStack(spacing: 0) {
            infoRow(tr("Type")) { Text(income.fixedID == nil ? tr("Revenu") : tr("Revenu fixe")) }
            MiniDivider().padding(.leading, -46)
            infoRow(tr("\(incomes) ce mois-ci")) {
                Text(TF.money(month, currency)).monospacedDigit()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .miniCard()
        actions(deleteTitle: tr("Supprimer le revenu"), canDelete: income.fixedID == nil)
    }

    // MARK: Shared pieces

    /// The icon of the category, the signed amount in big, the title, the day and hour, the Apple Pay mark.
    private func header(symbol: String, colorHex: String, amount: String, amountHex: String?, title: String, date: Date, isApplePay: Bool) -> some View {
        let tint = palette.category(colorHex)
        return VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.14), in: Circle())
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            Text(amount)
                .font(.system(size: amountSize, weight: .bold, design: .rounded))
                .foregroundStyle(amountHex.map { palette.strong($0) } ?? Color.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Text(when(date))
                if isApplePay {
                    Text("·")
                    ApplePayMark()
                    Text("Apple Pay")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    /// « Aujourd'hui à 12:41 », « Hier à 08:05 », « Mardi 10 novembre à 18:30 ».
    private func when(_ date: Date) -> String {
        let now = Date()
        let days = DateMath.daysBetween(date, now)
        let day = (0...1).contains(days) ? TF.relativeDay(date, from: now).capitalizedFirst : Fmt.longDay(date).capitalizedFirst
        return tr("\(day) à \(Fmt.time(date, uses24Hour: model.settings.uses24HourClock))")
    }

    /// A line of the card: the label on the left, the value on the right.
    private func infoRow<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            value()
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
        .frame(minHeight: 46)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// « Modifier » (the usual editor, on top) and the deletion. A payment of a bill or of a fixed amount is changed
    /// in its source, and can't be deleted on its own.
    private func actions(deleteTitle: String, canDelete: Bool) -> some View {
        VStack(spacing: 10) {
            Button { edit() } label: {
                Label(tr("Modifier"), systemImage: "pencil")
                    .font(.headline)
                    .foregroundStyle(palette.strong(Finances.accentHex))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(palette.category(Finances.accentHex).opacity(scheme == .dark ? 0.20 : 0.13), in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("operation-edit")
            if canDelete {
                Button(role: .destructive) { tapGuard.run(delete) } label: {
                    Label(deleteTitle, systemImage: "trash")
                        .font(.headline)
                        .foregroundStyle(palette.strong(Finances.overHex))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(Capsule().strokeBorder(palette.category(Finances.overHex).opacity(0.45), lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(deleteTitle))
            }
        }
        .padding(.top, 4)
    }

    /// The action color of Finances, readable with its ink.
    private var actionHex: String {
        let strong = palette.strongHex(Finances.accentHex)
        return scheme == .dark ? strong.dark : strong.light
    }

    /// Opens the editor of the operation, or of the bill or fixed amount a payment comes from.
    private func edit() {
        let state = model.budget
        switch subject {
        case .expense:
            guard let expense else { return }
            editor = expense.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .expense(expense)
        case .income:
            guard let income else { return }
            editor = income.fixedID.flatMap { FinanceSheet.fixed($0, state: state, items: model.content.money.items) } ?? .income(income)
        }
    }

    private func delete() {
        switch subject {
        case let .expense(given):
            model.update(\.budget) { $0.expenses.removeAll { $0.id == given.id } }
        case let .income(given):
            model.update(\.budget) { $0.incomes.removeAll { $0.id == given.id } }
        }
        Haptics.success()
        dismiss()
    }
}
