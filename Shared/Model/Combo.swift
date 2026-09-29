import Foundation
import WidgetKit

/// The three Home Screen sizes of iOS widgets.
enum WidgetFormat: String, Codable, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var family: WidgetFamily {
        switch self {
        case .small: .systemSmall
        case .medium: .systemMedium
        case .large: .systemLarge
        }
    }

    var title: String {
        switch self {
        case .small: "Petit"
        case .medium: "Moyen"
        case .large: "Grand"
        }
    }

    init?(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        case .systemLarge: self = .large
        default: return nil
        }
    }
}

/// One widget inside a combined widget: its content (kind, options, name) and the room it takes,
/// half a row (small) or a whole row (medium). It is drawn in the combined widget's style.
struct ComboPart: Codable, Hashable {
    var kind: WidgetKind
    var options: DesignOptions
    var name: String
    var size: WidgetFormat

    init(kind: WidgetKind, options: DesignOptions, name: String, size: WidgetFormat) {
        self.kind = kind
        var options = options
        options.parts = []
        self.options = options
        self.name = name
        self.size = size
    }
}

/// How the widgets of a combined widget are laid out, following the real iOS sizes:
/// a medium widget is two small ones side by side, a large one is two medium rows,
/// each row holding one medium widget or two small ones.
enum ComboLayout {
    /// The rows of a combined widget, or nil when the parts don't fill whole rows of a medium or large widget.
    static func rows(_ parts: [ComboPart]) -> [[ComboPart]]? {
        var rows: [[ComboPart]] = []
        var waitingSmallRow: Int?
        for part in parts {
            switch part.size {
            case .medium:
                rows.append([part])
            case .small:
                if let index = waitingSmallRow {
                    rows[index].append(part)
                    waitingSmallRow = nil
                } else {
                    rows.append([part])
                    waitingSmallRow = rows.count - 1
                }
            case .large:
                return nil
            }
        }
        guard waitingSmallRow == nil, (1...2).contains(rows.count) else { return nil }
        return rows
    }

    /// Medium for one row, large for two.
    static func format(_ parts: [ComboPart]) -> WidgetFormat? {
        rows(parts).map { $0.count == 1 ? .medium : .large }
    }
}

/// Merging widgets of the same category into one bigger widget, without losing any of their content:
/// small + small → medium; four small, two medium, or one medium and two small → large.
enum Fusion {
    struct Result: Equatable {
        let parts: [ComboPart]
        let format: WidgetFormat
    }

    /// Widgets merge only within one space (or one catalog category for widgets outside the spaces).
    static func category(of kind: WidgetKind) -> String {
        kind.space.map { "space.\($0.rawValue)" } ?? "category.\(kind.category.rawValue)"
    }

    /// What the designs merge into, or nil when they can't: another category, a large widget,
    /// the same content twice, or sizes that don't fill a medium or a large widget.
    static func result(for designs: [WidgetDesign]) -> Result? {
        guard designs.count >= 2 else { return nil }
        var parts: [ComboPart] = []
        for design in designs {
            if design.isCombo {
                // A combined medium joins with its own widgets; a combined large is already full.
                guard design.displayFormat == .medium else { return nil }
                parts += design.options.parts
            } else {
                let format = design.displayFormat
                guard format != .large, design.kind.families.contains(format.family) else { return nil }
                parts.append(ComboPart(kind: design.kind, options: design.options, name: design.name, size: format))
            }
        }
        guard Set(parts.map { category(of: $0.kind) }).count == 1 else { return nil }
        // Each widget brings its own information: the same content twice isn't worth a merge.
        let contents = parts.map { ContentKey(kind: $0.kind, options: $0.options) }
        guard Set(contents).count == contents.count else { return nil }
        guard let format = ComboLayout.format(parts) else { return nil }
        return Result(parts: parts, format: format)
    }

    /// The merged widget, in the look of the first selected widget.
    static func merge(_ designs: [WidgetDesign]) -> WidgetDesign? {
        guard let result = result(for: designs), let first = designs.first, let lead = result.parts.first else { return nil }
        var options = DesignOptions()
        options.parts = result.parts
        return WidgetDesign(
            name: result.parts.map(\.name).joined(separator: " + "),
            kind: lead.kind,
            themeID: first.themeID,
            accentHex: first.accentHex,
            background: first.background,
            font: first.font,
            showsTitle: first.showsTitle,
            showsDetails: first.showsDetails,
            alignment: first.alignment,
            options: options,
            format: result.format
        )
    }

    private struct ContentKey: Hashable {
        let kind: WidgetKind
        let options: DesignOptions
    }
}

extension WidgetDesign {
    /// A widget made of several widgets (see `ComboLayout`).
    var isCombo: Bool { !options.parts.isEmpty }

    /// The widgets drawn inside, each as a full design in this design's style. Just this design otherwise.
    var partDesigns: [WidgetDesign] {
        guard isCombo else { return [self] }
        return options.parts.map(design(for:))
    }

    func design(for part: ComboPart) -> WidgetDesign {
        var design = self
        design.kind = part.kind
        design.options = part.options
        design.name = part.name
        design.format = part.size
        return design
    }

    /// The size the widget is shown at in the app, and the one it is made for on the Home Screen.
    var displayFormat: WidgetFormat {
        if isCombo { return ComboLayout.format(options.parts) ?? .medium }
        if let format, kind.families.contains(format.family) { return format }
        return kind.families.contains(.systemSmall) ? .small : .medium
    }

    /// The sizes the widget can be placed at. A combined widget has exactly one.
    var families: [WidgetFamily] {
        isCombo ? [displayFormat.family] : kind.families
    }

    /// Everything the widget (or the widgets inside it) needs to load.
    var dataNeeds: Set<DataNeed> {
        partDesigns.reduce(into: Set<DataNeed>()) { $0.formUnion(DataNeeds.needs(for: $1.kind)) }
    }

    /// Whether one of the widgets drawn needs Premium.
    var usesPremiumKind: Bool { partDesigns.contains { $0.kind.isPremium } }

    /// « Macros », or « Combiné · 2 widgets » for a combined widget.
    var kindTitle: String {
        isCombo ? "Combiné · \(options.parts.count) widgets" : kind.title
    }
}

/// Building a medium or a large widget from widgets of one category (the space creator):
/// one widget at that size when it exists there, or several widgets combined.
enum Composer {
    struct Slot: Equatable {
        let kind: WidgetKind
        let size: WidgetFormat
    }

    enum Plan: Equatable {
        /// One widget, shown at the chosen size (its own layout for that size).
        case single(WidgetKind)
        /// Several widgets combined, each at the size of its slot.
        case combo([Slot])
        /// Not possible yet, with what to do about it.
        case invalid(String)
    }

    static func maxCount(for format: WidgetFormat) -> Int {
        switch format {
        case .small: 12
        case .medium: 2
        case .large: 4
        }
    }

    static func plan(_ kinds: [WidgetKind], format: WidgetFormat) -> Plan {
        func fits(_ kind: WidgetKind, _ size: WidgetFormat) -> Bool { kind.families.contains(size.family) }
        switch format {
        case .small:
            guard let kind = kinds.first, kinds.count == 1 else { return .invalid("Un petit widget montre un seul widget.") }
            return fits(kind, .small) ? .single(kind) : .invalid("\(kind.title) n'existe pas en petit.")
        case .medium:
            switch kinds.count {
            case 0:
                return .invalid("Choisis 1 widget, ou 2 à réunir.")
            case 1:
                return fits(kinds[0], .medium) ? .single(kinds[0]) : .invalid("\(kinds[0].title) n'existe pas en moyen : ajoute un 2e widget pour les réunir.")
            case 2:
                guard kinds.allSatisfy({ fits($0, .small) }) else {
                    return .invalid("Pour réunir 2 widgets, chacun doit exister en petit.")
                }
                return .combo(kinds.map { Slot(kind: $0, size: .small) })
            default:
                return .invalid("Un widget moyen réunit 2 widgets au plus.")
            }
        case .large:
            switch kinds.count {
            case 0:
                return .invalid("Choisis de 1 à 4 widgets.")
            case 1:
                return fits(kinds[0], .large) ? .single(kinds[0]) : .invalid("\(kinds[0].title) n'existe pas en grand : ajoute d'autres widgets, jusqu'à 4.")
            case 2:
                guard kinds.allSatisfy({ fits($0, .medium) }) else {
                    return .invalid("Pour 2 widgets en grand, chacun doit exister en moyen : ajoute un 3e ou un 4e widget.")
                }
                return .combo(kinds.map { Slot(kind: $0, size: .medium) })
            case 3:
                // The richest widget takes a whole row, the two others share the other row.
                guard let wide = kinds.lastIndex(where: { fits($0, .large) }) ?? kinds.lastIndex(where: { fits($0, .medium) }) else {
                    return .invalid("Pour 3 widgets, l'un d'eux doit exister en moyen.")
                }
                let slots = kinds.enumerated().map { pair in Slot(kind: pair.element, size: pair.offset == wide ? .medium : .small) }
                guard slots.filter({ $0.size == .small }).allSatisfy({ fits($0.kind, .small) }) else {
                    return .invalid("Ces widgets ne tiennent pas ensemble en grand.")
                }
                return .combo(slots)
            case 4:
                guard kinds.allSatisfy({ fits($0, .small) }) else {
                    return .invalid("Pour réunir 4 widgets, chacun doit exister en petit.")
                }
                return .combo(kinds.map { Slot(kind: $0, size: .small) })
            default:
                return .invalid("Un grand widget réunit 4 widgets au plus.")
            }
        }
    }
}
