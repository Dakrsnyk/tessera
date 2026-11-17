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
        let automatic = WalletImport.isEnabled && WalletImport.isSupported
        guard let last = lastDate(state) else { return automatic ? tr("Automatique · aucun achat pour l'instant") : tr("À configurer") }
        return automatic ? tr("Automatique · dernière dépense \(since(last))") : tr("Active · dernière dépense \(since(last))")
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
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        Text(tr("À vérifier"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(palette.strong(ApplePayStatus.hex))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(palette.category(ApplePayStatus.hex).opacity(0.14), in: Capsule())
            .fixedSize()
    }
}

// MARK: - The guide

/// The sheet that explains how to set up the Shortcuts automation, with the words of the Shortcuts app.
struct ApplePayGuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appStyle) private var style

    private var accentHex: String { Finances.accentHex }

    var body: some View {
        let state = model.budget
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro
                    status(state)
                    if WalletImport.isSupported {
                        WalletImportSection()
                    }
                    if !(WalletImport.isSupported && WalletImport.isEnabled && model.isPremium) {
                        steps
                        openShortcuts
                    }
                    howItWorks
                    rules(state)
                    MiniFootnote(text: tr("Ardane ne reçoit que le montant, le commerçant et la carte que Raccourcis lui passe. Une dépense reçue se supprime comme les autres."))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cristalScreen()
            .environment(\.miniAccent, CristalPalette.of(style.id).category(accentHex))
            .tint(CristalPalette.of(style.id).strong(accentHex))
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
            MiniSectionTitle(title: WalletImport.isSupported ? tr("Sans Premium : avec Raccourcis") : tr("À faire une seule fois"))
            VStack(alignment: .leading, spacing: 16) {
                GuideStep(number: 1, colorHex: accentHex,
                          text: tr("Ouvre Raccourcis › Automatisation › « + » › Transaction."))
                GuideStep(number: 2, colorHex: accentHex,
                          text: tr("Choisis tes cartes, « Tout paiement » et « Exécuter immédiatement »."))
                GuideStep(number: 3, colorHex: accentHex,
                          text: tr("Ajoute l'action « Ajouter une dépense Apple Pay » (app Ardane), puis touche chaque champ :"),
                          lines: [tr("Montant → « Montant »"), tr("Commerçant → « Commerçant »"), tr("Carte → « Carte ou laissez-passer »")])
                GuideStep(number: 4, colorHex: accentHex,
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

/// Premium, where Apple allows it (FinanceKit): the purchases of the Wallet cards arrive by themselves, without any
/// shortcut. Off by default: the person turns it on, iOS asks for the access, then the purchases of the month are read.
private struct WalletImportSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var isEnabled = WalletImport.isEnabled
    @State private var isWorking = false
    @State private var message: String?
    @State private var paywall: PaywallContext?

    private var isOn: Bool { isEnabled && model.isPremium }

    var body: some View {
        let palette = CristalPalette.of(style.id)
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Import automatique depuis Cartes"))
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "wave.3.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(palette.strong(isOn ? Finances.incomeHex : ApplePayStatus.hex))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isOn ? tr("Activé") : tr("Sans raccourci à créer"))
                            .font(.headline)
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actions
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .miniCard()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("applepay-wallet")
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    private var detail: String {
        guard model.isPremium else {
            return tr("Avec Premium, tes achats faits avec les cartes de Cartes arrivent seuls dans tes dépenses. Rien à régler dans Raccourcis.")
        }
        guard isEnabled else {
            return tr("Tes achats faits avec les cartes de Cartes arrivent seuls dans tes dépenses, à chaque ouverture d'Ardane. Rien ne quitte ton iPhone.")
        }
        if let last = WalletImport.lastRun {
            return tr("Dernière lecture \(ApplePayStatus.since(last)). Tes achats arrivent à chaque ouverture d'Ardane.")
        }
        return tr("Tes achats arrivent à chaque ouverture d'Ardane.")
    }

    @ViewBuilder
    private var actions: some View {
        if !model.isPremium {
            MiniActionButton(title: tr("Découvrir Premium"), symbol: "sparkles", colorHex: Finances.accentHex) { paywall = .walletImport }
                .accessibilityIdentifier("applepay-wallet-premium")
        } else if !isEnabled {
            MiniActionButton(title: isWorking ? tr("Un instant…") : tr("Activer l'import automatique"), symbol: "wave.3.right", colorHex: Finances.accentHex) {
                guard !isWorking else { return }
                isWorking = true
                Task {
                    let outcome = await WalletImport.enable(model: model)
                    isWorking = false
                    isEnabled = WalletImport.isEnabled
                    switch outcome {
                    case .enabled: message = nil
                    case .denied: message = tr("Accès refusé. Tu peux l'autoriser plus tard dans les Réglages de l'iPhone, puis revenir ici.")
                    case .unavailable: message = tr("Cartes ne partage pas encore les achats sur cet iPhone. Le raccourci reste possible.")
                    case .failed: message = tr("La lecture n'a pas pu se faire. Réessaie dans un moment.")
                    }
                }
            }
            .accessibilityIdentifier("applepay-wallet-enable")
        } else {
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Lire maintenant"), symbol: "arrow.clockwise", colorHex: Finances.accentHex, isProminent: false) {
                    Task { await WalletImport.sync(model: model) }
                }
                MiniActionButton(title: tr("Désactiver"), symbol: "pause.circle", colorHex: Finances.overHex, isProminent: false) {
                    WalletImport.disable()
                    isEnabled = false
                }
                .accessibilityIdentifier("applepay-wallet-disable")
            }
        }
    }
}

extension PaywallContext {
    /// The automatic Apple Pay expenses read in Wallet (FinanceKit), in Finances.
    static var walletImport: PaywallContext {
        PaywallContext(
            symbol: "wave.3.right.circle.fill",
            title: tr("Apple Pay automatique"),
            detail: tr("Tes achats faits avec les cartes de Cartes arrivent seuls dans tes dépenses, sans raccourci à créer."),
            perk: .smart
        )
    }
}

/// A numbered step: a circle with the number, the sentence, and short lines under it when needed.
private struct GuideStep: View {
    @Environment(\.appStyle) private var style
    let number: Int
    let colorHex: String
    let text: String
    var lines: [String] = []

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.onAccent)
                .frame(width: 28, height: 28)
                .background(CristalPalette.of(style.id).strong(colorHex), in: Circle())
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
                        .background(CristalPalette.of(style.id).wellColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    @Environment(\.appStyle) private var style
    let symbol: String
    let colorHex: String
    let text: String

    var body: some View {
        let tint = CristalPalette.of(style.id).category(colorHex)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: Circle())
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
    @Environment(\.appStyle) private var style

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
        .tint(CristalPalette.of(style.id).strong(Finances.accentHex))
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
