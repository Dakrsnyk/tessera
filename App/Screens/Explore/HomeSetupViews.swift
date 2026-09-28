import Photos
import SwiftUI
import WidgetKit

/// The phone the setups are drawn on: a 6.3" iPhone, in points. Screens are drawn at this size, then scaled.
enum SetupScreen {
    static let size = CGSize(width: 402, height: 874)
    /// Space between the screen edge and the widgets (364 pt of content, like iOS).
    static let margin: CGFloat = 19
    static let now: Date = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) ?? Date()
}

enum SetupPage: Int, CaseIterable, Identifiable {
    case home, lock
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: "Écran d'accueil"
        case .lock: "Écran verrouillé"
        }
    }
}

/// Favorites are kept on the device, as a comma-separated list of setup ids.
enum SetupFavorites {
    static let key = "favoriteSetups"

    static func ids(_ raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }

    static func toggled(_ id: String, in raw: String) -> String {
        var favorites = Self.ids(raw)
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        return favorites.sorted().joined(separator: ",")
    }
}

/// The rounded corners of an iPhone screen, whatever the size it is drawn at.
struct SetupScreenShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: rect.width * 0.12, style: .continuous).path(in: rect)
    }
}

// MARK: - Screens

/// One page of a setup, drawn at the real screen size and scaled to the width offered.
/// Equatable, so swiping a card's pages doesn't redraw every widget.
struct SetupScreenshot: View, Equatable {
    let setup: HomeSetup
    let page: SetupPage

    static func == (lhs: SetupScreenshot, rhs: SetupScreenshot) -> Bool {
        lhs.setup.id == rhs.setup.id && lhs.page == rhs.page
    }

    var body: some View {
        Color.clear
            .aspectRatio(SetupScreen.size.width / SetupScreen.size.height, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    let scale = geo.size.width / SetupScreen.size.width
                    Group {
                        switch page {
                        case .home: SetupHomeScreen(setup: setup)
                        case .lock: SetupLockScreen(setup: setup)
                        }
                    }
                    .frame(width: SetupScreen.size.width, height: SetupScreen.size.height)
                    .scaleEffect(scale, anchor: .topLeading)
                }
            }
            .clipShape(SetupScreenShape())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(page.title) \(setup.name)"))
    }
}

struct SetupStatusBar: View {
    let ink: Color
    var showsTime = true

    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                Text(showsTime ? "9:41" : "")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 96)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100percent")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 96)
            }
            .padding(.horizontal, 10)
            .padding(.top, 20)
            Capsule()
                .fill(Color.black)
                .frame(width: 122, height: 36)
                .padding(.top, 11)
        }
        .frame(width: SetupScreen.size.width, height: 54, alignment: .top)
        .foregroundStyle(ink)
        .fontDesign(.default)
    }
}

struct SetupAppIcon: View {
    let app: SetupApp
    let style: SetupIconStyle
    var size: CGFloat = 62

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        ZStack {
            switch style {
            case .glass:
                shape.fill(Color.white.opacity(0.2))
                    .overlay { shape.strokeBorder(Color.white.opacity(0.32), lineWidth: 1) }
            case .tinted:
                shape.fill(LinearGradient(colors: [Color(hex: "2B2B30"), Color(hex: "111113")], startPoint: .top, endPoint: .bottom))
                    .overlay { shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1) }
            case let .solid(background, _):
                shape.fill(Color(hex: background))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            case let .gradient(colors, _):
                shape.fill(LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            }
            if app == .tessera {
                TesseraMark(size: size * 0.56)
            } else {
                Image(systemName: app.symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(symbolColor)
            }
        }
        .frame(width: size, height: size)
    }

    private var symbolColor: Color {
        switch style {
        case .glass: .white
        case let .tinted(hex): Color(hex: hex)
        case let .solid(_, symbol): Color(hex: symbol)
        case let .gradient(_, symbol): Color(hex: symbol)
        }
    }
}

/// A Home Screen page: status bar, rows of widgets and icons, search pill and dock.
struct SetupHomeScreen: View {
    let setup: HomeSetup

    private var ink: Color { setup.ink }
    private var isLight: Bool { setup.wallpaper.isLight }

    var body: some View {
        ZStack(alignment: .top) {
            SetupWallpaperView(wallpaper: setup.wallpaper)
            VStack(spacing: 14) {
                ForEach(Array(setup.rows.enumerated()), id: \.offset) { pair in
                    row(pair.element)
                }
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                    Text("Rechercher")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink.opacity(0.9))
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background((isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.2)), in: Capsule())
                HStack(spacing: 0) {
                    ForEach(setup.dock, id: \.self) { app in
                        SetupAppIcon(app: app, style: setup.icons)
                            .frame(width: 95)
                    }
                }
                .frame(width: 382, height: 94)
                .background((isLight ? Color.white.opacity(0.42) : Color.white.opacity(0.16)), in: RoundedRectangle(cornerRadius: 38, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .strokeBorder(Color.white.opacity(isLight ? 0.5 : 0.14), lineWidth: 1)
                }
            }
            .padding(.top, 68)
            .padding(.bottom, 10)
            SetupStatusBar(ink: ink)
        }
        .frame(width: SetupScreen.size.width, height: SetupScreen.size.height)
        .environment(\.colorScheme, isLight ? .light : .dark)
        .fontDesign(.default)
    }

    @ViewBuilder private func row(_ row: SetupRow) -> some View {
        switch row {
        case let .widgets(widgets):
            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(widgets.enumerated()), id: \.offset) { pair in
                    widget(pair.element)
                }
            }
            .frame(width: 364, alignment: .leading)
        case let .widgetAndApps(widget, apps, widgetFirst):
            HStack(alignment: .top, spacing: 12) {
                if widgetFirst {
                    self.widget(widget)
                    appSquare(apps)
                } else {
                    appSquare(apps)
                    self.widget(widget)
                }
            }
            .frame(width: 364)
        case let .apps(apps):
            HStack(spacing: 0) {
                ForEach(apps, id: \.self) { app in
                    appCell(app).frame(width: 91)
                }
            }
        }
    }

    private func widget(_ widget: SetupWidget) -> some View {
        let design = widget.makeDesign()
        return VStack(spacing: 5) {
            WidgetPreview(
                design: design, family: widget.family,
                payload: SamplePayload.make(for: design, now: SetupScreen.now),
                width: WidgetMetrics.size(widget.family).width, date: SetupScreen.now
            )
            .shadow(color: .black.opacity(isLight ? 0.08 : 0.2), radius: 8, y: 3)
            label("Tessera")
        }
    }

    private func appSquare(_ apps: [SetupApp]) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(Array(apps.prefix(2)), id: \.self) { appCell($0).frame(width: 91) }
            }
            HStack(spacing: 0) {
                ForEach(Array(apps.dropFirst(2).prefix(2)), id: \.self) { appCell($0).frame(width: 91) }
            }
        }
        .frame(width: 182)
    }

    private func appCell(_ app: SetupApp) -> some View {
        VStack(spacing: 5) {
            SetupAppIcon(app: app, style: setup.icons)
            label(app.name)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(ink.opacity(isLight ? 0.85 : 0.95))
            .shadow(color: .black.opacity(isLight ? 0 : 0.3), radius: 2, y: 1)
            .lineLimit(1)
    }
}

/// The Lock Screen: date, clock, widgets under the clock, and the two buttons at the bottom.
struct SetupLockScreen: View {
    let setup: HomeSetup

    private var ink: Color { setup.ink }
    private var isLight: Bool { setup.wallpaper.isLight }

    var body: some View {
        ZStack(alignment: .top) {
            SetupWallpaperView(wallpaper: setup.wallpaper)
            if !isLight {
                LinearGradient(colors: [Color.black.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
            }
            VStack(spacing: 0) {
                dateLine
                    .frame(height: 30)
                Text("9:41")
                    .font(.system(size: 112, weight: setup.lock.clockWeight, design: setup.lock.clockDesign))
                    .tracking(-2)
                    .foregroundStyle(ink)
                    .padding(.top, -8)
                HStack(spacing: 14) {
                    ForEach(Array(setup.lock.widgets.enumerated()), id: \.offset) { pair in
                        accessory(pair.element)
                    }
                }
                .padding(.top, 6)
                Spacer(minLength: 0)
                HStack {
                    roundButton("flashlight.off.fill")
                    Spacer()
                    roundButton("camera.fill")
                }
                .padding(.horizontal, 44)
                Capsule()
                    .fill(ink.opacity(0.9))
                    .frame(width: 140, height: 5)
                    .padding(.top, 22)
            }
            .padding(.top, 64)
            .padding(.bottom, 9)
            SetupStatusBar(ink: ink, showsTime: false)
        }
        .frame(width: SetupScreen.size.width, height: SetupScreen.size.height)
        .environment(\.colorScheme, isLight ? .light : .dark)
        .fontDesign(.default)
    }

    @ViewBuilder private var dateLine: some View {
        if let inline = setup.lock.inline {
            let design = inline.makeDesign()
            HStack(spacing: 8) {
                Text(Self.capitalized(Fmt.format(SetupScreen.now, template: "EEEd")))
                WidgetCanvas(
                    design: design, family: .accessoryInline, date: SetupScreen.now,
                    payload: SamplePayload.make(for: design, now: SetupScreen.now), isPremium: true, isInteractive: false
                )
                .lineLimit(1)
                .fixedSize()
            }
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(ink.opacity(0.92))
        } else {
            Text(Self.capitalized(Fmt.format(SetupScreen.now, template: "EEEEdMMMM")))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ink.opacity(0.92))
        }
    }

    private func accessory(_ widget: SetupWidget) -> some View {
        let design = widget.makeDesign()
        return WidgetPreview(
            design: design, family: widget.family,
            payload: SamplePayload.make(for: design, now: SetupScreen.now),
            width: WidgetMetrics.size(widget.family).width, date: SetupScreen.now,
            lockInk: ink, lockInkIsDark: isLight
        )
    }

    private func roundButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(ink)
            .frame(width: 50, height: 50)
            .background((isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.16)), in: Circle())
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - Cards

/// A setup in the Store: its screens (swipe between them), name, tags, Premium and favorite.
struct SetupCard: View {
    let setup: HomeSetup
    /// The shelf shows the Home Screen only (a horizontal carousel inside a horizontal list would fight it).
    var showsPages = true
    let isFavorite: Bool
    let isPremiumUser: Bool
    let onFavorite: () -> Void
    let onOpen: () -> Void
    @State private var page: SetupPage = .home

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottom) {
                if showsPages {
                    TabView(selection: $page) {
                        ForEach(SetupPage.allCases) { page in
                            SetupScreenshot(setup: setup, page: page)
                                .contentShape(Rectangle())
                                .onTapGesture(perform: onOpen)
                                .tag(page)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    HStack(spacing: 5) {
                        ForEach(SetupPage.allCases) { item in
                            Capsule()
                                .fill(Color.white.opacity(item == page ? 0.95 : 0.45))
                                .frame(width: item == page ? 14 : 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.28), in: Capsule())
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.3), value: page)
                    .accessibilityHidden(true)
                } else {
                    SetupScreenshot(setup: setup, page: .home)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onOpen)
                }
            }
            .aspectRatio(SetupScreen.size.width / SetupScreen.size.height, contentMode: .fit)
            .clipShape(SetupScreenShape())
            .overlay { SetupScreenShape().stroke(Color.primary.opacity(0.08), lineWidth: 1) }
            .overlay(alignment: .topLeading) {
                if setup.isPremium && !isPremiumUser {
                    PremiumBadge()
                        .padding(9)
                        .allowsHitTesting(false)
                }
            }
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)

            HStack(alignment: .top, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(setup.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(setup.tags.prefix(2).map { "#\($0.title)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button(action: onFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFavorite ? Color(hex: "F2588F") : Color.secondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris"))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - All setups

struct HomeSetupsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @AppStorage(SetupFavorites.key) private var favoritesRaw = ""
    @State private var filter: Filter = .all
    @State private var opened: HomeSetup?

    enum Filter: Hashable {
        case all, favorites
        case tag(SetupTag)
    }

    private static let tagFilters: [SetupTag] = [.minimal, .dark, .light, .colorful, .pastel, .productivity, .fitness, .study, .travel, .money]

    private var favorites: Set<String> { SetupFavorites.ids(favoritesRaw) }

    private var items: [HomeSetup] {
        switch filter {
        case .all: HomeSetupCatalog.all
        case .favorites: HomeSetupCatalog.all.filter { favorites.contains($0.id) }
        case let .tag(tag): HomeSetupCatalog.all.filter { $0.tags.contains(tag) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Des écrans complets : fond d'écran, widgets et écran verrouillé assortis. Touche-en un pour l'installer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                chips
                if items.isEmpty {
                    EmptyStateView(
                        symbol: filter == .favorites ? "heart" : "square.grid.2x2",
                        title: filter == .favorites ? "Aucun favori" : "Aucun écran",
                        message: filter == .favorites ? "Touche le cœur sous un écran pour le retrouver ici." : "Essaie un autre filtre.",
                        actionTitle: "Tout afficher"
                    ) { filter = .all }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], alignment: .leading, spacing: 24) {
                        ForEach(items) { setup in
                            SetupCard(
                                setup: setup,
                                isFavorite: favorites.contains(setup.id),
                                isPremiumUser: model.isPremium,
                                onFavorite: { toggleFavorite(setup) },
                                onOpen: { opened = setup }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 32)
        }
        .background(.screenFill)
        .navigationTitle("Écrans d'accueil")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $opened) { setup in
            HomeSetupSheet(setup: setup)
        }
        .onAppear(perform: consumeRequest)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Tous", isSelected: filter == .all) { filter = .all }
                FilterChip(title: "Favoris", symbol: "heart.fill", isSelected: filter == .favorites) { filter = .favorites }
                Divider().frame(height: 22)
                ForEach(Self.tagFilters) { tag in
                    FilterChip(title: "#\(tag.title)", isSelected: filter == .tag(tag)) {
                        filter = filter == .tag(tag) ? .all : .tag(tag)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func toggleFavorite(_ setup: HomeSetup) {
        Haptics.tap()
        favoritesRaw = SetupFavorites.toggled(setup.id, in: favoritesRaw)
    }

    private func consumeRequest() {
        if let id = router.openedSetupID {
            router.openedSetupID = nil
            opened = HomeSetupCatalog.setup(id)
        }
    }
}

// MARK: - Detail

struct HomeSetupSheet: View {
    let setup: HomeSetup
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SetupFavorites.key) private var favoritesRaw = ""
    @State private var page: SetupPage = .home
    @State private var installed: Int?
    @State private var wallpaperState: WallpaperState = .idle

    enum WallpaperState {
        case idle, saving, saved, denied, failed
    }

    private var isFavorite: Bool { SetupFavorites.ids(favoritesRaw).contains(setup.id) }
    private var needsPremium: Bool { setup.isPremium && !model.isPremium }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    carousel
                    VStack(alignment: .leading, spacing: 10) {
                        Text(setup.tagline)
                            .font(.body)
                        HStack(spacing: 6) {
                            ForEach(setup.tags) { tag in
                                Text("#\(tag.title)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(.cardFill, in: Capsule())
                            }
                        }
                    }
                    widgetsSection
                    wallpaperSection
                    if let installed {
                        Label(installed == setup.widgets.count ? "Widgets ajoutés à Mes widgets" : "\(Fmt.plural(installed, "widget ajouté", "widgets ajoutés")) (limite de la version gratuite)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(20)
            }
            .background(.screenFill)
            .safeAreaInset(edge: .bottom) {
                Button(action: install) {
                    Text(buttonTitle)
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
            }
            .navigationTitle(setup.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Haptics.tap()
                        favoritesRaw = SetupFavorites.toggled(setup.id, in: favoritesRaw)
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? Color(hex: "F2588F") : Color.primary)
                    }
                    .accessibilityLabel(Text(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris"))
                }
            }
        }
    }

    private var buttonTitle: String {
        if installed != nil { return "Voir comment les ajouter à l'écran" }
        if needsPremium { return "Débloquer avec Premium" }
        return "Ajouter les \(setup.widgets.count) widgets"
    }

    private var carousel: some View {
        VStack(spacing: 14) {
            TabView(selection: $page) {
                ForEach(SetupPage.allCases) { page in
                    SetupScreenshot(setup: setup, page: page)
                        .frame(width: 236)
                        .overlay { SetupScreenShape().stroke(Color.primary.opacity(0.08), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                        .padding(.vertical, 18)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 236 * SetupScreen.size.height / SetupScreen.size.width + 36)
            Picker("Écran", selection: $page.animation()) {
                ForEach(SetupPage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
    }

    private var widgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "\(setup.widgets.count) widgets inclus")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(setup.homeWidgets.enumerated()), id: \.offset) { pair in
                        let widget = pair.element
                        let design = widget.makeDesign()
                        let size = WidgetMetrics.size(widget.family)
                        VStack(alignment: .leading, spacing: 6) {
                            WidgetPreview(design: design, family: widget.family, payload: SamplePayload.make(for: design), width: 118 * size.width / size.height)
                            Text(widget.kind.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            .scrollClipDisabled()
            if !setup.lockOnlyWidgets.isEmpty {
                Label {
                    Text("Aussi pour l'écran verrouillé : \(setup.lockOnlyWidgets.map { $0.kind.title }.joined(separator: ", ")).")
                } icon: {
                    Image(systemName: "lock.iphone")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var wallpaperSection: some View {
        HStack(alignment: .center, spacing: 14) {
            SetupWallpaperView(wallpaper: setup.wallpaper)
                .scaleEffect(64 / SetupScreen.size.width, anchor: .topLeading)
                .frame(width: 64, height: 64 * SetupScreen.size.height / SetupScreen.size.width, alignment: .topLeading)
                .clipShape(SetupScreenShape())
                .overlay { SetupScreenShape().stroke(Color.primary.opacity(0.1), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 4) {
                Text("Fond d'écran · \(setup.wallpaper.title)")
                    .font(.subheadline.weight(.semibold))
                Text(wallpaperMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: saveWallpaper) {
                    HStack(spacing: 6) {
                        if wallpaperState == .saving { ProgressView().controlSize(.small) }
                        Label(wallpaperState == .saved ? "Enregistré dans Photos" : "Enregistrer dans Photos",
                              systemImage: wallpaperState == .saved ? "checkmark" : "square.and.arrow.down")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .disabled(wallpaperState == .saving || wallpaperState == .saved)
                .padding(.top, 4)
            }
        }
        .card(padding: 14)
    }

    private var wallpaperMessage: String {
        switch wallpaperState {
        case .denied: "Tessera n'a pas accès à Photos. Autorise l'ajout de photos dans Réglages › Tessera › Photos."
        case .failed: "L'image n'a pas pu être enregistrée. Réessaie."
        case .saved: "Dans Photos, ouvre l'image, touche Partager puis « Utiliser en fond d'écran »."
        default: "À la bonne taille pour ton iPhone. Ensuite, dans Photos : Partager › « Utiliser en fond d'écran »."
        }
    }

    private func install() {
        if installed != nil {
            dismiss()
            router.lastSavedName = setup.name
            router.isAddGuidePresented = true
            return
        }
        if needsPremium {
            dismiss()
            router.isPaywallPresented = true
            return
        }
        installed = model.install(designs: setup.designs())
        Haptics.success()
    }

    private func saveWallpaper() {
        wallpaperState = .saving
        Task { @MainActor in
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                wallpaperState = .denied
                return
            }
            let renderer = ImageRenderer(content: SetupWallpaperView(wallpaper: setup.wallpaper))
            renderer.scale = 3
            guard let image = renderer.uiImage else {
                wallpaperState = .failed
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                wallpaperState = .saved
                Haptics.success()
            } catch {
                wallpaperState = .failed
            }
        }
    }
}
