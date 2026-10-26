import UIKit
import Vision
import ImageIO

/// Why a photo of a dish could not be analysed.
enum MealAnalysisError: Error {
    /// The online analysis is not switched on (step B, `MealAnalysisConfig.onlineEnabled`).
    case notEnabled
    /// The image has no pixels Vision can read.
    case unreadableImage
    /// The camera was not ready to take the photo.
    case cameraUnavailable
}

/// Something that looks at the photo of a dish and proposes foods. The screen only knows this protocol, so
/// the analysis can be replaced: today it is `OnDeviceMealAnalyzer` (Vision, on the iPhone); the online
/// one (`OnlineMealAnalyzer`) is prepared but switched off.
protocol MealPhotoAnalyzing {
    /// The foods the photo seems to show, as estimates (usual portions). An empty list means nothing was
    /// recognised; an error means the analysis itself failed.
    func analyze(_ image: UIImage) async throws -> [MealProposal]
    /// The same, with what the recap needs to remember the meal once validated.
    func analyzeMeal(_ image: UIImage) async throws -> MealAnalysis
}

extension MealPhotoAnalyzing {
    func analyzeMeal(_ image: UIImage) async throws -> MealAnalysis {
        MealAnalysis(proposals: try await analyze(image))
    }
}

/// What the analysis of a photo gives: the proposed foods, the visual fingerprint of the photo (a vector of
/// numbers, never the photo) and, when the first proposals come from a similar remembered meal, its date.
struct MealAnalysis {
    var proposals: [MealProposal]
    var featurePrint: [Float]?
    var memoryDate: Date?

    init(proposals: [MealProposal], featurePrint: [Float]? = nil, memoryDate: Date? = nil) {
        self.proposals = proposals
        self.featurePrint = featurePrint
        self.memoryDate = memoryDate
    }

    /// The recap to show; `ScanRecap.commit` stores the fingerprint with the foods the person keeps.
    var recap: ScanRecap {
        ScanRecap(proposals: proposals, featurePrint: featurePrint, memoryDate: memoryDate)
    }
}

/// Which analysis is used.
///
/// STEP B IS OFF. `onlineEnabled` is a constant of the code, not a setting and not shown to anyone: while
/// it is false nothing is ever sent out of the iPhone. Switching it on is NOT a code change alone. It needs
/// the owner's decision on the service to use, its cost, the server in between (no key may ship in the app
/// or sit on GitHub) and the privacy policy (`PRIVACY.md`, which says today that a photo is not sent
/// anywhere). Until then `OnlineMealAnalyzer` only throws `notEnabled`.
enum MealAnalysisConfig {
    static let onlineEnabled = false

    static func makeAnalyzer() -> MealPhotoAnalyzing {
        if onlineEnabled { return OnlineMealAnalyzer() }
        return OnDeviceMealAnalyzer()
    }
}

/// Step B, switched off: no network code, no address, no key. It answers « not enabled » so that nothing
/// can go out by mistake. The real one will be written after the decision described on `MealAnalysisConfig`.
struct OnlineMealAnalyzer: MealPhotoAnalyzing {
    func analyze(_ image: UIImage) async throws -> [MealProposal] {
        throw MealAnalysisError.notEnabled
    }
}

/// Step A: the photo is looked at on the iPhone by Vision (`VNClassifyImageRequest`, available since
/// iOS 13), which gives labels with a confidence, for the whole photo and for each object (or crop) of it. `FoodLabelMatcher` turns them into foods of the tables
/// of the app. The photo is not kept and nothing leaves the device.
struct OnDeviceMealAnalyzer: MealPhotoAnalyzing {
    /// The foods of the built-in table first (everyday foods, in French and English), then the Canadian
    /// Nutrient File.
    static func localSearch(_ query: String) -> [FoodItem] {
        FoodDatabase.search(query) + NutrientFile.search(query, limit: 5)
    }

    /// At most this many foods are proposed for a photo.
    static let maximumProposals = 8
    /// The photo is looked at on a copy of at most this many pixels on its long side.
    static let maximumSide: CGFloat = 1_024
    /// At most this many objects are cut out of the photo.
    static let maximumInstances = 4
    /// An object smaller than this share of the photo is not worth a crop; one bigger is the whole photo.
    static let minimumInstanceArea = 0.04
    static let maximumInstanceArea = 0.90
    /// How sure a food remembered from similar meals is shown (it is only a proposal, the person confirms).
    static let memoryConfidence = 0.8

    func analyze(_ image: UIImage) async throws -> [MealProposal] {
        try await analyzeMeal(image).proposals
    }

    func analyzeMeal(_ image: UIImage) async throws -> MealAnalysis {
        let vision = try await Self.runVision(image)
        // What the person usually keeps for a label, learned from their corrections (read on the iPhone).
        let state = SharedStore.shared.state(NutritionState.self)
        let known = state.customFoods + state.favorites + state.recentFoods
        let resolve: (String) -> FoodItem? = { id in known.first { $0.id == id } ?? FoodDatabase.all.first { $0.id == id } }

        // The whole photo and each crop give their own proposals; one food is kept once, at its best confidence.
        var byFood: [String: MealProposal] = [:]
        for scores in vision.labelSets {
            let found = FoodLabelMatcher.proposals(
                from: scores, limit: Self.maximumProposals, learning: state.scanLearning,
                resolve: resolve, search: Self.localSearch
            )
            for proposal in found {
                if let existing = byFood[proposal.food.id], existing.confidence >= proposal.confidence { continue }
                byFood[proposal.food.id] = proposal
            }
        }
        let fromLabels = byFood.values.sorted {
            $0.confidence != $1.confidence ? $0.confidence > $1.confidence : $0.food.id < $1.food.id
        }

        // Meals the person validated for a similar plate come first (only when at least two agree).
        var memoryProposals: [MealProposal] = []
        var memoryDate: Date?
        if let fingerprint = vision.featurePrint, let remembered = state.mealMemory.suggestionWithDate(for: fingerprint) {
            for item in remembered.items {
                guard let food = resolve(item.foodID) else { continue }
                memoryProposals.append(MealProposal(
                    food: food, grams: item.grams, confidence: Self.memoryConfidence, usesHabit: true
                ))
            }
            if !memoryProposals.isEmpty { memoryDate = remembered.date }
        }
        let memoryIDs = Set(memoryProposals.map { $0.food.id })
        let merged = memoryProposals + fromLabels.filter { !memoryIDs.contains($0.food.id) }
        return MealAnalysis(
            proposals: Array(merged.prefix(Self.maximumProposals)),
            featurePrint: vision.featurePrint, memoryDate: memoryDate
        )
    }

    // MARK: Vision

    /// What Vision saw: the labels of the whole photo then of each crop, and the fingerprint of the photo.
    private struct VisionResult {
        var labelSets: [[FoodLabelMatcher.LabelScore]]
        var featurePrint: [Float]?
    }

    /// Runs Vision off the main thread.
    private static func runVision(_ image: UIImage) async throws -> VisionResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<VisionResult, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let upright = Self.uprightCopy(of: image) else {
                    continuation.resume(throwing: MealAnalysisError.unreadableImage)
                    return
                }
                do {
                    var sets = [try Self.classify(upright)]
                    // The foods one by one: the objects Vision cuts out, else a grid of overlapping crops.
                    var crops = Self.instanceCrops(of: upright)
                    if crops.isEmpty { crops = Self.gridCrops(of: upright) }
                    for crop in crops {
                        if let scores = try? Self.classify(crop) { sets.append(scores) }
                    }
                    continuation.resume(returning: VisionResult(labelSets: sets, featurePrint: Self.featurePrint(of: upright)))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// The labels Vision gives to an upright image, with their confidence.
    private static func classify(_ image: CGImage) throws -> [FoodLabelMatcher.LabelScore] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])
        return (request.results ?? []).map {
            FoodLabelMatcher.LabelScore(label: $0.identifier, confidence: Double($0.confidence))
        }
    }

    /// The visual fingerprint of the photo (`VNGenerateImageFeaturePrintRequest`), nil if Vision cannot give
    /// one. Only the numbers are kept, never the image.
    private static func featurePrint(of image: CGImage) -> [Float]? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first,
              observation.elementType == .float, observation.elementCount > 0 else { return nil }
        let count = observation.elementCount
        let values: [Float] = observation.data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self).prefix(count))
        }
        return values.count == count ? values : nil
    }

    /// The photo drawn upright (whatever its camera orientation) and reduced to `maximumSide`, so every
    /// request and every crop works in the same coordinates.
    private static func uprightCopy(of image: UIImage) -> CGImage? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let longSide = max(image.size.width, image.size.height)
        let factor = min(1, maximumSide / longSide)
        let size = CGSize(width: max(1, (image.size.width * factor).rounded()), height: max(1, (image.size.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let drawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return drawn.cgImage
    }

    // MARK: Crops

    /// A crop for each object Vision cuts out of the photo (iOS 17), the biggest first. Empty when the
    /// request is not available, fails, or finds no object of a useful size.
    private static func instanceCrops(of image: CGImage) -> [CGImage] {
        guard #available(iOS 17.0, *) else { return [] }
        let width = image.width, height = image.height
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first else { return [] }
        var boxes: [CGRect] = []
        for instance in observation.allInstances {
            guard let mask = try? observation.generateScaledMaskForImage(forInstances: IndexSet(integer: instance), from: handler),
                  let box = boundingBox(ofMask: mask, imageWidth: width, imageHeight: height) else { continue }
            let area = Double(box.width * box.height) / Double(width * height)
            guard area >= minimumInstanceArea, area <= maximumInstanceArea else { continue }
            boxes.append(box)
        }
        boxes.sort { $0.width * $0.height > $1.width * $1.height }
        return boxes.prefix(maximumInstances).compactMap { image.cropping(to: $0) }
    }

    /// The rectangle (in pixels of the image, with a small margin) that contains the lit pixels of a mask.
    private static func boundingBox(ofMask mask: CVPixelBuffer, imageWidth: Int, imageHeight: Int) -> CGRect? {
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent32Float else { return nil }
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let w = CVPixelBufferGetWidth(mask), h = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard w > 0, h > 0 else { return nil }
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = (base + y * rowBytes).assumingMemoryBound(to: Float.self)
            for x in 0..<w where row[x] > 0.5 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let scaleX = Double(imageWidth) / Double(w), scaleY = Double(imageHeight) / Double(h)
        let marginX = Double(maxX - minX + 1) * scaleX * 0.08, marginY = Double(maxY - minY + 1) * scaleY * 0.08
        let rect = CGRect(
            x: Double(minX) * scaleX - marginX, y: Double(minY) * scaleY - marginY,
            width: Double(maxX - minX + 1) * scaleX + 2 * marginX, height: Double(maxY - minY + 1) * scaleY + 2 * marginY
        )
        return rect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)).integral
    }

    /// The fallback: 3 × 3 crops of half the photo's side, each shifted by a quarter (they overlap by half).
    private static func gridCrops(of image: CGImage) -> [CGImage] {
        let width = Double(image.width), height = Double(image.height)
        guard width >= 64, height >= 64 else { return [] }
        var crops: [CGImage] = []
        for row in 0..<3 {
            for column in 0..<3 {
                let rect = CGRect(x: width * 0.25 * Double(column), y: height * 0.25 * Double(row), width: width * 0.5, height: height * 0.5).integral
                if let crop = image.cropping(to: rect) { crops.append(crop) }
            }
        }
        return crops
    }

    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
