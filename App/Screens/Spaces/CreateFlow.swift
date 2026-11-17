import SwiftUI
import WidgetKit

// The start of Créer since 2026-11-16 (the PDG's « taille d'abord »): a size, then a category, then the widgets of
// that category, up to the room of the size, made into ONE widget. In Petit the touch on a widget opens the Atelier;
// in Moyen (2 at most) and Grand (4 at most) « Personnaliser le widget » does. Never several separate widgets.

/// Where the start of Créer is.
enum CreateStep: Hashable {
    case size
    case category(WidgetFormat)
    case pick(WidgetFormat, CreateCategory)

    /// The step the back button goes to: the widgets → the categories → the size (which stays).
    var back: CreateStep {
        switch self {
        case .size, .category: .size
        case let .pick(format, _): .category(format)
        }
    }
}

/// A category of Créer: a space, the time widgets that have none (« Heure et date »), or photos and quotes.
enum CreateCategory: Hashable, Identifiable {
    case space(Space)
    case time
    case photos

    var id: String {
        switch self {
        case let .space(space): "space-\(space.rawValue)"
        case .time: "time"
        case .photos: "photos"
        }
    }

    /// The person's interests first, then the other spaces; « Heure et date » first, photos and quotes last.
    static func all(preferred: [Space]) -> [CreateCategory] {
        let spaces = preferred + Space.allCases.filter { !preferred.contains($0) }
        return [.time] + spaces.map { .space($0) } + [.photos]
    }

    var title: String {
        switch self {
        case let .space(space): space.title
        case .time: tr("Heure et date")
        case .photos: tr("Photos et citations")
        }
    }

    var symbol: String {
        switch self {
        case let .space(space): space.symbol
        case .time: "clock"
        case .photos: MiniApp.photos.symbol
        }
    }

    var colorHex: String {
        switch self {
        case let .space(space): space.colorHex
        case .time: "5B6CFF"
        case .photos: "EC4899"
        }
    }

    /// The widgets it offers. Photos and quotes have their own editor: none here.
    var kinds: [WidgetKind] {
        switch self {
        case let .space(space): SpaceCatalog.kinds(in: space)
        case .time: WidgetKind.offered.filter { $0.space == nil && $0.category == .time }
        case .photos: []
        }
    }

    /// The widgets that can go in a widget of this size (alone or with others).
    func kinds(for format: WidgetFormat) -> [WidgetKind] {
        kinds.filter { kind in
            switch format {
            case .small: kind.families.contains(.systemSmall)
            case .medium, .large: kind.families.contains(.systemSmall) || kind.families.contains(.systemMedium)
            }
        }
    }
}

/// The widgets picked for the creation, at the size chosen first: what can still be added, and the one widget it makes.
struct CreationDraft: Equatable {
    let format: WidgetFormat
    var picked: [WidgetKind] = []

    /// How many widgets the size holds: 1 in Petit, 2 in Moyen, 4 in Grand.
    var room: Int { Composer.widgetLimit(for: format) }

    var plan: Composer.Plan { Composer.plan(picked, format: format) }

    /// One widget can be made from the picks.
    var isReady: Bool {
        guard !picked.isEmpty else { return false }
        if case .invalid = plan { return false }
        return true
    }

    /// Why the picks don't make a widget yet (the composer's own words), or nil.
    var blocker: String? {
        guard !picked.isEmpty, case let .invalid(message) = plan else { return nil }
        return message
    }

    /// Why a widget can't be added now, or nil. A picked one is never refused: touching it takes it out.
    func refusal(adding kind: WidgetKind) -> String? {
        if picked.contains(kind) { return nil }
        if picked.count >= room {
            switch format {
            case .small: return nil
            case .medium: return tr("Un widget moyen réunit 2 widgets au plus.")
            case .large: return tr("Un grand widget réunit 4 widgets au plus.")
            }
        }
        switch format {
        case .small:
            if case let .invalid(message) = Composer.plan([kind], format: .small) { return message }
            return nil
        case .medium:
            // Alone it shows its medium layout; beside another one both must exist in small.
            if picked.isEmpty { return nil }
            if case let .invalid(message) = Composer.plan(picked + [kind], format: .medium) { return message }
            return nil
        case .large:
            // Large is checked as a whole once done (a row holds 1 medium or 2 small): any row-sized widget may go in.
            return nil
        }
    }

    /// Adds a widget, or takes it out if it was picked. In Petit a new pick replaces the old one.
    mutating func toggle(_ kind: WidgetKind) {
        // Petit: the touch always takes the widget (back from the Atelier, the same touch opens it again).
        if format == .small {
            if refusal(adding: kind) == nil { picked = [kind] }
            return
        }
        if let index = picked.firstIndex(of: kind) {
            picked.remove(at: index)
        } else if refusal(adding: kind) == nil {
            picked.append(kind)
        }
    }

    /// The one widget this creation makes, or nil while the picks don't make one.
    var design: WidgetDesign? { Self.design(for: picked, format: format) }

    /// One widget at the size: a widget alone in its layout for that size, or the widgets combined.
    static func design(for kinds: [WidgetKind], format: WidgetFormat) -> WidgetDesign? {
        switch Composer.plan(kinds, format: format) {
        case let .single(kind):
            var design = SpaceCatalog.design(for: kind)
            design.format = format
            return design
        case let .combo(slots):
            let base = SpaceCatalog.design(for: slots[0].kind)
            var options = DesignOptions()
            options.parts = slots.map { slot in
                let part = SpaceCatalog.design(for: slot.kind)
                return ComboPart(kind: slot.kind, options: part.options, name: part.name, size: slot.size)
            }
            return WidgetDesign(
                name: slots.map { SpaceCatalog.design(for: $0.kind).name }.joined(separator: " + "),
                kind: slots[0].kind, themeID: base.themeID, accentHex: base.accentHex,
                options: options, format: format
            )
        case .invalid:
            return nil
        }
    }
}

// MARK: - The three pages

/// The start of Créer: the size, the category, the widgets, on one screen whose step changes (the Atelier is pushed on it).
struct CreateFlowView: View {
    @Binding var step: CreateStep
    /// The Atelier on the one widget made.
    let onOpen: (EditorRequest) -> Void
    /// « Widget d'écran verrouillé »: the Lock Screen widgets in a sheet.
    let onLockScreen: () -> Void

    @Environment(AppModel.self) private var model
    @State private var choosesPhotoQuote = false
    @State private var photoDraft: PhotoQuoteDraft?
    @State private var paywall: PaywallContext?

    var body: some View {
        content
            .cristalScreen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(step == .size ? .large : .inline)
            .toolbar {
                if step != .size {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Haptics.tap()
                            back()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                        .accessibilityLabel(Text(tr("Retour", context: "back")))
                        .accessibilityIdentifier("create-back")
                    }
                }
            }
            .confirmationDialog(tr("Créer un widget"), isPresented: $choosesPhotoQuote, titleVisibility: .visible) {
                Button(tr("Photos")) { startPhotoQuote(.photos) }
                Button(tr("Citation")) { startPhotoQuote(.quote) }
            }
            .sheet(item: $photoDraft) { draft in
                PhotoQuoteEditor(draft: draft)
            }
            .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .size:
            CreateSizePage(onSize: { format in go(.category(format)) }, onLockScreen: onLockScreen)
        case let .category(format):
            CreateCategoryPage(format: format) { category in
                if category == .photos {
                    choosesPhotoQuote = true
                } else {
                    go(.pick(format, category))
                }
            }
        case let .pick(format, category):
            CreatePickPage(format: format, category: category) { design in
                onOpen(EditorRequest(design: design, isNew: true, section: StudioSection.size.rawValue))
            }
            .id("\(format.rawValue)-\(category.id)")
        }
    }

    private var title: String {
        switch step {
        case .size: tr("Créer")
        case let .category(format): format.title
        case let .pick(_, category): category.title
        }
    }

    private func go(_ next: CreateStep) {
        withAnimation(.easeInOut(duration: 0.22)) { step = next }
    }

    private func back() {
        if step != .size { go(step.back) }
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
}

/// Page 1: Petit, Moyen or Grand, each at its real proportion with its places; a discreet link to the Lock Screen.
private struct CreateSizePage: View {
    let onSize: (WidgetFormat) -> Void
    let onLockScreen: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Quelle taille pour ton widget ?"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.primary)
                        .accessibilityAddTraits(.isHeader)
                    Text(tr("Tu pourras y réunir plusieurs widgets d'une même catégorie."))
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    ForEach(WidgetFormat.allCases) { format in
                        SizeCard(format: format) { onSize(format) }
                            .tutorialTarget(.createSpace, radius: 24, when: format == WidgetFormat.allCases.first)
                    }
                }
                Button {
                    Haptics.tap()
                    onLockScreen()
                } label: {
                    Label(tr("Widget d'écran verrouillé"), systemImage: "lock.rectangle.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("create-lock")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .screenshotScroll()
        .accessibilityIdentifier("create-start")
    }
}

/// A size, at the proportion iOS gives it (158 × 158, 338 × 158, 338 × 354 points), split into its places.
private struct SizeCard: View {
    let format: WidgetFormat
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                SizeSilhouette(format: format, scale: 0.42)
                    .frame(width: 150)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.primary)
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(room)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .padding(.top, 2)
                    Text(tr("La place de \(icons) icônes"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondary)
            }
            .padding(14)
            .cristalPanel(radius: 24)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("create-size-\(format.rawValue)")
    }

    private var summary: String {
        switch format {
        case .small: tr("L'essentiel en un coup d'œil.")
        case .medium: tr("Plus d'informations : un widget dans sa version moyenne, ou 2 widgets réunis côte à côte.")
        case .large: tr("Un tableau de bord de l'espace : un widget en grand, ou jusqu'à 4 widgets réunis.")
        }
    }

    private var room: String {
        switch format {
        case .small: tr("1 widget")
        case .medium: tr("1 ou 2 widgets")
        case .large: tr("1 à 4 widgets")
        }
    }

    private var icons: String {
        switch format {
        case .small: "4"
        case .medium: "8"
        case .large: "16"
        }
    }
}

/// The outline of a widget of a size, with its places: 1 in Petit, 2 side by side in Moyen, 2 × 2 in Grand.
private struct SizeSilhouette: View {
    let format: WidgetFormat
    let scale: CGFloat
    @Environment(\.appStyle) private var style

    var body: some View {
        let palette = CristalPalette.of(style.id)
        let size = Self.points(format)
        let columns = format == .small ? 1 : 2
        let rows = format == .large ? 2 : 1
        RoundedRectangle(cornerRadius: 16 * scale / 0.42, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .overlay {
                VStack(spacing: 5) {
                    ForEach(0..<rows, id: \.self) { _ in
                        HStack(spacing: 5) {
                            ForEach(0..<columns, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .foregroundStyle(Color.secondary.opacity(0.5))
                                    .background(palette.well2Color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                            }
                        }
                    }
                }
                .padding(5)
            }
            .frame(width: size.width * scale, height: size.height * scale)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    static func points(_ format: WidgetFormat) -> CGSize {
        switch format {
        case .small: CGSize(width: 158, height: 158)
        case .medium: CGSize(width: 338, height: 158)
        case .large: CGSize(width: 338, height: 354)
        }
    }
}

/// Page 2: the categories of Ardane, with how many widgets each has at the size chosen.
private struct CreateCategoryPage: View {
    let format: WidgetFormat
    let onCategory: (CreateCategory) -> Void
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Quelle catégorie ?"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.primary)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(CreateCategory.all(preferred: model.profile.preferredSpaces)) { category in
                        let count = category == .photos ? 2 : category.kinds(for: format).count
                        if count > 0 {
                            CategoryCard(category: category, count: count) { onCategory(category) }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .screenshotScroll()
    }
}

private struct CategoryCard: View {
    let category: CreateCategory
    let count: Int
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: category.colorHex), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(Fmt.plural(count, tr("widget"), tr("widgets")))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 58)
            .cristalPanel(radius: 18)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("create-category-\(category.id)")
    }
}

/// Page 3: the widgets of the category. The places of the size, taken or free, the count, and whether the
/// result is one widget alone or a combined widget. In Petit the touch opens the Atelier.
private struct CreatePickPage: View {
    let category: CreateCategory
    let onDone: (WidgetDesign) -> Void
    @State private var draft: CreationDraft
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    init(format: WidgetFormat, category: CreateCategory, onDone: @escaping (WidgetDesign) -> Void) {
        self.category = category
        self.onDone = onDone
        _draft = State(initialValue: CreationDraft(format: format))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PlacesCard(draft: draft)
                Text(tr("Widgets de \(category.title)"))
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(category.kinds(for: draft.format)) { kind in
                        tile(kind)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .screenshotScroll()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if draft.format != .small { goBar }
        }
    }

    private func tile(_ kind: WidgetKind) -> some View {
        let refusal = draft.refusal(adding: kind)
        let number = draft.picked.firstIndex(of: kind).map { $0 + 1 }
        return Button {
            Haptics.tap()
            pick(kind)
        } label: {
            StudioKindTile(kind: kind, design: SpaceCatalog.design(for: kind), payload: model.previewPayload(for: SpaceCatalog.design(for: kind)),
                           showsLock: kind.isPremium && !model.isPremium, refusal: refusal, isCurrent: number != nil)
                .overlay(alignment: .topLeading) {
                    if let number {
                        Text(verbatim: "\(number)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.accentColor, in: Circle())
                            .offset(x: -4, y: -4)
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(.pressable)
        .disabled(refusal != nil)
        .accessibilityValue(Text(number != nil ? tr("Choisi") : (refusal ?? "")))
        .accessibilityIdentifier("create-pick-\(kind.rawValue)")
    }

    private func pick(_ kind: WidgetKind) {
        withAnimation(.easeInOut(duration: 0.2)) { draft.toggle(kind) }
        // Petit holds one widget: the touch opens the Atelier on it.
        if draft.format == .small, let design = draft.design {
            onDone(design)
        }
    }

    private var goBar: some View {
        VStack(spacing: 6) {
            Button {
                Haptics.tap()
                if let design = draft.design { onDone(design) }
            } label: {
                Text(tr("Personnaliser le widget"))
                    .font(.headline)
                    .foregroundStyle(draft.isReady ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!draft.isReady)
            .accessibilityIdentifier("create-pick-go")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// The widget as it will be, live: the first widget alone fills the whole size, a second one splits it (PDG,
/// 2026-11-16). Before any pick, or while the picks don't make a widget yet, the places of the size (taken or
/// free) stand in for it. Then the count and the result.
private struct PlacesCard: View {
    let draft: CreationDraft
    @Environment(\.appStyle) private var style
    @Environment(AppModel.self) private var model

    var body: some View {
        let palette = CristalPalette.of(style.id)
        VStack(spacing: 10) {
            preview(palette: palette)
                .animation(.easeInOut(duration: 0.25), value: draft.picked)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<draft.room, id: \.self) { index in
                        Circle()
                            .fill(index < draft.picked.count ? Color.accentColor : Color.secondary.opacity(0.25))
                            .frame(width: 9, height: 9)
                    }
                }
                .accessibilityHidden(true)
                Text(tr("\(draft.picked.count) sur \(draft.room)"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.primary)
                kindBadge
            }
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .cristalPanel(radius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("create-places")
    }

    /// The real widget (the one the Atelier will open), or the places while there is none yet.
    @ViewBuilder private func preview(palette: CristalPalette) -> some View {
        if let design = draft.design {
            WidgetPreview(design: design, family: draft.format.family, payload: model.previewPayload(for: design), width: previewWidth)
                .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.opacity)
                .id(draft.picked)
        } else {
            places(palette: palette)
        }
    }

    private var previewWidth: CGFloat {
        switch draft.format {
        case .small: 150
        case .medium: 300
        case .large: 220
        }
    }

    /// The outline of the size, its places filled in order with the widgets picked.
    private func places(palette: CristalPalette) -> some View {
        let columns = draft.format == .small ? 1 : 2
        let rows = draft.format == .large ? 2 : 1
        let size = SizeSilhouette.points(draft.format)
        let width: CGFloat = previewWidth
        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.95))
            .overlay {
                VStack(spacing: 6) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<columns, id: \.self) { column in
                                place(row * columns + column, palette: palette)
                            }
                        }
                    }
                }
                .padding(7)
            }
            .frame(width: width, height: width * size.height / size.width)
            .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
            .accessibilityHidden(true)
    }

    @ViewBuilder private func place(_ index: Int, palette: CristalPalette) -> some View {
        if index < draft.picked.count {
            let kind = draft.picked[index]
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .overlay {
                    VStack(spacing: 3) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(kind.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(4)
                }
                .overlay(alignment: .topLeading) {
                    Text(verbatim: "\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.primary, in: Circle())
                        .padding(4)
                }
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundStyle(Color.secondary.opacity(0.5))
                .background(palette.well2Color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    VStack(spacing: 2) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text(tr("Ajouter"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                    }
                }
        }
    }

    private var kindBadge: some View {
        let combined = draft.picked.count > 1
        return Label {
            Text(combined ? tr("Combiné · \(draft.picked.count) widgets") : tr("Widget simple"))
        } icon: {
            Image(systemName: combined ? "square.stack.3d.up.fill" : "square.fill")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(combined ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.primary))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(combined ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.secondary.opacity(0.14)), in: Capsule())
    }

    /// What to know now: how to start, what is missing, how many places are left, or the limit.
    private var message: String? {
        if draft.format == .small { return tr("Touche un widget : l'Atelier s'ouvre aussitôt.") }
        if let blocker = draft.blocker { return blocker }
        let left = draft.room - draft.picked.count
        if draft.picked.isEmpty { return tr("Choisis jusqu'à \(draft.room) widgets : ils seront réunis en un seul.") }
        if left > 0 { return Fmt.plural(left, tr("place libre : tu peux encore ajouter un widget."), tr("places libres : tu peux encore ajouter des widgets.")) }
        return draft.format == .medium ? tr("Un widget moyen réunit 2 widgets au plus.") : tr("Un grand widget réunit 4 widgets au plus.")
    }
}
