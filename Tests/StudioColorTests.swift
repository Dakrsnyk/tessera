import SwiftUI
import WidgetKit
import XCTest
@testable import Tessera

/// The Studio's colors: the main color repaints the whole style and stays readable, a palette changes
/// every color, both survive a save, and several widgets made together can share one look.
@MainActor
final class StudioColorTests: XCTestCase {
    private func contrast(_ a: String, _ b: String) -> Double {
        let la = ColorMath.relativeLuminance(ColorMath.rgb(a).r, ColorMath.rgb(a).g, ColorMath.rgb(a).b)
        let lb = ColorMath.relativeLuminance(ColorMath.rgb(b).r, ColorMath.rgb(b).g, ColorMath.rgb(b).b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b)
        return min(d, 1 - d)
    }

    // MARK: Main color

    func testRecolorTakesTheHueAndKeepsTheBrightness() {
        for main in Palette.freeAccents.map(\.hex) where ColorMath.hsl(main).s > 0.1 {
            for original in ["FF2DAA", "0E2A47", "C6FF00", "1D4E89", "D4AF37", "7CFFA0"] {
                let painted = ColorMath.recolor(original, to: main)
                let before = ColorMath.relativeLuminance(ColorMath.rgb(original).r, ColorMath.rgb(original).g, ColorMath.rgb(original).b)
                let after = ColorMath.relativeLuminance(ColorMath.rgb(painted).r, ColorMath.rgb(painted).g, ColorMath.rgb(painted).b)
                XCTAssertEqual(after, before, accuracy: 0.03, "\(original) → \(main) : la luminosité doit rester")
                XCTAssertLessThan(hueDistance(ColorMath.hsl(painted).h, ColorMath.hsl(main).h), 0.04, "\(original) → \(main) : la teinte doit être celle de la couleur principale")
            }
        }
    }

    func testWhiteAndBlackSurfacesTakeATint() {
        let white = ColorMath.recolor("FFFFFF", to: "FF6B57", surface: true)
        let black = ColorMath.recolor("000000", to: "3366FF", surface: true)
        XCTAssertNotEqual(white, "FFFFFF", "Un fond blanc prend une teinte de la couleur principale")
        XCTAssertNotEqual(black, "000000", "Un fond noir prend une teinte de la couleur principale")
        XCTAssertTrue(ColorMath.isLight(white))
        XCTAssertFalse(ColorMath.isLight(black))
        // Text isn't a surface: pure white text stays white.
        XCTAssertEqual(ColorMath.recolor("FFFFFF", to: "FF6B57"), "FFFFFF")
    }

    /// Every style stays readable in every main color: text keeps its contrast with the background.
    func testEveryStyleStaysReadableInEveryMainColor() {
        func hex(_ color: ThemeColor) -> String? {
            switch color {
            case let .fixed(hex, opacity): opacity >= 0.99 ? hex : nil
            case let .adaptive(light, _): light
            default: nil
            }
        }
        for theme in ThemeCatalog.all {
            guard case let .solid(background) = theme.background, let bg = hex(background), let text = hex(theme.primary) else { continue }
            let original = contrast(bg, text)
            for main in Palette.freeAccents.map(\.hex) {
                let painted = contrast(ColorMath.recolor(bg, to: main, surface: true), ColorMath.recolor(text, to: main))
                XCTAssertGreaterThan(painted, min(4.5, original * 0.75), "\(theme.name) en \(main) : le texte doit rester lisible")
            }
        }
    }

    func testTheMainColorRepaintsTheWholeStyle() {
        var design = WidgetDesign(kind: .macros, themeID: .neon, accentHex: "2F8F7A", format: .medium)
        let before = ResolvedStyle(design: design)
        design = design.recolored(to: "3366FF")
        let after = ResolvedStyle(design: design)
        XCTAssertTrue(design.style.recolor)
        XCTAssertEqual(design.accentHex, "3366FF")
        XCTAssertEqual(after.accent.hexString, "3366FF", "La couleur d'accent du style (rose néon) devient la couleur principale")
        XCTAssertNotEqual(before.primary.hexString, after.primary.hexString, "Le texte prend la teinte")
        XCTAssertNotEqual(before.panel.hexString, after.panel.hexString, "Les cartes prennent la teinte")
        XCTAssertFalse(after.series.isEmpty, "Les lignes et parts prennent des nuances de la couleur principale")
        XCTAssertEqual(after.series.first, "3366FF")
        // Nothing of the look is lost: only colors change.
        XCTAssertEqual(design.themeID, .neon)
        let free = WidgetDesign(kind: .macros, themeID: .minimal, format: .medium).recolored(to: "3366FF")
        XCTAssertFalse(free.usesPremiumFeatures, "Une couleur principale gratuite ne rend pas le widget Premium")
    }

    func testTheMainColorReplacesAPaletteAndItsBackground() {
        let palette = ColorPalette.palette("neon")!
        var design = palette.applied(to: WidgetDesign(kind: .macros, themeID: .modern, format: .medium))
        design = design.recolored(to: "FF6B57")
        XCTAssertNil(design.style.textHex)
        XCTAssertNil(design.style.chartHex)
        XCTAssertNil(design.style.panelHex)
        XCTAssertTrue(design.style.seriesHexes.isEmpty)
        XCTAssertFalse(palette.matches(design))
        guard case let .color(background) = design.background else { return XCTFail("Le fond de la palette est repeint") }
        XCTAssertNotEqual(background, palette.background[0])
        XCTAssertLessThan(hueDistance(ColorMath.hsl(background).h, ColorMath.hsl("FF6B57").h), 0.05)
    }

    // MARK: Palettes

    func testAPaletteChangesEveryColor() {
        for palette in ColorPalette.all {
            let design = palette.applied(to: WidgetDesign(kind: .macros, themeID: .modern, format: .medium))
            XCTAssertTrue(palette.matches(design), palette.name)
            let s = design.style
            XCTAssertEqual(design.accentHex, palette.accent)
            for (name, value) in [("texte", s.textHex), ("secondaire", s.secondaryHex), ("chiffres", s.numberHex), ("icônes", s.iconHex),
                                  ("graphiques", s.chartHex), ("bordure", s.borderHex), ("surfaces", s.panelHex),
                                  ("positif", s.positiveHex), ("négatif", s.negativeHex)] {
                XCTAssertNotNil(value, "\(palette.name) : la couleur « \(name) » doit changer")
            }
            XCTAssertFalse(s.seriesHexes.isEmpty, "\(palette.name) : les lignes changent aussi")
            switch design.background {
            case .color, .gradient: break
            default: XCTFail("\(palette.name) : le fond doit changer")
            }
            // Readable: the palette's text on its own background.
            let background = palette.background.count > 1 ? ColorMath.mix(palette.background[0], palette.background[1], 0.5) : palette.background[0]
            XCTAssertGreaterThan(contrast(background, palette.text), 4.5, "\(palette.name) : texte lisible")
            let resolved = ResolvedStyle(design: design)
            XCTAssertEqual(resolved.primary.hexString, palette.text)
            XCTAssertEqual(resolved.series, palette.series)
        }
        XCTAssertEqual(Set(ColorPalette.all.map(\.id)).count, ColorPalette.all.count)
    }

    func testPaletteColorsTheLinesAndParts() {
        let design = ColorPalette.palette("midnight")!.applied(to: WidgetDesign(kind: .macros, format: .medium))
        let style = ResolvedStyle(design: design)
        var tile = Tile(title: "Macros", symbol: "chart.pie")
        tile.rows = [TileRow(id: "p", title: "Protéines", colorHex: "E5484D"), TileRow(id: "g", title: "Glucides", colorHex: "3366FF"), TileRow(id: "x", title: "Total")]
        tile.visual = .segments([TileSegment(label: "Protéines", value: 1, colorHex: "E5484D"), TileSegment(label: "Glucides", value: 1, colorHex: "3366FF")])
        let shown = style.filtered(tile)
        XCTAssertEqual(shown.rows.map(\.colorHex), [style.series[0], style.series[1], nil], "Une ligne sans couleur reste sans couleur")
        guard case let .segments(segments) = shown.visual else { return XCTFail() }
        XCTAssertEqual(segments.map(\.colorHex), Array(style.series.prefix(2)))
        // A color picked for one line still wins.
        var picked = design
        picked.style.rowColors = ["g": "00AA00"]
        XCTAssertEqual(ResolvedStyle(design: picked).filtered(tile).rows[1].colorHex, "00AA00")
    }

    func testBackToTheStyleColors() {
        let design = ColorPalette.palette("coral")!.applied(to: WidgetDesign(kind: .macros, themeID: .modern, format: .medium))
        let reset = design.withStyleColors()
        XCTAssertEqual(reset.background, .theme)
        XCTAssertEqual(reset.style.look, StyleOptions().look, "Plus aucune couleur choisie : celles du style")
        let photo = { () -> WidgetDesign in
            var d = design
            d.background = .photo("mine.jpg")
            return d.withStyleColors()
        }()
        XCTAssertEqual(photo.background, .photo("mine.jpg"), "Une photo reste")
    }

    // MARK: Saved, and shared

    func testColorsSurviveASave() throws {
        var design = ColorPalette.palette("sunset")!.applied(to: WidgetDesign(kind: .macros, format: .medium))
        let decoded = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(design))
        XCTAssertEqual(decoded, design)
        design = design.recolored(to: "8C6CFF")
        let again = try JSONDecoder().decode(WidgetDesign.self, from: JSONEncoder().encode(design))
        XCTAssertTrue(again.style.recolor)
        XCTAssertEqual(again, design)
        // A widget saved before these settings existed opens with the style's colors.
        let old = try JSONDecoder().decode(StyleOptions.self, from: Data(#"{"textHex":"112233"}"#.utf8))
        XCTAssertFalse(old.recolor)
        XCTAssertNil(old.panelHex)
        XCTAssertTrue(old.seriesHexes.isEmpty)
    }

    func testWidgetsMadeTogetherShareTheLookNotTheContent() {
        var calories = WidgetDesign(name: "Mes calories", kind: .caloriesLeft, format: .small)
        calories.style.hidden = ["caption"]
        var macros = WidgetDesign(kind: .macros, format: .small)
        macros = ColorPalette.palette("neon")!.applied(to: macros)
        macros.themeID = .dashboard
        macros.style.border = .dashed
        let shared = calories.withLook(of: macros)
        XCTAssertEqual(shared.name, "Mes calories")
        XCTAssertEqual(shared.kind, .caloriesLeft)
        XCTAssertEqual(shared.style.hidden, ["caption"], "Chaque widget garde ce qu'il cache")
        XCTAssertEqual(shared.themeID, .dashboard)
        XCTAssertEqual(shared.style.border, .dashed)
        XCTAssertTrue(ColorPalette.palette("neon")!.matches(shared))
        var photo = macros
        photo.background = .photo("mine.jpg")
        XCTAssertNotEqual(calories.withLook(of: photo).background, .photo("mine.jpg"), "Une photo reste au widget qui l'a")
    }

    func testOldSectionNamesStillOpen() {
        XCTAssertEqual(StudioSection(name: "themes"), .style)
        XCTAssertEqual(StudioSection(name: "colors"), .colors)
        XCTAssertNil(StudioSection(name: "layout"))
        XCTAssertFalse(StudioSection.allCases.map(\.rawValue).contains("depth"))
    }
}
