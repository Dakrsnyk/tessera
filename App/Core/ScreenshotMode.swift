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
        // A capture of a new person (`…-fresh`) clears the demo data: the next captures bring it back.
        if !screen.hasSuffix("-fresh"), model.fitness.routines.isEmpty, model.student.courses.isEmpty {
            restoreDemoData(model)
        }
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
            // The tour follows the first questions; every other capture starts without it.
            $0.hasSeenTutorial = !screen.hasPrefix("onboarding")
        }
        // The first launch starts with nothing about the user (a topic page, with the interest that leads to it).
        // Every other capture shows « Mes informations » filled in, whatever an earlier capture left.
        if !screen.hasPrefix("onboarding"), !screen.hasSuffix("-fresh"), model.profile != .sample {
            model.update(\.profile) { $0 = .sample }
        }
        if screen.hasPrefix("onboarding") {
            let topic = ProfileTopic(rawValue: String(screen.dropFirst("onboarding-".count)))
            model.update(\.profile) { profile in
                profile = UserProfile()
                profile.migrated = true
                profile.interests = Interest.allCases.filter { topic != nil && $0.topic == topic }
            }
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
                router.storePath = [.setups]
            }
        case "home":
            router.tab = .home
            model.updateSettings { $0.dailyCardPages = [:] }
        case "home-pages":
            // « Mon Quotidien » with every card swiped to its second view.
            router.tab = .home
            model.updateSettings { settings in
                for card in ["nutrition", "workout", "water", "steps", "weather"] { settings.dailyCardPages[card] = 1 }
            }
        case "spaces-lock":
            router.tab = .spaces
            router.showsLockScreenCreator = true
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
            // `tutorial-store`: the tutorial open on one of its steps (it shows its tab itself).
            if screen.hasPrefix("tutorial-"), let step = TutorialStep(rawValue: String(screen.dropFirst(9))) {
                router.tutorialStep = step
            }
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
            // A mini-app on Home, and one of its pages: app-nutrition, app-nutrition-history…
            if screen.hasPrefix("app-") {
                let parts = screen.dropFirst(4).split(separator: "-").map(String.init)
                if let app = parts.first.flatMap(MiniApp.init(rawValue:)) {
                    let name = "\(app.rawValue)-\(parts.dropFirst().first ?? "")"
                    // Travel is captured during the trip, the richest moment of the mini-app.
                    if app == .travel { model.update(\.travel) { $0 = SampleData.travel(now: Date(), ongoing: true) } }
                    let tripID = model.travel.trips.first?.id
                    let page: MiniAppPage? = switch name {
                    case "nutrition-meal": .nutritionMeal(.breakfast, Date())
                    case "nutrition-history": .nutritionHistory
                    case "nutrition-ideas": .nutritionIdeas
                    case "nutrition-nutrients": .nutritionNutrients(Date())
                    case "nutrition-saved": .nutritionSavedMeals
                    case "fitness-session": .fitnessSession
                    case "fitness-program": .fitnessProgram
                    case "fitness-library": .fitnessLibrary
                    case "fitness-exercise": .fitnessExercise(parts.count > 2 ? parts.dropFirst(2).joined(separator: "-") : "bench-press")
                    case "fitness-history": .fitnessHistory
                    case "fitness-progress": .fitnessProgress
                    case "fitness-activity": .fitnessActivity
                    case "planning-tasks": .planningTasks
                    case "planning-week": .planningWeek
                    case "planning-month": .planningMonth
                    case "planning-projects": .planningProjects
                    case "planning-habits": .planningHabits
                    case "planning-focus": .planningFocus
                    case "studies-timetable": .studiesTimetable
                    case "studies-courses": .studiesCourses
                    case "studies-course": model.student.courses.first.map { .studiesCourse($0.id) }
                    case "studies-exams": .studiesExams
                    case "studies-assignments": .studiesAssignments
                    case "studies-grades": .studiesGrades
                    case "studies-revision": .studiesRevision
                    case "finances-transactions": .financesTransactions
                    case "finances-categories": .financesCategories
                    case "finances-bills": .financesBills
                    case "finances-savings": .financesSavings
                    case "finances-trends": .financesTrends
                    case "business-sales": .businessSales
                    case "business-results": .businessResults
                    case "business-recurring": .businessRecurring
                    case "business-metrics": .businessMetrics
                    case "travel-program": tripID.map { .travelProgram($0) }
                    case "travel-budget": tripID.map { .travelBudget($0) }
                    case "travel-checklist": tripID.map { .travelChecklist($0) }
                    case "car-fuel": .carFuel
                    case "car-mileage": .carMileage
                    case "car-maintenance": .carMaintenance
                    case "car-deadlines": .carDeadlines
                    case "car-costs": .carCosts
                    default: nil
                    }
                    // A workout under way, two sets done, for the session page.
                    if name == "fitness-session", let routine = model.fitness.routines.first {
                        model.update(\.fitness) { state in
                            state.startSession(routine, at: Date().addingTimeInterval(-600))
                            state.completeNextSet(at: Date().addingTimeInterval(-400))
                            state.completeNextSet(at: Date().addingTimeInterval(-60))
                        }
                    }
                    router.tab = .home
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(700))
                        router.openApp(app, page: page)
                    }
                }
            }
            // « Mes informations » and one of its areas, pushed on Home.
            if screen == "info" || screen.hasPrefix("info-") {
                router.tab = .home
                let area = InfoArea(rawValue: String(screen.dropFirst(5)))
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(700))
                    router.homePath = area.map { [.info, .infoArea($0)] } ?? [.info]
                }
            }
            // Home as a new person sees it: interests chosen, nothing entered yet.
            if screen.hasSuffix("-fresh") {
                model.update(\.profile) { profile in
                    profile = UserProfile()
                    profile.migrated = true
                    profile.interests = [.nutrition, .sport, .budget]
                }
                model.update(\.nutrition) { $0 = NutritionState() }
                model.update(\.fitness) { $0 = FitnessState() }
                model.update(\.budget) { $0 = BudgetState() }
                model.update(\.student) { $0 = StudentState() }
                model.update(\.productivity) { $0 = ProductivityState() }
                model.update(\.travel) { $0 = TravelState() }
                model.update(\.car) { $0 = CarState() }
                model.updateContent { $0 = ContentState() }
                if screen == "home-fresh" { router.tab = .home }
                if screen == "editor-fresh" { router.openEditor(TemplateCatalog.design("calories-glass"), isNew: true) }
            }
            // The Widget Studio, open on one of its sections, on a widget with lines, parts and a chart.
            if screen == "studio-multi" {
                // Several widgets made together, opened in the Studio as a creation does.
                let designs = [WidgetKind.caloriesLeft, .macros, .proteinLeft].map { kind in
                    WidgetDesign(kind: kind, themeID: .modern, accentHex: "2F8F7A", format: .small)
                }
                router.editor = EditorRequest(designs: designs, isNew: true, section: "colors")
            } else if screen.hasPrefix("studio-") {
                let section = String(screen.dropFirst(7))
                // « studio-note »: a widget without a chart; « studio-main-… »: the colors with a main color picked.
                let kind: WidgetKind = section == "chart" ? .nutritionWeek : (section == "note" ? .note : .macros)
                var design = WidgetDesign(kind: kind, themeID: .modern, accentHex: "2F8F7A", format: .medium)
                if section.hasPrefix("main-") {
                    let theme = ThemeID(rawValue: String(section.dropFirst(5))) ?? .neon
                    design.themeID = theme
                    design = design.recolored(to: "3366FF")
                }
                if section.hasPrefix("palette-") {
                    design = ColorPalette.palette(String(section.dropFirst(8)))?.applied(to: design) ?? design
                }
                if section == "myStyles" {
                    for saved in model.savedStyles { model.deleteStyle(saved.id) }
                    var looks = design
                    looks = StylePreset.preset("ocean")?.applied(to: looks) ?? looks
                    model.saveStyle(named: "Océan du matin", from: looks)
                    model.saveStyle(named: "Mon thème", from: StylePreset.preset("midnight")?.applied(to: design) ?? design)
                }
                let opened = section.hasPrefix("main-") || section.hasPrefix("palette-") ? "colors" : section
                router.openEditor(design, isNew: true, section: opened)
            }
            if screen.hasPrefix("pack-") {
                router.tab = .explore
                let id = String(String(screen.dropFirst(5)).split(separator: "-").first ?? "")
                router.startsPackSetup = screen.contains("-setup")
                router.openedPackID = id
            }
            if screen.hasPrefix("store-") {
                router.tab = .explore
                let name = String(screen.dropFirst(6))
                let page: StorePage? = switch name {
                case "combos": .combos
                case "packs": .packs
                case "collections": .collections
                default: name.hasPrefix("collection-") ? .collection(String(name.dropFirst(11))) : nil
                }
                if name.hasPrefix("category-") {
                    router.exploreCategory = WidgetCategory(rawValue: String(name.dropFirst(9)))
                }
                if let page {
                    // Pushed once the Store tab is on screen (see "setups").
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(900))
                        router.storePath = [page]
                    }
                }
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
        restoreDemoData(model)
    }

    /// The demo person's data in every space, and « Mes informations » filled in as after the first launch.
    @MainActor
    private static func restoreDemoData(_ model: AppModel) {
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
        case let value?:
            // A fraction of the page, for long pages shot in several slices ("0.3").
            if let fraction = Double(value) { defaultScrollAnchor(UnitPoint(x: 0, y: fraction)) } else { self }
        default: self
        }
        #else
        self
        #endif
    }
}
