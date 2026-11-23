import SwiftUI
import WidgetKit

// The widgets inside a widget, in the Studio's « Contenu » and « Disposition » chapters: added with « + », opened
// from the stage or the list, replaced, removed and reordered with `ComboEditing`, each edit one step of the history.

/// What the « Contenu » panel shows.
enum StudioPartsPanel: Equatable {
    /// The size, the widgets inside and what the widget shows.
    case list
    /// One widget inside: replace it, remove it, its settings, what goes well with it.
    case part(Int)
    /// The choice of a widget to add.
    case adding
    /// The choice of a widget to put in the place of this one.
    case replacing(Int)

    /// The widget inside the panel is about (ringed on the stage).
    var partIndex: Int? {
        switch self {
        case let .part(index): return index
        case let .replacing(index): return index
        case .list, .adding: return nil
        }
    }

    /// Changes when the panel shows something else (the settings go back to the top).
    var key: String {
        switch self {
        case .list: return "list"
        case let .part(index): return "part\(index)"
        case .adding: return "adding"
        case let .replacing(index): return "replacing\(index)"
        }
    }
}

/// The note under the stage after an edit of the widgets inside: the size that changed, or why nothing changed.
struct StudioComboNote: Equatable {
    let text: String
    /// Something changed: « Annuler » takes it back.
    let canUndo: Bool
}

/// The rules the Studio shows the widgets inside with. The edits themselves are `ComboEditing`'s (pure, tested).
enum StudioPartRules {
    /// The rows of a combined widget as the indices of its widgets: the same grouping as `ComboLayout.rows`
    /// (a medium widget takes a row, two small ones share one), nil when they don't fill one or two rows.
    static func rowIndices(_ parts: [ComboPart]) -> [[Int]]? {
        var rows: [[Int]] = []
        var waitingSmallRow: Int?
        for (index, part) in parts.enumerated() {
            switch part.size {
            case .medium:
                rows.append([index])
            case .small:
                if let row = waitingSmallRow {
                    rows[row].append(index)
                    waitingSmallRow = nil
                } else {
                    rows.append([index])
                    waitingSmallRow = rows.count - 1
                }
            case .large:
                return nil
            }
        }
        guard waitingSmallRow == nil, (1...2).contains(rows.count) else { return nil }
        return rows
    }

    /// The rows drawn at this size, as `ComboWidgetView` draws them: the first widget in small, the first row in
    /// medium, every row in large.
    static func shownRows(_ parts: [ComboPart], family: WidgetFamily) -> [[Int]] {
        guard !parts.isEmpty else { return [] }
        let rows = rowIndices(parts) ?? [Array(parts.indices.prefix(2))]
        switch family {
        case .systemSmall:
            return [[0]]
        case .systemLarge, .systemExtraLarge:
            return rows
        default:
            return Array(rows.prefix(1))
        }
    }

    /// The widgets that can sit with this one in a widget: its space's, or its catalog category's outside the
    /// spaces (the rule of `Fusion.category`).
    static func candidates(for kind: WidgetKind) -> [WidgetKind] {
        let pool = kind.space.map { SpaceCatalog.kinds(in: $0) } ?? WidgetKind.kinds(in: kind.category)
        return pool.filter { ComboEditing.sameFamily($0, kind) }
    }

    /// « Fitness », or the catalog category of a widget outside the spaces.
    static func groupTitle(for kind: WidgetKind) -> String {
        kind.space?.title ?? kind.category.title
    }

    /// The space's usual widgets (what its creator picks first), shown first in « Va bien avec ».
    static func presets(for kind: WidgetKind) -> [WidgetKind] {
        guard let space = kind.space else { return [] }
        return SpaceCatalog.preset(for: space, format: .large)
            + SpaceCatalog.preset(for: space, format: .medium)
            + SpaceCatalog.preset(for: space, format: .small)
    }

    /// A widget to add, as the space creator starts it (its template's options and name). Its size follows the plan.
    static func newPart(_ kind: WidgetKind) -> ComboPart {
        let made = SpaceCatalog.design(for: kind)
        return ComboPart(kind: kind, options: made.options, name: made.name,
                         size: kind.families.contains(.systemSmall) ? .small : .medium)
    }

    /// Why this widget can't take the place of the widget at `index`, or nil when it can.
    static func refusal(replacing index: Int, with kind: WidgetKind, in parts: [ComboPart]) -> String? {
        // The part « Remplacer » will really put in (its template's options), not a default one.
        if case let .refused(reason) = ComboEditing.replacing(at: index, with: newPart(kind), in: parts) { return reason }
        return nil
    }

    /// Why this widget can't be added to the widgets inside, judged on the part « + » will really add.
    static func refusal(adding kind: WidgetKind, to parts: [ComboPart]) -> String? {
        ComboEditing.refusal(addingPart: newPart(kind), to: parts)
    }

    /// The widgets inside planned again at the size chosen (Petit, Moyen, Grand of a combined widget) with
    /// `Composer`: each keeps its options and name, only its size follows the plan; or why that size can't hold them.
    static func resizing(_ parts: [ComboPart], to format: WidgetFormat) -> ComboEditing.Change {
        let old = ComboEditing.format(of: parts)
        switch Composer.plan(parts.map(\.kind), format: format) {
        case .single:
            guard var part = parts.first, parts.count == 1 else { return .refused(tr("Ces widgets ne tiennent pas ensemble.")) }
            part.size = format
            return .applied(ComboEditing.Outcome(parts: [part], format: format, resizedFrom: format == old ? nil : old))
        case let .combo(slots):
            guard slots.count == parts.count else { return .refused(tr("Ces widgets ne tiennent pas ensemble.")) }
            var planned = parts
            for index in planned.indices { planned[index].size = slots[index].size }
            // In the order drawn, as every outcome of `ComboEditing`.
            planned = ComboEditing.inDisplayOrder(planned)
            let now = ComboEditing.format(of: planned)
            return .applied(ComboEditing.Outcome(parts: planned, format: now, resizedFrom: now == old ? nil : old))
        case let .invalid(reason):
            return .refused(reason)
        }
    }

    /// The note when an edit changed the size. Only a removal does (adding, replacing and moving keep the size the
    /// person chose): a widget left alone, or a large widget that no longer holds as one: « Repassé en Moyen : 2 widgets réunis. »
    static func resizeText(to format: WidgetFormat, count: Int) -> String {
        if count < 2 {
            switch format {
            case .small: return tr("Maintenant en Petit : un seul widget.")
            case .medium: return tr("Maintenant en Moyen : un seul widget.")
            case .large: return tr("Maintenant en Grand : un seul widget.")
            }
        }
        return tr("Repassé en Moyen : \(count) widgets réunis.")
    }

    /// The name of a layout: « Séance du jour en haut », « Prochaine série d'abord »…
    static func planTitle(_ plan: [ComboPart]) -> String {
        guard let first = plan.first else { return "" }
        if plan.count == 3, let wide = plan.first(where: { $0.size == .medium }) {
            return first == wide ? tr("\(wide.name) en haut") : tr("\(wide.name) en bas")
        }
        return tr("\(first.name) d'abord")
    }

    /// The number each widget of a layout has in the widget now (1 for the first), so a plan shows where each goes.
    static func planNumbers(_ plan: [ComboPart], current: [ComboPart]) -> [Int] {
        plan.enumerated().map { pair -> Int in
            let match = current.firstIndex { $0.kind == pair.element.kind && $0.name == pair.element.name && $0.options == pair.element.options }
            return (match ?? pair.offset) + 1
        }
    }
}

// MARK: - The stage

/// Touch zones laid exactly over the widgets of a combined widget on the stage (rows of equal height, cells of
/// equal width, like `ComboWidgetView`); the widget whose settings are open is ringed in the action color, thick.
struct StudioStageZones: View {
    let parts: [ComboPart]
    let family: WidgetFamily
    let selected: Int?
    let onPart: (Int) -> Void

    private struct Zone: Identifiable {
        let index: Int
        let frame: CGRect
        var id: Int { index }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(zones(in: geo.size)) { zone in
                button(zone.index)
                    .frame(width: zone.frame.width, height: zone.frame.height)
                    .position(x: zone.frame.midX, y: zone.frame.midY)
            }
        }
    }

    private func zones(in size: CGSize) -> [Zone] {
        let rows = StudioPartRules.shownRows(parts, family: family)
        guard !rows.isEmpty else { return [] }
        let height = size.height / CGFloat(rows.count)
        var zones: [Zone] = []
        for (rowIndex, row) in rows.enumerated() {
            let width = size.width / CGFloat(max(row.count, 1))
            for (cellIndex, partIndex) in row.enumerated() {
                let frame = CGRect(x: width * CGFloat(cellIndex), y: height * CGFloat(rowIndex), width: width, height: height)
                zones.append(Zone(index: partIndex, frame: frame))
            }
        }
        return zones
    }

    private func button(_ index: Int) -> some View {
        let isSelected = selected == index
        let name = parts.indices.contains(index) ? parts[index].name : ""
        return Button {
            Haptics.tap()
            onPart(index)
        } label: {
            // Clear when not chosen (not hidden: the whole cell stays touchable).
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                .padding(3)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
        .accessibilityHint(Text(tr("Touche une partie du widget pour la changer.")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("stage-part-\(index)")
    }
}

/// Under the stage after an edit of the widgets inside: the size that changed (with « Annuler »), or why nothing changed.
struct StudioComboNoteView: View {
    let note: StudioComboNote
    let onUndo: () -> Void
    let onClose: () -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        HStack(spacing: 8) {
            Image(systemName: note.canUndo ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(note.canUndo ? palette.okColor : Color.accentColor)
                .accessibilityHidden(true)
            Text(note.text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if note.canUndo {
                Button(action: onUndo) {
                    Text(tr("Annuler"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("combo-note-undo")
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(tr("Fermer")))
            .accessibilityIdentifier("combo-note-close")
        }
        .padding(.leading, 14)
        .padding(.vertical, 2)
        .background(note.canUndo ? palette.okColor.opacity(0.14) : palette.tintColor,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("combo-note")
    }
}

// MARK: - Contenu

/// « Dans ce widget · N sur M » (no count when `capacity` is 0): the widgets inside, in order (a touch opens one), and « Ajouter un widget » while
/// there is room. A widget alone is listed too: it is the first widget of a widget to come.
struct StudioPartsList: View {
    let design: WidgetDesign
    let parts: [ComboPart]
    let payload: WidgetPayload
    let capacity: Int
    let canAdd: Bool
    /// Why « + » can't add one now (the size is full), said under it; nil while there is room.
    var addLimit: String?
    let onOpen: (Int) -> Void
    let onAdd: () -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        EditorSection(title: tr("Dans ce widget"), detail: capacity > 0 ? tr("\(parts.count) sur \(capacity)") : nil) {
            VStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { Divider() }
                    row(pair.element, index: pair.offset)
                }
                if canAdd {
                    if !parts.isEmpty { Divider() }
                    addRow
                }
            }
        }
    }

    private func row(_ part: ComboPart, index: Int) -> some View {
        // Each widget as it is drawn inside (small or medium); a widget alone as itself.
        let shown = parts.count > 1 ? design.design(for: part) : design
        let family = part.size.family
        return Button {
            Haptics.tap()
            onOpen(index)
        } label: {
            HStack(spacing: 12) {
                WidgetPreview(design: shown, family: family, payload: payload, width: 40 * family.aspectRatio)
                    .allowsHitTesting(false)
                Text(part.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(verbatim: "\(index + 1)")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.onAccent)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor, in: Circle())
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(part.name))
        .accessibilityValue(Text(verbatim: "\(index + 1)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("part-\(part.kind.rawValue)")
    }

    /// « Ajouter un widget »; when the size is full it stays, faded, with the reason under it (a touch says it too).
    private var addRow: some View {
        let palette = CristalPalette.of(style.id)
        return Button {
            Haptics.tap()
            onAdd()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .background(palette.tintColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(tr("Ajouter un widget"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Spacer(minLength: 0)
                }
                .opacity(addLimit == nil ? 1 : 0.45)
                if let addLimit {
                    Text(addLimit)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minHeight: 56)
            .padding(.vertical, addLimit == nil ? 0 : 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityValue(Text(addLimit ?? ""))
        .accessibilityIdentifier("parts-add")
    }
}

/// « Remplacer » and « Retirer » for the widget inside that is open.
struct StudioPartActions: View {
    let canReplace: Bool
    let canRemove: Bool
    let onReplace: () -> Void
    let onRemove: () -> Void

    var body: some View {
        if canReplace || canRemove {
            HStack(spacing: 10) {
                if canReplace {
                    Button {
                        Haptics.tap()
                        onReplace()
                    } label: {
                        Label(tr("Remplacer"), systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("part-replace")
                }
                if canRemove {
                    Button {
                        Haptics.tap()
                        onRemove()
                    } label: {
                        Label(tr("Retirer"), systemImage: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityIdentifier("part-remove")
                }
            }
        }
    }
}

/// A widget that can join the widget (or take one's place): its live preview in the widget's look, its name,
/// its badges (Interactif, a readable Premium lock), and, when it can't, faded with the reason under it.
struct StudioKindTile: View {
    let kind: WidgetKind
    let design: WidgetDesign
    let payload: WidgetPayload
    let showsLock: Bool
    var refusal: String?
    var isCurrent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetPreview(design: design, family: kind.families.contains(.systemSmall) ? .systemSmall : .systemMedium, payload: payload)
                    .allowsHitTesting(false)
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 3)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if showsLock { lock.padding(4) }
                    }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(kind.title)
                        .font(.caption.weight(isCurrent ? .bold : .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if kind.isInteractive { InteractiveBadge() }
                }
            }
            // Faded when it can't be added, the reason staying readable under it.
            .opacity(refusal == nil ? 1 : 0.4)
            if let refusal {
                Text(refusal)
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .contentShape(Rectangle())
    }

    /// The Premium lock, at a readable size, in its gold badge.
    private var lock: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.premiumInk)
            .frame(width: 24, height: 24)
            .background(Color.premiumFill, in: Circle())
            .accessibilityLabel(Text(tr("Premium")))
    }
}

/// « Va bien avec »: three widgets of the space that can be added now, and the link to all of them.
struct StudioGoesWellWith: View {
    /// The widget being edited: the tiles are drawn in its look.
    let base: WidgetDesign
    let kinds: [WidgetKind]
    let groupTitle: String
    let onAdd: (WidgetKind) -> Void
    let onShowAll: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        EditorSection(title: tr("Va bien avec"), detail: groupTitle) {
            VStack(alignment: .leading, spacing: 12) {
                if !kinds.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), alignment: .leading, spacing: 12) {
                        ForEach(kinds) { kind in
                            tile(kind)
                        }
                    }
                    Divider()
                }
                Button(action: onShowAll) {
                    HStack(spacing: 6) {
                        Text(tr("Tous les widgets de \(groupTitle)"))
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("parts-all")
            }
        }
    }

    private func tile(_ kind: WidgetKind) -> some View {
        let shown = base.design(for: StudioPartRules.newPart(kind))
        let locked = kind.isPremium && !model.isPremium
        return Button {
            Haptics.tap()
            onAdd(kind)
        } label: {
            StudioKindTile(kind: kind, design: shown, payload: model.previewPayload(for: shown), showsLock: locked)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.title))
        .accessibilityValue(Text(locked ? tr("Premium") : ""))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("add-kind-\(kind.rawValue)")
    }
}

/// The choice of a widget to add (or to put in the place of one), in the panel under the stage: the widgets of the
/// same space (or the same category outside the spaces), those that can't be added faded with the reason.
struct StudioKindPicker: View {
    let title: String
    let kinds: [WidgetKind]
    /// The widget being edited: the tiles are drawn in its look.
    let base: WidgetDesign
    /// « Remplacer »: the widget being replaced, ringed in the grid.
    let currentKind: WidgetKind?
    let refusal: (WidgetKind) -> String?
    let identifierPrefix: String
    let onPick: (WidgetKind) -> Void
    let onClose: () -> Void
    @Environment(AppModel.self) private var model
    /// Only the widgets usable without opening the app.
    @State private var onlyInteractive = false

    private var shownKinds: [WidgetKind] {
        kinds.filter { !onlyInteractive || $0.isInteractive || $0 == currentKind }
    }

    var body: some View {
        StudioPanelHeader(title: title, link: StudioPanelLink(title: tr("Fermer"), identifier: "parts-picker-close", action: onClose))
        VStack(alignment: .leading, spacing: 14) {
            if kinds.contains(where: \.isInteractive) {
                Toggle(isOn: $onlyInteractive.animation(.snappy)) {
                    HStack(spacing: 6) {
                        InteractiveBadge()
                        Text(tr("Seulement les widgets interactifs"))
                            .font(.subheadline)
                    }
                }
                .tint(.accentColor)
                .accessibilityIdentifier("parts-interactive-filter")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), alignment: .leading, spacing: 16) {
                ForEach(shownKinds) { kind in
                    tile(kind)
                }
            }
        }
        .card(padding: 14)
    }

    private func tile(_ kind: WidgetKind) -> some View {
        let isCurrent = kind == currentKind
        let reason = isCurrent ? nil : refusal(kind)
        let shown = base.design(for: StudioPartRules.newPart(kind))
        let locked = kind.isPremium && !model.isPremium
        return Button {
            Haptics.tap()
            onPick(kind)
        } label: {
            StudioKindTile(kind: kind, design: shown, payload: model.previewPayload(for: shown), showsLock: locked,
                           refusal: reason, isCurrent: isCurrent)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.title))
        .accessibilityValue(Text(reason ?? (locked ? tr("Premium") : "")))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifierPrefix + kind.rawValue)
    }
}

// MARK: - Ordre

/// The order of the widgets inside (« Monter », « Descendre »), under the name in « Contenu »; shown from two widgets.
/// The layouts proposed (`ComboEditing.arrangements`) are no longer offered, but a saved design keeps its layout.
struct StudioLayoutPanel: View {
    let parts: [ComboPart]
    let onMove: (Int, Int) -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        order
    }

    /// The widgets inside in order, each with « Monter » and « Descendre ».
    private var order: some View {
        EditorSection(title: tr("Ordre")) {
            VStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { Divider() }
                    orderRow(pair.element, index: pair.offset)
                }
            }
        }
    }

    private func orderRow(_ part: ComboPart, index: Int) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(index + 1)")
                .font(.footnote.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.onAccent)
                .frame(width: 26, height: 26)
                .background(Color.accentColor, in: Circle())
            Text(part.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Spacer(minLength: 4)
            moveButton(symbol: "chevron.up", title: tr("Monter"), name: part.name, identifier: "part-up-\(index)", isEnabled: ComboEditing.canMove(from: index, to: index - 1, in: parts)) {
                onMove(index, index - 1)
            }
            moveButton(symbol: "chevron.down", title: tr("Descendre"), name: part.name, identifier: "part-down-\(index)", isEnabled: ComboEditing.canMove(from: index, to: index + 1, in: parts)) {
                onMove(index, index + 1)
            }
        }
        .frame(minHeight: 52)
    }

    private func moveButton(symbol: String, title: String, name: String, identifier: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        let palette = CristalPalette.of(style.id)
        return Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(palette.tintColor, in: Circle())
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(name))
        .accessibilityIdentifier(identifier)
    }
}

/// A layout drawn as a plan: one cell per widget, numbered as in the widget now; a medium widget takes a whole row.
struct StudioPlanThumbnail: View {
    let plan: [ComboPart]
    let numbers: [Int]
    let isCurrent: Bool
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        let rows = StudioPartRules.rowIndices(plan) ?? [Array(plan.indices)]
        let family: WidgetFamily = rows.count > 1 ? .systemLarge : .systemMedium
        VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { pair in
                HStack(spacing: 4) {
                    ForEach(pair.element, id: \.self) { index in
                        cell(index, palette: palette)
                    }
                }
            }
        }
        .padding(5)
        .aspectRatio(family.aspectRatio, contentMode: .fit)
        .background(palette.well2Color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isCurrent ? Color.accentColor : palette.ruleColor, lineWidth: isCurrent ? 3 : 1)
        }
    }

    private func cell(_ index: Int, palette: CristalPalette) -> some View {
        Text(verbatim: "\(numbers.indices.contains(index) ? numbers[index] : index + 1)")
            .font(.footnote.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(isCurrent ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.panelSolidColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
