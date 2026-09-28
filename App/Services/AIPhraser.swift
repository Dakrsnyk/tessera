import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Rewrites the deterministic analyses with Apple's on-device model (iOS 26, Apple Intelligence),
/// then stores the phrasing for the widgets. Nothing leaves the iPhone. A phrasing is kept only if
/// every number it contains comes from the facts; otherwise the widget keeps the plain analysis.
enum AIPhraser {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    static func phrase(_ insight: Insight) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            let prompt = "Faits :\n" + insight.facts.map { "- " + $0 }.joined(separator: "\n") + "\n\nRésume ces faits pour le widget « \(insight.title) »."
            do {
                let session = LanguageModelSession(instructions: """
                Tu écris le texte d'un widget iPhone, en français, en tutoyant. \
                Deux phrases courtes au maximum, 180 caractères au plus. \
                Utilise uniquement les faits fournis. N'invente aucun chiffre, aucune donnée, aucun conseil médical ou financier.
                """)
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, text.count <= 240, InsightCache.isGrounded(text, facts: insight.facts) else { return nil }
                return text
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// Refreshes the phrasings whose facts changed. Called when the app becomes active.
    static func refresh(payload: WidgetPayload, now: Date = Date()) async -> Bool {
        guard isAvailable else { return false }
        var cache = InsightCache.load()
        var changed = false
        for kind in [WidgetKind.aiSummary, .aiNutrition, .aiFinance, .aiProductivity] {
            let insight = InsightEngine.insight(for: kind, payload: payload, now: now)
            if cache.entries[kind.rawValue]?.factsKey == insight.factsKey { continue }
            if let text = await phrase(insight) {
                cache.entries[kind.rawValue] = InsightCache.Entry(factsKey: insight.factsKey, text: text, createdAt: now)
                changed = true
            }
        }
        if changed { SharedStore.shared.write(cache, to: .insights) }
        return changed
    }
}
