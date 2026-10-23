import UIKit
import Vision
import PDFKit

/// Where the timetable comes from.
enum ScheduleSource { case image(UIImage), pdf(URL) }

enum ScheduleImportError: Error { case unreadable, nothingFound }

/// One page read: its lines of text and, when the image could be looked at, a probe of its colours.
struct SchedulePage {
    var lines: [RecognizedLine]
    var probe: BlockProbe?
}

enum ScheduleImporter {
    /// Reads the schedule on the device only (Vision for text, PDFKit for PDFs); throws .nothingFound when no slot is recognized.
    static func slots(from source: ScheduleSource) async throws -> [ImportedSlot] {
        let pages = try await ScheduleReader.pages(from: source)
        var found: [ImportedSlot] = []
        for page in pages {
            try Task.checkCancellation()
            found.append(contentsOf: ScheduleParser.slots(from: page.lines, probe: page.probe))
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

    /// The lines (and the colour probe) of each page (one page for a photo).
    static func pages(from source: ScheduleSource) async throws -> [SchedulePage] {
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
            var pages: [SchedulePage] = []
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
        // `thumbnail` works in points and the image comes back at the screen scale: ask for fewer points.
        let scale = 2400 / max(width, height) / max(1, UIScreen.main.scale)
        let size = CGSize(width: width * scale, height: height * scale)
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        return upright(thumbnail)
    }

    // MARK: Vision

    private static func recognize(_ cgImage: CGImage) async throws -> SchedulePage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SchedulePage, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // The probe reads the same image Vision reads, so its coordinates are the ones of the lines.
                    let lines = try performRecognition(on: cgImage)
                    continuation.resume(returning: SchedulePage(lines: lines, probe: LuminanceProbe(cgImage)))
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

/// The colours of the page along vertical lines, from a grey copy of the image (the one Vision reads).
struct LuminanceProbe: BlockProbe {
    let width: Int
    let height: Int
    /// Grey levels, row by row from the top.
    let pixels: [UInt8]

    /// Below this level a sample is text or a border, not a cell.
    private static let darkest = 150
    /// The two kinds of cell must differ by at least this many levels (of 255).
    private static let minimumSeparation = 12.0
    /// Each kind must be at least this share of the samples (and the other at most one minus this).
    private static let minimumLightShare = 0.05
    private static let minimumRun = 10
    private static let closedGap = 2

    init?(_ image: CGImage) {
        let w = image.width
        let h = image.height
        guard w > 8, h > 8, w * h <= 40_000_000 else { return nil }
        var data = [UInt8](repeating: 255, count: w * h)
        let drawn: Bool = data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        self.width = w
        self.height = h
        self.pixels = data
    }

    func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
        guard x.isFinite, fromY.isFinite, toY.isFinite, x >= 0, x < 1 else { return nil }
        let column = min(width - 1, Int(x * Double(width)))
        let top = max(0, Int((fromY * Double(height)).rounded(.down)))
        let bottom = min(height - 1, Int((toY * Double(height)).rounded(.up)))
        guard bottom - top >= 20 else { return nil }
        // The median of three neighbouring columns ignores the noise of a photo and a border one pixel wide.
        let left = max(0, column - 1)
        let right = min(width - 1, column + 1)
        var samples: [Int] = []
        samples.reserveCapacity(bottom - top + 1)
        for row in top...bottom {
            var neighbours: [Int] = []
            for c in left...right { neighbours.append(Int(pixels[row * width + c])) }
            neighbours.sort()
            samples.append(neighbours[neighbours.count / 2])
        }
        // Otsu's threshold between the empty cells (a little grey) and the blocks (white), on the samples that
        // are not text or borders.
        var histogram = [Int](repeating: 0, count: 256)
        var total = 0
        for sample in samples where sample >= LuminanceProbe.darkest {
            histogram[sample] += 1
            total += 1
        }
        guard total >= 20 else { return nil }
        var sumAll = 0.0
        for level in 0..<256 { sumAll += Double(level * histogram[level]) }
        var weightBelow = 0.0
        var sumBelow = 0.0
        var bestVariance = -1.0
        var threshold = -1
        var separation = 0.0
        for level in 0..<255 {
            weightBelow += Double(histogram[level])
            sumBelow += Double(level * histogram[level])
            let weightAbove = Double(total) - weightBelow
            guard weightBelow > 0, weightAbove > 0 else { continue }
            let below = sumBelow / weightBelow
            let above = (sumAll - sumBelow) / weightAbove
            let variance = weightBelow * weightAbove * (above - below) * (above - below)
            if variance > bestVariance {
                bestVariance = variance
                threshold = level
                separation = above - below
            }
        }
        guard threshold >= 0, separation >= LuminanceProbe.minimumSeparation else { return nil }
        let lightCount = samples.filter { $0 >= LuminanceProbe.darkest && $0 > threshold }.count
        let share = Double(lightCount) / Double(total)
        guard share >= LuminanceProbe.minimumLightShare, share <= 1 - LuminanceProbe.minimumLightShare else { return nil }
        // Stretches of light samples; a hole of one or two pixels (the border between two blocks) is closed.
        var runs: [(from: Int, to: Int)] = []
        var start: Int? = nil
        var lastLight = 0
        for (offset, sample) in samples.enumerated() where sample >= LuminanceProbe.darkest && sample > threshold {
            if let begin = start, offset - lastLight - 1 > LuminanceProbe.closedGap {
                runs.append((from: begin, to: lastLight))
                start = offset
            } else if start == nil {
                start = offset
            }
            lastLight = offset
        }
        if let begin = start { runs.append((from: begin, to: lastLight)) }
        var result: [ClosedRange<Double>] = []
        for run in runs where run.to - run.from + 1 >= LuminanceProbe.minimumRun {
            let low = Double(top + run.from) / Double(height)
            let high = Double(top + run.to + 1) / Double(height)
            result.append(low...high)
        }
        return result
    }
}
