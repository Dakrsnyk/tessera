import SwiftUI

struct MoneyView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: MoneyItem?

    var body: some View {
        let money = model.content.money
        let currency = model.settings.currencyCode
        List {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let summary = MoneyMath.summary(money, at: context.date)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Solde net depuis le \(Fmt.format(summary.startDate, template: "dMMMM"))"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(Fmt.signedMoney(summary.totalNet, currency: currency))
                            .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(summary.totalNet >= 0 ? Color.green : Color.red)
                            .contentTransition(.numericText())
                        HStack {
                            summaryValue(tr("Par jour"), Fmt.signedMoney(summary.perDayNet, currency: currency))
                            Spacer()
                            summaryValue(tr("Par mois"), Fmt.signedMoney(summary.perDayNet * MoneySummary.daysPerMonth, currency: currency, decimals: 0))
                        }
                    }
                    .padding(.vertical, 6)
                }
            } footer: {
                Text(tr("Les montants sont répartis heure par heure : le widget montre ce qui s'accumule au fil de la journée."))
            }

            itemsSection(title: tr("Revenus"), isIncome: true, items: money.items.filter(\.isIncome), currency: currency)
            itemsSection(title: tr("Dépenses"), isIncome: false, items: money.items.filter { !$0.isIncome }, currency: currency)

            Section(tr("Réglages")) {
                DatePicker(tr("Début du calcul"), selection: Binding(
                    get: { money.startDate },
                    set: { date in model.updateContent { $0.money.startDate = DateMath.startOfDay(date) } }
                ), displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
                Picker(tr("Devise"), selection: Binding(
                    get: { model.settings.currencyCode },
                    set: { code in model.updateSettings { $0.currencyCode = code } }
                )) {
                    ForEach(AppSettings.currencies, id: \.self) { Text($0).tag($0) }
                }
            }
        }
        .styledList()
        .navigationTitle(tr("Revenus et dépenses"))
        .sheet(item: $editing) { item in
            MoneyItemEditor(item: item, isNew: !money.items.contains { $0.id == item.id })
        }
    }

    private func summaryValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }

    private func itemsSection(title: String, isIncome: Bool, items: [MoneyItem], currency: String) -> some View {
        Section {
            ForEach(items) { item in
                Button {
                    editing = item
                } label: {
                    HStack {
                        Text(item.name).foregroundStyle(.primary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Fmt.money(item.amount, currency: currency))
                                .foregroundStyle(isIncome ? Color.green : Color.red)
                                .monospacedDigit()
                            Text(item.period.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let ids = offsets.map { items[$0].id }
                model.updateContent { content in content.money.items.removeAll { ids.contains($0.id) } }
            }
            Button {
                editing = MoneyItem(name: "", amount: 0, period: .month, isIncome: isIncome)
            } label: {
                Label(isIncome ? tr("Ajouter un revenu") : tr("Ajouter une dépense"), systemImage: "plus.circle.fill")
            }
        } header: {
            Text(title)
        }
    }
}

struct MoneyItemEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var item: MoneyItem
    @State private var amountText: String
    let isNew: Bool

    init(item: MoneyItem, isNew: Bool) {
        _item = State(initialValue: item)
        _amountText = State(initialValue: item.amount == 0 ? "" : String(format: "%.2f", item.amount).replacingOccurrences(of: ".", with: ","))
        self.isNew = isNew
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: ""))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(tr("Type"), selection: $item.isIncome) {
                        Text(tr("Revenu")).tag(true)
                        Text(tr("Dépense")).tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Section(tr("Détails")) {
                    TextField(item.isIncome ? tr("Salaire, freelance…") : tr("Loyer, épicerie…"), text: $item.name)
                    HStack {
                        TextField(tr("Montant"), text: $amountText)
                            .keyboardType(.decimalPad)
                        Text(model.settings.currencyCode).foregroundStyle(.secondary)
                    }
                    Picker(tr("Fréquence"), selection: $item.period) {
                        ForEach(MoneyPeriod.allCases) { Text($0.title).tag($0) }
                    }
                }
                if let amount = parsedAmount, amount > 0 {
                    Section {
                        LabeledContent(tr("Soit par jour"), value: Fmt.money(amount / item.period.days, currency: model.settings.currencyCode))
                        LabeledContent(tr("Soit par mois"), value: Fmt.money(amount / item.period.days * MoneySummary.daysPerMonth, currency: model.settings.currencyCode, decimals: 0))
                    }
                }
                if !isNew {
                    Section {
                        Button(tr("Supprimer"), role: .destructive) {
                            model.updateContent { content in content.money.items.removeAll { $0.id == item.id } }
                            dismiss()
                        }
                    }
                }
            }
            .styledList()
            .navigationTitle(isNew ? (item.isIncome ? tr("Nouveau revenu") : tr("Nouvelle dépense")) : item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(tr("Annuler")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Enregistrer"), action: save)
                        .disabled(item.name.trimmed.isEmpty || (parsedAmount ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let amount = parsedAmount, amount > 0 else { return }
        var saved = item
        saved.name = saved.name.trimmed
        saved.amount = amount
        model.updateContent { content in
            if let index = content.money.items.firstIndex(where: { $0.id == saved.id }) {
                content.money.items[index] = saved
            } else {
                content.money.items.append(saved)
            }
        }
        dismiss()
    }
}
