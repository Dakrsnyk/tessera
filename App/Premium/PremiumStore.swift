import Foundation
import Observation
import StoreKit

/// StoreKit 2 purchases. The App Store is the source of truth; the result is cached in
/// the shared store so widgets and offline launches know the status.
@MainActor
@Observable
final class PremiumStore {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    enum PurchaseOutcome: Equatable {
        case success, pending, cancelled, failed(String)
    }

    private(set) var products: [Product] = []
    private(set) var loadState: LoadState = .idle
    private(set) var purchasingID: String?
    private(set) var isRestoring = false
    /// Whether the user can still claim the free trial (once per Apple account, for the whole group).
    private(set) var isIntroEligible = false

    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {}

    func start(model: AppModel) {
        guard self.model == nil else { return }
        self.model = model
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case let .verified(transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    var monthly: Product? { products.first { $0.id == PremiumConfiguration.monthlyID } }
    var yearly: Product? { products.first { $0.id == PremiumConfiguration.yearlyID } }
    var lifetime: Product? { products.first { $0.id == PremiumConfiguration.lifetimeID } }

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let fetched = try await Product.products(for: PremiumConfiguration.allProductIDs)
            products = PremiumConfiguration.allProductIDs.compactMap { id in fetched.first { $0.id == id } }
            if let subscription = monthly?.subscription ?? yearly?.subscription {
                isIntroEligible = await subscription.isEligibleForIntroOffer
            }
            loadState = products.isEmpty ? .failed(tr("Les offres ne sont pas encore disponibles.")) : .loaded
        } catch {
            loadState = .failed(tr("Impossible de joindre l'App Store. Vérifie ta connexion."))
        }
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        purchasingID = product.id
        defer { purchasingID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    return .failed(tr("L'achat n'a pas pu être vérifié."))
                }
                await transaction.finish()
                await refreshEntitlements()
                return .success
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed(tr("Réponse inattendue de l'App Store."))
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// What « Restaurer mes achats » found.
    enum RestoreOutcome: Equatable {
        case restored
        case notFound
        /// The person closed the Apple Account sign-in: nothing to say.
        case cancelled
        /// The App Store could not be reached (no connection, server): « nothing found » would be false.
        case failed
    }

    /// Syncs with the App Store, then reports whether Premium was found. Premium found in the purchases already on
    /// the iPhone counts even when the sync failed.
    func restore() async -> RestoreOutcome {
        isRestoring = true
        defer { isRestoring = false }
        var syncError: Error?
        do { try await AppStore.sync() } catch { syncError = error }
        await refreshEntitlements()
        if model?.isPremium ?? false { return .restored }
        guard let syncError else { return .notFound }
        if let storeError = syncError as? StoreKitError, case .userCancelled = storeError { return .cancelled }
        return .failed
    }

    /// The message shown after a restore; nil when the person cancelled.
    static func message(for outcome: RestoreOutcome) -> String? {
        switch outcome {
        case .restored: tr("Ton accès Premium est rétabli.")
        case .notFound: tr("Aucun achat Premium trouvé pour ce compte Apple.")
        case .cancelled: nil
        case .failed: tr("L'App Store n'a pas pu être joint. Vérifie ta connexion, puis réessaie.")
        }
    }

    func refreshEntitlements() async {
        guard let model else { return }
        var state = model.premium
        var active = false
        var productID: String?
        var expiration: Date?

        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  PremiumConfiguration.allProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if transaction.productType == .nonConsumable {
                active = true
                productID = transaction.productID
                expiration = nil
                break
            }
            if let date = transaction.expirationDate, date > Date() {
                active = true
                productID = transaction.productID
                expiration = max(expiration ?? date, date)
            }
        }

        state.isActive = active
        state.productID = productID
        state.expirationDate = expiration
        state.verifiedAt = Date()
        model.updatePremium(state)
    }

    // MARK: Display helpers

    func monthlyEquivalent(of product: Product) -> String? {
        guard product.id == PremiumConfiguration.yearlyID else { return nil }
        let monthly = product.price / 12
        return monthly.formatted(product.priceFormatStyle)
    }

    /// Savings of the yearly plan compared with paying monthly for 12 months.
    var yearlySavingsPercent: Int? {
        guard let monthly, let yearly else { return nil }
        let fullYear = monthly.price * 12
        guard fullYear > 0 else { return nil }
        let ratio = (fullYear - yearly.price) / fullYear
        let percent = NSDecimalNumber(decimal: ratio * 100).intValue
        return percent > 0 ? percent : nil
    }

    /// The only introductory offer: a free trial (7 days, on the monthly and the yearly plan). Days of the
    /// trial of a plan when the person can still claim it (once per Apple account, for the whole group).
    func trialDays(for product: Product) -> Int? {
        guard isIntroEligible, let subscription = product.subscription, let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        return Self.trialDays(unit: offer.period.unit, value: offer.period.value, periods: offer.periodCount)
    }

    /// Length of a free trial in days (1 week = 7 days); nil when it is not a day, week or month count.
    static func trialDays(unit: Product.SubscriptionPeriod.Unit, value: Int, periods: Int = 1) -> Int? {
        let perUnit: Int
        switch unit {
        case .day: perUnit = 1
        case .week: perUnit = 7
        case .month: perUnit = 30
        default: return nil
        }
        let days = perUnit * value * max(periods, 1)
        return days > 0 ? days : nil
    }

    /// « 7 jours gratuits, puis 6,99 $ par mois » when the trial can still be claimed, else nil.
    func introDescription(for product: Product) -> String? {
        guard let days = trialDays(for: product), let subscription = product.subscription else { return nil }
        let regular = Self.periodText(product.displayPrice, subscription.subscriptionPeriod)
        return tr("\(days) \(Fmt.plural(days, tr("jour gratuit"), tr("jours gratuits"))), puis \(regular)")
    }

    /// « 6,99 $ par mois », « 59,99 $ par an ».
    static func periodText(_ price: String, _ period: Product.SubscriptionPeriod) -> String {
        switch (period.unit, period.value) {
        case (.month, 1): tr("\(price) par mois")
        case (.year, 1): tr("\(price) par an")
        case (.week, 1): tr("\(price) par semaine")
        default: tr("\(price) par période")
        }
    }
}
