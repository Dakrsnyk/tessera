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

    // MARK: Moves as they are seen (CI of 2026-11-07)

    /// The rows drawn on screen for an order, with the cards named in `wide` across the width.
    private func drawn(_ ids: [String], wide: Set<String>) -> [[String]] {
        DailyLayoutRules.rows(wides: ids.map { wide.contains($0) }).map { row in row.map { ids[$0] } }
    }

    private func move(_ ids: [String], _ id: String, onto target: String, wide: Set<String>) -> [String] {
        DailyLayoutRules.moved(ids, id: id, onto: target, isWide: { wide.contains($0) })
    }

    func testReadingOrderDrawsTheSameScreen() {
        let wide: Set<String> = ["W"]
        // « A » waits for its partner: it is drawn after the wide card.
        XCTAssertEqual(DailyLayoutRules.readingOrder(["A", "W", "B"], isWide: { wide.contains($0) }), ["W", "A", "B"])
        for ids in [["A", "W", "B"], ["W", "A"], ["A", "B", "W", "C"]] {
            let reading = DailyLayoutRules.readingOrder(ids, isWide: { wide.contains($0) })
            XCTAssertEqual(drawn(reading, wide: wide), drawn(ids, wide: wide), "\(ids)")
        }
    }

    /// Seen on the CI: the wide Nutrition card dropped onto the left half card of the row under it changed the order
    /// but not the screen (still drawn above that row), then swung back while the finger stayed there.
    func testAWideCardDroppedOntoEitherCardOfTheRowUnderItTakesThatRow() {
        let wide: Set<String> = ["W"]
        let start = ["W", "A", "B"]
        XCTAssertEqual(drawn(start, wide: wide), [["W"], ["A", "B"]])
        XCTAssertEqual(drawn(move(start, "W", onto: "A", wide: wide), wide: wide), [["A", "B"], ["W"]], "Left card")
        XCTAssertEqual(drawn(move(start, "W", onto: "B", wide: wide), wide: wide), [["A", "B"], ["W"]], "Right card")
        // And back up, onto either card of the row above.
        let moved = ["A", "B", "W"]
        XCTAssertEqual(drawn(move(moved, "W", onto: "A", wide: wide), wide: wide), [["W"], ["A", "B"]])
        XCTAssertEqual(drawn(move(moved, "W", onto: "B", wide: wide), wide: wide), [["W"], ["A", "B"]])
    }

    func testAHalfCardDroppedOntoTheWideCardAboveGoesOverItWithItsRow() {
        let wide: Set<String> = ["W"]
        let start = ["W", "A", "B"]
        XCTAssertEqual(drawn(move(start, "A", onto: "W", wide: wide), wide: wide), [["A", "B"], ["W"]])
        XCTAssertEqual(drawn(move(start, "B", onto: "W", wide: wide), wide: wide), [["A", "B"], ["W"]])
        // Side by side, the two half cards trade places, the wide card stays.
        XCTAssertEqual(drawn(move(start, "A", onto: "B", wide: wide), wide: wide), [["W"], ["B", "A"]])
    }

    func testHalfCardsStillTakeThePlaceOfTheCardTheyAreDroppedOn() {
        // No wide card: the same result as a plain change of rank.
        let ids = ["a", "b", "c", "d"]
        XCTAssertEqual(move(ids, "a", onto: "c", wide: []), DailyLayoutRules.moved(ids, id: "a", onto: "c"))
        XCTAssertEqual(move(ids, "d", onto: "b", wide: []), DailyLayoutRules.moved(ids, id: "d", onto: "b"))
        XCTAssertEqual(move(ids, "a", onto: "a", wide: []), ids)
        XCTAssertEqual(move(ids, "a", onto: "zzz", wide: []), ids)
    }

    /// A half card alone is always drawn after the wide cards: it cannot go over one, so nothing changes (instead of an
    /// order that changes nothing on screen).
    func testAMoveThatCannotShowChangesNothing() {
        let wide: Set<String> = ["W"]
        XCTAssertEqual(move(["W", "A"], "A", onto: "W", wide: wide), ["W", "A"])
        XCTAssertEqual(move(["W", "A"], "W", onto: "A", wide: wide), ["W", "A"])
    }

    /// VoiceOver « Déplacer avant / après »: the neighbour on screen, or the next one when the card cannot pass it.
    func testMovingByOneGoesToTheNeighbourOnScreen() {
        let wide: Set<String> = ["W"]
        let isWide: (String) -> Bool = { wide.contains($0) }
        let start = ["W", "A", "B"]
        XCTAssertEqual(drawn(DailyLayoutRules.moved(start, id: "W", by: 1, isWide: isWide), wide: wide), [["A", "B"], ["W"]])
        XCTAssertEqual(drawn(DailyLayoutRules.moved(start, id: "A", by: -1, isWide: isWide), wide: wide), [["A", "B"], ["W"]])
        XCTAssertEqual(drawn(DailyLayoutRules.moved(start, id: "A", by: 1, isWide: isWide), wide: wide), [["W"], ["B", "A"]])
        // At the ends, nothing.
        XCTAssertEqual(DailyLayoutRules.moved(start, id: "W", by: -1, isWide: isWide), start)
        XCTAssertEqual(DailyLayoutRules.moved(start, id: "B", by: 1, isWide: isWide), start)
        // A half card alone cannot go over the wide card just before it: it goes over the next card it can pass.
        let lone = ["B", "C", "W", "A"]
        XCTAssertEqual(drawn(lone, wide: wide), [["B", "C"], ["W"], ["A"]])
        XCTAssertEqual(drawn(DailyLayoutRules.moved(lone, id: "A", by: -1, isWide: isWide), wide: wide), [["B", "A"], ["W"], ["C"]])
        XCTAssertEqual(DailyLayoutRules.moved(["W", "A"], id: "A", by: -1, isWide: isWide), ["W", "A"])
    }

    /// The cards that made room at a move of the drag: the finger can end over them, they are not taken again at once.
    func testTheCardsThatChangedRowsAreKnown() {
        let wide: Set<String> = ["W"]
        let isWide: (String) -> Bool = { wide.contains($0) }
        XCTAssertEqual(DailyLayoutRules.line(of: "B", in: ["W", "A", "B"], isWide: isWide), 1)
        XCTAssertNil(DailyLayoutRules.line(of: "zzz", in: ["W", "A", "B"], isWide: isWide))
        XCTAssertEqual(DailyLayoutRules.changedRows(from: ["W", "A", "B"], to: ["A", "B", "W"], isWide: isWide), ["A", "B", "W"])
        // Side by side, no card changes rows.
        XCTAssertEqual(DailyLayoutRules.changedRows(from: ["W", "A", "B"], to: ["W", "B", "A"], isWide: isWide), [])
        XCTAssertEqual(DailyLayoutRules.changedRows(from: ["a", "b", "c", "d"], to: ["b", "c", "a", "d"], isWide: isWide), ["c", "a"])
    }

    /// Every drop in a few mixed grids: either nothing changes, or the screen changes and the card is drawn in the row
    /// of the card it was dropped on. The same cards, none lost or doubled. Same for VoiceOver's moves.
    func testEveryDropEitherShowsOrChangesNothing() {
        let wide: Set<String> = ["W", "X"]
        let grids = [["W", "A", "B"], ["A", "B", "W"], ["W", "A", "B", "X", "C"], ["A", "B", "C", "D", "W"],
                     ["W", "X", "A", "B", "C", "D"], ["A", "W", "B", "C"]]
        for ids in grids {
            let before = drawn(ids, wide: wide)
            for id in ids {
                for target in ids where target != id {
                    let result = move(ids, id, onto: target, wide: wide)
                    XCTAssertEqual(result.sorted(), ids.sorted(), "\(ids) \(id)→\(target)")
                    if result == ids { continue }
                    let after = drawn(result, wide: wide)
                    XCTAssertNotEqual(after, before, "\(ids) \(id)→\(target): an order that changes nothing on screen")
                    let goal = before.firstIndex { $0.contains(target) }
                    XCTAssertEqual(after.firstIndex { $0.contains(id) }, goal, "\(ids) \(id)→\(target): not in the target's row")
                }
                for delta in [-1, 1] {
                    let result = DailyLayoutRules.moved(ids, id: id, by: delta, isWide: { wide.contains($0) })
                    XCTAssertEqual(result.sorted(), ids.sorted(), "\(ids) \(id) \(delta)")
                    if result != ids {
                        XCTAssertNotEqual(drawn(result, wide: wide), before, "\(ids) \(id) \(delta): an order that changes nothing on screen")
                    }
                }
            }
        }
    }

    func testOrderedKeepsUnknownCardsLast() {
        let tiles = [steps, habits, reminders]
        XCTAssertEqual(DailyLayoutRules.ordered(tiles, by: nil).map(\.id), tiles.map(\.id))
        let live = DailyLayoutRules.ordered(tiles, by: [reminders.id, steps.id])
        XCTAssertEqual(live.map(\.id), [reminders.id, steps.id, habits.id])
    }
}
