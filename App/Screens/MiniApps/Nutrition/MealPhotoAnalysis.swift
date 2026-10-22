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
/// iOS 13), which gives labels with a confidence. `FoodLabelMatcher` turns them into foods of the tables
/// of the app. The photo is not kept and nothing leaves the device.
struct OnDeviceMealAnalyzer: MealPhotoAnalyzing {
    /// The foods of the built-in table first (everyday foods, in French and English), then the Canadian
    /// Nutrient File.
    static func localSearch(_ query: String) -> [FoodItem] {
        FoodDatabase.search(query) + NutrientFile.search(query, limit: 5)
    }

    func analyze(_ image: UIImage) async throws -> [MealProposal] {
        guard let cgImage = image.cgImage else { throw MealAnalysisError.unreadableImage }
        let scores = try await Self.classify(cgImage, orientation: Self.orientation(of: image))
        return FoodLabelMatcher.proposals(from: scores, search: Self.localSearch)
    }

    /// Runs Vision off the main thread: every label it knows, with its confidence.
    private static func classify(_ image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [FoodLabelMatcher.LabelScore] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FoodLabelMatcher.LabelScore], Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNClassifyImageRequest()
                    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
                    try handler.perform([request])
                    let scores = (request.results ?? []).map {
                        FoodLabelMatcher.LabelScore(label: $0.identifier, confidence: Double($0.confidence))
                    }
                    continuation.resume(returning: scores)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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
