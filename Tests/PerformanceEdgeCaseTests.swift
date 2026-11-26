import UIKit
import XCTest
@testable import Ardane

/// Corrections de performance et de cas limites : réglages inchangés = rien d'écrit, exemple « habitudes »
/// mémorisé par jour, photo relue depuis le cache puis oubliée à la suppression, fichier lisible sans le charger.
@MainActor
final class PerformanceEdgeCaseTests: XCTestCase {
    private func temporaryStore() -> SharedStore {
        SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
    }

    func testUnchangedSettingsWriteNothing() {
        let store = temporaryStore()
        let model = AppModel(store: store)
        model.updateSettings { $0.cryptoCurrency = $0.cryptoCurrency == "eur" ? "usd" : "eur" }
        XCTAssertNotNil(store.rawData(.settings), "A real change is saved")
        store.remove(.settings)
        model.updateSettings { _ in }
        XCTAssertNil(store.rawData(.settings), "A change that changes nothing writes nothing")
    }

    func testSampleHabitDaysAreTheSameWithinADay() {
        let now = Date()
        let first = SamplePayload.sampleHabitDays(now: now)
        let second = SamplePayload.sampleHabitDays(now: now.addingTimeInterval(1))
        XCTAssertEqual(first.count, 3)
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.allSatisfy { $0.contains(DateMath.dayKey(now)) }, "Every habit is done today")
    }

    func testStoredPhotoIsReadAgainAfterDeleteAndGoneAfter() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { UIColor.red.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
        guard let name = ImageStore.save(image) else { return XCTFail("The photo is saved") }
        XCTAssertNotNil(ImageStore.image(named: name))
        XCTAssertNotNil(ImageStore.image(named: name), "Second read, from the cache")
        ImageStore.delete(named: name)
        XCTAssertNil(ImageStore.image(named: name), "A deleted photo isn't served from the cache")
    }
}
