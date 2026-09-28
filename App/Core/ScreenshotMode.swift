#if DEBUG
import SwiftUI
import WidgetKit

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
        switch screen {
        case "onboarding": return .onboarding
        case "home": router.tab = .home
        case "explore": router.tab = .explore
        case "editor": router.openEditor(TemplateCatalog.design("countdown-holidays"), isNew: true)
        case "mywidgets": router.tab = .mine
        case "paywall": router.isPaywallPresented = true
        case "settings": router.tab = .settings
        case "content": router.content = .money
        default:
            if screen.hasPrefix("gallery") { return .gallery(screen) }
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
        let sample = SamplePayload.make(for: .tasks).content.tasks
        let habits = SamplePayload.make(for: .habits).content.habits
        let money = SamplePayload.make(for: .moneyFlow).content.money
        model.updateContent {
            $0.tasks = sample
            $0.habits = habits
            $0.hydration.add(5, on: Date())
            $0.money = money
        }
    }
}

/// Every widget kind rendered at one size, used for visual QA in test builds.
struct WidgetGalleryView: View {
    let mode: String

    private var family: WidgetFamily {
        switch mode {
        case "gallery-medium": .systemMedium
        case "gallery-large": .systemLarge
        case "gallery-lock": .accessoryRectangular
        default: .systemSmall
        }
    }

    private var themes: [ThemeID] { [.minimal, .dark, .aurora, .retro, .elegant, .glass] }

    var body: some View {
        GeometryReader { geo in
            let columns = family == .systemSmall ? 3 : family == .systemMedium ? 2 : family == .systemLarge ? 3 : 2
            let spacing: CGFloat = 8
            let width = (geo.size.width - 16 - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(width), spacing: spacing), count: columns), spacing: spacing) {
                ForEach(Array(kinds.enumerated()), id: \.offset) { pair in
                    let kind = pair.element
                    WidgetPreview(
                        design: WidgetDesign(kind: kind, themeID: themes[pair.offset % themes.count], accentHex: Palette.freeAccents[pair.offset % Palette.freeAccents.count].hex),
                        family: family,
                        payload: SamplePayload.make(for: kind),
                        width: width
                    )
                }
            }
            .padding(8)
            .background(family.isAccessory ? Color(hex: "1F2A44") : Color.screenFill)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var kinds: [WidgetKind] {
        family.isAccessory ? WidgetKind.allCases.filter { $0.families.contains(family) } : WidgetKind.allCases.filter { $0.families.contains(family) || family == .systemSmall }
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
