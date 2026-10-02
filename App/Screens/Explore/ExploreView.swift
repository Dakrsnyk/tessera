import SwiftUI
import WidgetKit

/// The Store, laid out like a magazine: this week's Home Screen on the cover, then complete screens,
/// combinations, packs, collections and single widgets, each under a clear heading.
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
                            magazine
                        }
                    }
                    .padding(.bottom, 36)
                    .sheet(item: $openedSetup) { setup in
                        HomeSetupSheet(setup: setup)
                    }
                }
                .onChange(of: isFiltering) { _, _ in
                    proxy.scrollTo(Self.top, anchor: .top)
                }
                .onChange(of: router.tutorialStep) { _, step in
                    if step == .store { withAnimation { proxy.scrollTo(Self.top, anchor: .top) } }
                }
            }
            .background(.screenFill)
            .screenshotScroll()
            .navigationTitle(tr("Store"))
            .navigationDestination(for: StorePage.self) { page in
                destination(page)
            }
            .sheet(item: $openedPack) { pack in
                PackSheet(pack: pack)
            }
            .searchable(text: $query, isPresented: $isSearchPresented, prompt: tr("Écrans, packs, météo, bitcoin…"))
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

    private var magazine: some View {
        let weekly = HomeSetupCatalog.weekly()
        return LazyVStack(alignment: .leading, spacing: 38) {
            VStack(alignment: .leading, spacing: 14) {
                Text(Fmt.longDay(Date()).uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                WeeklySetupHero(setup: weekly, isPremiumUser: model.isPremium) {
                    openedSetup = weekly
                }
                .tutorialTarget(.storeHero)
            }
            setupsSection(excluding: weekly.id)
            if !forYou.isEmpty {
                forYouSection
            }
            combosSection
            packsSection
            collectionsSection
            Group {
                essentialsSection
                lockScreenSection
                stylesSection
                newestSection
                categoriesSection
            }
        }
        .padding(.top, 2)
    }

    /// Complete Home Screens, drawn as on a real iPhone.
    private func setupsSection(excluding weeklyID: String) -> some View {
        let favorites = SetupFavorites.ids(favoritesRaw)
        let setups = HomeSetupCatalog.all.filter { $0.id != weeklyID }
        return VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(
                eyebrow: tr("Clé en main"),
                title: tr("Écrans d'accueil"),
                subtitle: tr("Fond d'écran, widgets et écran verrouillé assortis, installés en quelques touches.")
            ) {
                router.storePath.append(.setups)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(setups) { setup in
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

    /// Widgets of the categories the person is interested in, one per kind.
    private var forYou: [WidgetTemplate] {
        var seen = Set<WidgetKind>()
        return interests
            .flatMap { category in TemplateCatalog.all.filter { $0.kind.category == category } }
            .filter { seen.insert($0.kind).inserted }
            .prefix(14)
            .map { $0 }
    }

    private var forYouSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(eyebrow: tr("Selon tes centres d'intérêt"), title: tr("Pour toi"))
            templateShelf(forYou)
        }
    }

    /// Two small widgets in a medium one, up to four in a large one.
    private var combosSection: some View {
        let combos = StoreRanking.combos(StoreComboCatalog.all, preferring: interests)
        let mediums = combos.filter { $0.format == .medium }
        let larges = combos.filter { $0.format == .large }
        return VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(
                eyebrow: tr("Plusieurs en un"),
                title: tr("Combinaisons"),
                subtitle: tr("\(StoreComboCatalog.all.count) widgets qui en réunissent plusieurs : deux dans un moyen, jusqu'à quatre dans un grand.")
            ) {
                router.storePath.append(.combos)
            }
            comboShelf(mediums, height: 140)
            comboShelf(larges, height: 250)
        }
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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// The pack of the week, big, then every other pack.
    private var packsSection: some View {
        let featured = StoreEdition.pack()
        let others = StoreRanking.packs(preferring: interests).filter { $0.id != featured.id }
        return VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(
                eyebrow: tr("Six widgets assortis"),
                title: tr("Packs"),
                subtitle: tr("Un style, une couleur, six widgets ajoutés d'une touche à Mes widgets.")
            ) {
                router.storePath.append(.packs)
            }
            Button {
                openedPack = featured
            } label: {
                PackFeature(pack: featured, isPremiumUser: model.isPremium)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(others) { pack in
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

    private var collectionsSection: some View {
        let collections = Array(StoreShowcase.collections(preferring: interests).prefix(4))
        return VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(
                eyebrow: tr("Sélections"),
                title: tr("Collections"),
                subtitle: tr("Des widgets réunis autour d'un thème, d'une taille ou d'un style.")
            ) {
                router.storePath.append(.collections)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(collections) { collection in
                    Button {
                        router.storePath.append(.collection(collection.id))
                    } label: {
                        CollectionTile(collection: collection)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// Chosen by the team: there are no download counts to rank by.
    private var essentialsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(eyebrow: tr("Notre sélection"), title: tr("Incontournables"), subtitle: tr("Les widgets à essayer en premier."))
            EssentialsList(templates: essentials, isPremiumUser: model.isPremium) { template in
                router.openEditor(template.makeDesign(), isNew: true)
            }
            .padding(.horizontal, 20)
        }
    }

    /// Six chosen widgets from six different categories.
    private var essentials: [WidgetTemplate] {
        var seen = Set<WidgetCategory>()
        let small = TemplateCatalog.featured.filter { $0.kind.families.contains(.systemSmall) }
        let varied = small.filter { seen.insert($0.kind.category).inserted }
        let rest = small.filter { template in !varied.contains { $0.id == template.id } }
        return Array((varied + rest).prefix(6))
    }

    private var lockScreenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(eyebrow: tr("Sous l'heure"), title: tr("Écran verrouillé"), subtitle: tr("D'un coup d'œil, sans déverrouiller ton iPhone."))
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

    private var stylesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(eyebrow: tr("12 styles"), title: tr("Styles"), subtitle: tr("Touche un style pour voir tous ses widgets."))
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

    private var newestSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(eyebrow: tr("Vient d'arriver"), title: tr("Nouveautés"))
            templateShelf(TemplateCatalog.newest)
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MagazineHeader(eyebrow: tr("Tout le catalogue"), title: tr("Catégories"))
            CategoryIndex(categories: interests + WidgetCategory.allCases.filter { !interests.contains($0) }) { category in
                router.exploreCategory = category
            }
            .padding(.horizontal, 20)
        }
    }

    /// Template shelves: every fourth widget (and those with no small size) shown medium.
    private func templateShelf(_ templates: [WidgetTemplate]) -> some View {
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
                ForEach(WidgetCategory.allCases.filter { $0 != router.exploreCategory }) { category in
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
                                    .buttonStyle(.plain)
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
            .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.cardFill), in: Capsule())
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
            .background(.screenFill)
            .safeAreaInset(edge: .bottom) {
                Button {
                    if needsPremium {
                        dismiss()
                        router.isPaywallPresented = true
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
