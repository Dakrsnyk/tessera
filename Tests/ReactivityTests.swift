import XCTest
@testable import Tessera

/// A double tap runs an action once; a tap after a pause runs it again.
@MainActor
final class ReactivityTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testASecondTapRightAfterTheFirstIsIgnored() {
        let guardian = TapGuard()
        var count = 0
        XCTAssertTrue(guardian.run(at: start) { count += 1 })
        XCTAssertFalse(guardian.run(at: start.addingTimeInterval(0.1)) { count += 1 })
        XCTAssertFalse(guardian.run(at: start.addingTimeInterval(0.4)) { count += 1 })
        XCTAssertEqual(count, 1)
    }

    func testATapAfterThePauseRunsAgain() {
        let guardian = TapGuard()
        var count = 0
        guardian.run(at: start) { count += 1 }
        XCTAssertTrue(guardian.run(at: start.addingTimeInterval(0.6)) { count += 1 })
        XCTAssertEqual(count, 2)
    }

    func testTheIgnoredTapDoesNotExtendThePause() {
        let guardian = TapGuard()
        var count = 0
        guardian.run(at: start) { count += 1 }
        _ = guardian.run(at: start.addingTimeInterval(0.4)) { count += 1 }
        // 0.55 s after the first run (the ignored tap at 0.4 s did not restart the pause).
        XCTAssertTrue(guardian.run(at: start.addingTimeInterval(0.55)) { count += 1 })
        XCTAssertEqual(count, 2)
    }

    func testTheIntervalCanBeChosen() {
        let guardian = TapGuard()
        var count = 0
        guardian.run(at: start, within: 2) { count += 1 }
        XCTAssertFalse(guardian.run(at: start.addingTimeInterval(1.5), within: 2) { count += 1 })
        XCTAssertTrue(guardian.run(at: start.addingTimeInterval(2.1), within: 2) { count += 1 })
        XCTAssertEqual(count, 2)
    }
}
