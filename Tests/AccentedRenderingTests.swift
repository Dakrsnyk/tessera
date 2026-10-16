import SwiftUI
import WidgetKit
import XCTest
@testable import Tessera

/// The « Clair » (iOS 26) and « Teinté » (iOS 18) Home Screen appearances (request of 2026-10-16): iOS keeps
/// only the opacity of each element and replaces the widget's background. What carries text is then filled
/// lightly and outlined while the text stays opaque, the parts of a whole differ by their opacity, the
/// style no longer counts on its background, and nothing changes in full color.
@MainActor
final class AccentedRenderingTests: XCTestCase {
    private func opacity(_ color: Color) -> Double {
        Double(color.resolve(in: EnvironmentValues()).opacity)
    }

    /// An opaque panel (the Jade palette), a glowing style (Néon), a photo behind the week's schedule.
    private var designs: [WidgetDesign] {
        [
            ColorPalette.palette("jade")!.applied(to: WidgetDesign(kind: .timetable, format: .large)),
            WidgetDesign(kind: .macros, themeID: .neon, format: .medium),
            WidgetDesign(kind: .timetable, background: .photo("missing"), format: .large),
        ]
    }

    func testOnlyTheAppearancesWithoutColorsChangeTheWidget() {
        XCTAssertFalse(AccentedStyle.isMonochrome(.fullColor))
        XCTAssertTrue(AccentedStyle.isMonochrome(.accented), "« Clair » et « Teinté »")
        XCTAssertTrue(AccentedStyle.isMonochrome(.vibrant), "Écran verrouillé de l'iPad, mode En veille la nuit")
    }

    func testTextOnAFilledShapeStaysReadableWithoutColors() {
        // A block of the schedule, a button, a pill: a light fill and its outline under opaque text.
        for prominent in [false, true] {
            let fill = AccentedStyle.fillOpacity(isMonochrome: true, isProminent: prominent)
            XCTAssertGreaterThanOrEqual(fill, 0.2)
            XCTAssertLessThanOrEqual(fill, 0.35)
            XCTAssertGreaterThanOrEqual(1 - fill, 0.6, "Le texte opaque se détache de son fond")
        }
        XCTAssertGreaterThan(AccentedStyle.fillOpacity(isMonochrome: true, isProminent: true), AccentedStyle.fillOpacity(isMonochrome: true),
                             "L'action principale se distingue")
        XCTAssertTrue(AccentedStyle.outlines(isMonochrome: true))
        XCTAssertGreaterThan(AccentedStyle.outlineOpacity, AccentedStyle.fillOpacity(isMonochrome: true, isProminent: true), "Le contour dessine la forme")
        // Bars, rings and slices without text stay full.
        XCTAssertEqual(AccentedStyle.fillOpacity(isMonochrome: true, carriesText: false), 1)
        XCTAssertFalse(AccentedStyle.outlines(isMonochrome: true, carriesText: false))
        // In full color, nothing changes.
        XCTAssertEqual(AccentedStyle.fillOpacity(isMonochrome: false), 1)
        XCTAssertEqual(AccentedStyle.fillOpacity(isMonochrome: false, isProminent: true), 1)
        XCTAssertFalse(AccentedStyle.outlines(isMonochrome: false))
    }

    func testPartsOfAWholeStayApartWithoutColors() {
        let steps = (0..<6).map { AccentedStyle.partOpacity(at: $0, isMonochrome: true) }
        XCTAssertEqual(steps.first, 1, "La première part reste pleine")
        XCTAssertEqual(Set(steps).count, steps.count, "Chaque part a son opacité")
        XCTAssertTrue(steps.allSatisfy { $0 > 0 && $0 <= 1 })
        for index in steps.indices {
            let next = steps[(index + 1) % steps.count]
            XCTAssertGreaterThanOrEqual(abs(steps[index] - next), 0.2, "Deux parts voisines se distinguent (\(index))")
        }
        XCTAssertEqual(AccentedStyle.partOpacity(at: 6, isMonochrome: true), steps[0], "Les parts suivantes reprennent la suite")
        XCTAssertEqual(AccentedStyle.partOpacity(at: -1, isMonochrome: true), steps[5])
        XCTAssertEqual((0..<8).map { AccentedStyle.partOpacity(at: $0, isMonochrome: false) }, Array(repeating: 1, count: 8))

        let style = ResolvedStyle(design: WidgetDesign(kind: .macros, format: .medium)).rendered(for: .accented)
        XCTAssertEqual(opacity(style.partColor("E5484D", at: 0)), 1, accuracy: 0.01)
        XCTAssertEqual(opacity(style.partColor("3366FF", at: 1)), steps[1], accuracy: 0.01)
        let colored = ResolvedStyle(design: WidgetDesign(kind: .macros, format: .medium))
        XCTAssertEqual(colored.partColor("3366FF", at: 1).hexString, "3366FF", "En couleur, chaque part garde sa couleur")
    }

    func testADoneHabitStaysTheStrongerStateWithoutColors() {
        // Done: a lit disc, its outline and a full symbol; to do: a panel, a ring and a dimmed symbol.
        let doneFill = AccentedStyle.fillOpacity(isMonochrome: true, isProminent: true)
        XCTAssertGreaterThan(doneFill, AccentedStyle.panelOpacity)
        XCTAssertGreaterThan(AccentedStyle.outlineOpacity, AccentedStyle.pendingRingOpacity(isMonochrome: true), "L'anneau « à faire » reste plus pâle que le contour « fait »")
        XCTAssertLessThanOrEqual(AccentedStyle.pendingRingWidth(isMonochrome: true), 1, "Pas plus épais que le contour « fait »")
        XCTAssertLessThan(AccentedStyle.secondaryOpacity, 1, "Le symbole « à faire » est atténué")
        // In full color, as before.
        XCTAssertEqual(AccentedStyle.pendingRingOpacity(isMonochrome: false), 0.7)
        XCTAssertEqual(AccentedStyle.pendingRingWidth(isMonochrome: false), 2)
    }

    func testTodayStandsOutOfTheYearWithoutColors() {
        XCTAssertEqual(AccentedStyle.elapsedOpacity(isMonochrome: false), 0.85, "En couleur, comme avant")
        XCTAssertLessThanOrEqual(AccentedStyle.elapsedOpacity(isMonochrome: true), 0.5, "Aujourd'hui, plein, se détache des jours passés")
        XCTAssertGreaterThan(AccentedStyle.elapsedOpacity(isMonochrome: true), AccentedStyle.trackOpacity, "Les jours passés se détachent des jours à venir")
    }

    func testTheStyleBecomesAnOpacityHierarchyWithoutColors() {
        for mode in [WidgetRenderingMode.accented, .vibrant] {
            for design in designs {
                let full = ResolvedStyle(design: design)
                let shown = full.rendered(for: mode)
                let name = "\(design.themeID) \(mode)"
                XCTAssertTrue(shown.isAccented, name)
                XCTAssertEqual(opacity(shown.primary), 1, accuracy: 0.01, name)
                XCTAssertEqual(opacity(shown.numberColor), 1, accuracy: 0.01, name)
                XCTAssertEqual(opacity(shown.onAccent), 1, accuracy: 0.01, "\(name) : le texte d'un bouton reste opaque")
                XCTAssertEqual(shown.primary.hexString, "FFFFFF", "\(name) : le blanc se lit aussi en mode vibrant")
                XCTAssertEqual(opacity(shown.secondary), AccentedStyle.secondaryOpacity, accuracy: 0.01, name)
                XCTAssertLessThan(opacity(shown.panel), 0.2, "\(name) : une carte ou un panneau ne cache plus le texte")
                XCTAssertLessThan(opacity(shown.track), opacity(shown.secondary), name)
                XCTAssertEqual(shown.options.depth, DepthKind.none, "\(name) : une ombre deviendrait un halo blanc")
                XCTAssertFalse(shown.prefersMulticolorSymbols, name)
            }
        }
        XCTAssertEqual(opacity(ResolvedStyle(design: designs[0]).panel), 1, accuracy: 0.01, "Le panneau opaque de Jade, qui cachait le texte")
        XCTAssertEqual(ResolvedStyle(design: designs[1]).options.depth, DepthKind.glow)
    }

    func testFullColorStaysExactlyAsDesigned() {
        for design in designs {
            let full = ResolvedStyle(design: design)
            let shown = full.rendered(for: .fullColor)
            XCTAssertFalse(shown.isAccented)
            XCTAssertEqual(shown.primary.hexString, full.primary.hexString)
            XCTAssertEqual(shown.secondary.hexString, full.secondary.hexString)
            XCTAssertEqual(shown.accent.hexString, full.accent.hexString)
            XCTAssertEqual(shown.chart.hexString, full.chart.hexString)
            XCTAssertEqual(opacity(shown.panel), opacity(full.panel), accuracy: 0.001)
            XCTAssertEqual(opacity(shown.secondary), opacity(full.secondary), accuracy: 0.001)
            XCTAssertEqual(shown.options, full.options)
            XCTAssertEqual(shown.prefersMulticolorSymbols, full.prefersMulticolorSymbols)
        }
        XCTAssertFalse(ResolvedStyle(design: WidgetDesign(kind: .clock)).isAccented, "Les aperçus de l'app restent en couleur")
    }
}
