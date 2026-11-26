import XCTest
@testable import Ardane

/// Lot 2 des styles : chaque nouvelle valeur a un titre et se relit depuis sa valeur brute.
final class StyleLot2Tests: XCTestCase {
    func testNewCasesHaveTitleAndDecode() throws {
        func check<T: RawRepresentable & Codable & Equatable>(_ values: [T], _ title: (T) -> String) throws where T.RawValue == String {
            for value in values {
                XCTAssertFalse(title(value).isEmpty)
                let data = try JSONEncoder().encode(["v": value.rawValue])
                let back = try JSONDecoder().decode([String: T].self, from: data)
                XCTAssertEqual(back["v"], value)
            }
        }
        try check([TextureKind.guilloche, .marble, .terrazzo, .linen, .topo, .brushed, .sunburst]) { $0.title }
        try check([BorderKind.ticket, .stitched, .bevel, .inset]) { $0.title }
        try check([DepthKind.longShadow]) { $0.title }
        try check([TitleCase.smallCaps]) { $0.title }
    }
}
