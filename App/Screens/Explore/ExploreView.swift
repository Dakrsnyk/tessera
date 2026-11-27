import SwiftUI
import WidgetKit

/// The Store, in aisles one under the other (the week's picks, complete Home Screens, single widgets,
/// combinations, packs, styles), each with a header in its colour and two scrolling rows; the row at
/// the top jumps to an aisle. Search and filters work across everything.
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

    /// The aisles of the Store, from the week's picks to the styles. The wallpapers come last but one, just
    /// above the styles (PDG, 2026-11-16: they are not the heart of Ardane).
    enum StoreAisle: String, CaseIterable, Identifiable {
        case featured, screens, widgets, combos, packs, themes, wallpapers, styles
        var id: String { rawValue }

        var title: String {
            switch self {
            case .featured: tr("À la une")
            case .screens: tr("Écrans d'accueil")
            case .wallpapers: tr("Fonds d'écran")
            case .widgets: tr("Widgets")
            case .combos: tr("Combinés")
            case .packs: tr("Packs")
            case .themes: tr("Packs thématiques")
            case .styles: tr("Styles")
            }
        }

        var symbol: String {
            switch self {
            case .featured: "star.fill"
            case .screens: "iphone"
            case .wallpapers: "photo.fill"
            case .widgets: "square.grid.2x2.fill"
            case .combos: "square.split.2x2.fill"
            case .packs: "shippingbox.fill"
            case .themes: "globe.americas.fill"
            case .styles: "paintpalette.fill"
            }
        }

        /// The colour of the aisle's header, so that each aisle is told apart at a glance.
        var colorHex: String {
            switch self {
            case .featured: "F2A33A"
            case .screens: "3366FF"
            case .wallpapers: "0F9BB0"
            case .widgets: "2F8F7A"
            case .combos: "6D4AE8"
            case .packs: "E5484D"
            case .themes: "1E88C8"
            case .styles: "D6409F"
            }
        }

        /// What the aisle holds, in one line.
        var hint: String {
            switch self {
            case .featured: tr("La sélection de la semaine : un écran, un style et des widgets à découvrir.")
            case .screens: tr("Des écrans d'accueil complets : widgets et fond d'écran assortis.")
            case .wallpapers: tr("Des fonds d'écran dessinés pour Ardane : mer, noir et blanc, dégradés, nuit, forêt et cosmos.")
            case .widgets: tr("Un widget à la fois, rangé par thème : temps, santé, argent…")
            case .combos: tr("Plusieurs widgets réunis en un seul, prêts à poser.")
            case .packs: tr("Des ensembles de widgets pour un usage : études, sport, voyage…")
            case .themes: tr("Un univers par pack : espace, Mars, nature, plantes et océan, avec son écran d'accueil assorti.")
            case .styles: tr("Le même widget dans chaque style : choisis l'allure qui te plaît.")
            }
        }
    }

    enum AccessFilter: String, CaseIterable, Identifiable {
        case all, free, premium
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: tr("Tous")
            case .free: tr("Gratuits")
            case .premium: tr("Premium")
            }
        }

        func allows(isPremium: Bool) -> Bool {
            switch self {
            case .all: true
            case .free: !isPremium
            case .premium: isPremium
            }
        }
    }

    private var isFiltering: Bool {
        !query.trimmed.isEmpty || access != .all || themeFilter != nil || router.exploreCategory != nil
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.storePath) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id(Self.top)
                        if isFiltering {
                            filtered
                        } else {
                            magazine(proxy)
                        }
                    }
                    .padding(.bottom, 36)
                    .tutorialScroll(step: router.tutorialStep, tab: .explore)
                    .sheet(item: $openedSetup) { setup in
                        HomeSetupSheet(setup: setup)
                    }
                }
                .onChange(of: isFiltering) { _, _ in
                    proxy.scrollTo(Self.top, anchor: .top)
                }
                .onChange(of: router.tutorialStep) { _, step in
                    if step == .store {
                        withAnimation { proxy.scrollTo(Self.top, anchor: .top) }
                    }
                }
            }
            .cristalScreen()
            .screenshotScroll()
            .navigationTitle(tr("Store"))
            .navigationDestination(for: StorePage.self) { page in
                destination(page)
            }
            .sheet(item: $openedPack) { pack in
                PackSheet(pack: pack)
            }
            .searchable(text: $query, isPresented: $isSearchPresented, prompt: tr("Écrans, packs, lune, bitcoin…"))
            .onAppear(perform: consumeRequests)
            .onChange(of: router.exploreSearchRequested) { _, _ in consumeRequests() }
            .onChange(of: router.openedSetupID) { _, _ in consumeRequests() }
            .onChange(of: router.openedPackID) { _, _ in consumeRequests() }
        }
    }

    private static let top = "store-top"

    @ViewBuilder private func destination(_ page: StorePage) -> some View {
        switch page {
        case .setups: HomeSetupsView()
        case .combos: StoreCombosView()
        case .packs: StorePacksView()
        case .collections: StoreCollectionsView()
        case let .collection(id):
            if let collection = StoreShowcase.collection(id) {
                StoreCollectionView(collection: collection)
            }
        case let .aisle(raw):
            if let aisle = StoreAisle(rawValue: raw) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(aisle.hint)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                        aisleRows(aisle)
                    }
                    .padding(.vertical, 12)
                }
                .cristalScreen()
                .navigationTitle(aisle.title)
            }
        }
    }

    private func consumeRequests() {
        if router.exploreSearchRequested {
            router.exploreSearchRequested = false
            isSearchPresented = true
        }
        if router.storePath.isEmpty, let id = router.openedSetupID {
            router.openedSetupID = nil
            openedSetup = HomeSetupCatalog.setup(id)
        }
        if let id = router.openedPackID {
            router.openedPackID = nil
            // Presented once the Store is on screen: a sheet asked for while the tab is still
            // switching can be dropped.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                openedPack = PackCatalog.pack(id)
            }
        }
    }

    /// The person's categories, each once, in the order of their interests.
    private var interests: [WidgetCategory] {
        var seen = Set<WidgetCategory>()
        return model.profile.preferredCategories.filter { seen.insert($0).inserted }
    }

    // MARK: - Magazine

    /// Every aisle, one under the other: a header in the aisle's colour, then two scrolling rows
    /// (one for the Home Screens, which are big).
    /// The Store's home (PDG, 2026-11-26): the showcase, the needs, every mini-app with its mosaics of widgets, the
    /// Home Screens and the wallpapers (no rayons any more).
    private func magazine(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 34) {
            VStack(alignment: .leading, spacing: 26) {
                featuredRows
            }
            needsRow
            // Every mini-app (the person's interests first), each with its mosaics of widgets that scroll sideways.
            LazyVStack(alignment: .leading, spacing: 34) {
                ForEach(homeMiniApps) { category in
                    miniAppSection(category)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                AisleHeader(aisle: .screens, action: seeAll(.screens))
                setupsRow
            }
            VStack(alignment: .leading, spacing: 16) {
                AisleHeader(aisle: .wallpapers, action: nil)
                WallpaperStoreSection()
            }
        }
        .padding(.top, 2)
    }

    /// « Que veux-tu sur ton écran ? »: a need opens the widgets of its mini-app (the Store's category filter);
    /// « Embellir mon écran » opens the wallpapers.
    private var needsRow: some View {
        let needs: [(title: String, symbol: String, hex: String, category: WidgetCategory?)] = [
            (tr("Ma journée"), "rectangle.3.group", "5B6CFF", .dashboards),
            (tr("Sport"), "dumbbell", "E5484D", .fitness),
            (tr("Manger mieux"), "fork.knife", "F08A24", .nutrition),
            (tr("Argent"), "creditcard", "2F8F7A", .finance),
            (tr("Études"), "graduationcap", "6D4AE8", .student),
            (tr("Voyage"), "airplane", "1E88C8", .travel),
            (tr("Embellir mon écran"), "sparkles", "D6409F", nil),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text(tr("Que veux-tu sur ton écran ?"))
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                // What the tutorial lights up on « Le Store » (the rayons before 2026-11-26).
                .background {
                    Color.clear.tutorialTarget(.storeAisles, radius: 20)
                }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(needs.enumerated()), id: \.offset) { pair in
                        let need = pair.element
                        Button {
                            Haptics.tap()
                            if let category = need.category {
                                router.exploreCategory = category
                            } else {
                                router.storePath.append(.aisle(StoreAisle.wallpapers.rawValue))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: need.symbol)
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color(hex: need.hex), in: Circle())
                                Text(need.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.leading, 8)
                            .padding(.trailing, 16)
                            .frame(minHeight: 46)
                            .cristalPanel(radius: 100)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("store-need-\(need.category?.rawValue ?? "wallpapers")")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// Every mini-app that has widgets, the person's interests first.
    private var homeMiniApps: [WidgetCategory] {
        // No Productivity in the Store (PDG, 2026-11-26).
        let all = WidgetCategory.offered.filter { $0 != .productivity && !WidgetKind.kinds(in: $0).isEmpty }
        return interests.filter(all.contains) + all.filter { !interests.contains($0) }
    }

    /// A mini-app: its name in its color, « Tout voir » (all its widgets), then its mosaic.
    private func miniAppSection(_ category: WidgetCategory) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: category.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: category.colorHex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(category.title)
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 6)
                Button {
                    router.exploreCategory = category
                } label: {
                    HStack(spacing: 3) {
                        Text(tr("Tout voir"))
                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .accessibilityLabel(Text("\(tr("Tout voir")) : \(category.title)"))
                .accessibilityIdentifier("store-miniapp-\(category.rawValue)")
            }
            .padding(.horizontal, 20)
            MiniAppMosaicRow(category: category, isPremiumUser: model.isPremium) { design in
                router.openEditor(design, isNew: true)
            }
        }
    }

    private func seeAll(_ item: StoreAisle) -> (() -> Void)? {
        switch item {
        case .screens: return { router.storePath.append(.setups) }
        case .combos: return { router.storePath.append(.combos) }
        case .packs: return { router.storePath.append(.packs) }
        case .featured, .wallpapers, .widgets, .themes, .styles: return nil
        }
    }

    @ViewBuilder private func aisleRows(_ item: StoreAisle) -> some View {
        switch item {
        case .featured: featuredRows
        case .screens: setupsRow
        case .wallpapers: WallpaperStoreSection()
        case .widgets: widgetRows
        case .combos: comboRows
        case .packs: packRows
        case .themes: themeRows
        case .styles: styleRows
        }
    }

    /// One scrolling row, with what it holds above it.
    private func shelfRow<Content: View>(_ title: String? = nil, action: (() -> Void)? = nil,
                                         @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    if let action {
                        Button(action: action) {
                            HStack(spacing: 3) {
                                Text(tr("Tout voir"))
                                Image(systemName: "chevron.right").font(.caption.weight(.bold))
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .accessibilityLabel(Text("\(tr("Tout voir")) : \(title)"))
                    }
                }
                .padding(.horizontal, 20)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    content()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
        }
    }

    /// The season's collection when there is one, the Home Screen and the style of the week, then
    /// the widgets of the week.
    @ViewBuilder private var featuredRows: some View {
        if let season = StoreSeason.current() {
            SeasonalCollection(season: season, isPremiumUser: model.isPremium) { openedPack = $0 }
        }
        let weekly = HomeSetupCatalog.weekly()
        VStack(alignment: .leading, spacing: 14) {
            Text(Fmt.longDay(Date()).uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            WeeklySetupHero(setup: weekly, isPremiumUser: model.isPremium) {
                openedSetup = weekly
            }
        }
        let style = StoreEdition.style()
        WeeklyStyleFeature(look: style, isPremiumUser: model.isPremium) {
            openStyle(style)
        }
    }

    /// Complete Home Screens, drawn as on a real iPhone: one row, they're big.
    private var setupsRow: some View {
        shelfRow {
            ForEach(HomeSetupCatalog.all) { setup in
                setupCard(setup)
            }
        }
        .padding(.vertical, 4)
    }

    private func setupCard(_ setup: HomeSetup) -> some View {
        SetupCard(
            setup: setup,
            showsPages: false,
            isFavorite: SetupFavorites.ids(favoritesRaw).contains(setup.id),
            isPremiumUser: model.isPremium,
            onFavorite: {
                Haptics.tap()
                favoritesRaw = SetupFavorites.toggled(setup.id, in: favoritesRaw)
            },
            onOpen: { openedSetup = setup }
        )
        .frame(width: 150)
    }

    /// The widgets to try first, then those of the Lock Screen.
    @ViewBuilder private var widgetRows: some View {
        LazyVStack(alignment: .leading, spacing: 30) {
            ForEach(WidgetCategory.offered.filter { $0 != .productivity && !WidgetKind.kinds(in: $0).isEmpty }) { category in
                miniAppSection(category)
            }
        }
        shelfRow(tr("Écran verrouillé")) {
            ForEach(Array(StoreShowcase.lockScreen.enumerated()), id: \.element.id) { pair in
                Button {
                    router.openEditor(pair.element.widget.makeDesign(), isNew: true)
                } label: {
                    LockShowcaseCard(item: pair.element, index: pair.offset, isPremiumUser: model.isPremium)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    /// Two small widgets in a medium one on the first row, up to four in a large one on the second.
    @ViewBuilder private var comboRows: some View {
        let combos = StoreRanking.combos(StoreComboCatalog.all, preferring: interests)
        comboShelf(combos.filter { $0.format == .medium }, height: 140)
        comboShelf(combos.filter { $0.format == .large }, height: 250)
    }

    private func comboShelf(_ combos: [StoreCombo], height: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(combos) { combo in
                    Button {
                        router.openEditor(combo.makeDesign(), isNew: true)
                    } label: {
                        ComboCard(combo: combo, height: height, isPremiumUser: model.isPremium)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// The packs of all year on two rows, the pack of the week first.
    @ViewBuilder private var packRows: some View {
        let featured = StoreEdition.pack()
        let packs = [featured] + StoreRanking.packs(preferring: interests).filter { $0.id != featured.id }
        shelfRow { packItems(packs.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)) }
        shelfRow { packItems(packs.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)) }
    }

    /// The themed worlds: their packs, then their matching Home Screens.
    @ViewBuilder private var themeRows: some View {
        shelfRow { packItems(PackCatalog.themed) }
        shelfRow(tr("Les écrans d'accueil assortis")) {
            ForEach(HomeSetupCatalog.themed) { setup in
                setupCard(setup)
            }
        }
        .padding(.bottom, 4)
    }

    private func packItems(_ packs: [WidgetPack]) -> some View {
        ForEach(packs) { pack in
            Button {
                openedPack = pack
            } label: {
                PackCard(pack: pack, isPremiumUser: model.isPremium)
            }
            .buttonStyle(.pressable)
        }
    }

    /// A style of every family on two rows, the style of the week first: a tap opens the Studio on a demonstration
    /// widget in that style (Premium ones are tried there, then offered by the Studio as for any Premium widget).
    private var styleRows: some View {
        let weekly = StoreEdition.style()
        let looks = [weekly] + StoreShowcase.allStyles.compactMap(\.look).filter { $0.id != weekly.id }
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr("Touche un style pour l'essayer sur un widget."))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(124), spacing: 14), GridItem(.fixed(124))], alignment: .top, spacing: 12) {
                    ForEach(looks) { look in
                        let design = StoreShowcase.styleItem(look).makeDesign()
                        Button {
                            openStyle(look)
                        } label: {
                            VStack(spacing: 5) {
                                WidgetPreview(design: design, family: .systemSmall, payload: SamplePayload.make(for: design), width: 86)
                                    .overlay(alignment: .topTrailing) {
                                        if look.isPremium && !model.isPremium { PremiumBadge(compact: true).padding(4) }
                                    }
                                Text(look.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 96)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(Text(tr("Style \(look.name)\(look.isPremium && !model.isPremium ? tr(", Premium") : "")")))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// The Studio on the demonstration widget, in this style, on its « Style » tool.
    private func openStyle(_ look: StyleLook) {
        router.openEditor(StoreShowcase.styleItem(look).makeDesign(), isNew: true, section: StudioSection.style.rawValue)
    }

    /// Six chosen widgets from six different categories, chosen by the team: there are no download
    /// counts to rank by.
    private var essentials: [WidgetTemplate] {
        var seen = Set<WidgetCategory>()
        let small = TemplateCatalog.featured.filter { $0.kind.families.contains(.systemSmall) }
        let varied = small.filter { seen.insert($0.kind.category).inserted }
        let rest = small.filter { template in !varied.contains { $0.id == template.id } }
        return Array((varied + rest).prefix(6))
    }

    /// Template cards: every fourth widget (and those with no small size) shown medium.
    private func templateItems(_ templates: [WidgetTemplate]) -> some View {
        ForEach(Array(templates.enumerated()), id: \.element.id) { pair in
            let template = pair.element
            let canBeMedium = template.kind.families.contains(.systemMedium)
            let family: WidgetFamily? = pair.offset % 4 == 0 && canBeMedium ? .systemMedium : nil
            templateButton(template, width: 150, family: family)
        }
    }

    // MARK: - Search and filters

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AccessFilter.allCases) { filter in
                    FilterChip(title: filter.title, isSelected: access == filter) { access = filter }
                }
                Divider().frame(height: 22)
                // What is filtered comes first, with a cross to remove it.
                if let themeFilter {
                    FilterChip(title: ThemeCatalog.theme(themeFilter).name, symbol: "xmark", isSelected: true) {
                        self.themeFilter = nil
                    }
                }
                if let category = router.exploreCategory {
                    FilterChip(title: category.title, symbol: "xmark", isSelected: true) {
                        router.exploreCategory = nil
                    }
                }
                ForEach(WidgetCategory.offered.filter { $0 != router.exploreCategory && $0 != .productivity }) { category in
                    FilterChip(title: category.title, symbol: category.symbol, isSelected: false) {
                        router.exploreCategory = category
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 4)
    }

    private var folded: String {
        query.trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
    }

    private func matches(_ texts: [String]) -> Bool {
        let q = folded
        guard !q.isEmpty else { return true }
        return texts.joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
            .contains(q)
    }

    private var templateResults: [WidgetTemplate] {
        TemplateCatalog.search(query).filter { template in
            guard access.allows(isPremium: template.isPremium) else { return false }
            if let themeFilter, template.themeID != themeFilter { return false }
            if let category = router.exploreCategory, template.kind.category != category { return false }
            return true
        }
    }

    private var comboResults: [StoreCombo] {
        StoreComboCatalog.all.filter { combo in
            guard access.allows(isPremium: combo.isPremium) else { return false }
            if let themeFilter, combo.theme != themeFilter { return false }
            if let category = router.exploreCategory, combo.category != category { return false }
            return matches([combo.name, combo.tagline, combo.category.title] + combo.parts.map(\.kind.title))
        }
    }

    private var packResults: [WidgetPack] {
        PackCatalog.all.filter { pack in
            guard access.allows(isPremium: pack.isPremium) else { return false }
            if let themeFilter, pack.themeID != themeFilter { return false }
            if let category = router.exploreCategory, !pack.kinds.contains(where: { $0.category == category }) { return false }
            return matches([pack.name, pack.tagline] + pack.kinds.map(\.title))
        }
    }

    /// Screens are found by words only: they mix categories and styles.
    private var setupResults: [HomeSetup] {
        guard !folded.isEmpty, themeFilter == nil, router.exploreCategory == nil else { return [] }
        return HomeSetupCatalog.all.filter { setup in
            access.allows(isPremium: setup.isPremium) && matches([setup.name, setup.tagline] + setup.tags.map(\.title))
        }
    }

    @ViewBuilder private var filtered: some View {
        let templates = templateResults
        let combos = comboResults
        let packs = packResults
        let setups = setupResults
        VStack(alignment: .leading, spacing: 30) {
            filters
            if templates.isEmpty && combos.isEmpty && packs.isEmpty && setups.isEmpty {
                EmptyStateView(
                    symbol: "magnifyingglass",
                    title: tr("Aucun résultat"),
                    message: tr("Essaie un autre mot, ou retire un filtre."),
                    actionTitle: tr("Tout afficher")
                ) {
                    query = ""
                    access = .all
                    themeFilter = nil
                    router.exploreCategory = nil
                }
            } else {
                if !setups.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        MagazineHeader(title: tr("Écrans d'accueil"), subtitle: Fmt.plural(setups.count, tr("écran"), tr("écrans")))
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 14) {
                                ForEach(setups) { setup in
                                    SetupCard(
                                        setup: setup,
                                        showsPages: false,
                                        isFavorite: SetupFavorites.ids(favoritesRaw).contains(setup.id),
                                        isPremiumUser: model.isPremium,
                                        onFavorite: { favoritesRaw = SetupFavorites.toggled(setup.id, in: favoritesRaw) },
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
                if !combos.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        MagazineHeader(title: tr("Combinaisons"), subtitle: Fmt.plural(combos.count, tr("combinaison"), tr("combinaisons")))
                        comboShelf(combos, height: 140)
                    }
                }
                if !packs.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        MagazineHeader(title: tr("Packs"), subtitle: Fmt.plural(packs.count, tr("pack"), tr("packs")))
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 16) {
                                ForEach(packs) { pack in
                                    Button {
                                        openedPack = pack
                                    } label: {
                                        PackCard(pack: pack, isPremiumUser: model.isPremium)
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                if !templates.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        MagazineHeader(title: tr("Widgets"), subtitle: Fmt.plural(templates.count, tr("widget"), tr("widgets")))
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], alignment: .leading, spacing: 20) {
                            ForEach(templates) { template in
                                templateButton(template, width: nil)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    private func templateButton(_ template: WidgetTemplate, width: CGFloat?, family: WidgetFamily? = nil) -> some View {
        Button {
            router.openEditor(template.makeDesign(), isNew: true)
        } label: {
            TemplateCard(template: template, width: width, isPremiumUser: model.isPremium, family: family)
        }
        .buttonStyle(.pressable)
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
            .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .modifier(FilterChipSurface(isSelected: isSelected))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The chip's surface: the action color when chosen, a Cristal panel (a capsule at 36 pt) otherwise.
private struct FilterChipSurface: ViewModifier {
    let isSelected: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if isSelected {
            content.background(Color.accentColor, in: Capsule())
        } else {
            content.cristalPanel(radius: 100)   // a capsule at any height (large text)
        }
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
                            Text(tr("Aa"))
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
        .accessibilityLabel(Text(tr("Style \(theme.name)\(showsLock ? tr(", Premium") : "")")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PackSheet: View {
    let pack: WidgetPack
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var designs: [WidgetDesign] = []
    @State private var configures = false

    private var needsPremium: Bool { pack.isPremium && !model.isPremium }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(pack.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    let smalls = designs.filter { $0.kind.families.contains(.systemSmall) }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                        ForEach(smalls) { design in
                            packItem(design, family: .systemSmall)
                        }
                    }
                    // Widgets that exist only in medium or large, across the width.
                    ForEach(designs.filter { !$0.kind.families.contains(.systemSmall) }) { design in
                        packItem(design, family: .systemMedium)
                    }
                    if designs.contains(where: { !model.hasOwnData(for: $0) }) {
                        Label(tr("Les widgets marqués « Exemple » montrent des données d'exemple. Tu donneras les tiennes dans le Studio, widget par widget."), systemImage: "sparkles")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .cristalScreen()
            .safeAreaInset(edge: .bottom) {
                Button {
                    if needsPremium {
                        dismiss()
                        router.showPaywall(.pack(pack.name, designs: designs))
                    } else {
                        configures = true
                    }
                } label: {
                    Text(needsPremium ? tr("Débloquer avec Premium") : tr("Personnaliser et ajouter"))
                        .font(.headline)
                        .foregroundStyle(.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(AppFill.screenFill.opacity(0.96))
                .accessibilityIdentifier("pack-configure")
            }
            .navigationTitle(pack.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $configures) {
                // Selection, then editing as in the Studio: every widget of the set, one after the other.
                if !designs.isEmpty {
                    WidgetStudio(request: EditorRequest(designs: designs, isNew: true), isPushed: true) { dismiss() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Fermer")) { dismiss() }
                }
            }
        }
        .onAppear {
            if designs.isEmpty { designs = pack.designs() }
            // Test captures: straight to the step-by-step setup.
            if router.startsPackSetup {
                router.startsPackSetup = false
                configures = true
            }
        }
    }

    /// A widget of the pack: the person's data when they gave it, marked example data otherwise.
    private func packItem(_ design: WidgetDesign, family: WidgetFamily) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetPreview(design: design, family: family, payload: model.previewPayload(for: design))
                .overlay(alignment: .topTrailing) {
                    if !model.hasOwnData(for: design) {
                        ExampleBadge().scaleEffect(0.85).padding(6)
                    }
                }
            Text(design.kind.title).font(.caption.weight(.semibold)).lineLimit(1)
        }
    }
}

/// The header of an aisle of the Store: its symbol in its colour, its name, what it holds.
struct AisleHeader: View {
    let aisle: ExploreView.StoreAisle
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(Color(hex: aisle.colorHex).opacity(0.5))
                .frame(height: 2)
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: aisle.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: aisle.colorHex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(aisle.title)
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(aisle.hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if let action {
                    Button(action: action) {
                        HStack(spacing: 3) {
                            Text(tr("Tout voir"))
                            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel(Text("\(tr("Tout voir")) : \(aisle.title)"))
                }
            }
        }
        .padding(.horizontal, 20)
    }
}
