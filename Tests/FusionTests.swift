import WidgetKit
import XCTest
@testable import Tessera

/// Sizes, the space creator's compositions and merging widgets.
final class FusionTests: XCTestCase {
    private func small(_ kind: WidgetKind) -> WidgetDesign {
        WidgetDesign(kind: kind, format: .small)
    }

    func testTwoSmallWidgetsMergeIntoAMediumOne() throws {
        let result = try XCTUnwrap(Fusion.result(for: [small(.caloriesLeft), small(.proteinLeft)]))
        XCTAssertEqual(result.format, .medium)
        XCTAssertEqual(result.parts.map(\.kind), [.caloriesLeft, .proteinLeft])
        let merged = try XCTUnwrap(Fusion.merge([small(.caloriesLeft), small(.proteinLeft)]))
        XCTAssertTrue(merged.isCombo)
        XCTAssertEqual(merged.displayFormat, .medium)
        XCTAssertEqual(merged.families, [.systemMedium])
        XCTAssertEqual(merged.partDesigns.map(\.kind), [.caloriesLeft, .proteinLeft])
    }

    func testFourSmallWidgetsMergeIntoALargeOne() throws {
        let designs = [small(.caloriesLeft), small(.macros), small(.proteinLeft), small(.nextMeal)]
        let result = try XCTUnwrap(Fusion.result(for: designs))
        XCTAssertEqual(result.format, .large)
        XCTAssertEqual(ComboLayout.rows(result.parts)?.map(\.count), [2, 2])
    }

    func testMediumWidgetsMergeIntoALargeOne() throws {
        let mediums = [WidgetDesign(kind: .mealsToday, format: .medium), WidgetDesign(kind: .nutritionWeek, format: .medium)]
        XCTAssertEqual(Fusion.result(for: mediums)?.format, .large)
        let mixed = [WidgetDesign(kind: .mealsToday, format: .medium), small(.caloriesLeft), small(.macros)]
        XCTAssertEqual(Fusion.result(for: mixed)?.format, .large)
        // A merged medium joins with another medium into a large one, keeping all four widgets.
        let merged = try XCTUnwrap(Fusion.merge([small(.caloriesLeft), small(.macros)]))
        let bigger = try XCTUnwrap(Fusion.result(for: [merged, WidgetDesign(kind: .mealsToday, format: .medium)]))
        XCTAssertEqual(bigger.format, .large)
        XCTAssertEqual(bigger.parts.count, 3)
    }

    func testIncompatibleSelectionsDontMerge() {
        XCTAssertNil(Fusion.result(for: [small(.caloriesLeft)]), "One widget alone")
        XCTAssertNil(Fusion.result(for: [small(.caloriesLeft), small(.budgetLeft)]), "Two categories")
        XCTAssertNil(Fusion.result(for: [small(.caloriesLeft), small(.macros), small(.proteinLeft)]), "Three small ones leave a hole")
        XCTAssertNil(Fusion.result(for: [small(.caloriesLeft), small(.caloriesLeft)]), "The same content twice")
        var later = small(.countdown)
        later.options.countdownDate = later.options.countdownDate.addingTimeInterval(30 * 86_400)
        XCTAssertNotNil(Fusion.result(for: [small(.countdown), later]), "Two countdowns to different dates are two contents")
        XCTAssertNil(Fusion.result(for: [WidgetDesign(kind: .mealsToday, format: .large), small(.caloriesLeft)]), "A large widget is already full")
        let five = [small(.caloriesLeft), small(.macros), small(.proteinLeft), small(.nextMeal), small(.quickFood)]
        XCTAssertNil(Fusion.result(for: five), "More than a large widget holds")
    }

    func testCombinedWidgetsSurviveSavingAndOldDesignsStillDecode() throws {
        let merged = try XCTUnwrap(Fusion.merge([small(.caloriesLeft), small(.macros)]))
        let decoded = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(merged))
        XCTAssertEqual(decoded, merged)
        let old = Data(#"{"id": "8A9A6D1E-1C1B-4B0F-9C3E-2B1D3C4E5F60", "kind": "tasks"}"#.utf8)
        let design = try JSONDecoder().decode(WidgetDesign.self, from: old)
        XCTAssertNil(design.format)
        XCTAssertFalse(design.isCombo)
        XCTAssertEqual(design.displayFormat, .small)
    }

    func testComposerFollowsTheRealSizes() {
        XCTAssertEqual(Composer.plan([.caloriesLeft], format: .medium), .single(.caloriesLeft))
        XCTAssertEqual(Composer.plan([.caloriesLeft, .macros], format: .medium),
                       .combo([.init(kind: .caloriesLeft, size: .small), .init(kind: .macros, size: .small)]))
        XCTAssertEqual(Composer.plan([.caloriesLeft, .macros, .mealsToday], format: .large),
                       .combo([.init(kind: .caloriesLeft, size: .small), .init(kind: .macros, size: .small), .init(kind: .mealsToday, size: .medium)]))
        if case .invalid = Composer.plan([.caloriesLeft], format: .large) {} else {
            XCTFail("Calories restantes has no large size: it needs other widgets")
        }
    }

    func testEverySpacePresetComposes() {
        for space in Space.allCases {
            for format in [WidgetFormat.medium, .large] {
                let preset = SpaceCatalog.preset(for: space, format: format)
                XCTAssertFalse(preset.isEmpty, "\(space) has no \(format) preset")
                if case let .invalid(reason) = Composer.plan(preset, format: format) {
                    XCTFail("\(space) \(format): \(reason)")
                }
            }
            XCTAssertEqual(SpaceCatalog.preset(for: space, format: .small).count, 1)
        }
    }

    func testCombinedWidgetLoadsWhatEachPartNeeds() throws {
        let merged = try XCTUnwrap(Fusion.merge([small(.budgetLeft), small(.savingsGoal)]))
        XCTAssertTrue(merged.dataNeeds.isSuperset(of: DataNeeds.needs(for: .budgetLeft)))
        XCTAssertTrue(merged.dataNeeds.isSuperset(of: DataNeeds.needs(for: .savingsGoal)))
    }
}
