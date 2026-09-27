import AppIntents
import Foundation
import WidgetKit

/// A saved design, offered in the widget's "Modifier le widget" menu.
struct DesignEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Tessera"
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
        kindTitle = design.kind.title
    }
}

struct DesignQuery: EntityQuery {
    func entities(for identifiers: [DesignEntity.ID]) async throws -> [DesignEntity] {
        let designs = SharedStore.shared.designs
        return identifiers.compactMap { id in
            designs.first { $0.id.uuidString == id }.map(DesignEntity.init(design:))
        }
    }

    func suggestedEntities() async throws -> [DesignEntity] {
        SharedStore.shared.designs
            .sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
            .map(DesignEntity.init(design:))
    }
}

/// Configuration shared by every Tessera widget: which saved design to display.
struct DesignWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choisir un widget"
    static var description = IntentDescription("Affiche un widget que tu as créé dans Tessera.")

    @Parameter(title: "Widget")
    var design: DesignEntity?

    init() {}

    init(design: DesignEntity?) {
        self.design = design
    }
}
