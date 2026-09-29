import Foundation
import Observation
import SwiftUI
import WidgetKit

/// Single source of truth for the app's data. Everything is written through to the shared store,
/// then widgets are asked to refresh.
@MainActor
@Observable
final class AppModel {
    static let freeDesignLimit = 5
    static let freeHabitLimit = 3

    private(set) var designs: [WidgetDesign] = []
    private(set) var content = ContentState()
    private(set) var settings = AppSettings()
    private(set) var premium = PremiumState()

    // Mini-apps (V2). Written through to the shared store by `update(_:_:)`.
    var nutrition = NutritionState()
    var fitness = FitnessState()
    var budget = BudgetState()
    var business = BusinessState()
    var portfolio = PortfolioState()
    var following = MarketsState()
    var student = StudentState()
    var travel = TravelState()
    var car = CarState()
    var productivity = ProductivityState()
    var life = LifeState()
    /// « Mes informations »: written through `update(\.profile)` or the setters below.
    var profile = UserProfile()

    // Live data used by previews, refreshed on demand.
    private(set) var weather: WeatherResult = .needsLocation
    private(set) var crypto: [String: CryptoResult] = [:]
    private(set) var events: EventsResult = .needsAccess
    private(set) var prices = PriceBook()
    private(set) var quotes: [CoinQuote] = []
    private(set) var global: MarketGlobal?
    private(set) var companies: [Int: CompanyFinancials] = [:]
    private(set) var stocks: [String: StockQuote] = [:]
    private(set) var fx: FXRates?
    private(set) var tripWeather: WeatherSnapshot?
    private(set) var insights = InsightCache()

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    init(store: SharedStore = .shared) {
        self.store = store
        reloadFromDisk()
    }

    /// Widgets can change tasks, habits and water while the app is in the background.
    func reloadFromDisk() {
        designs = store.designs
        content = store.content
        settings = store.settings
        AppStyle.current = AppStyle.style(settings.appStyle)
        premium = store.premium
        weather = WeatherService.cached.map { cache -> WeatherResult in
            guard let location = settings.weatherLocation, cache.matches(location) else { return .needsLocation }
            return .ready(cache)
        } ?? (settings.weatherLocation == nil ? .needsLocation : .unavailable(nil))
        events = CalendarService.upcoming()
        nutrition = store.state(NutritionState.self)
        fitness = store.state(FitnessState.self)
        budget = store.state(BudgetState.self)
        business = store.state(BusinessState.self)
        portfolio = store.state(PortfolioState.self)
        following = store.state(MarketsState.self)
        student = store.state(StudentState.self)
        travel = store.state(TravelState.self)
        car = store.state(CarState.self)
        productivity = store.state(ProductivityState.self)
        life = store.state(LifeState.self)
        profile = store.state(UserProfile.self)
        migrateProfile()
        insights = InsightCache.load()
        let cache = MarketService.cache
        quotes = portfolio.watchlist.compactMap { cache.quotes[$0] }
        global = cache.global
        stocks = cache.stocks
        fx = FXService.cached(base: settings.currencyCode)
        if let trip = TravelMath.currentTrip(travel, at: Date()), let location = trip.location {
            let stored = store.read(WeatherSnapshot.self, from: .tripWeather)
            tripWeather = (stored?.matches(location) ?? false) ? stored : nil
        }
        for ref in following.followed {
            if let cached = CompanyService.cached(ref.cik) { companies[ref.cik] = cached }
        }
    }

    // MARK: Mini-apps

    /// Changes one mini-app's data, saves it for the widgets and refreshes them.
    func update<T: StoredState>(_ keyPath: ReferenceWritableKeyPath<AppModel, T>, _ change: (inout T) -> Void) {
        var value = self[keyPath: keyPath]
        change(&value)
        self[keyPath: keyPath] = value
        store.save(value)
        scheduleWidgetReload()
    }

    /// Everything a widget of any kind may show, from the data in memory (used by previews).
    #if DEBUG
    /// Screenshot mode: demo market, company and travel data, so review captures don't depend on the network.
    func seedDemoCaches(_ data: DomainData) {
        prices = data.prices
        quotes = data.quotes
        global = data.global
        companies = Dictionary(data.companies.map { ($0.ref.cik, $0) }, uniquingKeysWith: { first, _ in first })
        stocks = data.stocks
        fx = data.fx
        tripWeather = data.tripWeather
    }
    #endif

    var domains: DomainData {
        var data = DomainData()
        data.nutrition = nutrition
        data.fitness = fitness
        data.budget = budget
        data.business = business
        data.portfolio = portfolio
        data.prices = prices
        data.quotes = quotes
        data.global = global
        data.following = following
        data.companies = following.followed.compactMap { companies[$0.cik] }
        data.stocks = stocks
        data.student = student
        data.travel = travel
        data.tripWeather = tripWeather
        data.fx = fx
        data.car = car
        data.productivity = productivity
        data.life = life
        data.insights = insights
        data.apply(profile)
        return data
    }

    /// Bumped when the Premium status can change without `premium` changing (test builds).
    var premiumRevision = 0

    var isPremium: Bool {
        _ = premiumRevision
        return premium.isPremium()
    }

    // MARK: Designs

    var canCreateDesign: Bool { isPremium || designs.count < Self.freeDesignLimit }

    var recentDesigns: [WidgetDesign] {
        designs.sorted { ($0.lastUsedAt ?? $0.updatedAt) > ($1.lastUsedAt ?? $1.updatedAt) }
    }

    var favoriteDesigns: [WidgetDesign] { recentDesigns.filter(\.isFavorite) }

    func design(id: UUID) -> WidgetDesign? { designs.first { $0.id == id } }

    func isSaved(_ design: WidgetDesign) -> Bool { designs.contains { $0.id == design.id } }

    func save(_ design: WidgetDesign) {
        var updated = design
        updated.updatedAt = Date()
        updated.lastUsedAt = Date()
        if updated.name.trimmed.isEmpty { updated.name = updated.kind.title }
        if let index = designs.firstIndex(where: { $0.id == updated.id }) {
            let previous = designs[index]
            if case let .photo(old) = previous.background, previous.background != updated.background {
                ImageStore.delete(named: old)
            }
            designs[index] = updated
        } else {
            designs.insert(updated, at: 0)
        }
        store.designs = designs
        NotificationScheduler.syncCountdownReminder(for: updated)
        scheduleWidgetReload()
    }

    func delete(_ design: WidgetDesign) {
        designs.removeAll { $0.id == design.id }
        if case let .photo(name) = design.background { ImageStore.delete(named: name) }
        store.designs = designs
        NotificationScheduler.cancelCountdownReminder(for: design.id)
        scheduleWidgetReload()
    }

    /// Deletes several widgets at once, with a single save and a single widget refresh.
    func delete(_ designsToDelete: [WidgetDesign]) {
        let ids = Set(designsToDelete.map(\.id))
        guard !ids.isEmpty else { return }
        for design in designs where ids.contains(design.id) {
            if case let .photo(name) = design.background { ImageStore.delete(named: name) }
            NotificationScheduler.cancelCountdownReminder(for: design.id)
        }
        designs.removeAll { ids.contains($0.id) }
        store.designs = designs
        scheduleWidgetReload()
    }

    func duplicate(_ design: WidgetDesign) -> WidgetDesign? {
        guard canCreateDesign else { return nil }
        var copy = design
        copy.id = UUID()
        copy.name = "\(design.name) (copie)"
        copy.createdAt = Date()
        copy.isFavorite = false
        if case let .photo(name) = design.background, let image = ImageStore.image(named: name), let newName = ImageStore.save(image) {
            copy.background = .photo(newName)
        }
        save(copy)
        return copy
    }

    /// Adds one design per widget of a pack, within the free limit. Returns how many were added.
    @discardableResult
    func install(_ pack: WidgetPack) -> Int {
        install(designs: pack.designs())
    }

    /// Saves each design as a new widget, within the free limit. Returns how many were added.
    @discardableResult
    func install(designs: [WidgetDesign]) -> Int {
        var added = 0
        for design in designs {
            guard canCreateDesign else { break }
            save(design)
            added += 1
        }
        return added
    }

    func toggleFavorite(_ design: WidgetDesign) {
        guard let index = designs.firstIndex(where: { $0.id == design.id }) else { return }
        designs[index].isFavorite.toggle()
        store.designs = designs
    }

    // MARK: Content

    func updateContent(_ change: (inout ContentState) -> Void) {
        change(&content)
        store.content = content
        scheduleWidgetReload()
    }

    var canAddHabit: Bool { isPremium || content.habits.count < Self.freeHabitLimit }

    // MARK: Settings

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        let before = settings
        change(&settings)
        store.settings = settings
        // Before any view reads the new settings, so rebuilt screens draw with the new style.
        AppStyle.current = AppStyle.style(settings.appStyle)
        if before.weatherLocation != settings.weatherLocation {
            weather = settings.weatherLocation == nil ? .needsLocation : .unavailable(nil)
            Task { await refreshWeather(force: true) }
        }
        if before.cryptoCurrency != settings.cryptoCurrency {
            crypto = [:]
        }
        scheduleWidgetReload()
    }

    // MARK: Premium

    func updatePremium(_ state: PremiumState) {
        guard state != premium else { return }
        premium = state
        store.premium = state
        scheduleWidgetReload()
    }

    // MARK: Live data

    func refreshWeather(force: Bool = false) async {
        guard let location = settings.weatherLocation else {
            weather = .needsLocation
            return
        }
        if !force, case let .ready(snapshot) = weather, snapshot.matches(location),
           Date().timeIntervalSince(snapshot.fetchedAt) < WeatherService.refreshInterval {
            return
        }
        weather = await WeatherService.load(allowNetwork: true)
        scheduleWidgetReload()
    }

    func refreshCrypto(_ coinID: String) async {
        crypto[coinID] = await CryptoService.load(coinID: coinID, allowNetwork: true)
    }

    func refreshEvents() {
        events = CalendarService.upcoming()
    }

    /// Data for a preview inside the app: the user's real content and the latest fetched data.
    func payload(for design: WidgetDesign) -> WidgetPayload {
        // A combined widget: the data of its first widget, plus what the others follow (coin, companies, markets).
        if design.isCombo, let first = design.partDesigns.first {
            var merged = payload(for: first)
            for part in design.partDesigns.dropFirst() {
                let other = payload(for: part)
                if part.kind == .crypto { merged.crypto = other.crypto }
                if part.kind == .marketOverview { merged.domains.quotes = other.domains.quotes }
                for company in other.domains.companies where !merged.domains.companies.contains(where: { $0.ref.cik == company.ref.cik }) {
                    merged.domains.companies.append(company)
                }
            }
            return merged
        }
        var payload = WidgetPayload()
        payload.settings = settings
        payload.content = content
        payload.weather = weather
        payload.crypto = crypto[design.options.coinID] ?? CryptoService.cached(design.options.coinID, currency: settings.cryptoCurrency).map { CryptoResult.ready($0) } ?? .unavailable(nil)
        payload.events = events
        var data = domains
        if design.kind == .marketOverview {
            data.quotes = ["bitcoin", "ethereum", "solana"].compactMap { id in MarketService.cache.quotes[id] }
        }
        if [.companySnapshot, .companyRevenue, .companyStock, .companyCompare].contains(design.kind) {
            data.companies = CompanyTargets.refs(for: design, following: following).compactMap { companies[$0.cik] }
        }
        payload.domains = data
        return payload
    }

    /// Loads whatever network data a design needs for its preview.
    func prepare(_ design: WidgetDesign) async {
        if design.isCombo {
            for part in design.partDesigns { await prepare(part) }
            return
        }
        let needs = DataNeeds.needs(for: design.kind)
        if needs.contains(.weather) { await refreshWeather() }
        if needs.contains(.crypto) { await refreshCrypto(design.options.coinID) }
        if needs.contains(.events) { refreshEvents() }
        if needs.contains(.portfolio) || needs.contains(.quotes) || needs.contains(.global) { await refreshMarkets() }
        if needs.contains(.companies) {
            for ref in CompanyTargets.refs(for: design, following: following) {
                await refreshCompany(ref)
            }
        }
        if needs.contains(.fx) { await refreshFX() }
        if needs.contains(.tripWeather) { await refreshTripWeather() }
    }

    func refreshMarkets() async {
        prices = await MarketService.priceBook(for: portfolio, allowNetwork: true)
        quotes = await MarketService.coinQuotes(portfolio.watchlist, allowNetwork: true)
        global = await MarketService.global(allowNetwork: true)
        stocks = MarketService.cache.stocks
    }

    func refreshCompany(_ ref: CompanyRef) async {
        if let financials = await CompanyService.financials(ref, allowNetwork: true) {
            companies[ref.cik] = financials
        }
    }

    func refreshFX() async {
        fx = await FXService.rates(base: settings.currencyCode, allowNetwork: true)
    }

    func refreshTripWeather() async {
        guard let trip = TravelMath.currentTrip(travel, at: Date()) else { return }
        tripWeather = await TripWeatherService.load(for: trip, allowNetwork: true)
    }

    /// Asks the on-device model (when available) to phrase the analysis widgets.
    func refreshInsights() async {
        var payload = WidgetPayload()
        payload.settings = settings
        payload.content = content
        payload.weather = weather
        payload.events = events
        payload.domains = domains
        if await AIPhraser.refresh(payload: payload) {
            insights = InsightCache.load()
            scheduleWidgetReload()
        }
    }

    // MARK: Widgets

    /// Coalesces bursts of edits (typing a task, dragging a slider) into one widget reload.
    func scheduleWidgetReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Onboarding

    func completeOnboarding() {
        updateSettings {
            $0.hasCompletedOnboarding = true
            $0.hasChosenStyle = true
            $0.hasCompletedProfileSetup = true
        }
    }

    func setStyle(_ style: AppStyleID) {
        guard style != settings.appStyle else { return }
        updateSettings { $0.appStyle = style }
    }

    func setAppearance(_ mode: AppearanceMode) {
        guard mode != settings.appearance else { return }
        updateSettings { $0.appearance = mode }
    }

    /// Erases everything the user created. Premium status is kept (it belongs to the App Store account).
    func resetAllData() {
        for design in designs {
            if case let .photo(name) = design.background { ImageStore.delete(named: name) }
        }
        designs = []
        content = ContentState()
        var fresh = AppSettings()
        fresh.hasCompletedOnboarding = true
        // The look of the app is a preference, not data: it stays.
        fresh.appStyle = settings.appStyle
        fresh.appearance = settings.appearance
        fresh.hasChosenStyle = settings.hasChosenStyle
        fresh.profileName = settings.profileName
        fresh.hasCompletedProfileSetup = settings.hasCompletedProfileSetup
        settings = fresh
        store.designs = designs
        store.content = content
        store.settings = settings
        store.remove(.weather)
        store.remove(.crypto)
        for file in [StoreFile.nutrition, .fitness, .budget, .business, .portfolio, .following, .student, .travel, .car, .productivity, .life, .markets, .companies, .fx, .tripWeather, .insights] {
            store.remove(file)
        }
        // « Mes informations » start over too; the name stays, like the first name.
        var freshProfile = UserProfile()
        freshProfile.lastName = profile.lastName
        freshProfile.migrated = true
        profile = freshProfile
        store.save(profile)
        nutrition = NutritionState()
        fitness = FitnessState()
        budget = BudgetState()
        business = BusinessState()
        portfolio = PortfolioState()
        following = MarketsState()
        student = StudentState()
        travel = TravelState()
        car = CarState()
        productivity = ProductivityState()
        life = LifeState()
        insights = InsightCache()
        weather = .needsLocation
        crypto = [:]
        NotificationScheduler.cancelAll()
        scheduleWidgetReload()
    }
}

// MARK: - « Mes informations »

extension AppModel {
    /// Installs from before « Mes informations »: a value already changed in a space counts as given,
    /// and the body weight moves to the profile, its only home from now on.
    fileprivate func migrateProfile() {
        guard !profile.migrated else { return }
        var migrated = profile
        let nutritionDefaults = NutritionGoals()
        if nutrition.goals.kcal != nutritionDefaults.kcal { migrated.provided.insert(.kcalTarget) }
        if nutrition.goals.protein != nutritionDefaults.protein { migrated.provided.insert(.proteinTarget) }
        if nutrition.goals.carbs != nutritionDefaults.carbs { migrated.provided.insert(.carbsTarget) }
        if nutrition.goals.fat != nutritionDefaults.fat { migrated.provided.insert(.fatTarget) }
        if fitness.weeklyGoal != FitnessState().weeklyGoal { migrated.provided.insert(.weeklyWorkouts) }
        if budget.monthlyBudget != BudgetState().monthlyBudget { migrated.provided.insert(.monthlyBudget) }
        if business.name != BusinessState().name { migrated.provided.insert(.businessName) }
        if business.monthlyGoal != BusinessState().monthlyGoal { migrated.provided.insert(.businessGoal) }
        if productivity.weeklyFocusGoalHours != ProductivityState().weeklyFocusGoalHours { migrated.provided.insert(.focusGoal) }
        if content.hydration.goal != HydrationState().goal { migrated.provided.insert(.hydrationGoal) }
        if car.name != CarState().name { migrated.provided.insert(.carName) }
        if migrated.weightKg == nil, fitness.bodyWeightKg != FitnessState().bodyWeightKg {
            migrated.weightKg = fitness.bodyWeightKg
        }
        migrated.migrated = true
        profile = migrated
        store.save(profile)
    }

    /// The user cleared a value: it is unknown again (the space keeps its default, never shown as theirs).
    func forget(_ fact: ProvidedFact) {
        guard profile.provided.contains(fact) else { return }
        update(\.profile) { $0.provided.remove(fact) }
    }

    /// Today's odometer reading (replaces one already noted today). Clearing the field changes nothing.
    func setOdometer(_ kilometres: Double?) {
        guard let kilometres, kilometres > 0 else { return }
        let now = Date()
        update(\.car) { state in
            state.readings.removeAll { DateMath.isSameDay($0.date, now) }
            state.readings.append(OdometerReading(date: now, km: kilometres))
        }
    }

    /// The odometer as shown in « Mes informations »: today's reading while it is being typed, else the latest.
    var odometer: Double? {
        todayOdometerReading ?? CarMath.odometer(car)
    }

    private var todayOdometerReading: Double? {
        car.readings.last { DateMath.isSameDay($0.date, Date()) }?.km
    }

    private func markProvided(_ facts: ProvidedFact...) {
        guard !Set(facts).isSubset(of: profile.provided) else { return }
        update(\.profile) { $0.provided.formUnion(facts) }
    }

    /// The daily nutrition targets, kept by the Nutrition space. Nil leaves a target as it was.
    func setNutritionTargets(kcal: Double? = nil, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil) {
        update(\.nutrition) { state in
            if let kcal { state.goals.kcal = max(0, kcal) }
            if let protein { state.goals.protein = max(0, protein) }
            if let carbs { state.goals.carbs = max(0, carbs) }
            if let fat { state.goals.fat = max(0, fat) }
        }
        var facts: [ProvidedFact] = []
        if kcal != nil { facts.append(.kcalTarget) }
        if protein != nil { facts.append(.proteinTarget) }
        if carbs != nil { facts.append(.carbsTarget) }
        if fat != nil { facts.append(.fatTarget) }
        if !facts.isEmpty { update(\.profile) { $0.provided.formUnion(facts) } }
    }

    func setNutritionGoals(_ goals: NutritionGoals) {
        update(\.nutrition) { $0.goals = goals }
        markProvided(.kcalTarget, .proteinTarget, .carbsTarget, .fatTarget)
    }

    func setWeeklyWorkouts(_ count: Int) {
        update(\.fitness) { $0.weeklyGoal = min(7, max(1, count)) }
        markProvided(.weeklyWorkouts)
    }

    func setMonthlyBudget(_ amount: Double) {
        update(\.budget) { $0.monthlyBudget = max(0, amount) }
        markProvided(.monthlyBudget)
    }

    func setBusinessName(_ name: String) {
        update(\.business) { $0.name = name }
        markProvided(.businessName)
    }

    func setBusinessGoal(_ amount: Double) {
        update(\.business) { $0.monthlyGoal = max(0, amount) }
        markProvided(.businessGoal)
    }

    func setFocusGoal(_ hours: Double) {
        update(\.productivity) { $0.weeklyFocusGoalHours = max(0.5, hours) }
        markProvided(.focusGoal)
    }

    func setHydrationGoal(_ glasses: Int) {
        updateContent { $0.hydration.goal = min(20, max(1, glasses)) }
        markProvided(.hydrationGoal)
    }

    func setCarName(_ name: String) {
        update(\.car) { $0.name = name }
        markProvided(.carName)
    }

    /// The body weight: the profile is its only home, every space and widget reads it from there.
    func setWeight(_ kilograms: Double?) {
        update(\.profile) { $0.weightKg = kilograms.flatMap { $0 > 0 ? $0 : nil } }
    }

    /// The age, kept as a birth year unless the birthday of « Ma vie » is set.
    var age: Int? { profile.age(birthday: life.birthday) }

    func setAge(_ years: Int?) {
        update(\.profile) { profile in
            profile.birthYear = years.flatMap { $0 > 0 && $0 < 120 ? DateMath.calendar.component(.year, from: Date()) - $0 : nil }
        }
    }

    /// Nutrition targets from the profile (Mifflin-St Jeor), when age, height, weight and sex are known.
    func calculatedNutritionGoals(activity: NutritionCalculator.Activity) -> NutritionGoals? {
        guard let age, let height = profile.heightCm, let weight = profile.weightKg, let sex = profile.sex else { return nil }
        return NutritionCalculator.goals(
            sex: sex.calculatorSex, age: age, heightCm: height, weightKg: weight,
            activity: activity, goal: (profile.nutritionAim ?? profile.fitnessGoal?.nutritionAim ?? .maintain).calculatorGoal
        )
    }

    /// The activity level that goes with the workouts per week, when the user gave them.
    var activityFromWorkouts: NutritionCalculator.Activity? {
        guard profile.knows(.weeklyWorkouts) else { return nil }
        switch fitness.weeklyGoal {
        case ...1: return .sedentary
        case 2...3: return .light
        case 4...5: return .moderate
        default: return .active
        }
    }
}
