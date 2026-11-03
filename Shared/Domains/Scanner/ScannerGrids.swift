import Foundation

/// A binary mask on a grid: which cells (pixels of the photo, or cells of a height map) belong to a food, to a
/// plate or to a ring of plate. Row by row, the origin at the top left, a cell is its column `x` and row `y`.
///
/// An inconsistent size (the cells do not fill the grid) gives an empty mask, never a crash.
struct FoodMask: Hashable, Sendable {
    let width: Int
    let height: Int
    private let cells: [Bool]

    init(width: Int, height: Int, cells: [Bool]) {
        let w = max(0, width)
        let h = max(0, height)
        self.width = w
        self.height = h
        self.cells = cells.count == w * h ? cells : [Bool](repeating: false, count: w * h)
    }

    /// An empty mask.
    init(width: Int, height: Int) {
        self.init(width: width, height: height, cells: [])
    }

    /// The cells for which `contains` is true.
    init(width: Int, height: Int, contains: (Int, Int) -> Bool) {
        let w = max(0, width)
        let h = max(0, height)
        var values = [Bool](repeating: false, count: w * h)
        for y in 0..<h {
            for x in 0..<w where contains(x, y) { values[y * w + x] = true }
        }
        self.init(width: w, height: h, cells: values)
    }

    func contains(x: Int, y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return cells[y * width + x]
    }

    /// The number of cells in the mask.
    var count: Int { cells.reduce(0) { $0 + ($1 ? 1 : 0) } }

    var isEmpty: Bool { !cells.contains(true) }

    /// Calls `body(x, y)` for every cell of the mask, row by row.
    func forEachCell(_ body: (Int, Int) -> Void) {
        for y in 0..<height {
            for x in 0..<width where cells[y * width + x] { body(x, y) }
        }
    }

    func hasSameGrid(as other: FoodMask) -> Bool {
        width == other.width && height == other.height
    }

    /// The cells of this mask that are not in `other` (nil when the grids differ).
    func subtracting(_ other: FoodMask) -> FoodMask? {
        guard hasSameGrid(as: other) else { return nil }
        return FoodMask(width: width, height: height, cells: zip(cells, other.cells).map { $0 && !$1 })
    }

    /// The cells in at least one of the masks (nil when the list is empty or the grids differ).
    static func union(of masks: [FoodMask]) -> FoodMask? {
        guard let first = masks.first, masks.allSatisfy({ $0.hasSameGrid(as: first) }) else { return nil }
        var values = first.cells
        for mask in masks.dropFirst() {
            for index in values.indices where mask.cells[index] { values[index] = true }
        }
        return FoodMask(width: first.width, height: first.height, cells: values)
    }

    /// The mask on another grid, each new cell taking the value of the cell that covers its center (nearest
    /// neighbour): to move a mask from the photo to the grid of a height map.
    func resampled(width newWidth: Int, height newHeight: Int) -> FoodMask? {
        guard width > 0, height > 0, newWidth > 0, newHeight > 0 else { return nil }
        return FoodMask(width: newWidth, height: newHeight) { x, y in
            let sourceX = min(width - 1, Int((Double(x) + 0.5) * Double(width) / Double(newWidth)))
            let sourceY = min(height - 1, Int((Double(y) + 0.5) * Double(height) / Double(newHeight)))
            return contains(x: sourceX, y: sourceY)
        }
    }
}

/// How much a depth sensor trusts a cell. The raw values are those of ARKit's `ARConfidenceLevel`, so the app
/// converts with `DepthConfidence(rawValue:)`.
enum DepthConfidence: Int, Hashable, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: DepthConfidence, rhs: DepthConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Heights above a horizontal reference, on a regular top-down grid (the LiDAR route). Row by row, the origin at
/// the top left. A cell with no measure is NaN: it is never read as a height of 0.
struct HeightMap: Hashable, Sendable {
    let width: Int
    let height: Int
    /// The side of a cell, in cm (0.2 to 0.3 for cells of 2 to 3 mm).
    let cellSizeCm: Double
    let heightsCm: [Double]
    let confidence: [DepthConfidence]

    init(width: Int, height: Int, cellSizeCm: Double, heightsCm: [Double], confidence: [DepthConfidence]) {
        self.width = width
        self.height = height
        self.cellSizeCm = cellSizeCm
        self.heightsCm = heightsCm
        self.confidence = confidence
    }

    /// True when the arrays fill the grid and the cells have a size: only then can the map be integrated.
    var isConsistent: Bool {
        width > 0 && height > 0 && cellSizeCm.isFinite && cellSizeCm > 0
            && heightsCm.count == width * height && confidence.count == width * height
    }

    /// The height of a cell in cm, nil outside the grid or where there is no measure.
    func heightCm(x: Int, y: Int) -> Double? {
        guard isConsistent, x >= 0, x < width, y >= 0, y < height else { return nil }
        let value = heightsCm[y * width + x]
        return value.isFinite ? value : nil
    }

    /// The confidence of a cell (`low` outside the grid).
    func confidenceAt(x: Int, y: Int) -> DepthConfidence {
        guard isConsistent, x >= 0, x < width, y >= 0, y < height else { return .low }
        return confidence[y * width + x]
    }
}

/// What a depth engine hands over for one scan: the height map and, on the same grid, the mask of every food and
/// the ring of the plate (the part of the plate left free of food, which gives the plane of the table).
struct HeightMapCapture: Hashable, Sendable {
    var map: HeightMap
    var foodMasks: [FoodMask]
    var plateRing: FoodMask
}
