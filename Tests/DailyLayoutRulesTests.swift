import XCTest
@testable import Ardane

/// The rules of the edit mode of « Mon Quotidien »: which cards can grow or shrink, moving by one rank,
/// dropping a card onto another, and the rows the grid lays out (the same as `DailyBrief.rows`).
final class DailyLayoutRulesTests: XCTestCase {
    private let steps = DailyBrief.Tile.steps(steps: 100, goal: nil)          // half by default
    private let habits = DailyBrief.Tile.habits(done: 0, items: [])           // half by default
    private let reminders = DailyBrief.Tile.reminders([])                     // wide by default
    private let invite = DailyBrief.Tile.invite(.nutrition)                   // always wide, last

    func testGrowAndShrinkFollowTheCurrentSize() {
        XCTAssertTrue(DailyLayoutRules.canGrow(steps, wide: [:]))
        XCTAssertFalse(DailyLayoutRules.canShrink(steps, wide: [:]))
        XCTAssertFalse(DailyLayoutRules.canGrow(reminders, wide: [:]))
        XCTAssertTrue(DailyLayoutRules.canShrink(reminders, wide: [:]))
        // The person's choice wins over the card's own size.
        XCTAssertFalse(DailyLayoutRules.canGrow(steps, wide: [steps.id: true]))
        XCTAssertTrue(DailyLayoutRules.canShrink(steps, wide: [steps.id: true]))
        XCTAssertTrue(DailyLayoutRules.canGrow(reminders, wide: [reminders.id: false]))
    }

    func testAnInvitationHasOneSizeAndStaysPut() {
        XCTAssertEqual(DailyLayoutRules.allowedSizes(for: invite), [.wide])
        XCTAssertFalse(DailyLayoutRules.canGrow(invite, wide: [:]))
        XCTAssertFalse(DailyLayoutRules.canShrink(invite, wide: [:]))
        XCTAssertFalse(DailyLayoutRules.isMovable(invite))
        XCTAssertTrue(DailyLayoutRules.isMovable(steps))
        XCTAssertEqual(DailyLayoutRules.resized([:], tile: invite, to: .half), [:])
    }

    func testResizeChangesOnlyTheChosenCard() {
        let wide = DailyLayoutRules.resized(["other": false], tile: steps, to: .wide)
        XCTAssertEqual(wide, ["other": false, steps.id: true])
        XCTAssertEqual(DailyLayoutRules.size(of: steps, wide: wide), .wide)
        let half = DailyLayoutRules.resized(wide, tile: steps, to: .half)
        XCTAssertEqual(half[steps.id], false)
        XCTAssertEqual(DailyLayoutRules.size(of: steps, wide: half), .half)
    }

    func testMoveByOneRankStopsAtTheEnds() {
        let ids = ["a", "b", "c"]
        XCTAssertFalse(DailyLayoutRules.canMove(ids, id: "a", by: -1))
        XCTAssertTrue(DailyLayoutRules.canMove(ids, id: "a", by: 1))
        XCTAssertFalse(DailyLayoutRules.canMove(ids, id: "c", by: 1))
        XCTAssertFalse(DailyLayoutRules.canMove(ids, id: "zzz", by: 1))
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "b", by: -1), ["b", "a", "c"])
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "b", by: 1), ["a", "c", "b"])
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "a", by: -1), ids)
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "zzz", by: 1), ids)
    }

    func testDroppingOntoACardTakesItsPlace() {
        let ids = ["a", "b", "c", "d"]
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "a", onto: "c"), ["b", "c", "a", "d"])
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "d", onto: "b"), ["a", "d", "b", "c"])
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "a", onto: "a"), ids)
        XCTAssertEqual(DailyLayoutRules.moved(ids, id: "a", onto: "zzz"), ids)
    }

    func testTargetIsTheCardUnderTheFingerNotTheDraggedOne() {
        let frames = ["a": CGRect(x: 0, y: 0, width: 100, height: 100), "b": CGRect(x: 112, y: 0, width: 100, height: 100)]
        XCTAssertEqual(DailyLayoutRules.target(at: CGPoint(x: 150, y: 50), frames: frames, excluding: "a"), "b")
        XCTAssertNil(DailyLayoutRules.target(at: CGPoint(x: 50, y: 50), frames: frames, excluding: "a"))
        XCTAssertNil(DailyLayoutRules.target(at: CGPoint(x: 106, y: 50), frames: frames, excluding: "a"))
    }

    func testGridRowsMatchTheDashboardRows() {
        let tiles = [steps, reminders, habits, steps2, invite]
        let wide = [steps.id: false]
        let expected = DailyBrief.rows(tiles, wide: wide).map { $0.map(\.id) }
        let wides = tiles.map { DailyLayoutRules.size(of: $0, wide: wide) == .wide }
        let rows = DailyLayoutRules.rows(wides: wides).map { $0.map { tiles[$0].id } }
        XCTAssertEqual(rows, expected)
        XCTAssertEqual(DailyLayoutRules.rows(wides: [false, false, false]), [[0, 1], [2]])
        XCTAssertEqual(DailyLayoutRules.rows(wides: []), [])
    }

    /// A second half card with another id.
    private var steps2: DailyBrief.Tile { .budget(spentToday: 0, perDayLeft: nil) }

    func testOrderedKeepsUnknownCardsLast() {
        let tiles = [steps, habits, reminders]
        XCTAssertEqual(DailyLayoutRules.ordered(tiles, by: nil).map(\.id), tiles.map(\.id))
        let live = DailyLayoutRules.ordered(tiles, by: [reminders.id, steps.id])
        XCTAssertEqual(live.map(\.id), [reminders.id, steps.id, habits.id])
    }
}
