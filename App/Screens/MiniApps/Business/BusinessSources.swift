import SwiftUI
import UniformTypeIdentifiers

/// « Ventes automatiques »: Stripe, read-only and synced by itself, and the import of a file exported from
/// a sales service (Stripe, Shopify, a bank, a spreadsheet), so the sales don't have to be typed one by one.
/// The last sync, its result and its error are always shown.
struct BusinessSourcesCard: View {
    @Environment(AppModel.self) private var model
    @State private var connecting = false
    @State private var importing = false
    @State private var preview: BusinessImportPreview?
    @State private var importError: String?
    @State private var isSyncing = false
    @State private var confirmsDisconnect = false

    private var accentHex: String { BusinessFormat.accentHex }

    var body: some View {
        let connections = model.business.connections
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Ventes automatiques"))
            MiniRowsCard {
                if let stripe = connections.stripe {
                    VStack(alignment: .leading, spacing: 8) {
                        MiniRow(symbol: "creditcard.and.123", colorHex: "635BFF", title: stripe.isTestMode ? tr("Stripe (mode test)") : "Stripe",
                                detail: stripeDetail(stripe), showsChevron: false)
                        if let error = stripe.lastError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color(hex: BusinessFormat.badHex))
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("stripe-error")
                        }
                        if let codes = stripe.unconvertedCurrencies, !codes.isEmpty {
                            Button {
                                Task {
                                    isSyncing = true
                                    await StripeSync.sync(model: model, convertsCurrencies: false)
                                    isSyncing = false
                                }
                            } label: {
                                Label(tr("Synchroniser sans conversion"), systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline)
                            }
                            .disabled(isSyncing)
                            .accessibilityIdentifier("stripe-sync-unconverted")
                        } else if let note = conversionNote(stripe) {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    isSyncing = true
                                    await StripeSync.sync(model: model)
                                    isSyncing = false
                                }
                            } label: {
                                Label(isSyncing ? tr("Synchronisation…") : tr("Synchroniser"), systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .disabled(isSyncing)
                            .accessibilityIdentifier("stripe-sync")
                            Spacer()
                            Button(tr("Déconnecter"), role: .destructive) { confirmsDisconnect = true }
                                .font(.subheadline)
                        }
                        .padding(.bottom, 8)
                    }
                } else {
                    Button {
                        connecting = true
                    } label: {
                        MiniRow(symbol: "creditcard.and.123", colorHex: "635BFF", title: tr("Connecter Stripe"),
                                detail: tr("Ventes, remboursements et frais, en lecture seule"))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("stripe-connect")
                }
                MiniDivider()
                Button {
                    importing = true
                } label: {
                    MiniRow(symbol: "doc.badge.arrow.up", colorHex: accentHex, title: tr("Importer un fichier CSV"),
                            detail: connections.lastImport.map { tr("Dernier : \($0.fileName), \(Fmt.shortDay($0.date))") }
                                ?? tr("Export de Stripe, Shopify, ta banque ou un tableur"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("business-import")
            }
            MiniFootnote(text: tr("Les données vont directement de ton iPhone à Stripe, sans passer par Ardane. Une vente déjà importée n'est jamais ajoutée deux fois."))
        }
        .task { await StripeSync.syncIfDue(model: model) }
        .sheet(isPresented: $connecting) { StripeConnectSheet() }
        .sheet(item: $preview) { BusinessImportSheet(preview: $0) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]) { result in
            read(result)
        }
        .alert(tr("Import impossible"), isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button(tr("OK")) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .confirmationDialog(tr("Déconnecter Stripe ?"), isPresented: $confirmsDisconnect, titleVisibility: .visible) {
            Button(tr("Déconnecter et garder les ventes")) { StripeSync.disconnect(model: model, removingEntries: false) }
            Button(tr("Déconnecter et retirer ses ventes"), role: .destructive) { StripeSync.disconnect(model: model, removingEntries: true) }
        } message: {
            Text(tr("La clé est effacée de ton iPhone. Pense aussi à la supprimer dans ton tableau de bord Stripe."))
        }
    }

    private func stripeDetail(_ link: BusinessConnections.StripeLink) -> String {
        guard let last = link.lastSync else { return tr("Clé \(link.keyHint) · jamais synchronisé") }
        let time = Fmt.time(last, uses24Hour: model.settings.uses24HourClock)
        let when = DateMath.isSameDay(last, Date()) ? tr("aujourd'hui à \(time)") : tr("le \(Fmt.shortDay(last)) à \(time)")
        let added = link.lastResult.map { $0.added > 0 ? tr(" · \(Fmt.plural($0.added, tr("nouvelle opération"), tr("nouvelles opérations")))") : "" } ?? ""
        return tr("Synchronisé \(when)\(added)")
    }

    /// « Montants en USD convertis au taux de référence de la BCE. », and the currencies the ECB doesn't
    /// publish that are kept as Stripe gives them. Never the app's currency (it may have changed since).
    private func conversionNote(_ link: BusinessConnections.StripeLink) -> String? {
        let home = model.settings.currencyCode.uppercased()
        var sentences: [String] = []
        let converted = (link.convertedCurrencies ?? []).filter { $0 != home }
        if !converted.isEmpty {
            let list = converted.joined(separator: ", ")
            sentences.append(tr("Montants en \(list) convertis au taux de référence de la BCE."))
        }
        let kept = (link.keptCurrencies ?? []).filter { $0 != home }
        if !kept.isEmpty {
            let list = kept.joined(separator: ", ")
            sentences.append(tr("Montants en \(list) gardés tels quels, sans conversion."))
        }
        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    private func read(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        // Excel's « Texte Unicode » is UTF-16 (it starts with its byte order mark).
        let isUTF16 = { (data: Data) in data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) }
        guard let data = try? Data(contentsOf: url),
              let text = (isUTF16(data) ? String(data: data, encoding: .utf16) : nil)
                ?? String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) else {
            importError = tr("Le fichier n'a pas pu être lu.")
            return
        }
        do {
            let batch = try BusinessCSV.parse(text)
            preview = BusinessImportPreview(fileName: url.lastPathComponent, batch: batch)
        } catch BusinessCSV.ImportError.missingColumns {
            importError = tr("Aucune colonne de date ou de montant n'a été trouvée. Le fichier doit avoir au moins une date et un montant par ligne.")
        } catch {
            importError = tr("Le fichier est vide.")
        }
    }
}

/// A file read, before its sales are added.
struct BusinessImportPreview: Identifiable {
    let id = UUID()
    let fileName: String
    let batch: BusinessBatch
}

/// What the file holds, then « Importer ». Amounts in another currency than the app's are converted first,
/// at the ECB rate of their day (one request per currency for the whole period); without the rates, the
/// person tries again or imports them as they are: never a wrong amount in silence.
struct BusinessImportSheet: View {
    let preview: BusinessImportPreview
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// The file in the app's currency (nil while the rates are being fetched).
    @State private var converted: BusinessBatch?
    @State private var history: FXHistory?
    @State private var attempt = 0
    /// What the file holds, when nothing in it says (`directionGuessed`): sales unless the person says costs.
    @State private var holdsExpenses = false
    @State private var includesPending = true

    private var home: String { model.settings.currencyCode }
    private var foreign: [String] { preview.batch.foreignCurrencies(home: home).sorted() }

    /// What « Enregistrer » imports: the file in the app's currency, nil until it is.
    private var ready: BusinessBatch? {
        if foreign.isEmpty { return preview.batch }
        guard let converted, converted.unconverted.isEmpty else { return nil }
        return converted
    }

    private var failed: Bool { !(converted?.unconverted.isEmpty ?? true) }

    /// The batch as the person chose: costs rather than sales, and with or without what isn't paid yet.
    private func chosen(_ batch: BusinessBatch) -> BusinessBatch {
        var result = batch
        if preview.batch.directionGuessed && holdsExpenses { result = result.asExpenses() }
        if !includesPending { result = result.withoutPending() }
        return result
    }

    var body: some View {
        let batch = chosen(ready ?? preview.batch)
        let pending = preview.batch.pendingCount
        let revenue = batch.sales.reduce(0) { $0 + $1.amount }
        let costs = batch.expenses.reduce(0) { $0 + $1.amount }
        SheetForm(title: tr("Importer"), canSave: ready.map(chosen).map { !$0.sales.isEmpty || !$0.expenses.isEmpty } ?? false, onSave: importReady) {
            Section {
                LabeledContent(tr("Ventes et remboursements"), value: "\(batch.sales.count)")
                LabeledContent(tr("Dépenses et frais"), value: "\(batch.expenses.count)")
                if let currency = totalsCurrency {
                    LabeledContent(tr("Chiffre d'affaires"), value: TF.money(revenue, currency))
                    LabeledContent(tr("Dépenses"), value: TF.money(costs, currency))
                } else if !failed {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(tr("Conversion en \(home)…")).foregroundStyle(.secondary)
                    }
                }
                if batch.skipped > 0 {
                    LabeledContent(tr("Lignes ignorées"), value: "\(batch.skipped)")
                }
                if let period = batch.period {
                    LabeledContent(tr("Période"), value: "\(Fmt.shortDay(period.lowerBound)) – \(Fmt.shortDay(period.upperBound))")
                }
            } header: {
                Text(preview.fileName)
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Lignes ignorées : paiements échoués ou annulés, virements vers ta banque, lignes sans date ou sans montant. Une ligne déjà importée est mise à jour, jamais ajoutée deux fois."))
                    if let note = conversionNote {
                        Text(note)
                    }
                }
            }
            if preview.batch.directionGuessed {
                Section {
                    Picker(tr("Ce fichier contient"), selection: $holdsExpenses) {
                        Text(tr("Des ventes")).tag(false)
                        Text(tr("Des dépenses")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("business-import-contents")
                } header: {
                    Text(tr("Ce fichier contient"))
                } footer: {
                    Text(tr("Rien dans le fichier n'indique si ce sont des ventes ou des dépenses : tous les montants sont positifs, sans colonne de type. Vérifie ce qu'il contient avant d'importer."))
                }
            }
            if pending > 0 {
                Section {
                    Toggle(tr("Inclure les opérations non payées (\(pending))"), isOn: $includesPending)
                        .accessibilityIdentifier("business-import-pending")
                } footer: {
                    Text(tr("Statut « à payer », « prévu » ou « en attente » dans le fichier."))
                }
            }
            if failed {
                Section {
                    if history?.unavailable.values.contains(.unreachable) ?? false {
                        Button(tr("Réessayer")) { attempt += 1 }
                    }
                    Button(tr("Importer sans conversion")) {
                        // Only the currencies without a rate stay as they came; the others are converted.
                        save(chosen(converted ?? preview.batch))
                        dismiss()
                    }
                    .accessibilityIdentifier("business-import-unconverted")
                } footer: {
                    Text(CurrencyConversion.problemMessage(for: converted?.unconverted ?? [], unavailable: history?.unavailable ?? [:]))
                        .foregroundStyle(Color(hex: BusinessFormat.badHex))
                }
            }
        }
        .task(id: attempt) { await convert() }
    }

    /// The currency of the totals: the app's once converted; the file's when the rates are missing, it has a
    /// single one and no line of it was converted; nil otherwise (while converting, a file in several
    /// currencies, or converted in part).
    private var totalsCurrency: String? {
        if ready != nil { return home }
        let batch = preview.batch
        let codes = Set(batch.entryCurrencies.values)
        guard failed, converted?.convertedCurrencies.isEmpty ?? false, codes.count == 1,
              batch.entryCurrencies.count == batch.sales.count + batch.expenses.count else { return nil }
        return codes.first
    }

    /// « Converti depuis USD au taux de référence de la BCE du jour de chaque opération (2 janv. – 31 mars). »
    private var conversionNote: String? {
        guard !foreign.isEmpty, let ready, let days = ready.rateDays else { return nil }
        let codes = ready.convertedCurrencies.sorted().joined(separator: ", ")
        let first = DateMath.date(fromKey: days.lowerBound).map(Fmt.shortDay) ?? days.lowerBound
        let last = DateMath.date(fromKey: days.upperBound).map(Fmt.shortDay) ?? days.upperBound
        let span = first == last ? first : "\(first) – \(last)"
        return tr("Converti depuis \(codes) au taux de référence de la BCE du jour de chaque opération (\(span)).")
    }

    /// The rates of the file's period, then the file converted with them.
    private func convert() async {
        guard !foreign.isEmpty else { return }
        converted = nil
        let rates = await CurrencyConversion.rates(for: preview.batch, home: home)
        history = rates
        converted = preview.batch.converted(with: rates)
    }

    private func importReady() {
        guard let ready else { return }
        save(chosen(ready))
    }

    private func save(_ batch: BusinessBatch) {
        let name = preview.fileName
        model.update(\.business) { state in
            let result = state.merge(batch)
            state.connections.lastImport = BusinessConnections.ImportRecord(fileName: name, date: Date(), result: result, skipped: batch.skipped)
        }
        Haptics.success()
    }
}

/// Connecting Stripe: how to make a restricted key that can only read, then pasting it.
struct StripeConnectSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var key = ""
    @State private var isChecking = false
    @State private var failure: StripeSync.Failure?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    step(1, tr("Dans ton tableau de bord Stripe : Développeurs › Clés API › « Créer une clé restreinte »."))
                    step(2, tr("Donne-lui une seule autorisation : « Balance transactions » en lecture (Read). Tout le reste : aucune."))
                    step(3, tr("Copie la clé (elle commence par rk_live_) et colle-la ici."))
                    Button(tr("Ouvrir les clés API de Stripe")) {
                        if let url = URL(string: "https://dashboard.stripe.com/apikeys") { openURL(url) }
                    }
                } header: {
                    Text(tr("En lecture seule"))
                } footer: {
                    Text(tr("Ardane ne demande jamais ton mot de passe ni ta clé secrète. La clé restreinte reste dans le trousseau de ton iPhone, et ne sert qu'à lire tes ventes, remboursements et frais."))
                }
                Section {
                    SecureField(tr("Clé restreinte (rk_…)"), text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("stripe-key")
                    if let failure {
                        Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(hex: BusinessFormat.badHex))
                    }
                }
            }
            .styledList()
            .navigationTitle(tr("Connecter Stripe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isChecking {
                        ProgressView()
                    } else {
                        Button(tr("Connecter")) {
                            Task {
                                isChecking = true
                                failure = await StripeSync.connect(key: key, model: model)
                                isChecking = false
                                if failure == nil { dismiss() }
                            }
                        }
                        .disabled(key.trimmed.isEmpty)
                        .accessibilityIdentifier("stripe-connect-save")
                    }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color(hex: "635BFF"), in: Circle())
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
