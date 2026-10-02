import SwiftUI

// MARK: - Portefeuille

struct PortfolioSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let positions = PortfolioMath.positions(model.portfolio, prices: model.prices)
        let summary = PortfolioMath.summary(positions)
        Section {
            if positions.isEmpty {
                HintRow(text: tr("Ajoute tes actions, ETF, cryptos et liquidités. Les cryptos se mettent à jour en direct (CoinGecko). Pour les actions et ETF, indique le dernier prix connu."))
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TF.money(summary.value, currency))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(tr("\(Fmt.signedMoney(summary.gain, currency: currency, decimals: 0)) au total"))
                        .foregroundStyle(summary.gain >= 0 ? Color.green : Color.red)
                }
                .padding(.vertical, 4)
            }
            ForEach(positions.sorted { $0.value > $1.value }, id: \.holding.id) { position in
                Button {
                    sheets?.open { HoldingEditor(holding: position.holding) }
                } label: {
                    HStack {
                        Circle().fill(Color(hex: position.holding.kind.colorHex)).frame(width: 9, height: 9)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(position.holding.name).foregroundStyle(Color.primary)
                            Text("\(TF.quantity(position.holding.quantity)) · \(position.holding.kind.title)")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        Text(TF.money(position.value, currency)).monospacedDigit().foregroundStyle(Color.secondary)
                    }
                }
            }
            .onDelete { offsets in
                let sorted = positions.sorted { $0.value > $1.value }
                let ids = offsets.map { sorted[$0].holding.id }
                model.update(\.portfolio) { $0.holdings.removeAll { ids.contains($0.id) } }
            }
            Button {
                sheets?.open { HoldingEditor(holding: Holding(kind: .etf, name: "", symbol: "", quantity: 0, costBasis: 0)) }
            } label: {
                Label(tr("Ajouter un placement"), systemImage: "plus")
            }
        } header: {
            Text(tr("Mon portefeuille"))
        } footer: {
            Text(tr("À titre informatif seulement : Tessera ne donne aucun conseil d'investissement."))
        }
        .task { await model.refreshMarkets() }

        Section {
            ForEach(CryptoService.coins) { coin in
                let followed = model.portfolio.watchlist.contains(coin.id)
                Button {
                    model.update(\.portfolio) { state in
                        if followed { state.watchlist.removeAll { $0 == coin.id } } else { state.watchlist.append(coin.id) }
                    }
                } label: {
                    HStack {
                        Text("\(coin.name) (\(coin.symbol))").foregroundStyle(Color.primary)
                        Spacer()
                        if let quote = model.quotes.first(where: { $0.id == coin.id }) {
                            Text(Fmt.price(quote.price, currency: model.settings.cryptoCurrency.uppercased())).foregroundStyle(Color.secondary).monospacedDigit()
                        }
                        Image(systemName: followed ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                    }
                }
            }
        } header: {
            Text(tr("Liste de suivi"))
        } footer: {
            Text(tr("Cours fournis par CoinGecko."))
        }
    }
}

struct HoldingEditor: View {
    @Environment(AppModel.self) private var model
    @State var holding: Holding

    var body: some View {
        SheetForm(title: tr("Placement"), canSave: !holding.name.trimmed.isEmpty && holding.quantity > 0, onSave: save) {
            Section {
                Picker(tr("Type"), selection: $holding.kind) {
                    ForEach(AssetKind.allCases) { Text($0.title).tag($0) }
                }
                if holding.kind == .crypto {
                    Picker(tr("Crypto"), selection: $holding.symbol) {
                        ForEach(CryptoService.coins) { Text("\($0.name) (\($0.symbol))").tag($0.id) }
                    }
                    .onChange(of: holding.symbol) { _, id in holding.name = CryptoService.info(id).name }
                } else {
                    TextField(tr("Nom"), text: $holding.name)
                    if holding.kind != .cash {
                        TextField(tr("Symbole (XEQT, AAPL…)"), text: $holding.symbol)
                            .textInputAutocapitalization(.characters)
                    }
                }
            }
            Section {
                NumberRow(title: holding.kind == .cash ? tr("Montant") : tr("Quantité"), value: $holding.quantity)
                if holding.kind != .cash {
                    NumberRow(title: tr("Prix payé au total"), value: $holding.costBasis, unit: model.settings.currencyCode)
                }
                if holding.kind == .stock || holding.kind == .etf {
                    NumberRow(title: tr("Dernier prix connu"), value: Binding(get: { holding.manualPrice ?? 0 }, set: { holding.manualPrice = $0 > 0 ? $0 : nil }), unit: model.settings.currencyCode)
                }
            } footer: {
                Text(holding.kind == .crypto ? tr("Le prix se met à jour automatiquement.") : tr("Mets le prix à jour quand tu veux : il sert à calculer la valeur."))
            }
        }
        .onAppear {
            if holding.kind == .crypto && holding.symbol.isEmpty { holding.symbol = "bitcoin" }
        }
    }

    private func save() {
        var saved = holding
        if saved.kind == .crypto {
            if saved.symbol.isEmpty { saved.symbol = "bitcoin" }
            saved.name = CryptoService.info(saved.symbol).name
        }
        if saved.kind == .cash {
            saved.costBasis = saved.quantity
            saved.symbol = model.settings.currencyCode
        }
        saved.name = saved.name.trimmed
        saved.symbol = saved.symbol.trimmed
        model.update(\.portfolio) { state in
            if let index = state.holdings.firstIndex(where: { $0.id == saved.id }) {
                state.holdings[index] = saved
            } else {
                state.holdings.append(saved)
            }
        }
        Task { await model.refreshMarkets() }
    }
}

// MARK: - Business

struct BusinessSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    private var currency: String { model.settings.currencyCode }

    var body: some View {
        let now = Date()
        let state = model.business
        Section {
            TextField(tr("Nom de l'entreprise"), text: Binding(get: { state.name }, set: { name in model.setBusinessName(name) }))
            NumberRow(title: tr("Objectif du mois"), value: Binding(get: { state.monthlyGoal }, set: { goal in model.setBusinessGoal(goal) }), unit: currency)
            ValueRow(title: tr("Aujourd'hui"), value: TF.money(BusinessMath.revenue(state, .day, at: now), currency), symbol: "sun.max")
            ValueRow(title: tr("Cette semaine"), value: TF.money(BusinessMath.revenue(state, .week, at: now), currency), symbol: "calendar")
            ValueRow(title: tr("Ce mois-ci"), value: TF.money(BusinessMath.revenue(state, .month, at: now), currency), symbol: "chart.bar")
            ValueRow(title: tr("Cette année"), value: TF.money(BusinessMath.revenue(state, .year, at: now), currency), symbol: "chart.line.uptrend.xyaxis")
            let profit = BusinessMath.profit(state, month: now)
            ValueRow(title: tr("Bénéfice du mois"), value: "\(TF.money(profit.profit, currency))\(profit.margin.map { " · \(Fmt.percent($0))" } ?? "")", symbol: "banknote")
        } header: {
            Text(tr("Chiffre d'affaires"))
        }

        Section {
            Button { sheets?.open { SaleEditor() } } label: { Label(tr("Noter une vente"), systemImage: "plus.circle.fill").font(.headline) }
            Button { sheets?.open { BusinessCostEditor() } } label: { Label(tr("Noter une dépense"), systemImage: "minus.circle") }
            Button { sheets?.open { MRREditor() } } label: { Label(tr("Mettre à jour le MRR"), systemImage: "arrow.triangle.2.circlepath") }
        } footer: {
            Text(tr("Saisie manuelle : pour un export Shopify, Stripe ou autre, note le total du jour."))
        }

        Section(tr("Dernières ventes")) {
            ForEach(state.sales.sorted { $0.date > $1.date }.prefix(15)) { sale in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Fmt.shortDay(sale.date))
                        Text("\(Fmt.plural(sale.orders, tr("commande"), tr("commandes")))\(sale.note.isEmpty ? "" : " · \(sale.note)")")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    Text(TF.money(sale.amount, currency, decimals: 2)).monospacedDigit()
                }
                .swipeActions {
                    Button(role: .destructive) {
                        model.update(\.business) { $0.sales.removeAll { $0.id == sale.id } }
                    } label: {
                        Label(tr("Supprimer"), systemImage: "trash")
                    }
                }
            }
            if state.sales.isEmpty {
                HintRow(text: tr("Aucune vente notée pour l'instant."))
            }
        }
    }
}

struct SaleEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sale: SalesEntry
    private let isNew: Bool

    /// A new sale, or an existing one to change or delete.
    init(sale: SalesEntry? = nil) {
        _sale = State(initialValue: sale ?? SalesEntry(amount: 0))
        isNew = sale == nil
    }

    var body: some View {
        SheetForm(title: isNew ? tr("Vente") : tr("Modifier la vente"), canSave: sale.amount > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Montant"), value: $sale.amount, unit: model.settings.currencyCode)
                DatePicker(tr("Date"), selection: $sale.date, displayedComponents: .date).environment(\.locale, Fmt.locale)
                IntRow(title: tr("Commandes"), value: $sale.orders)
                IntRow(title: tr("Nouveaux clients"), value: $sale.newCustomers)
                IntRow(title: tr("Visiteurs"), value: $sale.visitors)
                TextField(tr("Note (facultatif)"), text: $sale.note)
            }
            if !isNew {
                Section {
                    Button(tr("Supprimer la vente"), role: .destructive) {
                        let id = sale.id
                        model.update(\.business) { $0.sales.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let saved = sale
        model.update(\.business) { $0.save(saved) }
        Haptics.success()
    }
}

struct BusinessCostEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var cost: BusinessExpense
    private let isNew: Bool

    init(cost: BusinessExpense? = nil) {
        _cost = State(initialValue: cost ?? BusinessExpense(amount: 0, label: ""))
        isNew = cost == nil
    }

    var body: some View {
        SheetForm(title: isNew ? tr("Dépense") : tr("Modifier la dépense"), canSave: cost.amount > 0, onSave: save) {
            Section {
                NumberRow(title: tr("Montant"), value: $cost.amount, unit: model.settings.currencyCode)
                TextField(tr("Libellé (publicité, matériel…)"), text: $cost.label)
                DatePicker(tr("Date"), selection: $cost.date, displayedComponents: .date).environment(\.locale, Fmt.locale)
            }
            if !isNew {
                Section {
                    Button(tr("Supprimer la dépense"), role: .destructive) {
                        let id = cost.id
                        model.update(\.business) { $0.expenses.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        var saved = cost
        saved.label = saved.label.trimmed.isEmpty ? tr("Dépense") : saved.label.trimmed
        model.update(\.business) { $0.save(saved) }
    }
}

struct MRREditor: View {
    @Environment(AppModel.self) private var model
    @State private var snapshot = SubscriptionSnapshot(month: Date(), mrr: 0, subscribers: 0)

    var body: some View {
        SheetForm(title: tr("Revenu récurrent"), canSave: snapshot.mrr > 0, onSave: save) {
            DatePicker(tr("Mois"), selection: $snapshot.month, displayedComponents: .date).environment(\.locale, Fmt.locale)
            NumberRow(title: tr("MRR"), value: $snapshot.mrr, unit: model.settings.currencyCode)
            IntRow(title: tr("Abonnés"), value: $snapshot.subscribers)
        }
        .onAppear {
            if let last = model.business.subscriptions.max(by: { $0.month < $1.month }) {
                snapshot.mrr = last.mrr
                snapshot.subscribers = last.subscribers
            }
        }
    }

    private func save() {
        let saved = snapshot
        let cal = DateMath.calendar
        model.update(\.business) { state in
            state.subscriptions.removeAll { cal.isDate($0.month, equalTo: saved.month, toGranularity: .month) }
            state.subscriptions.append(saved)
        }
    }
}

// MARK: - Entreprises cotées

struct MarketsSpaceSections: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var results: [CompanyRef] = []
    @State private var isSearching = false
    @State private var message: String?

    var body: some View {
        Section {
            ForEach(model.following.followed) { ref in
                NavigationLink {
                    CompanyDetailView(ref: ref)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ref.name)
                            Text(ref.ticker).font(.caption).foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        if let revenue = model.companies[ref.cik]?.latestRevenue {
                            Text(BigNumber.compact(revenue.value)).foregroundStyle(Color.secondary).monospacedDigit()
                        } else {
                            Text("—").foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in model.update(\.following) { $0.followed.remove(atOffsets: offsets) } }
            .onMove { from, to in model.update(\.following) { $0.followed.move(fromOffsets: from, toOffset: to) } }
        } header: {
            Text(tr("Entreprises suivies"))
        } footer: {
            Text(tr("Chiffres officiels déposés à la SEC (EDGAR, domaine public) : revenus, bénéfice, marge, croissance. Sociétés cotées aux États-Unis."))
        }
        .task {
            for ref in model.following.followed {
                await model.refreshCompany(ref)
            }
        }

        Section(tr("Ajouter une entreprise")) {
            HStack {
                TextField(tr("Nom ou symbole (Tesla, NVDA…)"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { Task { await search() } }
                if isSearching {
                    ProgressView()
                } else {
                    Button(tr("Chercher")) { Task { await search() } }
                        .disabled(query.trimmed.isEmpty)
                }
            }
            if let message {
                HintRow(text: message)
            }
            ForEach(results) { ref in
                let followed = model.following.followed.contains { $0.cik == ref.cik }
                Button {
                    guard !followed else { return }
                    model.update(\.following) { $0.followed.append(ref) }
                    Task { await model.refreshCompany(ref) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ref.name).foregroundStyle(Color.primary)
                            Text(ref.ticker).font(.caption).foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        Image(systemName: followed ? "checkmark.circle.fill" : "plus.circle").foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    private func search() async {
        let text = query.trimmed
        guard !text.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await CompanyService.search(text)
            message = results.isEmpty ? tr("Aucune société trouvée. Seules les sociétés déposant à la SEC sont disponibles.") : nil
        } catch {
            message = tr("La SEC ne répond pas. Réessaie dans un instant.")
        }
    }
}

struct CompanyDetailView: View {
    let ref: CompanyRef
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            if let company = model.companies[ref.cik] {
                Section(tr("Revenus annuels")) {
                    ForEach(company.annualRevenue.reversed(), id: \.label) { period in
                        ValueRow(title: period.label, value: BigNumber.compact(period.value))
                    }
                }
                Section(tr("Bénéfice net")) {
                    ForEach(company.annualNetIncome.reversed(), id: \.label) { period in
                        ValueRow(title: period.label, value: BigNumber.compact(period.value))
                    }
                }
                Section(tr("Indicateurs")) {
                    if let margin = company.netMargin { ValueRow(title: tr("Marge nette"), value: Fmt.percent(margin, decimals: 1)) }
                    if let growth = company.revenueGrowth { ValueRow(title: tr("Croissance des revenus"), value: Fmt.signedPercent(growth * 100)) }
                    if let shares = company.sharesOutstanding { ValueRow(title: tr("Actions en circulation"), value: tr("\(TF.decimal(shares / 1_000_000_000, 2)) milliards")) }
                    ValueRow(title: tr("Mis à jour"), value: Fmt.shortDay(company.fetchedAt))
                }
            } else {
                HintRow(text: tr("Chargement des états financiers…"))
            }
            Section {
                HintRow(text: tr("Source : SEC EDGAR (données XBRL des dépôts 10-K et 10-Q). À titre informatif, pas un conseil d'investissement."))
            }
        }
        .styledList()
        .navigationTitle(ref.ticker)
        .task { await model.refreshCompany(ref) }
    }
}
