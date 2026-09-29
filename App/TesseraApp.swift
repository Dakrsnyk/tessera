import SwiftUI
import WidgetKit

@main
struct TesseraApp: App {
    @State private var model = AppModel()
    @State private var router = Router()
    @State private var premium = PremiumStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(router)
                .environment(premium)
                .onAppear { premium.start(model: model) }
                .onOpenURL { url in
                    if let link = DeepLink(url: url) {
                        router.handle(link, model: model)
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        model.reloadFromDisk()
                        Task { await premium.refreshEntitlements() }
                        Task { await model.refreshInsights() }
                    } else if phase == .background {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var showsLaunch = true
    /// The app grows into place as the launch mark lifts away.
    @State private var revealed = false
    @State private var showsOnboarding = false
    @State private var showsStylePicker = false
    /// Installs from before « Mes informations »: the questions about the user, once.
    @State private var showsPersonalization = false
    @State private var galleryMode: String?

    var body: some View {
        @Bindable var router = router
        ZStack {
            MainTabView()
                .scaleEffect(revealed ? 1 : 0.94)
                .opacity(revealed ? 1 : 0)
                .sheet(item: $router.editor, onDismiss: {
                    if router.showsAddGuideAfterEditor {
                        router.showsAddGuideAfterEditor = false
                        router.isAddGuidePresented = true
                    }
                }) { request in
                    EditorView(request: request)
                }
                .sheet(isPresented: $router.isPaywallPresented) {
                    PaywallView()
                }
                .sheet(item: $router.content) { screen in
                    ContentScreenView(screen: screen)
                }
                .sheet(isPresented: $router.isFoodScanPresented) {
                    // From a Nutrition widget: straight to the camera, with the search as the fallback.
                    FoodSearchView(startsWithScanner: true)
                }
                .sheet(isPresented: $router.isAddGuidePresented) {
                    AddToHomeScreenGuide(designName: router.lastSavedName)
                }
                .sheet(isPresented: $router.isProfilePresented) {
                    ProfileView()
                        .appStyle(model.settings)
                }
                .fullScreenCover(isPresented: $showsOnboarding) {
                    OnboardingView {
                        model.completeOnboarding()
                        showsOnboarding = false
                    }
                    .appStyle(model.settings)
                }
                .fullScreenCover(isPresented: $showsPersonalization) {
                    OnboardingView(personalizationOnly: true) {
                        model.updateSettings { $0.hasCompletedProfileSetup = true }
                        showsPersonalization = false
                    }
                    .appStyle(model.settings)
                }
                // Installs from before the styles existed: the style picker alone, once.
                .fullScreenCover(isPresented: $showsStylePicker) {
                    OnboardingView(styleOnly: true) {
                        model.updateSettings { $0.hasChosenStyle = true }
                        showsStylePicker = false
                    }
                    .appStyle(model.settings)
                }

            #if DEBUG
            if let galleryMode {
                Group {
                    if galleryMode.hasPrefix("marketing") {
                        MarketingView(scene: galleryMode)
                    } else if galleryMode.hasPrefix("gallery-setups") {
                        SetupGalleryView(mode: galleryMode)
                    } else {
                        WidgetGalleryView(mode: galleryMode)
                    }
                }
                .zIndex(2)
            }
            #endif

            if let flight = router.saveFlight {
                SaveFlightOverlay(flight: flight) { router.saveFlight = nil }
                    .id(flight.id)
                    .zIndex(3)
            }

            if showsLaunch {
                LaunchView()
                    .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 1.15))))
                    .zIndex(1)
            }
        }
        .appStyle(model.settings)
        .onChange(of: model.settings.hasCompletedOnboarding) { _, done in
            if !done && !showsLaunch { showsOnboarding = true }
        }
        .task {
            #if DEBUG
            if ScreenshotMode.isActive {
                // `-screenshotScreen launch` keeps the launch mark on screen.
                showsLaunch = ScreenshotMode.screen == "launch"
                revealed = true
                switch ScreenshotMode.apply(model: model, router: router) {
                case .onboarding: showsOnboarding = true
                case let .gallery(mode): galleryMode = mode
                case .none: break
                }
                return
            }
            #endif
            try? await Task.sleep(for: .milliseconds(1_150))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                showsLaunch = false
                revealed = true
            }
            if !model.settings.hasCompletedOnboarding {
                showsOnboarding = true
            } else if !model.settings.hasChosenStyle {
                showsStylePicker = true
            } else if !model.settings.hasCompletedProfileSetup {
                showsPersonalization = true
            }
        }
    }
}

struct MainTabView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        // Styles repaint in place (see `AppFill`): no tab is ever rebuilt.
        TabView(selection: $router.tab) {
            HomeView()
                .pageEntrance(.home)
                .tabItem { Label("Accueil", systemImage: "square.grid.2x2") }
                .tag(Router.Tab.home)
            SpacesView()
                .pageEntrance(.spaces)
                .tabItem { Label("Créer", systemImage: "plus.square.on.square") }
                .tag(Router.Tab.spaces)
            ExploreView()
                .pageEntrance(.explore)
                .tabItem { Label("Store", systemImage: "bag") }
                .tag(Router.Tab.explore)
            MyWidgetsView()
                .pageEntrance(.mine)
                .tabItem { Label("Mes widgets", systemImage: "rectangle.stack") }
                .tag(Router.Tab.mine)
        }
    }
}

/// Sheets for the data behind widgets (tasks, habits, water, money, location, calendar access).
struct ContentScreenView: View {
    let screen: ContentScreen
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch screen {
                case .tasks: TasksView()
                case .habits: HabitsView()
                case .hydration: HydrationView()
                case .money: MoneyView()
                case .weather: WeatherLocationView()
                case .calendar: CalendarAccessView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

/// Opening a tab: its page fades in and rises into place. The page is hidden as it is left,
/// so it is ready to come back in without a flash.
struct PageEntrance: ViewModifier {
    let tab: Router.Tab
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = true

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 16)
            .scaleEffect(visible || reduceMotion ? 1 : 0.985, anchor: .top)
            .onChange(of: router.tab) { old, new in
                if old == tab && new != tab {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { visible = false }
                } else if new == tab && old != tab {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { visible = true }
                }
            }
    }
}

extension View {
    func pageEntrance(_ tab: Router.Tab) -> some View {
        modifier(PageEntrance(tab: tab))
    }
}
