import XCTest
@testable import Tessera

/// The Store's wallpapers: every one is distinct, each mood has its share, a third are free.
final class WallpaperCatalogTests: XCTestCase {
    func testEveryWallpaperHasItsOwnId() {
        let ids = WallpaperCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertGreaterThanOrEqual(ids.count, 36, "A large collection")
    }

    func testEveryMoodIsFilledAndHasFreeAndPremiumWallpapers() {
        for category in WallpaperCategory.allCases {
            let list = WallpaperCatalog.wallpapers(in: category)
            XCTAssertGreaterThanOrEqual(list.count, 6, "\(category)")
            XCTAssertTrue(list.contains { !$0.isPremium }, "\(category) has a free wallpaper")
            XCTAssertTrue(list.contains { $0.isPremium }, "\(category) has a Premium wallpaper")
            XCTAssertEqual(list.map(\.number), Array(1...list.count), "Numbered one to n, in order")
        }
    }

    func testAboutAThirdIsFree() {
        let all = WallpaperCatalog.all
        let free = all.filter { !$0.isPremium }.count
        XCTAssertGreaterThanOrEqual(Double(free) / Double(all.count), 0.25)
        XCTAssertLessThanOrEqual(Double(free) / Double(all.count), 0.5)
    }

    func testPalettesAreHexColors() {
        for wallpaper in WallpaperCatalog.all {
            XCTAssertFalse(wallpaper.palette.isEmpty, wallpaper.id)
            for color in wallpaper.palette {
                XCTAssertEqual(color.count, 6, "\(wallpaper.id): \(color)")
                XCTAssertNotNil(UInt32(color, radix: 16), "\(wallpaper.id): \(color)")
            }
        }
    }
}
