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
    /// Height over width of the image: the tilt of a photo is turned back with it.
    var aspect = ScheduleLayouts.defaultAspect
}

enum ScheduleImporter {
    /// Reads the schedule on the device only (Vision for text, PDFKit for PDFs); throws .nothingFound when no slot is recognized.
    static func slots(from source: ScheduleSource) async throws -> [ImportedSlot] {
        let pages = try await ScheduleReader.pages(from: source)
        var found: [ImportedSlot] = []
        for page in pages {
            try Task.checkCancellation()
            found.append(contentsOf: ScheduleParser.slots(from: page.lines, probe: page.probe, aspect: page.aspect))
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
    /// An image narrower than this (and not too long) is enlarged before it is read.
    static let narrowSide: CGFloat = 1500

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
        } else if min(pixelWidth, pixelHeight) < narrowSide {
            // A screenshot (1020 px wide) has text only 8 px high: it is read better enlarged.
            factor = min(2, longestSide / longest)
        }
        let target = CGSize(width: max(1, (pixelWidth * factor).rounded()), height: max(1, (pixelHeight * factor).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { context in
            context.cgContext.interpolationQuality = .high
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
                    continuation.resume(returning: SchedulePage(lines: lines, probe: LuminanceProbe(cgImage),
                                                                aspect: Double(cgImage.height) / Double(max(1, cgImage.width))))
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
        // Small print (hour labels, the text of a block) is about 0.004 of the page height.
        request.minimumTextHeight = 0.002
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
///
/// Along a line there are two kinds of cell, told apart by Otsu's threshold on the grey levels: the lighter and the
/// darker one. The parser decides which of the two holds the text (Omnivox: white blocks on grey cells, so the lighter;
/// a calendar: coloured blocks on a white page, so the darker; a dark-mode screenshot: blocks lighter than the
/// background). Text and borders are left out first, whatever the theme of the page:
/// - a light page (most samples above 110): samples below 150 are text or borders; if the two kinds of cell cannot be
///   told apart that way, samples above 60 are tried (saturated blocks are darker than 150);
/// - a dark page: samples above 105 are text or borders, then above 195.
struct LuminanceProbe: BlockProbe {
    let width: Int
    let height: Int
    /// Grey levels, row by row from the top.
    let pixels: [UInt8]
    /// Dark text on a light page (the outlines of `framedRuns` are dark lines on it).
    private var lightPage = true

    /// A page whose middle sample is below this is a dark page.
    private static let darkPageBelow = 110
    /// The two kinds of cell must differ by at least this many levels (of 255): white against light grey is about 16,
    /// a column of empty cells (noise only) gives about 12.
    private static let minimumSeparation = 14.0
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
        self.lightPage = LuminanceProbe.isLight(data, width: w, height: h)
    }

    /// For tests: a probe over grey levels already known (row by row from the top).
    init?(width: Int, height: Int, pixels: [UInt8]) {
        guard width > 8, height > 8, pixels.count == width * height else { return nil }
        self.width = width
        self.height = height
        self.pixels = pixels
        self.lightPage = LuminanceProbe.isLight(pixels, width: width, height: height)
    }

    /// Whether the middle grey level of the page (looked at on a coarse grid of points) is a light one.
    private static func isLight(_ pixels: [UInt8], width: Int, height: Int) -> Bool {
        var levels: [UInt8] = []
        let rowStep = max(1, height / 200)
        let columnStep = max(1, width / 200)
        for row in stride(from: 0, to: height, by: rowStep) {
            for column in stride(from: 0, to: width, by: columnStep) { levels.append(pixels[row * width + column]) }
        }
        levels.sort()
        return Int(levels[levels.count / 2]) >= darkPageBelow
    }

    func blockRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
        analysis(atX: x, fromY: fromY, toY: toY)?.lighter
    }

    func darkRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
        analysis(atX: x, fromY: fromY, toY: toY)?.darker
    }

    /// A row of the window is part of an outline when this share of it is black.
    private static let outlineShare = 0.85
    private static let outlineBelow = 120
    /// The window starts this far (a share of the page width) right of the asked x, inside the cell, clear of its left
    /// outline and of the text, and is this wide.
    private static let outlineShift = 0.012
    private static let outlineWidth = 0.07
    /// Two outlines closer than this (a share of the page height) do not make a block.
    private static let outlineGap = 15.0 / 1023.0

    /// The stretches between two consecutive thick black horizontal lines (from the middle of one to the middle of the
    /// next), along the line at `x`. A line one or two
    /// pixels thick counts (a photo or a small screenshot); the text of a cell never fills 85% of a row, and the thin
    /// grey lines of the grid are not black.
    func framedRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
        guard lightPage, x.isFinite, fromY.isFinite, toY.isFinite else { return nil }
        let first = Int((x + LuminanceProbe.outlineShift) * Double(width))
        let last = min(width, Int((x + LuminanceProbe.outlineShift + LuminanceProbe.outlineWidth) * Double(width)))
        guard first >= 0, last - first >= 8 else { return nil }
        let top = max(0, Int((fromY * Double(height)).rounded(.down)))
        let bottom = min(height - 1, Int((toY * Double(height)).rounded(.up)))
        guard bottom - top >= 20 else { return nil }
        let needed = Int((Double(last - first) * LuminanceProbe.outlineShare).rounded(.up))
        var centers: [Double] = []
        var start: Int? = nil
        var lastDark = 0
        for row in top...bottom {
            var dark = 0
            for column in first..<last where Int(pixels[row * width + column]) < LuminanceProbe.outlineBelow { dark += 1 }
            guard dark >= needed else { continue }
            if let begin = start, row - lastDark - 1 > 1 {
                centers.append(Double(begin + lastDark) / 2)
                start = row
            } else if start == nil {
                start = row
            }
            lastDark = row
        }
        if let begin = start { centers.append(Double(begin + lastDark) / 2) }
        guard centers.count >= 2 else { return nil }
        var result: [ClosedRange<Double>] = []
        for index in 0..<(centers.count - 1) {
            // Two blocks that share an outline touch exactly: the end of one is the start of the next.
            let low = centers[index] / Double(height)
            let high = centers[index + 1] / Double(height)
            if high - low >= LuminanceProbe.outlineGap { result.append(low...high) }
        }
        return result
    }

    /// The stretches of the lighter and of the darker kind of cell along one vertical line, or nil when the line holds
    /// no two kinds of cell.
    private func analysis(atX x: Double, fromY: Double, toY: Double)
        -> (lighter: [ClosedRange<Double>], darker: [ClosedRange<Double>])? {
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
        let ordered = samples.sorted()
        let darkPage = ordered[ordered.count / 2] < LuminanceProbe.darkPageBelow
        let limits = darkPage ? [105, 195] : [150, 60]
        for limit in limits {
            let kept = samples.map { darkPage ? $0 <= limit : $0 >= limit }
            if let found = split(samples, kept: kept, top: top) { return found }
        }
        return nil
    }

    /// Otsu's threshold on the kept samples, then the stretches of each side.
    private func split(_ samples: [Int], kept: [Bool], top: Int)
        -> (lighter: [ClosedRange<Double>], darker: [ClosedRange<Double>])? {
        var histogram = [Int](repeating: 0, count: 256)
        var total = 0
        for (index, sample) in samples.enumerated() where kept[index] {
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
        var upper = [Bool](repeating: false, count: samples.count)
        var lower = [Bool](repeating: false, count: samples.count)
        var upperCount = 0
        for (index, sample) in samples.enumerated() where kept[index] {
            if sample > threshold {
                upper[index] = true
                upperCount += 1
            } else {
                lower[index] = true
            }
        }
        let share = Double(upperCount) / Double(total)
        guard share >= LuminanceProbe.minimumLightShare, share <= 1 - LuminanceProbe.minimumLightShare else { return nil }
        return (lighter: runs(of: upper, top: top), darker: runs(of: lower, top: top))
    }

    /// Stretches of true flags; a hole of one or two pixels (the border between two blocks) is closed.
    private func runs(of flags: [Bool], top: Int) -> [ClosedRange<Double>] {
        var stretches: [(from: Int, to: Int)] = []
        var start: Int? = nil
        var last = 0
        for (offset, flag) in flags.enumerated() where flag {
            if let begin = start, offset - last - 1 > LuminanceProbe.closedGap {
                stretches.append((from: begin, to: last))
                start = offset
            } else if start == nil {
                start = offset
            }
            last = offset
        }
        if let begin = start { stretches.append((from: begin, to: last)) }
        var result: [ClosedRange<Double>] = []
        for stretch in stretches where stretch.to - stretch.from + 1 >= LuminanceProbe.minimumRun {
            let low = Double(top + stretch.from) / Double(height)
            let high = Double(top + stretch.to + 1) / Double(height)
            result.append(low...high)
        }
        return result
    }
}
