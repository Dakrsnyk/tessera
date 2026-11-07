import XCTest
import StoreKit
import StoreKitTest
@testable import Ardane

/// Audit 24.C-A1: billing grace period, trial eligibility recomputed, clear purchase errors, terms link.
@MainActor
final class Audit24PremiumTests: XCTestCase {
    private var session: SKTestSession!
    private var directory: URL!

    override func setUp() async throws {
        try await super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        session?.resetToDefaultState()
        session?.clearTransactions()
        session = nil
        if let directory { try? FileManager.default.removeItem(at: directory) }
        try await super.tearDown()
    }

    /// A store on a StoreKit test session (skipped when the configuration is not readable), products loaded.
    private func makeStore() async throws -> PremiumStore {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/Ardane.storekit")
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw XCTSkip("Config/Ardane.storekit is not readable from here")
        }
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        let model = AppModel(store: SharedStore(directory: directory))
        let store = PremiumStore()
        store.start(model: model)
        for _ in 0..<200 {
            if store.loadState == .loaded { return store }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("The products did not load in 20 seconds")
        return store
    }

    // MARK: Billing grace period

    func testSubscriptionKeepsAccessUntilItsDate() {
        let now = Date()
        XCTAssertTrue(PremiumStore.subscriptionGrantsAccess(expiration: now.addingTimeInterval(60), now: now, renewalState: .subscribed))
        XCTAssertTrue(PremiumStore.subscriptionGrantsAccess(expiration: now.addingTimeInterval(60), now: now, renewalState: nil))
    }

    func testBillingGracePeriodKeepsAccessPastTheDate() {
        let now = Date()
        let past = now.addingTimeInterval(-5 * 86_400)
        XCTAssertTrue(PremiumStore.subscriptionGrantsAccess(expiration: past, now: now, renewalState: .inGracePeriod),
                      "Apple keeps access while it retries the payment in the grace period")
    }

    func testExpiredRetryingOrRevokedSubscriptionHasNoAccess() {
        let now = Date()
        let past = now.addingTimeInterval(-86_400)
        XCTAssertFalse(PremiumStore.subscriptionGrantsAccess(expiration: past, now: now, renewalState: .expired))
        XCTAssertFalse(PremiumStore.subscriptionGrantsAccess(expiration: past, now: now, renewalState: .inBillingRetryPeriod))
        XCTAssertFalse(PremiumStore.subscriptionGrantsAccess(expiration: past, now: now, renewalState: .revoked))
        XCTAssertFalse(PremiumStore.subscriptionGrantsAccess(expiration: past, now: now, renewalState: nil))
    }

    // MARK: Trial eligibility

    func testEligibilityIsRecomputedAfterTheTrialIsClaimedElsewhere() async throws {
        let store = try await makeStore()
        XCTAssertTrue(store.isIntroEligible, "A new Apple account can claim the trial")

        // Bought outside the store's own purchase (another device, the App Store): nothing recomputed yet.
        _ = try await session.buyProduct(identifier: PremiumConfiguration.monthlyID)
        await store.refreshIntroEligibility()

        XCTAssertFalse(store.isIntroEligible, "The paywall must not promise a trial that is gone")
        XCTAssertNil(store.trialDays(for: try XCTUnwrap(store.yearly)))
    }

    // MARK: Purchase errors

    func testPurchaseErrorsHaveClearMessages() {
        let network = PremiumStore.message(forPurchaseError: StoreKitError.networkError(URLError(.notConnectedToInternet)))
        let urlLost = PremiumStore.message(forPurchaseError: URLError(.networkConnectionLost))
        let unavailable = PremiumStore.message(forPurchaseError: Product.PurchaseError.productUnavailable)
        let notAllowed = PremiumStore.message(forPurchaseError: Product.PurchaseError.purchaseNotAllowed)
        let unknown = PremiumStore.message(forPurchaseError: StoreKitError.unknown)
        XCTAssertEqual(network, urlLost)
        XCTAssertNotEqual(network, unavailable)
        XCTAssertNotEqual(unavailable, notAllowed)
        for message in [network, unavailable, notAllowed, unknown] {
            XCTAssertFalse(message.isEmpty)
        }
        let raw = NSError(domain: "raw", code: 7, userInfo: [NSLocalizedDescriptionKey: "RAW-SYSTEM-TEXT"])
        XCTAssertFalse(PremiumStore.message(forPurchaseError: raw).contains("RAW-SYSTEM-TEXT"), "Never the raw system text")
    }

    // MARK: Terms

    func testTermsLinkIsTheHostedPage() {
        XCTAssertEqual(PremiumConfiguration.termsURL.absoluteString, "https://ardane.app/terms.html")
    }
}
