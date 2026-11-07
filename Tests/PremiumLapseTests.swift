import XCTest
@testable import Ardane

/// When Premium ends (expired subscription, refund): the widgets already saved are all kept, nothing new that
/// counts can be added past the free limit, and the Premium looks are not applied any more (but kept for a return).
@MainActor
final class PremiumLapseTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        AppModel(store: SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)))
    }

    private func widgets(_ count: Int) -> [WidgetDesign] {
        let kinds: [WidgetKind] = [.clock, .tasks, .note, .progress, .calendar, .worldClock, .yearDots, .habits, .focus]
        return (0..<count).map { WidgetDesign(kind: kinds[$0 % kinds.count], format: .small) }
    }

    private func subscribed(until date: Date) -> PremiumState {
        PremiumState(isActive: true, productID: PremiumConfiguration.yearlyID, expirationDate: date, verifiedAt: Date())
    }

    /// Runs `body` without the Debug test switch (it keeps Premium true in a Debug build), then puts it back.
    private func withoutDebugUnlock(_ body: () throws -> Void) rethrows {
        #if DEBUG
        let previous = DebugPremium.isUnlocked
        DebugPremium.setUnlocked(false)
        defer { DebugPremium.setUnlocked(previous) }
        #endif
        try body()
    }

    func testAfterAnExpirationEveryWidgetIsKeptButNothingNewThatCountsCanBeAdded() {
        withoutDebugUnlock {
            let model = temporaryModel()
            model.updatePremium(subscribed(until: Date().addingTimeInterval(30 * 86_400)))
            XCTAssertTrue(model.isPremium)
            for design in widgets(6) { model.save(design) }
            XCTAssertEqual(model.designs.count, 6, "Premium has no limit")
            XCTAssertTrue(model.canCreateDesign)

            // The subscription ends (what `PremiumStore.refreshEntitlements` writes when nothing is active).
            model.updatePremium(PremiumState(isActive: false, productID: nil, expirationDate: nil, verifiedAt: Date()))

            XCTAssertFalse(model.isPremium)
            XCTAssertEqual(model.designs.count, 6, "Nothing is ever deleted when Premium ends")
            XCTAssertEqual(model.limitedDesignCount, 6)
            XCTAssertFalse(model.canCreateDesign)
            XCTAssertEqual(model.install(designs: widgets(2)), 0)
            XCTAssertEqual(model.designs.count, 6)
            // Photos and quotes stay free, and a saved widget can still be edited.
            XCTAssertEqual(model.install(designs: [WidgetDesign(kind: .photos, format: .small)]), 1)
            var edited = model.designs[0]
            edited.name = "Renommé"
            model.save(edited)
            XCTAssertEqual(model.designs.first { $0.id == edited.id }?.name, "Renommé")
            XCTAssertEqual(model.designs.count, 7)
        }
    }

    func testPremiumLooksAreKeptInTheFileButNotAppliedAfterTheEnd() throws {
        try withoutDebugUnlock {
            let model = temporaryModel()
            model.updatePremium(subscribed(until: Date().addingTimeInterval(30 * 86_400)))
            let styled = WidgetDesign(kind: .clock, themeID: .aurora, accentHex: "123456", background: .gradient, font: .serif)
            XCTAssertTrue(styled.usesPremiumFeatures)
            model.save(styled)

            model.updatePremium(PremiumState())

            let kept = try XCTUnwrap(model.designs.first { $0.id == styled.id })
            XCTAssertEqual(kept.themeID, .aurora, "The choice stays saved: it comes back with Premium")
            let shown = kept.downgradedForFree()
            XCTAssertEqual(shown.themeID, .minimal)
            XCTAssertEqual(shown.background, .theme)
            XCTAssertEqual(shown.font, .theme)
            XCTAssertEqual(shown.accentHex, Palette.defaultAccent)
        }
    }

    func testASubscriptionPastItsGraceNoLongerUnlocksEvenIfTheCacheSaysActive() {
        withoutDebugUnlock {
            let model = temporaryModel()
            // Cached « active » but the end date, plus the three days of grace, is past: the offline cache lapses by itself.
            model.updatePremium(subscribed(until: Date().addingTimeInterval(-(PremiumState.gracePeriod + 3_600))))
            XCTAssertFalse(model.isPremium)
            XCTAssertTrue(model.canCreateDesign, "A free model with no widget still has its three")
            // Inside the grace, the renewal not yet synced does not lock the person out.
            model.updatePremium(subscribed(until: Date().addingTimeInterval(-(PremiumState.gracePeriod - 3_600))))
            XCTAssertTrue(model.isPremium)
        }
    }
}
