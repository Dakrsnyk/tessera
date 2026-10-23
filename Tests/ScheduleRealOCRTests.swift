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
/// The assertions are cautious on purpose; tighten them with the numbers read in the CI report.
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

    // MARK: Run

    private func run(_ name: String) async throws {
        let rendered = try XCTUnwrap(ScheduleRenderer.make(name))
        for variant in ScheduleVariant.allCases {
            let image = ScheduleRenderer.apply(variant, to: rendered.image)
            let label = "\(name) \(variant.rawValue)"

            // The lines Vision reads (and the reason when it does not).
            var lineCount = 0
            do {
                let pages = try await ScheduleReader.pages(from: .image(image))
                for page in pages {
                    for line in page.lines.sorted(by: { ($0.box.midY, $0.box.midX) < ($1.box.midY, $1.box.midX) }) {
                        print("OCR-LINES \(label) [y=\(fmt(line.box.midY)) x=\(fmt(line.box.midX)) w=\(fmt(line.box.width)) h=\(fmt(line.box.height)) « \(line.text) »]")
                    }
                    lineCount += page.lines.count
                }
                print("OCR-NOMBRE \(label): \(lineCount) lignes lues, image \(Int(image.size.width))x\(Int(image.size.height)) px")
            } catch {
                let reason = "Vision a échoué sur « \(label) » : \(error) ; \(visionDiagnostic(image))"
                print("OCR-ERREUR \(reason)")
                if variant == .clean { throw XCTSkip(reason) }
                continue
            }
            if lineCount == 0 {
                let reason = "Vision ne renvoie aucune ligne sur « \(label) » : \(visionDiagnostic(image))"
                print("OCR-ERREUR \(reason)")
                if variant == .clean { throw XCTSkip(reason) }
            }

            // The import, end to end.
            var slots: [ImportedSlot] = []
            do {
                slots = try await ScheduleImporter.slots(from: .image(image))
            } catch ScheduleImportError.nothingFound {
                slots = []
            } catch {
                print("OCR-ERREUR import \(label): \(error)")
            }
            let result = score(slots, expected: rendered.expected)
            print("OCR-CAS \(label): \(slots.count) créneaux, attendus \(rendered.expected.count), corrects \(result.correct)")
            print("OCR-DETAIL \(label): titres \(result.titles)/\(result.correct), salles \(result.rooms)/\(result.correct), "
                  + "manquants \(result.missing), en trop \(result.extra)")
            print("OCR-LUS \(label): \(slots.map { summary($0) })")

            XCTAssertLessThanOrEqual(slots.count, rendered.expected.count + 2, "trop de cours pour \(label)")
            if variant == .clean {
                XCTAssertGreaterThanOrEqual(result.correct, 1, "aucun cours juste sur l'image propre « \(label) »")
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
