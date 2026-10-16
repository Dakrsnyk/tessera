import XCTest
@testable import Tessera

/// The free plan (request of 2026-10-16): 3 saved widgets, and photo and quote widgets unlimited. Every new
/// widget follows the same rule (Studio, Store, duplicate, merge, « Photos et citations »), and whoever
/// already has more keeps them all.
@MainActor
final class FreeWidgetLimitTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        AppModel(store: SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)))
    }

    private func widgets(_ count: Int) -> [WidgetDesign] {
        let kinds: [WidgetKind] = [.clock, .tasks, .note, .progress, .calendar, .worldClock, .yearDots, .habits, .focus]
        return (0..<count).map { WidgetDesign(kind: kinds[$0 % kinds.count], format: .small) }
    }

    private var photos: WidgetDesign { WidgetDesign(kind: .photos, format: .small) }
    private var quote: WidgetDesign { WidgetDesign(kind: .quote, format: .medium) }

    /// Runs `body` as a free user, then puts the test switch back as it was.
    private func asFreeUser(_ body: () throws -> Void) rethrows {
        #if DEBUG
        let previous = DebugPremium.isUnlocked
        DebugPremium.setUnlocked(false)
        defer { DebugPremium.setUnlocked(previous) }
        #endif
        try body()
    }

    func testTheFreePlanKeepsThreeWidgets() {
        XCTAssertEqual(AppModel.freeDesignLimit, 3)
    }

    func testPhotoAndQuoteWidgetsDoNotCount() {
        XCTAssertFalse(AppModel.countsTowardFreeLimit(photos))
        XCTAssertFalse(AppModel.countsTowardFreeLimit(quote))
        for design in widgets(9) {
            XCTAssertTrue(AppModel.countsTowardFreeLimit(design), "\(design.kind)")
        }
        // A combined widget counts, whatever its first part.
        var combo = WidgetDesign(kind: .photos, format: .medium)
        combo.options.parts = [
            ComboPart(kind: .photos, options: DesignOptions(), name: "A", size: .small),
            ComboPart(kind: .quote, options: DesignOptions(), name: "B", size: .small),
        ]
        XCTAssertTrue(AppModel.countsTowardFreeLimit(combo))
    }

    func testNewWidgetsFitWithinThreeAndPhotosAlwaysFit() {
        XCTAssertTrue(AppModel.fitsFreePlan(saved: [], adding: widgets(3)))
        XCTAssertFalse(AppModel.fitsFreePlan(saved: [], adding: widgets(4)))
        XCTAssertTrue(AppModel.fitsFreePlan(saved: widgets(2), adding: widgets(1)))
        XCTAssertFalse(AppModel.fitsFreePlan(saved: widgets(3), adding: widgets(1)))
        XCTAssertTrue(AppModel.fitsFreePlan(saved: widgets(3), adding: [photos]))
        XCTAssertTrue(AppModel.fitsFreePlan(saved: widgets(3), adding: [quote]))
        // Photos and quotes already saved leave the room to the other widgets.
        let many = (0..<20).map { _ in WidgetDesign(kind: .photos, format: .small) }
        XCTAssertTrue(AppModel.fitsFreePlan(saved: many + widgets(2), adding: widgets(1)))
        XCTAssertFalse(AppModel.fitsFreePlan(saved: many + widgets(3), adding: widgets(1)))
    }

    func testWhoeverHasMoreKeepsThemAndCanStillMerge() {
        let saved = widgets(8)
        XCTAssertFalse(AppModel.fitsFreePlan(saved: saved, adding: widgets(1)), "No new widget that counts")
        XCTAssertTrue(AppModel.fitsFreePlan(saved: saved, adding: [photos, quote]), "Photos and quotes still fit")
        let merged = widgets(1)
        XCTAssertTrue(AppModel.fitsFreePlan(saved: saved, adding: merged, removing: Array(saved.prefix(2))), "Two merged into one")
        XCTAssertFalse(AppModel.fitsFreePlan(saved: saved, adding: merged), "Keeping the originals makes one more")
        // Two photo widgets merged into a combined one: one more that counts.
        let photoWidgets = [WidgetDesign(kind: .photos, format: .small), WidgetDesign(kind: .quote, format: .small)]
        var combo = WidgetDesign(kind: .photos, format: .medium)
        combo.options.parts = photoWidgets.map { ComboPart(kind: $0.kind, options: $0.options, name: $0.name, size: .small) }
        XCTAssertFalse(AppModel.fitsFreePlan(saved: widgets(3) + photoWidgets, adding: [combo], removing: photoWidgets))
    }

    func testAFreeModelKeepsEveryWidgetAndAppliesTheSameRuleEverywhere() {
        asFreeUser {
            let model = temporaryModel()
            XCTAssertFalse(model.isPremium)
            // Widgets saved before the limit went down to 3: all kept.
            for design in widgets(8) { model.save(design) }
            model.save(photos)
            XCTAssertEqual(model.designs.count, 9)
            XCTAssertEqual(model.limitedDesignCount, 8)
            XCTAssertFalse(model.canCreateDesign)
            XCTAssertFalse(model.canSave(adding: widgets(1)))
            XCTAssertTrue(model.canSave(adding: [quote]))
            // Duplicate: a photo widget yes, another widget no.
            let counted = model.designs.filter { AppModel.countsTowardFreeLimit($0) }
            XCTAssertNil(model.duplicate(counted[0]))
            XCTAssertNotNil(model.duplicate(photos))
            // Store and Studio: the photos and quotes are added, nothing else.
            XCTAssertEqual(model.install(designs: [WidgetDesign(kind: .photos, format: .small), WidgetDesign(kind: .quote, format: .small)]), 2)
            XCTAssertEqual(model.install(designs: widgets(1)), 0)
            XCTAssertEqual(model.designs.count, 12, "Nothing was ever removed")
        }
    }

    func testAFreeModelFillsUpToThree() {
        asFreeUser {
            let model = temporaryModel()
            XCTAssertEqual(model.install(designs: widgets(5)), 3, "The first three fit")
            XCTAssertFalse(model.canCreateDesign)
            XCTAssertTrue(model.canSave(adding: [photos]))
        }
    }

    func testPremiumHasNoLimit() {
        #if DEBUG
        let previous = DebugPremium.isUnlocked
        DebugPremium.setUnlocked(true)
        defer { DebugPremium.setUnlocked(previous) }
        let model = temporaryModel()
        XCTAssertEqual(model.install(designs: widgets(9)), 9)
        XCTAssertTrue(model.canCreateDesign)
        XCTAssertNotNil(model.duplicate(model.designs[0]))
        #endif
    }
}
