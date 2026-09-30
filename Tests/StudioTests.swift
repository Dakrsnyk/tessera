import SwiftUI
import WidgetKit
import XCTest
@testable import Tessera

/// The Widget Studio: every setting is saved with the widget, survives edits, duplicates and new
/// versions, never touches the widget's data, and every style, layout and chart renders.
@MainActor
final class StudioTests: XCTestCase {
    private func temporaryStore() -> SharedStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return SharedStore(directory: directory)
    }

    private func styled() -> StyleOptions {
        var style = StyleOptions()
        style.textHex = "112233"
        style.chartHex = "FF6B57"
        style.rowColors = ["p": "00AA00"]
        style.gradient = GradientSpec(startHex: "FF9A62", endHex: "8E3BA8", direction: .radial, intensity: 0.6)
        style.texture = .paper
        style.border = .dashed
        style.borderWidth = 3
        style.depth = .glow
        style.shape = .panel
        style.valueScale = 1.3
        style.numberWeight = .black
        style.titleCase = .lower
        style.iconStyle = .circle
        style.iconFamily = .outlined
        style.iconPosition = .trailing
        style.layout = .cards
        style.chart = .area
        style.chartValues = true
        style.density = .dense
        style.hidden = ["caption", "row:f"]
        return style
    }

    // MARK: Saving

    func testEverySettingRoundTrips() throws {
        let style = styled()
        let data = try JSONEncoder().encode(style)
        XCTAssertEqual(try JSONDecoder().decode(StyleOptions.self, from: data), style)

        var design = WidgetDesign(kind: .macros, themeID: .neon, accentHex: "8C6CFF", background: .glass, format: .medium)
        design.style = style
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(WidgetDesign.self, from: encoder.encode(design))
        XCTAssertEqual(decoded.style, style)
        XCTAssertEqual(decoded.background, .glass)
        XCTAssertEqual(decoded.themeID, .neon)
    }

    func testOlderAndNewerFilesStillOpen() throws {
        // A widget saved before the Studio: no style at all.
        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","kind":"macros","themeID":"dark"}"#
        let design = try JSONDecoder().decode(WidgetDesign.self, from: Data(old.utf8))
        XCTAssertEqual(design.style, StyleOptions())
        XCTAssertEqual(design.effectiveStyle, ThemeCatalog.theme(.dark).preset)
        // A style from a newer version: unknown values fall back, known ones stay.
        let newer = #"{"layout":"spiral","border":"solid","borderWidth":4,"chart":"radar","hidden":["value"],"future":1}"#
        let style = try JSONDecoder().decode(StyleOptions.self, from: Data(newer.utf8))
        XCTAssertEqual(style.layout, .auto)
        XCTAssertEqual(style.chart, .auto)
        XCTAssertEqual(style.border, .solid)
        XCTAssertEqual(style.borderWidth, 4)
        XCTAssertEqual(style.hidden, ["value"])
    }

    func testStyleSurvivesSavingReopeningAndDuplicating() {
        let store = temporaryStore()
        let model = AppModel(store: store)
        var design = WidgetDesign(kind: .macros, themeID: .dashboard, format: .medium)
        design.style = styled()
        model.save(design)

        let reopened = AppModel(store: store)
        XCTAssertEqual(reopened.design(id: design.id)?.style, design.style, "The look is saved with the widget")

        let copy = try? XCTUnwrap(reopened.duplicate(design))
        XCTAssertEqual(copy?.style, design.style)
        XCTAssertEqual(copy?.themeID, .dashboard)
        let variant = reopened.duplicate(design, asVariant: true)
        XCTAssertEqual(variant?.style, design.style)
        XCTAssertTrue(variant?.name.contains("variante") == true)
    }

    func testDataAndDesignChangeIndependently() {
        var design = WidgetDesign(kind: .countdown)
        design.options.countdownTitle = "Voyage"
        design.style = styled()
        // New data, same look.
        var newData = design
        newData.options.countdownTitle = "Examens"
        XCTAssertEqual(newData.style, design.style)
        // New look, same data.
        let restyled = StylePreset.preset("ocean")!.applied(to: design)
        XCTAssertEqual(restyled.options, design.options)
        XCTAssertEqual(restyled.kind, design.kind)
        XCTAssertEqual(restyled.name, design.name)
        XCTAssertEqual(restyled.style.hidden, design.style.hidden, "The parts the person hid belong to the content")
    }

    // MARK: Styles and themes

    func testThePersonsSettingsWinOverTheStyle() {
        let neon = ThemeCatalog.theme(.neon)
        XCTAssertEqual(neon.preset.border, .glow)
        var design = WidgetDesign(kind: .macros, themeID: .neon)
        XCTAssertEqual(design.effectiveStyle.border, .glow, "The style brings its border")
        design.style.border = .dashed
        design.style.depth = .floating
        XCTAssertEqual(design.effectiveStyle.border, .dashed)
        XCTAssertEqual(design.effectiveStyle.depth, .floating)
        XCTAssertEqual(design.effectiveStyle.chartThickness, neon.preset.chartThickness, "Untouched settings stay the style's")
        // Switching style keeps the person's own settings.
        design.themeID = .editorial
        XCTAssertEqual(design.effectiveStyle.border, .dashed)
        XCTAssertEqual(design.effectiveStyle.layout, .vertical)
    }

    func testStylesAreManyAndDistinct() {
        XCTAssertEqual(ThemeCatalog.all.count, ThemeID.allCases.count)
        XCTAssertEqual(Set(ThemeCatalog.all.map(\.id)).count, ThemeCatalog.all.count)
        XCTAssertGreaterThanOrEqual(ThemeCatalog.all.count, 35)
        XCTAssertGreaterThanOrEqual(ThemeCatalog.free.count, 8)
        // The Studio styles change the composition too, not only the colors.
        let composing = ThemeCatalog.studioThemes.filter { !$0.preset.isDefault }
        XCTAssertEqual(composing.count, ThemeCatalog.studioThemes.count)
        XCTAssertGreaterThanOrEqual(Set(ThemeCatalog.all.map(\.preset.layout)).count, 7)
        // The twelve first styles look exactly as before.
        for theme in ThemeCatalog.classicThemes {
            XCTAssertTrue(theme.preset.isDefault, "\(theme.name) changed")
        }
        XCTAssertEqual(Set(StylePreset.all.map(\.id)).count, StylePreset.all.count)
        for name in ["Midnight", "Pure White", "Ocean", "Forest", "Sunset", "Cyber", "Luxury", "Minimal Black", "Glass", "Monochrome"] {
            XCTAssertTrue(StylePreset.all.contains { $0.name == name }, "Theme \(name) missing")
        }
    }

    func testPremiumSettingsWaitForPremiumOnTheHomeScreen() {
        var design = WidgetDesign(kind: .macros, format: .medium)
        design.style.layout = .cards
        design.style.iconStyle = .circle
        design.style.density = .compact
        XCTAssertFalse(design.usesPremiumFeatures, "Layout, icons and density are free")
        design.style = styled()
        let features = design.premiumFeatures
        XCTAssertTrue(features.contains("Couleurs personnalisées"))
        XCTAssertTrue(features.contains("Bordure"))
        XCTAssertTrue(features.contains("Texture"))
        let free = design.downgradedForFree()
        XCTAssertNil(free.style.textHex)
        XCTAssertEqual(free.style.border, .none)
        XCTAssertEqual(free.style.depth, .none)
        XCTAssertNil(free.style.gradient)
        XCTAssertEqual(free.style.layout, .cards, "Free settings stay")
        XCTAssertEqual(free.style.hidden, design.style.hidden)
        XCTAssertFalse(free.usesPremiumFeatures)
    }

    // MARK: Personal styles

    func testMyStylesAreSavedAndGivenToSeveralWidgets() {
        let store = temporaryStore()
        let model = AppModel(store: store)
        var source = WidgetDesign(kind: .macros, themeID: .luxury, accentHex: "D4AF37")
        source.style.border = .double
        source.style.hidden = ["row:p"]
        let saved = model.saveStyle(named: "Mon thème", from: source)
        XCTAssertEqual(saved.style.hidden, [], "Hidden lines aren't part of a look")

        var weather = WidgetDesign(kind: .weeklyForecast)
        weather.style.hidden = ["footnote"]
        let budget = WidgetDesign(kind: .budgetLeft, themeID: .aurora)
        var withPhoto = WidgetDesign(kind: .caloriesLeft)
        withPhoto.background = .photo("mine.jpg")
        for design in [weather, budget, withPhoto] { model.save(design) }

        XCTAssertEqual(model.apply(saved, to: [weather.id, budget.id, withPhoto.id]), 3)
        let reopened = AppModel(store: store)
        XCTAssertEqual(reopened.savedStyles.map(\.name), ["Mon thème"])
        for id in [weather.id, budget.id, withPhoto.id] {
            let design = reopened.design(id: id)!
            XCTAssertEqual(design.themeID, .luxury)
            XCTAssertEqual(design.style.border, .double)
            XCTAssertTrue(saved.matches(design))
        }
        XCTAssertEqual(reopened.design(id: weather.id)?.kind, .weeklyForecast, "The content stays")
        XCTAssertEqual(reopened.design(id: weather.id)?.style.hidden, ["footnote"])
        XCTAssertEqual(reopened.design(id: withPhoto.id)?.background, .photo("mine.jpg"), "A widget's own photo is kept")

        reopened.renameStyle(saved.id, to: "Doré")
        reopened.deleteStyle(saved.id)
        XCTAssertTrue(AppModel(store: store).savedStyles.isEmpty)
    }

    // MARK: Content

    func testHiddenPartsAndLineColors() {
        var design = WidgetDesign(kind: .macros, format: .medium)
        design.style.hidden = ["caption", "row:f", "seg:Lipides"]
        design.style.rowColors = ["p": "00AA00", "seg:Protéines": "112233"]
        let style = ResolvedStyle(design: design)
        var tile = Tile(title: "Macros", symbol: "chart.pie")
        tile.caption = "Aujourd'hui"
        tile.rows = [TileRow(id: "p", title: "Protéines", colorHex: "E5484D"), TileRow(id: "f", title: "Lipides", colorHex: "3366FF")]
        tile.visual = .segments([TileSegment(label: "Protéines", value: 1, colorHex: "E5484D"), TileSegment(label: "Lipides", value: 1, colorHex: "3366FF")])
        let shown = style.filtered(tile)
        XCTAssertNil(shown.caption)
        XCTAssertEqual(shown.rows.map(\.id), ["p"])
        XCTAssertEqual(shown.rows.first?.colorHex, "00AA00")
        guard case let .segments(segments) = shown.visual else { return XCTFail() }
        XCTAssertEqual(segments.map(\.label), ["Protéines"])
        XCTAssertEqual(segments.first?.colorHex, "112233")
    }

    func testChartsOfferedMatchTheNumbers() {
        XCTAssertEqual(TileVisual.bars([1, 2], labels: [], highlight: nil).chartFamily, .series)
        XCTAssertEqual(TileVisual.ring(0.4).chartFamily, .progress)
        XCTAssertEqual(TileVisual.week([true]).chartFamily, .none)
        XCTAssertTrue(ChartKind.options(for: .series).contains(.histogram))
        XCTAssertFalse(ChartKind.options(for: .series).contains(.gauge), "A gauge needs a single value")
        XCTAssertTrue(ChartKind.options(for: .progress).contains(.gauge))
        XCTAssertTrue(ChartKind.options(for: .segments).contains(.pie))
    }

    func testIconFamiliesKeepExistingSymbols() {
        XCTAssertEqual(SymbolFamily.baseName("flame.circle.fill"), "flame")
        XCTAssertEqual(SymbolFamily.resolve("flame.fill", family: .outlined), "flame")
        XCTAssertEqual(SymbolFamily.resolve("flame", family: .filled), "flame.fill")
        XCTAssertEqual(SymbolFamily.resolve("pas.un.symbole", family: .circled), "pas.un.symbole")
        XCTAssertEqual(SymbolFamily.resolve("drop.fill", family: .theme), "drop.fill")
    }

    // MARK: Rendering

    private func render(_ design: WidgetDesign, _ family: WidgetFamily, file: StaticString = #filePath, line: UInt = #line) {
        let view = WidgetPreview(design: design, family: family, payload: SamplePayload.make(for: design.kind), width: WidgetMetrics.size(family).width)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        XCTAssertNotNil(renderer.uiImage, "\(design.themeID) \(design.style.layout) \(family) doesn't render", file: file, line: line)
    }

    func testEveryStyleRenders() {
        let kinds: [WidgetKind] = [.caloriesLeft, .nutritionWeek, .macros, .clock, .weather]
        for (index, theme) in ThemeCatalog.all.enumerated() {
            let design = WidgetDesign(kind: kinds[index % kinds.count], themeID: theme.id)
            render(design, .systemSmall)
            render(design, .systemMedium)
        }
        for preset in StylePreset.all {
            render(preset.applied(to: WidgetDesign(kind: .macros)), .systemMedium)
        }
    }

    func testEveryLayoutChartAndLookRenders() {
        for layout in LayoutKind.allCases {
            for kind in [WidgetKind.caloriesLeft, .macros, .nutritionWeek, .todaysWorkout] {
                var design = WidgetDesign(kind: kind)
                design.style.layout = layout
                for family in kind.families where !family.isAccessory {
                    render(design, family)
                }
            }
        }
        for chart in ChartKind.allCases {
            for kind in [WidgetKind.caloriesLeft, .macros, .nutritionWeek] {
                var design = WidgetDesign(kind: kind)
                design.style.chart = chart
                design.style.chartValues = true
                render(design, .systemMedium)
            }
        }
        var looks = WidgetDesign(kind: .macros, background: .gradient)
        looks.style = styled()
        for border in BorderKind.allCases {
            looks.style.border = border
            for depth in DepthKind.allCases {
                looks.style.depth = depth
                render(looks, .systemSmall)
            }
        }
        for texture in TextureKind.allCases {
            looks.style.texture = texture
            render(looks, .systemLarge)
        }
        for shape in ShapeKind.allCases {
            looks.style.shape = shape
            render(looks, .systemMedium)
        }
    }
}
