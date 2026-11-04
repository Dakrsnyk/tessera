import XCTest
import CoreGraphics
@testable import Ardane

/// The pure logic around the Core ML food models (`ScannerModelLogic`), with cases worked out by hand. No model is loaded here:
/// `FoodModelParityTests` compares the whole engine with the PyTorch references.
final class FoodModelLogicTests: XCTestCase {

    private func assertRect(_ rect: CGRect, _ x: Double, _ y: Double, _ width: Double, _ height: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Double(rect.minX), x, accuracy: 1e-9, "x", file: file, line: line)
        XCTAssertEqual(Double(rect.minY), y, accuracy: 1e-9, "y", file: file, line: line)
        XCTAssertEqual(Double(rect.width), width, accuracy: 1e-9, "largeur", file: file, line: line)
        XCTAssertEqual(Double(rect.height), height, accuracy: 1e-9, "hauteur", file: file, line: line)
    }

    // MARK: Square crop

    func testSquareCropThatFitsIsCenteredOnTheBounds() {
        // 200 × 100 at (100, 100): center (200, 150), side 200 × 1.2 = 240, so x0 = 80 and y0 = 30, all inside 800 × 600.
        let rect = ScannerModelLogic.squareCropRect(around: CGRect(x: 100, y: 100, width: 200, height: 100), imageWidth: 800, imageHeight: 600)
        assertRect(rect, 80, 30, 240, 240)
    }

    func testSquareCropIsMovedBackInsideThePhotoAtTheBorders() {
        // Top left: 100 × 50 at (0, 0) → side 120, center (50, 25) would start at (-10, -35): moved to (0, 0).
        let topLeft = ScannerModelLogic.squareCropRect(around: CGRect(x: 0, y: 0, width: 100, height: 50), imageWidth: 800, imageHeight: 600)
        assertRect(topLeft, 0, 0, 120, 120)
        // Bottom right: 100 × 100 at (700, 500) → side 120, center (750, 550) would start at (690, 490): moved to (680, 480).
        let bottomRight = ScannerModelLogic.squareCropRect(around: CGRect(x: 700, y: 500, width: 100, height: 100), imageWidth: 800, imageHeight: 600)
        assertRect(bottomRight, 680, 480, 120, 120)
    }

    func testSquareCropBiggerThanThePhotoStaysCenteredAndFallsOutside() {
        // The whole photo, no margin: the side is the long side (800), more than the short one (722): no shift, grey above and below.
        let whole = ScannerModelLogic.squareCropRect(
            around: CGRect(x: 0, y: 0, width: 800, height: 722), imageWidth: 800, imageHeight: 722, margin: 0
        )
        assertRect(whole, 0, -39, 800, 800)
        // With the margin of a zone: 800 × 1.2 = 960, centered on (400, 300) of an 800 × 600 photo.
        let margin = ScannerModelLogic.squareCropRect(around: CGRect(x: 0, y: 0, width: 800, height: 600), imageWidth: 800, imageHeight: 600)
        assertRect(margin, -80, -180, 960, 960)
    }

    func testSquareCropIsNeverSmallerThanEightPixels() {
        let rect = ScannerModelLogic.squareCropRect(around: CGRect(x: 50, y: 50, width: 2, height: 2), imageWidth: 800, imageHeight: 600)
        assertRect(rect, 47, 47, 8, 8)
    }

    // MARK: Boxes and masks

    func testBoxIoU() {
        let a = CGRect(x: 0, y: 0, width: 10, height: 10)
        XCTAssertEqual(ScannerModelLogic.boxIoU(a, a), 1, accuracy: 1e-12)
        // Half of one box over the other: 50 / (100 + 100 − 50).
        XCTAssertEqual(ScannerModelLogic.boxIoU(a, CGRect(x: 5, y: 0, width: 10, height: 10)), 1.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(ScannerModelLogic.boxIoU(a, CGRect(x: 20, y: 20, width: 5, height: 5)), 0, accuracy: 1e-12)
        XCTAssertEqual(ScannerModelLogic.boxIoU(CGRect.zero, CGRect.zero), 0, accuracy: 1e-12)
    }

    func testDetectionBoxIsKeptInsideThePhoto() {
        // Wider than the photo: 0.5 ± 0.6 of 800 is −80…880, kept to 0…800; 0.5 ± 0.25 of 600 is 150…450.
        let box = ScannerModelLogic.detectionBox(
            centerX: 0.5, centerY: 0.5, width: 1.2, height: 0.5, imageWidth: 800, imageHeight: 600
        )
        assertRect(box, 0, 150, 800, 300)
    }

    func testLitBoundsOfAMask() {
        let mask = FoodMask(width: 6, height: 4) { x, y in (x == 1 && y == 1) || (x == 4 && y == 2) }
        // Columns 1 to 4 and rows 1 to 2: the width and height count the last lit cell.
        if let bounds = ScannerModelLogic.litBounds(of: mask) {
            assertRect(bounds, 1, 1, 4, 2)
        } else {
            XCTFail("masque allumé sans boîte")
        }
        XCTAssertNil(ScannerModelLogic.litBounds(of: FoodMask(width: 6, height: 4)))
    }

    func testMaskIoU() {
        let a = FoodMask(width: 10, height: 10) { x, y in x < 5 && y < 5 }
        let b = FoodMask(width: 10, height: 10) { x, y in x < 5 && y < 4 }
        // 20 cells of b inside the 25 of a: 20 / 25.
        XCTAssertEqual(ScannerModelLogic.maskIoU(a, b), 0.8, accuracy: 1e-12)
        XCTAssertEqual(ScannerModelLogic.maskIoU(a, a), 1, accuracy: 1e-12)
        XCTAssertEqual(ScannerModelLogic.maskIoU(a, FoodMask(width: 5, height: 5)), 0, accuracy: 1e-12, "grilles différentes")
    }

    func testDuplicatesAreMergedOnlyWhenTheBoxAndTheMaskOverlap() {
        let a = DetectedShape(box: CGRect(x: 0, y: 0, width: 5, height: 5), mask: FoodMask(width: 10, height: 10) { x, y in x < 5 && y < 5 })
        // Box IoU 0.8 and mask IoU 0.8: a duplicate of a.
        let b = DetectedShape(box: CGRect(x: 0, y: 0, width: 5, height: 4), mask: FoodMask(width: 10, height: 10) { x, y in x < 5 && y < 4 })
        // Box IoU 0.4 (below 0.5): kept.
        let c = DetectedShape(box: CGRect(x: 0, y: 0, width: 5, height: 2), mask: FoodMask(width: 10, height: 10) { x, y in x < 5 && y < 2 })
        // Same box as a (IoU 1) but a mask that overlaps a for 0.4 only (below 0.7): kept.
        let d = DetectedShape(box: CGRect(x: 0, y: 0, width: 5, height: 5), mask: FoodMask(width: 10, height: 10) { x, y in x < 5 && y < 2 })
        // Same box and same mask as a: a duplicate.
        let e = a
        XCTAssertEqual(ScannerModelLogic.indicesAfterMergingDuplicates([a, b, c, d, e]), [0, 2, 3])
        XCTAssertTrue(ScannerModelLogic.isDuplicate(b, of: [a]))
        XCTAssertFalse(ScannerModelLogic.isDuplicate(b, of: []))
        XCTAssertEqual(ScannerModelLogic.indicesAfterMergingDuplicates([]), [])
    }

    // MARK: Foods of the classifier

    func testProbabilitiesAreAddedUpPerFood() {
        // a and c are the same food, b has no food, d is another one, e has no food either.
        let result = ScannerModelLogic.mergedByFood(
            probabilities: [0.20, 0.30, 0.25, 0.10, 0.05],
            foods: ["builtin.x", "", "builtin.x", "cnf.1", ""],
            labels: ["mfr:a", "mfr:b", "mfr:c", "mfr:d", "mfr:e"],
            limit: 3
        )
        XCTAssertEqual(result.map(\.key), ["builtin.x", "mfr:b", "cnf.1"])
        XCTAssertEqual(result[0].probability, 0.45, accuracy: 1e-12)
        XCTAssertEqual(result[1].probability, 0.30, accuracy: 1e-12)
        XCTAssertEqual(result[2].probability, 0.10, accuracy: 1e-12)
    }

    func testEqualProbabilitiesKeepTheOrderOfTheClasses() {
        let result = ScannerModelLogic.mergedByFood(
            probabilities: [0.2, 0.2, 0.2], foods: ["", "", ""], labels: ["mfr:first", "mfr:second", "mfr:third"], limit: 2
        )
        XCTAssertEqual(result.map(\.key), ["mfr:first", "mfr:second"])
        XCTAssertTrue(ScannerModelLogic.mergedByFood(probabilities: [1], foods: ["builtin.x"], labels: ["mfr:a"], limit: 0).isEmpty)
    }

    // MARK: Resizing

    func testBilinearUpscaleMatchesTheHandWorkedValues() {
        // 2 × 2 → 4 × 4: the source coordinates of the 4 pixels of a line are 0, 0.25, 0.75, 1 (the first kept at 0, the last at the edge).
        // The picture is 10 × x + 20 × y with x and y in those positions.
        let result = ScannerModelLogic.bilinearResize([0, 10, 20, 30], width: 2, height: 2, toWidth: 4, toHeight: 4)
        let expected: [Float] = [
            0, 2.5, 7.5, 10,
            5, 7.5, 12.5, 15,
            15, 17.5, 22.5, 25,
            20, 22.5, 27.5, 30,
        ]
        XCTAssertEqual(result.count, expected.count)
        for (index, value) in expected.enumerated() where index < result.count {
            XCTAssertEqual(result[index], value, accuracy: 1e-5, "pixel \(index)")
        }
    }

    func testBilinearDownscaleAveragesNeighbours() {
        // 4 × 1 → 2 × 1: positions 0.5 and 2.5, halfway between 0 and 10, then between 20 and 30.
        let result = ScannerModelLogic.bilinearResize([0, 10, 20, 30], width: 4, height: 1, toWidth: 2, toHeight: 1)
        XCTAssertEqual(result.count, 2)
        if result.count == 2 {
            XCTAssertEqual(result[0], 5, accuracy: 1e-5)
            XCTAssertEqual(result[1], 25, accuracy: 1e-5)
        }
    }

    func testBilinearSameSizeIsTheIdentityAndBadSizesGiveNothing() {
        let plane: [Float] = [1, 2, 3, 4, 5, 6]
        XCTAssertEqual(ScannerModelLogic.bilinearResize(plane, width: 3, height: 2, toWidth: 3, toHeight: 2), plane)
        XCTAssertTrue(ScannerModelLogic.bilinearResize(plane, width: 3, height: 3, toWidth: 3, toHeight: 2).isEmpty, "plan trop court")
        XCTAssertTrue(ScannerModelLogic.bilinearResize(plane, width: 3, height: 2, toWidth: 0, toHeight: 2).isEmpty)
    }

    func testNormalizedPlanesAreChannelByChannel() {
        // Two pixels (red, then green) with 4 bytes of padding at the end of the row, resized 2 × 1 → 2 × 2 (same columns, rows repeated).
        let bytes: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 9, 9, 9, 9]
        let planes = ScannerModelLogic.resizedNormalizedPlanes(
            rgba: bytes, width: 2, height: 1, bytesPerRow: 12, side: 2, mean: [0.5, 0.5, 0.5], spread: [0.5, 0.5, 0.5]
        )
        // (value − 0.5) / 0.5: 255 → 1, 0 → −1. Red plane, green plane, blue plane.
        let expected: [Float] = [1, -1, 1, -1, -1, 1, -1, 1, -1, -1, -1, -1]
        XCTAssertEqual(planes?.count, expected.count)
        if let planes, planes.count == expected.count {
            for index in expected.indices { XCTAssertEqual(planes[index], expected[index], accuracy: 1e-5, "valeur \(index)") }
        }
        XCTAssertNil(ScannerModelLogic.resizedNormalizedPlanes(rgba: bytes, width: 2, height: 1, bytesPerRow: 4, side: 2), "ligne trop courte")
        XCTAssertNil(ScannerModelLogic.resizedNormalizedPlanes(rgba: [1, 2, 3], width: 2, height: 1, bytesPerRow: 8, side: 2), "pixels manquants")
    }

    func testSigmoid() {
        XCTAssertEqual(ScannerModelLogic.sigmoid(0), 0.5, accuracy: 1e-12)
        XCTAssertEqual(ScannerModelLogic.sigmoid(log(3.0)), 0.75, accuracy: 1e-12)
        XCTAssertGreaterThan(ScannerModelLogic.sigmoid(10), 0.9999)
    }

    // MARK: Proposals from the models

    func testModelProposalsTakeTheFirstFoodThatResolvesAndKeepEachFoodOnce() {
        func food(_ id: String, serving: Double) -> FoodItem {
            FoodItem(id: id, name: id, brand: nil, kcal: 150, protein: 8, carbs: 20, fat: 4, fiber: 1,
                     servingGrams: serving, servingName: "1", source: .builtin, barcode: nil)
        }
        let apple = food("builtin.apple", serving: 150)
        let rice = food("builtin.rice", serving: 180)
        let resolve: (String) -> FoodItem? = { id in [apple, rice].first { $0.id == id } }
        func zone(_ label: String, _ foods: [(String, Double)]) -> FoodModelZone {
            FoodModelZone(
                score: 0.9, box: CGRect(x: 0, y: 0, width: 10, height: 10), maskBounds: CGRect(x: 0, y: 0, width: 10, height: 10),
                cropRect: CGRect(x: 0, y: 0, width: 12, height: 12),
                classification: FoodModelClassification(
                    foods: foods.map { FoodModelCandidate(key: $0.0, probability: $0.1) }, topLabel: label, topProbability: foods.first?.1 ?? 0
                )
            )
        }
        let zones = [
            // The best class has no food: the next food that resolves is used (rice, 0.30).
            zone("mfr:sauce", [("mfr:sauce", 0.5), ("builtin.rice", 0.30), ("builtin.apple", 0.1)]),
            // The same food in a zone that is surer of it: it is proposed once, at 0.8.
            zone("mfr:rice", [("builtin.rice", 0.8), ("builtin.apple", 0.1)]),
            // Under the floor: nothing.
            zone("mfr:other", [("builtin.apple", 0.05)]),
        ]
        let proposals = OnDeviceMealAnalyzer.modelProposals(from: zones, learning: ScanLearning(), resolve: resolve)
        XCTAssertEqual(proposals.map { $0.food.id }, ["builtin.rice"])
        XCTAssertEqual(proposals.first?.confidence ?? 0, 0.8, accuracy: 1e-12)
        XCTAssertEqual(proposals.first?.grams ?? 0, 180, accuracy: 1e-9, "la portion usuelle de l'aliment")
        XCTAssertEqual(proposals.first?.label, "mfr:rice")
        XCTAssertEqual(proposals.first?.detectedFoodID, "builtin.rice")
        XCTAssertTrue(OnDeviceMealAnalyzer.modelProposals(from: [], learning: ScanLearning(), resolve: resolve).isEmpty)
        // Nothing resolves: no proposal, Vision takes over.
        XCTAssertTrue(OnDeviceMealAnalyzer.modelProposals(from: zones, learning: ScanLearning(), resolve: { _ in nil }).isEmpty)
    }
}
