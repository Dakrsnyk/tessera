import WidgetKit
import XCTest
@testable import Ardane

/// Editing the widgets inside a widget: adding, removing, replacing, moving, arrangements and refusals.
final class ComboEditingTests: XCTestCase {
    private func part(_ kind: WidgetKind, _ size: WidgetFormat = .small, name: String? = nil) -> ComboPart {
        ComboPart(kind: kind, options: DesignOptions(), name: name ?? kind.title, size: size)
    }

    private func applied(_ change: ComboEditing.Change, file: StaticString = #filePath, line: UInt = #line) throws -> ComboEditing.Outcome {
        guard case let .applied(outcome) = change else {
            XCTFail("Expected an applied change, got \(change)", file: file, line: line)
            throw XCTSkip("not applied")
        }
        return outcome
    }

    private func isRefused(_ change: ComboEditing.Change) -> Bool {
        if case .refused = change { return true }
        return false
    }

    // MARK: Adding

    func testAddingToASmallWidgetMakesAMediumOne() throws {
        let outcome = try applied(ComboEditing.adding(part(.macros), to: [part(.caloriesLeft)]))
        XCTAssertEqual(outcome.parts.map(\.kind), [.caloriesLeft, .macros])
        XCTAssertEqual(outcome.parts.map(\.size), [.small, .small])
        XCTAssertEqual(outcome.format, .medium)
        XCTAssertEqual(outcome.resizedFrom, .small)
    }

    func testThirdAndFourthWidgetsGoToLarge() throws {
        let two = [part(.caloriesLeft), part(.macros)]
        let three = try applied(ComboEditing.adding(part(.proteinLeft), to: two))
        XCTAssertEqual(three.format, .large)
        XCTAssertEqual(three.resizedFrom, .medium)
        XCTAssertNotNil(ComboLayout.rows(three.parts))
        let four = try applied(ComboEditing.adding(part(.nextMeal), to: three.parts))
        XCTAssertEqual(four.format, .large)
        XCTAssertNil(four.resizedFrom)
        XCTAssertEqual(four.parts.count, 4)
    }

    func testFifthWidgetIsRefused() {
        let four = [part(.caloriesLeft), part(.macros), part(.proteinLeft), part(.nextMeal)]
        XCTAssertTrue(isRefused(ComboEditing.adding(part(.quickFood), to: four)))
        XCTAssertNotNil(ComboEditing.refusal(adding: .quickFood, to: four))
    }

    func testAnotherSpaceOrTheSameContentIsRefused() {
        let current = [part(.caloriesLeft)]
        XCTAssertTrue(isRefused(ComboEditing.adding(part(.budgetLeft), to: current)))
        XCTAssertTrue(isRefused(ComboEditing.adding(part(.caloriesLeft), to: current)))
        XCTAssertNotNil(ComboEditing.refusal(adding: .budgetLeft, to: current))
        XCTAssertNotNil(ComboEditing.refusal(adding: .caloriesLeft, to: current))
        XCTAssertNil(ComboEditing.refusal(adding: .macros, to: current))
    }

    func testAddingKeepsTheOptionsAndNamesOfTheParts() throws {
        var first = part(.caloriesLeft, name: "Mon nom")
        first.options.noteTitle = "Garde-moi"
        let outcome = try applied(ComboEditing.adding(part(.macros), to: [first]))
        XCTAssertEqual(outcome.parts[0].name, "Mon nom")
        XCTAssertEqual(outcome.parts[0].options.noteTitle, "Garde-moi")
    }

    func testALargeWidgetAloneStaysLargeWhenItCan() throws {
        let outcome = try applied(ComboEditing.adding(part(.macros, .medium), to: [part(.mealsToday, .large)]))
        XCTAssertEqual(outcome.format, .large)
        XCTAssertEqual(outcome.parts.map(\.size), [.medium, .medium])
        XCTAssertNil(outcome.resizedFrom)
    }

    // MARK: Removing

    func testRemovingDownToOneWidget() throws {
        let four = [part(.caloriesLeft), part(.macros), part(.proteinLeft), part(.nextMeal)]
        let three = try applied(ComboEditing.removing(at: 3, from: four))
        XCTAssertEqual(three.parts.count, 3)
        XCTAssertEqual(three.format, .large)
        let two = try applied(ComboEditing.removing(at: 1, from: three.parts))
        XCTAssertEqual(two.parts.map(\.kind), [.caloriesLeft, .proteinLeft])
        XCTAssertEqual(two.format, .medium)
        XCTAssertEqual(two.resizedFrom, .large)
        let one = try applied(ComboEditing.removing(at: 0, from: two.parts))
        XCTAssertEqual(one.parts.map(\.kind), [.proteinLeft])
        XCTAssertEqual(one.parts[0].size, .medium, "Protéines restantes exists in medium")
        XCTAssertEqual(one.format, .medium)
    }

    func testTheLastWidgetCantBeRemoved() {
        XCTAssertTrue(isRefused(ComboEditing.removing(at: 0, from: [part(.caloriesLeft)])))
    }

    func testRemovingKeepsTheOptionsOfTheOthers() throws {
        var kept = part(.macros, name: "Garder")
        kept.options.noteTitle = "Option"
        let outcome = try applied(ComboEditing.removing(at: 0, from: [part(.caloriesLeft), kept]))
        XCTAssertEqual(outcome.parts.count, 1)
        XCTAssertEqual(outcome.parts[0].name, "Garder")
        XCTAssertEqual(outcome.parts[0].options.noteTitle, "Option")
    }

    // MARK: Replacing

    func testReplacingKeepsThePlace() throws {
        let outcome = try applied(ComboEditing.replacing(at: 1, with: part(.proteinLeft), in: [part(.caloriesLeft), part(.macros)]))
        XCTAssertEqual(outcome.parts.map(\.kind), [.caloriesLeft, .proteinLeft])
        XCTAssertEqual(outcome.format, .medium)
        XCTAssertNil(outcome.resizedFrom)
    }

    func testReplacingRefusesAnotherSpaceAndTheSameContent() {
        let current = [part(.caloriesLeft), part(.macros)]
        XCTAssertTrue(isRefused(ComboEditing.replacing(at: 1, with: part(.budgetLeft), in: current)))
        XCTAssertTrue(isRefused(ComboEditing.replacing(at: 1, with: part(.caloriesLeft), in: current)))
    }

    func testReplacingAWidgetAlone() throws {
        let outcome = try applied(ComboEditing.replacing(at: 0, with: part(.macros), in: [part(.caloriesLeft, .medium)]))
        XCTAssertEqual(outcome.parts.map(\.kind), [.macros])
        XCTAssertEqual(outcome.parts[0].size, .medium)
    }

    // MARK: Moving

    func testMovingChangesTheOrderAndKeepsTheSizes() throws {
        var first = part(.caloriesLeft, name: "Premier")
        first.options.noteTitle = "Option"
        let current = [first, part(.macros), part(.mealsToday, .medium)]
        let outcome = try applied(ComboEditing.moving(from: 2, to: 0, in: current))
        XCTAssertEqual(outcome.parts.map(\.kind), [.mealsToday, .caloriesLeft, .macros])
        XCTAssertEqual(outcome.parts.map(\.size), [.medium, .small, .small])
        XCTAssertEqual(outcome.format, .large)
        XCTAssertNil(outcome.resizedFrom)
        let moved = try XCTUnwrap(outcome.parts.first { $0.kind == .caloriesLeft })
        XCTAssertEqual(moved.name, "Premier")
        XCTAssertEqual(moved.options.noteTitle, "Option")
    }

    func testMovingTwoSmallOnesSwapsThem() throws {
        let outcome = try applied(ComboEditing.moving(from: 0, to: 1, in: [part(.caloriesLeft), part(.macros)]))
        XCTAssertEqual(outcome.parts.map(\.kind), [.macros, .caloriesLeft])
        XCTAssertEqual(outcome.format, .medium)
    }

    func testMovingFollowsTheOrderDrawnNotTheList() throws {
        let s1 = part(.caloriesLeft), s2 = part(.macros), m3 = part(.mealsToday, .medium)
        let current = [s1, s2, m3]
        // Rows are [[S1, S2], [M3]]: dropping S2 after M3 would draw the same widget, so the rows swap instead.
        let down = try applied(ComboEditing.moving(from: 1, to: 2, in: current))
        XCTAssertEqual(down.parts.map(\.kind), [.mealsToday, .caloriesLeft, .macros])
        XCTAssertEqual(down.parts.firstIndex { $0.kind == .macros }, 2)
        XCTAssertTrue(ComboEditing.canMove(from: 1, to: 2, in: current))
        let up = try applied(ComboEditing.moving(from: 2, to: 1, in: current))
        XCTAssertEqual(up.parts.map(\.kind), [.mealsToday, .caloriesLeft, .macros])
        // Every outcome lists its parts as drawn: the rows flattened.
        for outcome in [down, up] {
            XCTAssertEqual(outcome.parts, ComboLayout.rows(outcome.parts)?.flatMap { $0 })
        }
        // The first widget can't go up, the last can't go down.
        XCTAssertFalse(ComboEditing.canMove(from: 0, to: -1, in: current))
        XCTAssertFalse(ComboEditing.canMove(from: 2, to: 3, in: current))
    }

    func testMovingOutOfRangeIsRefused() {
        XCTAssertTrue(isRefused(ComboEditing.moving(from: 0, to: 5, in: [part(.caloriesLeft), part(.macros)])))
    }

    // MARK: Arrangements

    func testArrangementsOfTwoSmallOnes() {
        let a = part(.caloriesLeft), b = part(.macros)
        XCTAssertEqual(ComboEditing.arrangements(of: [a, b]), [[a, b], [b, a]])
    }

    func testArrangementsOfTwoMediumOnes() {
        let a = part(.mealsToday, .medium), b = part(.nutritionWeek, .medium)
        XCTAssertEqual(ComboEditing.arrangements(of: [a, b]), [[a, b], [b, a]])
    }

    func testArrangementsOfFourSmallOnes() {
        let a = part(.caloriesLeft), b = part(.macros), c = part(.proteinLeft), d = part(.nextMeal)
        XCTAssertEqual(ComboEditing.arrangements(of: [a, b, c, d]), [[a, b, c, d], [c, d, a, b]])
    }

    func testArrangementsOfOneMediumAndTwoSmallOnes() {
        let current = [part(.caloriesLeft), part(.macros), part(.mealsToday, .medium)]
        let all = ComboEditing.arrangements(of: current)
        XCTAssertEqual(all.first, current, "The first one is the current one")
        XCTAssertEqual(Set(all).count, all.count, "No duplicates")
        XCTAssertGreaterThan(all.count, 2)
        for arrangement in all {
            XCTAssertEqual(ComboLayout.format(arrangement), .large)
            XCTAssertEqual(Set(arrangement.map(\.kind)), Set(current.map(\.kind)))
        }
    }

    func testArrangementsOfAWidgetAloneIsItself() {
        let a = part(.caloriesLeft)
        XCTAssertEqual(ComboEditing.arrangements(of: [a]), [[a]])
    }

    // MARK: Editing a design

    func testEditablePartsOfAWidgetAloneAndOfACombination() throws {
        let alone = WidgetDesign(kind: .caloriesLeft, format: .small)
        XCTAssertEqual(alone.editableParts.count, 1)
        XCTAssertEqual(alone.editableParts[0].kind, .caloriesLeft)
        XCTAssertEqual(alone.editableParts[0].size, .small)
        let merged = try XCTUnwrap(Fusion.merge([alone, WidgetDesign(kind: .macros, format: .small)]))
        XCTAssertEqual(merged.editableParts.map(\.kind), [.caloriesLeft, .macros])
    }

    func testApplyingKeepsIdentityAndStyle() throws {
        var design = WidgetDesign(kind: .caloriesLeft, accentHex: "FF0000", showsTitle: false, isFavorite: true, format: .small)
        design.background = .theme
        let outcome = try applied(ComboEditing.adding(part(.macros), to: design.editableParts))
        let result = design.applying(outcome)
        XCTAssertEqual(result.id, design.id)
        XCTAssertEqual(result.themeID, design.themeID)
        XCTAssertEqual(result.accentHex, "FF0000")
        XCTAssertEqual(result.background, design.background)
        XCTAssertEqual(result.font, design.font)
        XCTAssertEqual(result.style, design.style)
        XCTAssertFalse(result.showsTitle)
        XCTAssertTrue(result.isFavorite)
        XCTAssertTrue(result.isCombo)
        XCTAssertEqual(result.kind, .caloriesLeft)
        XCTAssertEqual(result.format, .medium)
        XCTAssertEqual(result.displayFormat, .medium)
        XCTAssertEqual(result.options.parts.map(\.kind), [.caloriesLeft, .macros])
    }

    func testApplyingFollowsTheNameUntilItIsChanged() throws {
        let design = WidgetDesign(kind: .caloriesLeft, format: .small)
        let merged = design.applying(try applied(ComboEditing.adding(part(.macros), to: design.editableParts)))
        XCTAssertEqual(merged.name, "\(WidgetKind.caloriesLeft.title) + \(WidgetKind.macros.title)")
        // Back to one widget: the name follows.
        let back = merged.applying(try applied(ComboEditing.removing(at: 0, from: merged.editableParts)))
        XCTAssertFalse(back.isCombo)
        XCTAssertEqual(back.kind, .macros)
        XCTAssertEqual(back.name, WidgetKind.macros.title)
        XCTAssertEqual(back.options.parts, [])
        XCTAssertEqual(back.id, design.id)
        // A name the person chose stays.
        var renamed = merged
        renamed.name = "Mon tableau"
        let more = renamed.applying(try applied(ComboEditing.adding(part(.proteinLeft), to: renamed.editableParts)))
        XCTAssertEqual(more.name, "Mon tableau")
        XCTAssertEqual(more.format, .large)
    }

    // MARK: Fusion.refusal

    private func small(_ kind: WidgetKind) -> WidgetDesign {
        WidgetDesign(kind: kind, format: .small)
    }

    func testFusionRefusalGivesAReasonOnlyWhenItCantMerge() {
        XCTAssertNil(Fusion.refusal(for: [small(.caloriesLeft), small(.macros)]), "Valid case")
        XCTAssertNotNil(Fusion.refusal(for: [small(.caloriesLeft), small(.budgetLeft)]), "Another space")
        XCTAssertNotNil(Fusion.refusal(for: [WidgetDesign(kind: .mealsToday, format: .large), small(.caloriesLeft)]), "A large widget")
        XCTAssertNotNil(Fusion.refusal(for: [small(.caloriesLeft), small(.caloriesLeft)]), "The same content twice")
        XCTAssertNotNil(Fusion.refusal(for: [small(.caloriesLeft), small(.macros), small(.proteinLeft)]), "Three small ones")
    }
}
