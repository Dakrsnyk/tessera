import Foundation

/// Mini-app data a widget may need. Only what its kind uses is loaded (see `DataNeeds`).
struct DomainData: Hashable {
    var nutrition = NutritionState()
    var fitness = FitnessState()
    var budget = BudgetState()
    var business = BusinessState()
    var portfolio = PortfolioState()
    var prices = PriceBook()
    var quotes: [CoinQuote] = []
    var global: MarketGlobal?
    var following = MarketsState()
    var companies: [CompanyFinancials] = []
    var stocks: [String: StockQuote] = [:]
    var student = StudentState()
    var travel = TravelState()
    var tripWeather: WeatherSnapshot?
    var fx: FXRates?
    var car = CarState()
    var productivity = ProductivityState()
    var life = LifeState()
    var insights = InsightCache()
    /// « Mes informations ». Nil for example data, which counts every value as given.
    var profile: UserProfile?

    /// Takes the facts whose only home is the profile into the spaces that use them.
    mutating func apply(_ profile: UserProfile) {
        self.profile = profile
        if let weight = profile.weightKg { fitness.bodyWeightKg = weight }
    }
}

enum DataNeed: Hashable {
    case content, weather, crypto, events
    case nutrition, fitness, budget, business, portfolio, quotes, global, companies
    case student, travel, tripWeather, fx, car, productivity, life, insights
}

enum DataNeeds {
    static func needs(for kind: WidgetKind) -> Set<DataNeed> {
        switch kind {
        case .clock, .calendar, .worldClock, .progress, .countdown, .yearDots, .note, .weekView, .moonPhase:
            return []
        case .ageProgress, .birthday, .holiday:
            return [.life]
        case .tasks, .habits, .focus, .hydration, .moneyFlow, .habitStreak, .habitWeek, .habitRate:
            return [.content]
        case .weather, .sunCycle, .rainNext, .windUV, .weatherDetails, .weeklyForecast:
            return [.weather]
        case .crypto:
            return [.crypto]
        case .upNext:
            return [.events]
        case .priorities, .project, .deadline, .counter:
            return [.productivity]
        case .deepWork:
            return [.productivity, .content]
        case .caloriesLeft, .macros, .proteinLeft, .mealsToday, .nutritionWeek, .nutritionStreak, .quickFood, .nextMeal:
            return [.nutrition]
        case .todaysWorkout, .nextSet, .restTimer, .weeklyVolume, .personalRecords, .trainingStreak, .caloriesBurned, .workoutMonth:
            return [.fitness]
        case .budgetLeft, .spendingByCategory, .billsUpcoming, .savingsGoal, .netWorth, .subscriptions, .quickExpense:
            return [.budget]
        case .portfolio, .allocation, .topMover:
            return [.portfolio]
        case .watchlist:
            return [.portfolio, .quotes]
        case .marketOverview:
            return [.global]
        case .revenueGoal, .revenueTrend, .profit, .businessKPIs, .mrr, .revenueToday, .businessDashboard:
            return [.business]
        case .companySnapshot, .companyRevenue, .companyStock, .companyCompare:
            return [.companies]
        case .nextClass, .nextExam, .assignments, .gradeAverage, .semesterProgress, .flashcard, .studyHours, .timetable:
            return [.student]
        case .tripCountdown, .flight, .hotel, .localTime, .tripProgress, .nextActivity:
            return [.travel]
        case .destinationWeather:
            return [.travel, .tripWeather]
        case .currency:
            return [.travel, .fx]
        case .carCost, .nextService, .mileage, .fuelStats, .carDeadlines:
            return [.car]
        case .myDay:
            return [.weather, .events, .content, .nutrition, .productivity]
        case .now:
            return [.weather, .events, .content, .productivity, .nutrition, .fitness, .budget]
        case .morning:
            return [.weather, .events, .productivity, .content, .budget]
        case .fitnessDashboard:
            return [.fitness, .nutrition]
        case .moneyDashboard:
            return [.budget]
        case .studentDashboard:
            return [.student]
        case .aiSummary:
            return [.weather, .events, .content, .productivity, .nutrition, .budget, .fitness, .insights]
        case .aiNutrition:
            return [.nutrition, .insights]
        case .aiFinance:
            return [.budget, .insights]
        case .aiProductivity:
            return [.productivity, .content, .insights]
        }
    }
}

extension PayloadLoader {
    /// Loads the mini-app data and network caches a design needs.
    static func loadDomains(for design: WidgetDesign, needs: Set<DataNeed>, into payload: inout WidgetPayload, allowNetwork: Bool, now: Date) async {
        let store = SharedStore.shared
        var data = DomainData()
        if needs.contains(.nutrition) { data.nutrition = store.state(NutritionState.self) }
        if needs.contains(.fitness) { data.fitness = store.state(FitnessState.self) }
        if needs.contains(.budget) { data.budget = store.state(BudgetState.self) }
        if needs.contains(.business) { data.business = store.state(BusinessState.self) }
        if needs.contains(.student) { data.student = store.state(StudentState.self) }
        if needs.contains(.car) { data.car = store.state(CarState.self) }
        if needs.contains(.productivity) { data.productivity = store.state(ProductivityState.self) }
        if needs.contains(.life) { data.life = store.state(LifeState.self) }
        if needs.contains(.insights) { data.insights = InsightCache.load() }
        if !needs.isDisjoint(with: [.nutrition, .fitness, .budget, .business, .productivity, .content, .car]) {
            data.apply(store.state(UserProfile.self))
        }
        if needs.contains(.portfolio) || needs.contains(.quotes) {
            data.portfolio = store.state(PortfolioState.self)
            data.prices = await MarketService.priceBook(for: data.portfolio, allowNetwork: allowNetwork)
        }
        if needs.contains(.quotes) {
            data.quotes = await MarketService.coinQuotes(data.portfolio.watchlist, allowNetwork: allowNetwork, now: now)
        }
        if needs.contains(.global) {
            data.global = await MarketService.global(allowNetwork: allowNetwork, now: now)
            data.quotes = await MarketService.coinQuotes(["bitcoin", "ethereum", "solana"], allowNetwork: allowNetwork, now: now)
        }
        if needs.contains(.companies) {
            data.following = store.state(MarketsState.self)
            let refs = CompanyTargets.refs(for: design, following: data.following)
            var companies: [CompanyFinancials] = []
            for ref in refs {
                if let financials = await CompanyService.financials(ref, allowNetwork: allowNetwork, now: now) {
                    companies.append(financials)
                }
            }
            data.companies = companies
            if design.kind == .companyStock {
                data.stocks = await MarketService.stockQuotes(refs.map(\.ticker), allowNetwork: allowNetwork, now: now)
            }
        }
        if needs.contains(.travel) || needs.contains(.tripWeather) || needs.contains(.fx) {
            data.travel = store.state(TravelState.self)
        }
        if needs.contains(.tripWeather), let trip = TravelMath.currentTrip(data.travel, at: now) {
            data.tripWeather = await TripWeatherService.load(for: trip, allowNetwork: allowNetwork, now: now)
        }
        if needs.contains(.fx) {
            data.fx = await FXService.rates(base: payload.settings.currencyCode, allowNetwork: allowNetwork, now: now)
        }
        payload.domains = data
    }
}

/// Which companies a design shows: the one picked in the editor, otherwise the followed list.
enum CompanyTargets {
    static func refs(for design: WidgetDesign, following: MarketsState) -> [CompanyRef] {
        if design.kind == .companyCompare {
            return Array(following.followed.prefix(4))
        }
        if let id = design.options.targetID, let ref = following.followed.first(where: { String($0.cik) == id }) {
            return [ref]
        }
        return Array(following.followed.prefix(1))
    }
}
