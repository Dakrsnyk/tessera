import CoreGraphics
import Foundation

// Architecture of the next food scanner (chantier 22.2). Nothing here is used by the screens yet: the previous
// pipeline (`FoodScanView` → `OnDeviceMealAnalyzer` → `FoodLabelMatcher` → `ScanRecap`) stays the default and is
// NOT rewritten. This folder holds the roles as protocols and the pure logic that is the same on every device, so
// that each role can be filled one at a time, tested without a device, and compared with the previous pipeline.
//
// `Shared/` is also compiled in the widget extension: Foundation and CoreGraphics only, no UIKit, ARKit, Vision or
// Core ML. The engines that need them (a Vision request, a Core ML model, an ARKit session) live in `App/` and
// conform to the protocols below; they hand over plain data (masks, height maps, candidates).
//
// Where each role is played TODAY (read from the code, audit of 2026-11-02):
//
// | Role (protocol)          | Existing component                                                         | Limit today |
// |--------------------------|----------------------------------------------------------------------------|-------------|
// | FoodRecognitionEngine    | `OnDeviceMealAnalyzer.classify` (Vision `VNClassifyImageRequest` on the photo | generic labels, not food-specific |
// |                          | and on each crop), then `FoodLabelMatcher.proposals` (synonyms, `DishTemplate`), | |
// |                          | `MealMemory` (nearest validated meals by feature print), `ScanLearning`      | |
// | FoodSegmentationEngine   | `OnDeviceMealAnalyzer.instanceCrops` (`VNGenerateForegroundInstanceMaskRequest`, | boxes of up to 4 generic |
// |                          | up to 4 objects) and `gridCrops` (3×3 grid)                                  | objects, no mask per food |
// | FoodDepthEngine          | none (no ARKit, no LiDAR, no depth anywhere)                                 | to write, experimental |
// | FoodVolumeEstimating     | none                                                                        | this folder |
// | FoodMassEstimating       | portions, not measures: `ScanLearning.usualGrams`, the median grams of      | no estimate of the quantity |
// |                          | `MealMemory`, `DishTemplate.Component.grams`, `FoodItem.servingGrams`        | on the photo |
// | NutritionResolving       | `FoodItem.nutrients(grams:)` (kept: it is the deterministic formula),       | fixed ±5/30/40 %, never measured |
// |                          | `ScanRecap.totals`, `ScanRecap.kcalRange` with `ScanUncertainty`             | |
// | FoodScanConfidence       | `ScanLine.confidence`, `ScanRecap.lowConfidence`, `ScanUncertainty`          | one number per food, not calibrated |
//
// Files: the protocols FoodRecognitionEngine, FoodSegmentationEngine, FoodDepthEngine and FoodVolumeEstimating are
// below; FoodMassEstimating is in ScannerMass.swift, NutritionResolving and FoodScanConfidence in
// ScannerConfidence.swift; ScannerEstimate (the log-normal estimate), ScannerGrids (masks, height map) and
// ScannerGeometry (scale, area, rectification) are the shared data and geometry.
//
// Routes of the quantity, from the most to the least precise:
//   1. LiDAR (iPhone Pro), experimental: `HeightMapIntegrator` → volume → mass by density.
//   2. Universal, no sensor: plate of known diameter (`ScanGeometry`) → area of the mask → × typical thickness
//      (`FoodThicknessTable`, TO MEASURE) → volume → mass by density (`FoodDensityTable`).
//   3. Fallback: the usual portion of the previous pipeline.
// Every quantity is a log-normal law (`ScanEstimate`) with its sources; the calories come from the existing
// deterministic formula. Nothing is ever presented as measured when it is a prior (`ScanEstimate.isPrior`).

/// What the recognition thinks a food could be: a food of the tables and how likely it is (0 to 1).
struct FoodCandidate: Hashable, Sendable {
    var food: FoodItem
    var probability: Double
    /// The label of the engine this food was found for (kept to record what the person corrects).
    var label: String?
    var preparation: FoodPreparation

    init(food: FoodItem, probability: Double, label: String? = nil, preparation: FoodPreparation = FoodPreparation.unknown) {
        self.food = food
        self.probability = probability
        self.label = label
        self.preparation = preparation
    }
}

/// One food found on the photo: the cells it covers and how sure the segmentation is.
struct FoodSegment: Hashable, Sendable {
    var mask: FoodMask
    var score: Double
    var label: String?
}

/// What a segmentation engine finds on a photo: the plate (the whole disc, food included) if there is one, and
/// one mask per food. All the masks are on the grid of the photo.
struct FoodSegmentation: Hashable, Sendable {
    var plate: FoodMask?
    var foods: [FoodSegment]
}

// MARK: - Engines (filled by the app)

/// Says which foods an image seems to show, most likely first.
protocol FoodRecognitionEngine {
    /// `segment`: the part of the image to look at (nil: the whole image). At most `limit` candidates.
    func recognize(_ image: CGImage, in segment: FoodSegment?, limit: Int) async throws -> [FoodCandidate]
}

/// Separates the foods of a photo: one mask per food, and the plate.
protocol FoodSegmentationEngine {
    func segment(_ image: CGImage) async throws -> FoodSegmentation
}

/// Measures the depth of the scene on a device that has a sensor (LiDAR).
protocol FoodDepthEngine {
    /// False on a device with no depth sensor, or when the experimental mode is off: the universal route is used.
    var isAvailable: Bool { get }
    /// A height map of the table with the masks of the foods and the ring of the plate moved onto its grid.
    func captureHeightMap(foodMasks: [FoodMask], plate: FoodMask?, cellSizeCm: Double) async throws -> HeightMapCapture
}

// MARK: - Volume

/// Everything a volume estimator may use for one food. An estimator takes what it needs and returns nil when
/// what it needs is missing, so the routes can be tried one after the other.
struct FoodVolumeInput: Sendable {
    var family: FoodCategory?
    var preparation: FoodPreparation
    var shape: FoodShape
    /// The footprint of the food in cm² (from the plate or an object of known size), for the route without depth.
    var area: ScanEstimate?
    /// The height map and which of its food masks is this food, for the LiDAR route.
    var heightMap: HeightMapCapture?
    var maskIndex: Int?

    init(
        family: FoodCategory? = nil, preparation: FoodPreparation = FoodPreparation.unknown, shape: FoodShape = FoodShape.heap,
        area: ScanEstimate? = nil, heightMap: HeightMapCapture? = nil, maskIndex: Int? = nil
    ) {
        self.family = family
        self.preparation = preparation
        self.shape = shape
        self.area = area
        self.heightMap = heightMap
        self.maskIndex = maskIndex
    }
}

/// An estimate of the volume of a food in cm³ (= ml), or nil when this route cannot give one.
protocol FoodVolumeEstimating {
    func estimateVolume(_ input: FoodVolumeInput) -> ScanEstimate?
}

/// Route 1: the volume integrated on a metric height map. Nil without a map, or when the integration falls back
/// (no plane, too few cells read, a food lower than 3 mm).
struct HeightMapVolumeEstimator: FoodVolumeEstimating {
    func estimateVolume(_ input: FoodVolumeInput) -> ScanEstimate? {
        guard let capture = input.heightMap, let index = input.maskIndex, capture.foodMasks.indices.contains(index) else { return nil }
        return HeightMapIntegrator.estimate(
            map: capture.map, mask: capture.foodMasks[index], ring: capture.plateRing, excluding: capture.foodMasks
        )
    }
}

/// Route 2: the volume as the footprint times the typical thickness of the food (a prior, to measure). Nil without
/// a footprint, or for a food that has no thickness (a drink).
struct ThicknessVolumeEstimator: FoodVolumeEstimating {
    func estimateVolume(_ input: FoodVolumeInput) -> ScanEstimate? {
        guard let area = input.area,
              let thickness = FoodThicknessTable.prior(family: input.family, preparation: input.preparation, shape: input.shape)
        else { return nil }
        return ThicknessVolume.volume(area: area, thickness: thickness)
    }
}
