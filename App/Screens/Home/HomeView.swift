import SwiftUI
import WidgetKit

/// Home: the greeting, « Mon Quotidien » (the figures of the day), « Mes informations », the person's
/// widgets as they sit on a Home Screen, and a taste of the Store.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    /// The Store shelf picked on Home; by default « Pour toi » once interests are known.
    @State private var chosenShelf: StoreShelf?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    DailySection()
                    MiniAppsRow()
                    MyInfoCard()
                    myWidgets
                    storeSample
                    if !model.isPremium {
                        PremiumBanner { router.isPaywallPresented = true }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(.screenFill)
            .screenshotScroll()
            .navigationTitle("Tessera")
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case let .space(space):
                    // A space with its mini-app opens the mini-app; the others show their data.
                    if let app = MiniApp(space: space), app.isBuilt {
                        MiniAppView(app: app)
                    } else {
                        SpaceView(space: space, isEmbedded: true)
                    }
                case .info: MyInfoView()
                case let .infoArea(area): InfoAreaView(area: area)
                case let .app(app): MiniAppView(app: app)
                case let .page(page): MiniAppPageView(page: page)
                }
            }
            .task {
                // « Mon Quotidien » shows the weather and today's events when they are available.
                model.refreshEvents()
                await model.refreshWeather()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        router.openExplore(search: true)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(Text("Rechercher un widget"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.isProfilePresented = true
                    } label: {
                        ProfileAvatar(name: model.settings.profileName.trimmed, size: 32)
                    }
                    .accessibilityLabel(Text("Profil et réglages"))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.longDay(Date()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(greetingWithName)
                .font(.title2.weight(.semibold))
        }
    }

    private var greetingWithName: String {
        let first = model.settings.profileName.trimmed.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? greeting : "\(greeting) \(first)"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        default: return "Bonsoir"
        }
    }

    // MARK: Mes widgets

    private static let wallpaper = LinearGradient(
        colors: [Color(hex: "22324F"), Color(hex: "4A3F5E"), Color(hex: "92596A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    @ViewBuilder private var myWidgets: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mes widgets", actionTitle: model.designs.isEmpty ? nil : "Tout voir") {
                router.tab = .mine
            }
            if model.designs.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Crée ton premier widget")
                        .font(.headline)
                    Text("Choisis une catégorie, personnalise ton widget, puis ajoute-le à ton écran d'accueil.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        router.tab = .spaces
                    } label: {
                        Label("Créer un widget", systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                }
                .card()
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(homeRows.enumerated()), id: \.offset) { pair in
                        HStack(spacing: 14) {
                            ForEach(pair.element) { design in
                                Button {
                                    router.openEditor(design, isNew: false)
                                } label: {
                                    // A fixed width, not a GeometryReader: measuring here re-lays out the whole Home
                                    // inside the update, deep enough to overflow the iPhone's main-thread stack.
                                    WidgetPreview(design: design, family: design.displayFormat.family, payload: model.payload(for: design),
                                                  width: Self.previewWidth(for: design.displayFormat))
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                            }
                            // A small widget alone on its row keeps its size, like on the Home Screen.
                            if pair.element.count == 1, pair.element[0].displayFormat == .small {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Self.wallpaper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text("Tes widgets comme sur ton écran d'accueil · touche-en un pour le modifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// The width of a preview on Home: the screen minus the page margins (20) and the wallpaper's
    /// padding (14) on each side; two small widgets share a row with 14 between them.
    private static func previewWidth(for format: WidgetFormat) -> CGFloat {
        let available = max(200, UIScreen.main.bounds.width - 68)
        return format == .small ? (available - 14) / 2 : available
    }

    /// The latest widgets laid out like a Home Screen: two small ones side by side, a medium one across,
    /// a large one over two rows; two rows at most, so the Store stays close below.
    private var homeRows: [[WidgetDesign]] {
        let maxRows = 2
        var rows: [[WidgetDesign]] = []
        var used = 0
        var waitingSmall: Int?
        for design in model.recentDesigns {
            switch design.displayFormat {
            case .small:
                if let index = waitingSmall {
                    rows[index].append(design)
                    waitingSmall = nil
                } else if used < maxRows {
                    rows.append([design])
                    waitingSmall = rows.count - 1
                    used += 1
                }
            case .medium:
                if used < maxRows {
                    rows.append([design])
                    used += 1
                }
            case .large:
                if used + 2 <= maxRows {
                    rows.append([design])
                    used += 2
                }
            }
            if used >= maxRows && waitingSmall == nil { break }
        }
        return rows
    }

    // MARK: Store

    private enum StoreShelf: String, CaseIterable, Identifiable {
        case forYou = "Pour toi"
        case new = "Nouveautés"
        case popular = "Populaires"
        case free = "Gratuits"
        var id: String { rawValue }
    }

    private var preferredCategories: [WidgetCategory] { model.profile.preferredCategories }

    private var shelves: [StoreShelf] {
        preferredCategories.isEmpty ? StoreShelf.allCases.filter { $0 != .forYou } : StoreShelf.allCases
    }

    private var storeShelf: StoreShelf {
        if let chosenShelf, shelves.contains(chosenShelf) { return chosenShelf }
        return shelves[0]
    }

    /// A few Store widgets of the chosen shelf, one per kind.
    private var shelfTemplates: [WidgetTemplate] {
        let source: [WidgetTemplate]
        switch storeShelf {
        case .forYou:
            // The user's interests, in the order they were picked.
            source = preferredCategories.flatMap { category in TemplateCatalog.all.filter { $0.kind.category == category } }
        case .new: source = TemplateCatalog.all.filter { $0.kind.isNew }
        case .popular: source = TemplateCatalog.featured
        case .free: source = TemplateCatalog.all.filter { !$0.isPremium }
        }
        var seen = Set<WidgetKind>()
        let picked = source.filter { seen.insert($0.kind).inserted }
        return Array((picked.isEmpty ? TemplateCatalog.featured : picked).prefix(10))
    }

    private var storeSample: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                router.openExplore()
            } label: {
                HStack(spacing: 4) {
                    Text("Store")
                        .font(.title3.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Color.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint(Text("Ouvre le Store"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shelves) { shelf in
                        let isOn = storeShelf == shelf
                        Button {
                            withAnimation(.snappy) { chosenShelf = shelf }
                        } label: {
                            Text(shelf.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .foregroundStyle(isOn ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(Color.primary))
                                .background(isOn ? AnyShapeStyle(Color.primary) : AnyShapeStyle(AppFill.cardFill), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(shelfTemplates) { template in
                        Button {
                            router.openEditor(template.makeDesign(), isNew: true)
                        } label: {
                            TemplateCard(template: template, width: 150, isPremiumUser: model.isPremium)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            .id(storeShelf)
            .transition(.opacity)
        }
    }
}

struct PremiumBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.premiumInk)
                    .frame(width: 48, height: 48)
                    .background(Color.premiumFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tessera Premium")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Plus de 70 widgets en plus, 12 styles, fonds photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
