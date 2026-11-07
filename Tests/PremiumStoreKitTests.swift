import XCTest
import StoreKit
import StoreKitTest
@testable import Ardane

/// The real purchase code (`PremiumStore`) against a StoreKit test session built from Config/Ardane.storekit:
/// purchase, lifetime, refund, expiration (with the 3-day grace of `PremiumState`), restore, failure and the
/// free-trial eligibility. The result is read in `AppModel.premium` and in the store file on disk, never in
/// `isPremium`, which a Debug build keeps true through the test switch.
@MainActor
final class PremiumStoreKitTests: XCTestCase {
    private var session: SKTestSession!
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/Ardane.storekit")
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw XCTSkip("Config/Ardane.storekit is not readable from here")
        }
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        session?.resetToDefaultState()
        session?.clearTransactions()
        session = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
        try await super.tearDown()
    }

    /// A store connected to a model that saves in a temporary folder, with its products loaded.
    private func makeStore() async throws -> (store: PremiumStore, model: AppModel, saved: SharedStore) {
        let saved = SharedStore(directory: directory)
        let model = AppModel(store: saved)
        let store = PremiumStore()
        store.start(model: model)
        for _ in 0..<200 {
            switch store.loadState {
            case .loaded:
                return (store, model, saved)
            case .failed(let message):
                XCTFail("The products did not load: \(message)")
                return (store, model, saved)
            case .idle, .loading:
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        XCTFail("The products did not load in 20 seconds")
        return (store, model, saved)
    }

    /// Runs `body` as a user without the Debug test switch, then puts the switch back as it was.
    private func withoutDebugUnlock(_ body: () async throws -> Void) async rethrows {
        #if DEBUG
        let previous = DebugPremium.isUnlocked
        DebugPremium.setUnlocked(false)
        defer { DebugPremium.setUnlocked(previous) }
        #endif
        try await body()
    }

    func testTheThreeOffersLoadInTheConfiguredOrder() async throws {
        let (store, _, _) = try await makeStore()
        XCTAssertEqual(store.products.map(\.id), PremiumConfiguration.allProductIDs)
        XCTAssertNotNil(store.monthly)
        XCTAssertNotNil(store.yearly)
        XCTAssertNotNil(store.lifetime)
    }

    func testPurchaseOfTheMonthlyGrantsPremiumAndIsSaved() async throws {
        try await withoutDebugUnlock {
            let (store, model, _) = try await makeStore()
            XCTAssertFalse(model.premium.isActive, "Nothing bought yet")
            let monthly = try XCTUnwrap(store.monthly)

            let outcome = await store.purchase(monthly)

            XCTAssertEqual(outcome, .success)
            XCTAssertNil(store.purchasingID, "The purchase in progress is cleared")
            XCTAssertTrue(model.premium.isActive)
            XCTAssertEqual(model.premium.productID, PremiumConfiguration.monthlyID)
            let expiration = try XCTUnwrap(model.premium.expirationDate, "A subscription ends on a date")
            XCTAssertGreaterThan(expiration, Date())
            XCTAssertTrue(model.premium.hasPurchase())
            XCTAssertTrue(model.isPremium)
            // The status reaches the widgets and the next launch through the store file.
            let reread = SharedStore(directory: directory).premium
            XCTAssertTrue(reread.isActive)
            XCTAssertEqual(reread.productID, PremiumConfiguration.monthlyID)
            XCTAssertEqual(reread.expirationDate, model.premium.expirationDate)
        }
    }

    func testLifetimePurchaseHasNoExpiration() async throws {
        try await withoutDebugUnlock {
            let (store, model, _) = try await makeStore()
            let lifetime = try XCTUnwrap(store.lifetime)

            let outcome = await store.purchase(lifetime)

            XCTAssertEqual(outcome, .success)
            XCTAssertTrue(model.premium.isActive)
            XCTAssertEqual(model.premium.productID, PremiumConfiguration.lifetimeID)
            XCTAssertNil(model.premium.expirationDate)
            XCTAssertTrue(model.premium.hasPurchase(at: Date().addingTimeInterval(50 * 365 * 86_400)), "Lifetime never lapses")
        }
    }

    func testRefundRevokesPremium() async throws {
        try await withoutDebugUnlock {
            let (store, model, _) = try await makeStore()
            let lifetime = try XCTUnwrap(store.lifetime)
            let outcome = await store.purchase(lifetime)
            XCTAssertEqual(outcome, .success)
            XCTAssertTrue(model.premium.isActive)

            let latest = await Transaction.latest(for: PremiumConfiguration.lifetimeID)
            let transaction = try XCTUnwrap(latest?.unsafePayloadValue, "The purchase left a transaction")
            _ = try await session.refundTransaction(UInt(transaction.id))
            await store.refreshEntitlements()

            XCTAssertFalse(model.premium.isActive, "A refunded purchase no longer unlocks Premium")
            XCTAssertNil(model.premium.productID)
            XCTAssertFalse(model.premium.hasPurchase())
            XCTAssertFalse(SharedStore(directory: directory).premium.isActive)
        }
    }

    func testExpiredSubscriptionEndsPremiumAndTheGraceLastsThreeDays() async throws {
        try await withoutDebugUnlock {
            let (store, model, _) = try await makeStore()
            let monthly = try XCTUnwrap(store.monthly)
            let outcome = await store.purchase(monthly)
            XCTAssertEqual(outcome, .success)

            // Grace of an unsynced renewal: three days after the expiration date, not a second more.
            let expiration = try XCTUnwrap(model.premium.expirationDate)
            XCTAssertEqual(PremiumState.gracePeriod, 3 * 86_400)
            XCTAssertTrue(model.premium.hasPurchase(at: expiration.addingTimeInterval(PremiumState.gracePeriod - 1)))
            XCTAssertFalse(model.premium.hasPurchase(at: expiration.addingTimeInterval(PremiumState.gracePeriod + 1)))

            try await session.expireSubscription(productIdentifier: PremiumConfiguration.monthlyID)
            await store.refreshEntitlements()

            XCTAssertFalse(model.premium.isActive, "An expired subscription is no longer an entitlement")
            XCTAssertNil(model.premium.productID)
            XCTAssertNil(model.premium.expirationDate)
            XCTAssertFalse(model.premium.hasPurchase())
        }
    }

    func testRestoreFindsAnExistingPurchase() async throws {
        try await withoutDebugUnlock {
            let (store, model, _) = try await makeStore()
            let lifetime = try XCTUnwrap(store.lifetime)
            let outcome = await store.purchase(lifetime)
            XCTAssertEqual(outcome, .success)
            // The cached status is lost (a new iPhone, a reinstall): the purchase is still at the App Store.
            model.updatePremium(PremiumState())
            XCTAssertFalse(model.premium.isActive)

            let restored = await store.restore()

            XCTAssertEqual(restored, .restored)
            XCTAssertTrue(model.premium.isActive)
            XCTAssertEqual(model.premium.productID, PremiumConfiguration.lifetimeID)
            XCTAssertFalse(store.isRestoring)
        }
    }

    func testRestoreWithoutAnyPurchaseSaysNothingWasFound() async throws {
        try await withoutDebugUnlock {
            let (store, model, _) = try await makeStore()

            let restored = await store.restore()

            XCTAssertEqual(restored, .notFound)
            XCTAssertFalse(model.premium.isActive)
            XCTAssertFalse(store.isRestoring)
        }
    }

    func testAFailedPurchaseIsReportedAndGrantsNothing() async throws {
        try await withoutDebugUnlock {
            let (store, model, _) = try await makeStore()
            let yearly = try XCTUnwrap(store.yearly)
            session.failTransactionsEnabled = true

            let outcome = await store.purchase(yearly)

            if case .failed(let message) = outcome {
                XCTAssertFalse(message.isEmpty, "The person is told something")
            } else {
                XCTFail("A failed transaction must give .failed, not \(outcome)")
            }
            XCTAssertNil(store.purchasingID)
            XCTAssertFalse(model.premium.isActive)
            XCTAssertFalse(SharedStore(directory: directory).premium.isActive)
        }
    }

    func testTheFreeTrialIsOfferedOnlyOnceForTheWholeGroup() async throws {
        try await withoutDebugUnlock {
            let (store, _, _) = try await makeStore()
            XCTAssertTrue(store.isIntroEligible, "A new Apple account can claim the trial")
            let monthly = try XCTUnwrap(store.monthly)
            let outcome = await store.purchase(monthly)
            XCTAssertEqual(outcome, .success)

            await store.loadProducts()

            XCTAssertFalse(store.isIntroEligible, "Once subscribed, neither the monthly nor the yearly plan has a trial")
        }
    }
}
