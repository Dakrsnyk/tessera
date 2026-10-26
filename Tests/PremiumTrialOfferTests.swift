import XCTest
@testable import Tessera

/// The only introductory offer (decision of 2026-10-26): a free trial of 7 days on the monthly and the yearly
/// plan (same subscription group: Apple grants one introductory offer per group and per person), none on the
/// lifetime purchase. Reads Config/Tessera.storekit, the local StoreKit configuration.
final class PremiumTrialOfferTests: XCTestCase {
    private func configuration() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Config/Tessera.storekit")
        guard let data = try? Data(contentsOf: url) else { throw XCTSkip("Config/Tessera.storekit is not readable from here") }
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
            .appendingPathComponent("Config/Tessera.storekit")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw XCTSkip("Config/Tessera.storekit is not readable from here") }
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

    func testTheFreePlanStillKeepsThreeWidgets() {
        XCTAssertEqual(AppModel.freeDesignLimit, 3)
    }
}
