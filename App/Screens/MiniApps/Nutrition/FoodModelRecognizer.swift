import CoreGraphics
import CoreML
import Foundation

/// Why the Core ML food models could not give an answer. Never shown: the caller falls back on Vision.
enum FoodModelError: Error {
    /// A compiled model is not in the app bundle.
    case modelMissing(String)
    /// The file that links the classes of the classifier to the foods of the tables is missing or does not fit the classifier.
    case classMapInvalid
    /// A model does not have the inputs or outputs this code expects.
    case unexpectedModel(String)
    /// The image has no pixels to read or the crop could not be drawn.
    case unreadableImage
}

/// A food the classifier thinks a zone shows: the identifier of a food of the tables (`builtin.…`, `cnf.…`, `usda.…`), or,
/// for a class that has no food in the tables, the label of the class (`mfr:…`). The probability is added up over every
/// class that gives the same food.
struct FoodModelCandidate: Hashable, Sendable {
    var key: String
    var probability: Double

    /// False for a class with no food in the tables (its key is its label).
    var isFood: Bool { !key.hasPrefix(FoodModelRecognizer.labelPrefix) }
}

/// What the classifier says about one square of the photo.
struct FoodModelClassification: Hashable, Sendable {
    /// The most likely foods, the most likely first (at most `ScannerModelLogic.foodsPerZone`).
    var foods: [FoodModelCandidate]
    /// The class with the highest probability (`mfr:…`) and its probability.
    var topLabel: String
    var topProbability: Double
}

/// One zone of the photo where the segmenter found a food, and what the classifier says it is.
struct FoodModelZone: Hashable, Sendable {
    /// How sure the segmenter is that the zone is a food, 0 to 1.
    var score: Double
    /// The box of the segmenter, in pixels of the photo (x, y, width, height).
    var box: CGRect
    /// The box of the pixels of the mask, in pixels of the photo.
    var maskBounds: CGRect
    /// The square (margin included, possibly partly outside the photo) given to the classifier.
    var cropRect: CGRect
    var classification: FoodModelClassification
}

/// The food recognition of the iPhone, in two steps: a segmenter (RF-DETR-Seg, Core ML) says where the foods are, then a
/// classifier (DINOv2 and a small head, Core ML) says which food each zone is. The photo is not kept and nothing leaves
/// the device. The two models and the list of classes are read the first time they are needed and kept.
///
/// The rules (resizing, threshold, duplicates, square crop, merging of the classes) are those of the Python that checked the
/// models, in `ScannerModelLogic`; `FoodModelParityTests` compares this engine with the PyTorch references.
///
/// It never crashes on a missing or failing model: it throws a `FoodModelError`, and the caller uses Vision instead.
final class FoodModelRecognizer: @unchecked Sendable {
    /// The classes without a food in the tables keep a label that starts with this.
    static let labelPrefix = "mfr:"
    /// The compiled models and the class map, in the bundle of the app (Xcode compiles the `.mlpackage` files).
    static let segmenterName = "ArdaneFoodSegmenter"
    static let classifierName = "ArdaneFoodClassifier"
    static let classMapName = "ArdaneFoodClassMap"
    /// Side of the square the segmenter reads, when the model does not say it.
    static let defaultSegmenterSide = 312
    /// Side of the square the classifier reads, when the model does not say it.
    static let defaultCropSide = 224
    /// At most this many candidates of the segmenter are looked at (the best scores); far above what a plate shows.
    static let maximumCandidates = 30
    /// The longest side of a photo the engine accepts (the scan gives at most `OnDeviceMealAnalyzer.maximumSide`).
    static let maximumSide = 2_048

    /// On the iPhone every unit may be used; the Simulator of the CI has no neural engine to rely on, so the CPU is used there.
    static let defaultComputeUnits: MLComputeUnits = {
        #if targetEnvironment(simulator)
        return .cpuOnly
        #else
        return .all
        #endif
    }()

    /// The engine of the app. The models are only read when something asks for them.
    static let shared = FoodModelRecognizer()

    let computeUnits: MLComputeUnits

    init(computeUnits: MLComputeUnits = FoodModelRecognizer.defaultComputeUnits) {
        self.computeUnits = computeUnits
    }

    // MARK: Loading

    private struct ClassMap: Decodable {
        let labels: [String]
        let foods: [String]
    }

    private struct Loaded {
        let segmenter: MLModel
        let segmenterInput: String
        let segmenterSide: Int
        let classifier: MLModel
        let classifierInput: String
        let classifierConstraint: MLImageConstraint
        let cropSide: Int
        let labels: [String]
        let foods: [String]
    }

    private let lock = NSLock()
    /// The result of the first loading, kept even when it failed (a missing model is not looked for again and again).
    private var loading: Result<Loaded, Error>?

    private func loadedModels() throws -> Loaded {
        lock.lock()
        defer { lock.unlock() }
        if let loading { return try loading.get() }
        let units = computeUnits
        let result: Result<Loaded, Error> = Result(catching: { try Self.load(computeUnits: units) })
        // A missing or unexpected model stays missing; an error of Core ML itself (low memory) is tried again next time.
        switch result {
        case .success: loading = result
        case .failure(let error): if error is FoodModelError { loading = result }
        }
        return try result.get()
    }

    /// Reads the models and the class map now. Throws what is missing; calling it again is free.
    func prepare() throws {
        _ = try loadedModels()
    }

    /// True when both models and the class map could be read.
    var isAvailable: Bool {
        (try? loadedModels()) != nil
    }

    private static func load(computeUnits: MLComputeUnits) throws -> Loaded {
        let segmenter = try model(named: segmenterName, computeUnits: computeUnits)
        let classifier = try model(named: classifierName, computeUnits: computeUnits)
        guard let mapURL = Bundle.main.url(forResource: classMapName, withExtension: "json"),
              let mapData = try? Data(contentsOf: mapURL),
              let map = try? JSONDecoder().decode(ClassMap.self, from: mapData),
              !map.labels.isEmpty, map.labels.count == map.foods.count else { throw FoodModelError.classMapInvalid }

        // The inputs are found by their type, not by their name (the converter chose them).
        guard let segmenterEntry = segmenter.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == .multiArray }) else {
            throw FoodModelError.unexpectedModel("segmenter input")
        }
        let shape = segmenterEntry.value.multiArrayConstraint?.shape.map { $0.intValue } ?? []
        var side = defaultSegmenterSide
        if shape.count == 4, shape[1] == 3, shape[2] == shape[3], shape[2] > 0 { side = shape[2] }

        guard let classifierEntry = classifier.modelDescription.inputDescriptionsByName.first(where: { $0.value.type == .image }),
              let constraint = classifierEntry.value.imageConstraint else {
            throw FoodModelError.unexpectedModel("classifier input")
        }
        var cropSide = defaultCropSide
        if constraint.pixelsWide > 0, constraint.pixelsWide == constraint.pixelsHigh { cropSide = constraint.pixelsWide }

        return Loaded(
            segmenter: segmenter, segmenterInput: segmenterEntry.key, segmenterSide: side,
            classifier: classifier, classifierInput: classifierEntry.key, classifierConstraint: constraint, cropSide: cropSide,
            labels: map.labels, foods: map.foods
        )
    }

    private static func model(named name: String, computeUnits: MLComputeUnits) throws -> MLModel {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else { throw FoodModelError.modelMissing(name) }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        return try MLModel(contentsOf: url, configuration: configuration)
    }

    // MARK: Recognition

    /// The foods on an upright photo: one zone per food the segmenter finds, the best score first, each with the foods the
    /// classifier proposes for it. Empty when the segmenter finds nothing. Heavy: call it off the main thread.
    func recognize(_ image: CGImage) throws -> [FoodModelZone] {
        // The masks are kept at the size of the photo: a photo of the camera must be reduced first (the scan does).
        guard max(image.width, image.height) <= Self.maximumSide else { throw FoodModelError.unreadableImage }
        let loaded = try loadedModels()
        var zones: [FoodModelZone] = []
        for found in try segment(image, with: loaded) {
            guard let bounds = ScannerModelLogic.litBounds(of: found.shape.mask) else { continue }
            let rect = ScannerModelLogic.squareCropRect(around: bounds, imageWidth: image.width, imageHeight: image.height)
            // A zone that cannot be cut out is skipped; the others are still classified.
            guard let crop = Self.squareCrop(of: image, rect: rect, side: loaded.cropSide) else { continue }
            let classification = try classify(crop, with: loaded)
            zones.append(FoodModelZone(
                score: found.score, box: found.shape.box, maskBounds: bounds, cropRect: rect, classification: classification
            ))
        }
        return zones
    }

    /// The classifier alone on the whole photo (a square around it with no margin, grey where it is outside).
    func classifyWholeImage(_ image: CGImage) throws -> FoodModelClassification {
        let loaded = try loadedModels()
        let whole = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = ScannerModelLogic.squareCropRect(around: whole, imageWidth: image.width, imageHeight: image.height, margin: 0)
        guard let crop = Self.squareCrop(of: image, rect: rect, side: loaded.cropSide) else { throw FoodModelError.unreadableImage }
        return try classify(crop, with: loaded)
    }

    // MARK: Segmenter

    private struct SegmentedZone {
        let score: Double
        let shape: DetectedShape
    }

    private func segment(_ image: CGImage, with loaded: Loaded) throws -> [SegmentedZone] {
        let width = image.width
        let height = image.height
        let side = loaded.segmenterSide
        guard let pixels = Self.rgbaPixels(of: image),
              let planes = ScannerModelLogic.resizedNormalizedPlanes(
                  rgba: pixels.bytes, width: width, height: height, bytesPerRow: pixels.bytesPerRow, side: side
              ) else { throw FoodModelError.unreadableImage }

        let inputShape: [NSNumber] = [1, 3, side, side].map { NSNumber(value: $0) }
        let input = try MLMultiArray(shape: inputShape, dataType: .float32)
        guard input.count == planes.count else { throw FoodModelError.unexpectedModel("segmenter input size") }
        // A new Float32 array is contiguous, in the order of its shape: the planes are copied as they are.
        input.withUnsafeMutableBytes { destination, _ in
            planes.withUnsafeBytes { source in destination.copyMemory(from: source) }
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: [loaded.segmenterInput: MLFeatureValue(multiArray: input)])
        let output = try loaded.segmenter.prediction(from: provider)

        // The three outputs are told apart by their shape: boxes [1, Q, 4], logits [1, Q, 2], masks [1, Q, h, w].
        var boxArray: MLMultiArray?
        var logitArray: MLMultiArray?
        var maskArray: MLMultiArray?
        for name in output.featureNames {
            guard let array = output.featureValue(for: name)?.multiArrayValue else { continue }
            let shape = array.shape.map { $0.intValue }
            if shape.count == 4 {
                maskArray = array
            } else if shape.count == 3, shape[2] == 4 {
                boxArray = array
            } else if shape.count == 3, shape[2] == 2 {
                logitArray = array
            }
        }
        guard let boxArray, let logitArray, let maskArray else { throw FoodModelError.unexpectedModel("segmenter outputs") }
        let boxShape = boxArray.shape.map { $0.intValue }
        let logitShape = logitArray.shape.map { $0.intValue }
        let maskShape = maskArray.shape.map { $0.intValue }
        let queries = boxShape[1]
        let classCount = logitShape[2]
        let maskHeight = maskShape[2]
        let maskWidth = maskShape[3]
        let maskSize = maskHeight * maskWidth
        guard queries > 0, logitShape[1] == queries, maskShape[1] == queries, maskSize > 0 else {
            throw FoodModelError.unexpectedModel("segmenter output sizes")
        }
        // Float16 or Float32 outputs alike: the values are converted to Float.
        let boxes = MLShapedArray<Float>(converting: boxArray).scalars
        let logits = MLShapedArray<Float>(converting: logitArray).scalars
        let masks = MLShapedArray<Float>(converting: maskArray).scalars
        guard boxes.count >= queries * 4, logits.count >= queries * classCount, masks.count >= queries * maskSize else {
            throw FoodModelError.unexpectedModel("segmenter output values")
        }

        // The queries that are foods (the first logit), the best score first.
        var candidates: [(query: Int, score: Double)] = []
        for query in 0..<queries {
            let score = ScannerModelLogic.sigmoid(Double(logits[query * classCount]))
            if score >= ScannerModelLogic.detectionThreshold { candidates.append((query, score)) }
        }
        candidates.sort { $0.score != $1.score ? $0.score > $1.score : $0.query < $1.query }

        // Each mask is brought to the size of the photo, then dropped if it duplicates a better one already kept.
        var keptShapes: [DetectedShape] = []
        var kept: [SegmentedZone] = []
        for candidate in candidates.prefix(Self.maximumCandidates) {
            let base = candidate.query * 4
            let box = ScannerModelLogic.detectionBox(
                centerX: Double(boxes[base]), centerY: Double(boxes[base + 1]),
                width: Double(boxes[base + 2]), height: Double(boxes[base + 3]),
                imageWidth: width, imageHeight: height
            )
            let start = candidate.query * maskSize
            let lowResolution = Array(masks[start..<(start + maskSize)])
            let resized = ScannerModelLogic.bilinearResize(lowResolution, width: maskWidth, height: maskHeight, toWidth: width, toHeight: height)
            guard resized.count == width * height else { continue }
            let mask = FoodMask(width: width, height: height, cells: resized.map { $0 > 0 })
            let shape = DetectedShape(box: box, mask: mask)
            if ScannerModelLogic.isDuplicate(shape, of: keptShapes) { continue }
            keptShapes.append(shape)
            kept.append(SegmentedZone(score: candidate.score, shape: shape))
        }
        return kept
    }

    // MARK: Classifier

    private func classify(_ crop: CGImage, with loaded: Loaded) throws -> FoodModelClassification {
        let value = try MLFeatureValue(cgImage: crop, constraint: loaded.classifierConstraint, options: nil)
        let provider = try MLDictionaryFeatureProvider(dictionary: [loaded.classifierInput: value])
        let output = try loaded.classifier.prediction(from: provider)
        guard let array = Self.probabilityArray(in: output, classCount: loaded.labels.count) else {
            throw FoodModelError.unexpectedModel("classifier output")
        }
        let probabilities = MLShapedArray<Float>(converting: array).scalars.map { Double($0) }
        guard probabilities.count == loaded.labels.count else { throw FoodModelError.unexpectedModel("classifier output size") }
        var best = 0
        for index in probabilities.indices where probabilities[index] > probabilities[best] { best = index }
        let foods = ScannerModelLogic.mergedByFood(probabilities: probabilities, foods: loaded.foods, labels: loaded.labels)
        return FoodModelClassification(
            foods: foods.map { FoodModelCandidate(key: $0.key, probability: $0.probability) },
            topLabel: loaded.labels[best], topProbability: probabilities[best]
        )
    }

    /// The array of class probabilities: the output named `probabilities`, else the one array that has one value per class
    /// (the embedding has another size).
    private static func probabilityArray(in output: MLFeatureProvider, classCount: Int) -> MLMultiArray? {
        if let named = output.featureValue(for: "probabilities")?.multiArrayValue, named.count == classCount { return named }
        for name in output.featureNames {
            if let array = output.featureValue(for: name)?.multiArrayValue, array.count == classCount { return array }
        }
        return nil
    }

    // MARK: Pixels

    /// The pixels of an image as 8-bit RGBA (sRGB, over white), row by row, at the size of the image.
    private static func rgbaPixels(of image: CGImage) -> (bytes: [UInt8], bytesPerRow: Int)? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return (bytes, bytesPerRow)
    }

    /// The square `rect` of the photo (corners rounded to pixels, as the Python does) brought to `side` × `side` pixels.
    /// The part of the square outside the photo is grey (`ScannerModelLogic.cropFill`).
    private static func squareCrop(of image: CGImage, rect: CGRect, side: Int) -> CGImage? {
        guard side > 0 else { return nil }
        let left = Double(rect.minX).rounded()
        let top = Double(rect.minY).rounded()
        let cropWidth = Double(rect.maxX).rounded() - left
        let cropHeight = Double(rect.maxY).rounded() - top
        guard cropWidth >= 1, cropHeight >= 1 else { return nil }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let fill = ScannerModelLogic.cropFill
        context.setFillColor(CGColor(red: CGFloat(fill[0]) / 255, green: CGFloat(fill[1]) / 255, blue: CGFloat(fill[2]) / 255, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.interpolationQuality = .high

        // Only the part of the square that is inside the photo is drawn, where it falls in the square.
        let visible = CGRect(x: left, y: top, width: cropWidth, height: cropHeight)
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        if !visible.isNull, visible.width >= 1, visible.height >= 1, let piece = image.cropping(to: visible) {
            let scaleX = Double(side) / cropWidth
            let scaleY = Double(side) / cropHeight
            let drawWidth = Double(visible.width) * scaleX
            let drawHeight = Double(visible.height) * scaleY
            let drawX = (Double(visible.minX) - left) * scaleX
            // The context has its origin at the bottom left, the photo at the top left.
            let drawY = Double(side) - (Double(visible.minY) - top) * scaleY - drawHeight
            context.draw(piece, in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
        return context.makeImage()
    }
}
