import SwiftUI
import WidgetKit

// MARK: - Magazine pieces

/// A section title of the Store: a hairline, a small colored kicker, a big title and a line of context.
struct MagazineHeader: View {
    var eyebrow: String?
    let title: String
    var subtitle: String?
    var actionTitle = "Tout voir"
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1)
                .padding(.bottom, 12)
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.accentColor)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let action {
                    Button(action: action) {
                        HStack(spacing: 3) {
                            Text(actionTitle)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel(Text("\(actionTitle) : \(title)"))
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
    }
}

/// The cover of the Store: this week's Home Screen, on its own wallpaper, next to the phone that shows it.
struct WeeklySetupHero: View {
    let setup: HomeSetup
    let isPremiumUser: Bool
    let onOpen: () -> Void

    private var ink: Color { setup.ink }
    private var scrim: Color { setup.wallpaper.isLight ? .white : .black }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Écran d'accueil\nde la semaine".uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(ink.opacity(0.85))
                    Text(setup.name)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(setup.tagline)
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Text("\(Fmt.plural(setup.widgets.count, "widget", "widgets")) · fond d'écran assorti")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text("Installer")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(setup.wallpaper.isLight ? Color.white : Color.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(setup.wallpaper.isLight ? Color(hex: setup.wallpaper.darkInk) : Color.white, in: Capsule())
                        if setup.isPremium && !isPremiumUser {
                            PremiumBadge(compact: true)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SetupScreenshot(setup: setup, page: .home)
                    .frame(width: 146)
                    .overlay { SetupScreenShape().stroke(Color.white.opacity(0.3), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            }
            .padding(20)
            .frame(height: 360)
            .background { wallpaper }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Écran d'accueil de la semaine : \(setup.name). \(setup.tagline)"))
        .accessibilityHint(Text("Ouvre l'écran pour l'installer"))
    }

    /// The setup's wallpaper, scaled to cover the card, its middle band showing.
    private var wallpaper: some View {
        GeometryReader { geo in
            let scale = max(geo.size.width / SetupScreen.size.width, geo.size.height / SetupScreen.size.height)
            SetupWallpaperView(wallpaper: setup.wallpaper)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .overlay {
            LinearGradient(colors: [scrim.opacity(0.55), scrim.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// A collection in the Store: its color, one of its widgets peeking out, its name.
struct CollectionTile: View {
    let collection: StoreCollection
    var height: CGFloat = 150

    var body: some View {
        let cover = collection.cover
        let design = cover.widget.makeDesign()
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Color(hex: collection.colorHex)
                RadialGradient(colors: [.white.opacity(0.24), .clear], center: .topTrailing, startRadius: 0, endRadius: 200)
                LinearGradient(colors: [.black.opacity(0.02), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            }
            WidgetPreview(design: design, family: cover.widget.family, payload: SamplePayload.make(for: design), width: 78)
                .rotationEffect(.degrees(9))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .padding(.top, 10)
                .padding(.trailing, -10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            VStack(alignment: .leading, spacing: 2) {
                Image(systemName: collection.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Spacer(minLength: 0)
                Text(collection.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(Fmt.plural(collection.items.count, "widget", "widgets"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Collection \(collection.title), \(collection.items.count) widgets"))
        .accessibilityAddTraits(.isButton)
    }
}

/// A pack in the Store: three of its widgets fanned on its color, its name and what it holds.
struct PackCard: View {
    let pack: WidgetPack
    let isPremiumUser: Bool
    /// Nil: the width offered.
    var width: CGFloat? = 250

    var body: some View {
        let fan = Array(pack.smallDesigns().prefix(3))
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                // The two side widgets first, the middle one on top.
                ForEach([1, 2, 0].filter { $0 < fan.count }, id: \.self) { index in
                    let position = index == 0 ? 0 : (index == 1 ? -1 : 1)
                    WidgetPreview(design: fan[index], family: .systemSmall, payload: SamplePayload.make(for: fan[index]), width: 92)
                        .rotationEffect(.degrees(Double(position) * 9))
                        .offset(x: CGFloat(position) * 64, y: position == 0 ? -4 : 8)
                        .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(Color(hex: pack.accentHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: pack.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: pack.accentHex), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(pack.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    // In a shelf, the style only (every pack holds six widgets, as the heading says).
                    Text(width == nil ? "\(pack.kinds.count) widgets · \(ThemeCatalog.theme(pack.themeID).name)" : "Style \(ThemeCatalog.theme(pack.themeID).name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if pack.isPremium && !isPremiumUser {
                    PremiumBadge(compact: true)
                } else {
                    GetLabel()
                }
            }
            Text(pack.tagline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Pack \(pack.name), \(pack.kinds.count) widgets. \(pack.tagline)"))
    }
}

/// Widgets of any Home Screen size: small ones two by two, medium and large ones across the width.
struct ShowcaseGrid: View {
    let items: [ShowcaseItem]
    let isPremiumUser: Bool
    let onOpen: (ShowcaseItem) -> Void

    private var rows: [[ShowcaseItem]] {
        var rows: [[ShowcaseItem]] = []
        var waiting: ShowcaseItem?
        for item in items {
            if item.widget.family == .systemSmall {
                if let first = waiting {
                    rows.append([first, item])
                    waiting = nil
                } else {
                    waiting = item
                }
            } else {
                rows.append([item])
            }
        }
        if let waiting { rows.append([waiting]) }
        return rows
    }

    var body: some View {
        VStack(spacing: 22) {
            ForEach(Array(rows.enumerated()), id: \.offset) { pair in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(pair.element) { item in
                        Button {
                            onOpen(item)
                        } label: {
                            ShowcaseTile(item: item, isPremiumUser: isPremiumUser)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if pair.element.count == 1 && pair.element[0].widget.family == .systemSmall {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
    }
}

/// A widget at the width offered, with its name, its look and Premium.
private struct ShowcaseTile: View {
    let item: ShowcaseItem
    let isPremiumUser: Bool

    var body: some View {
        let design = item.widget.makeDesign()
        VStack(alignment: .leading, spacing: 8) {
            WidgetPreview(design: design, family: item.widget.family, payload: SamplePayload.make(for: design))
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(item.subtitle) · \(item.widget.family.shortTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if design.usesPremiumFeatures && !isPremiumUser {
                    PremiumBadge(compact: true)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Ouvre l'éditeur"))
    }
}

// MARK: - Pages

/// One collection: its cover and every widget in it.
struct StoreCollectionView: View {
    let collection: StoreCollection
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                cover
                ShowcaseGrid(items: collection.items, isPremiumUser: model.isPremium) { item in
                    router.openEditor(item.widget.makeDesign(), isNew: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(.screenFill)
        .screenshotScroll()
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: collection.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer(minLength: 18)
            Text("Collection".uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.8))
            Text(collection.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text(collection.subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            Text(Fmt.plural(collection.items.count, "widget", "widgets"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
        .background {
            ZStack {
                Color(hex: collection.colorHex)
                RadialGradient(colors: [.white.opacity(0.24), .clear], center: .topTrailing, startRadius: 0, endRadius: 320)
                LinearGradient(colors: [.black.opacity(0.02), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Every collection, the ones matching the person's interests first.
struct StoreCollectionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Des sélections de widgets autour d'un thème, d'un format ou d'un style.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(StoreShowcase.collections(preferring: model.profile.preferredCategories)) { collection in
                        Button {
                            router.storePath.append(.collection(collection.id))
                        } label: {
                            CollectionTile(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(.screenFill)
        .screenshotScroll()
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Every pack, free or Premium.
struct StorePacksView: View {
    @Environment(AppModel.self) private var model
    @State private var access: ExploreView.AccessFilter = .all
    @State private var openedPack: WidgetPack?

    private var packs: [WidgetPack] {
        StoreRanking.packs(preferring: model.profile.preferredCategories).filter { pack in
            switch access {
            case .all: true
            case .free: !pack.isPremium
            case .premium: pack.isPremium
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Six widgets assortis, dans le même style, ajoutés d'une touche à Mes widgets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(ExploreView.AccessFilter.allCases) { filter in
                        FilterChip(title: filter.title, isSelected: access == filter) { access = filter }
                    }
                }
                LazyVStack(spacing: 28) {
                    ForEach(packs) { pack in
                        Button {
                            openedPack = pack
                        } label: {
                            PackCard(pack: pack, isPremiumUser: model.isPremium, width: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(.screenFill)
        .screenshotScroll()
        .navigationTitle("Packs")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $openedPack) { pack in
            PackSheet(pack: pack)
        }
    }
}

/// The person's interests first, wherever the Store lists things.
enum StoreRanking {
    /// Packs whose widgets match an interest first (the earliest interest wins), catalog order otherwise.
    static func packs(preferring categories: [WidgetCategory]) -> [WidgetPack] {
        func rank(_ pack: WidgetPack) -> Int {
            pack.kinds.compactMap { categories.firstIndex(of: $0.category) }.min() ?? Int.max
        }
        return PackCatalog.all.enumerated()
            .sorted { lhs, rhs in
                let left = rank(lhs.element)
                let right = rank(rhs.element)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }

    /// Combinations of the person's categories first, the others after.
    static func combos(_ combos: [StoreCombo], preferring categories: [WidgetCategory]) -> [StoreCombo] {
        func rank(_ combo: StoreCombo) -> Int {
            categories.firstIndex(of: combo.category) ?? Int.max
        }
        return combos.enumerated()
            .sorted { lhs, rhs in
                let left = rank(lhs.element)
                let right = rank(rhs.element)
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }
}

// MARK: - This week's edition

/// What the Store puts forward: the same all week, something else the next week.
enum StoreEdition {
    static func week(_ now: Date = Date()) -> Int {
        Calendar(identifier: .iso8601).component(.weekOfYear, from: now)
    }

    /// The pack of the week (shifted from the Home Screen of the week, so they don't always pair up).
    static func pack(now: Date = Date()) -> WidgetPack {
        PackCatalog.all[(week(now) * 7 + 3) % PackCatalog.all.count]
    }
}

/// The pack of the week, across the page: its six widgets on its color, its name and what it holds.
struct PackFeature: View {
    let pack: WidgetPack
    let isPremiumUser: Bool

    var body: some View {
        let smalls = pack.smallDesigns()
        let designs = Array(smalls.prefix(smalls.count >= 6 ? 6 : 3))
        let accent = Color(hex: pack.accentHex)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pack de la semaine".uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(pack.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(pack.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: pack.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(designs) { design in
                    WidgetPreview(design: design, family: .systemSmall, payload: SamplePayload.make(for: design))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                }
            }
            HStack(spacing: 10) {
                Text("\(pack.kinds.count) widgets · style \(ThemeCatalog.theme(pack.themeID).name)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
                if pack.isPremium && !isPremiumUser {
                    PremiumBadge(compact: true)
                }
                Text("Ajouter")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.white, in: Capsule())
            }
        }
        .padding(18)
        .background {
            ZStack {
                accent
                RadialGradient(colors: [.white.opacity(0.28), .clear], center: .topTrailing, startRadius: 0, endRadius: 320)
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.42)], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pack de la semaine : \(pack.name), \(pack.kinds.count) widgets. \(pack.tagline)"))
        .accessibilityAddTraits(.isButton)
    }
}

/// A short numbered list of widgets, as in the charts of a magazine.
struct EssentialsList: View {
    let templates: [WidgetTemplate]
    let isPremiumUser: Bool
    let onOpen: (WidgetTemplate) -> Void

    private var shown: [WidgetTemplate] {
        templates.filter { $0.kind.families.contains(.systemSmall) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { pair in
                let template = pair.element
                let design = template.makeDesign()
                Button {
                    onOpen(template)
                } label: {
                    HStack(spacing: 14) {
                        Text("\(pair.offset + 1)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        WidgetPreview(design: design, family: .systemSmall, payload: SamplePayload.make(for: design), width: 58)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(template.kind.category.title) · \(template.theme.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        if template.isPremium && !isPremiumUser {
                            PremiumBadge(compact: true)
                        } else {
                            GetLabel()
                        }
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text("Ouvre l'éditeur"))
                if pair.offset < shown.count - 1 {
                    Divider().padding(.leading, 34)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Every category, as the index at the back of a magazine.
struct CategoryIndex: View {
    let categories: [WidgetCategory]
    let onOpen: (WidgetCategory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element) { pair in
                let category = pair.element
                let count = WidgetKind.allCases.filter { $0.category == category }.count
                Button {
                    onOpen(category)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: category.colorHex), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Text(category.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 6)
                        Text(Fmt.plural(count, "widget", "widgets"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("store-category-\(category.rawValue)")
                if pair.offset < categories.count - 1 {
                    Divider().padding(.leading, 44)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
