import PhotosUI
import SwiftUI
import WidgetKit

/// The Studio in its own sheet: a saved widget from « Mes widgets », or a new one from the Store.
struct EditorView: View {
    let request: EditorRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WidgetStudio(request: request, isPushed: false) { dismiss() }
        }
    }
}

/// Photos imported while editing. Those the saved widgets don't use are deleted once the Studio is gone
/// for good (not when a page is pushed over it, nor when a change is undone).
final class StudioPhotoSession {
    var imported: [String] = []
    var kept: Set<String> = []

    deinit {
        for name in imported where !kept.contains(name) {
            ImageStore.delete(named: name)
        }
    }
}

/// The Widget Studio: every widget is made and changed here, whether it comes from « Créer », the Store,
/// a pack or « Mes widgets ». Several widgets made together are edited one after the other and can
/// share their look. Every change can be undone and redone.
struct WidgetStudio: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    /// Pushed inside another flow (a creation, a pack): its back button returns to the selection.
    let isPushed: Bool
    /// Closes the Studio, and the flow that opened it, once the widgets are saved or the edit dropped.
    let onClose: () -> Void

    @State private var designs: [WidgetDesign]
    @State private var index = 0
    @State private var family: WidgetFamily
    @State private var showsPaywall = false
    @State private var confirmDiscard = false
    @State private var confirmDelete = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var backgroundTab: BackgroundKind
    @State private var previewFrame: CGRect = .zero
    @State private var section: StudioSection
    /// Widgets made together wear the same look while this is on: a change to one goes to all.
    @State private var sharesLook: Bool
    // Undo and redo: the widgets as they were before each change, and after each undo.
    @State private var past: [[WidgetDesign]] = []
    @State private var future: [[WidgetDesign]] = []
    @State private var lastChange = Date.distantPast
    @State private var restored: [WidgetDesign]?
    @State private var photos = StudioPhotoSession()

    private let isNew: Bool
    private let originals: [WidgetDesign]

    init(request: EditorRequest, isPushed: Bool, onClose: @escaping () -> Void) {
        let designs = request.designs
        _designs = State(initialValue: designs)
        _family = State(initialValue: request.design.displayFormat.family)
        _backgroundTab = State(initialValue: BackgroundKind(request.design.background))
        _section = State(initialValue: request.section.flatMap(StudioSection.init(name:)) ?? .content)
        _sharesLook = State(initialValue: designs.count > 1 && designs.dropFirst().allSatisfy { $0.withLook(of: designs[0]) == $0 })
        isNew = request.isNew
        originals = designs
        self.isPushed = isPushed
        self.onClose = onClose
    }

    private var design: WidgetDesign { designs[index] }
    private var edited: Binding<WidgetDesign> { $designs[index] }
    private var hasChanges: Bool { isNew || designs != originals }
    private var needsPremium: Bool { !model.isPremium && designs.contains(where: \.usesPremiumFeatures) }
    private var exceedsFreeLimit: Bool {
        isNew && !model.isPremium && model.designs.count + designs.count > AppModel.freeDesignLimit
    }

    private var title: String {
        if !isNew { return "Studio" }
        return designs.count > 1 ? "Nouveaux widgets" : "Nouveau widget"
    }

    var body: some View {
        let input = studioInput
        let sections = Self.sections(for: input)
        VStack(spacing: 0) {
            // Always in view: every change shows at once.
            StudioStage(design: design, family: $family, payload: payload, isExample: !model.hasOwnData(for: design))
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
            if designs.count > 1 { widgetSwitcher }
            StudioSectionBar(sections: sections, selection: $section)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if needsPremium { premiumNotice }
                    sectionContent(input)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .id("\(section.rawValue)-\(index)")
            .scrollDismissesKeyboard(.interactively)
            .screenshotScroll()
        }
        .background(.screenFill)
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .confirmationDialog("Abandonner les modifications ?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Abandonner", role: .destructive) { onClose() }
        }
        .confirmationDialog("Supprimer ce widget ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                // The saved version: its own photo goes with it.
                model.delete(originals.first { $0.id == design.id } ?? design)
                onClose()
            }
        } message: {
            Text("Les widgets qui l'affichent reviendront au modèle par défaut.")
        }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
        .task(id: design.kind) { await model.prepare(design) }
        .task(id: design.options.coinID) { if design.kind == .crypto { await model.prepare(design) } }
        .task {
            for other in designs.dropFirst() { await model.prepare(other) }
        }
        .onChange(of: photoItem) { _, item in importPhoto(item) }
        .onChange(of: designs) { old, new in record(from: old, to: new) }
        .onChange(of: design.background) { _, background in backgroundTab = BackgroundKind(background) }
        .onChange(of: index) { _, _ in
            family = design.displayFormat.family
            backgroundTab = BackgroundKind(design.background)
        }
        .onChange(of: sections) { _, shown in
            if !shown.contains(section) { section = .content }
        }
        .onChange(of: sharesLook) { _, shares in
            guard shares else { return }
            let lead = design
            withAnimation { designs = designs.map { $0.id == lead.id ? $0 : $0.withLook(of: lead) } }
        }
        .interactiveDismissDisabled(hasChanges && !isNew)
    }

    /// « Graphique » only for widgets that draw one.
    private static func sections(for input: StudioInput) -> [StudioSection] {
        let chart: ChartFamily = input.tile?.visual.chartFamily ?? ChartFamily.none
        return StudioSection.allCases.filter { $0 != .chart || chart != ChartFamily.none }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if !isPushed {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") {
                    if hasChanges && !isNew { confirmDiscard = true } else { onClose() }
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(past.isEmpty)
            .accessibilityLabel(Text("Retour en arrière"))
            .accessibilityIdentifier("studio-undo")
            Button(action: redo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(future.isEmpty)
            .accessibilityLabel(Text("Retour en avant"))
            .accessibilityIdentifier("studio-redo")
        }
    }

    /// Widgets made together: which one is being edited, and whether they share their look.
    private var widgetSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(designs.enumerated()), id: \.element.id) { pair in
                    FilterChip(title: "\(pair.offset + 1) · \(pair.element.name)", isSelected: pair.offset == index) {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { index = pair.offset }
                    }
                    .accessibilityIdentifier("studio-widget-\(pair.offset + 1)")
                    .accessibilityLabel(Text("Widget \(pair.offset + 1) sur \(designs.count) : \(pair.element.name)"))
                }
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1, height: 24)
                FilterChip(title: "Même style", symbol: sharesLook ? "link" : "link.badge.plus", isSelected: sharesLook) {
                    Haptics.tap()
                    sharesLook.toggle()
                }
                .accessibilityIdentifier("studio-share-look")
                .accessibilityHint(Text("Le thème, les couleurs, le fond et la bordure vont à tous les widgets"))
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    // MARK: Studio

    private var payload: WidgetPayload { model.previewPayload(for: design) }

    /// The size used for the small previews: the one shown, or the widget's own on the Lock Screen.
    private var gridFamily: WidgetFamily {
        family.isAccessory ? design.displayFormat.family : family
    }

    private var studioInput: StudioInput {
        let payload = self.payload
        var tile: Tile?
        if design.kind.usesTileLayout && !design.isCombo {
            let context = RenderContext(design: design, style: ResolvedStyle(design: design), family: gridFamily, date: Date(), payload: payload, isInteractive: false)
            let made = TileFactory.make(context)
            tile = made.empty == nil ? made : nil
        }
        return StudioInput(payload: payload, family: gridFamily, tile: tile)
    }

    @ViewBuilder private func sectionContent(_ input: StudioInput) -> some View {
        switch section {
        case .content:
            if !model.hasOwnData(for: design) && !design.dataItems.isEmpty {
                Text("Aperçu avec des données d'exemple. Renseigne tes données ci-dessous : ton widget affichera les tiennes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            nameSection
            // What the widget needs from the person, asked here and shared with every widget.
            if !design.dataItems.isEmpty {
                WidgetDataSection(items: design.dataItems)
            }
            // A combined widget keeps the options of each widget inside it, set one by one.
            if design.isCombo {
                comboPartsSection
            } else {
                KindOptionsSection(design: edited)
            }
            StudioElementsPanel(design: edited, tile: input.tile)
            if !isNew && designs.count == 1 { deleteButton }
        case .style:
            StudioLookPanel(design: edited, input: input)
        case .colors:
            StudioColorsPanel(design: edited, input: input)
        case .background:
            backgroundSection
            textureSection
            StudioNote(text: "iOS ne laisse pas un widget montrer le fond d'écran à travers lui : une vraie transparence n'est pas possible. Tessera propose le Verre (givre et reflets dessinés), les dégradés doux et ta photo. Les apparences « Teinté » ou transparentes d'iOS (Personnaliser l'écran d'accueil) s'appliquent aussi aux widgets Tessera.")
        case .border:
            StudioBorderPanel(design: edited)
        case .chart:
            StudioChartPanel(design: edited, input: input)
        case .density:
            StudioDensityPanel(design: edited, input: input)
        case .myStyles:
            StudioMyStylesPanel(design: edited, input: input)
        }
    }

    // MARK: Sections

    private var premiumNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.premiumInk)
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Ce widget utilise Premium")
                    .font(.subheadline.weight(.semibold))
                Text(design.premiumFeatures.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { showsPaywall = true } label: {
                Text("Débloquer").foregroundStyle(.onAccent)
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(14)
        .background(Color.premiumFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var nameSection: some View {
        EditorSection(title: "Nom") {
            TextField("Nom du widget", text: edited.name)
                .accessibilityIdentifier("widget-name")
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(12)
                .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var backgroundSection: some View {
        EditorSection(title: "Fond", isPremium: !model.isPremium) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Fond", selection: $backgroundTab) {
                    Text("Style").tag(BackgroundKind.theme)
                    Text("Couleur").tag(BackgroundKind.color)
                    Text("Dégradé").tag(BackgroundKind.gradient)
                    Text("Verre").tag(BackgroundKind.glass)
                    Text("Photo").tag(BackgroundKind.photo)
                }
                .pickerStyle(.segmented)
                .onChange(of: backgroundTab) { _, tab in
                    switch tab {
                    case .theme: designs[index].background = .theme
                    case .color:
                        if case .color = design.background {} else { designs[index].background = .color(Palette.backgrounds[0].hex) }
                    case .gradient: designs[index].background = .gradient
                    case .glass: designs[index].background = .glass
                    case .photo: break
                    }
                }

                switch backgroundTab {
                case .color:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(Palette.backgrounds) { swatch in
                            ColorDot(hex: swatch.hex, isSelected: design.background == .color(swatch.hex), size: 40) {
                                designs[index].background = .color(swatch.hex)
                            }
                            .accessibilityLabel(Text(swatch.name))
                        }
                    }
                    ColorPicker("Autre couleur", selection: Binding(
                        get: {
                            if case let .color(hex) = design.background { return Color(hex: hex) }
                            return Color(hex: Palette.backgrounds[0].hex)
                        },
                        set: { designs[index].background = .color($0.hexString) }
                    ), supportsOpacity: false)
                    .font(.subheadline)
                case .gradient:
                    gradientSettings
                case .glass:
                    Text("Du verre dépoli teinté de la couleur principale, avec ses reflets. Change la couleur principale pour le teinter.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .theme:
                    Text("Le fond du style choisi, clair ou sombre selon le style.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .photo:
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text(BackgroundKind(design.background) == .photo ? "Changer de photo" : "Choisir une photo")
                            Spacer()
                            if isImportingPhoto { ProgressView() }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(12)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    if case .photo = design.background {
                        StudioSlider(title: "Voile pour la lisibilité", value: Binding(
                            get: { design.style.veil ?? 0.28 },
                            set: { designs[index].style.veil = $0 }
                        ), range: 0...0.75)
                    }
                    StudioNote(text: "La photo est réduite pour tenir dans la mémoire limitée des widgets.")
                }
            }
        }
    }

    /// Automatic (from the main color) or the person's own: two colors, a direction and an intensity.
    @ViewBuilder private var gradientSettings: some View {
        Toggle("Mon propre dégradé", isOn: Binding(
            get: { design.style.gradient != nil },
            set: { isOn in
                designs[index].style.gradient = isOn
                    ? GradientSpec(startHex: ColorMath.shade(design.accentHex, 0.18), endHex: ColorMath.shade(design.accentHex, -0.45))
                    : nil
            }
        ))
        .font(.subheadline)
        if let spec = design.style.gradient {
            HStack(spacing: 16) {
                ColorPicker("Couleur 1", selection: Binding(
                    get: { Color(hex: spec.startHex) },
                    set: { designs[index].style.gradient?.startHex = $0.hexString }
                ), supportsOpacity: false)
                ColorPicker("Couleur 2", selection: Binding(
                    get: { Color(hex: spec.endHex) },
                    set: { designs[index].style.gradient?.endHex = $0.hexString }
                ), supportsOpacity: false)
            }
            .font(.subheadline)
            StudioChoices(
                options: GradientDirection.allCases,
                selection: Binding(get: { spec.direction }, set: { designs[index].style.gradient?.direction = $0 }),
                title: \.title,
                symbol: { $0.symbol }
            )
            StudioSlider(title: "Intensité", value: Binding(
                get: { spec.intensity },
                set: { designs[index].style.gradient?.intensity = $0 }
            ), range: 0.1...1)
            FlowLayout(spacing: 8) {
                ForEach(Array(Self.gradientIdeas.enumerated()), id: \.offset) { _, idea in
                    Button {
                        withAnimation { designs[index].style.gradient = GradientSpec(startHex: idea.0, endHex: idea.1, direction: spec.direction, intensity: 1) }
                    } label: {
                        LinearGradient(colors: [Color(hex: idea.0), Color(hex: idea.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: 44, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Dégradé"))
                }
            }
        } else {
            Text("Le dégradé suit la couleur principale.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static let gradientIdeas: [(String, String)] = [
        ("FF9A62", "8E3BA8"), ("0B8FAC", "063A6B"), ("1B2250", "05060F"), ("F6D365", "FDA085"),
        ("84FAB0", "8FD3F4"), ("A18CD1", "FBC2EB"), ("434343", "000000"), ("F5F7FA", "C3CFE2"),
        ("FF5F6D", "FFC371"), ("11998E", "38EF7D"),
    ]

    private var textureSection: some View {
        EditorSection(title: "Texture", isPremium: !model.isPremium) {
            VStack(alignment: .leading, spacing: 12) {
                StudioChoices(options: TextureKind.allCases, selection: edited.style.texture, title: \.title, identifier: { "texture-\($0.rawValue)" })
                if design.effectiveStyle.texture != .none {
                    StudioSlider(title: "Intensité", value: edited.style.textureOpacity, range: 0.1...1)
                }
            }
        }
    }

    /// The widgets inside a combined widget: each keeps its own name and options.
    private var comboPartsSection: some View {
        EditorSection(title: "Widgets réunis", detail: "Règle chacun") {
            VStack(spacing: 0) {
                ForEach(Array(design.options.parts.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { Divider() }
                    NavigationLink {
                        ComboPartSettingsView(design: edited, index: pair.offset)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: pair.element.kind.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pair.element.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                                Text(pair.element.kind.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Régler")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("part-\(pair.element.kind.rawValue)")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label("Supprimer ce widget", systemImage: "trash")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: save) {
                Text(saveTitle)
                    .font(.headline)
                    .foregroundStyle(hasChanges ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .disabled(!hasChanges)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var saveTitle: String {
        if needsPremium { return "Débloquer et enregistrer" }
        if !isNew { return "Enregistrer" }
        return designs.count > 1 ? "Enregistrer les \(designs.count) widgets" : "Enregistrer le widget"
    }

    // MARK: Undo and redo

    /// Keeps what the widgets were before a change. A slider being dragged or a name being typed
    /// counts as one change. Widgets that share their look get the change too.
    private func record(from old: [WidgetDesign], to new: [WidgetDesign]) {
        if let restored, restored == new {
            self.restored = nil
            return
        }
        if sharesLook && new.count > 1 && new.indices.contains(index) {
            let lead = new[index]
            let synced = new.map { $0.id == lead.id ? $0 : $0.withLook(of: lead) }
            if synced != new { designs = synced }
        }
        let now = Date()
        if now.timeIntervalSince(lastChange) > 0.6 {
            past.append(old)
            if past.count > 80 { past.removeFirst() }
        }
        lastChange = now
        future.removeAll()
    }

    private func undo() {
        guard let previous = past.popLast() else { return }
        future.append(designs)
        restore(previous)
    }

    private func redo() {
        guard let next = future.popLast() else { return }
        past.append(designs)
        restore(next)
    }

    private func restore(_ value: [WidgetDesign]) {
        Haptics.tap()
        // The next change is a new step, however soon it comes.
        lastChange = .distantPast
        guard value != designs else { return }
        restored = value
        withAnimation(.easeInOut(duration: 0.2)) { designs = value }
    }

    // MARK: Actions

    private func save() {
        if needsPremium || (isNew && !model.canCreateDesign) || exceedsFreeLimit {
            showsPaywall = true
            return
        }
        var saved = designs
        if isNew {
            let added = model.install(designs: designs)
            saved = Array(designs.prefix(added))
            // The new widgets glide into « Mes widgets » as the Studio closes.
            router.saveFlight = SaveFlight(designs: saved, source: previewFrame)
            if !isPushed && designs.count == 1 {
                router.lastSavedName = design.name
                router.showsAddGuideAfterEditor = true
            }
        } else {
            for design in designs { model.save(design) }
        }
        photos.kept.formUnion(saved.compactMap(\.photoName))
        Haptics.success()
        onClose()
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isImportingPhoto = true
        let target = index
        Task {
            defer {
                isImportingPhoto = false
                photoItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let name = ImageStore.save(image) else { return }
            photos.imported.append(name)
            if designs.indices.contains(target) { designs[target].background = .photo(name) }
        }
    }
}

/// One widget inside a combined widget: its name and options, with its preview in the combined look.
struct ComboPartSettingsView: View {
    @Binding var design: WidgetDesign
    let index: Int
    @Environment(AppModel.self) private var model

    private var part: Binding<WidgetDesign> {
        Binding(
            get: {
                let parts = design.options.parts
                return parts.indices.contains(index) ? design.design(for: parts[index]) : design
            },
            set: { updated in
                guard design.options.parts.indices.contains(index) else { return }
                design.options.parts[index].name = updated.name
                var options = updated.options
                options.parts = []
                design.options.parts[index].options = options
            }
        )
    }

    var body: some View {
        let shown = part.wrappedValue
        let family: WidgetFamily = shown.kind.families.contains(.systemSmall) ? .systemSmall : .systemMedium
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                WidgetPreview(design: shown, family: family, payload: model.previewPayload(for: shown), width: family == .systemSmall ? 170 : 330)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                EditorSection(title: "Nom") {
                    TextField("Nom du widget", text: part.name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .padding(12)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if !shown.dataItems.isEmpty {
                    WidgetDataSection(items: shown.dataItems)
                }
                KindOptionsSection(design: part)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.screenFill)
        .navigationTitle(shown.kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension WidgetDesign {
    var photoName: String? {
        if case let .photo(name) = background { return name }
        return nil
    }
}

enum BackgroundKind: Hashable {
    case theme, color, gradient, glass, photo

    init(_ style: BackgroundStyle) {
        switch style {
        case .theme: self = .theme
        case .color: self = .color
        case .gradient: self = .gradient
        case .glass: self = .glass
        case .photo: self = .photo
        }
    }
}

struct EditorSection<Content: View>: View {
    let title: String
    var detail: String?
    var isPremium = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if isPremium { PremiumBadge(compact: true) }
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            content()
                .card(padding: 14)
        }
    }
}

struct ColorDot: View {
    let hex: String
    let isSelected: Bool
    var size: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: size, height: size)
                .overlay { Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1) }
                .padding(3)
                .overlay {
                    Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                }
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
