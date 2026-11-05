import XCTest
import CoreGraphics
import CoreML
import ImageIO
@testable import Ardane

/// The Core ML engine (`FoodModelRecognizer`: segmenter then classifier, on the CPU) against the PyTorch references of 6 photos
/// (`Tests/Fixtures/FoodModels/parity.json`, made by `scripts/ml/make_parity_fixtures.py`). The models are int8 and the resizing
/// is not the same code, so the checks are tolerant: most zones found again, a close score, mostly the same first food. One line
/// per photo:
///   PARITE <file> : réf <n> zones, app <m> ; appariées <k> ; écart de score max <x> ; même 1er aliment <a>/<k> ; entier : réf <label> <p> / app <label> <p>
final class FoodModelParityTests: XCTestCase {

    private struct Parity: Decodable {
        let photos: [Photo]
    }

    private struct Photo: Decodable {
        let file: String
        let width: Int
        let height: Int
        let detections: [Detection]
        let wholeImage: Whole
    }

    private struct Detection: Decodable {
        let score: Double
        /// x0, y0, x1, y1 in pixels.
        let box: [Double]
        let top5: [Ranked]
        let foods: [Food]
    }

    private struct Whole: Decodable {
        let top5: [Ranked]
        let foods: [Food]
    }

    private struct Ranked: Decodable {
        let label: String
        let p: Double
    }

    private struct Food: Decodable {
        let id: String
        let p: Double
    }

    /// Where the fixtures are: next to this source file (the repository is on the runner's disk in CI), else in the test bundle.
    private func fixtures() -> (parity: URL, photos: URL)? {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")
        let parity = folder.appendingPathComponent("FoodModels/parity.json")
        if FileManager.default.fileExists(atPath: parity.path) { return (parity, folder.appendingPathComponent("FoodPhotos")) }
        if let bundled = Bundle(for: FoodModelParityTests.self).url(forResource: "parity", withExtension: "json") {
            return (bundled, bundled.deletingLastPathComponent())
        }
        return nil
    }

    /// The photo as the references read it: the pixels of the file, not straightened by the EXIF orientation.
    private func loadImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func percent(_ part: Int, _ total: Int) -> String {
        total == 0 ? "n/a" : String(format: "%.0f %%", 100 * Double(part) / Double(total))
    }

    func testEngineMatchesTheTorchReferences() throws {
        guard let fixtures = fixtures() else { throw XCTSkip("Dossier Tests/Fixtures/FoodModels introuvable") }
        let recognizer = FoodModelRecognizer(computeUnits: .cpuOnly)
        do {
            try recognizer.prepare()
        } catch {
            XCTFail("Modèles Core ML absents ou illisibles dans le paquet de l'app (\(error)) : il faut ArdaneFoodSegmenter.mlmodelc, "
                + "ArdaneFoodClassifier.mlmodelc et ArdaneFoodClassMap.json dans l'app")
            return
        }
        let parity = try JSONDecoder().decode(Parity.self, from: Data(contentsOf: fixtures.parity))
        XCTAssertFalse(parity.photos.isEmpty)

        var lines: [String] = []
        var referenceZones = 0
        var matchedZones = 0
        var sameFirstFood = 0
        var scoreGapSum = 0.0
        var wholeSame = 0
        var wholeChecked = 0

        for photo in parity.photos {
            guard let image = loadImage(fixtures.photos.appendingPathComponent(photo.file)) else {
                XCTFail("photo illisible : \(photo.file)")
                continue
            }
            XCTAssertEqual(image.width, photo.width, "\(photo.file) : largeur")
            XCTAssertEqual(image.height, photo.height, "\(photo.file) : hauteur")
            let zones: [FoodModelZone]
            let whole: FoodModelClassification
            do {
                // The references are at the 0.30 threshold: the app's « maybe » zones (0.20 to 0.30) are left out.
                zones = try recognizer.recognize(image).filter { !$0.isTentative }
                whole = try recognizer.classifyWholeImage(image)
            } catch {
                XCTFail("\(photo.file) : le moteur a échoué (\(error))")
                lines.append("PARITE \(photo.file) : ERREUR \(error)")
                referenceZones += photo.detections.count
                continue
            }

            // Each reference zone is paired with the free zone of the app whose box overlaps it most (IoU of at least 0.7).
            var used = Set<Int>()
            var matched = 0
            var same = 0
            var maxGap = 0.0
            for reference in photo.detections {
                guard reference.box.count == 4 else { continue }
                let referenceBox = CGRect(
                    x: reference.box[0], y: reference.box[1],
                    width: reference.box[2] - reference.box[0], height: reference.box[3] - reference.box[1]
                )
                var bestIndex: Int?
                var bestOverlap = 0.7
                for (index, zone) in zones.enumerated() where !used.contains(index) {
                    let overlap = ScannerModelLogic.boxIoU(referenceBox, zone.box)
                    if overlap >= bestOverlap {
                        bestOverlap = overlap
                        bestIndex = index
                    }
                }
                guard let index = bestIndex else { continue }
                used.insert(index)
                matched += 1
                let gap = abs(zones[index].score - reference.score)
                maxGap = max(maxGap, gap)
                scoreGapSum += gap
                if let firstReference = reference.foods.first, let firstApp = zones[index].classification.foods.first,
                   firstReference.id == firstApp.key {
                    same += 1
                }
            }
            referenceZones += photo.detections.count
            matchedZones += matched
            sameFirstFood += same

            let referenceLabel = photo.wholeImage.top5.first?.label ?? "?"
            let referenceProbability = photo.wholeImage.top5.first?.p ?? 0
            wholeChecked += 1
            if referenceLabel == whole.topLabel { wholeSame += 1 }
            let gapText = String(format: "%.3f", maxGap)
            let referenceText = String(format: "%.3f", referenceProbability)
            let appText = String(format: "%.3f", whole.topProbability)
            var line = "PARITE \(photo.file) : réf \(photo.detections.count) zones, app \(zones.count) ; appariées \(matched) ; "
            line += "écart de score max \(gapText) ; même 1er aliment \(same)/\(matched) ; "
            line += "entier : réf \(referenceLabel) \(referenceText) / app \(whole.topLabel) \(appText)"
            lines.append(line)
        }

        let meanGap = matchedZones == 0 ? 0 : scoreGapSum / Double(matchedZones)
        let meanText = String(format: "%.3f", meanGap)
        var total = "PARITE-TOTAL zones appariées \(matchedZones)/\(referenceZones) (\(percent(matchedZones, referenceZones))) ; "
        total += "écart de score moyen \(meanText) ; "
        total += "même 1er aliment \(sameFirstFood)/\(matchedZones) (\(percent(sameFirstFood, matchedZones))) ; "
        total += "même étiquette sur la photo entière \(wholeSame)/\(wholeChecked)"
        lines.append(total)
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "PARITE-MODELES"
        attachment.lifetime = .keepAlways
        add(attachment)
        print(lines.joined(separator: "\n"))

        XCTAssertGreaterThan(referenceZones, 0)
        XCTAssertGreaterThanOrEqual(Double(matchedZones), 0.8 * Double(referenceZones), "au moins 80 % des zones de référence retrouvées")
        XCTAssertLessThanOrEqual(meanGap, 0.10, "écart de score moyen")
        XCTAssertGreaterThanOrEqual(Double(sameFirstFood), 0.75 * Double(matchedZones), "même premier aliment pour 75 % des zones appariées")
        XCTAssertGreaterThanOrEqual(wholeSame, min(5, wholeChecked), "même première étiquette sur la photo entière pour 5 photos sur 6")
    }
}
