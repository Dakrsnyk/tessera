import SwiftUI
import WidgetKit

#if DEBUG
/// Test-build helper: `-screenshotScreen <name>` opens a given screen with demo content,
/// so the CI can capture every screen and every widget for visual review.
enum ScreenshotMode {
    static var screen: String? { UserDefaults.standard.string(forKey: "screenshotScreen") }
    static var isActive: Bool { screen != nil }

    enum Action {
        case none
        case onboarding
        case gallery(String)
    }

    @MainActor
    static func apply(model: AppModel, router: Router) -> Action {
        guard let screen else { return .none }
        seed(model)
        model.seedDemoCaches(SampleData.domains(now: Date()))
        // The offer is captured as a free user sees it; every other screen with Premium unlocked.
        model.setDebugPremium(screen != "paywall" && screen != "setups-free")
        // `-screenshotStyle ocean -screenshotAppearance dark`: the app style to capture with (default otherwise).
        let defaults = UserDefaults.standard
        model.updateSettings {
            $0.appStyle = defaults.string(forKey: "screenshotStyle").flatMap(AppStyleID.init(rawValue:)) ?? .tessera
            $0.appearance = defaults.string(forKey: "screenshotAppearance").flatMap(AppearanceMode.init(rawValue:)) ?? .system
            $0.hasChosenStyle = true
            $0.hasCompletedProfileSetup = true
        }
        switch screen {
        case "onboarding": return .onboarding
        case "home-info": router.tab = .home
        case "setups", "setups-free":
            router.tab = .explore
            // Pushed once the Store tab is on screen: switching tab and pushing in the same
            // instant leaves the tab bar on the Store with the previous page still shown.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(900))
                router.showsAllSetups = true
            }
        case "home": router.tab = .home
        case "explore": router.tab = .explore
        case "editor": router.openEditor(TemplateCatalog.design("countdown-holidays"), isNew: true)
        case "mywidgets": router.tab = .mine
        case "paywall": router.isPaywallPresented = true
        case "settings", "profile": router.isProfilePresented = true
        case "content": router.content = .money
        case "spaces": router.tab = .spaces
        case "store": router.tab = .explore
        case "editor-v2": router.openEditor(TemplateCatalog.design("calories-glass"), isNew: true)
        default:
            if screen.hasPrefix("gallery") || screen.hasPrefix("marketing") { return .gallery(screen) }
            // Steps of the first launch (the flow picks the step itself, see `OnboardingView`).
            if screen.hasPrefix("onboarding-") { return .onboarding }
            if screen == "scan-food" { router.handle(.scanFood, model: model) }
            if screen.hasPrefix("space-"), let space = Space(rawValue: String(screen.dropFirst(6))) {
                router.openSpace(space)
            }
            if screen.hasPrefix("creator-"), let space = Space(rawValue: String(screen.dropFirst(8))) {
                router.tab = .spaces
                router.requestedCreator = space
            }
            if screen == "mywidgets-fusion" {
                router.tab = .mine
                router.startsFusion = true
            }
            if screen == "mywidgets-select" {
                router.tab = .mine
                router.startsSelection = true
            }
            if screen.hasPrefix("setup-") {
                router.tab = .explore
                router.openedSetupID = String(screen.dropFirst(6))
            }
        }
        return .none
    }

    @MainActor
    private static func seed(_ model: AppModel) {
        guard model.designs.isEmpty else { return }
        model.updateSettings {
            $0.hasCompletedOnboarding = true
            $0.weatherLocation = WeatherLocation(name: "Montréal", latitude: 45.5019, longitude: -73.5674)
        }
        for id in ["progress-year", "tasks-minimal", "weather-aurora", "habits-dark", "countdown-holidays", "money-net"] {
            model.save(TemplateCatalog.design(id))
        }
        // Widgets made in a space at each size, and merged ones.
        var mediumMeals = TemplateCatalog.template(for: .mealsToday)?.makeDesign() ?? WidgetDesign(kind: .mealsToday)
        mediumMeals.format = .medium
        model.save(mediumMeals)
        if let merged = Fusion.merge([WidgetDesign(kind: .caloriesLeft, themeID: .aurora, format: .small), WidgetDesign(kind: .macros, format: .small)]) {
            model.save(merged)
        }
        let dashboard = [WidgetKind.nextSet, .trainingStreak, .personalRecords, .caloriesBurned].map { WidgetDesign(kind: $0, themeID: .dark, accentHex: "FF6B57", format: .small) }
        if let merged = Fusion.merge(dashboard) { model.save(merged) }
        let sample = SampleData.content(now: Date())
        let money = SamplePayload.make(for: .moneyFlow).content.money
        model.updateContent {
            $0.tasks = sample.tasks
            $0.habits = sample.habits
            $0.hydration = sample.hydration
            $0.money = money
        }
        let data = SampleData.domains(now: Date())
        // « Mes informations » filled in, as after the first launch.
        model.update(\.profile) { $0 = .sample }
        model.update(\.nutrition) { $0 = data.nutrition }
        model.update(\.fitness) { $0 = data.fitness }
        model.update(\.budget) { $0 = data.budget }
        model.update(\.business) { $0 = data.business }
        model.update(\.portfolio) { $0 = data.portfolio }
        model.update(\.student) { $0 = data.student }
        model.update(\.travel) { $0 = data.travel }
        model.update(\.car) { $0 = data.car }
        model.update(\.productivity) { $0 = data.productivity }
        model.update(\.life) { $0 = data.life }
        model.update(\.following) { $0 = data.following }
    }
}

/// Every Home Screen setup, one page of each (gallery-setups-home or gallery-setups-lock), for visual QA.
struct SetupGalleryView: View {
    let mode: String

    var body: some View {
        let page: SetupPage = mode.hasSuffix("lock") ? .lock : .home
        GeometryReader { geo in
            let spacing: CGFloat = 6
            let width = (geo.size.width - 12 - spacing * 3) / 4
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: spacing), count: 4), spacing: spacing) {
                ForEach(HomeSetupCatalog.all) { setup in
                    SetupScreenshot(setup: setup, page: page)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// Every widget kind rendered at one size, page by page, used for visual QA in test builds.
/// Mode: gallery-<small|medium|large|lock>[-<page>].
struct WidgetGalleryView: View {
    let mode: String

    private var parts: [String] { mode.split(separator: "-").map(String.init) }

    private var family: WidgetFamily {
        switch parts[safe: 1] ?? "small" {
        case "medium": .systemMedium
        case "large": .systemLarge
        case "lock": .accessoryRectangular
        case "circular": .accessoryCircular
        default: .systemSmall
        }
    }

    private var page: Int { max(1, Int(parts[safe: 2] ?? "1") ?? 1) }

    private var pageSize: Int {
        switch family {
        case .systemSmall: 18
        case .systemMedium: 14
        case .systemLarge: 9
        case .accessoryCircular: 30
        default: 22
        }
    }

    private var themes: [ThemeID] { [.minimal, .dark, .aurora, .retro, .elegant, .glass] }

    private var columns: Int {
        switch family {
        case .systemSmall, .systemLarge: 3
        case .accessoryCircular: 5
        default: 2
        }
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 8
            let width = (geo.size.width - 16 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: spacing), count: columns), spacing: spacing) {
                ForEach(Array(pageKinds.enumerated()), id: \.offset) { pair in
                    let kind = pair.element
                    let index = (page - 1) * pageSize + pair.offset
                    WidgetPreview(
                        design: WidgetDesign(kind: kind, themeID: themes[index % themes.count], accentHex: Palette.freeAccents[index % Palette.freeAccents.count].hex),
                        family: family,
                        payload: SamplePayload.make(for: kind),
                        width: width
                    )
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(family.isAccessory ? AnyShapeStyle(Color(hex: "1F2A44")) : AnyShapeStyle(.screenFill))
    }

    private var kinds: [WidgetKind] {
        WidgetKind.allCases.filter { $0.families.contains(family) }
    }

    private var pageKinds: [WidgetKind] {
        let start = (page - 1) * pageSize
        guard start < kinds.count else { return [] }
        return Array(kinds[start..<min(kinds.count, start + pageSize)])
    }
}
#endif

extension View {
    /// Test builds: `-screenshotScroll center|bottom` opens long screens scrolled, for review captures.
    @ViewBuilder
    func screenshotScroll() -> some View {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "screenshotScroll") {
        case "center": defaultScrollAnchor(.center)
        case "bottom": defaultScrollAnchor(.bottom)
        default: self
        }
        #else
        self
        #endif
    }
}
