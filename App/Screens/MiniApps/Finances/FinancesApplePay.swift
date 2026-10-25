import SwiftUI

/// What the Finances mini-app knows about the automatic Apple Pay expenses (the ones the Shortcuts
/// automation adds through the « Ajouter une dépense Apple Pay » action).
enum ApplePayStatus {
    static let hex = "F2A33A"

    /// The date of the latest expense received from Apple Pay, if any.
    static func lastDate(_ state: BudgetState) -> Date? {
        state.expenses.filter { $0.source == .applePay }.map(\.date).max()
    }

    /// How many received expenses still wait for the person to check their category.
    static func reviewCount(_ state: BudgetState) -> Int {
        state.expenses.filter { $0.source == .applePay && $0.needsReview == true }.count
    }

    /// « il y a 5 min », « il y a 2 h », « hier », « il y a 3 jours »…
    static func since(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return tr("à l'instant") }
        if seconds < 3600 { return tr("il y a \(Int(seconds / 60)) min") }
        if seconds < 86_400 { return tr("il y a \(Int(seconds / 3600)) h") }
        return TF.relativeDay(date, from: now)
    }

    /// The line of the row in Finances.
    static func subtitle(_ state: BudgetState) -> String {
        guard let last = lastDate(state) else { return tr("À configurer") }
        return tr("Active · dernière dépense \(since(last))")
    }
}

/// The small « Apple Pay » mark next to an expense that came from the automation.
struct ApplePayMark: View {
    var body: some View {
        Image(systemName: "wave.3.right.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Apple Pay"))
    }
}

/// The « À vérifier » pill of an expense whose category was guessed (or is missing).
struct ReviewBadge: View {
    var body: some View {
        Text(tr("À vérifier"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color(hex: ApplePayStatus.hex))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color(hex: ApplePayStatus.hex).opacity(0.16), in: Capsule())
            .fixedSize()
    }
}

// MARK: - The guide

/// The sheet that explains how to set up the Shortcuts automation, with the words of the Shortcuts app.
struct ApplePayGuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var accentHex: String { Finances.accentHex }

    var body: some View {
        let state = model.budget
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    status(state)
                    steps
                    openShortcuts
                    howItWorks
                    rules(state)
                    MiniFootnote(text: tr("Ardane ne reçoit que le montant, le commerçant et la carte que Raccourcis lui passe. Une dépense reçue se supprime comme les autres."))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.screenGradient)
            .environment(\.miniAccent, Color(hex: accentHex))
            .navigationTitle("Apple Pay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("applepay-guide")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            MiniSectionTitle(title: tr("Dépenses Apple Pay automatiques"))
            Text(tr("Chaque paiement Apple Pay arrive tout seul dans tes dépenses. Rien ne quitte ton iPhone."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: State

    private func status(_ state: BudgetState) -> some View {
        let last = ApplePayStatus.lastDate(state)
        let toReview = ApplePayStatus.reviewCount(state)
        var detail = tr("Aucun paiement reçu pour l'instant")
        if let last { detail = tr("Dernière dépense \(ApplePayStatus.since(last))") }
        return MiniRowsCard {
            MiniRow(symbol: last == nil ? "exclamationmark.circle.fill" : "checkmark.circle.fill",
                    colorHex: last == nil ? ApplePayStatus.hex : Finances.incomeHex,
                    title: last == nil ? tr("À configurer") : tr("Active"),
                    detail: detail,
                    value: toReview > 0 ? tr("\(toReview) à vérifier") : nil,
                    showsChevron: false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("applepay-status")
    }

    // MARK: Steps

    /// The steps, with the words of the Shortcuts app in French.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("À faire une seule fois"))
            VStack(alignment: .leading, spacing: 16) {
                GuideStep(number: 1, colorHex: accentHex,
                          text: tr("Ouvre Raccourcis › Automatisation › « + » › Créer une automatisation personnelle › Transaction."))
                GuideStep(number: 2, colorHex: accentHex,
                          text: tr("Choisis tes cartes et « Tout paiement »."))
                GuideStep(number: 3, colorHex: accentHex,
                          text: tr("Choisis « Exécuter immédiatement » (et désactive « Notifier à l'exécution » si proposé)."))
                GuideStep(number: 4, colorHex: accentHex,
                          text: tr("Ajoute l'action « Ajouter une dépense Apple Pay » (app Ardane)."))
                GuideStep(number: 5, colorHex: accentHex,
                          text: tr("Dans l'action, touche chaque champ et choisis la variable de la transaction :"),
                          lines: [tr("Montant → « Montant »"), tr("Commerçant → « Commerçant »"), tr("Carte → « Carte ou laissez-passer »")])
                GuideStep(number: 6, colorHex: accentHex,
                          text: tr("Termine : le prochain paiement apparaîtra tout seul dans tes dépenses."))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .miniCard()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("applepay-steps")
    }

    private var openShortcuts: some View {
        MiniActionButton(title: tr("Ouvrir Raccourcis"), symbol: "arrow.up.forward.app", colorHex: accentHex) {
            if let url = URL(string: "shortcuts://") { openURL(url) }
        }
        .accessibilityIdentifier("applepay-open-shortcuts")
    }

    // MARK: How it works

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Comment ça marche"))
            VStack(alignment: .leading, spacing: 14) {
                GuideInfoLine(symbol: "wave.3.right.circle", colorHex: accentHex,
                              text: tr("À chaque paiement Apple Pay, Raccourcis passe le montant et le commerçant à Ardane."))
                GuideInfoLine(symbol: "tag.fill", colorHex: accentHex,
                              text: tr("Ardane choisit la catégorie d'après le commerçant. Si elle est incertaine, la dépense porte « À vérifier »."))
                GuideInfoLine(symbol: "checkmark.shield.fill", colorHex: Finances.incomeHex,
                              text: tr("Quand tu changes une catégorie, Ardane s'en souvient pour ce commerçant. Tout reste sur ton iPhone."))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .miniCard()
        }
    }

    // MARK: Rules

    private func rules(_ state: BudgetState) -> some View {
        let count = state.merchantRules.count
        return MiniRowsCard {
            NavigationLink { MerchantRulesView() } label: {
                MiniRow(symbol: "list.bullet.rectangle", colorHex: "8C6CFF", title: tr("Règles de commerçants"),
                        detail: count == 0 ? tr("Ardane apprend quand tu changes une catégorie") : Fmt.plural(count, tr("règle"), tr("règles")))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("applepay-rules")
        }
    }
}

/// A numbered step: a circle with the number, the sentence, and short lines under it when needed.
private struct GuideStep: View {
    let number: Int
    let colorHex: String
    let text: String
    var lines: [String] = []

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
                .background(Color(hex: colorHex), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(number). \(text) \(lines.joined(separator: ", "))"))
    }
}

/// An icon and a sentence, for the « Comment ça marche » card.
private struct GuideInfoLine: View {
    let symbol: String
    let colorHex: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 30, height: 30)
                .background(Color(hex: colorHex).opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Merchant rules

/// « Règles de commerçants »: the category Ardane learned for each merchant, one per line; a swipe removes one.
struct MerchantRulesView: View {
    @Environment(AppModel.self) private var model

    private struct Rule: Identifiable {
        let merchant: String
        let categoryID: UUID
        var id: String { merchant }
    }

    private var rules: [Rule] {
        model.budget.merchantRules
            .map { Rule(merchant: $0.key, categoryID: $0.value) }
            .sorted { $0.merchant < $1.merchant }
    }

    var body: some View {
        let state = model.budget
        let list = rules
        List {
            if list.isEmpty {
                Section {
                    Text(tr("Aucune règle pour l'instant. Quand tu changes la catégorie d'une dépense Apple Pay, Ardane s'en souvient pour ce commerçant et classe les prochains paiements tout seul."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("applepay-rules-empty")
                }
            } else {
                Section {
                    ForEach(list) { rule in
                        let category = state.category(rule.categoryID)
                        HStack(spacing: 12) {
                            Text(rule.merchant.capitalizedFirst)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Label(category?.name ?? tr("Sans catégorie"), systemImage: category?.symbol ?? "square.grid.2x2")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .accessibilityIdentifier("applepay-rule-row")
                    }
                    .onDelete { offsets in
                        let merchants = offsets.map { list[$0].merchant }
                        model.update(\.budget) { budget in
                            for merchant in merchants { budget.merchantRules.removeValue(forKey: merchant) }
                        }
                    }
                } footer: {
                    Text(tr("Balaie une règle vers la gauche pour la supprimer. Les dépenses déjà notées ne changent pas."))
                }
            }
        }
        .styledList()
        .tint(Color(hex: Finances.accentHex))
        .navigationTitle(tr("Règles de commerçants"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Editing an expense that came from Apple Pay

/// The editor of an expense received from Apple Pay (or that has a merchant): the same fields as the usual
/// one, plus the merchant. Saving confirms the expense (« À vérifier » goes away); changing its category
/// teaches Ardane that merchant's category for the next payments.
struct MerchantExpenseEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var expense: Expense
    private let original: Expense

    init(expense: Expense) {
        _expense = State(initialValue: expense)
        original = expense
    }

    var body: some View {
        SheetForm(title: tr("Modifier la dépense"), canSave: expense.amount > 0, onSave: save) {
            if let merchant = original.merchant, !merchant.isEmpty {
                Section {
                    HStack {
                        Text(tr("Commerçant"))
                        Spacer()
                        Text(merchant.capitalizedFirst).foregroundStyle(.secondary)
                    }
                    if original.source == .applePay {
                        HStack {
                            Text(tr("Reçue de"))
                            Spacer()
                            Label("Apple Pay", systemImage: "wave.3.right.circle").foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if original.needsReview == true {
                        Text(tr("La catégorie est une estimation. Corrige-la si besoin : Ardane s'en souviendra pour ce commerçant. Enregistrer sans rien changer la confirme."))
                    }
                }
            }
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
            Section {
                Button(tr("Supprimer la dépense"), role: .destructive) {
                    let id = expense.id
                    model.update(\.budget) { $0.expenses.removeAll { $0.id == id } }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        var saved = expense
        saved.note = saved.note.trimmed
        // Opening an expense to check and saving it confirms it, changed or not, as long as it has a category.
        saved.needsReview = saved.categoryID == nil ? original.needsReview : false
        // A category kept as it was guessed is a confirmation: it teaches the merchant too.
        let learns = saved.merchant != nil && saved.categoryID != nil && (original.needsReview == true || saved.categoryID != original.categoryID)
        model.update(\.budget) { state in
            state.save(saved)
            if learns { state.learnMerchantCategory(for: saved) }
        }
        Haptics.success()
    }
}
