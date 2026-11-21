import SwiftUI
import XCTest
@testable import Ardane

/// La police des widgets (« Texte » du Studio, demande du PDG du 2026-11-21) : au moins 100 polices de plusieurs
/// styles, toutes déjà installées sur l'iPhone, un réglage facultatif qui se sauvegarde et se relit, et qui reste
/// du Premium.
@MainActor
final class FontCatalogTests: XCTestCase {
    func testAtLeastAHundredFontsAreInstalled() {
        XCTAssertGreaterThanOrEqual(FontCatalog.available.count, 100,
            "polices manquantes : \(Set(FontCatalog.candidates.map(\.id)).subtracting(FontCatalog.available.map(\.id)).sorted())")
    }

    func testEveryKindHasFonts() {
        for kind in FontCategory.allCases {
            XCTAssertFalse(FontCatalog.fonts(in: kind).isEmpty, "aucune police pour \(kind.rawValue)")
        }
    }

    func testIdentifiersAreUnique() {
        let ids = FontCatalog.candidates.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "doublons : \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys.sorted())")
    }

    func testBoldFacesExistWhenGiven() {
        for entry in FontCatalog.available {
            guard let bold = entry.boldID else { continue }
            XCTAssertTrue(FontCatalog.isInstalled(bold), "\(entry.id) : la face grasse \(bold) n'existe pas")
        }
    }

    func testAnUnknownFontFallsBackToTheStyle() {
        XCTAssertNil(FontCatalog.entry(for: nil))
        XCTAssertNil(FontCatalog.entry(for: "PoliceQuiNExistePas"))
        var design = WidgetDesign(kind: .clock)
        design.style.fontName = "PoliceQuiNExistePas"
        XCTAssertNil(ResolvedStyle(design: design).customFont, "une police absente ne casse pas le widget")
    }

    func testTheChosenFontReachesTheWidgetStyle() throws {
        let entry = try XCTUnwrap(FontCatalog.available.first)
        var design = WidgetDesign(kind: .clock)
        XCTAssertNil(ResolvedStyle(design: design).customFont)
        design.style.fontName = entry.id
        XCTAssertEqual(ResolvedStyle(design: design).customFont?.id, entry.id)
    }

    func testTheFontIsSavedAndReadBack() throws {
        let entry = try XCTUnwrap(FontCatalog.available.first)
        var design = WidgetDesign(kind: .clock)
        design.style.fontName = entry.id
        let data = try JSONEncoder().encode(design)
        let back = try JSONDecoder().decode(WidgetDesign.self, from: data)
        XCTAssertEqual(back.style.fontName, entry.id)
    }

    func testAWidgetSavedBeforeHasNoFont() throws {
        let design = WidgetDesign(kind: .clock)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(design)) as? [String: Any])
        var style = try XCTUnwrap(json["style"] as? [String: Any])
        style.removeValue(forKey: "fontName")
        json["style"] = style
        let back = try JSONDecoder().decode(WidgetDesign.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(back.style.fontName)
    }

    func testTheFontIsAPremiumSettingAndFollowsTheStyleOverride() throws {
        var options = StyleOptions()
        XCTAssertTrue(options.premiumFeatures.isEmpty)
        options.fontName = "Georgia"
        XCTAssertTrue(options.premiumFeatures.contains(tr("Police personnalisée")))
        XCTAssertNil(options.withoutPremium().fontName)
        // Sur le style du thème : la police de la personne gagne, sinon celle du style.
        var base = StyleOptions()
        base.fontName = "Avenir-Book"
        XCTAssertEqual(StyleOptions().over(base).fontName, "Avenir-Book")
        XCTAssertEqual(options.over(base).fontName, "Georgia")
    }

    func testOnlyHeavyWeightsAskForABoldFace() {
        XCTAssertTrue(FontCatalog.isBold(.semibold))
        XCTAssertTrue(FontCatalog.isBold(.black))
        XCTAssertFalse(FontCatalog.isBold(.regular))
        XCTAssertFalse(FontCatalog.isBold(.light))
    }

    func testTheTextToolSitsAfterTheColors() {
        let order = StudioSection.allCases
        let colors = try? XCTUnwrap(order.firstIndex(of: .colors))
        XCTAssertEqual(order.firstIndex(of: .text), colors.map { $0 + 1 })
        XCTAssertEqual(StudioSection(name: "text"), .text)
    }
}
