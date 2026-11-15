import SwiftUI
import WidgetKit

/// The start screen of the Créer tab: « Pour toi » (a ready widget per favourite space), « Partir de zéro »
/// (a size or the Lock Screen), « Partir d'un modèle » (a combo of the Store, a copy of one of Mes widgets) and
/// « Photos et citations ». It only builds requests for the Studio, which the Créer tab pushes (`onOpen`).
struct CreateStartView: View {
    /// What the Studio opens on (a new widget).
    let onOpen: (EditorRequest) -> Void
    /// « Écran verrouillé »: the Créer tab opens the Lock Screen widgets in a sheet.
    let onLockScreen: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.appStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var duplicating = false
    @State private var choosesPhotoQuote = false
    /// A photo or quote widget being made.
    @State private var photoDraft: PhotoQuoteDraft?
    @State private var paywall: PaywallContext?
    /// « Pour toi »: one ready widget per space, with a stable id (built on appearing and when its inputs change).
    @State private var forYou: [ForYouItem] = []

    private struct ForYouItem: Identifiable {
        let space: Space
        let design: WidgetDesign
        var id: Space { space }
    }

    init(onOpen: @escaping (EditorRequest) -> Void, onLockScreen: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onLockScreen = onLockScreen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                forYouSection
                    .tutorialTarget(.createSpace)
                scratchSection
                modelSection
                photosSection
            }
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .cristalScreen()
        .screenshotScroll()
        .navigationTitle(tr("Créer"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { if forYou.isEmpty { rebuildForYou() } }
        .onChange(of: model.profile.preferredSpaces) { _, _ in rebuildForYou() }
        .onChange(of: model.isPremium) { _, _ in rebuildForYou() }
        .sheet(isPresented: $duplicating) {
            DuplicatePicker { design in
                duplicating = false
                onOpen(Self.request(design: Self.copy(of: design)))
            }
        }
        .sheet(item: $photoDraft) { draft in
            PhotoQuoteEditor(draft: draft)
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
        .accessibilityIdentifier("create-start")
    }

    // MARK: Requests

    /// The Studio on a new widget, on its content.
    private static func request(design: WidgetDesign) -> EditorRequest {
        EditorRequest(design: design, isNew: true, section: StudioSection.size.rawValue)
    }

    /// The same widget as a new one: its own id and name, nothing saved yet.
    private static func copy(of design: WidgetDesign) -> WidgetDesign {
        var copy = design
        copy.id = UUID()
        copy.name = tr("\(design.name) (copie)")
        copy.createdAt = Date()
        copy.isFavorite = false
        // A background photo is copied under its own name: deleting the original never empties the copy.
        copy.background = Fusion.ownBackground(of: design.background)
        return copy
    }

    /// The widget a size starts from: the proposal (small) at that size when it exists there, else a widget of the
    /// spaces that does (a free one first, a Premium one only with Premium), else the proposal in small (the tile
    /// says so), with its list of widgets ready to receive a « + ».
    private func scratchRequest(_ format: WidgetFormat) -> EditorRequest {
        var design = SpaceCatalog.proposal(for: model.profile.preferredSpaces, isPremium: model.isPremium)
        if format != .small, !design.kind.families.contains(format.family), let kind = scratchKind(format) {
            design = SpaceCatalog.design(for: kind)
            if !model.isPremium { design = design.downgradedForFree() }
        }
        if format != .small, design.kind.families.contains(format.family) {
            design.format = format
        }
        return Self.request(design: design)
    }

    /// A widget of the spaces (the favourites first) that exists at this size: a free one first, a Premium one only
    /// with Premium.
    private func scratchKind(_ format: WidgetFormat) -> WidgetKind? {
        let preferred = model.profile.preferredSpaces
        let spaces = preferred + Space.allCases.filter { !preferred.contains($0) }
        let found = spaces.flatMap { SpaceCatalog.kinds(in: $0) }.filter { $0.families.contains(format.family) }
        return found.first { !$0.isPremium } ?? (model.isPremium ? found.first : nil)
    }

    /// The tile's note when no widget exists at this size for this account, so the Studio opens in small.
    private func scratchNote(_ format: WidgetFormat) -> String? {
        guard format != .small else { return nil }
        let proposal = SpaceCatalog.proposal(for: model.profile.preferredSpaces, isPremium: model.isPremium)
        if proposal.kind.families.contains(format.family) || scratchKind(format) != nil { return nil }
        return tr("S'ouvre en Petit")
    }

    // MARK: Pour toi

    /// Six spaces at most: the favourites first, then the others.
    private var forYouSpaces: [Space] {
        let preferred = model.profile.preferredSpaces
        return Array((preferred + Space.allCases.filter { !preferred.contains($0) }).prefix(6))
    }

    /// The compositions are built once (each with its own id, which the previews are prepared for), and again only
    /// when the favourite spaces or Premium change.
    private func rebuildForYou() {
        forYou = forYouSpaces.map { ForYouItem(space: $0, design: SpaceCatalog.startDesign(for: $0, isPremium: model.isPremium)) }
    }

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                header(tr("Pour toi"))
                Spacer(minLength: 8)
                if !model.profile.preferredSpaces.isEmpty {
                    Text(tr("Tes espaces préférés"))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(forYou) { item in
                        ForYouCard(space: item.space, design: item.design) {
                            Haptics.tap()
                            onOpen(Self.request(design: item.design))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Partir de zéro

    private var scratchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(tr("Partir de zéro"))
            // Four tiles in a row; two by two once the text is large (« Écran verrouillé » would be cut).
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize >= .xxLarge ? 2 : 4),
                spacing: 10
            ) {
                ScratchTile(title: WidgetFormat.small.title, shape: .small) {
                    onOpen(scratchRequest(.small))
                }
                .accessibilityIdentifier("create-scratch-small")
                ScratchTile(title: WidgetFormat.medium.title, shape: .medium, note: scratchNote(.medium)) {
                    onOpen(scratchRequest(.medium))
                }
                .accessibilityIdentifier("create-scratch-medium")
                ScratchTile(title: WidgetFormat.large.title, shape: .large, note: scratchNote(.large)) {
                    onOpen(scratchRequest(.large))
                }
                .accessibilityIdentifier("create-scratch-large")
                ScratchTile(title: tr("Écran verrouillé"), shape: .lock) {
                    onLockScreen()
                }
                .accessibilityIdentifier("create-scratch-lock")
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Partir d'un modèle

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(tr("Partir d'un modèle"))
            VStack(spacing: 10) {
                StartRow(symbol: "square.grid.2x2", title: tr("Un combiné du Store"), subtitle: tr("Déjà réuni, à ajuster")) {
                    openStoreCombos()
                }
                .accessibilityIdentifier("create-from-store")
                StartRow(symbol: "plus.square.on.square", title: tr("Dupliquer un de mes widgets"), subtitle: tr("Depuis Mes widgets")) {
                    duplicating = true
                }
                .accessibilityIdentifier("create-duplicate")
            }
            .padding(.horizontal, 20)
        }
    }

    /// The Store tab on its combos page. The page is pushed once the tab is on screen (switching tab and
    /// pushing in the same instant leaves the previous page showing).
    private func openStoreCombos() {
        router.tab = .explore
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            router.storePath = [.combos]
        }
    }

    // MARK: Photos et citations

    private var photosSection: some View {
        StartRow(symbol: MiniApp.photos.symbol, title: tr("Photos et citations"), subtitle: tr("Illimitées, même en gratuit")) {
            choosesPhotoQuote = true
        }
        .accessibilityIdentifier("create-photos")
        .padding(.horizontal, 20)
        .confirmationDialog(tr("Créer un widget"), isPresented: $choosesPhotoQuote, titleVisibility: .visible) {
            Button(tr("Photos")) { startPhotoQuote(.photos) }
            Button(tr("Citation")) { startPhotoQuote(.quote) }
        }
    }

    /// The rule of every new widget: photos and quotes don't count toward the free limit.
    private func startPhotoQuote(_ kind: WidgetKind) {
        let draft = PhotoQuoteDraft.blank(kind)
        if model.canSave(adding: [draft.design]) {
            photoDraft = draft
        } else {
            paywall = .designLimit
        }
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(Color.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Pieces

/// A ready medium widget of a space, with its real preview, name, space and size, and what it costs.
private struct ForYouCard: View {
    let space: Space
    let design: WidgetDesign
    let action: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let format = design.displayFormat
        let subtitle = space.title + " · " + format.title
        let isPremiumWidget = design.usesPremiumKind
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                WidgetPreview(design: design, family: format.family, payload: model.previewPayload(for: design), width: format == .small ? 150 : 248)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(design.name)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    if isPremiumWidget {
                        if !model.isPremium { lockPill }
                    } else {
                        freePill
                    }
                }
            }
            .padding(16)
            .frame(width: 280, alignment: .leading)
            .cristalPanel(radius: 26)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.pressable)
        .task(id: design.id) { await model.prepare(design) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(design.name), \(subtitle), " + (isPremiumWidget ? tr("Premium") : tr("Gratuit"))))
        .accessibilityHint(Text(tr("Ouvre l'Atelier sur ce widget")))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("create-for-you-\(space.rawValue)")
    }

    private var freePill: some View {
        Text(tr("Gratuit"))
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(CristalPalette.of(style.id).tintColor, in: Capsule())
    }

    private var lockPill: some View {
        Label(tr("Premium"), systemImage: "lock.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.premiumInk)
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .background(Color.premiumFill, in: Capsule())
    }

    @Environment(\.appStyle) private var style
}

/// A size to start from: its silhouette and its name.
private struct ScratchTile: View {
    enum Silhouette { case small, medium, large, lock }

    let title: String
    let shape: Silhouette
    /// Said under the name when the tile doesn't open what it shows (no widget exists at this size).
    var note: String?
    let action: () -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 10) {
                silhouette
                    .frame(height: 54)
                    .accessibilityHidden(true)
                VStack(spacing: 2) {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    if let note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 96)
            .cristalPanel(radius: 22)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder private var silhouette: some View {
        let palette = CristalPalette.of(style.id)
        switch shape {
        case .small: outline(width: 36, height: 36, palette: palette)
        case .medium: outline(width: 56, height: 32, palette: palette)
        case .large: outline(width: 46, height: 50, palette: palette)
        case .lock:
            outline(width: 28, height: 50, palette: palette)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.secondary)
                }
        }
    }

    private func outline(width: CGFloat, height: CGFloat, palette: CristalPalette) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(palette.well2Color)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 2)
            }
            .frame(width: width, height: height)
    }
}

/// A row of « Partir d'un modèle » and « Photos et citations »: a round icon, two lines, a chevron.
private struct StartRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(palette.tintColor, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .cristalPanel(radius: 22)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

/// « Dupliquer un de mes widgets »: Mes widgets as thumbnails; the one touched opens as a copy.
private struct DuplicatePicker: View {
    let onChoose: (WidgetDesign) -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// Photo and quote widgets are copied from Mes widgets, which also copies their photos.
    private var designs: [WidgetDesign] {
        model.recentDesigns.filter { !$0.kind.isMadeInItsMiniApp }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if designs.isEmpty {
                    Text(tr("Tu n'as pas encore de widget à copier. Crée-en un, puis reviens ici."))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(32)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14, alignment: .top), GridItem(.flexible(), spacing: 14, alignment: .top)], spacing: 18) {
                        ForEach(designs) { design in
                            Button {
                                Haptics.tap()
                                onChoose(design)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    WidgetPreview(design: design, family: design.displayFormat.family, payload: model.previewPayload(for: design))
                                    Text(design.name)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel(Text(design.name))
                            .accessibilityIdentifier("duplicate-pick-\(design.id.uuidString)")
                        }
                    }
                    .padding(20)
                }
            }
            .cristalScreen()
            .navigationTitle(tr("Dupliquer un widget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Annuler")) { dismiss() }
                }
            }
            .task {
                for design in designs { await model.prepare(design) }
            }
        }
    }
}

// MARK: - « Pour toi »

extension SpaceCatalog {
    /// The medium widget « Pour toi » offers for a space: what the space creator selects first at that size,
    /// built the way it builds it (`Composer`, one `ComboPart` per widget), on the look of the space's first
    /// widget. Without Premium its look is made free too. When the pair doesn't fit, the space's small widget.
    static func startDesign(for space: Space, isPremium: Bool) -> WidgetDesign {
        let first = preset(for: space, format: .small).first ?? .note
        let base = Self.design(for: first)
        var result: WidgetDesign
        switch Composer.plan(preset(for: space, format: .medium), format: .medium) {
        case let .single(kind):
            result = Self.design(for: kind)
            result.themeID = base.themeID
            result.accentHex = base.accentHex
            result.format = .medium
        case let .combo(slots):
            var options = DesignOptions()
            options.parts = slots.map { slot in
                let part = Self.design(for: slot.kind)
                return ComboPart(kind: slot.kind, options: part.options, name: part.name, size: slot.size)
            }
            result = WidgetDesign(
                name: slots.map { Self.design(for: $0.kind).name }.joined(separator: " + "),
                kind: slots[0].kind, themeID: base.themeID, accentHex: base.accentHex,
                options: options, format: .medium
            )
        case .invalid:
            result = base
            result.format = .small
        }
        return isPremium ? result : result.downgradedForFree()
    }
}
