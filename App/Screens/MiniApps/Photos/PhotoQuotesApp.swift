import PhotosUI
import SwiftUI
import WidgetKit

/// « Photos et citations »: the gallery of its widgets (as they are placed, a « … » menu on each), with what the
/// « Un par jour » widget shows today. One main action for each kind, then the widgets already made, ready to be
/// changed. A widget is made in a workshop: the widget stays in view above, the settings in chapters. Photos come
/// from Apple's photo picker (only the chosen photos are shared, no access to the library is asked).
struct PhotoQuotesAppView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var editing: PhotoQuoteDraft?
    @State private var paywall: PaywallContext?
    @State private var pendingDeletion: WidgetDesign?

    private var accentHex: String { MiniApp.photos.colorHex }

    var body: some View {
        let made = model.photoQuoteDesigns
        MiniAppScaffold(colorHex: accentHex) {
            header(made)
        } sheet: {
            // Two actions: a row at the head of the sheet.
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Photos"), symbol: "photo.on.rectangle.angled", colorHex: accentHex) {
                    start(.photos)
                }
                .accessibilityIdentifier("photos-new")
                .tourAnchor(.photos, 0)
                MiniActionButton(title: tr("Citation"), symbol: "quote.opening", colorHex: accentHex, isProminent: false) {
                    start(.quote)
                }
                .accessibilityIdentifier("quote-new")
                .tourAnchor(.photos, 1)
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Mes widgets"),
                                 detail: made.isEmpty ? nil : Fmt.plural(made.count, tr("widget"), tr("widgets")))
                if made.isEmpty {
                    Text(tr("Choisis des photos (jusqu'à 12) ou écris une citation : ton premier widget se crée en quelques touches."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .card(padding: 14)
                } else {
                    gallery(made)
                }
            }
            MiniFootnote(text: tr("Pour le poser : touche longuement l'écran d'accueil, puis + › Ardane › « Mes widgets », et choisis-le avec « Modifier le widget »."))
        }
        .navigationTitle(tr("Photos et citations"))
        .miniAppTour(.photos)
        .sheet(item: $editing) { draft in
            PhotoQuoteEditor(draft: draft)
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
        .confirmationDialog(tr("Supprimer ce widget ?"), isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button(tr("Supprimer"), role: .destructive) {
                if let design = pendingDeletion { model.delete(design) }
                pendingDeletion = nil
            }
        } message: {
            Text(tr("Il disparaîtra de ton écran d'accueil. Les photos de ta photothèque ne sont pas touchées."))
        }
    }

    /// The band: the day of the first « Un par jour » widget and what it shows, else how many widgets there are
    /// and what is shared.
    @ViewBuilder private func header(_ made: [WidgetDesign]) -> some View {
        let now = Date()
        if let daily = made.first(where: { $0.dailyPosition(on: now) != nil }), let position = daily.dailyPosition(on: now) {
            let next = daily.kind == .quote ? tr("prochain texte à minuit") : tr("prochaine photo à minuit")
            MiniHero(label: tr("Aujourd'hui"), value: PhotoDailyText.day(position), caption: "\(daily.name) · \(next)", valueSize: 40)
                .accessibilityIdentifier("photos-today")
        } else {
            MiniHero(label: tr("Tes widgets"), value: Fmt.plural(made.count, tr("widget"), tr("widgets")),
                     caption: tr("Seules les photos que tu choisis sont copiées dans Ardane : aucun accès à ta photothèque n'est demandé."))
        }
    }

    /// The widgets in their real proportions: a Medium or a Large takes the whole width, two Small ones share a row.
    private func gallery(_ made: [WidgetDesign]) -> some View {
        var rows: [[WidgetDesign]] = []
        for design in made {
            let isSmall = (design.format ?? .small) == .small
            if isSmall, let last = rows.last, last.count == 1, (last[0].format ?? .small) == .small {
                rows[rows.count - 1].append(design)
            } else {
                rows.append([design])
            }
        }
        return VStack(spacing: 16) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(row) { tile($0) }
                    if row.count == 1, (row[0].format ?? .small) == .small {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func tile(_ design: WidgetDesign) -> some View {
        PhotoWidgetTile(
            design: design,
            isFavorite: design.isFavorite,
            edit: { editing = PhotoQuoteDraft(design: design, isNew: false) },
            duplicate: { duplicate(design, asVariant: false) },
            makeVariant: { duplicate(design, asVariant: true) },
            toggleFavorite: {
                Haptics.tap()
                model.toggleFavorite(design)
            },
            place: {
                // The widget to place becomes the latest of its size: the gallery previews it.
                model.markUsed(design)
                router.lastSavedName = design.name
                router.lastSavedID = design.id
                router.isAddGuidePresented = true
            },
            delete: { pendingDeletion = design }
        )
        .frame(maxWidth: .infinity)
    }

    private func duplicate(_ design: WidgetDesign, asVariant: Bool) {
        guard let copy = model.duplicate(design, asVariant: asVariant) else {
            paywall = .designLimit
            return
        }
        Haptics.success()
        // A variant is the same copy, opened to be changed.
        if asVariant { editing = PhotoQuoteDraft(design: copy, isNew: false) }
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

/// Makes or changes a photo or quote widget, in a workshop: the widget as it will look stays in view above, the
/// settings in chapters (« Contenu », « Disposition », and « Style » for a quote).
struct PhotoQuoteEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appStyle) private var style
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
    @State private var chapter: PhotoChapter = .content
    /// The thumbnail whose actions (frame, move, remove) are shown under the grid.
    @State private var selectedPhoto: UUID?
    @State private var importsTexts = false
    @State private var paywall: PaywallContext?

    init(draft: PhotoQuoteDraft) {
        _design = State(initialValue: draft.design)
        isNew = draft.isNew
    }

    private var accentHex: String { MiniApp.photos.colorHex }
    /// The mini-app's action color as Cristal translates it (fills, rings and text).
    private var strong: Color { style.cristal.strong(accentHex) }
    private var format: WidgetFormat { design.format ?? .small }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // The widget stays in view while the settings scroll under it.
                VStack(spacing: 12) {
                    WidgetPreview(design: design, family: format.family, payload: WidgetPayload())
                        .frame(maxWidth: format == .small ? 150 : .infinity, maxHeight: 170)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("photos-preview")
                    Picker(tr("Chapitre"), selection: $chapter) {
                        ForEach(PhotoChapter.chapters(for: design.kind)) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("photos-chapter")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch chapter {
                        case .content: contentChapter
                        case .layout: layoutChapter
                        case .style: styleChapter
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
            }
            .cristalScreen()
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
            .sheet(isPresented: $importsTexts) {
                QuoteTextsImportView { texts, day in applyImport(texts, from: day) }
            }
            .sheet(item: $paywall) { PaywallView(context: $0) }
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

    private func heading(_ title: String) -> some View {
        Text(title).font(.headline)
    }

    // MARK: Chapters

    @ViewBuilder private var contentChapter: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(tr("Le nom"))
            TextField(tr("Nom du widget"), text: $design.name)
                .padding(12)
                .cristalPanel(radius: 12)
                .accessibilityIdentifier("photos-name")
        }
        if design.kind == .photos {
            VStack(alignment: .leading, spacing: 10) {
                heading(tr("Les photos"))
                photosStep
            }
        } else {
            quoteStep
        }
    }

    @ViewBuilder private var layoutChapter: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(tr("La taille"))
            sizePicker
        }
        if design.kind == .photos {
            photosLayout
        } else {
            quoteLayout
        }
    }

    @ViewBuilder private var styleChapter: some View {
        quoteStyle
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
                            .strokeBorder(format == option ? strong : Color.secondary.opacity(0.4), lineWidth: 2)
                            .frame(width: size.width / 8, height: size.height / 8)
                            .frame(height: 50)
                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(format == option ? strong : Color.primary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 86)
                    .cristalPanel(radius: 14)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(format == option ? strong : .clear, lineWidth: 2)
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
                    .foregroundStyle(style.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(strong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            if photos.isEmpty {
                Text(tr("Seules les photos que tu choisis sont copiées dans Ardane : aucun accès à ta photothèque n'est demandé."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // The grid: every photo in view, no hidden scrolling.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, slot in
                        thumbnail(slot, index: index, count: photos.count)
                    }
                }
                if let slot = photos.first(where: { $0.id == selectedPhoto }), let index = photos.firstIndex(where: { $0.id == slot.id }) {
                    photoActions(slot, index: index, count: photos.count)
                } else {
                    Text(tr("Touche une photo pour la recadrer, la déplacer ou la retirer."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(rotationNote(count: photos.count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func rotationNote(count: Int) -> String {
        if design.options.daily != nil && count > 1 {
            return tr("Une photo par jour : la série passe à minuit.")
        }
        return count > PhotoLayout.capacity
            ? tr("Plus de \(PhotoLayout.capacity) photos : le widget en montre \(PhotoLayout.capacity) à la fois, puis les suivantes chaque heure.")
            : tr("La mise en page suit leur nombre : une, deux, trois ou quatre.")
    }

    private func thumbnail(_ slot: PhotoSlot, index: Int, count: Int) -> some View {
        let isOn = selectedPhoto == slot.id
        return Button {
            withAnimation(.snappy) { selectedPhoto = isOn ? nil : slot.id }
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
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isOn ? strong : .clear, lineWidth: 3)
                }
                .frame(maxWidth: .infinity)
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
                remove(slot)
            } label: {
                Label(tr("Retirer"), systemImage: "minus.circle")
            }
        }
        .accessibilityLabel(Text(tr("Photo \(index + 1)")))
        .accessibilityHint(Text(tr("Touche pour la choisir, puis recadre-la, déplace-la ou retire-la.")))
        .accessibilityIdentifier("photos-thumbnail")
    }

    /// The actions of the chosen photo, in front of the person (they used to hide in a long-press menu).
    private func photoActions(_ slot: PhotoSlot, index: Int, count: Int) -> some View {
        HStack(spacing: 6) {
            photoAction(tr("Recadrer"), "crop", id: "photos-action-frame") { framing = slot }
            photoAction(tr("Avancer"), "arrow.left", id: "photos-action-earlier", isEnabled: index > 0) { move(slot, to: index - 1) }
            photoAction(tr("Reculer"), "arrow.right", id: "photos-action-later", isEnabled: index < count - 1) { move(slot, to: index + 1) }
            photoAction(tr("Retirer"), "minus.circle", id: "photos-action-remove", isDestructive: true) { remove(slot) }
        }
    }

    private func photoAction(_ title: String, _ symbol: String, id: String, isEnabled: Bool = true, isDestructive: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.subheadline)
                Text(title).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(isDestructive ? Color.red : strong)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background((isDestructive ? Color.red : strong).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .accessibilityIdentifier(id)
    }

    private func remove(_ slot: PhotoSlot) {
        withAnimation(.snappy) {
            design.options.photos.removeAll { $0.id == slot.id }
            if selectedPhoto == slot.id { selectedPhoto = nil }
            if design.options.photos.count < 2 { design.options.daily = nil }
        }
    }

    private func move(_ slot: PhotoSlot, to index: Int) {
        guard let from = design.options.photos.firstIndex(where: { $0.id == slot.id }) else { return }
        withAnimation(.snappy) {
            let item = design.options.photos.remove(at: from)
            design.options.photos.insert(item, at: min(index, design.options.photos.count))
        }
    }

    /// « Disposition » of a photo widget: the automatic layouts, and how the series goes by (four at a time, or
    /// one per day).
    @ViewBuilder private var photosLayout: some View {
        let count = design.options.photos.count
        VStack(alignment: .leading, spacing: 10) {
            heading(tr("Mise en page automatique"))
            PhotoLayoutChoices(family: format.family, count: count, strong: strong)
        }
        VStack(alignment: .leading, spacing: 10) {
            heading(tr("Défilement"))
            Picker(tr("Défilement"), selection: Binding(
                get: { design.options.daily != nil },
                set: { isDaily in
                    withAnimation(.snappy) {
                        design.options.daily = isDaily ? DailyRotation(startDay: Date()) : nil
                    }
                }
            )) {
                Text(tr("Quatre à la fois")).tag(false)
                Text(tr("Un par jour")).tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(count < 2)
            .accessibilityIdentifier("photos-scroll")
            if count < 2 {
                Text(tr("Il faut au moins deux photos pour en changer chaque jour."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if design.options.daily != nil {
                PhotoDailyBlock(design: $design, strong: strong)
            } else {
                Text(rotationNote(count: count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Copies the chosen photos (downscaled) into the shared container, in the order they were chosen. A
    /// quote has one photo at most, behind its text: a new one takes its place.
    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        failed = 0
        var slots: [PhotoSlot] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  // Decoding and writing the photo stay off the main actor.
                  let file = await Task.detached(priority: .userInitiated, operation: { () -> String? in
                      guard let image = SafeImage.decode(data, maxDimension: 2_400) else { return nil }
                      return ImageStore.save(image, maxDimension: 1_200)
                  }).value else {
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

    /// The texts imported into this quote (« Mes textes »), nil for a quote written by hand.
    private var importedCount: Int { design.options.quote?.texts?.count ?? 0 }

    /// « Contenu » of a quote: what is written (or the imported texts), and the door to « Mes textes ».
    @ViewBuilder private var quoteStep: some View {
        let quote = quoteBinding
        VStack(alignment: .leading, spacing: 12) {
            if importedCount > 0 {
                importedCard
            } else {
                heading(tr("La citation"))
                TextField(tr("Ta citation"), text: Binding(get: { quote.wrappedValue.text }, set: { quote.wrappedValue.text = String($0.prefix(280)) }), axis: .vertical)
                    .lineLimit(3...8)
                    .padding(12)
                    .cristalPanel(radius: 12)
                    .accessibilityIdentifier("quote-text")
                TextField(tr("Auteur (facultatif)"), text: quote.author)
                    .padding(12)
                    .cristalPanel(radius: 12)
                    .accessibilityIdentifier("quote-author")
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
                textsCard
            }
        }
        .tint(strong)
    }

    /// The door to « Mes textes » on a quote written by hand.
    private var textsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tr("Mes textes"), systemImage: "square.and.arrow.down")
                .font(.headline)
            Text(tr("Importe un recueil à toi : un texte s'affiche chaque jour."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                importsTexts = true
            } label: {
                Text(tr("Importer mes textes"))
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("quote-import")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cristalPanel(radius: 16)
    }

    /// A quote made of imported texts: how many, and the ways to replace or leave them.
    private var importedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(tr("Mes textes"), systemImage: "square.and.arrow.down")
                .font(.headline)
            Text(Fmt.plural(importedCount, tr("texte importé"), tr("textes importés")))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let text = design.options.quote?.texts?.first {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 16) {
                Button(tr("Remplacer")) { importsTexts = true }
                    .accessibilityIdentifier("quote-import")
                Button(tr("Retirer mes textes"), role: .destructive) { removeTexts() }
                    .accessibilityIdentifier("quote-import-remove")
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cristalPanel(radius: 16)
    }

    /// The person's texts, one per day from the chosen day. The quote's own text becomes the first one, so that
    /// the widget can be saved and shows something where « Un par jour » can't.
    private func applyImport(_ texts: [String], from day: Date) {
        guard let first = texts.first else { return }
        var quote = quoteBinding.wrappedValue
        quote.texts = texts
        quote.text = first
        quote.author = ""
        design.options.quote = quote
        let old = design.options.daily
        design.options.daily = DailyRotation(order: old?.order ?? .inOrder, startDay: day, seed: old?.seed ?? Int.random(in: 1...1_000_000))
        withAnimation(.snappy) { chapter = .layout }
        Haptics.success()
    }

    private func removeTexts() {
        var quote = quoteBinding.wrappedValue
        quote.texts = nil
        design.options.quote = quote
        design.options.daily = nil
    }

    /// « Disposition » of a quote: the two switches, and « Un texte par jour » once texts are imported.
    @ViewBuilder private var quoteLayout: some View {
        let quote = quoteBinding
        VStack(alignment: .leading, spacing: 10) {
            Toggle(tr("Centrée"), isOn: quote.isCentered).font(.subheadline)
            Toggle(tr("Guillemets"), isOn: quote.showsMarks).font(.subheadline)
        }
        .tint(strong)
        if importedCount > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(tr("Un texte par jour"), isOn: Binding(
                    get: { design.options.daily != nil },
                    set: { isOn in
                        withAnimation(.snappy) { design.options.daily = isOn ? DailyRotation(startDay: Date()) : nil }
                    }
                ))
                .font(.subheadline.weight(.semibold))
                .tint(strong)
                .accessibilityIdentifier("quote-daily")
                if design.options.daily != nil {
                    PhotoDailyBlock(design: $design, strong: strong)
                }
            }
        }
    }

    /// « Style » of a quote: typography, color pairs, the photo behind, then the background and text colors.
    @ViewBuilder private var quoteStyle: some View {
        let quote = quoteBinding
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Typographie")).font(.headline)
            Picker(tr("Typographie"), selection: quote.font) {
                ForEach(QuoteFont.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(tr("Couleurs")).font(.headline)
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
                                            .strokeBorder(isOn ? strong : Color.primary.opacity(0.1), lineWidth: isOn ? 2.5 : 1)
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
            // The photo comes before the colors it replaces.
            backgroundSection
            let hasPhoto = design.quoteBackground != nil
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("Fond")).font(.subheadline.weight(.semibold))
                QuoteBackgroundSwatches(selectedHex: quote.wrappedValue.backgroundHex, isPremium: model.isPremium, strong: strong) { swatch, isLocked in
                    if isLocked {
                        paywall = PaywallContext(
                            symbol: "paintpalette.fill",
                            title: tr("Couleurs de fond"),
                            detail: tr("Premium ouvre toutes les couleurs de fond, comme dans le Studio."),
                            perk: .styles
                        )
                    } else {
                        quote.wrappedValue.backgroundHex = swatch.hex
                        quote.wrappedValue.textHex = readableTextHex(onBackground: swatch.hex)
                    }
                }
                HStack(spacing: 12) {
                    // Any background color is Premium, as the locked swatches above (audit 2026-11-26: the free picker
                    // went around them).
                    ColorPicker(tr("Fond"), selection: colorBinding(\.backgroundHex), supportsOpacity: false)
                        .disabled(!model.isPremium)
                    ColorPicker(tr("Texte"), selection: colorBinding(\.textHex), supportsOpacity: false)
                }
                .font(.subheadline)
                if hasPhoto {
                    Text(tr("Avec une photo, la couleur de fond ne sert que si la photo n'est plus disponible."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(hasPhoto ? 0.55 : 1)
        }
        .tint(strong)
    }

    /// The text color that reads on a background chosen from the swatches: dark on a light color, light on a dark one.
    private func readableTextHex(onBackground hex: String) -> String {
        let rgb = ColorMath.rgb(hex)
        return ColorMath.relativeLuminance(rgb.r, rgb.g, rgb.b) >= 0.5 ? "2B2622" : "F2EEE6"
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
                    .cristalPanel(radius: 12)
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
        // « Un par jour » needs something to go through: texts imported, or two photos at least.
        if saved.kind == .quote, saved.options.quote?.texts?.isEmpty ?? true { saved.options.daily = nil }
        if saved.kind == .photos, saved.options.photos.count < 2 { saved.options.daily = nil }
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
        let shown = PhotoLayout.visible(design.options.photos, daily: design.options.daily, at: Date())
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
