import Foundation

/// Example content for the system widget gallery, the Store previews and test builds.
/// Never shown on the Home Screen in place of the user's data. Companies are fictional on purpose.
enum SampleData {
    static func fill(_ payload: inout WidgetPayload, for kind: WidgetKind, now: Date) {
        let needs = DataNeeds.needs(for: kind)
        payload.domains = domains(now: now, ongoingTrip: ongoingTripKinds.contains(kind))
        if needs.contains(.weather) { payload.weather = .ready(weather(now: now)) }
        if needs.contains(.events) { payload.events = events(now: now) }
        if needs.contains(.content) { payload.content = content(now: now) }
    }

    private static let ongoingTripKinds: Set<WidgetKind> = [.tripProgress, .nextActivity, .hotel, .localTime, .destinationWeather, .currency]

    private static func day(_ offset: Int, _ hour: Int = 12, _ minute: Int = 0, from now: Date) -> Date {
        let start = DateMath.calendar.date(byAdding: .day, value: offset, to: DateMath.startOfDay(now)) ?? now
        return start.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }

    // MARK: Weather, events, content

    static func weather(now: Date, name: String = tr("Montréal"), shift: Double = 0) -> WeatherSnapshot {
        let startHour = DateMath.calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let rain = [0, 0, 5, 10, 20, 45, 70, 60, 35, 15, 5, 0, 0, 0, 10, 20, 30, 20, 10, 5, 0, 0, 0, 0]
        let hours = (0..<24).map { (offset: Int) -> HourForecast in
            let date = startHour.addingTimeInterval(Double(offset) * 3600)
            let hour = DateMath.calendar.component(.hour, from: date)
            let isDay = hour >= 7 && hour < 19
            let temperature = 14 + shift + 5 * sin(Double(hour - 9) / 24 * 2 * Double.pi)
            var forecast = HourForecast(date: date, temperature: temperature, code: rain[offset] > 40 ? 61 : (offset < 4 ? 1 : 3), isDay: isDay)
            forecast.precipitationProbability = rain[offset]
            forecast.uvIndex = isDay ? max(0, 6 - abs(Double(hour - 13))) : 0
            return forecast
        }
        let codes = [1, 3, 61, 0, 2, 80, 1]
        let days = (0..<7).map { (offset: Int) -> DayForecast in
            var forecast = DayForecast(date: day(offset, 0, from: now), code: codes[offset], high: 20 + shift + Double(offset % 3), low: 10 + shift + Double(offset % 2))
            forecast.sunrise = day(offset, 6, 52 + offset, from: now)
            forecast.sunset = day(offset, 18, 41 - 2 * offset, from: now)
            forecast.precipitationProbability = [10, 30, 80, 5, 20, 60, 10][offset]
            forecast.uvMax = [5.0, 4, 2, 6, 5, 3, 5][offset]
            return forecast
        }
        var snapshot = WeatherSnapshot(
            locationName: name, latitude: 45.5, longitude: -73.57, fetchedAt: now,
            temperature: 15 + shift, apparentTemperature: 14 + shift, code: 1, isDay: true, windSpeed: 14,
            high: 20 + shift, low: 10 + shift, hourly: hours, daily: days
        )
        snapshot.humidity = 62
        snapshot.pressure = 1016
        snapshot.windDirection = 250
        snapshot.windGusts = 31
        return snapshot
    }

    static func events(now: Date) -> EventsResult {
        .ready([
            EventSnapshot(id: "1", title: tr("Réunion d'équipe"), start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(5_400), isAllDay: false, colorHex: "3366FF"),
            EventSnapshot(id: "2", title: tr("Dentiste"), start: now.addingTimeInterval(4 * 3_600), end: now.addingTimeInterval(5 * 3_600), isAllDay: false, colorHex: "FF6B57"),
            EventSnapshot(id: "3", title: tr("Souper avec Léa"), start: now.addingTimeInterval(8 * 3_600), end: now.addingTimeInterval(10 * 3_600), isAllDay: false, colorHex: "2F8F7A"),
        ])
    }

    static func content(now: Date) -> ContentState {
        var content = ContentState()
        content.tasks = [
            TaskItem(title: tr("Appeler le garage"), priority: .medium, due: DateMath.startOfDay(now)),
            TaskItem(title: tr("Envoyer la facture"), priority: .high, due: day(0, 11, from: now), hasTime: true),
            TaskItem(title: tr("Courir 5 km"), isDone: true, completedAt: now, due: DateMath.startOfDay(now)),
            TaskItem(title: tr("Lire 20 pages"), due: DateMath.startOfDay(now), repeats: .daily),
            TaskItem(title: tr("Payer le loyer"), priority: .high, due: day(-1, 0, from: now)),
            TaskItem(title: tr("Réserver le resto pour samedi"), priority: .low, due: day(2, 0, from: now)),
            TaskItem(title: tr("Trier les photos de vacances")),
        ]
        func keys(_ offsets: [Int]) -> [String] { offsets.map { DateMath.dayKey(day(-$0, from: now)) } }
        content.habits = [
            Habit(name: tr("Méditer"), symbol: "brain.head.profile", colorHex: "8C6CFF", completedDays: keys(Array(0...11) + [13, 14, 16, 17, 18, 20, 22, 23, 25])),
            Habit(name: tr("Sport"), symbol: "figure.run", colorHex: "FF6B57", completedDays: keys([1, 2, 4, 6, 8, 9, 11, 13, 15, 16, 18, 20, 23, 25, 27])),
            Habit(name: tr("Lecture"), symbol: "book.fill", colorHex: "2F8F7A", completedDays: keys([0, 1, 2, 3, 5, 6, 7, 9, 10, 12, 14, 15, 17, 19, 21, 22, 24, 26, 28])),
            Habit(name: tr("Pas d'écran au lit"), symbol: "moon.zzz.fill", colorHex: "3366FF", completedDays: keys([0, 2, 3, 6, 9, 10, 13, 17, 20, 24])),
        ]
        content.hydration.add(5, on: now)
        return content
    }

    // MARK: Mini-apps

    static func domains(now: Date, ongoingTrip: Bool = false) -> DomainData {
        var data = DomainData()
        data.nutrition = nutrition(now: now)
        data.fitness = fitness(now: now)
        data.budget = budget(now: now)
        data.business = business(now: now)
        data.portfolio = portfolio(now: now)
        data.prices = PriceBook(prices: ["bitcoin": 64_210, "ethereum": 3_180], changes: ["bitcoin": 2.4, "ethereum": -1.2, "XEQT": 0.6, "AAPL": 1.1])
        data.quotes = [
            CoinQuote(id: "bitcoin", symbol: "BTC", name: tr("Bitcoin"), price: 64_210, change24h: 2.4),
            CoinQuote(id: "ethereum", symbol: "ETH", name: tr("Ethereum"), price: 3_180, change24h: -1.2),
            CoinQuote(id: "solana", symbol: "SOL", name: tr("Solana"), price: 148, change24h: 5.6),
        ]
        data.global = MarketGlobal(totalMarketCap: 2.35e12, change24h: 1.8, bitcoinDominance: 54.2, ethereumDominance: 12.1, fetchedAt: now)
        let example = CompanyRef(cik: 1, ticker: "EXMP", name: tr("Exemple Inc."))
        data.following = MarketsState()
        data.following.followed = [example, CompanyRef(cik: 2, ticker: "DEMO", name: tr("Démo Corp")), CompanyRef(cik: 3, ticker: "TEST", name: tr("Test Industries"))]
        data.companies = [
            company(example, base: 82e9, growth: 0.12, margin: 0.21, now: now),
            company(CompanyRef(cik: 2, ticker: "DEMO", name: tr("Démo Corp")), base: 54e9, growth: 0.06, margin: 0.14, now: now),
            company(CompanyRef(cik: 3, ticker: "TEST", name: tr("Test Industries")), base: 31e9, growth: 0.19, margin: 0.09, now: now),
        ]
        data.stocks = ["EXMP": StockQuote(symbol: "EXMP", price: 186.40, changePercent: 1.3, fetchedAt: now)]
        data.student = student(now: now)
        data.travel = travel(now: now, ongoing: ongoingTrip)
        data.tripWeather = weather(now: now, name: tr("Lisbonne"), shift: 6)
        data.fx = FXRates(base: "CAD", rates: ["EUR": 0.66, "USD": 0.73, "GBP": 0.55, "JPY": 106.2, "CHF": 0.62, "MXN": 13.4], day: DateMath.dayKey(now), fetchedAt: now)
        data.car = car(now: now)
        data.productivity = productivity(now: now)
        data.life = LifeState()
        data.life.birthday = Holidays.make(1998, 3, 14)
        return data
    }

    static func nutrition(now: Date) -> NutritionState {
        var state = NutritionState()
        let foods = FoodDatabase.self
        let today: [(String, Double, MealType, Int)] = [
            ("builtin.oats", 60, .breakfast, 8), ("builtin.banana", 120, .breakfast, 8), ("builtin.milk2", 250, .breakfast, 8),
            ("builtin.chicken", 150, .lunch, 12), ("builtin.rice", 180, .lunch, 12), ("builtin.broccoli", 100, .lunch, 12),
            ("builtin.greekyogurt", 175, .snack, 15),
        ]
        for (id, grams, meal, hour) in today {
            if let food = foods.item(id) { state.log(food, grams: grams, meal: meal, at: day(0, hour, 10, from: now)) }
        }
        // Earlier days: real meals from a few usual menus, two days left untracked.
        let menus: [[(String, Double, MealType)]] = [
            [("builtin.greekyogurt", 175, .breakfast), ("builtin.granola", 50, .breakfast), ("builtin.blueberries", 100, .breakfast),
             ("builtin.chickenwrap", 250, .lunch), ("builtin.apple", 180, .snack),
             ("builtin.salmon", 150, .dinner), ("builtin.rice", 200, .dinner), ("builtin.greenbeans", 120, .dinner)],
            [("builtin.egg", 100, .breakfast), ("builtin.wholebread", 70, .breakfast), ("builtin.orangejuice", 250, .breakfast),
             ("builtin.poke", 400, .lunch), ("builtin.proteinbar", 60, .snack),
             ("builtin.spaghetti", 380, .dinner), ("builtin.caesar", 120, .dinner)],
            [("builtin.oats", 60, .breakfast), ("builtin.milk2", 250, .breakfast), ("builtin.banana", 120, .breakfast),
             ("builtin.sandwich", 150, .lunch), ("builtin.soup", 250, .lunch), ("builtin.almonds", 28, .snack),
             ("builtin.chicken", 160, .dinner), ("builtin.sweetpotato", 200, .dinner), ("builtin.broccoli", 120, .dinner)],
            [("builtin.bagel", 100, .breakfast), ("builtin.creamcheese", 30, .breakfast), ("builtin.latte", 350, .breakfast),
             ("builtin.burrito", 280, .lunch), ("builtin.greekyogurt", 175, .snack),
             ("builtin.stirfry", 350, .dinner), ("builtin.ricenoodles", 175, .dinner)],
        ]
        let hours: [MealType: Int] = [.breakfast: 8, .lunch: 12, .snack: 15, .dinner: 19]
        for offset in 1...45 where offset != 6 && offset != 17 {
            for (id, grams, meal) in menus[offset % menus.count] {
                guard let food = foods.item(id) else { continue }
                // A little variety from one week to the next.
                let factor = 0.9 + Double((offset * 7) % 5) * 0.05
                let date = SampleData.day(-offset, hours[meal] ?? 12, from: now)
                state.entries.append(FoodEntry(date: date, meal: meal, food: food, grams: (grams * factor).rounded()))
            }
        }
        if let oats = foods.item("builtin.oats"), let milk = foods.item("builtin.milk2"), let whey = foods.item("builtin.whey"), let banana = foods.item("builtin.banana") {
            state.savedMeals = [SavedMeal(name: tr("Déjeuner protéiné"), items: [
                SavedMeal.Item(food: oats, grams: 60), SavedMeal.Item(food: milk, grams: 250),
                SavedMeal.Item(food: whey, grams: 30), SavedMeal.Item(food: banana, grams: 120),
            ])]
        }
        state.entries.sort { $0.date < $1.date }
        state.favorites = ["builtin.greekyogurt", "builtin.banana", "builtin.latte", "builtin.whey"].compactMap { foods.item($0) }
        state.recentFoods = state.favorites
        return state
    }

    static func fitness(now: Date) -> FitnessState {
        var state = FitnessState()
        state.bodyWeightKg = 75
        let upper = Routine(name: tr("Haut du corps"), exercises: [
            ExerciseTemplate(name: tr("Développé couché"), sets: 4, reps: 8, weight: 60, restSeconds: 120),
            ExerciseTemplate(name: tr("Tractions"), sets: 4, reps: 8, weight: 0, restSeconds: 90),
            ExerciseTemplate(name: tr("Développé militaire"), sets: 3, reps: 10, weight: 35, restSeconds: 90),
            ExerciseTemplate(name: tr("Rowing haltère"), sets: 3, reps: 10, weight: 24, restSeconds: 75),
        ], weekdays: [1, 4])
        let lower = Routine(name: tr("Bas du corps"), exercises: [
            ExerciseTemplate(name: tr("Squat"), sets: 4, reps: 6, weight: 80, restSeconds: 150),
            ExerciseTemplate(name: tr("Soulevé de terre roumain"), sets: 3, reps: 8, weight: 70, restSeconds: 120),
            ExerciseTemplate(name: tr("Fentes"), sets: 3, reps: 10, weight: 20, restSeconds: 90),
        ], weekdays: [2, 5])
        let full = Routine(name: tr("Full body"), exercises: [
            ExerciseTemplate(name: tr("Soulevé de terre"), sets: 3, reps: 5, weight: 100, restSeconds: 180),
            ExerciseTemplate(name: tr("Pompes"), sets: 3, reps: 15, weight: 0, restSeconds: 60),
        ], weekdays: [3, 6, 7])
        state.routines = [upper, lower, full]
        // Four weeks of history on the planned days.
        for offset in 1...27 {
            let date = day(-offset, 18, from: now)
            let weekday = FitnessMath.isoWeekday(date)
            guard let routine = state.routines.first(where: { $0.weekdays.contains(weekday) }), weekday != 3, weekday != 7 else { continue }
            var session = WorkoutSession(routineID: routine.id, routineName: routine.name, exercises: routine.exercises, start: date)
            let progression = Double(27 - offset) / 27 * 5
            for exercise in routine.exercises {
                for index in 0..<exercise.sets {
                    let weight = exercise.weight > 0 ? exercise.weight - 5 + progression : 0
                    session.sets.append(SetLog(exercise: exercise.name, reps: exercise.reps, weight: weight, date: date.addingTimeInterval(Double(index) * 180)))
                }
            }
            session.end = date.addingTimeInterval(55 * 60)
            session.exerciseIndex = routine.exercises.count
            state.history.append(session)
        }
        if let routine = state.routine(for: now) {
            state.startSession(routine, at: now.addingTimeInterval(-25 * 60))
            for _ in 0..<3 { state.completeNextSet(at: now.addingTimeInterval(-60)) }
            state.active?.restEndsAt = now.addingTimeInterval(75)
        }
        return state
    }

    static func budget(now: Date) -> BudgetState {
        var state = BudgetState()
        state.monthlyBudget = 2_400
        let cat = BudgetState.fixedID
        let dayOfMonth = DateMath.calendar.component(.day, from: now)
        let plan: [(Double, Int, String)] = [
            (86.40, 1, "IGA"), (4.50, 2, tr("Café")), (32.00, 4, tr("Cinéma")), (112.75, 1, tr("Costco")), (3.75, 3, tr("Bus")),
            (18.90, 2, tr("Lunch")), (64.20, 5, tr("Quincaillerie")), (41.30, 1, tr("Marché")), (27.00, 2, tr("Pizza")), (90.00, 3, tr("Passe mensuelle")),
            (15.00, 4, tr("Musée")), (58.60, 1, tr("Épicerie")), (22.40, 2, tr("Resto")), (35.00, 6, tr("Cadeau")), (9.99, 6, tr("App")),
        ]
        for (index, item) in plan.enumerated() {
            let dayNumber = min(dayOfMonth, 1 + index * 2)
            let date = day(dayNumber - dayOfMonth, 12 + index % 6, from: now)
            state.add(Expense(amount: item.0, categoryID: cat(item.1), note: item.2, date: date))
        }
        // Last week, for the comparison.
        for (index, amount) in [52.0, 12.5, 30.0, 8.75, 44.0].enumerated() {
            state.add(Expense(amount: amount, categoryID: cat([1, 2, 4, 3, 1][index]), note: "", date: day(-7 - index % 3, 13, from: now)))
        }
        // The five months before, for the evolution: groceries, restaurants, transport, outings, home.
        let calendar = DateMath.calendar
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        for back in 1...5 {
            guard let start = calendar.date(byAdding: .month, value: -back, to: monthStart) else { continue }
            let past: [(Double, Int, String, Int)] = [
                (92 + Double(back * 7), 1, tr("Épicerie"), 2), (118 - Double(back * 5), 1, tr("Costco"), 9), (84 + Double(back * 3), 1, "IGA", 16), (101, 1, tr("Marché"), 24),
                (24 + Double(back * 4), 2, tr("Resto"), 5), (46 - Double(back * 2), 2, tr("Brunch"), 13), (31, 2, tr("Pizza"), 21),
                (90, 3, tr("Passe mensuelle"), 1), (22 + Double(back), 3, tr("Taxi"), 18),
                (38 + Double(back * 6), 4, tr("Spectacle"), 11), (19, 4, tr("Cinéma"), 26),
                (Double(40 + back * 13), 5, tr("Quincaillerie"), 7), (27.5, 6, tr("Divers"), 20),
            ]
            for item in past {
                let date = start.addingTimeInterval(TimeInterval(item.3 - 1) * 86_400 + 13 * 3_600)
                state.add(Expense(amount: item.0, categoryID: cat(item.1), note: item.2, date: date))
            }
        }
        // The pay, twice a month, and a freelance job now and then.
        for back in 0...5 {
            guard let start = calendar.date(byAdding: .month, value: -back, to: monthStart) else { continue }
            for payDay in [1, 15] {
                let date = start.addingTimeInterval(TimeInterval(payDay - 1) * 86_400 + 9 * 3_600)
                if date <= now { state.addIncome(IncomeEntry(amount: 1_500, label: tr("Salaire"), date: date)) }
            }
            if back % 2 == 1 {
                state.addIncome(IncomeEntry(amount: 350 + Double(back * 40), label: tr("Contrat de design"), date: start.addingTimeInterval(19 * 86_400 + 15 * 3_600)))
            }
        }
        state.quickExpenses = [
            QuickExpense(name: tr("Café"), amount: 4.5, categoryID: cat(2), symbol: "cup.and.saucer.fill"),
            QuickExpense(name: tr("Bus"), amount: 3.75, categoryID: cat(3), symbol: "bus.fill"),
            QuickExpense(name: tr("Lunch"), amount: 15, categoryID: cat(2), symbol: "takeoutbag.and.cup.and.straw.fill"),
        ]
        state.bills = [
            Bill(name: tr("Loyer"), amount: 1_250, anchorDate: day(3, 0, from: now), symbol: "house.fill"),
            Bill(name: tr("Hydro"), amount: 86, anchorDate: day(9, 0, from: now), symbol: "bolt.fill"),
            Bill(name: tr("Internet"), amount: 70, anchorDate: day(12, 0, from: now), symbol: "wifi"),
            Bill(name: tr("Netflix"), amount: 16.99, anchorDate: day(5, 0, from: now), isSubscription: true, symbol: "play.tv.fill"),
            Bill(name: tr("Spotify"), amount: 11.99, anchorDate: day(15, 0, from: now), isSubscription: true, symbol: "music.note"),
            Bill(name: "iCloud+", amount: 3.99, anchorDate: day(1, 0, from: now), isSubscription: true, symbol: "icloud.fill"),
            Bill(name: tr("Salle de sport"), amount: 39.99, anchorDate: day(20, 0, from: now), isSubscription: true, symbol: "dumbbell.fill"),
        ]
        state.goals = [
            SavingsGoal(name: tr("Voyage au Japon"), target: 5_000, saved: 2_150, deadline: day(240, 0, from: now)),
            SavingsGoal(name: tr("Fonds d'urgence"), target: 10_000, saved: 6_400, deadline: nil),
        ]
        state.accounts = [
            Account(name: tr("Compte chèque"), balance: 2_350),
            Account(name: tr("Épargne"), balance: 6_400),
            Account(name: tr("CELI"), balance: 12_500),
            Account(name: tr("Carte de crédit"), balance: 850, isLiability: true),
            Account(name: tr("Prêt auto"), balance: 9_800, isLiability: true),
        ]
        let worth = BudgetMath.netWorth(state)
        state.netWorthHistory = (0..<30).map { offset in
            ValuePoint(date: day(offset - 29, 0, from: now), value: worth - Double(29 - offset) * 38 + sin(Double(offset) / 3) * 120)
        }
        return state
    }

    static func business(now: Date) -> BusinessState {
        var state = BusinessState()
        state.name = tr("Atelier Nova")
        state.monthlyGoal = 12_000
        for offset in 0..<62 {
            let date = day(-offset, 8, from: now)
            let wave = sin(Double(offset) / 4) * 120
            let amount = 420 + wave + Double((offset * 37) % 150) - Double(offset) * 2
            let orders = 4 + (offset * 7) % 5
            state.sales.append(SalesEntry(date: date, amount: max(90, amount), orders: orders, newCustomers: 1 + offset % 3, visitors: 160 + (offset * 13) % 90))
        }
        state.expenses = [
            BusinessExpense(date: day(-2, from: now), amount: 900, label: tr("Publicité")),
            BusinessExpense(date: day(-6, from: now), amount: 620, label: tr("Matériel")),
            BusinessExpense(date: day(-9, from: now), amount: 49, label: tr("Hébergement")),
            BusinessExpense(date: day(-12, from: now), amount: 310, label: tr("Frais de paiement")),
            BusinessExpense(date: day(-15, from: now), amount: 1_450, label: tr("Sous-traitance")),
        ]
        let mrr: [Double] = [2_100, 2_380, 2_620, 2_890, 3_150, 3_420]
        state.subscriptions = mrr.enumerated().map { pair in
            SubscriptionSnapshot(month: DateMath.calendar.date(byAdding: .month, value: pair.offset - 5, to: now) ?? now, mrr: pair.element, subscribers: 70 + pair.offset * 8)
        }
        state.pinnedKPIs = [.revenue, .profit, .orders, .averageBasket, .conversion, .mrr]
        var followers = CustomMetric(name: tr("Abonnés Instagram"), target: 5_000)
        var quotes = CustomMetric(name: tr("Devis envoyés"), unit: tr("devis"))
        for week in 0..<8 {
            let date = day(-7 * (7 - week), 18, from: now)
            followers.record(Double(3_120 + week * 145 + (week % 3) * 40), at: date)
            quotes.record(Double(4 + (week * 3) % 5), at: date)
        }
        state.metrics = [followers, quotes]
        return state
    }

    static func portfolio(now: Date) -> PortfolioState {
        var state = PortfolioState()
        state.holdings = [
            Holding(kind: .etf, name: tr("iShares Core Equity"), symbol: "XEQT", quantity: 120, costBasis: 3_300, manualPrice: 32.4),
            Holding(kind: .stock, name: tr("Exemple Inc."), symbol: "EXMP", quantity: 15, costBasis: 2_450, manualPrice: 186.4),
            Holding(kind: .crypto, name: tr("Bitcoin"), symbol: "bitcoin", quantity: 0.08, costBasis: 4_200),
            Holding(kind: .crypto, name: tr("Ethereum"), symbol: "ethereum", quantity: 1.2, costBasis: 3_000),
            Holding(kind: .cash, name: tr("Liquidités"), symbol: "CAD", quantity: 1_500, costBasis: 1_500),
        ]
        return state
    }

    private static func company(_ ref: CompanyRef, base: Double, growth: Double, margin: Double, now: Date) -> CompanyFinancials {
        let year = DateMath.calendar.component(.year, from: now) - 1
        let annual = (0..<5).map { index -> FinancialPeriod in
            let value = base * pow(1 + growth, Double(index))
            return FinancialPeriod(label: String(year - 4 + index), end: Holidays.make(year - 4 + index, 12, 31), value: value)
        }
        let income = annual.map { FinancialPeriod(label: $0.label, end: $0.end, value: $0.value * margin) }
        let quarterly = (0..<8).map { index -> FinancialPeriod in
            let quarter = index % 4 + 1
            let qYear = year - 1 + index / 4
            let trend: Double = pow(1 + growth, 3 + Double(index) / 4)
            let wobble: Double = 1 + 0.06 * sin(Double(index))
            let value: Double = base * trend / 4 * wobble
            return FinancialPeriod(label: "T\(quarter) \(qYear)", end: Holidays.make(qYear, quarter * 3, 28), value: value)
        }
        return CompanyFinancials(ref: ref, annualRevenue: annual, quarterlyRevenue: quarterly, annualNetIncome: income, sharesOutstanding: 2.4e9, fetchedAt: now)
    }

    static func student(now: Date) -> StudentState {
        var state = StudentState()
        let math = Course(name: tr("Mathématiques"), colorHex: "3366FF", teacher: tr("Mme Tremblay"), credits: 3)
        let bio = Course(name: tr("Biologie"), colorHex: "D6409F", teacher: tr("M. Gagnon"), credits: 3)
        let history = Course(name: tr("Histoire"), colorHex: "F2A33A", teacher: tr("Mme Roy"), credits: 2)
        let english = Course(name: tr("Anglais"), colorHex: "1E9E75", teacher: tr("M. Smith"), credits: 2)
        state.courses = [math, bio, history, english]
        var slots: [ClassSlot] = []
        for weekday in 1...5 {
            slots.append(ClassSlot(courseID: [math, bio, history, english, math][weekday - 1].id, weekday: weekday, startMinute: 8 * 60 + 30, endMinute: 10 * 60 + 20, room: ["B-204", tr("Labo 3"), "A-110", "C-015", "B-204"][weekday - 1]))
            slots.append(ClassSlot(courseID: [bio, english, math, history, bio][weekday - 1].id, weekday: weekday, startMinute: 13 * 60, endMinute: 14 * 60 + 50, room: [tr("Labo 3"), "C-015", "B-204", "A-110", tr("Labo 1")][weekday - 1]))
            slots.append(ClassSlot(courseID: [history, math, english, bio, english][weekday - 1].id, weekday: weekday, startMinute: 15 * 60, endMinute: 16 * 60 + 20, room: ["A-110", "B-204", "C-015", tr("Labo 3"), "C-015"][weekday - 1]))
        }
        state.slots = slots
        state.exams = [
            Exam(courseID: bio.id, title: tr("Intra de biologie"), date: day(6, 9, from: now), room: tr("Gymnase")),
            Exam(courseID: math.id, title: tr("Examen final de maths"), date: day(21, 13, 30, from: now), room: "B-204"),
        ]
        state.assignments = [
            Assignment(courseID: bio.id, title: tr("Rapport de labo"), due: day(2, 23, 59, from: now)),
            Assignment(courseID: history.id, title: tr("Dissertation"), due: day(5, 17, from: now)),
            Assignment(courseID: math.id, title: tr("Exercices ch. 4"), due: day(1, 9, from: now), isDone: true),
            Assignment(courseID: english.id, title: tr("Oral en équipe"), due: day(9, 10, from: now)),
        ]
        state.grades = [
            Grade(courseID: math.id, title: tr("Quiz 1"), score: 17, maxScore: 20, weight: 10),
            Grade(courseID: math.id, title: tr("Devoir 1"), score: 82, maxScore: 100, weight: 15),
            Grade(courseID: bio.id, title: tr("Labo 1"), score: 88, maxScore: 100, weight: 15),
            Grade(courseID: bio.id, title: tr("Quiz"), score: 7, maxScore: 10, weight: 10),
            Grade(courseID: history.id, title: tr("Exposé"), score: 91, maxScore: 100, weight: 20),
            Grade(courseID: english.id, title: tr("Rédaction"), score: 76, maxScore: 100, weight: 20),
        ]
        state.cards = [
            Flashcard(deck: tr("Biologie"), front: tr("Mitochondrie"), back: tr("Organite qui produit l'énergie de la cellule (ATP)."), box: 2, due: now.addingTimeInterval(-600)),
            Flashcard(deck: tr("Biologie"), front: tr("Photosynthèse"), back: tr("Production de glucose à partir de CO₂, d'eau et de lumière."), box: 1, due: now.addingTimeInterval(-300)),
            Flashcard(deck: tr("Histoire"), front: "1867", back: tr("Confédération canadienne."), box: 3, due: day(2, 0, from: now)),
            Flashcard(deck: tr("Anglais"), front: tr("To overcome"), back: tr("Surmonter"), box: 1, due: now.addingTimeInterval(-60)),
        ]
        let week = DateMath.week(containing: now)
        for (index, date) in week.enumerated() where date <= now {
            state.sessions.append(StudySession(date: date.addingTimeInterval(19 * 3600), minutes: [95, 60, 120, 45, 80, 150, 30][index], courseID: nil))
        }
        state.semesterStart = day(-45, 0, from: now)
        state.semesterEnd = day(60, 0, from: now)
        state.weeklyStudyGoalHours = 12
        return state
    }

    static func travel(now: Date, ongoing: Bool) -> TravelState {
        var state = TravelState()
        let startOffset = ongoing ? -3 : 18
        let start = day(startOffset, 21, 30, from: now)
        let end = day(startOffset + 9, 18, from: now)
        state.trips = [Trip(destination: tr("Lisbonne"), start: start, end: end, timeZoneID: "Europe/Lisbon", currencyCode: "EUR", latitude: 38.72, longitude: -9.14)]
        state.flights = [Flight(number: tr("TP 258"), from: "YUL", to: "LIS", departure: start, arrival: start.addingTimeInterval(6.5 * 3600), terminal: "A", gate: "52", seat: "23C")]
        state.stays = [Stay(name: tr("Hôtel Alfama"), address: tr("Rua de São Miguel 12, Lisbonne"), checkIn: day(startOffset + 1, 15, from: now), checkOut: day(startOffset + 9, 11, from: now), confirmation: "HX4821")]
        let base = ongoing ? 0 : startOffset + 1
        state.activities = [
            TripActivity(title: tr("Château Saint-Georges"), date: day(base, ongoing ? 15 : 10, from: now), place: tr("Alfama")),
            TripActivity(title: tr("Tram 28"), date: day(base + 1, 11, from: now), place: tr("Martim Moniz")),
            TripActivity(title: tr("Pastéis de Belém"), date: day(base + 2, 15, from: now), place: tr("Belém")),
        ]
        state.sampleAmount = 100
        let trip = state.trips[0]
        state.trips[0].budget = 3_200
        state.expenses = [
            TripExpense(tripID: trip.id, amount: 1_180, currencyCode: "CAD", kind: .transport, label: tr("Billets d'avion"), date: day(-40, 20, from: now)),
            TripExpense(tripID: trip.id, amount: 896, currencyCode: "EUR", kind: .lodging, label: tr("Hôtel Alfama"), date: day(-30, 20, from: now)),
        ]
        if ongoing {
            state.expenses += [
                TripExpense(tripID: trip.id, amount: 42.5, currencyCode: "EUR", kind: .food, label: tr("Souper à Alfama"), date: day(-2, 21, from: now)),
                TripExpense(tripID: trip.id, amount: 18, currencyCode: "EUR", kind: .transport, label: tr("Carte Viva Viagem"), date: day(-2, 10, from: now)),
                TripExpense(tripID: trip.id, amount: 15, currencyCode: "EUR", kind: .activities, label: tr("Château Saint-Georges"), date: day(-1, 15, from: now)),
                TripExpense(tripID: trip.id, amount: 31.8, currencyCode: "EUR", kind: .food, label: tr("Marché de Campo de Ourique"), date: day(-1, 13, from: now)),
            ]
        }
        state.addEssentials(to: trip.id, abroad: true)
        for index in state.checklist.indices where index % 3 != 2 {
            state.checklist[index].isDone = ongoing || index < 3
        }
        return state
    }

    static func car(now: Date) -> CarState {
        var state = CarState()
        state.name = tr("Civic 2019")
        state.tankLiters = 47
        var odometer = 61_200.0
        for index in 0..<10 {
            let date = day(-95 + index * 10, 17, from: now)
            odometer += 430 + Double((index * 53) % 80)
            let liters = 36 + Double((index * 7) % 6)
            let price = 1.62 + Double(index % 4) * 0.03
            state.fills.append(FuelFill(date: date, liters: liters, total: liters * price, odometer: odometer, isFull: true))
        }
        state.readings = [OdometerReading(date: day(-1, 18, from: now), km: odometer + 180)]
        let current = odometer + 180
        state.services = [
            ServiceItem(name: tr("Vidange d'huile"), intervalKm: 8_000, intervalMonths: 6, lastKm: current - 6_400, lastDate: DateMath.calendar.date(byAdding: .month, value: -4, to: now), cost: 90),
            ServiceItem(name: tr("Rotation des pneus"), intervalKm: 10_000, intervalMonths: nil, lastKm: current - 3_100, lastDate: nil, cost: 40),
            ServiceItem(name: tr("Plaquettes de frein"), intervalKm: 40_000, intervalMonths: nil, lastKm: current - 21_000, lastDate: nil, cost: 320),
        ]
        let year = DateMath.calendar.component(.year, from: now)
        let winter = Holidays.make(year, 12, 1)
        state.deadlines = [
            CarDeadline(title: tr("Pneus d'hiver"), date: winter < now ? Holidays.make(year + 1, 12, 1) : winter, symbol: "snowflake"),
            CarDeadline(title: tr("Immatriculation"), date: day(64, 0, from: now), symbol: "doc.text.fill"),
            CarDeadline(title: tr("Assurance auto"), date: day(142, 0, from: now), symbol: "shield.fill"),
        ]
        state.insuranceMonthly = 95
        state.loanMonthly = 320
        state.parkingMonthly = 60
        state.maintenanceYearly = 600
        return state
    }

    static func productivity(now: Date) -> ProductivityState {
        var state = ProductivityState()
        let today = DateMath.dayKey(now)
        state.priorities = [
            PriorityItem(title: tr("Finir la présentation"), doneDayKey: today),
            PriorityItem(title: tr("Appeler le comptable")),
            PriorityItem(title: tr("30 minutes de sport")),
        ]
        let tasks = [tr("Maquettes"), tr("Textes"), tr("Photos"), tr("Paiement en ligne"), tr("Tests"), tr("Nom de domaine"), tr("Annonce"), tr("Mise en ligne")]
        state.projects = [Project(name: tr("Lancement du site"), colorHex: "3366FF", deadline: day(12, 17, from: now), tasks: tasks.enumerated().map { pair in
            ProjectTask(title: pair.element, isDone: pair.offset < 5, completedAt: pair.offset < 5 ? day(-pair.offset, from: now) : nil)
        })]
        state.deadlines = [Deadline(title: tr("Rendu du rapport"), date: day(2, 17, from: now))]
        state.counters = [
            CounterItem(name: tr("Cafés"), symbol: "cup.and.saucer.fill", colorHex: "B7791F", step: 1, goal: 3, resetsDaily: true, total: 2, dayKey: today),
            CounterItem(name: tr("Pompes"), symbol: "figure.strengthtraining.functional", colorHex: "E5484D", step: 10, goal: 100, resetsDaily: true, total: 40, dayKey: today),
        ]
        let week = DateMath.week(containing: now)
        for (index, date) in week.enumerated() where date <= now {
            let minutes = [[50, 25], [90], [25, 50, 25], [50], [90, 25], [45], [25]][index]
            for (slot, length) in minutes.enumerated() {
                state.focusLog.append(FocusLog(start: date.addingTimeInterval(TimeInterval(9 + slot * 2) * 3600), minutes: length))
            }
        }
        state.weeklyFocusGoalHours = 10
        return state
    }
}
