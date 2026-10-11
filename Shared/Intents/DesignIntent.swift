import AppIntents
import Foundation
import WidgetKit

/// A saved design, or a ready-made widget of the catalog, offered in the widget's "Modifier le widget" menu.
struct DesignEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Ardane"
    static var defaultQuery = DesignQuery()

    var id: String
    var name: String
    var kindTitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(kindTitle)")
    }

    init(design: WidgetDesign) {
        id = design.id.uuidString
        name = design.name
        kindTitle = design.kindTitle
    }

    /// A catalog widget with its default look, usable without creating a design first.
    init(starter kind: WidgetKind) {
        id = Self.starterPrefix + kind.rawValue
        name = kind.title
        kindTitle = tr("\(kind.category.title) · modèle")
    }

    static let starterPrefix = "kind:"

    static func starterKind(_ id: String) -> WidgetKind? {
        guard id.hasPrefix(starterPrefix) else { return nil }
        return WidgetKind(rawValue: String(id.dropFirst(starterPrefix.count)))
    }
}

struct DesignQuery: EntityStringQuery {
    func entities(for identifiers: [DesignEntity.ID]) async throws -> [DesignEntity] {
        let designs = SharedStore.shared.designs
        return identifiers.compactMap { id -> DesignEntity? in
            if let design = designs.first(where: { $0.id.uuidString == id }) {
                return DesignEntity(design: design)
            }
            return DesignEntity.starterKind(id).map { DesignEntity(starter: $0) }
        }
    }

    func suggestedEntities() async throws -> [DesignEntity] {
        let saved = SharedStore.shared.designs
            .sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
            .map(DesignEntity.init(design:))
        let catalog = WidgetCategory.allCases.flatMap { WidgetKind.kinds(in: $0) }.map { DesignEntity(starter: $0) }
        return saved + catalog
    }

    func entities(matching string: String) async throws -> [DesignEntity] {
        let query = string.trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
        let all = try await suggestedEntities()
        guard !query.isEmpty else { return all }
        return all.filter { entity in
            "\(entity.name) \(entity.kindTitle)".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale).contains(query)
        }
    }
}

/// Configuration shared by every Ardane widget: which saved design (or catalog widget) to display.
struct DesignWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choisir un widget"
    static var description = IntentDescription("Affiche un widget que tu as créé dans Ardane, ou un modèle du catalogue.")

    @Parameter(title: "Widget")
    var design: DesignEntity?

    init() {}

    init(design: DesignEntity?) {
        self.design = design
    }
}
