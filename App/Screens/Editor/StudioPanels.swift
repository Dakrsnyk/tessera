import SwiftUI
import WidgetKit

/// What the Studio's panels share: the example or real data, the size shown, and the widget's content.
struct StudioInput {
    let payload: WidgetPayload
    /// The size used for the small previews in the choice grids.
    let family: WidgetFamily
    /// The widget's content, for the settings that depend on it (lines, chart). Nil for widgets with
    /// their own arrangement (clock, calendar…) and combined widgets.
    let tile: Tile?

    var columns: Int { family == .systemMedium ? 2 : 3 }

    func previewWidth(in width: CGFloat) -> CGFloat {
        let spacing: CGFloat = 10
        return (width - spacing * CGFloat(columns - 1)) / CGFloat(columns) - 6
    }
}

/// A grid of live previews, each the widget with one change.
struct StudioPreviewGrid<Option: Identifiable>: View {
    let options: [Option]
    let input: StudioInput
    let variant: (Option) -> WidgetDesign
    let title: (Option) -> String
    var subtitle: (Option) -> String? = { _ in nil }
    let isSelected: (Option) -> Bool
    var showsLock: (Option) -> Bool = { _ in false }
    var identifier: (Option) -> String
    let select: (Option) -> Void
    @State private var width: CGFloat = 320

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: input.columns), spacing: 14) {
            ForEach(options) { option in
                Button {
                    Haptics.tap()
                    withAnimation(.easeInOut(duration: 0.25)) { select(option) }
                } label: {
                    StudioPreviewTile(
                        design: variant(option), family: input.family, payload: input.payload,
                        title: title(option), subtitle: subtitle(option), isSelected: isSelected(option),
                        showsLock: showsLock(option), width: input.previewWidth(in: width)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(title(option)))
                .accessibilityAddTraits(isSelected(option) ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(identifier(option))
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

// MARK: - Contenu

/// What the widget shows: each part and each line can be hidden, and lines colored.
struct StudioElementsPanel: View {
    @Binding var design: WidgetDesign
    let tile: Tile?

    var body: some View {
        StudioGroup(title: "Éléments affichés") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Titre", isOn: $design.showsTitle)
                if let tile {
                    Toggle("Icône", isOn: shown("icon"))
                    if !tile.value.isEmpty || tile.timer != nil { Toggle("Valeur principale", isOn: shown("value")) }
                    if tile.caption != nil { Toggle("Légende", isOn: shown("caption")) }
                    if tile.detail != nil { Toggle("Détails", isOn: $design.showsDetails) }
                    if tile.visual != TileVisual.none { Toggle("Graphique", isOn: shown("visual")) }
                    if !tile.buttons.isEmpty || tile.headerButton != nil { Toggle("Boutons", isOn: shown("buttons")) }
                    if tile.footnote != nil { Toggle("Source", isOn: shown("footnote")) }
                    if !tile.rows.isEmpty { Toggle("Lignes", isOn: shown("rows")) }
                } else {
                    Toggle("Détails", isOn: $design.showsDetails)
                }
            }
            .font(.subheadline)
        }
        if let tile {
            let lines = tile.rows.filter { UUID(uuidString: $0.id) == nil }
            if !lines.isEmpty && !design.style.isHidden("rows") {
                StudioGroup(title: "Lignes", detail: "\(lines.count)") {
                    VStack(spacing: 10) {
                        ForEach(lines) { row in
                            line(id: row.id, key: "row:\(row.id)", title: row.title, colorHex: shownColor(of: row, in: tile.rows), colored: row.colorHex != nil || row.progress != nil)
                        }
                    }
                }
            }
            if case let .segments(segments) = tile.visual, !segments.isEmpty {
                StudioGroup(title: "Répartition", detail: "\(segments.count)") {
                    VStack(spacing: 10) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { pair in
                            let segment = pair.element
                            let series = ResolvedStyle(design: design)
                            line(id: "seg:\(segment.label)", key: "seg:\(segment.label)", title: segment.label,
                                 colorHex: series.series.isEmpty ? segment.colorHex : series.seriesColor(at: pair.offset), colored: true)
                        }
                    }
                }
            }
        }
    }

    private func line(id: String, key: String, title: String, colorHex: String?, colored: Bool) -> some View {
        let colorKey = key.hasPrefix("row:") ? String(key.dropFirst(4)) : key
        return HStack(spacing: 10) {
            Toggle(isOn: shown(key)) {
                Text(title).font(.subheadline).lineLimit(1)
            }
            if colored {
                ColorPicker("Couleur de \(title)", selection: Binding(
                    get: { Color(hex: design.style.rowColors[colorKey] ?? colorHex ?? design.accentHex) },
                    set: { design.style.rowColors[colorKey] = $0.hexString }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(width: 34)
            }
        }
    }

    /// The color a line is drawn in: its own, or the palette's (or main color's) when they color the lines.
    private func shownColor(of row: TileRow, in lines: [TileRow]) -> String? {
        guard row.colorHex != nil else { return nil }
        let style = ResolvedStyle(design: design)
        guard !style.series.isEmpty else { return row.colorHex }
        let colored = lines.filter { $0.colorHex != nil }
        return style.seriesColor(at: colored.firstIndex { $0.id == row.id } ?? 0)
    }

    /// A toggle that is on while the part is shown.
    private func shown(_ part: String) -> Binding<Bool> {
        Binding(
            get: { !design.style.hidden.contains(part) },
            set: { isOn in
                if isOn { design.style.hidden.remove(part) } else { design.style.hidden.insert(part) }
            }
        )
    }
}

// MARK: - Thème & style

/// Complete themes (every setting at once) and styles (the composition), in one section.
struct StudioLookPanel: View {
    @Binding var design: WidgetDesign
    let input: StudioInput
    @Environment(AppModel.self) private var model
    @State private var tab: LookTab = .themes

    enum LookTab: String, CaseIterable, Identifiable {
        case themes, styles
        var id: String { rawValue }
        var title: String { self == .themes ? "Thèmes" : "Styles" }
    }

    var body: some View {
        Picker("Thème ou style", selection: $tab) {
            ForEach(LookTab.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("look-tabs")
        switch tab {
        case .themes:
            StudioNote(text: "Un thème règle tout d'un coup : style, couleurs, fond et bordure. Ensuite, la couleur principale ou une palette (Couleurs) repeint tout le widget.", symbol: "sparkles")
            StudioPreviewGrid(
                options: StylePreset.all,
                input: input,
                variant: { $0.applied(to: design) },
                title: \.name,
                subtitle: { $0.summary },
                isSelected: { preset in
                    let applied = preset.applied(to: design)
                    return applied.themeID == design.themeID && applied.accentHex == design.accentHex
                        && applied.background == design.background && applied.style.look == design.style.look
                },
                showsLock: { $0.isPremium && !model.isPremium },
                identifier: { "preset-\($0.id)" },
                select: { design = $0.applied(to: design) }
            )
        case .styles:
            StudioNote(text: "Un style change l'apparence et la composition : disposition, formes, texte, icônes, ombre. Tes couleurs restent.", symbol: "swatchpalette")
            StudioPreviewGrid(
                options: ThemeCatalog.all,
                input: input,
                variant: { theme in
                    var copy = design
                    copy.themeID = theme.id
                    return copy
                },
                title: \.name,
                subtitle: { $0.isPremium ? nil : "Gratuit" },
                isSelected: { $0.id == design.themeID },
                showsLock: { $0.isPremium && !model.isPremium },
                identifier: { "theme-\($0.id.rawValue)" },
                select: { design.themeID = $0.id }
            )
        }
        Button {
            withAnimation {
                let hidden = design.style.hidden
                design.style = StyleOptions()
                design.style.hidden = hidden
            }
        } label: {
            Label("Revenir aux réglages du style", systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(design.style.look.isDefault)
    }
}

// MARK: - Couleurs

struct StudioColorsPanel: View {
    @Binding var design: WidgetDesign
    let input: StudioInput
    @Environment(AppModel.self) private var model

    private var style: ResolvedStyle { ResolvedStyle(design: design) }

    /// Whether the colors are the style's own (no main color, palette or color picked one by one).
    private var usesStyleColors: Bool {
        let s = design.style
        return !s.recolor && s.seriesHexes.isEmpty && s.panelHex == nil && s.textHex == nil && s.secondaryHex == nil
            && s.numberHex == nil && s.iconHex == nil && s.chartHex == nil && s.rowColors.isEmpty
    }

    /// What colors the widget now: the main color, a palette, colors picked one by one, or the style.
    private var colorsDetail: String {
        if design.style.recolor { return Palette.name(for: design.accentHex) }
        if let palette = ColorPalette.all.first(where: { $0.matches(design) }) { return "Palette \(palette.name)" }
        return usesStyleColors ? "Couleurs du style" : "Personnalisées"
    }

    var body: some View {
        StudioGroup(title: "Couleur principale", detail: colorsDetail) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Elle repeint tout le widget : fond, cartes, texte, chiffres, icônes, graphiques et bordure.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                    ForEach(Palette.freeAccents) { swatch in
                        ColorDot(hex: swatch.hex, isSelected: design.style.recolor && design.accentHex == swatch.hex) {
                            design = design.recolored(to: swatch.hex)
                            Haptics.tap()
                        }
                        .accessibilityLabel(Text(swatch.name))
                        .accessibilityIdentifier("main-\(swatch.hex)")
                    }
                    ColorPicker("Couleur personnalisée", selection: Binding(
                        get: { Color(hex: design.accentHex) },
                        set: { design = design.recolored(to: $0.hexString) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(minWidth: 44, minHeight: 44)
                }
                if !usesStyleColors {
                    Button {
                        Haptics.tap()
                        withAnimation { design = design.withStyleColors() }
                    } label: {
                        Label("Revenir aux couleurs du style", systemImage: "arrow.uturn.backward")
                            .font(.subheadline.weight(.medium))
                    }
                    .accessibilityIdentifier("colors-reset")
                }
            }
        }
        StudioGroup(title: "Palettes", detail: "Tout change d'un coup", isPremium: !model.isPremium) {
            FlowLayout(spacing: 8) {
                ForEach(ColorPalette.all) { palette in
                    let isOn = palette.matches(design)
                    Button {
                        Haptics.tap()
                        withAnimation { design = palette.applied(to: design) }
                    } label: {
                        HStack(spacing: 6) {
                            HStack(spacing: -4) {
                                ForEach(Array(palette.swatches.enumerated()), id: \.offset) { _, hex in
                                    Circle().fill(Color(hex: hex)).frame(width: 14, height: 14)
                                        .overlay { Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1) }
                                }
                            }
                            Text(palette.name)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 36)
                        .background(isOn ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(.screenFill), in: Capsule())
                        .overlay { Capsule().strokeBorder(isOn ? Color.accentColor : .clear, lineWidth: 1.5) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("palette-\(palette.id)")
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        StudioGroup(title: "Chaque couleur", isPremium: !model.isPremium) {
            VStack(spacing: 6) {
                StudioColorRow(title: "Texte", hex: $design.style.textHex, fallback: style.primary)
                Divider()
                StudioColorRow(title: "Texte secondaire", hex: $design.style.secondaryHex, fallback: style.secondary)
                Divider()
                StudioColorRow(title: "Chiffres", hex: $design.style.numberHex, fallback: style.numberColor)
                Divider()
                StudioColorRow(title: "Icônes", hex: $design.style.iconHex, fallback: style.icon)
                Divider()
                StudioColorRow(title: "Graphiques", hex: $design.style.chartHex, fallback: style.chart)
                Divider()
                StudioColorRow(title: "Cartes et surfaces", hex: $design.style.panelHex, fallback: style.panel)
            }
        }
        StudioGroup(title: "Hausse et baisse", isPremium: !model.isPremium) {
            VStack(spacing: 6) {
                StudioColorRow(title: "Positif", hex: $design.style.positiveHex, fallback: style.positive, detail: "Gains, progression")
                Divider()
                StudioColorRow(title: "Négatif", hex: $design.style.negativeHex, fallback: style.negative, detail: "Pertes, dépassement")
            }
        }
        if input.tile.map({ !$0.rows.isEmpty }) == true {
            StudioNote(text: "La couleur de chaque ligne (protéines, glucides, catégories…) se règle aussi dans Contenu.")
        }
    }
}

// MARK: - Bordure

struct StudioBorderPanel: View {
    @Binding var design: WidgetDesign
    @Environment(AppModel.self) private var model

    var body: some View {
        StudioGroup(title: "Bordure", isPremium: !model.isPremium) {
            VStack(alignment: .leading, spacing: 14) {
                StudioChoices(options: BorderKind.allCases, selection: $design.style.border, title: \.title, identifier: { "border-\($0.rawValue)" })
                if design.effectiveStyle.border != .none {
                    StudioSlider(title: "Épaisseur", value: $design.style.borderWidth, range: 0.5...6, step: 0.5, format: { String(format: "%.1f pt", $0) })
                    StudioSlider(title: "Opacité", value: $design.style.borderOpacity, range: 0.1...1)
                    StudioColorRow(title: "Couleur", hex: $design.style.borderHex, fallback: ResolvedStyle(design: design).borderColor)
                }
            }
        }
        StudioNote(text: "La bordure suit exactement le contour du widget, que iOS dessine lui-même.")
    }
}

// MARK: - Graphique

struct StudioChartPanel: View {
    @Binding var design: WidgetDesign
    let input: StudioInput
    @Environment(AppModel.self) private var model

    private var family: ChartFamily { input.tile?.visual.chartFamily ?? .none }

    var body: some View {
        if family != .none {
            StudioPreviewGrid(
                options: ChartKind.options(for: family),
                input: input,
                variant: { kind in
                    var copy = design
                    copy.style.chart = kind
                    return copy
                },
                title: \.title,
                isSelected: { $0 == design.effectiveStyle.chart },
                identifier: { "chart-\($0.rawValue)" },
                select: { design.style.chart = $0 }
            )
        }
        StudioGroup(title: "Apparence du graphique") {
            VStack(spacing: 12) {
                StudioSlider(title: "Épaisseur", value: $design.style.chartThickness, range: 0.5...2.5, step: 0.1, format: { String(format: "×%.1f", $0) })
                Toggle("Remplissage", isOn: $design.style.chartFill)
                Toggle("Afficher les valeurs", isOn: $design.style.chartValues)
                StudioColorRow(title: "Couleur", hex: $design.style.chartHex, fallback: ResolvedStyle(design: design).chart)
            }
            .font(.subheadline)
        }
    }
}

// MARK: - Densité

struct StudioDensityPanel: View {
    @Binding var design: WidgetDesign
    let input: StudioInput

    var body: some View {
        StudioPreviewGrid(
            options: Density.allCases,
            input: input,
            variant: { density in
                var copy = design
                copy.style.density = density
                return copy
            },
            title: \.title,
            subtitle: { _ in nil },
            isSelected: { $0 == design.effectiveStyle.density },
            identifier: { "density-\($0.rawValue)" },
            select: { design.style.density = $0 }
        )
        StudioNote(text: design.effectiveStyle.density.summary + " Les marges, l'espacement et le nombre de lignes s'adaptent.")
    }
}

// MARK: - Mes styles

struct StudioMyStylesPanel: View {
    @Binding var design: WidgetDesign
    let input: StudioInput
    @Environment(AppModel.self) private var model
    @State private var newName = ""
    @State private var applying: SavedStyle?
    @State private var renaming: SavedStyle?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .sheet(item: $applying) { style in
            ApplyStyleSheet(style: style)
        }
        .alert("Renommer le style", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nom", text: $renameText)
            Button("Annuler", role: .cancel) { renaming = nil }
            Button("Renommer") {
                if let renaming { model.renameStyle(renaming.id, to: renameText) }
                renaming = nil
            }
        }
    }

    @ViewBuilder private var content: some View {
        StudioGroup(title: "Enregistrer ce look") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Garde les couleurs, le fond, la bordure, le texte, les icônes et la disposition de ce widget sous un nom, pour les donner à d'autres widgets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("Mon thème", text: $newName)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(10)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("style-name")
                    Button {
                        Haptics.success()
                        model.saveStyle(named: newName, from: design)
                        newName = ""
                    } label: {
                        Text("Enregistrer").foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("style-save")
                }
            }
        }
        if model.savedStyles.isEmpty {
            StudioNote(text: "Tes styles apparaîtront ici. Un même style sur la météo, la nutrition et le budget donne un écran d'accueil cohérent.", symbol: "bookmark")
        } else {
            StudioGroup(title: "Mes styles", detail: "\(model.savedStyles.count)") {
                VStack(spacing: 0) {
                    ForEach(Array(model.savedStyles.enumerated()), id: \.element.id) { index, saved in
                        savedRow(saved)
                        if index < model.savedStyles.count - 1 { Divider().padding(.vertical, 8) }
                    }
                }
            }
        }
    }

    private func savedRow(_ saved: SavedStyle) -> some View {
        let preview = saved.applied(to: design)
        let isApplied = saved.matches(design)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                WidgetPreview(design: preview, family: input.family, payload: input.payload, width: input.family == .systemMedium ? 110 : 64)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 3) {
                    Text(saved.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text("\(ThemeCatalog.theme(saved.themeID).name) · \(saved.style.look.isDefault ? "réglages du style" : "personnalisé")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Renommer", systemImage: "pencil") {
                        renameText = saved.name
                        renaming = saved
                    }
                    Button("Supprimer", systemImage: "trash", role: .destructive) {
                        withAnimation { model.deleteStyle(saved.id) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Options de \(saved.name)"))
            }
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    withAnimation { design = saved.applied(to: design) }
                } label: {
                    Label(isApplied ? "Appliqué" : "Appliquer", systemImage: isApplied ? "checkmark" : "paintbrush")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isApplied)
                .accessibilityIdentifier("style-apply-\(saved.name)")
                if !model.designs.isEmpty {
                    Button {
                        applying = saved
                    } label: {
                        Label("Autres widgets", systemImage: "square.stack")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.subheadline.weight(.medium))
        }
    }
}

/// Gives a saved look to several saved widgets at once: their content stays, only the look changes.
struct ApplyStyleSheet: View {
    let style: SavedStyle
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.designs) { design in
                        Button {
                            if selection.contains(design.id) { selection.remove(design.id) } else { selection.insert(design.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selection.contains(design.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selection.contains(design.id) ? Color.accentColor : .secondary)
                                let family = design.displayFormat.family
                                WidgetPreview(design: style.applied(to: design), family: family, payload: model.previewPayload(for: design), width: family == .systemSmall ? 52 : 100)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(design.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                    Text(design.kindTitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Le contenu de chaque widget ne change pas : seuls les couleurs, le fond, la bordure, le texte, les icônes et la disposition changent. Une photo de fond est gardée.")
                }
            }
            .navigationTitle("Appliquer « \(style.name) »")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer (\(selection.count))") {
                        let count = model.apply(style, to: selection)
                        if count > 0 { Haptics.success() }
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
}
