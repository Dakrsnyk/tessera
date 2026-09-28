import SwiftUI
import WidgetKit

struct ExploreView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var access: AccessFilter = .all
    @State private var themeFilter: ThemeID?
    @State private var isSearchPresented = false

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
            }
            .background(Color.screenFill)
            .screenshotScroll()
            .navigationTitle("Explorer")
            .searchable(text: $query, isPresented: $isSearchPresented, prompt: "Météo, tâches, bitcoin…")
            .onAppear(perform: consumeSearchRequest)
            .onChange(of: router.exploreSearchRequested) { _, _ in consumeSearchRequest() }
        }
    }

    private func consumeSearchRequest() {
        if router.exploreSearchRequested {
            router.exploreSearchRequested = false
            isSearchPresented = true
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

    private var shelves: some View {
        VStack(alignment: .leading, spacing: 30) {
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

    private func shelf(title: String, templates: [WidgetTemplate], seeAll: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, actionTitle: seeAll == nil ? nil : "Tout voir", action: seeAll)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(templates) { template in
                        templateButton(template, width: 150)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var stylesShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Styles")
                .padding(.horizontal, 20)
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

    private func templateButton(_ template: WidgetTemplate, width: CGFloat?) -> some View {
        Button {
            router.openEditor(template.makeDesign(), isNew: true)
        } label: {
            TemplateCard(template: template, width: width, isPremiumUser: model.isPremium)
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
            .foregroundStyle(isSelected ? Color.white : Color.primary)
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
