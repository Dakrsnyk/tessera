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

    /// Draws the file into an 8-bit RGB bitmap (white background), `width` pixels wide, and measures it.
    private func renderedImage(_ url: URL, width: Int) throws -> (CGImage, String) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let original = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "FoodPhoto", code: 1, userInfo: [NSLocalizedDescriptionKey: "image illisible \(url.lastPathComponent)"])
        }
        let height = max(1, Int((Double(original.height) * Double(width) / Double(original.width)).rounded()))
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "FoodPhoto", code: 2, userInfo: [NSLocalizedDescriptionKey: "CGContext impossible"])
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(original, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(), let data = context.data else {
            throw NSError(domain: "FoodPhoto", code: 3, userInfo: [NSLocalizedDescriptionKey: "bitmap vide"])
        }
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var sum = 0.0
        var count = 0
        var index = 0
        while index < width * height * 4 {
            sum += 0.299 * Double(bytes[index]) + 0.587 * Double(bytes[index + 1]) + 0.114 * Double(bytes[index + 2])
            count += 1
            index += 4 * 7
        }
        func pixel(_ fx: Double, _ fy: Double) -> String {
            let o = (Int(Double(height - 1) * fy) * width + Int(Double(width - 1) * fx)) * 4
            return "(\(bytes[o]),\(bytes[o + 1]),\(bytes[o + 2]))"
        }
        let diag = "source \(original.width)x\(original.height) bits \(original.bitsPerComponent) espace \(original.colorSpace?.name.map { String(describing: $0) } ?? "?") ; "
            + "dessinée \(width)x\(height) ; luminance moyenne \(String(format: "%.1f", sum / Double(max(count, 1)))) ; "
            + "pixels \(pixel(0.25, 0.25)) \(pixel(0.75, 0.25)) \(pixel(0.25, 0.75)) \(pixel(0.5, 0.5))"
        return (image, diag)
    }

    private enum Variant: String, CaseIterable { case cpu800, revision2, small299 }

    private func classify(_ image: CGImage, variant: Variant) throws -> [FoodLabelMatcher.LabelScore] {
        let request = VNClassifyImageRequest()
        request.usesCPUOnly = true
        if variant == .revision2 { request.revision = VNClassifyImageRequestRevision2 }
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).map { FoodLabelMatcher.LabelScore(label: $0.identifier, confidence: Double($0.confidence)) }
    }

    private func signature(_ scores: [FoodLabelMatcher.LabelScore]) -> String {
        scores.sorted { $0.confidence > $1.confidence }.prefix(8)
            .map { "\($0.label) \(String(format: "%.2f", $0.confidence))" }.joined(separator: ", ")
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

        // Step 1: every photo, three ways (CPU only on 800 px, revision 2, 299x299), plus a diagnostic of the bitmap.
        var results: [String: [Variant: [FoodLabelMatcher.LabelScore]]] = [:]
        for entry in entries {
            let url = folder.appendingPathComponent(entry.file)
            do {
                let (image800, diag) = try renderedImage(url, width: 800)
                let (image299, _) = try renderedImage(url, width: 299)
                lines.append("RECO-DIAG \(entry.file): \(diag)")
                var byVariant: [Variant: [FoodLabelMatcher.LabelScore]] = [:]
                for variant in Variant.allCases {
                    byVariant[variant] = try classify(variant == .small299 ? image299 : image800, variant: variant)
                }
                results[entry.file] = byVariant
            } catch {
                if firstFailure == nil { firstFailure = "\(entry.file): \(error.localizedDescription)" }
                lines.append("RECO-PHOTO \(entry.file) [\(entry.category)]: ERREUR \(error.localizedDescription)")
            }
        }
        classified = results.count
        // Step 2: does Vision vary from one photo to another? Keep the first way that does.
        var chosen: Variant?
        for variant in Variant.allCases {
            let distinct = Set(results.values.compactMap { $0[variant].map(signature) })
            lines.append("RECO-ESSAI \(variant.rawValue) (usesCPUOnly" + (variant == .revision2 ? ", révision 2" : "")
                + (variant == .small299 ? ", 299x299" : ", 800 px") + "): \(distinct.count) jeu(x) d'étiquettes distinct(s) sur \(results.count) photos")
            if chosen == nil && distinct.count > 1 { chosen = variant }
        }
        if classified == 0 || chosen == nil {
            let reason = classified == 0 ? (firstFailure ?? "aucune image classée")
                : "mêmes étiquettes pour toutes les images (\(signature(results.values.first?[.cpu800] ?? [])))"
            attach(lines + ["Vision inutilisable : \(reason)"])
            throw XCTSkip("Vision classification inutilisable sur ce simulateur : \(reason)")
        }
        lines.append("RECO-CHOIX: \(chosen!.rawValue)")
        for entry in entries {
            guard let scores = results[entry.file]?[chosen!] else { continue }
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
            lines.append("RECO-PHOTO \(entry.file) [\(entry.category)]: étiquettes [\(signature(scores))] ; "
                + "propositions [\(names.joined(separator: ", "))] ; attendu \(entry.expected) ; \(ok ? "OK" : "RATÉ")")
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
