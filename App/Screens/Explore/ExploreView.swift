import SwiftUI
import WidgetKit

struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var access: AccessFilter = .all
    @State private var themeFilter: ThemeID?
    @State private var isSearchPresented = false
    @State private var openedPack: WidgetPack?
    @State private var openedSetup: HomeSetup?
    @AppStorage(SetupFavorites.key) private var favoritesRaw = ""

    enum AccessFilter: String, CaseIterable, Identifiable {
        case all, free, premium
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "Tous"
            case .free: "Gratuits"
            case .premium: "Premium"
            }
        }
    }

    private var isFiltering: Bool {
        !query.trimmed.isEmpty || access != .all || themeFilter != nil || router.exploreCategory != nil
    }

    private var results: [WidgetTemplate] {
        TemplateCatalog.search(query).filter { template in
            switch access {
            case .all: break
            case .free: if template.isPremium { return false }
            case .premium: if !template.isPremium { return false }
            }
            if let themeFilter, template.themeID != themeFilter { return false }
            if let category = router.exploreCategory, template.kind.category != category { return false }
            return true
        }
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    filters
                    if isFiltering {
                        resultsGrid
                    } else {
                        shelves
                    }
                }
                .padding(.bottom, 32)
                .sheet(item: $openedSetup) { setup in
                    HomeSetupSheet(setup: setup)
                }
            }
            .background(Color.screenFill)
            .screenshotScroll()
            .navigationTitle("Store")
            .sheet(item: $openedPack) { pack in
                PackSheet(pack: pack)
            }
            .navigationDestination(isPresented: $router.showsAllSetups) {
                HomeSetupsView()
            }
            .searchable(text: $query, isPresented: $isSearchPresented, prompt: "Météo, tâches, bitcoin…")
            .onAppear(perform: consumeSearchRequest)
            .onChange(of: router.exploreSearchRequested) { _, _ in consumeSearchRequest() }
        }
        // Backgrounds come from the current style: rebuilt when it changes.
        .id(model.settings.appStyle)
    }

    private func consumeSearchRequest() {
        if router.exploreSearchRequested {
            router.exploreSearchRequested = false
            isSearchPresented = true
        }
        if !router.showsAllSetups, let id = router.openedSetupID {
            router.openedSetupID = nil
            openedSetup = HomeSetupCatalog.setup(id)
        }
    }

    // MARK: Filters

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AccessFilter.allCases) { filter in
                    FilterChip(title: filter.title, isSelected: access == filter) { access = filter }
                }
                Divider().frame(height: 22)
                ForEach(WidgetCategory.allCases) { category in
                    FilterChip(title: category.title, symbol: category.symbol, isSelected: router.exploreCategory == category) {
                        router.exploreCategory = router.exploreCategory == category ? nil : category
                    }
                }
                if let themeFilter {
                    FilterChip(title: ThemeCatalog.theme(themeFilter).name, symbol: "xmark", isSelected: true) {
                        self.themeFilter = nil
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 4)
    }

    // MARK: Shelves (default view)

    /// The Store front: from complete screens to single widgets, every size, style and color.
    private var shelves: some View {
        LazyVStack(alignment: .leading, spacing: 32) {
            featuresCarousel
            setupsShelf
            showcaseShelf(title: "Widgets moyens", subtitle: "Deux fois plus de place, pour tout voir d'un coup d'œil.", items: StoreShowcase.mediums)
            packsShelf
            ForEach(StoreShowcase.collectionsTop) { collection in
                showcaseShelf(title: collection.title, subtitle: collection.subtitle, symbol: collection.symbol, items: collection.items)
            }
            showcaseShelf(title: "Un widget, 12 styles", subtitle: "Le même compte à rebours, dans chaque style.", items: StoreShowcase.allStyles)
            showcaseShelf(title: "Grands formats", subtitle: "Ta semaine, ton mois ou ta journée entière.", items: StoreShowcase.larges, height: 250)
            ForEach(StoreShowcase.collectionsBottom) { collection in
                showcaseShelf(title: collection.title, subtitle: collection.subtitle, symbol: collection.symbol, items: collection.items)
            }
            lockScreenShelf
            showcaseShelf(title: "Toutes les couleurs", subtitle: "Choisis la tienne, ou n'importe quelle autre avec Premium.", items: StoreShowcase.allColors)
            shelf(title: "Nouveautés", templates: TemplateCatalog.newest)
            stylesShelf
            ForEach(WidgetCategory.allCases) { category in
                let templates = TemplateCatalog.all.filter { $0.kind.category == category }
                shelf(title: category.title, templates: templates) {
                    router.exploreCategory = category
                }
            }
        }
    }

    private func shelfHeader(title: String, subtitle: String?, symbol: String? = nil, seeAll: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
                SectionHeader(title: title, actionTitle: seeAll == nil ? nil : "Tout voir", action: seeAll)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    /// Template shelves: every fourth widget (and those with no small size) shown medium.
    private func shelf(title: String, templates: [WidgetTemplate], seeAll: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            shelfHeader(title: title, subtitle: nil, seeAll: seeAll)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(templates.enumerated()), id: \.element.id) { pair in
                        let template = pair.element
                        let canBeMedium = template.kind.families.contains(.systemMedium)
                        let family: WidgetFamily? = pair.offset % 4 == 0 && canBeMedium ? .systemMedium : nil
                        templateButton(template, width: 150, family: family)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func showcaseShelf(title: String, subtitle: String?, symbol: String? = nil, items: [ShowcaseItem], height: CGFloat = 150) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            shelfHeader(title: title, subtitle: subtitle, symbol: symbol)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(items) { item in
                        Button {
                            router.openEditor(item.widget.makeDesign(), isNew: true)
                        } label: {
                            ShowcaseCard(item: item, height: height, isPremiumUser: model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// Big cards, one per page, each with a medium widget.
    private var featuresCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(StoreShowcase.features) { feature in
                    Button {
                        router.openEditor(feature.widget.makeDesign(), isNew: true)
                    } label: {
                        StoreFeatureCard(feature: feature, isPremiumUser: model.isPremium)
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
    }

    private var lockScreenShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            shelfHeader(title: "Écran verrouillé", subtitle: "Sous l'heure, d'un coup d'œil, sans déverrouiller.", symbol: "lock.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(StoreShowcase.lockScreen.enumerated()), id: \.element.id) { pair in
                        Button {
                            router.openEditor(pair.element.widget.makeDesign(), isNew: true)
                        } label: {
                            LockShowcaseCard(item: pair.element, index: pair.offset, isPremiumUser: model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// Complete Home Screens, drawn as on a real iPhone.
    private var setupsShelf: some View {
        let favorites = SetupFavorites.ids(favoritesRaw)
        return VStack(alignment: .leading, spacing: 12) {
            shelfHeader(title: "Écrans d'accueil", subtitle: "Fond, widgets et écran verrouillé assortis.") {
                router.showsAllSetups = true
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(HomeSetupCatalog.all) { setup in
                        SetupCard(
                            setup: setup,
                            showsPages: false,
                            isFavorite: favorites.contains(setup.id),
                            isPremiumUser: model.isPremium,
                            onFavorite: {
                                Haptics.tap()
                                favoritesRaw = SetupFavorites.toggled(setup.id, in: favoritesRaw)
                            },
                            onOpen: { openedSetup = setup }
                        )
                        .frame(width: 150)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }

    private var packsShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            shelfHeader(title: "Packs", subtitle: "Six widgets assortis, ajoutés d'une touche.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(PackCatalog.all) { pack in
                        Button {
                            openedPack = pack
                        } label: {
                            PackCard(pack: pack, isPremiumUser: model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var stylesShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            shelfHeader(title: "Styles", subtitle: "Touche un style pour voir tous ses widgets.")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemeCatalog.all) { theme in
                        Button {
                            themeFilter = theme.id
                        } label: {
                            ThemeSwatch(theme: theme, accentHex: Palette.defaultAccent, isSelected: false, showsLock: theme.isPremium && !model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: Results

    @ViewBuilder private var resultsGrid: some View {
        let items = results
        if items.isEmpty {
            EmptyStateView(
                symbol: "magnifyingglass",
                title: "Aucun résultat",
                message: "Essaie un autre mot, ou retire un filtre.",
                actionTitle: "Tout afficher"
            ) {
                query = ""
                access = .all
                themeFilter = nil
                router.exploreCategory = nil
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], alignment: .leading, spacing: 20) {
                ForEach(items) { template in
                    templateButton(template, width: nil)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func templateButton(_ template: WidgetTemplate, width: CGFloat?, family: WidgetFamily? = nil) -> some View {
        Button {
            router.openEditor(template.makeDesign(), isNew: true)
        } label: {
            TemplateCard(template: template, width: width, isPremiumUser: model.isPremium, family: family)
        }
        .buttonStyle(.plain)
    }
}

struct FilterChip: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color.onAccent : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isSelected ? Color.accentColor : Color.cardFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small card showing how a theme looks: its background, "Aa" in its font and its tint.
struct ThemeSwatch: View {
    let theme: WidgetTheme
    let accentHex: String
    let isSelected: Bool
    var showsLock = false

    var body: some View {
        let design = WidgetDesign(kind: .note, themeID: theme.id, accentHex: accentHex)
        let style = ResolvedStyle(design: design)
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                DesignBackground(design: design)
                    .frame(width: 76, height: 76)
                    .overlay {
                        VStack(spacing: 4) {
                            Text("Aa")
                                .font(.system(size: 24, weight: theme.numberWeight, design: theme.fontDesign))
                                .foregroundStyle(style.primary)
                            Capsule().fill(style.accent).frame(width: 26, height: 4)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 3 : 1)
                    }
                if showsLock {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.premiumInk)
                        .padding(4)
                        .background(Color.premiumFill, in: Circle())
                        .padding(5)
                }
            }
            Text(theme.name)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Style \(theme.name)\(showsLock ? ", Premium" : "")"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A pack in the Store: three of its widgets stacked, its name and what it contains.
struct PackCard: View {
    let pack: WidgetPack
    let isPremiumUser: Bool

    var body: some View {
        let designs = pack.designs()
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(designs.prefix(3).enumerated().reversed()), id: \.offset) { pair in
                    WidgetPreview(design: pair.element, family: .systemSmall, payload: SamplePayload.make(for: pair.element), width: 104)
                        .rotationEffect(.degrees(Double(pair.offset - 1) * 6))
                        .offset(x: CGFloat(pair.offset) * 34, y: CGFloat(pair.offset) * 4)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }
            }
            .frame(width: 190, height: 124, alignment: .topLeading)
            .padding(.top, 6)
            HStack(spacing: 6) {
                Image(systemName: pack.symbol).foregroundStyle(Color(hex: pack.accentHex))
                Text(pack.name).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if pack.isPremium && !isPremiumUser { PremiumBadge(compact: true) }
            }
            Text(pack.tagline)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 200, alignment: .leading)
        .card(padding: 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Pack \(pack.name), \(pack.kinds.count) widgets"))
    }
}

struct PackSheet: View {
    let pack: WidgetPack
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var installed: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(pack.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                        ForEach(pack.designs()) { design in
                            VStack(alignment: .leading, spacing: 6) {
                                WidgetPreview(design: design, family: .systemSmall, payload: model.payload(for: design))
                                Text(design.kind.title).font(.caption.weight(.semibold)).lineLimit(1)
                            }
                        }
                    }
                    if let installed {
                        Label(installed == pack.kinds.count ? "Pack ajouté à Mes widgets" : "\(Fmt.plural(installed, "widget ajouté", "widgets ajoutés")) (limite de la version gratuite)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(20)
            }
            .background(Color.screenFill)
            .safeAreaInset(edge: .bottom) {
                Button {
                    install()
                } label: {
                    Text(installed == nil ? (pack.isPremium && !model.isPremium ? "Débloquer avec Premium" : "Ajouter le pack") : "Voir comment l'ajouter à l'écran")
                        .font(.headline)
                        .foregroundStyle(Color.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(Color.screenFill.opacity(0.96))
            }
            .navigationTitle(pack.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func install() {
        if installed != nil {
            dismiss()
            router.lastSavedName = pack.name
            router.isAddGuidePresented = true
            return
        }
        if pack.isPremium && !model.isPremium {
            dismiss()
            router.isPaywallPresented = true
            return
        }
        installed = model.install(pack)
        Haptics.success()
    }
}
