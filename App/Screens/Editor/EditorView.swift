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

    private let isNew: Bool
    private let original: WidgetDesign

    init(request: EditorRequest) {
        _design = State(initialValue: request.design)
        _family = State(initialValue: request.design.kind.homeFamilies.first ?? .systemSmall)
        _backgroundTab = State(initialValue: BackgroundKind(request.design.background))
        isNew = request.isNew
        original = request.design
    }

    private var hasChanges: Bool { isNew || design != original }
    private var needsPremium: Bool { design.usesPremiumFeatures && !model.isPremium }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PreviewStage(design: design, family: $family, payload: model.payload(for: design))
                    if needsPremium { premiumNotice }
                    nameSection
                    styleSection
                    colorSection
                    backgroundSection
                    fontSection
                    displaySection
                    KindOptionsSection(design: $design)
                    if !isNew { deleteButton }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenshotScroll()
            .background(Color.screenFill)
            .safeAreaInset(edge: .bottom) { saveBar }
            .navigationTitle(isNew ? "Nouveau widget" : "Modifier")
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
            Button("Débloquer") { showsPaywall = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(14)
        .background(Color.premiumFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var nameSection: some View {
        EditorSection(title: "Nom") {
            TextField("Nom du widget", text: $design.name)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(12)
                .background(Color.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var styleSection: some View {
        EditorSection(title: "Style", detail: design.theme.tagline) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemeCatalog.all) { theme in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { design.themeID = theme.id }
                            Haptics.tap()
                        } label: {
                            ThemeSwatch(theme: theme, accentHex: design.accentHex, isSelected: design.themeID == theme.id, showsLock: theme.isPremium && !model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var colorSection: some View {
        EditorSection(title: "Couleur", detail: Palette.name(for: design.accentHex)) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                ForEach(Palette.freeAccents) { swatch in
                    ColorDot(hex: swatch.hex, isSelected: design.accentHex == swatch.hex) {
                        design.accentHex = swatch.hex
                        Haptics.tap()
                    }
                    .accessibilityLabel(Text(swatch.name))
                }
                ColorPicker("Couleur personnalisée", selection: Binding(
                    get: { Color(hex: design.accentHex) },
                    set: { design.accentHex = $0.hexString }
                ), supportsOpacity: false)
                .labelsHidden()
                .frame(minWidth: 44, minHeight: 44)
                .overlay(alignment: .topTrailing) {
                    if !model.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.premiumInk)
                            .padding(3)
                            .background(Color.premiumFill, in: Circle())
                            .offset(x: 6, y: -6)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var backgroundSection: some View {
        EditorSection(title: "Fond", isPremium: !model.isPremium) {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Fond", selection: $backgroundTab) {
                    Text("Thème").tag(BackgroundKind.theme)
                    Text("Couleur").tag(BackgroundKind.color)
                    Text("Dégradé").tag(BackgroundKind.gradient)
                    Text("Photo").tag(BackgroundKind.photo)
                }
                .pickerStyle(.segmented)
                .onChange(of: backgroundTab) { _, tab in
                    switch tab {
                    case .theme: design.background = .theme
                    case .color:
                        if case .color = design.background {} else { design.background = .color(Palette.backgrounds[0].hex) }
                    case .gradient: design.background = .gradient
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
                case .gradient:
                    Text("Le dégradé suit la couleur choisie plus haut.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .theme:
                    Text("Le fond du style choisi.")
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
                        .background(Color.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var fontSection: some View {
        EditorSection(title: "Police") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FontChoice.allCases) { font in
                        Button {
                            design.font = font
                        } label: {
                            HStack(spacing: 4) {
                                Text(font.title)
                                    .font(.system(.subheadline, design: fontDesign(font)).weight(.medium))
                                if font.isPremium && !model.isPremium {
                                    Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold))
                                }
                            }
                            .foregroundStyle(design.font == font ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(design.font == font ? Color.accentColor : Color.screenFill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func fontDesign(_ font: FontChoice) -> Font.Design {
        switch font {
        case .theme: design.theme.fontDesign
        case .standard: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }

    private var displaySection: some View {
        EditorSection(title: "Affichage") {
            VStack(spacing: 12) {
                Toggle("Titre", isOn: $design.showsTitle)
                Divider()
                Toggle("Détails", isOn: $design.showsDetails)
                Divider()
                HStack {
                    Text("Alignement")
                    Spacer()
                    Picker("Alignement", selection: $design.alignment) {
                        ForEach(ContentAlignment.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
            }
            .font(.subheadline)
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
    case theme, color, gradient, photo

    init(_ style: BackgroundStyle) {
        switch style {
        case .theme: self = .theme
        case .color: self = .color
        case .gradient: self = .gradient
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

/// The live preview at the top of the editor, with a size switcher.
struct PreviewStage: View {
    let design: WidgetDesign
    @Binding var family: WidgetFamily
    let payload: WidgetPayload

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                LinearGradient(
                    colors: family.isAccessory
                        ? [Color(hex: "1F2A44"), Color(hex: "3B2F5C")]
                        : [Color(light: "DCE3EA", dark: "1B1F26"), Color(light: "C9D3DD", dark: "11141A")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                preview
                    .padding(20)
                    .animation(.easeInOut(duration: 0.2), value: family)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            if design.kind.families.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(design.kind.families, id: \.self) { item in
                            FilterChip(title: item.shortTitle, symbol: item.isAccessory ? "lock" : nil, isSelected: family == item) {
                                family = item
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
        .onChange(of: design.kind) { _, kind in
            if !kind.families.contains(family) { family = kind.families.first ?? .systemSmall }
        }
    }

    @ViewBuilder private var preview: some View {
        switch family {
        case .systemSmall:
            WidgetPreview(design: design, family: family, payload: payload, width: 170)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            WidgetPreview(design: design, family: family, payload: payload, width: WidgetMetrics.size(family).width * 1.4)
                .padding(.vertical, 24)
        default:
            WidgetPreview(design: design, family: family, payload: payload)
                .frame(maxWidth: 364)
        }
    }
}
