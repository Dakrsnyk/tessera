import XCTest
@testable import Ardane

/// The only introductory offer (decision of 2026-10-26): a free trial of 7 days on the monthly and the yearly
/// plan (same subscription group: Apple grants one introductory offer per group and per person), none on the
/// lifetime purchase. Reads Config/Ardane.storekit, the local StoreKit configuration.
@MainActor
final class PremiumTrialOfferTests: XCTestCase {
    private func configuration() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/Ardane.storekit")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("Config/Ardane.storekit is not readable from here") }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func subscriptions() throws -> [[String: Any]] {
        let groups = try XCTUnwrap(try configuration()["subscriptionGroups"] as? [[String: Any]])
        XCTAssertEqual(groups.count, 1, "One group: a person gets a single introductory offer")
        return groups.flatMap { $0["subscriptions"] as? [[String: Any]] ?? [] }
    }

    func testMonthlyAndYearlyHaveOneFreeWeekTrial() throws {
        let subscriptions = try subscriptions()
        for id in [PremiumConfiguration.monthlyID, PremiumConfiguration.yearlyID] {
            let plan = try XCTUnwrap(subscriptions.first { $0["productID"] as? String == id }, id)
            let offer = try XCTUnwrap(plan["introductoryOffer"] as? [String: Any], "\(id) has a trial")
            XCTAssertEqual(offer["paymentMode"] as? String, "free", id)
            XCTAssertEqual(offer["subscriptionPeriod"] as? String, "P1W", id)
            XCTAssertNil(offer["numberOfPeriods"], id)
            XCTAssertTrue((plan["adHocOffers"] as? [Any] ?? []).isEmpty, id)
            XCTAssertTrue((plan["codeOffers"] as? [Any] ?? []).isEmpty, id)
        }
    }

    func testNoOtherIntroductoryOfferAndNothingOnLifetime() throws {
        let subscriptions = try subscriptions()
        XCTAssertEqual(Set(subscriptions.compactMap { $0["productID"] as? String }),
                       [PremiumConfiguration.monthlyID, PremiumConfiguration.yearlyID])
        XCTAssertEqual(subscriptions.compactMap { $0["introductoryOffer"] as? [String: Any] }.count, 2)
        let products = try XCTUnwrap(try configuration()["products"] as? [[String: Any]])
        let lifetime = try XCTUnwrap(products.first { $0["productID"] as? String == PremiumConfiguration.lifetimeID })
        XCTAssertNil(lifetime["introductoryOffer"])
        XCTAssertEqual(lifetime["type"] as? String, "NonConsumable")
    }

    func testNoOldWelcomeOfferLeftInTheConfiguration() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/Ardane.storekit")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw XCTSkip("Config/Ardane.storekit is not readable from here") }
        XCTAssertFalse(text.contains("payAsYouGo"))
        XCTAssertFalse(text.contains("4,99") || text.contains("4.99"))
    }

    func testTrialLengthInDays() {
        XCTAssertEqual(PremiumStore.trialDays(unit: .week, value: 1), 7)
        XCTAssertEqual(PremiumStore.trialDays(unit: .day, value: 3), 3)
        XCTAssertEqual(PremiumStore.trialDays(unit: .month, value: 1), 30)
        XCTAssertNil(PremiumStore.trialDays(unit: .year, value: 1))
        XCTAssertNil(PremiumStore.trialDays(unit: .day, value: 0))
    }

    func testRestoreSaysWhatHappenedAndStaysQuietWhenCancelled() {
        XCTAssertNil(PremiumStore.message(for: .cancelled), "La connexion annulée n'affiche rien")
        let shown = [PremiumStore.RestoreOutcome.restored, .notFound, .failed].map { PremiumStore.message(for: $0) }
        XCTAssertTrue(shown.allSatisfy { $0?.isEmpty == false })
        XCTAssertEqual(Set(shown.compactMap { $0 }).count, 3, "« Aucun achat » et « App Store injoignable » ne se confondent plus")
    }

    func testProductTextsFitTheLimitsOfAppStoreConnect() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/Ardane.storekit")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("Config/Ardane.storekit is not readable from here") }
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var products = root["nonRenewingSubscriptions"] as? [[String: Any]] ?? []
        products += root["products"] as? [[String: Any]] ?? []
        for group in root["subscriptionGroups"] as? [[String: Any]] ?? [] {
            products += (group["subscriptions"] as? [[String: Any]] ?? []).map { $0.merging(["isSubscription": true]) { a, _ in a } }
        }
        XCTAssertEqual(products.count, 3)
        for product in products {
            let limit = product["isSubscription"] as? Bool == true ? 55 : 45
            for localization in product["localizations"] as? [[String: Any]] ?? [] {
                let name = localization["displayName"] as? String ?? ""
                let text = localization["description"] as? String ?? ""
                XCTAssertTrue((2...30).contains(name.count), "nom « \(name) »")
                XCTAssertLessThanOrEqual(text.count, limit, "description « \(text) »")
            }
        }
    }

    func testTheFreePlanStillKeepsThreeWidgets() {
        XCTAssertEqual(AppModel.freeDesignLimit, 3)
    }
}
