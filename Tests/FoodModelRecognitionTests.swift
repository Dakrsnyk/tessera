import XCTest
import UIKit
import CoreML
@testable import Ardane

/// The same measure as `FoodPhotoRecognitionTests` (same photos, same manifest, same criterion) but with the analysis of the
/// app going through the Core ML food models (`OnDeviceMealAnalyzer` with `FoodModelRecognizer`, on the CPU). The goal is to
/// MEASURE what the scan recognises. One line per photo:
///   RECO-MODELE <file> [<category>]: zones [...] ; propositions [...] ; attendu [...] ; OK|RATÉ
/// then a global rate and one per category. A photo is « recognised » when one of the first 5 proposals matches an expected food
/// or alternative (accents and case ignored). The rate is measured, not imposed.
final class FoodModelRecognitionTests: XCTestCase {

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
        if let bundled = Bundle(for: FoodModelRecognitionTests.self).url(forResource: "manifest", withExtension: "json") {
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

    private func percent(_ ok: Int, _ total: Int) -> String {
        total == 0 ? "n/a" : String(format: "%.0f %%", 100 * Double(ok) / Double(total))
    }

    /// « best food 0.62 (score 0.91) » for a zone of the models.
    private func describe(_ zone: FoodModelZone) -> String {
        let first = zone.classification.foods.first
        let probability = String(format: "%.2f", first?.probability ?? 0)
        let score = String(format: "%.2f", zone.score)
        return "\(first?.key ?? zone.classification.topLabel) \(probability) (score \(score))"
    }

    func testRecognitionRateWithTheModels() async throws {
        let (folder, entries) = try loadManifest()
        let recognizer = FoodModelRecognizer(computeUnits: .cpuOnly)
        do {
            try recognizer.prepare()
        } catch {
            XCTFail("Modèles Core ML absents ou illisibles dans le paquet de l'app (\(error)) : il faut ArdaneFoodSegmenter.mlmodelc, "
                + "ArdaneFoodClassifier.mlmodelc et ArdaneFoodClassMap.json dans l'app")
            return
        }
        let analyzer = OnDeviceMealAnalyzer(recognizer: recognizer)

        var lines: [String] = []
        var perCategory: [String: (ok: Int, total: Int)] = [:]
        var recognised = 0
        var analysed = 0
        var photosWithZones = 0

        for entry in entries {
            let url = folder.appendingPathComponent(entry.file)
            guard let image = UIImage(contentsOfFile: url.path) else {
                lines.append("RECO-MODELE \(entry.file) [\(entry.category)]: ERREUR image illisible")
                continue
            }
            let result: (analysis: MealAnalysis, zones: [FoodModelZone])
            do {
                result = try await analyzer.analyzeMealDetailed(image)
            } catch {
                lines.append("RECO-MODELE \(entry.file) [\(entry.category)]: ERREUR \(error.localizedDescription)")
                continue
            }
            analysed += 1
            if !result.zones.isEmpty { photosWithZones += 1 }
            let proposals = result.analysis.proposals
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

            let zonesText = result.zones.map { describe($0) }.joined(separator: ", ")
            let names = proposals.map { $0.food.name }.joined(separator: ", ")
            var line = "RECO-MODELE \(entry.file) [\(entry.category)]: zones [\(zonesText)] ; propositions [\(names)] ; "
            line += "attendu \(entry.expected) ; \(ok ? "OK" : "RATÉ")"
            lines.append(line)
        }

        lines.append("RECO-MODELE-TAUX global: \(recognised)/\(analysed) (\(percent(recognised, analysed))) ; photos avec zones \(photosWithZones)/\(analysed)")
        for category in perCategory.keys.sorted() {
            let tally = perCategory[category] ?? (0, 0)
            lines.append("RECO-MODELE-TAUX \(category): \(tally.ok)/\(tally.total) (\(percent(tally.ok, tally.total)))")
        }
        let attachment = XCTAttachment(string: lines.joined(separator: "\n"))
        attachment.name = "RECO-MODELES"
        attachment.lifetime = .keepAlways
        add(attachment)
        print(lines.joined(separator: "\n"))

        XCTAssertGreaterThan(analysed, 0, "aucune photo analysée")
        XCTAssertGreaterThan(photosWithZones, 0, "le moteur Core ML chargé n'a trouvé aucune zone sur aucune photo")
    }
}
