import CoreGraphics
import Foundation

// The pure logic around the two Core ML models of the food scanner (chantier 22): a segmenter (where the foods are)
// and a classifier (which food it is). The models themselves live in `App/` (`FoodModelRecognizer`); everything here
// is plain arithmetic on arrays, so it can be tested without Core ML and gives the same numbers on every device.
//
// The rules come from the Python that built and checked the models (`scripts/ml/ml_common.py`, `make_parity_fixtures.py`):
// the parity test (`Tests/FoodModelParityTests.swift`) compares the app with the PyTorch references, so a change here
// must be a change there. Foundation and CoreGraphics only (this folder is also compiled in the widget extension).

/// A box and the mask of one candidate food on the grid of the photo, in the order of the segmenter's scores.
struct DetectedShape: Hashable, Sendable {
    /// The box in pixels of the photo: x, y, width, height.
    var box: CGRect
    var mask: FoodMask

    init(box: CGRect, mask: FoodMask) {
        self.box = box
        self.mask = mask
    }
}

/// A food of the tables (its identifier) or, for a class of the classifier that has no food, the label of the class
/// (« mfr:… »), with the probability added up over every class that gives the same food.
struct FoodProbability: Hashable, Sendable {
    var key: String
    var probability: Double

    init(key: String, probability: Double) {
        self.key = key
        self.probability = probability
    }
}

enum ScannerModelLogic {
    /// A query of the segmenter is a food from this score (sigmoid of its first logit).
    static let detectionThreshold = 0.30
    /// A mask is a duplicate of an earlier, better one when both its box and its mask overlap that much.
    static let duplicateBoxIoU = 0.5
    static let duplicateMaskIoU = 0.7
    /// The crop given to the classifier is the box of the mask plus this share on each side.
    static let cropMargin = 0.10
    /// A crop is never smaller than this many pixels.
    static let minimumCropSide = 8.0
    /// The classifier keeps this many foods per zone.
    static let foodsPerZone = 3
    /// The mean and spread of the pixels the segmenter was trained with (ImageNet), red, green, blue.
    static let imageMean: [Float] = [0.485, 0.456, 0.406]
    static let imageSpread: [Float] = [0.229, 0.224, 0.225]
    /// The grey (red, green, blue, 0 to 255) of the part of a crop that falls outside the photo.
    static let cropFill: [UInt8] = [124, 116, 104]

    static func sigmoid(_ value: Double) -> Double {
        1 / (1 + exp(-value))
    }

    // MARK: Bilinear resizing

    /// For every pixel of a line of `target` pixels, the two source pixels it is read from and the weight of the second.
    /// The source coordinate of a destination pixel is (destination + 0.5) × (source / target) − 0.5, kept inside the
    /// source: the convention of PyTorch `interpolate(mode: "bilinear", align_corners: False)` without antialiasing.
    static func bilinearTaps(source: Int, target: Int) -> (lower: [Int], upper: [Int], weight: [Float]) {
        guard source > 0, target > 0 else { return ([], [], []) }
        let ratio = Double(source) / Double(target)
        var lower = [Int](repeating: 0, count: target)
        var upper = [Int](repeating: 0, count: target)
        var weight = [Float](repeating: 0, count: target)
        for index in 0..<target {
            let position = max(0, (Double(index) + 0.5) * ratio - 0.5)
            let first = min(Int(position), source - 1)
            let second = min(first + 1, source - 1)
            lower[index] = first
            upper[index] = second
            weight[index] = first == second ? 0 : Float(position - Double(first))
        }
        return (lower, upper, weight)
    }

    /// A plane of numbers (row by row) resized with a bilinear interpolation. Empty when a size is not positive or the
    /// plane does not fill its grid.
    static func bilinearResize(_ plane: [Float], width: Int, height: Int, toWidth newWidth: Int, toHeight newHeight: Int) -> [Float] {
        guard width > 0, height > 0, newWidth > 0, newHeight > 0, plane.count == width * height else { return [] }
        let columns = bilinearTaps(source: width, target: newWidth)
        let rows = bilinearTaps(source: height, target: newHeight)
        var result = [Float](repeating: 0, count: newWidth * newHeight)
        plane.withUnsafeBufferPointer { source in
            result.withUnsafeMutableBufferPointer { output in
                for y in 0..<newHeight {
                    let rowA = rows.lower[y] * width
                    let rowB = rows.upper[y] * width
                    let weightY = rows.weight[y]
                    for x in 0..<newWidth {
                        let colA = columns.lower[x]
                        let colB = columns.upper[x]
                        let weightX = columns.weight[x]
                        let topLeft = source[rowA + colA]
                        let topRight = source[rowA + colB]
                        let bottomLeft = source[rowB + colA]
                        let bottomRight = source[rowB + colB]
                        let top = topLeft + (topRight - topLeft) * weightX
                        let bottom = bottomLeft + (bottomRight - bottomLeft) * weightX
                        output[y * newWidth + x] = top + (bottom - top) * weightY
                    }
                }
            }
        }
        return result
    }

    /// The input of the segmenter: the RGBA pixels (8 bits, `bytesPerRow` bytes per row) read as 0…1, resized to
    /// `side` × `side` by a bilinear interpolation (the proportions are not kept), then (value − mean) / spread. The result is
    /// laid out channel by channel (red plane, green plane, blue plane), row by row: [1, 3, side, side] without the 1.
    /// Nil when the sizes are not consistent.
    static func resizedNormalizedPlanes(
        rgba: [UInt8], width: Int, height: Int, bytesPerRow: Int, side: Int,
        mean: [Float] = ScannerModelLogic.imageMean, spread: [Float] = ScannerModelLogic.imageSpread
    ) -> [Float]? {
        guard width > 0, height > 0, side > 0, bytesPerRow >= width * 4, mean.count >= 3, spread.count >= 3,
              rgba.count >= bytesPerRow * (height - 1) + width * 4 else { return nil }
        let columns = bilinearTaps(source: width, target: side)
        let rows = bilinearTaps(source: height, target: side)
        let planeSize = side * side
        var result = [Float](repeating: 0, count: 3 * planeSize)
        rgba.withUnsafeBufferPointer { source in
            result.withUnsafeMutableBufferPointer { output in
                for y in 0..<side {
                    let rowA = rows.lower[y] * bytesPerRow
                    let rowB = rows.upper[y] * bytesPerRow
                    let weightY = rows.weight[y]
                    for x in 0..<side {
                        let colA = columns.lower[x] * 4
                        let colB = columns.upper[x] * 4
                        let weightX = columns.weight[x]
                        for channel in 0..<3 {
                            let topLeft = Float(source[rowA + colA + channel])
                            let topRight = Float(source[rowA + colB + channel])
                            let bottomLeft = Float(source[rowB + colA + channel])
                            let bottomRight = Float(source[rowB + colB + channel])
                            let top = topLeft + (topRight - topLeft) * weightX
                            let bottom = bottomLeft + (bottomRight - bottomLeft) * weightX
                            let value = (top + (bottom - top) * weightY) / 255
                            output[channel * planeSize + y * side + x] = (value - mean[channel]) / spread[channel]
                        }
                    }
                }
            }
        }
        return result
    }

    // MARK: Boxes and masks

    /// The box of a query of the segmenter (center and size, 0…1 of the photo) in pixels of the photo, kept inside it.
    static func detectionBox(centerX: Double, centerY: Double, width: Double, height: Double, imageWidth: Int, imageHeight: Int) -> CGRect {
        let photoWidth = Double(imageWidth)
        let photoHeight = Double(imageHeight)
        let left = max(0, (centerX - width / 2) * photoWidth)
        let top = max(0, (centerY - height / 2) * photoHeight)
        let right = min(photoWidth, (centerX + width / 2) * photoWidth)
        let bottom = min(photoHeight, (centerY + height / 2) * photoHeight)
        return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }

    /// Intersection over union of two boxes (0 when they do not overlap or one has no area).
    static func boxIoU(_ a: CGRect, _ b: CGRect) -> Double {
        let overlapWidth = max(0, min(Double(a.maxX), Double(b.maxX)) - max(Double(a.minX), Double(b.minX)))
        let overlapHeight = max(0, min(Double(a.maxY), Double(b.maxY)) - max(Double(a.minY), Double(b.minY)))
        let intersection = overlapWidth * overlapHeight
        let areaA = Double(a.width) * Double(a.height)
        let areaB = Double(b.width) * Double(b.height)
        let union = areaA + areaB - intersection
        return union > 0 ? intersection / union : 0
    }

    /// Intersection over union of two masks on the same grid (0 on different grids or when both are empty).
    static func maskIoU(_ a: FoodMask, _ b: FoodMask) -> Double {
        guard a.hasSameGrid(as: b) else { return 0 }
        var intersection = 0
        a.forEachCell { x, y in
            if b.contains(x: x, y: y) { intersection += 1 }
        }
        let union = a.count + b.count - intersection
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    /// True when the shape duplicates one already kept: the box AND the mask overlap with one of them enough.
    static func isDuplicate(_ shape: DetectedShape, of kept: [DetectedShape]) -> Bool {
        for other in kept {
            if boxIoU(shape.box, other.box) >= duplicateBoxIoU, maskIoU(shape.mask, other.mask) >= duplicateMaskIoU { return true }
        }
        return false
    }

    /// The indices of the shapes kept once the duplicates are dropped. The shapes come by decreasing score: each one is
    /// compared with those already kept, so the best of a group of duplicates is the one that stays.
    static func indicesAfterMergingDuplicates(_ shapes: [DetectedShape]) -> [Int] {
        var kept: [DetectedShape] = []
        var indices: [Int] = []
        for (index, shape) in shapes.enumerated() where !isDuplicate(shape, of: kept) {
            kept.append(shape)
            indices.append(index)
        }
        return indices
    }

    /// The smallest box that contains the cells of a mask (x, y, width, height in cells), nil for an empty mask.
    static func litBounds(of mask: FoodMask) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        mask.forEachCell { x, y in
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX + 1 - minX, height: maxY + 1 - minY)
    }

    // MARK: Square crop

    /// The square given to the classifier for a zone: centered on its bounds, the longer side plus `margin` on each side
    /// (at least `minimumCropSide`). A square that fits in the photo is moved to stay inside it; a bigger one is kept
    /// centered and falls partly outside (the outside is filled with `cropFill`).
    static func squareCropRect(around bounds: CGRect, imageWidth: Int, imageHeight: Int, margin: Double = ScannerModelLogic.cropMargin) -> CGRect {
        let boundsWidth = Double(bounds.width)
        let boundsHeight = Double(bounds.height)
        let centerX = Double(bounds.minX) + boundsWidth / 2
        let centerY = Double(bounds.minY) + boundsHeight / 2
        let side = max(max(boundsWidth, boundsHeight) * (1 + 2 * margin), minimumCropSide)
        var left = centerX - side / 2
        var top = centerY - side / 2
        let photoWidth = Double(imageWidth)
        let photoHeight = Double(imageHeight)
        if side <= min(photoWidth, photoHeight) {
            left = min(max(left, 0), photoWidth - side)
            top = min(max(top, 0), photoHeight - side)
        }
        return CGRect(x: left, y: top, width: side, height: side)
    }

    // MARK: Classifier output

    /// The foods most likely for a zone: the probabilities of the classes that give the same food are added up; a class
    /// with no food (an empty identifier) stays alone under its label. The most likely first (a tie keeps the order of the
    /// classes), at most `limit`.
    static func mergedByFood(probabilities: [Double], foods: [String], labels: [String], limit: Int = ScannerModelLogic.foodsPerZone) -> [FoodProbability] {
        guard limit > 0 else { return [] }
        var order: [String] = []
        var totals: [String: Double] = [:]
        for index in 0..<min(probabilities.count, labels.count) {
            let food = index < foods.count ? foods[index] : ""
            let key = food.isEmpty ? labels[index] : food
            if totals[key] == nil { order.append(key) }
            totals[key, default: 0] += probabilities[index]
        }
        var ranked: [(key: String, probability: Double, position: Int)] = []
        for (position, key) in order.enumerated() {
            ranked.append((key, totals[key] ?? 0, position))
        }
        ranked.sort { $0.probability != $1.probability ? $0.probability > $1.probability : $0.position < $1.position }
        return ranked.prefix(limit).map { FoodProbability(key: $0.key, probability: $0.probability) }
    }
}
