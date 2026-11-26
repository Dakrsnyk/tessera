import XCTest
@testable import Ardane

/// The Studio's « Style » tab (« Thème » and « Style » merged on the 2026-11-26): 500+ looks, 4 free.
/// The 3-axes difference rule and the contrast are checked on the source by scripts/styles/library.py.
final class StyleLibraryTests: XCTestCase {
    func testTheLibraryHasFiveHundredStylesAndFourFree() {
        XCTAssertGreaterThanOrEqual(StyleCatalog.all.count, 504, "500 styles en plus des 4 d'origine")
        XCTAssertEqual(StyleCatalog.all.filter(\.isFree).map(\.id), ["minimal", "light", "dark", "monochrome"])
        XCTAssertEqual(StyleCatalog.premiumCount, StyleCatalog.all.count - 4)
    }

    func testIdsAndNamesAreUnique() {
        let ids = StyleCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Deux styles ont le même identifiant")
        let names = StyleCatalog.all.map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count, "Deux styles ont le même nom")
        for look in StyleCatalog.all {
            XCTAssertFalse(look.name.isEmpty, look.id)
            XCTAssertFalse(look.summary.isEmpty, look.id)
            XCTAssertEqual(StyleCatalog.look(look.id)?.id, look.id)
        }
    }

    func testEveryPremiumStyleNeedsPremiumOnTheWidget() {
        for look in StyleCatalog.all where look.isPremium {
            let design = look.applied(to: WidgetDesign(kind: .budgetLeft, format: .small))
            XCTAssertTrue(design.usesPremiumFeatures, "\(look.id) doit demander Premium")
        }
        for look in StyleCatalog.all where look.isFree {
            let design = look.applied(to: WidgetDesign(kind: .budgetLeft, format: .small))
            XCTAssertFalse(design.usesPremiumFeatures, "\(look.id) doit rester gratuit")
        }
    }

    func testApplyingAStyleKeepsTheContentAndIsSelected() {
        var design = WidgetDesign(kind: .macros, format: .medium)
        design.style.hidden = ["caption", "row:protein"]
        design.showsTitle = false
        for look in StyleCatalog.all {
            let styled = look.applied(to: design)
            XCTAssertEqual(styled.kind, design.kind)
            XCTAssertEqual(styled.style.hidden, design.style.hidden, "\(look.id) a perdu les parties masquées")
            XCTAssertEqual(styled.showsTitle, design.showsTitle)
            XCTAssertTrue(look.matches(styled), "\(look.id) n'est pas sélectionné une fois appliqué")
        }
    }

    func testTheOriginalStylesKeepThePersonsColor() {
        var design = WidgetDesign(kind: .note)
        design.accentHex = "FF2D55"
        for id in ["minimal", "light", "dark", "monochrome"] {
            XCTAssertEqual(StyleCatalog.look(id)?.applied(to: design).accentHex, "FF2D55")
        }
    }

    func testOldThemeAndStyleSectionsOpenStyle() {
        XCTAssertEqual(StudioSection(name: "theme"), .style)
        XCTAssertEqual(StudioSection(name: "themes"), .style)
        XCTAssertFalse(StudioSection.allCases.map(\.rawValue).contains("theme"))
    }

    func testEveryStyleIsInANamedFamilyRow() {
        let named = Set(StyleCatalog.families.map(\.id))
        XCTAssertEqual(named.count, StyleCatalog.families.count)
        let inRows = StyleCatalog.families.flatMap { StyleCatalog.looks(in: $0.id) }
        XCTAssertEqual(inRows.count, StyleCatalog.all.count - StyleCatalog.originals.count, "Un style n'est dans aucune rangée")
        XCTAssertTrue(StyleCatalog.families.allSatisfy { !$0.name.isEmpty && !StyleCatalog.looks(in: $0.id).isEmpty })
    }

    func testTheFiltersSortTheStyles() {
        let dark = StyleCatalog.look("dark")!, light = StyleCatalog.look("light")!
        XCTAssertTrue(StyleFilter.dark.includes(dark))
        XCTAssertFalse(StyleFilter.dark.includes(light))
        XCTAssertTrue(StyleFilter.light.includes(light))
        XCTAssertEqual(StyleCatalog.all.filter(StyleFilter.free.includes).count, 4)
        for filter in StyleFilter.allCases where filter != .free {
            XCTAssertGreaterThan(StyleCatalog.all.filter(filter.includes).count, 20, "\(filter) montre trop peu de styles")
        }
    }
}
