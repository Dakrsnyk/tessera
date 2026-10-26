import XCTest
import Vision
import ImageIO
@testable import Tessera

/// Real photos (free licences, see Tests/Fixtures/FoodPhotos/ATTRIBUTIONS.md) read by the REAL Vision classifier, then turned
/// into foods by `FoodLabelMatcher`. The goal is to MEASURE what the scan recognises on the CI simulator. One line per photo:
///   RECO-PHOTO <file> [<category>]: étiquettes [...] ; propositions [...] ; attendu [...] ; OK|RATÉ
/// then a global rate and one per category. A photo is « recognised » when one of the first 5 proposals matches an expected food
/// or alternative (accents and case ignored). The rate is measured, not imposed.
final class FoodPhotoRecognitionTests: XCTestCase {

    private struct Entry: Decodable {
        let file: String
        let category: String
        let expected: [String]
        let alternatives: [String]
    }

    /// Where the fixtures are: the test bundle if the files were copied there, else next to this source file (the repository is on
    /// the runner's disk in CI).
    private func fixturesFolder() -> URL? {
        let fromSource = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/FoodPhotos")
        if FileManager.default.fileExists(atPath: fromSource.appendingPathComponent("manifest.json").path) { return fromSource }
        if let bundled = Bundle(for: FoodPhotoRecognitionTests.self).url(forResource: "manifest", withExtension: "json") {
            return bundled.deletingLastPathComponent()
        }
        return nil
    }

    private func loadManifest() throws -> (URL, [Entry]) {
        guard let folder = fixturesFolder() else { throw XCTSkip("Dossier Tests/Fixtures/FoodPhotos introuvable") }
        let data = try Data(contentsOf: folder.appendingPathComponent("manifest.json"))
        return (folder, try JSONDecoder().decode([Entry].self, from: data))
    }

    private func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_CA"))
            .lowercased()
    }

    private func classify(_ url: URL) throws -> [FoodLabelMatcher.LabelScore] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "FoodPhoto", code: 1, userInfo: [NSLocalizedDescriptionKey: "image illisible \(url.lastPathComponent)"])
        }
        let request = VNClassifyImageRequest()
        #if targetEnvironment(simulator)
        request.usesCPUOnly = true
        #endif
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let observations = request.results ?? []
        return observations.map { FoodLabelMatcher.LabelScore(label: $0.identifier, confidence: Double($0.confidence)) }
    }

    func testManifestAndFilesAreConsistent() throws {
        let (folder, entries) = try loadManifest()
        XCTAssertGreaterThanOrEqual(entries.count, 30)
        for entry in entries {
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(entry.file).path), entry.file)
            XCTAssertFalse(entry.expected.isEmpty, entry.file)
            XCTAssertTrue(["single", "composite", "plate", "breakfast", "dessert"].contains(entry.category), entry.file)
        }
        XCTAssertEqual(Set(entries.map(\.file)).count, entries.count, "noms de fichiers uniques")
    }

    func testRecognitionRateOnRealPhotos() throws {
        let (folder, entries) = try loadManifest()
        var lines: [String] = []
        var perCategory: [String: (ok: Int, total: Int)] = [:]
        var recognised = 0
        var classified = 0
        var firstFailure: String?

        for entry in entries {
            let url = folder.appendingPathComponent(entry.file)
            let scores: [FoodLabelMatcher.LabelScore]
            do {
                scores = try classify(url)
            } catch {
                if firstFailure == nil { firstFailure = "\(entry.file): \(error.localizedDescription)" }
                lines.append("RECO-PHOTO \(entry.file) [\(entry.category)]: ERREUR Vision \(error.localizedDescription)")
                continue
            }
            classified += 1
            let top = scores.sorted { $0.confidence > $1.confidence }.prefix(8)
                .map { "\($0.label) \(String(format: "%.2f", $0.confidence))" }
            let proposals = FoodLabelMatcher.proposals(from: scores)
            let names = proposals.map { $0.food.name }
            let wanted = (entry.expected + entry.alternatives).map(normalized)
            let ok = proposals.prefix(5).contains { proposal in
                let haystack = normalized(proposal.food.name) + " " + normalized(proposal.food.id)
                return wanted.contains { !$0.isEmpty && haystack.contains($0) }
            }
            if ok { recognised += 1 }
            var tally = perCategory[entry.category] ?? (0, 0)
            tally.total += 1
            if ok { tally.ok += 1 }
            perCategory[entry.category] = tally
            lines.append("RECO-PHOTO \(entry.file) [\(entry.category)]: étiquettes [\(top.joined(separator: ", "))] ; "
                + "propositions [\(names.joined(separator: ", "))] ; attendu \(entry.expected) ; \(ok ? "OK" : "RATÉ")")
        }

        if classified == 0 {
            let reason = firstFailure ?? "aucune image classée"
            attach(lines + ["Vision indisponible : \(reason)"])
            throw XCTSkip("Vision ne classe aucune image sur ce simulateur : \(reason)")
        }

        func percent(_ ok: Int, _ total: Int) -> String {
            total == 0 ? "n/a" : String(format: "%.0f %%", 100 * Double(ok) / Double(total))
        }
        lines.append("RECO-TAUX global: \(recognised)/\(classified) (\(percent(recognised, classified)))")
        for category in perCategory.keys.sorted() {
            let tally = perCategory[category]!
            lines.append("RECO-TAUX \(category): \(tally.ok)/\(tally.total) (\(percent(tally.ok, tally.total)))")
        }
        attach(lines)
        print(lines.joined(separator: "\n"))

        XCTAssertGreaterThan(classified, 0)
        XCTAssertGreaterThanOrEqual(recognised, 1, "au moins une photo doit être reconnue")
    }

    private func attach(_ lines: [String]) {
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "RECO-PHOTOS"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
