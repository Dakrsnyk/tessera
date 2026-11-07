import XCTest
import SwiftUI
@testable import Ardane

/// Every widget in every size it offers (Home Screen and Lock Screen) when the person has entered nothing and
/// no network answer arrived: the tile is built, nothing is « NaN » or infinite, and the view draws.
@MainActor
final class WidgetEmptyDataTests: XCTestCase {
    private let now = DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))!

    private func strings(of tile: Tile) -> [String] {
        [tile.title, tile.value, tile.unit, tile.caption, tile.detail, tile.inline, tile.shortValue].compactMap { $0 }
            + tile.rows.flatMap { [$0.title] + [$0.value, $0.detail].compactMap { $0 } }
    }

    func testEveryWidgetBuildsItsTileWithoutAnyData() {
        let payload = WidgetPayload()
        for kind in WidgetKind.allCases {
            let design = WidgetDesign(kind: kind)
            for family in kind.families {
                let context = RenderContext(design: design, style: ResolvedStyle(design: design), family: family, date: now, payload: payload, isInteractive: false)
                let tile = TileFactory.make(context)
                XCTAssertFalse(tile.title.isEmpty, "\(kind) \(family) has a title")
                for text in strings(of: tile) {
                    XCTAssertFalse(text.contains("NaN"), "\(kind) \(family) shows « \(text) »")
                    XCTAssertFalse(text.contains("∞"), "\(kind) \(family) shows « \(text) »")
                }
                if let gauge = tile.gauge {
                    XCTAssertTrue(gauge.isFinite, "\(kind) \(family) gauge")
                }
            }
        }
    }

    func testEveryWidgetDrawsWithoutAnyData() {
        let payload = WidgetPayload()
        for kind in WidgetKind.allCases {
            let design = WidgetDesign(kind: kind)
            for family in kind.families {
                let view = WidgetPreview(design: design, family: family, payload: payload, width: WidgetMetrics.size(family).width, date: now)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                XCTAssertNotNil(renderer.uiImage, "\(kind) \(family) does not draw without data")
            }
        }
    }
}
