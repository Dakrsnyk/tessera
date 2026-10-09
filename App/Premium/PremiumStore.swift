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
    /// Whether the user can still claim the welcome offer (once per Apple account, for the whole group).
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

    /// Syncs with the App Store, then reports whether Premium was found.
    func restore() async -> Bool {
        isRestoring = true
        defer { isRestoring = false }
        try? await AppStore.sync()
        await refreshEntitlements()
        return model?.isPremium ?? false
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

    /// The welcome offer of a plan when the person can still claim it: its price, for how long, then
    /// the price that follows (« 4,99 $ par mois les 3 premiers mois, puis 6,99 $ par mois »).
    func introDescription(for product: Product) -> String? {
        guard isIntroEligible, let subscription = product.subscription, let offer = subscription.introductoryOffer else { return nil }
        let regular = Self.periodText(product.displayPrice, subscription.subscriptionPeriod)
        switch offer.paymentMode {
        case .payAsYouGo:
            let months = offer.period.unit == .month ? offer.period.value * offer.periodCount : offer.periodCount
            let first = Self.periodText(offer.displayPrice, offer.period)
            return tr("\(first) les \(Fmt.plural(months, tr("premier mois"), tr("premiers mois"))), puis \(regular)")
        case .payUpFront:
            return tr("\(offer.displayPrice) pour commencer, puis \(regular)")
        case .freeTrial:
            return tr("Essai gratuit, puis \(regular)")
        default:
            return nil
        }
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
