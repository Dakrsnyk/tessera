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
        var items = StoreShowcase.mediums + StoreShowcase.larges + StoreShowcase.lockScreen + StoreShowcase.allStyles + StoreShowcase.allColors
        items += (StoreShowcase.collectionsTop + StoreShowcase.collectionsBottom).flatMap(\.items)
        let widgets = items.map(\.widget) + StoreShowcase.features.map(\.widget)
        for widget in widgets {
            XCTAssertTrue(widget.kind.families.contains(widget.family), "\(widget.kind) has no \(widget.family) size")
        }
        XCTAssertEqual(StoreShowcase.allStyles.count, ThemeCatalog.all.count)
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
