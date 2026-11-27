import XCTest
@testable import Ardane

/// The welcome offer comes back once, three days after the setup, after « Plus tard ».
final class WelcomeOfferReturnTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    func testDueOnlyAfterThreeDaysAndOnce() {
        XCTAssertFalse(WelcomeOfferReturn.isDue(since: nil, returned: false, now: start))
        XCTAssertFalse(WelcomeOfferReturn.isDue(since: start, returned: false, now: start.addingTimeInterval(2 * 86_400)))
        XCTAssertTrue(WelcomeOfferReturn.isDue(since: start, returned: false, now: start.addingTimeInterval(3 * 86_400)))
        XCTAssertFalse(WelcomeOfferReturn.isDue(since: start, returned: true, now: start.addingTimeInterval(30 * 86_400)))
    }

    func testFirstLaunchStartsTheDelayThenComesBackOnce() throws {
        let suite = "WelcomeOfferReturnTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(WelcomeOfferReturn.takeIfDue(defaults: defaults, now: start))
        XCTAssertFalse(WelcomeOfferReturn.takeIfDue(defaults: defaults, now: start.addingTimeInterval(86_400)))
        XCTAssertTrue(WelcomeOfferReturn.takeIfDue(defaults: defaults, now: start.addingTimeInterval(4 * 86_400)))
        XCTAssertFalse(WelcomeOfferReturn.takeIfDue(defaults: defaults, now: start.addingTimeInterval(5 * 86_400)))
    }
}
