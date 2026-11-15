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
        case .small: tr("Petit")
        case .medium: tr("Moyen")
        case .large: tr("Grand")
        }
    }

    /// What the size is for, said under the size choice (the space creator and the Studio's « Taille »).
    var hint: String {
        switch self {
        case .small: tr("L'essentiel en un coup d'œil. Choisis-en plusieurs pour créer plusieurs petits widgets.")
        case .medium: tr("Plus d'informations : un widget dans sa version moyenne, ou 2 widgets réunis côte à côte.")
        case .large: tr("Un tableau de bord de l'espace : un widget en grand, ou jusqu'à 4 widgets réunis.")
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
        let contents = parts.map { contentKey($0.kind, $0.options) }
        guard Set(contents).count == contents.count else { return nil }
        guard let format = ComboLayout.format(parts) else { return nil }
        return Result(parts: parts, format: format)
    }

    /// The merged widget, in the look of the first selected widget.
    /// `copiesBackground: false` is for a preview that may be built many times and then dropped: it
    /// leaves the photo file shared, so no copy is left behind (see `ownBackground`).
    static func merge(_ designs: [WidgetDesign], copiesBackground: Bool = true) -> WidgetDesign? {
        guard let result = result(for: designs), let first = designs.first, let lead = result.parts.first else { return nil }
        var options = DesignOptions()
        options.parts = result.parts
        return WidgetDesign(
            name: result.parts.map(\.name).joined(separator: " + "),
            kind: lead.kind,
            themeID: first.themeID,
            accentHex: first.accentHex,
            background: copiesBackground ? ownBackground(of: first.background) : first.background,
            font: first.font,
            showsTitle: first.showsTitle,
            showsDetails: first.showsDetails,
            alignment: first.alignment,
            options: options,
            format: result.format
        )
    }

    /// A background photo is copied under a new name: deleting the original widgets (which erases their
    /// photo file) must never take the merged widget's background with it. Without a readable file the
    /// merged widget takes the theme's background rather than pointing at a file that is about to go.
    static func ownBackground(of background: BackgroundStyle) -> BackgroundStyle {
        guard case let .photo(name) = background else { return background }
        guard let data = ImageStore.data(named: name) else { return .theme }
        let copy = "\(UUID().uuidString).jpg"
        ImageStore.restore(data, named: copy)
        return ImageStore.data(named: copy) == nil ? .theme : .photo(copy)
    }

    /// What a widget shows: its kind, and only the options that kind uses. Every widget carries all the
    /// options (a countdown date set when it was made, say), and those it doesn't use don't make it different.
    static func contentKey(_ kind: WidgetKind, _ options: DesignOptions) -> String {
        let detail: String
        switch kind {
        case .clock: detail = "\(options.clockShowsDate)"
        case .worldClock: detail = options.cities.joined(separator: ",")
        case .progress: detail = options.progressUnit.rawValue
        case .countdown: detail = "\(options.countdownTitle)|\(DateMath.dayKey(options.countdownDate))|\(options.countdownMode.rawValue)"
        case .birthday:
            let title = options.dayTitle ?? ""
            let day = options.dayDate.map { DateMath.dayKey($0) } ?? ""
            detail = "\(title)|\(day)|\(options.dayRepeatsYearly)"
        case .tasks: detail = "\(options.showsCompletedTasks)"
        case .note: detail = "\(options.noteTitle)|\(options.noteText)"
        case .crypto: detail = options.coinID
        case .moneyFlow: detail = options.moneyMode.rawValue
        default: detail = options.targetID ?? ""
        }
        return "\(kind.rawValue)|\(detail)"
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
        isCombo ? tr("Combiné · \(options.parts.count) widgets") : kind.title
    }
}

/// Editing the widgets inside a widget one step at a time (the Studio's « + », « Retirer », « Remplacer »,
/// « Monter / Descendre »): pure functions on the parts, following the layout rules of `ComboLayout` and `Composer`.
/// A widget alone is one part whose `size` is its format.
enum ComboEditing {
    /// The result of an edit: the parts (one = a widget alone), the format, and the old format when the size changed.
    struct Outcome: Equatable {
        let parts: [ComboPart]
        let format: WidgetFormat
        /// The previous format when the size changed (for the « Passé en Grand pour tout afficher » note).
        let resizedFrom: WidgetFormat?
    }

    enum Change: Equatable {
        case applied(Outcome)
        /// The reason, already translated.
        case refused(String)
    }

    /// Same space, or same catalog category for widgets outside the spaces (the rule of `Fusion.category`).
    static func sameFamily(_ a: WidgetKind, _ b: WidgetKind) -> Bool {
        Fusion.category(of: a) == Fusion.category(of: b)
    }

    /// The format the parts are shown at now.
    static func format(of parts: [ComboPart]) -> WidgetFormat {
        if parts.count == 1 { return parts[0].size }
        return ComboLayout.format(parts) ?? .medium
    }

    /// The part alone, at the medium size when its kind has one, else small (else its first size).
    private static func alone(_ part: ComboPart) -> ComboPart {
        var part = part
        if part.kind.families.contains(.systemMedium) {
            part.size = .medium
        } else if part.kind.families.contains(.systemSmall) {
            part.size = .small
        } else if part.kind.families.contains(.systemLarge) {
            part.size = .large
        }
        return part
    }

    /// The parts in the order they are drawn: row 1 then row 2, left to right (`ComboLayout.rows` groups the small
    /// ones by rows, whatever their order in the list). The parts as they are when they fill no whole rows.
    static func inDisplayOrder(_ parts: [ComboPart]) -> [ComboPart] {
        guard parts.count > 1, let rows = ComboLayout.rows(parts) else { return parts }
        return rows.flatMap { $0 }
    }

    /// Every outcome lists its parts in the order they are drawn, so the list and the widget agree.
    private static func outcome(_ parts: [ComboPart], from old: WidgetFormat) -> Outcome {
        let shown = inDisplayOrder(parts)
        let now = ComboEditing.format(of: shown)
        return Outcome(parts: shown, format: now, resizedFrom: now == old ? nil : old)
    }

    /// Plans these parts (in this order) at the first format of `formats` that works: each part keeps its
    /// options and name, only its size follows the plan.
    private static func fit(_ parts: [ComboPart], formats: [WidgetFormat], from old: WidgetFormat) -> Change {
        let kinds = parts.map(\.kind)
        for format in formats {
            switch Composer.plan(kinds, format: format) {
            case .single:
                guard parts.count == 1 else { continue }
                var part = parts[0]
                part.size = format
                return .applied(outcome([part], from: old))
            case let .combo(slots):
                guard slots.count == parts.count else { continue }
                var planned = parts
                for index in planned.indices { planned[index].size = slots[index].size }
                return .applied(outcome(planned, from: old))
            case .invalid:
                continue
            }
        }
        if case let .invalid(reason) = Composer.plan(kinds, format: .large) { return .refused(reason) }
        return .refused(tr("Ces widgets ne tiennent pas ensemble."))
    }

    static func adding(_ part: ComboPart, to current: [ComboPart]) -> Change {
        guard let first = current.first else {
            return .applied(outcome([alone(part)], from: alone(part).size))
        }
        let old = format(of: current)
        if current.contains(where: { Fusion.contentKey($0.kind, $0.options) == Fusion.contentKey(part.kind, part.options) }) {
            return .refused(tr("Ce widget est déjà dans le widget."))
        }
        guard sameFamily(first.kind, part.kind) else {
            return .refused(tr("Un widget réunit des widgets du même espace."))
        }
        guard current.count < 4 else {
            return .refused(tr("Un grand widget réunit 4 widgets au plus."))
        }
        // The smallest size that works; a large widget alone tries to stay large first.
        let formats: [WidgetFormat] = (current.count == 1 && first.size == .large) ? [.large, .medium] : [.medium, .large]
        return fit(current + [part], formats: formats, from: old)
    }

    static func removing(at index: Int, from current: [ComboPart]) -> Change {
        guard current.indices.contains(index) else { return .refused(tr("Ce widget n'existe plus.")) }
        guard current.count > 1 else { return .refused(tr("Il reste au moins un widget.")) }
        let old = format(of: current)
        var remaining = current
        remaining.remove(at: index)
        if remaining.count == 1 {
            return .applied(outcome([alone(remaining[0])], from: old))
        }
        return fit(remaining, formats: [.medium, .large], from: old)
    }

    static func replacing(at index: Int, with part: ComboPart, in current: [ComboPart]) -> Change {
        guard current.indices.contains(index) else { return .refused(tr("Ce widget n'existe plus.")) }
        let old = format(of: current)
        var others = current
        others.remove(at: index)
        if let other = others.first {
            if others.contains(where: { Fusion.contentKey($0.kind, $0.options) == Fusion.contentKey(part.kind, part.options) }) {
                return .refused(tr("Ce widget est déjà dans le widget."))
            }
            guard sameFamily(other.kind, part.kind) else {
                return .refused(tr("Un widget réunit des widgets du même espace."))
            }
        }
        var replaced = current
        replaced[index] = part
        if replaced.count == 1 {
            // A widget alone keeps its size when the new one has it.
            var single = part
            if part.kind.families.contains(current[0].size.family) {
                single.size = current[0].size
            } else {
                single = alone(part)
            }
            return .applied(outcome([single], from: old))
        }
        return fit(replaced, formats: old == .large ? [.large] : [.medium, .large], from: old)
    }

    static func moving(from: Int, to: Int, in current: [ComboPart]) -> Change {
        guard current.indices.contains(from), current.indices.contains(to) else {
            return .refused(tr("Ce widget n'existe plus."))
        }
        let old = format(of: current)
        guard from != to else { return .applied(outcome(current, from: old)) }
        var moved = current
        let part = moved.remove(at: from)
        moved.insert(part, at: to)
        // What is drawn follows the rows, not the list: the move counts only when the part really goes the way asked.
        var candidates: [Change] = []
        if ComboLayout.rows(moved) != nil {
            candidates.append(.applied(outcome(moved, from: old)))
        } else {
            // The sizes no longer fill whole rows in this order: plan again, at the same format when possible.
            let formats: [WidgetFormat] = old == .large ? [.large, .medium] : [.medium, .large]
            candidates.append(fit(moved, formats: formats, from: old))
        }
        // The same order of rows would be drawn again (a small one at the end of its row going down…): swap the rows.
        if let rows = ComboLayout.rows(current), rows.count == 2 {
            candidates.append(.applied(outcome(Array(rows.reversed().joined()), from: old)))
        }
        for candidate in candidates {
            if case let .applied(result) = candidate, movesAsAsked(part, from: from, to: to, in: result.parts) { return candidate }
        }
        if let refused = candidates.first(where: { if case .refused = $0 { return true } else { return false } }) { return refused }
        return .applied(outcome(current, from: old))
    }

    /// Whether the part sits further up (`to` < `from`) or further down than it did.
    private static func movesAsAsked(_ part: ComboPart, from: Int, to: Int, in result: [ComboPart]) -> Bool {
        guard let now = result.firstIndex(where: { $0.kind == part.kind }) else { return false }
        return to > from ? now > from : now < from
    }

    /// Whether « Monter » / « Descendre » moves this widget (false at the ends, or when it would be drawn in the same place).
    static func canMove(from: Int, to: Int, in current: [ComboPart]) -> Bool {
        guard current.indices.contains(from), current.indices.contains(to), from != to,
              case let .applied(result) = moving(from: from, to: to, in: current) else { return false }
        return movesAsAsked(current[from], from: from, to: to, in: result.parts)
    }

    static func arrangements(of current: [ComboPart]) -> [[ComboPart]] {
        guard current.count >= 2, let rows = ComboLayout.rows(current) else { return [current] }
        var candidates: [[ComboPart]] = [current]
        func resized(_ part: ComboPart, _ size: WidgetFormat) -> ComboPart {
            var part = part
            part.size = size
            return part
        }
        switch (current.count, rows.count) {
        case (2, 1):
            // Two small ones side by side.
            candidates.append([current[1], current[0]])
        case (2, 2):
            // Two medium ones, one per row.
            candidates.append([current[1], current[0]])
        case (3, 2):
            // One whole row and two small ones: any part can be the whole row, on top or at the bottom.
            for wide in current.indices {
                let others = current.indices.filter { $0 != wide }.map { current[$0] }
                guard current[wide].kind.families.contains(.systemMedium),
                      others.allSatisfy({ $0.kind.families.contains(.systemSmall) }) else { continue }
                let top = [resized(current[wide], .medium)] + others.map { resized($0, .small) }
                let bottom = others.map { resized($0, .small) } + [resized(current[wide], .medium)]
                candidates.append(top)
                candidates.append(bottom)
            }
        case (4, 2):
            // Four small ones: the two rows swapped.
            candidates.append([current[2], current[3], current[0], current[1]])
        default:
            break
        }
        var seen: [[ComboPart]] = []
        for candidate in candidates where !seen.contains(candidate) {
            seen.append(candidate)
        }
        return seen
    }

    /// Why this widget can't be added, judged with a default part (use `refusal(addingPart:to:)` with the part
    /// that will really be added).
    static func refusal(adding kind: WidgetKind, to current: [ComboPart]) -> String? {
        let part = ComboPart(kind: kind, options: DesignOptions(), name: kind.title,
                             size: kind.families.contains(.systemSmall) ? .small : .medium)
        return refusal(addingPart: part, to: current)
    }

    /// Why this part can't be added, or nil when it can: judged on the part itself (its options and name).
    static func refusal(addingPart part: ComboPart, to current: [ComboPart]) -> String? {
        guard !current.isEmpty else { return nil }
        if case let .refused(reason) = adding(part, to: current) { return reason }
        return nil
    }
}

extension WidgetDesign {
    /// The parts to edit: those of a combined widget, or the widget alone as one part (at its displayed format).
    var editableParts: [ComboPart] {
        if isCombo { return options.parts }
        return [ComboPart(kind: kind, options: options, name: name, size: displayFormat)]
    }

    /// The widget with these parts: one part = a widget alone, two or more = a combined widget. Style, colors,
    /// background… are kept. The name follows the parts until the user changes it.
    func applying(_ outcome: ComboEditing.Outcome) -> WidgetDesign {
        func autoName(_ parts: [ComboPart]) -> String { parts.map(\.name).joined(separator: " + ") }
        var design = self
        let followsParts = name == autoName(editableParts)
        if outcome.parts.count == 1, let part = outcome.parts.first {
            design.kind = part.kind
            design.options = part.options
            design.options.parts = []
            design.format = part.size
            if followsParts { design.name = part.name }
        } else if let lead = outcome.parts.first {
            design.kind = lead.kind
            design.options.parts = outcome.parts
            design.format = outcome.format
            if followsParts { design.name = autoName(outcome.parts) }
        }
        return design
    }
}

extension Fusion {
    /// Why these widgets don't merge (another space, a large widget, the same content twice, sizes that don't
    /// fill a medium or a large widget), or nil when they do.
    static func refusal(for designs: [WidgetDesign]) -> String? {
        guard designs.count >= 2, result(for: designs) == nil else { return nil }
        var parts: [ComboPart] = []
        for design in designs {
            if design.isCombo {
                guard design.displayFormat == .medium else { return tr("Un grand widget est déjà plein : il ne peut pas être réuni.") }
                parts += design.options.parts
            } else {
                let format = design.displayFormat
                guard format != .large else { return tr("Un grand widget est déjà plein : il ne peut pas être réuni.") }
                guard design.kind.families.contains(format.family) else {
                    return tr("\(design.name) n'existe pas dans cette taille.")
                }
                parts.append(ComboPart(kind: design.kind, options: design.options, name: design.name, size: format))
            }
        }
        guard Set(parts.map { category(of: $0.kind) }).count == 1 else {
            return tr("Un widget réunit des widgets du même espace.")
        }
        let contents = parts.map { contentKey($0.kind, $0.options) }
        guard Set(contents).count == contents.count else {
            return tr("Ce widget est déjà dans le widget.")
        }
        return tr("Ces tailles ne remplissent pas un widget moyen ou grand : il faut 2 petits, 2 moyens, 1 moyen et 2 petits, ou 4 petits.")
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
            guard let kind = kinds.first, kinds.count == 1 else { return .invalid(tr("Un petit widget montre un seul widget.")) }
            return fits(kind, .small) ? .single(kind) : .invalid(tr("\(kind.title) n'existe pas en petit."))
        case .medium:
            switch kinds.count {
            case 0:
                return .invalid(tr("Choisis 1 widget, ou 2 à réunir."))
            case 1:
                return fits(kinds[0], .medium) ? .single(kinds[0]) : .invalid(tr("\(kinds[0].title) n'existe pas en moyen : ajoute un 2e widget pour les réunir."))
            case 2:
                guard kinds.allSatisfy({ fits($0, .small) }) else {
                    return .invalid(tr("Pour réunir 2 widgets, chacun doit exister en petit."))
                }
                return .combo(kinds.map { Slot(kind: $0, size: .small) })
            default:
                return .invalid(tr("Un widget moyen réunit 2 widgets au plus."))
            }
        case .large:
            switch kinds.count {
            case 0:
                return .invalid(tr("Choisis de 1 à 4 widgets."))
            case 1:
                return fits(kinds[0], .large) ? .single(kinds[0]) : .invalid(tr("\(kinds[0].title) n'existe pas en grand : ajoute d'autres widgets, jusqu'à 4."))
            case 2:
                guard kinds.allSatisfy({ fits($0, .medium) }) else {
                    return .invalid(tr("Pour 2 widgets en grand, chacun doit exister en moyen : ajoute un 3e ou un 4e widget."))
                }
                return .combo(kinds.map { Slot(kind: $0, size: .medium) })
            case 3:
                // The richest widget takes a whole row, the two others share the other row.
                guard let wide = kinds.lastIndex(where: { fits($0, .large) }) ?? kinds.lastIndex(where: { fits($0, .medium) }) else {
                    return .invalid(tr("Pour 3 widgets, l'un d'eux doit exister en moyen."))
                }
                let slots = kinds.enumerated().map { pair in Slot(kind: pair.element, size: pair.offset == wide ? .medium : .small) }
                guard slots.filter({ $0.size == .small }).allSatisfy({ fits($0.kind, .small) }) else {
                    return .invalid(tr("Ces widgets ne tiennent pas ensemble en grand."))
                }
                return .combo(slots)
            case 4:
                guard kinds.allSatisfy({ fits($0, .small) }) else {
                    return .invalid(tr("Pour réunir 4 widgets, chacun doit exister en petit."))
                }
                return .combo(kinds.map { Slot(kind: $0, size: .small) })
            default:
                return .invalid(tr("Un grand widget réunit 4 widgets au plus."))
            }
        }
    }
}
