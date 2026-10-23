import PhotosUI
import SwiftUI
import WidgetKit

/// « Photos et citations »: widgets made of the person's photos or of a quote. One main action for each,
/// then the widgets already made, ready to be changed. A widget is made in two steps: its size, then its
/// photos (Apple's photo picker: only the chosen photos are shared, no access to the library is asked)
/// or its quote.
struct PhotoQuotesAppView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: PhotoQuoteDraft?
    @State private var paywall: PaywallContext?

    private var accentHex: String { MiniApp.photos.colorHex }

    var body: some View {
        let made = model.photoQuoteDesigns
        MiniAppScaffold(colorHex: accentHex) {
            // No selector: nothing here is dated. The band tells how many widgets exist and what is shared.
            MiniHero(label: tr("Tes widgets photo"), value: "\(made.count)",
                     caption: tr("Seules les photos que tu choisis sont copiées dans Ardane : aucun accès à ta photothèque n'est demandé."))
        } sheet: {
            // Two actions: a row at the head of the sheet.
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Photos"), symbol: "photo.on.rectangle.angled", colorHex: accentHex) {
                    start(.photos)
                }
                .accessibilityIdentifier("photos-new")
                MiniActionButton(title: tr("Citation"), symbol: "quote.opening", colorHex: accentHex, isProminent: false) {
                    start(.quote)
                }
                .accessibilityIdentifier("quote-new")
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Mes widgets"))
                if made.isEmpty {
                    Text(tr("Une photo, deux, trois ou quatre, ou une citation : ton premier widget se crée en deux étapes."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .card(padding: 14)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(made) { design in
                            Button {
                                editing = PhotoQuoteDraft(design: design, isNew: false)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    WidgetPreview(design: design, family: (design.format ?? .small).family, payload: WidgetPayload())
                                    Text(design.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("\(design.kind.title) · \((design.format ?? .small).title)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.pressable)
                            .accessibilityIdentifier("photos-widget")
                        }
                    }
                }
            }
            MiniFootnote(text: tr("Pour le poser : touche longuement l'écran d'accueil, puis + › Ardane › « Mes widgets », et choisis-le avec « Modifier le widget »."))
        }
        .navigationTitle(tr("Photos et citations"))
        .sheet(item: $editing) { draft in
            PhotoQuoteEditor(draft: draft)
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    private func start(_ kind: WidgetKind) {
        let draft = PhotoQuoteDraft.blank(kind)
        // The rule of every new widget: photos and quotes don't count toward the free limit.
        guard model.canSave(adding: [draft.design]) else {
            paywall = .designLimit
            return
        }
        editing = draft
    }
}

extension AppModel {
    /// The photo and quote widgets, the most recently used first.
    var photoQuoteDesigns: [WidgetDesign] { recentDesigns.filter { $0.kind.isMadeInItsMiniApp } }
}

/// A photo or quote widget being made or changed.
struct PhotoQuoteDraft: Identifiable {
    var design: WidgetDesign
    var isNew: Bool
    var id: UUID { design.id }

    /// A new photo or quote widget, small until its size is chosen: started the same way from the mini-app
    /// and from Créer (the caller checks the free limit first).
    static func blank(_ kind: WidgetKind) -> PhotoQuoteDraft {
        var design = WidgetDesign(kind: kind, format: .small)
        design.name = kind == .photos ? tr("Mes photos") : tr("Ma citation")
        if kind == .quote { design.options.quote = QuoteContent() }
        return PhotoQuoteDraft(design: design, isNew: true)
    }
}

/// Makes or changes a photo or quote widget: its size first, then its photos (framed one by one) or its
/// quote (text, author, typography, colors), with the widget as it will look above.
struct PhotoQuoteEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var design: WidgetDesign
    let isNew: Bool
    @State private var picked: [PhotosPickerItem] = []
    /// The photo chosen to go behind a quote.
    @State private var backgroundItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var failed = 0
    @State private var framing: PhotoSlot?
    @State private var confirmsDelete = false
    /// Photo files written while editing: removed if the widget isn't saved.
    @State private var written: Set<String> = []

    init(draft: PhotoQuoteDraft) {
        _design = State(initialValue: draft.design)
        isNew = draft.isNew
    }

    private var accentHex: String { MiniApp.photos.colorHex }
    private var format: WidgetFormat { design.format ?? .small }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WidgetPreview(design: design, family: format.family, payload: WidgetPayload())
                        .frame(maxWidth: format == .small ? 200 : .infinity)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("photos-preview")
                    step(1, tr("La taille")) { sizePicker }
                    if design.kind == .photos {
                        step(2, tr("Les photos")) { photosStep }
                    } else {
                        step(2, tr("La citation")) { quoteStep }
                    }
                    step(3, tr("Le nom")) {
                        TextField(tr("Nom du widget"), text: $design.name)
                            .padding(12)
                            .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityIdentifier("photos-name")
                    }
                    if !isNew {
                        Button(role: .destructive) {
                            confirmsDelete = true
                        } label: {
                            Label(tr("Supprimer ce widget"), systemImage: "trash")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.screenGradient)
            .navigationTitle(design.kind == .photos ? tr("Widget photo") : tr("Widget citation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Enregistrer")) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("photos-save")
                }
            }
            .sheet(item: $framing) { slot in
                PhotoFramingView(slot: slot, design: design) { framed in
                    if let index = design.options.photos.firstIndex(where: { $0.id == framed.id }) {
                        design.options.photos[index] = framed
                    }
                }
            }
            .confirmationDialog(tr("Supprimer ce widget ?"), isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button(tr("Supprimer"), role: .destructive) {
                    // The saved widget's photos go with it, and so do the copies made in this edit.
                    model.delete(model.design(id: design.id) ?? design)
                    for file in written { ImageStore.delete(named: file) }
                    written = []
                    dismiss()
                }
            } message: {
                Text(tr("Il disparaîtra de ton écran d'accueil. Les photos de ta photothèque ne sont pas touchées."))
            }
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                Task { await load(items) }
            }
            .onChange(of: backgroundItem) { _, item in
                guard let item else { return }
                Task { await load([item]) }
            }
        }
        // Copies made in this edit are only cleaned up by Annuler or Enregistrer: no swiping them away.
        .interactiveDismissDisabled(isLoading || !written.isEmpty)
    }

    private var canSave: Bool {
        guard !isLoading else { return false }
        switch design.kind {
        case .photos: return !design.options.photos.isEmpty
        default: return !(design.options.quote?.text.trimmed.isEmpty ?? true)
        }
    }

    private func step<Content: View>(_ number: Int, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color(hex: accentHex), in: Circle())
                Text(title).font(.headline)
            }
            content()
        }
    }

    // MARK: Size

    private var sizePicker: some View {
        HStack(spacing: 10) {
            ForEach(WidgetFormat.allCases) { option in
                let size = WidgetMetrics.size(option.family)
                Button {
                    withAnimation(.snappy) { design.format = option }
                } label: {
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(format == option ? Color(hex: accentHex) : Color.secondary.opacity(0.4), lineWidth: 2)
                            .frame(width: size.width / 8, height: size.height / 8)
                            .frame(height: 50)
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(format == option ? Color(hex: accentHex) : Color.primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 86)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(format == option ? Color(hex: accentHex) : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("photos-size-\(option.rawValue)")
                .accessibilityAddTraits(format == option ? .isSelected : [])
            }
        }
    }

    // MARK: Photos

    @ViewBuilder private var photosStep: some View {
        let photos = design.options.photos
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $picked, maxSelectionCount: max(1, PhotoLayout.maxPhotos - photos.count), matching: .images) {
                Label(photos.isEmpty ? tr("Choisir des photos") : tr("Ajouter des photos"), systemImage: "photo.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(hex: accentHex), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(photos.count >= PhotoLayout.maxPhotos || isLoading)
            .accessibilityIdentifier("photos-pick")
            if isLoading {
                ProgressView(tr("Préparation des photos…"))
            }
            if failed > 0 {
                Label(Fmt.plural(failed, tr("photo illisible"), tr("photos illisibles")), systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(photos.isEmpty
                 ? tr("Seules les photos que tu choisis sont copiées dans Ardane : aucun accès à ta photothèque n'est demandé.")
                 : (photos.count > PhotoLayout.capacity
                    ? tr("Plus de \(PhotoLayout.capacity) photos : le widget en montre \(PhotoLayout.capacity) à la fois, puis les suivantes chaque heure.")
                    : tr("Touche une photo pour la recadrer. La mise en page suit leur nombre : une, deux, trois ou quatre.")))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, slot in
                            thumbnail(slot, index: index, count: photos.count)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func thumbnail(_ slot: PhotoSlot, index: Int, count: Int) -> some View {
        Button {
            framing = slot
        } label: {
            PhotoCell(slot: PhotoSlot(file: slot.file), size: CGSize(width: 72, height: 72))
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.black.opacity(0.55), in: Circle())
                        .padding(4)
                }
        }
        .buttonStyle(.pressable)
        .contextMenu {
            Button { framing = slot } label: { Label(tr("Recadrer"), systemImage: "crop") }
            if index > 0 {
                Button { move(slot, to: index - 1) } label: { Label(tr("Avancer"), systemImage: "arrow.left") }
            }
            if index < count - 1 {
                Button { move(slot, to: index + 1) } label: { Label(tr("Reculer"), systemImage: "arrow.right") }
            }
            Button(role: .destructive) {
                design.options.photos.removeAll { $0.id == slot.id }
            } label: {
                Label(tr("Retirer"), systemImage: "minus.circle")
            }
        }
        .accessibilityLabel(Text(tr("Photo \(index + 1)")))
        .accessibilityHint(Text(tr("Touche pour recadrer, touche longuement pour la déplacer ou la retirer.")))
        .accessibilityIdentifier("photos-thumbnail")
    }

    private func move(_ slot: PhotoSlot, to index: Int) {
        guard let from = design.options.photos.firstIndex(where: { $0.id == slot.id }) else { return }
        withAnimation(.snappy) {
            let item = design.options.photos.remove(at: from)
            design.options.photos.insert(item, at: min(index, design.options.photos.count))
        }
    }

    /// Copies the chosen photos (downscaled) into the shared container, in the order they were chosen. A
    /// quote has one photo at most, behind its text: a new one takes its place.
    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        failed = 0
        var slots: [PhotoSlot] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data),
                  let file = ImageStore.save(image, maxDimension: 1_200) else {
                failed += 1
                continue
            }
            written.insert(file)
            slots.append(PhotoSlot(file: file))
        }
        if design.kind == .quote {
            if let first = slots.first { design.options.photos = [first] }
        } else {
            let room = PhotoLayout.maxPhotos - design.options.photos.count
            design.options.photos.append(contentsOf: slots.prefix(max(0, room)))
        }
        picked = []
        backgroundItem = nil
        isLoading = false
        Haptics.success()
    }

    // MARK: Quote

    private var quoteBinding: Binding<QuoteContent> {
        Binding(get: { design.options.quote ?? QuoteContent() }, set: { design.options.quote = $0 })
    }

    @ViewBuilder private var quoteStep: some View {
        let quote = quoteBinding
        VStack(alignment: .leading, spacing: 12) {
            TextField(tr("Ta citation"), text: Binding(get: { quote.wrappedValue.text }, set: { quote.wrappedValue.text = String($0.prefix(280)) }), axis: .vertical)
                .lineLimit(3...8)
                .padding(12)
                .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("quote-text")
            TextField(tr("Auteur (facultatif)"), text: quote.author)
                .padding(12)
                .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityIdentifier("quote-author")
            Text(tr("Typographie")).font(.subheadline.weight(.semibold))
            Picker(tr("Typographie"), selection: quote.font) {
                ForEach(QuoteFont.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(tr("Couleurs")).font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(QuotePalette.all) { palette in
                        let isOn = quote.wrappedValue.backgroundHex == palette.backgroundHex && quote.wrappedValue.textHex == palette.textHex
                        Button {
                            quote.wrappedValue.apply(palette)
                        } label: {
                            VStack(spacing: 4) {
                                Text("Aa")
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color(hex: palette.textHex))
                                    .frame(width: 52, height: 40)
                                    .background(Color(hex: palette.backgroundHex), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(isOn ? Color(hex: accentHex) : Color.primary.opacity(0.1), lineWidth: isOn ? 2.5 : 1)
                                    }
                                Text(palette.name).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(Text(palette.name))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
            HStack(spacing: 12) {
                ColorPicker(tr("Fond"), selection: colorBinding(\.backgroundHex), supportsOpacity: false)
                ColorPicker(tr("Texte"), selection: colorBinding(\.textHex), supportsOpacity: false)
            }
            .font(.subheadline)
            backgroundSection
            Group {
                Toggle(tr("Centrée"), isOn: quote.isCentered).font(.subheadline)
                Toggle(tr("Guillemets"), isOn: quote.showsMarks).font(.subheadline)
            }
            if quote.wrappedValue.text.trimmed.isEmpty {
                Button(tr("Essayer avec un exemple")) {
                    let current = quote.wrappedValue
                    var sample = QuoteContent.sample
                    sample.font = current.font
                    sample.backgroundHex = current.backgroundHex
                    sample.textHex = current.textHex
                    sample.photoVeil = current.photoVeil
                    quote.wrappedValue = sample
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .tint(Color(hex: accentHex))
    }

    /// A photo behind the quote, copied and framed like a photo widget's (it is the widget's only photo), under
    /// a veil that keeps the text readable.
    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("Photo de fond")).font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading { ProgressView() }
            }
            if let slot = design.quoteBackground {
                let widget = WidgetMetrics.size(format.family)
                let thumbnail = CGSize(width: widget.width * 64 / max(1, widget.height), height: 64)
                HStack(spacing: 12) {
                    Button {
                        framing = slot
                    } label: {
                        PhotoCell(slot: slot, size: thumbnail)
                            .frame(width: thumbnail.width, height: thumbnail.height)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(tr("Recadrer")))
                    .accessibilityIdentifier("quote-background-frame")
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            framing = slot
                        } label: {
                            Label(tr("Recadrer"), systemImage: "crop")
                        }
                        PhotosPicker(selection: $backgroundItem, matching: .images) {
                            Label(tr("Changer de photo"), systemImage: "photo.on.rectangle")
                        }
                        .disabled(isLoading)
                        Button(role: .destructive) {
                            withAnimation(.snappy) { design.options.photos = [] }
                        } label: {
                            Label(tr("Retirer"), systemImage: "minus.circle")
                        }
                        .accessibilityIdentifier("quote-background-remove")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                StudioSlider(title: tr("Voile pour la lisibilité"), value: quoteBinding.photoVeil, range: QuoteContent.veilRange)
                Text(tr("Sur la photo, le texte garde ta couleur si elle est claire, sinon il passe en blanc. La couleur de fond ne sert que si la photo n'est plus disponible."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                PhotosPicker(selection: $backgroundItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text(tr("Choisir une photo"))
                        Spacer()
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(12)
                    .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.pressable)
                .disabled(isLoading)
                .accessibilityIdentifier("quote-background-pick")
            }
            if failed > 0 {
                Label(Fmt.plural(failed, tr("photo illisible"), tr("photos illisibles")), systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<QuoteContent, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: quoteBinding.wrappedValue[keyPath: keyPath]) },
            set: { color in
                var quote = quoteBinding.wrappedValue
                quote[keyPath: keyPath] = color.hexString
                quoteBinding.wrappedValue = quote
            }
        )
    }

    // MARK: Saving

    private func save() {
        var saved = design
        saved.name = saved.name.trimmed.isEmpty ? saved.kind.title : saved.name.trimmed
        if saved.kind == .quote, var quote = saved.options.quote {
            quote.text = quote.text.trimmed
            quote.author = quote.author.trimmed
            saved.options.quote = quote
        }
        let kept = Set(saved.options.photos.map(\.file))
        let before = Set(model.design(id: saved.id)?.options.photos.map(\.file) ?? [])
        model.save(saved)
        // Photos taken off the widget: their copies go too (the library's originals are never touched).
        for file in before.union(written).subtracting(kept) { ImageStore.delete(named: file) }
        written = []
        Haptics.success()
        if isNew { model.celebrate() }
        dismiss()
    }

    private func cancel() {
        // Copies made for this edit and not kept.
        let saved = Set(model.design(id: design.id)?.options.photos.map(\.file) ?? [])
        for file in written.subtracting(saved) { ImageStore.delete(named: file) }
        written = []
        dismiss()
    }
}

/// Frames one photo in its cell: drag to move it, pinch to zoom, as it will be cut on the widget.
struct PhotoFramingView: View {
    @State var slot: PhotoSlot
    let design: WidgetDesign
    let onDone: (PhotoSlot) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var startSlot: PhotoSlot?
    /// The photo's own size, read once (dragging never reads the file again).
    @State private var imageSize: CGSize = .zero

    /// The cell of this photo in the widget, at the widget's real size.
    private var cellSize: CGSize {
        let family = (design.format ?? .small).family
        let shown = PhotoLayout.visible(design.options.photos, at: Date())
        let index = shown.firstIndex { $0.id == slot.id } ?? 0
        let cells = PhotoLayout.cells(count: max(1, shown.count), family: family)
        let cell = cells[safe: index] ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let widget = WidgetMetrics.size(family)
        return CGSize(width: cell.width * widget.width, height: cell.height * widget.height)
    }

    var body: some View {
        let cell = cellSize
        NavigationStack {
            VStack(spacing: 20) {
                GeometryReader { geo in
                    let scale = min(geo.size.width / cell.width, geo.size.height / cell.height)
                    let shown = CGSize(width: cell.width * scale, height: cell.height * scale)
                    PhotoCell(slot: slot, size: shown)
                        .frame(width: shown.width, height: shown.height)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
                        }
                        .contentShape(Rectangle())
                        .gesture(drag(cell: shown).simultaneously(with: magnify))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 20)
                .accessibilityIdentifier("photos-framing")
                Text(tr("Glisse pour déplacer la photo, pince pour zoomer."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: $slot.zoom, in: 1...4) {
                    Text(tr("Zoom"))
                } minimumValueLabel: {
                    Image(systemName: "minus.magnifyingglass")
                } maximumValueLabel: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .padding(.horizontal, 24)
                .accessibilityIdentifier("photos-zoom")
            }
            .padding(.vertical, 20)
            .onAppear { imageSize = ImageStore.image(named: slot.file)?.size ?? .zero }
            .background(Color.black.opacity(0.92).ignoresSafeArea())
            .environment(\.colorScheme, .dark)
            .navigationTitle(tr("Recadrer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button(tr("Réinitialiser")) {
                        withAnimation(.snappy) {
                            slot.centerX = 0.5
                            slot.centerY = 0.5
                            slot.zoom = 1
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) {
                        onDone(slot.clamped)
                        dismiss()
                    }
                    .accessibilityIdentifier("photos-framing-done")
                }
            }
        }
    }

    /// Moving the finger moves the photo: the center goes the other way, by the photo's drawn size.
    private func drag(cell: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let base = startSlot ?? slot
                if startSlot == nil { startSlot = slot }
                guard imageSize.width > 0 else { return }
                let drawn = PhotoLayout.frame(image: imageSize, cell: cell, slot: base).size
                var moved = base
                moved.centerX = base.centerX - value.translation.width / max(1, drawn.width)
                moved.centerY = base.centerY - value.translation.height / max(1, drawn.height)
                moved.zoom = slot.zoom
                slot = moved.clamped
            }
            .onEnded { _ in startSlot = nil }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = startSlot ?? slot
                if startSlot == nil { startSlot = slot }
                slot.zoom = min(4, max(1, base.zoom * value.magnification))
            }
            .onEnded { _ in startSlot = nil }
    }
}
