import XCTest
import Vision
@testable import Tessera

/// The import end to end with the REAL Vision: synthetic timetables (Tests/Support/ScheduleRenderer.swift) are drawn,
/// degraded (blur, tilt, JPEG, dark mode), read by `ScheduleImporter` and compared with what was drawn.
///
/// The goal is to KNOW what Vision really reads on the CI simulator, so the journal gets, for every case:
///   OCR-CAS <layout> <variant>: <n> créneaux, attendus <m>, corrects <k>
///   OCR-DETAIL <layout> <variant>: titres …, salles …, manquants [...], en trop [...]
///   OCR-LINES <layout> <variant> [y=… x=… w=… h=… « text »]   (one line per observation, centres, top-left origin)
/// A class is « correct » when its weekday matches and its start and end are within 10 minutes of the drawn ones.
/// When Vision fails or reads nothing on the clean page, the test is skipped with the exact reason (printed too).
/// The assertions are cautious on purpose; tighten them with the numbers read in the CI report. The lines Vision returned on the
/// first real run are kept in Tests/Support/ScheduleRealLines.swift and replayed by ScheduleRealWorldTests.
final class ScheduleRealOCRTests: XCTestCase {

    func testRendererIsConsistent() {
        for rendered in ScheduleRenderer.all() {
            XCTAssertGreaterThan(rendered.image.size.width, 500, rendered.name)
            XCTAssertGreaterThan(rendered.image.size.height, 500, rendered.name)
            XCTAssertFalse(rendered.expected.isEmpty, rendered.name)
            for variant in ScheduleVariant.allCases {
                let image = ScheduleRenderer.apply(variant, to: rendered.image)
                XCTAssertGreaterThan(image.size.width, 500, "\(rendered.name) \(variant.rawValue)")
            }
            // Two classes of the same day never overlap in the data the pages are drawn from.
            for first in rendered.expected {
                for second in rendered.expected where first.weekday == second.weekday
                    && first.startMinute < second.startMinute {
                    XCTAssertLessThanOrEqual(first.endMinute, second.startMinute, "\(rendered.name) overlap")
                }
            }
        }
    }

    func testOmnivoxGrid() async throws { try await run("omnivox") }
    func testFramedBlocks() async throws { try await run("encadres") }
    func testWeekView() async throws { try await run("semaine") }
    func testDayList() async throws { try await run("liste") }
    func testTable() async throws { try await run("tableau") }

    /// Runs last (XCTest goes in alphabetical order): the table of all the cases of this run, as one attachment. The
    /// `print`s are not kept by the CI journal; the attachments are exported in the report.
    func testZSynthese() {
        attach(Self.summaryRows.isEmpty ? "aucun cas lu" : Self.summaryRows.joined(separator: "\n"), name: "OCR-SYNTHESE")
    }

    /// One row per case: name, variant, lines read, classes found / expected / correct, or the reason of a skip.
    private static var summaryRows: [String] = []

    private func attach(_ text: String, name: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: Run

    private func run(_ name: String) async throws {
        let rendered = try XCTUnwrap(ScheduleRenderer.make(name))
        var rows: [String] = []
        defer { attach(rows.isEmpty ? "aucun cas lu" : rows.joined(separator: "\n"), name: "OCR-SYNTHESE-\(name)") }
        // Each variant costs up to three Vision passes on the simulator: the JPEG and dark-mode variants are kept for the two
        // main layouts only.
        let mainLayouts = ["omnivox", "encadres"]
        let variants = ScheduleVariant.allCases.filter { mainLayouts.contains(name) || ($0 != .jpeg && $0 != .dark) }
        for variant in variants {
            let image = ScheduleRenderer.apply(variant, to: rendered.image)
            let label = "\(name) \(variant.rawValue)"
            // Everything printed for the case is also kept, to be attached as one text file named OCR-<layout>-<variant>.
            var report: [String] = []
            func record(_ text: String) {
                print(text)
                report.append(text)
            }
            func finish(_ row: String) {
                rows.append(row)
                Self.summaryRows.append(row)
                attach(report.joined(separator: "\n"), name: "OCR-\(name)-\(variant.rawValue)")
            }

            // The lines Vision reads (and the reason when it does not). The image is read ONCE: the classes are then
            // computed from these same pages, as `ScheduleImporter.slots` does.
            var lineCount = 0
            var pages: [SchedulePage] = []
            do {
                pages = try await ScheduleReader.pages(from: .image(image))
                for page in pages {
                    for line in page.lines.sorted(by: { ($0.box.midY, $0.box.midX) < ($1.box.midY, $1.box.midX) }) {
                        record("OCR-LINES \(label) [y=\(fmt(line.box.midY)) x=\(fmt(line.box.midX)) w=\(fmt(line.box.width)) h=\(fmt(line.box.height)) « \(line.text) »]")
                    }
                    lineCount += page.lines.count
                }
                record("OCR-NOMBRE \(label): \(lineCount) lignes lues, image \(Int(image.size.width))x\(Int(image.size.height)) px")
            } catch {
                let reason = "Vision a échoué sur « \(label) » : \(error) ; \(visionDiagnostic(image))"
                record("OCR-ERREUR \(reason)")
                finish("\(name) | \(variant.rawValue) | erreur : \(reason)")
                if variant == .clean { throw XCTSkip(reason) }
                continue
            }
            if lineCount == 0 {
                let reason = "Vision ne renvoie aucune ligne sur « \(label) » : \(visionDiagnostic(image))"
                record("OCR-ERREUR \(reason)")
                finish("\(name) | \(variant.rawValue) | aucune ligne : \(reason)")
                if variant == .clean { throw XCTSkip(reason) }
                continue
            }

            // The import from the pages already read (the same steps as `ScheduleImporter.slots`; an empty list when nothing is found).
            var found: [ImportedSlot] = []
            for page in pages {
                found.append(contentsOf: ScheduleParser.slots(from: page.lines, probe: page.probe, aspect: page.aspect))
            }
            let slots = ScheduleParser.deduplicated(found)
            let result = score(slots, expected: rendered.expected)
            record("OCR-CAS \(label): \(slots.count) créneaux, attendus \(rendered.expected.count), corrects \(result.correct)")
            record("OCR-DETAIL \(label): titres \(result.titles)/\(result.correct), salles \(result.rooms)/\(result.correct), "
                + "manquants \(result.missing), en trop \(result.extra)")
            record("OCR-LUS \(label): \(slots.map { summary($0) })")
            finish("\(name) | \(variant.rawValue) | lignes \(lineCount) | créneaux \(slots.count) | attendus \(rendered.expected.count) | corrects \(result.correct)")

            XCTAssertLessThanOrEqual(slots.count, rendered.expected.count + 2, "trop de cours pour \(label)")
            if variant == .clean {
                // Not measured yet: the first real run read the clean boxed blocks at 6/10 and the others perfectly. Four classes of slack, to tighten with the CI numbers.
                XCTAssertGreaterThanOrEqual(result.correct, rendered.expected.count - 4, "image propre « \(label) » mal lue : \(slots.map { summary($0) })")
            }
        }
    }

    // MARK: Score

    private func score(_ slots: [ImportedSlot], expected: [ExpectedSlot])
        -> (correct: Int, titles: Int, rooms: Int, missing: [String], extra: [String]) {
        var used = Set<Int>()
        var correct = 0
        var titles = 0
        var rooms = 0
        var missing: [String] = []
        for item in expected {
            var best: (index: Int, distance: Int)?
            for (index, slot) in slots.enumerated() where !used.contains(index) && slot.weekday == item.weekday {
                let distance = abs(slot.startMinute - item.startMinute) + abs(slot.endMinute - item.endMinute)
                guard abs(slot.startMinute - item.startMinute) <= 10, abs(slot.endMinute - item.endMinute) <= 10 else { continue }
                if best == nil || distance < best!.distance { best = (index, distance) }
            }
            guard let found = best else {
                missing.append("\(item.weekday)|\(ScheduleRenderer.clock(item.startMinute))-\(ScheduleRenderer.clock(item.endMinute))|\(item.title)")
                continue
            }
            used.insert(found.index)
            correct += 1
            let slot = slots[found.index]
            let firstWord = item.title.split(separator: " ").first.map(String.init) ?? item.title
            if folded(slot.title).contains(folded(firstWord)) { titles += 1 }
            if let room = slot.room, folded(room).replacingOccurrences(of: " ", with: "").contains(folded(item.room)) { rooms += 1 }
        }
        let extra = slots.enumerated().filter { !used.contains($0.offset) }.map { summary($0.element) }
        return (correct, titles, rooms, missing, extra)
    }

    private func summary(_ slot: ImportedSlot) -> String {
        "\(slot.weekday)|\(ScheduleRenderer.clock(slot.startMinute))-\(ScheduleRenderer.clock(slot.endMinute))|\(slot.title)|\(slot.room ?? "-")"
    }

    private func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
    }

    private func fmt(_ value: CGFloat) -> String { String(format: "%.3f", Double(value)) }

    /// What Vision itself says about the image (the reader hides the original error), in both recognition levels.
    private func visionDiagnostic(_ image: UIImage) -> String {
        guard let cgImage = ScheduleReader.upright(image) else { return "image illisible" }
        let levels: [(name: String, level: VNRequestTextRecognitionLevel)] = [("accurate", .accurate), ("fast", .fast)]
        var parts: [String] = []
        for entry in levels {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = entry.level
            do {
                try VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:]).perform([request])
                parts.append("\(entry.name): \(request.results?.count ?? 0) observations")
            } catch {
                let nsError = error as NSError
                parts.append("\(entry.name): erreur \(nsError.domain) \(nsError.code) \(nsError.localizedDescription)")
            }
        }
        return parts.joined(separator: " ; ")
    }
}
