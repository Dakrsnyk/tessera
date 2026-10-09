import UIKit
import WidgetKit
import XCTest
@testable import Tessera

/// App styles, profile settings, Home Screen setups and Store shelves.
final class AppearanceAndStoreTests: XCTestCase {
    func testSettingsFromBeforeStylesDecodeWithDefaults() throws {
        let old = Data(#"{"hasCompletedOnboarding": true, "currencyCode": "EUR"}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: old)
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.currencyCode, "EUR")
        XCTAssertEqual(settings.appStyle, .tessera)
        XCTAssertEqual(settings.appearance, .system)
        XCTAssertFalse(settings.hasChosenStyle, "Existing installs are asked for a style once")
        XCTAssertEqual(settings.profileName, "")
    }

    func testStyleAndProfileAreSaved() throws {
        var settings = AppSettings()
        settings.appStyle = .neon
        settings.appearance = .dark
        settings.hasChosenStyle = true
        settings.profileName = "Mathys"
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded, settings)
    }

    func testEveryStyleIsDefinedOnce() {
        XCTAssertEqual(AppStyle.all.count, AppStyleID.allCases.count)
        XCTAssertEqual(Set(AppStyle.all.map(\.id)).count, AppStyle.all.count)
        for id in AppStyleID.allCases {
            XCTAssertEqual(AppStyle.style(id).id, id)
        }
    }

    func testAppIconsComeWithTheirPictureAndClassiqueFirst() {
        let icons = AppIconChoice.all
        XCTAssertEqual(icons.first?.asset, AppIconChoice.main, "Classique, the main icon, comes first")
        XCTAssertNil(icons.first?.alternateName)
        XCTAssertEqual(Set(icons.map(\.asset)).count, icons.count)
        for icon in icons.dropFirst() {
            XCTAssertEqual(icon.alternateName, icon.asset)
        }
        for icon in icons {
            XCTAssertNotNil(UIImage(named: icon.preview), "\(icon.preview) is in the app")
        }
    }

    func testSetupsFitOnAPhone() {
        XCTAssertEqual(Set(HomeSetupCatalog.all.map(\.id)).count, HomeSetupCatalog.all.count)
        XCTAssertGreaterThanOrEqual(HomeSetupCatalog.all.filter { !$0.isPremium }.count, 3, "Some setups stay free")
        for setup in HomeSetupCatalog.all {
            for widget in setup.rows.flatMap(\.widgets) + setup.lock.allWidgets {
                XCTAssertTrue(widget.kind.families.contains(widget.family), "\(setup.id): \(widget.kind) has no \(widget.family) size")
            }
            for row in setup.rows {
                if case let .widgets(widgets) = row {
                    let width = widgets.map { WidgetMetrics.size($0.family).width }.reduce(0, +) + CGFloat(max(0, widgets.count - 1)) * 24
                    XCTAssertLessThanOrEqual(width, 364, "\(setup.id): a row is wider than the screen")
                }
            }
            let lock = setup.lock.widgets
            let lockWidth = lock.map { WidgetMetrics.size($0.family).width }.reduce(0, +) + CGFloat(max(0, lock.count - 1)) * 14
            XCTAssertLessThanOrEqual(lockWidth, 364, "\(setup.id): the Lock Screen row is too wide")
            XCTAssertFalse(setup.designs().isEmpty)
        }
    }

    func testStoreShelvesUseSupportedSizes() {
        let items = StoreShowcase.lockScreen + StoreShowcase.allStyles + StoreShowcase.allColors + StoreShowcase.collections.flatMap(\.items)
        for widget in items.map(\.widget) {
            XCTAssertTrue(widget.kind.families.contains(widget.family), "\(widget.kind) has no \(widget.family) size")
        }
        XCTAssertEqual(StoreShowcase.allStyles.count, ThemeCatalog.all.count)
    }

    func testCollectionsAreDistinctAndFilled() {
        let ids = StoreShowcase.collections.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(ids.count, 10)
        for collection in StoreShowcase.collections {
            XCTAssertGreaterThanOrEqual(collection.items.count, 5, collection.id)
            XCTAssertEqual(StoreShowcase.collection(collection.id)?.id, collection.id)
        }
        // Someone into sport sees the sport collection first.
        XCTAssertEqual(StoreShowcase.collections(preferring: [.fitness]).first?.id, "sport")
        XCTAssertEqual(StoreShowcase.collections(preferring: []).map(\.id), ids)
    }

    /// Every combination follows the rules of merging widgets: one category, whole rows, sizes the widgets have.
    func testCombinationsFollowTheMergeRules() {
        let ids = StoreComboCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(StoreComboCatalog.mediums.count, 20)
        XCTAssertGreaterThanOrEqual(StoreComboCatalog.larges.count, 12)
        for combo in StoreComboCatalog.all {
            let design = combo.makeDesign()
            XCTAssertTrue(design.isCombo, combo.id)
            XCTAssertEqual(Set(combo.parts.map { Fusion.category(of: $0.kind) }).count, 1, "\(combo.id) mixes categories")
            XCTAssertNotNil(ComboLayout.format(combo.comboParts), "\(combo.id) doesn't fill whole rows")
            for part in combo.parts {
                let family: WidgetFamily = part.size == .medium ? .systemMedium : .systemSmall
                XCTAssertTrue(part.kind.families.contains(family), "\(combo.id): \(part.kind) has no \(family) size")
            }
        }
        XCTAssertTrue(StoreComboCatalog.mediums.allSatisfy { $0.format == .medium })
        XCTAssertTrue(StoreComboCatalog.larges.allSatisfy { $0.format == .large })
        XCTAssertTrue(StoreComboCatalog.all.contains { !$0.isPremium }, "Some combinations stay free")
    }

    /// The example of a combination fills every part, not only the first one.
    func testCombinationSampleShowsEveryPart() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let combo = try XCTUnwrap(StoreComboCatalog.combo("eau-serie"))
        let payload = SamplePayload.make(for: combo.makeDesign(), now: now)
        XCTAssertEqual(payload.content.hydration, SamplePayload.make(for: .hydration, now: now).content.hydration)
        XCTAssertNotEqual(payload.domains, DomainData(), "The second widget brings its example data")
        XCTAssertEqual(SamplePayload.make(for: .hydration, now: now).domains, DomainData())
    }

    func testPacksAreDistinctAndShowable() {
        let ids = PackCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(ids.count, 20)
        for pack in PackCatalog.all {
            XCTAssertEqual(Set(pack.kinds).count, pack.kinds.count, "\(pack.id) repeats a widget")
            XCTAssertGreaterThanOrEqual(pack.smallDesigns().count, 3, "\(pack.id) needs three small widgets for its card")
        }
        XCTAssertTrue(PackCatalog.all.contains { !$0.isPremium }, "Some packs stay free")
    }

    func testThisWeeksEditionIsStableAllWeek() throws {
        let calendar = Calendar(identifier: .iso8601)
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 9)))
        let sunday = try XCTUnwrap(calendar.date(byAdding: .day, value: 6, to: monday))
        let nextMonday = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: monday))
        XCTAssertEqual(HomeSetupCatalog.weekly(now: monday).id, HomeSetupCatalog.weekly(now: sunday).id)
        XCTAssertNotEqual(HomeSetupCatalog.weekly(now: monday).id, HomeSetupCatalog.weekly(now: nextMonday).id)
        XCTAssertEqual(StoreEdition.pack(now: monday).id, StoreEdition.pack(now: sunday).id)
        XCTAssertNotEqual(StoreEdition.pack(now: monday).id, StoreEdition.pack(now: nextMonday).id)
    }

    func testSpaceExamplesUseSupportedSizes() {
        for space in Space.allCases {
            let examples = SpaceCatalog.examples(for: space)
            XCTAssertFalse(examples.isEmpty, "\(space) has no example")
            for example in examples {
                XCTAssertTrue(example.design.kind.families.contains(example.family), "\(space): \(example.design.kind) has no \(example.family) size")
            }
        }
    }
}
