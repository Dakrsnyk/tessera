import AppIntents
import Foundation
import WidgetKit

/// A saved design offered in the widget's "Modifier le widget" menu (a catalog widget chosen by an earlier
/// version still reads).
struct DesignEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Ardane"
    static var defaultQuery = DesignQuery()

    var id: String
    var name: String
    var kindTitle: String

    var displayRepresentation: DisplayRepresentation {
        guard !kindTitle.isEmpty else { return DisplayRepresentation(title: "\(name)") }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(kindTitle)")
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

    /// The choice a widget gets when it is added (see `MyWidgetsChoice.newestID(in:)`). It never changes
    /// afterwards, so it isn't called automatic. It names no widget: Lock Screen widgets get it too and
    /// ignore it, and the entity can't tell which widget it configures.
    init(newestID: String) {
        id = newestID
        name = tr("Choisi à l'ajout")
        kindTitle = ""
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
            if MyWidgetsChoice.isNewestID(id) {
                return DesignEntity(newestID: id)
            }
            return DesignEntity.starterKind(id).map { DesignEntity(starter: $0) }
        }
    }

    /// The person's own widgets only, the latest first (« Modifier le widget » never lists the catalog).
    func suggestedEntities() async throws -> [DesignEntity] {
        MyWidgetsChoice.recent(SharedStore.shared.designs).map(DesignEntity.init(design:))
    }

    /// Given to each widget when it is added and kept in its configuration: « Mes widgets » keeps the
    /// latest widget of its size from then on, whatever is made afterwards. Lock Screen widgets ignore it.
    func defaultResult() async -> DesignEntity? {
        MyWidgetsChoice.newestID(in: SharedStore.shared.designs).map { DesignEntity(newestID: $0) }
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
    static var description = IntentDescription("Affiche un widget que tu as créé dans Ardane.")

    @Parameter(title: "Widget")
    var design: DesignEntity?

    init() {}

    init(design: DesignEntity?) {
        self.design = design
    }
}

/// Which of the person's widgets a « Mes widgets » on the Home Screen shows. iOS keeps one configuration
/// per placed widget: the widget chosen in « Modifier le widget », or the one fixed when it was added
/// (the latest of its size at that moment). Nothing made or saved afterwards changes a placed widget.
enum MyWidgetsChoice {
    static let newestPrefix = "new:"

    /// Used or changed most recently first: the order of « Modifier le widget ».
    static func recent(_ designs: [WidgetDesign]) -> [WidgetDesign] {
        designs.sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
    }

    /// The widget used or changed most recently that fits the size, made for it first.
    static func latest(in designs: [WidgetDesign], for family: WidgetFamily) -> WidgetDesign? {
        let fitting = recent(designs).filter { $0.families.contains(family) }
        return fitting.first { $0.format?.family == family } ?? fitting.first
    }

    /// The configuration of a widget being added: the latest widget of each Home Screen size, written
    /// `new:small=<id>,medium=<id>,large=<id>`. Nil before the first widget.
    static func newestID(in designs: [WidgetDesign]) -> String? {
        let parts = WidgetFormat.allCases.compactMap { format -> String? in
            guard let design = latest(in: designs, for: format.family) else { return nil }
            return "\(format.rawValue)=\(design.id.uuidString)"
        }
        return parts.isEmpty ? nil : newestPrefix + parts.joined(separator: ",")
    }

    static func isNewestID(_ id: String) -> Bool {
        id.hasPrefix(newestPrefix)
    }

    /// The widget fixed for this size in a configuration made by `newestID(in:)`.
    static func newestDesignID(_ id: String, for family: WidgetFamily) -> UUID? {
        guard isNewestID(id), let format = WidgetFormat(family) else { return nil }
        for part in id.dropFirst(newestPrefix.count).split(separator: ",") {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2, pair[0] == format.rawValue {
                return UUID(uuidString: pair[1])
            }
        }
        return nil
    }

    struct Resolution: Equatable {
        /// Nil: no widget made yet (the widget invites to make one).
        var design: WidgetDesign?
        /// The configuration names no widget that still exists: the widget shows the one remembered for
        /// its size, which the provider keeps from then on.
        var isFallback: Bool
    }

    /// What a « Mes widgets » shows. Without a usable configuration (placed by an earlier version, added
    /// before the first widget was made, or its widget deleted), the widget remembered for the size, else
    /// the latest of the size: once remembered, it no longer follows the widgets made afterwards.
    static func resolve(_ configuredID: String?, family: WidgetFamily, designs: [WidgetDesign], remembered: UUID?) -> Resolution {
        if let configuredID {
            let id = UUID(uuidString: configuredID) ?? newestDesignID(configuredID, for: family)
            if let id, let design = designs.first(where: { $0.id == id }) {
                return Resolution(design: design, isFallback: false)
            }
        }
        if let remembered, let design = designs.first(where: { $0.id == remembered }) {
            return Resolution(design: design, isFallback: true)
        }
        return Resolution(design: latest(in: designs, for: family), isFallback: true)
    }
}
