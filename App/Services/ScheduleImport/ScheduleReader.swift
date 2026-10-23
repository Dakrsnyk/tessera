import UIKit
import Vision
import PDFKit

/// Where the timetable comes from.
enum ScheduleSource { case image(UIImage), pdf(URL) }

enum ScheduleImportError: Error { case unreadable, nothingFound }

enum ScheduleImporter {
    /// Reads the schedule on the device only (Vision for text, PDFKit for PDFs); throws .nothingFound when no slot is recognized.
    static func slots(from source: ScheduleSource) async throws -> [ImportedSlot] {
        let pages = try await ScheduleReader.pages(from: source)
        var found: [ImportedSlot] = []
        for lines in pages {
            try Task.checkCancellation()
            found.append(contentsOf: ScheduleParser.slots(from: lines))
        }
        let slots = ScheduleParser.deduplicated(found)
        guard !slots.isEmpty else { throw ScheduleImportError.nothingFound }
        return slots
    }
}

/// Turns a photo or a PDF into lines of text with their place on the page. Everything runs on the iPhone:
/// nothing is sent anywhere. A PDF page is drawn as an image and read like a photo, so scanned PDFs and
/// PDFs with a text layer go through the same path (the places of the words are then the ones that are seen).
enum ScheduleReader {
    /// A longer PDF is cut here: a timetable never needs more.
    static let maxPages = 6
    /// Pixels of the longest side given to Vision: enough for small print, not so much that memory blows up.
    static let longestSide: CGFloat = 3000
    static let smallestSide: CGFloat = 1000

    /// The lines of each page (one page for a photo).
    static func pages(from source: ScheduleSource) async throws -> [[RecognizedLine]] {
        switch source {
        case .image(let image):
            guard let cgImage = upright(image) else { throw ScheduleImportError.unreadable }
            return [try await recognize(cgImage)]
        case .pdf(let url):
            // A file chosen in the Files picker may need this access; it is harmless for any other file.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else {
                throw ScheduleImportError.unreadable
            }
            var pages: [[RecognizedLine]] = []
            for index in 0..<min(document.pageCount, maxPages) {
                try Task.checkCancellation()
                guard let page = document.page(at: index), let cgImage = render(page) else { continue }
                pages.append(try await recognize(cgImage))
            }
            guard !pages.isEmpty else { throw ScheduleImportError.unreadable }
            return pages
        }
    }

    // MARK: Images

    /// The image drawn upright (its orientation applied) on a white background, with a side between
    /// `smallestSide` and `longestSide` pixels.
    static func upright(_ image: UIImage) -> CGImage? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest.isFinite, longest > 1, pixelWidth > 0, pixelHeight > 0 else { return nil }
        var factor: CGFloat = 1
        if longest > longestSide {
            factor = longestSide / longest
        } else if longest < smallestSide {
            factor = min(3, smallestSide / longest)
        }
        let target = CGSize(width: max(1, (pixelWidth * factor).rounded()), height: max(1, (pixelHeight * factor).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.cgImage
    }

    /// A PDF page drawn as an image.
    static func render(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        let turned = page.rotation % 180 != 0
        let width = turned ? bounds.height : bounds.width
        let height = turned ? bounds.width : bounds.height
        let scale = 2400 / max(width, height)
        let size = CGSize(width: width * scale, height: height * scale)
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        return upright(thumbnail)
    }

    // MARK: Vision

    private static func recognize(_ cgImage: CGImage) async throws -> [RecognizedLine] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[RecognizedLine], Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try performRecognition(on: cgImage))
                } catch {
                    continuation.resume(throwing: ScheduleImportError.unreadable)
                }
            }
        }
    }

    private static func performRecognition(on cgImage: CGImage) throws -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.minimumTextHeight = 0.007
        let languages = recognitionLanguages(for: request)
        if !languages.isEmpty { request.recognitionLanguages = languages }
        // The image was already drawn upright, so Vision reads it as it is.
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])
        var lines: [RecognizedLine] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.15 else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let box = observation.boundingBox
            // Vision's origin is the bottom left; the parser reads from the top left.
            lines.append(RecognizedLine(text: text, box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)))
        }
        return lines
    }

    /// The app's languages that Vision can read, the language of the device first.
    private static func recognitionLanguages(for request: VNRecognizeTextRequest) -> [String] {
        let supported = (try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: request.revision)) ?? []
        var wanted = ["fr", "en", "es", "de", "it", "pt", "ja"]
        if let device = Locale.preferredLanguages.first?.prefix(2).lowercased(), let index = wanted.firstIndex(of: device) {
            wanted.remove(at: index)
            wanted.insert(device, at: 0)
        }
        var result: [String] = []
        for code in wanted {
            if let match = supported.first(where: { $0.lowercased().hasPrefix(code) }) { result.append(match) }
        }
        return result
    }
}
