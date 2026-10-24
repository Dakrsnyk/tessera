import UIKit
import Vision
import PDFKit
import CoreImage

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
    /// Seconds an import may spend in extra OCR passes (the first pass of each page always runs).
    static let timeBudget: TimeInterval = 25

    /// The lines (and the colour probe) of each page (one page for a photo).
    static func pages(from source: ScheduleSource) async throws -> [SchedulePage] {
        switch source {
        case .image(let image):
            guard let cgImage = upright(image) else { throw ScheduleImportError.unreadable }
            return [try await recognize(cgImage, deadline: Date().addingTimeInterval(timeBudget))]
        case .pdf(let url):
            // A file chosen in the Files picker may need this access; it is harmless for any other file.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let document = PDFDocument(url: url), !document.isLocked, document.pageCount > 0 else {
                throw ScheduleImportError.unreadable
            }
            var pages: [SchedulePage] = []
            // One budget for the whole file: the extra passes of the last pages are skipped once it is spent.
            let deadline = Date().addingTimeInterval(timeBudget)
            for index in 0..<min(document.pageCount, maxPages) {
                try Task.checkCancellation()
                guard let page = document.page(at: index), let cgImage = render(page) else { continue }
                pages.append(try await recognize(cgImage, deadline: deadline))
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

    /// One way of looking at the image.
    private enum Pass: String {
        /// The image as it is (language correction on: names are better read with it).
        case original
        /// Enlarged (up to x2, within `longestSide`), grey, with more contrast and a light sharpening; language correction on.
        case enlarged
        /// Local contrast pushed to black on white (shadows of a photo and tinted cells vanish); language correction off,
        /// so that "08:10" stays a time and does not become a word.
        case binarized

        var usesLanguageCorrection: Bool { self != .binarized }
    }

    /// A line with the confidence Vision gives to its text.
    private struct ReadLine {
        var line: RecognizedLine
        var confidence: Float
    }

    /// What one pass (or a fusion of passes) gives once the parser has read it: the lines, and how well they explain the page.
    private struct Reading {
        var pass: Pass
        var lines: [ReadLine]
        var score: ScheduleScore
        var slotCount: Int
        /// Share (0...1) of the classes found that the parser marks "to check".
        var doubtfulShare: Double
    }

    /// A first reading is enough when it has this many lines at least, a quality of this or more, and at most this share
    /// of classes in doubt. Anything less starts another pass (at most `maximumPasses` in all: a few seconds).
    private static let solidLines = 15
    private static let solidQuality = 0.75
    private static let solidDoubtShare = 0.25
    private static let maximumPasses = 3
    /// A later pass replaces the best one so far only if it beats it by this share (as the layouts do).
    private static let switchMargin = 1.05
    /// When fusing, a line of another pass replaces one of the chosen pass at the same place if Vision is this much surer
    /// of it; a line only the other pass saw is added at this confidence at least.
    private static let confidenceGain: Float = 0.2
    private static let addedConfidence: Float = 0.6
    private static let samePlaceOverlap: CGFloat = 0.5

    /// Reads the image with one pass, then more passes only while the reading is not solid. The colour probe is built once,
    /// from the image as it was given: every pass keeps the aspect of the page, so the normalised places of the lines
    /// (0...1) are the same for all of them and the probe fits whichever lines are kept.
    private static func recognize(_ cgImage: CGImage, deadline: Date) async throws -> SchedulePage {
        let aspect = Double(cgImage.height) / Double(max(1, cgImage.width))
        let probe: LuminanceProbe? = try await background { LuminanceProbe(cgImage) }
        guard let first = try await read(.original, of: cgImage, probe: probe, aspect: aspect) else {
            throw ScheduleImportError.unreadable
        }
        var readings = [first]
        // A page with no class found and little text (a cover page) is not worth another look.
        let worthAnotherLook = first.slotCount > 0 || first.lines.count >= solidLines
        for pass in [Pass.enlarged, .binarized].prefix(maximumPasses - 1) {
            guard worthAnotherLook, !isSolid(best(of: readings)), Date() < deadline else { break }
            try Task.checkCancellation()
            if let more = try await read(pass, of: cgImage, probe: probe, aspect: aspect) { readings.append(more) }
        }
        var chosen = best(of: readings)
        // The lines the chosen pass is surer of elsewhere are replaced by the other pass's, and lines only another pass
        // saw are added; the fusion is kept only if the parser explains the page better with it.
        let others = readings.filter { $0.pass != chosen.pass }
        if !others.isEmpty {
            let base = chosen
            let merged: Reading? = try await background { fused(base, with: others, probe: probe, aspect: aspect) }
            if let merged { chosen = merged }
        }
        return SchedulePage(lines: chosen.lines.map { $0.line }, probe: probe, aspect: aspect)
    }

    /// The reading with the best score: a later one must beat the best so far by `switchMargin`.
    private static func best(of readings: [Reading]) -> Reading {
        var chosen = readings[0]
        for reading in readings.dropFirst() where reading.score.value > chosen.score.value * switchMargin + 0.01 {
            chosen = reading
        }
        return chosen
    }

    private static func isSolid(_ reading: Reading) -> Bool {
        reading.slotCount > 0
            && reading.lines.count >= solidLines
            && reading.score.quality >= solidQuality
            && reading.doubtfulShare <= solidDoubtShare
    }

    /// One pass: image prepared, text recognised, classes parsed and scored. nil when the pass cannot run (the first
    /// pass failing makes the page unreadable; a later one failing is just left out).
    private static func read(_ pass: Pass, of cgImage: CGImage, probe: LuminanceProbe?, aspect: Double) async throws -> Reading? {
        try await background { () -> Reading? in
            guard let image = prepared(cgImage, for: pass),
                  let lines = try? performRecognition(on: image, languageCorrection: pass.usesLanguageCorrection)
            else { return nil }
            return assess(pass, lines: lines, probe: probe, aspect: aspect)
        }
    }

    /// Parses and scores a set of lines.
    private static func assess(_ pass: Pass, lines: [ReadLine], probe: BlockProbe?, aspect: Double) -> Reading {
        let plain = lines.map { $0.line }
        let slots = ScheduleParser.slots(from: plain, probe: probe, aspect: aspect)
        let score = ScheduleScoring.evaluate(slots, lines: plain)
        let doubtful = slots.filter { $0.needsCheck }.count
        return Reading(pass: pass, lines: lines, score: score, slotCount: slots.count,
                       doubtfulShare: slots.isEmpty ? 1 : Double(doubtful) / Double(slots.count))
    }

    /// Runs a piece of work off the main thread.
    private static func background<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Fusion

    /// The chosen reading with, place by place, the text Vision is surer of in the other passes. nil when nothing changes
    /// or when the fused lines do not score better than the chosen reading.
    private static func fused(_ base: Reading, with others: [Reading], probe: BlockProbe?, aspect: Double) -> Reading? {
        var lines = base.lines
        var changed = false
        for other in others {
            var matched = Set<Int>()
            for index in lines.indices {
                guard let match = counterpart(of: lines[index], in: other.lines) else { continue }
                matched.insert(match)
                let theirs = other.lines[match]
                if theirs.confidence >= lines[index].confidence + confidenceGain, theirs.line.text != lines[index].line.text {
                    // The place stays the one of the chosen pass.
                    lines[index] = ReadLine(line: RecognizedLine(text: theirs.line.text, box: lines[index].line.box),
                                            confidence: theirs.confidence)
                    changed = true
                }
            }
            for (index, theirs) in other.lines.enumerated() where !matched.contains(index) && theirs.confidence >= addedConfidence {
                guard theirs.line.text.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
                // A line that overlaps one already read is another cut of the same text: not added.
                if lines.contains(where: { overlap($0.line.box, theirs.line.box) > 0.2 }) { continue }
                lines.append(theirs)
                changed = true
            }
        }
        guard changed else { return nil }
        let result = assess(base.pass, lines: lines, probe: probe, aspect: aspect)
        return result.score.value > base.score.value ? result : nil
    }

    /// The line of `others` at the same place as `line` (most overlapping, at least `samePlaceOverlap`).
    private static func counterpart(of line: ReadLine, in others: [ReadLine]) -> Int? {
        var found: Int?
        var bestOverlap = samePlaceOverlap
        for (index, other) in others.enumerated() {
            let shared = overlap(line.line.box, other.line.box)
            if shared >= bestOverlap {
                bestOverlap = shared
                found = index
            }
        }
        return found
    }

    /// Intersection over union of two boxes (0...1).
    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let shared = a.intersection(b)
        guard !shared.isNull, shared.width > 0, shared.height > 0 else { return 0 }
        let sharedArea = shared.width * shared.height
        let total = a.width * a.height + b.width * b.height - sharedArea
        return total > 0 ? sharedArea / total : 0
    }

    // MARK: Image passes

    private static let imageContext = CIContext(options: [.useSoftwareRenderer: false])

    /// The image for a pass: the original for `.original`, otherwise a processed copy with the same proportions.
    private static func prepared(_ cgImage: CGImage, for pass: Pass) -> CGImage? {
        switch pass {
        case .original: return cgImage
        case .enlarged: return enhanced(cgImage)
        case .binarized: return binarized(cgImage)
        }
    }

    /// One Core Image filter by name (a missing filter gives nil and the pass is skipped).
    private static func apply(_ name: String, to image: CIImage, _ values: [String: Any] = [:]) -> CIImage? {
        guard let filter = CIFilter(name: name) else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        for (key, value) in values { filter.setValue(value, forKey: key) }
        return filter.outputImage
    }

    /// The image enlarged by min(2, longestSide / longest side), so that small print has more pixels.
    private static func enlarged(_ cgImage: CGImage) -> CIImage? {
        let image = CIImage(cgImage: cgImage)
        let longest = CGFloat(max(cgImage.width, cgImage.height))
        let factor = max(1, min(2, longestSide / max(1, longest)))
        guard factor > 1.05 else { return image }
        return apply("CILanczosScaleTransform", to: image, [kCIInputScaleKey: Double(factor), kCIInputAspectRatioKey: 1.0])
    }

    private static func renderImage(_ image: CIImage) -> CGImage? {
        let rect = image.extent.integral
        guard rect.width > 8, rect.height > 8, rect.width.isFinite, rect.height.isFinite else { return nil }
        return imageContext.createCGImage(image, from: rect)
    }

    /// Enlarged, grey, more contrast, light sharpening.
    private static func enhanced(_ cgImage: CGImage) -> CGImage? {
        guard let big = enlarged(cgImage),
              let grey = apply("CIColorControls", to: big, [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 1.4]),
              let sharp = apply("CIUnsharpMask", to: grey, [kCIInputRadiusKey: 2.0, kCIInputIntensityKey: 0.7])
        else { return nil }
        return renderImage(sharp.cropped(to: big.extent))
    }

    /// Black text on a white page whatever the light: the grey image is compared with a strongly blurred copy of itself
    /// (the local background); what differs from it is ink, what does not is paper. A shadow or a tinted cell is part of
    /// the local background, so it turns white.
    private static func binarized(_ cgImage: CGImage) -> CGImage? {
        guard let big = enlarged(cgImage),
              let grey = apply("CIColorControls", to: big, [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 1.0])
        else { return nil }
        let extent = big.extent
        let sigma = max(8.0, Double(max(extent.width, extent.height)) / 80)
        let localBackground = grey.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: extent)
        // |grey - background|: 0 on paper, up to 1 on ink (dark on light or light on dark).
        guard let difference = apply("CIDifferenceBlendMode", to: grey, [kCIInputBackgroundImageKey: localBackground]) else { return nil }
        // out = 1 + gain * noiseFloor - gain * difference, clamped to 0...1: a difference under `noiseFloor` (noise) is paper.
        let gain = 4.0
        let noiseFloor = 0.08
        let bias = 1 + gain * noiseFloor
        guard let stretched = apply("CIColorMatrix", to: difference, [
            "inputRVector": CIVector(x: -gain, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: -gain, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: -gain, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0)
        ]) else { return nil }
        return renderImage(stretched.cropped(to: extent))
    }

    // MARK: Vision

    /// Words Vision should expect: the days and months of the six languages (and Japanese), their short forms, and the words
    /// of a school or college timetable. Used with language correction only.
    private static let customWords: [String] = {
        var words = Set<String>()
        func add(_ raw: String) {
            let word = raw.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).trimmingCharacters(in: .whitespacesAndNewlines)
            guard word.count >= 2 || ScheduleScoring.hasCJK(word) else { return }
            words.insert(word)
            words.insert(word.lowercased())
        }
        for identifier in ["fr_CA", "fr_FR", "en_US", "en_GB", "es_ES", "de_DE", "it_IT", "pt_BR", "ja_JP"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: identifier)
            let groups: [[String]] = [calendar.weekdaySymbols, calendar.shortWeekdaySymbols, calendar.veryShortWeekdaySymbols,
                                      calendar.monthSymbols, calendar.shortMonthSymbols]
            for symbol in groups.flatMap({ $0 }) { add(symbol) }
        }
        let extras = ["Horaire", "Local", "Salle", "Présentiel", "Distance", "Hybride", "En ligne", "Laboratoire", "Cours", "Pavillon",
                      "Pause", "Dîner", "Période", "Session", "Semaine", "Automne", "Hiver", "Été", "Printemps",
                      "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche",
                      "Schedule", "Timetable", "Room", "Classroom", "Lecture", "Lab", "Online", "Break", "Lunch", "Week",
                      "Horario", "Aula", "Sala", "Clase", "Stundenplan", "Raum", "Vorlesung", "Pause", "Woche",
                      "Orario", "Lezione", "Settimana", "Horário", "Semana", "時間割", "教室", "授業", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日"]
        for extra in extras { add(extra) }
        return Array(words)
    }()

    private static func performRecognition(on cgImage: CGImage, languageCorrection: Bool) throws -> [ReadLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = languageCorrection
        request.automaticallyDetectsLanguage = true
        // Small print (hour labels, the text of a block) is about 0.004 of the page height.
        request.minimumTextHeight = 0.002
        request.customWords = customWords
        let languages = recognitionLanguages(for: request)
        if !languages.isEmpty { request.recognitionLanguages = languages }
        // The image was already drawn upright, so Vision reads it as it is.
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])
        var lines: [ReadLine] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.15 else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let box = observation.boundingBox
            // Vision's origin is the bottom left; the parser reads from the top left.
            lines.append(ReadLine(line: RecognizedLine(text: text, box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)),
                                  confidence: candidate.confidence))
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
    /// A light page (the outlines of `framedRuns` are dark lines on it; on a dark page they are light lines).
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

    /// The page turned back by the tilt measured on the lines (`PageSkew`): each pixel of the straightened page is read from
    /// the place it comes from on the photo (bilinear), so the outlines are level and the columns upright again, exactly where
    /// the straightened lines say they are. Edges of the photo are repeated.
    func straightened(slope: Double, pivotX: Double, pivotY: Double, aspect: Double) -> BlockProbe? {
        guard slope.isFinite, abs(slope) <= 0.5, pivotX.isFinite, pivotY.isFinite, aspect.isFinite, aspect > 0 else { return nil }
        let w = width
        let h = height
        let source = pixels
        var turned = [UInt8](repeating: 255, count: w * h)
        turned.withUnsafeMutableBufferPointer { target in
            source.withUnsafeBufferPointer { from in
                for row in 0..<h {
                    let straightY = (Double(row) + 0.5) / Double(h)
                    for column in 0..<w {
                        let straightX = (Double(column) + 0.5) / Double(w)
                        let origin = PageSkew.photoPoint(x: straightX, y: straightY, slope: slope, pivotX: pivotX,
                                                         pivotY: pivotY, aspect: aspect)
                        // Pixel-centre coordinates on the photo, kept near the image so that the conversions below are safe.
                        let fx = min(max(origin.x * Double(w) - 0.5, -2), Double(w + 1))
                        let fy = min(max(origin.y * Double(h) - 0.5, -2), Double(h + 1))
                        let x0 = Int(fx.rounded(.down))
                        let y0 = Int(fy.rounded(.down))
                        let tx = fx - Double(x0)
                        let ty = fy - Double(y0)
                        let xa = min(max(x0, 0), w - 1)
                        let xb = min(max(x0 + 1, 0), w - 1)
                        let ya = min(max(y0, 0), h - 1)
                        let yb = min(max(y0 + 1, 0), h - 1)
                        let upper = Double(from[ya * w + xa]) * (1 - tx) + Double(from[ya * w + xb]) * tx
                        let lower = Double(from[yb * w + xa]) * (1 - tx) + Double(from[yb * w + xb]) * tx
                        let level = (upper * (1 - ty) + lower * ty).rounded()
                        target[row * w + column] = UInt8(min(255, max(0, level)))
                    }
                }
            }
        }
        return LuminanceProbe(width: w, height: h, pixels: turned)
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
    /// grey lines of the grid are not black. On a dark page (dark mode) the outlines are the thick LIGHT lines.
    func framedRuns(atX x: Double, fromY: Double, toY: Double) -> [ClosedRange<Double>]? {
        guard x.isFinite, fromY.isFinite, toY.isFinite else { return nil }
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
        // The ink of an outline: below the limit on a light page, above its mirror on a dark one.
        let darkLimit = LuminanceProbe.outlineBelow
        let lightLimit = 255 - LuminanceProbe.outlineBelow
        let onLightPage = lightPage
        for row in top...bottom {
            var dark = 0
            for column in first..<last {
                let level = Int(pixels[row * width + column])
                let isInk = onLightPage ? (level < darkLimit) : (level > lightLimit)
                if isInk { dark += 1 }
            }
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
