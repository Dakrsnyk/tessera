import PhotosUI
import SwiftUI
import WidgetKit

struct EditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var design: WidgetDesign
    @State private var family: WidgetFamily
    @State private var showsPaywall = false
    @State private var confirmDiscard = false
    @State private var confirmDelete = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var backgroundTab: BackgroundKind
    @State private var didSave = false
    @State private var previewFrame: CGRect = .zero
    @State private var section: StudioSection

    private let isNew: Bool
    private let original: WidgetDesign

    init(request: EditorRequest) {
        _design = State(initialValue: request.design)
        _family = State(initialValue: request.design.displayFormat.family)
        _backgroundTab = State(initialValue: BackgroundKind(request.design.background))
        _section = State(initialValue: request.section.flatMap(StudioSection.init(rawValue:)) ?? .content)
        isNew = request.isNew
        original = request.design
    }

    private var hasChanges: Bool { isNew || design != original }
    private var needsPremium: Bool { design.usesPremiumFeatures && !model.isPremium }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Always in view: every change shows at once.
                StudioStage(design: design, family: $family, payload: payload, isExample: !model.hasOwnData(for: design))
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { previewFrame = $0 }
                StudioSectionBar(selection: $section)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if needsPremium { premiumNotice }
                        sectionContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
                .id(section)
                .scrollDismissesKeyboard(.interactively)
                .screenshotScroll()
            }
            .background(.screenFill)
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(isNew ? "Nouveau widget" : "Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        if hasChanges && !isNew { confirmDiscard = true } else { dismiss() }
                    }
                }
            }
            .confirmationDialog("Abandonner les modifications ?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Abandonner", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Supprimer ce widget ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    model.delete(original)
                    dismiss()
                }
            } message: {
                Text("Les widgets qui l'affichent reviendront au modèle par défaut.")
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .task(id: design.kind) { await model.prepare(design) }
            .task(id: design.options.coinID) { if design.kind == .crypto { await model.prepare(design) } }
            .onChange(of: photoItem) { _, item in importPhoto(item) }
        }
        .interactiveDismissDisabled(hasChanges && !isNew)
        .onDisappear {
            if !didSave { discardUnsavedPhoto() }
        }
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

    @ViewBuilder private var sectionContent: some View {
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
            // A combined widget keeps the options of each widget inside it.
            if !design.isCombo { KindOptionsSection(design: $design) }
            StudioElementsPanel(design: $design, tile: studioInput.tile)
            if !isNew { deleteButton }
        case .themes:
            StudioThemesPanel(design: $design, input: studioInput)
        case .style:
            StudioStylesPanel(design: $design, input: studioInput)
        case .colors:
            StudioColorsPanel(design: $design, input: studioInput)
        case .background:
            backgroundSection
            textureSection
            StudioNote(text: "iOS ne laisse pas un widget montrer le fond d'écran à travers lui : une vraie transparence n'est pas possible. Tessera propose le Verre (givre et reflets dessinés), les dégradés doux et ta photo. Les apparences « Teinté » ou transparentes d'iOS (Personnaliser l'écran d'accueil) s'appliquent aussi aux widgets Tessera.")
        case .border:
            StudioBorderPanel(design: $design)
        case .depth:
            StudioDepthPanel(design: $design)
        case .shape:
            StudioShapePanel(design: $design, input: studioInput)
        case .text:
            StudioTextPanel(design: $design)
        case .icons:
            StudioIconsPanel(design: $design)
        case .layout:
            StudioLayoutPanel(design: $design, input: studioInput)
        case .chart:
            StudioChartPanel(design: $design, input: studioInput)
        case .density:
            StudioDensityPanel(design: $design, input: studioInput)
        case .myStyles:
            StudioMyStylesPanel(design: $design, input: studioInput)
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
            TextField("Nom du widget", text: $design.name)
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
                    case .theme: design.background = .theme
                    case .color:
                        if case .color = design.background {} else { design.background = .color(Palette.backgrounds[0].hex) }
                    case .gradient: design.background = .gradient
                    case .glass: design.background = .glass
                    case .photo: break
                    }
                }

                switch backgroundTab {
                case .color:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(Palette.backgrounds) { swatch in
                            ColorDot(hex: swatch.hex, isSelected: design.background == .color(swatch.hex), size: 40) {
                                design.background = .color(swatch.hex)
                            }
                            .accessibilityLabel(Text(swatch.name))
                        }
                    }
                    ColorPicker("Autre couleur", selection: Binding(
                        get: {
                            if case let .color(hex) = design.background { return Color(hex: hex) }
                            return Color(hex: Palette.backgrounds[0].hex)
                        },
                        set: { design.background = .color($0.hexString) }
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
                            set: { design.style.veil = $0 }
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
                design.style.gradient = isOn
                    ? GradientSpec(startHex: ColorMath.shade(design.accentHex, 0.18), endHex: ColorMath.shade(design.accentHex, -0.45))
                    : nil
            }
        ))
        .font(.subheadline)
        if let spec = design.style.gradient {
            HStack(spacing: 16) {
                ColorPicker("Couleur 1", selection: Binding(
                    get: { Color(hex: spec.startHex) },
                    set: { design.style.gradient?.startHex = $0.hexString }
                ), supportsOpacity: false)
                ColorPicker("Couleur 2", selection: Binding(
                    get: { Color(hex: spec.endHex) },
                    set: { design.style.gradient?.endHex = $0.hexString }
                ), supportsOpacity: false)
            }
            .font(.subheadline)
            StudioChoices(
                options: GradientDirection.allCases,
                selection: Binding(get: { spec.direction }, set: { design.style.gradient?.direction = $0 }),
                title: \.title,
                symbol: { $0.symbol }
            )
            StudioSlider(title: "Intensité", value: Binding(
                get: { spec.intensity },
                set: { design.style.gradient?.intensity = $0 }
            ), range: 0.1...1)
            FlowLayout(spacing: 8) {
                ForEach(Array(Self.gradientIdeas.enumerated()), id: \.offset) { _, idea in
                    Button {
                        withAnimation { design.style.gradient = GradientSpec(startHex: idea.0, endHex: idea.1, direction: spec.direction, intensity: 1) }
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
                StudioChoices(options: TextureKind.allCases, selection: $design.style.texture, title: \.title, identifier: { "texture-\($0.rawValue)" })
                if design.effectiveStyle.texture != .none {
                    StudioSlider(title: "Intensité", value: $design.style.textureOpacity, range: 0.1...1)
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
                Text(needsPremium ? "Débloquer et enregistrer" : (isNew ? "Enregistrer le widget" : "Enregistrer"))
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

    // MARK: Actions

    private func save() {
        if needsPremium || (isNew && !model.canCreateDesign) {
            showsPaywall = true
            return
        }
        model.save(design)
        didSave = true
        Haptics.success()
        if isNew {
            router.lastSavedName = design.name
            router.showsAddGuideAfterEditor = true
            // The new widget glides into « Mes widgets » as the editor closes.
            router.saveFlight = SaveFlight(designs: [design], source: previewFrame)
        }
        dismiss()
    }

    private func importPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isImportingPhoto = true
        Task {
            defer {
                isImportingPhoto = false
                photoItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let name = ImageStore.save(image) else { return }
            discardUnsavedPhoto()
            design.background = .photo(name)
        }
    }

    /// Removes a photo imported during this editing session that won't be kept.
    private func discardUnsavedPhoto() {
        if case let .photo(name) = design.background, name != originalPhotoName {
            ImageStore.delete(named: name)
        }
    }

    private var originalPhotoName: String? {
        if case let .photo(name) = original.background { return name }
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
