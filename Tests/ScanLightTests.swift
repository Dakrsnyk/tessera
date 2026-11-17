import UIKit
import XCTest
@testable import Ardane

/// The light of the scanners (2026-11-17): when the scene is dark it comes on by itself, and the person can set it
/// to automatic, on or off. The rules are pure (the exposure the camera reports), so they are tested here; the light
/// itself only exists on an iPhone.
@MainActor
final class ScanLightTests: XCTestCase {
    /// Preferences of its own for one test, removed after it.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "scan-flash-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    // MARK: Is it dark?

    func testTheExposureValueFollowsWhatTheCameraChose() throws {
        // f/1.8, 1/30 s, ISO 100: log2(1.8² × 30) = 6.60.
        let base = try XCTUnwrap(ScanLight.exposureValue(iso: 100, seconds: 1.0 / 30, aperture: 1.8))
        XCTAssertEqual(base, 6.60, accuracy: 0.01)
        // Twice the sensitivity, or twice the time: one stop less light in the scene.
        XCTAssertEqual(try XCTUnwrap(ScanLight.exposureValue(iso: 200, seconds: 1.0 / 30, aperture: 1.8)), base - 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(ScanLight.exposureValue(iso: 100, seconds: 1.0 / 15, aperture: 1.8)), base - 1, accuracy: 0.001)
    }

    func testAReadingThatCannotBeUsedDecidesNothing() {
        XCTAssertNil(ScanLight.exposureValue(iso: 0, seconds: 1.0 / 30, aperture: 1.8))
        XCTAssertNil(ScanLight.exposureValue(iso: 100, seconds: 0, aperture: 1.8))
        XCTAssertNil(ScanLight.exposureValue(iso: 100, seconds: 1.0 / 30, aperture: 0))
        XCTAssertNil(ScanLight.exposureValue(iso: .nan, seconds: 1.0 / 30, aperture: 1.8))
        XCTAssertNil(ScanLight.exposureValue(iso: 100, seconds: .nan, aperture: 1.8))
        XCTAssertNil(ScanLight.exposureValue(iso: 100, seconds: .infinity, aperture: 1.8))
        XCTAssertNil(ScanLight.isDark(iso: 0, seconds: 0, aperture: 0, offset: -3), "Une caméra arrêtée ne dit rien")
    }

    func testDaylightAnOfficeAndALivingRoomNeverTurnTheLightOn() {
        // Daylight by a window, an office, a living room in the evening (about 60 lux).
        XCTAssertEqual(ScanLight.isDark(iso: 50, seconds: 1.0 / 120, aperture: 1.8, offset: 0), false)
        XCTAssertEqual(ScanLight.isDark(iso: 160, seconds: 1.0 / 60, aperture: 1.8, offset: 0.1), false)
        XCTAssertEqual(ScanLight.isDark(iso: 400, seconds: 1.0 / 30, aperture: 1.8, offset: -0.2), false)
        // Even under its target for a moment (the camera is still settling), a lit scene stays without the light.
        XCTAssertEqual(ScanLight.isDark(iso: 400, seconds: 1.0 / 30, aperture: 1.8, offset: -2), false)
        XCTAssertEqual(ScanLight.isDark(iso: 200, seconds: 1.0 / 60, aperture: 1.8, offset: -2), false)
    }

    func testADarkSceneTurnsTheLightOn() {
        // The camera at the end of its sensitivity: a dark room.
        XCTAssertEqual(ScanLight.isDark(iso: 2304, seconds: 1.0 / 30, aperture: 1.8, offset: -1.4), true)
        XCTAssertEqual(ScanLight.isDark(iso: 2304, seconds: 1.0 / 15, aperture: 1.8, offset: 0), true)
        // Just under the limit (about 14 lux), without any underexposure.
        XCTAssertEqual(ScanLight.isDark(iso: 1800, seconds: 1.0 / 30, aperture: 1.8, offset: 0), true)
        // Just over it: not dark by itself…
        XCTAssertEqual(ScanLight.isDark(iso: 1600, seconds: 1.0 / 30, aperture: 1.8, offset: -0.5), false)
        // …but dark when the camera says it can't expose enough.
        XCTAssertEqual(ScanLight.isDark(iso: 1600, seconds: 1.0 / 30, aperture: 1.8, offset: -1.2), true)
        XCTAssertEqual(ScanLight.isDark(iso: 640, seconds: 1.0 / 30, aperture: 1.8, offset: -1), true)
    }

    func testACameraWithASmallerApertureIsCaughtByItsUnderexposure() {
        // An ultra wide camera (f/2.4) at its highest sensitivity stops above the dark limit: its underexposure tells.
        XCTAssertEqual(ScanLight.isDark(iso: 2304, seconds: 1.0 / 30, aperture: 2.4, offset: 0), false)
        XCTAssertEqual(ScanLight.isDark(iso: 2304, seconds: 1.0 / 30, aperture: 2.4, offset: -1.5), true)
        // A reading whose offset is not a number falls back on the exposure alone.
        XCTAssertEqual(ScanLight.isDark(iso: 2304, seconds: 1.0 / 30, aperture: 2.4, offset: .nan), false)
        XCTAssertEqual(ScanLight.isDark(iso: 2304, seconds: 1.0 / 30, aperture: 1.8, offset: .nan), true)
    }

    func testTheLightWaitsForSeveralDarkReadingsInARow() {
        var meter = ScanLightMeter()
        XCTAssertFalse(meter.feed(true))
        XCTAssertFalse(meter.feed(true))
        XCTAssertTrue(meter.feed(true), "Trois lectures sombres de suite allument la lumière")
        // A hand in front of the lens for a moment, then light again, then readings that can't be used.
        var passing = ScanLightMeter()
        XCTAssertFalse(passing.feed(true))
        XCTAssertFalse(passing.feed(true))
        XCTAssertFalse(passing.feed(false))
        XCTAssertFalse(passing.feed(true))
        XCTAssertFalse(passing.feed(nil), "Une lecture inutilisable remet le compte à zéro")
        XCTAssertFalse(passing.feed(true))
        XCTAssertFalse(passing.feed(true))
        XCTAssertTrue(passing.feed(true))
        passing.reset()
        XCTAssertEqual(passing.streak, 0)
        XCTAssertFalse(passing.feed(true))
    }

    func testACameraThatMayNotBeRunningIsBelievedOnlyOnceItsReadingsMove() {
        // Readings that never move: a camera that is not running. Nothing is decided on them, however dark they look.
        var still = ScanLiveness()
        for _ in 0..<6 {
            XCTAssertFalse(still.feed(iso: 2304, offset: -2))
        }
        XCTAssertFalse(still.isLive)
        // A live camera: its measure moves a little at every image.
        var live = ScanLiveness()
        XCTAssertFalse(live.feed(iso: 2304, offset: -1.91), "Une seule lecture ne prouve rien")
        XCTAssertTrue(live.feed(iso: 2304, offset: -1.87))
        XCTAssertTrue(live.feed(iso: 2304, offset: -1.87), "Une fois vivante, elle le reste")
        var adjusting = ScanLiveness()
        XCTAssertFalse(adjusting.feed(iso: 800, offset: 0))
        XCTAssertTrue(adjusting.feed(iso: 1000, offset: 0))
        adjusting.reset()
        XCTAssertFalse(adjusting.isLive)
        XCTAssertFalse(adjusting.feed(iso: 1000, offset: 0))
    }

    // MARK: The person's choice

    func testTheButtonGoesThroughTheThreeChoicesAndBack() {
        XCTAssertEqual(ScanFlashMode.auto.next, .on)
        XCTAssertEqual(ScanFlashMode.on.next, .off)
        XCTAssertEqual(ScanFlashMode.off.next, .auto)
        XCTAssertEqual(ScanFlashMode.allCases.count, 3)
        XCTAssertEqual(Set(ScanFlashMode.allCases.map(\.title)).count, 3, "Trois libellés différents")
        XCTAssertEqual(ScanFlashMode.auto.title, "Flash automatique")
        XCTAssertEqual(ScanFlashMode.on.title, "Flash activé")
        XCTAssertEqual(ScanFlashMode.off.title, "Flash désactivé")
    }

    func testAutomaticIsTheDefaultAndTheChoiceIsKept() throws {
        try withDefaults { defaults in
            XCTAssertEqual(ScanFlashMode.saved(in: defaults), .auto, "Sans choix : automatique")
            ScanFlashMode.off.save(in: defaults)
            XCTAssertEqual(ScanFlashMode.saved(in: defaults), .off)
            ScanFlashMode.on.save(in: defaults)
            XCTAssertEqual(ScanFlashMode.saved(in: defaults), .on)
            // A value from elsewhere (an older or newer version) falls back on automatic.
            defaults.set("strobe", forKey: ScanFlashMode.key)
            XCTAssertEqual(ScanFlashMode.saved(in: defaults), .auto)
        }
    }

    func testTheLightStartsFromTheSavedChoiceAndKeepsANewOne() throws {
        try withDefaults { defaults in
            let torch = ScanTorch(defaults: defaults)
            XCTAssertEqual(torch.mode, .auto)
            XCTAssertFalse(torch.isLit)
            torch.cycle()
            XCTAssertEqual(torch.mode, .on)
            XCTAssertEqual(ScanFlashMode.saved(in: defaults), .on)
            torch.cycle()
            XCTAssertEqual(torch.mode, .off)
            XCTAssertEqual(ScanTorch(defaults: defaults).mode, .off, "Le prochain scan reprend le choix")
            torch.cycle()
            XCTAssertEqual(torch.mode, .auto)
            XCTAssertEqual(ScanFlashMode.saved(in: defaults), .auto)
        }
    }

    func testWithoutACameraThereIsNoLightAndNothingBreaks() throws {
        // The simulator has no camera: the button is not shown, and starting, choosing and stopping are harmless.
        try withDefaults { defaults in
            let torch = ScanTorch(defaults: defaults)
            torch.start(scanner: UIViewController())
            XCTAssertFalse(torch.isAvailable)
            torch.cycle()
            XCTAssertFalse(torch.isLit)
            torch.stop()
            torch.stop()
            XCTAssertFalse(torch.isLit)
            XCTAssertEqual(torch.mode, .on, "Le choix reste, même sans lumière")
        }
    }

    // MARK: The schedule photographed with the document camera

    private func page(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    func testAPhotographedPageIsMadeNoLargerThanWhatTheReadingUses() {
        let large = ScheduleReader.light(page(width: 4500, height: 3000))
        XCTAssertEqual(large.size.width * large.scale, 3000, accuracy: 1)
        XCTAssertEqual(large.size.height * large.scale, 2000, accuracy: 1, "Les proportions sont gardées")
        let tall = ScheduleReader.light(page(width: 1500, height: 6000))
        XCTAssertEqual(tall.size.height * tall.scale, 3000, accuracy: 1)
        XCTAssertEqual(tall.size.width * tall.scale, 750, accuracy: 1)
        // A page already small enough is left as it is.
        let small = page(width: 1200, height: 900)
        XCTAssertTrue(ScheduleReader.light(small) === small)
    }

    func testThePagesOfAScanAreOpenedInOrderAndNoMoreThanTheReaderTakes() async {
        let widths: [CGFloat] = [1100, 1200, 1300]
        let source = widths.map { page(width: $0, height: 900) }
        let three = await ScheduleReader.lightPages(count: 3) { source[$0] }
        XCTAssertEqual(three.map { $0.size.width }, widths, "Les pages gardent leur ordre")
        let small = page(width: 1000, height: 1000)
        let many = await ScheduleReader.lightPages(count: 25) { _ in small }
        XCTAssertEqual(many.count, ScheduleReader.maxPages)
        let none = await ScheduleReader.lightPages(count: 0) { _ in small }
        XCTAssertTrue(none.isEmpty)
    }

    func testSeveralPhotographedPagesAreReadOneByOne() async throws {
        let pages = try await ScheduleReader.pages(from: .images([page(width: 1200, height: 900), page(width: 1200, height: 900)]))
        XCTAssertEqual(pages.count, 2, "Chaque page photographiée est lue")
        do {
            _ = try await ScheduleReader.pages(from: .images([]))
            XCTFail("Aucune page : illisible")
        } catch ScheduleImportError.unreadable {
            // Expected.
        }
        // Blank pages hold no class: the import says so instead of inventing one.
        do {
            _ = try await ScheduleImporter.slots(from: .images([page(width: 1200, height: 900)]))
            XCTFail("Une page blanche ne contient aucun cours")
        } catch ScheduleImportError.nothingFound {
            // Expected.
        }
    }
}
