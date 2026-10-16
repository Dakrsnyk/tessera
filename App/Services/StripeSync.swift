import Foundation
import Security

/// Secrets kept in the iPhone's keychain, on this device only, readable after the first unlock. Never in
/// the shared files, the backups or the widgets.
enum SecretStore {
    private static let service = "com.dakrsnyk.ardane.secrets"

    static func save(_ value: String, for account: String) -> Bool {
        delete(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8),
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Business ← Stripe, read-only, straight from the iPhone to Stripe (no server in between, nothing sent to
/// Ardane). The person creates a restricted key in their Stripe dashboard with the single permission
/// « Balance transactions: Read »; it is kept in the keychain. Ardane never asks for a password and never
/// accepts a secret key (sk_), which could change the account.
@MainActor
enum StripeSync {
    static let keychainAccount = "stripe.restrictedKey"
    /// The first sync reads a year back; the next ones from the day before the last transaction read.
    static let firstSyncDays = 365

    enum Failure: Error, Equatable {
        case notRestrictedKey, refused, missingPermission, network, server(Int), unreadable
        /// No exchange rate for these currencies (offline, not published by the ECB, or none for the day),
        /// with why: nothing was added.
        case rates([String], message: String)

        var message: String {
            switch self {
            case .notRestrictedKey: tr("Utilise une clé restreinte (elle commence par rk_) : Ardane ne garde jamais de clé secrète.")
            case .refused: tr("Stripe a refusé la clé : elle a peut-être été supprimée ou mal copiée.")
            case .missingPermission: tr("Il manque à la clé l'autorisation « Balance transactions : lecture ».")
            case .network: tr("Impossible de joindre Stripe. Vérifie ta connexion.")
            case let .server(code): tr("Stripe ne répond pas correctement (erreur \(code)). Réessaie plus tard.")
            case .unreadable: tr("La réponse de Stripe n'a pas pu être lue.")
            case let .rates(_, message): message
            }
        }
    }

    static var isConnected: Bool { SecretStore.read(keychainAccount) != nil }

    /// Checks the key with one request, keeps it in the keychain, then syncs.
    static func connect(key raw: String, model: AppModel) async -> Failure? {
        let key = raw.trimmed
        guard key.hasPrefix("rk_live_") || key.hasPrefix("rk_test_") else { return .notRestrictedKey }
        do {
            _ = try await page(key: key, since: Date(), after: nil, limit: 1)
        } catch let failure as Failure {
            return failure
        } catch {
            return .network
        }
        guard SecretStore.save(key, for: keychainAccount) else { return .unreadable }
        model.update(\.business) { state in
            state.connections.stripe = BusinessConnections.StripeLink(keyHint: "…" + String(key.suffix(4)), isTestMode: key.hasPrefix("rk_test_"), connectedAt: Date())
        }
        let failure = await sync(model: model)
        // Connected all the same: the card tells about the missing rates and offers to sync without conversion.
        if case .rates? = failure { return nil }
        return failure
    }

    /// Reads the transactions since the last sync and merges them (no double: same id, same entry). The
    /// amounts in another currency than the app's are converted at the ECB rate of their day; when a rate
    /// is missing nothing is merged (never a wrong amount in silence), unless `convertsCurrencies` is false:
    /// the person chose to keep the currencies the last sync had no rate for as Stripe gives them (the others
    /// are still converted, and an entry converted before stays converted).
    @discardableResult
    static func sync(model: AppModel, now: Date = Date(), convertsCurrencies: Bool = true) async -> Failure? {
        guard let key = SecretStore.read(keychainAccount), let link = model.business.connections.stripe else { return nil }
        let calendar = DateMath.calendar
        // Whole days from the day before the last transaction read: each day's fees are counted in full.
        let since = link.syncedUntil.flatMap { calendar.date(byAdding: .day, value: -1, to: DateMath.startOfDay($0)) }
            ?? calendar.date(byAdding: .day, value: -firstSyncDays, to: DateMath.startOfDay(now)) ?? now
        var transactions: [StripeTransactions.Transaction] = []
        var after: String?
        do {
            for _ in 0..<30 {
                let result = try await page(key: key, since: since, after: after, limit: 100)
                transactions += result.data
                guard result.hasMore, let last = result.data.last else { break }
                after = last.id
            }
        } catch {
            let failure = (error as? Failure) ?? .network
            model.update(\.business) { state in
                state.connections.stripe?.lastError = failure.message
                state.connections.stripe?.unconvertedCurrencies = nil
            }
            return failure
        }
        let home = model.settings.currencyCode.uppercased()
        let dates = transactions.map { Date(timeIntervalSince1970: $0.created) }
        // Left as Stripe gives them: the currencies the ECB doesn't publish the person chose to keep (until it
        // does), and on a sync without conversion the ones the last sync had no rate for.
        let kept = Set(link.keptCurrencies ?? []).filter { !FXService.currencies.contains($0) }
        let chosen = convertsCurrencies ? Set<String>() : Set(link.unconvertedCurrencies ?? [])
        let asIs = kept.union(chosen)
        let foreign = Set(transactions.map { $0.currency.uppercased() }).subtracting([home])
        var history: FXHistory?
        if !foreign.isEmpty, let first = dates.min(), let last = dates.max() {
            let needed = foreign.subtracting(asIs)
            if needed.isEmpty {
                history = FXHistory(home: home)
            } else {
                history = await FXService.history(of: needed, in: home, from: first, to: last, now: now)
            }
        }
        let batch = StripeTransactions.batch(from: transactions, history: history)
        let missing = batch.unconverted.subtracting(asIs)
        if !missing.isEmpty {
            let failure = Failure.rates(missing.sorted(), message: CurrencyConversion.problemMessage(for: missing, unavailable: history?.unavailable ?? [:]))
            // The ones already chosen stay chosen: the button then leaves them all as they are.
            let codes = missing.union(chosen).sorted()
            model.update(\.business) { state in
                state.connections.stripe?.lastError = failure.message
                state.connections.stripe?.unconvertedCurrencies = codes
            }
            return failure
        }
        let newest = dates.max()
        model.update(\.business) { state in
            let result = state.merge(batch)
            guard var link = state.connections.stripe else { return }
            link.lastSync = now
            link.lastError = nil
            link.lastResult = result
            // A currency the ECB doesn't publish will never have a rate: once chosen, kept as Stripe gives it.
            let keeps = kept.union(chosen.filter { !FXService.currencies.contains($0) })
            link.keptCurrencies = keeps.isEmpty ? nil : keeps.sorted()
            link.unconvertedCurrencies = nil
            // What this sync converted, for the card (never a note left over from before).
            let converted = batch.convertedCurrencies.subtracting([home])
            link.convertedCurrencies = converted.isEmpty ? nil : converted.sorted()
            if let newest { link.syncedUntil = max(newest, link.syncedUntil ?? newest) }
            state.connections.stripe = link
        }
        return nil
    }

    /// Forgets the key (and, if asked, what Stripe brought). The entries typed by hand stay.
    static func disconnect(model: AppModel, removingEntries: Bool) {
        SecretStore.delete(keychainAccount)
        model.update(\.business) { state in
            state.connections.stripe = nil
            if removingEntries { state.removeEntries(from: .stripe) }
        }
    }

    /// Syncs again when the last sync is more than an hour old (on opening Business).
    static func syncIfDue(model: AppModel, now: Date = Date()) async {
        guard let link = model.business.connections.stripe else { return }
        if let last = link.lastSync, now.timeIntervalSince(last) < 3_600 { return }
        await sync(model: model, now: now)
    }

    private static func page(key: String, since: Date, after: String?, limit: Int) async throws -> StripeTransactions.Page {
        var components = URLComponents(string: "https://api.stripe.com/v1/balance_transactions")!
        var items = [URLQueryItem(name: "limit", value: "\(limit)"), URLQueryItem(name: "created[gte]", value: "\(Int(since.timeIntervalSince1970))")]
        if let after { items.append(URLQueryItem(name: "starting_after", value: after)) }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure.network
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 401: throw Failure.refused
        case 403: throw Failure.missingPermission
        case let code: throw Failure.server(code)
        }
        do {
            return try JSONDecoder().decode(StripeTransactions.Page.self, from: data)
        } catch {
            throw Failure.unreadable
        }
    }
}
