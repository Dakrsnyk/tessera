import XCTest
@testable import Ardane

/// The habits proposed on the Bien-être page each have their own color (2026-11-22), and the ones the first version
/// added in its single green take theirs; nothing else changes color.
final class HabitSuggestionsTests: XCTestCase {
    func testEverySuggestionHasItsOwnColorAndIcon() {
        let items = HabitSuggestions.all
        XCTAssertEqual(Set(items.map(\.colorHex)).count, items.count, "Two suggestions share a color")
        XCTAssertEqual(Set(items.map(\.symbol)).count, items.count)
        XCTAssertEqual(Set(items.map(\.name)).count, items.count)
    }

    func testOnlyTheFormerGreenSuggestionsAreRecolored() throws {
        let walk = try XCTUnwrap(HabitSuggestions.all.first { $0.symbol == "figure.walk" })
        let water = try XCTUnwrap(HabitSuggestions.all.first { $0.symbol == "drop.fill" })
        var habits = [
            Habit(name: water.name, symbol: water.symbol, colorHex: HabitSuggestions.formerColorHex, completedDays: ["2026-11-20"]),
            Habit(name: water.name, symbol: water.symbol, colorHex: "FF6B57"),
            Habit(name: "Courir", symbol: water.symbol, colorHex: HabitSuggestions.formerColorHex),
            Habit(name: walk.name, symbol: walk.symbol, colorHex: HabitSuggestions.formerColorHex),
        ]
        let before = habits
        XCTAssertTrue(HabitSuggestions.recolor(&habits))
        XCTAssertEqual(habits[0].colorHex, water.colorHex, "A former suggestion takes its own color")
        XCTAssertEqual(habits[0].completedDays, before[0].completedDays, "Only the color changes")
        XCTAssertEqual(habits[0].id, before[0].id)
        XCTAssertEqual(habits[1].colorHex, "FF6B57", "A color chosen by the person is kept")
        XCTAssertEqual(habits[2].colorHex, HabitSuggestions.formerColorHex, "A habit of the person's own is kept")
        XCTAssertEqual(habits[3].colorHex, walk.colorHex)
        XCTAssertFalse(HabitSuggestions.recolor(&habits), "Nothing left to change the second time")
    }
}
