import Foundation
#if canImport(FinanceKit)
import FinanceKit
#endif

/// Premium : les achats faits avec les cartes de Cartes (Wallet) arrivent seuls dans les dépenses de Finances, lus
/// sur l'iPhone par FinanceKit, sans aucun raccourci à créer (demande du PDG, 2026-11-16).
///
/// Apple n'ouvre FinanceKit qu'aux États-Unis (iOS 17.4 : Apple Card, Apple Cash, Épargne) et au Royaume-Uni
/// (iOS 18.4 : banques reliées à Cartes), et seulement à une app qui a reçu son autorisation
/// (`com.apple.developer.financekit`, demandée par le titulaire du compte développeur). Sans cette autorisation, le
/// système fermerait l'app au premier appel : tant qu'elle n'est pas dans l'app, la clé `ArdaneFinanceKit` de
/// l'Info.plist reste à NO et FinanceKit n'est jamais appelé. Ailleurs, l'automatisation « Transaction » de
/// Raccourcis reste la voie (gratuite), comme avant. Rien ne quitte l'iPhone : seuls le montant, le commerçant et la
/// date de chaque achat sont copiés dans le budget.
enum WalletImport {
    private static let enabledKey = "tessera.wallet.enabled"
    private static let sinceKey = "tessera.wallet.since"
    private static let lastRunKey = "tessera.wallet.lastRun"

    /// The app carries Apple's authorization: the key is set to YES once the entitlement is in the signed app.
    static var isBuiltIn: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ArdaneFinanceKit") as? Bool) == true
    }

    /// Wallet data can be read by this app on this iPhone (an authorized app, a supported country and iOS).
    static var isSupported: Bool {
        guard isBuiltIn else { return false }
        #if canImport(FinanceKit)
        if #available(iOS 17.4, *) {
            return FinanceStore.isDataAvailable(.financialData)
        }
        #endif
        return false
    }

    /// The person turned the import on (it runs only with Premium).
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// The last time the purchases were read.
    static var lastRun: Date? {
        UserDefaults.standard.object(forKey: lastRunKey) as? Date
    }

    enum Outcome: Equatable {
        case enabled
        case denied
        case unavailable
        case failed
    }

    /// Asks iOS for the access to the cards of Wallet (the system sheet), then reads the purchases of the month.
    @MainActor
    static func enable(model: AppModel) async -> Outcome {
        guard isSupported else { return .unavailable }
        #if canImport(FinanceKit)
        if #available(iOS 17.4, *) {
            do {
                let status = try await FinanceStore.shared.requestAuthorization()
                guard status == .authorized else { return .denied }
                isEnabled = true
                if UserDefaults.standard.object(forKey: sinceKey) == nil {
                    // The month in progress, from its first day: nothing older is read.
                    UserDefaults.standard.set(BudgetMath.monthInterval(Date()).start, forKey: sinceKey)
                }
                await sync(model: model)
                return .enabled
            } catch {
                return .failed
            }
        }
        #endif
        return .unavailable
    }

    /// Stops reading Wallet (the expenses already added stay).
    static func disable() {
        isEnabled = false
    }

    /// Reads the purchases made since the last reading (three days back, for a purchase still pending then) and adds
    /// the new ones as Apple Pay expenses. Premium only; does nothing when the import is off or not possible here.
    @MainActor
    static func sync(model: AppModel) async {
        guard model.isPremium, isEnabled, isSupported else { return }
        #if canImport(FinanceKit)
        if #available(iOS 17.4, *) {
            do {
                guard try await FinanceStore.shared.authorizationStatus() == .authorized else { return }
                let now = Date()
                let stored = (UserDefaults.standard.object(forKey: sinceKey) as? Date) ?? BudgetMath.monthInterval(now).start
                let since = stored.addingTimeInterval(-3 * 86_400)
                let query = TransactionQuery(sortDescriptors: [SortDescriptor(\FinanceKit.Transaction.transactionDate, order: .reverse)],
                                             predicate: nil, limit: 500, offset: nil)
                let purchases = try await FinanceStore.shared.transactions(query: query)
                    .filter { $0.transactionDate >= since && isPurchase($0) }
                if !purchases.isEmpty {
                    model.update(\.budget) { state in
                        for purchase in purchases.reversed() {
                            state.addWalletPurchase(id: purchase.id,
                                                    amount: NSDecimalNumber(decimal: purchase.transactionAmount.amount).doubleValue,
                                                    merchant: purchase.merchantName ?? purchase.transactionDescription,
                                                    date: purchase.transactionDate)
                        }
                    }
                }
                UserDefaults.standard.set(now, forKey: sinceKey)
                UserDefaults.standard.set(now, forKey: lastRunKey)
            } catch {
                // Read again at the next opening: nothing is lost, the reading starts from the same day.
            }
        }
        #endif
    }

    #if canImport(FinanceKit)
    /// A purchase paid with a card: money going out at a shop, in person or online. Not a refund, a transfer, a fee,
    /// the payment of the card itself, nor a purchase the bank refused.
    @available(iOS 17.4, *)
    private static func isPurchase(_ transaction: FinanceKit.Transaction) -> Bool {
        guard transaction.creditDebitIndicator == .debit else { return false }
        guard transaction.status != .rejected, transaction.status != .memo else { return false }
        return transaction.transactionType == .pointOfSale || transaction.transactionType == .unknown
    }
    #endif
}
