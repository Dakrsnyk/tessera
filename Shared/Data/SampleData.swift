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

    static func weather(now: Date, name: String = "Montréal", shift: Double = 0) -> WeatherSnapshot {
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
            EventSnapshot(id: "1", title: "Réunion d'équipe", start: now.addingTimeInterval(3_600), end: now.addingTimeInterval(5_400), isAllDay: false, colorHex: "3366FF"),
            EventSnapshot(id: "2", title: "Dentiste", start: now.addingTimeInterval(4 * 3_600), end: now.addingTimeInterval(5 * 3_600), isAllDay: false, colorHex: "FF6B57"),
            EventSnapshot(id: "3", title: "Souper avec Léa", start: now.addingTimeInterval(8 * 3_600), end: now.addingTimeInterval(10 * 3_600), isAllDay: false, colorHex: "2F8F7A"),
        ])
    }

    static func content(now: Date) -> ContentState {
        var content = ContentState()
        content.tasks = [
            TaskItem(title: "Appeler le garage"),
            TaskItem(title: "Envoyer la facture"),
            TaskItem(title: "Courir 5 km", isDone: true, completedAt: now),
            TaskItem(title: "Lire 20 pages"),
        ]
        func keys(_ offsets: [Int]) -> [String] { offsets.map { DateMath.dayKey(day(-$0, from: now)) } }
        content.habits = [
            Habit(name: "Méditer", symbol: "brain.head.profile", colorHex: "8C6CFF", completedDays: keys(Array(0...11) + [13, 14, 16, 17, 18, 20, 22, 23, 25])),
            Habit(name: "Sport", symbol: "figure.run", colorHex: "FF6B57", completedDays: keys([1, 2, 4, 6, 8, 9, 11, 13, 15, 16, 18, 20, 23, 25, 27])),
            Habit(name: "Lecture", symbol: "book.fill", colorHex: "2F8F7A", completedDays: keys([0, 1, 2, 3, 5, 6, 7, 9, 10, 12, 14, 15, 17, 19, 21, 22, 24, 26, 28])),
            Habit(name: "Pas d'écran au lit", symbol: "moon.zzz.fill", colorHex: "3366FF", completedDays: keys([0, 2, 3, 6, 9, 10, 13, 17, 20, 24])),
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
            CoinQuote(id: "bitcoin", symbol: "BTC", name: "Bitcoin", price: 64_210, change24h: 2.4),
            CoinQuote(id: "ethereum", symbol: "ETH", name: "Ethereum", price: 3_180, change24h: -1.2),
            CoinQuote(id: "solana", symbol: "SOL", name: "Solana", price: 148, change24h: 5.6),
        ]
        data.global = MarketGlobal(totalMarketCap: 2.35e12, change24h: 1.8, bitcoinDominance: 54.2, ethereumDominance: 12.1, fetchedAt: now)
        let example = CompanyRef(cik: 1, ticker: "EXMP", name: "Exemple Inc.")
        data.following = MarketsState()
        data.following.followed = [example, CompanyRef(cik: 2, ticker: "DEMO", name: "Démo Corp"), CompanyRef(cik: 3, ticker: "TEST", name: "Test Industries")]
        data.companies = [
            company(example, base: 82e9, growth: 0.12, margin: 0.21, now: now),
            company(CompanyRef(cik: 2, ticker: "DEMO", name: "Démo Corp"), base: 54e9, growth: 0.06, margin: 0.14, now: now),
            company(CompanyRef(cik: 3, ticker: "TEST", name: "Test Industries"), base: 31e9, growth: 0.19, margin: 0.09, now: now),
        ]
        data.stocks = ["EXMP": StockQuote(symbol: "EXMP", price: 186.40, changePercent: 1.3, fetchedAt: now)]
        data.student = student(now: now)
        data.travel = travel(now: now, ongoing: ongoingTrip)
        data.tripWeather = weather(now: now, name: "Lisbonne", shift: 6)
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
        let typicalDay = FoodItem(id: "sample.day", name: "Journée", brand: nil, kcal: 100, protein: 6, carbs: 12, fat: 3.3, fiber: 1.3, servingGrams: 100, servingName: "", source: .custom, barcode: nil)
        let totals: [Double] = [2150, 1980, 2320, 2090, 2410, 1870, 2230, 2050, 2190, 1960, 2280, 2120, 2010]
        for (offset, kcal) in totals.enumerated() {
            let date = SampleData.day(-(offset + 1), 13, from: now)
            state.entries.append(FoodEntry(date: date, meal: .lunch, food: typicalDay, grams: kcal))
        }
        state.entries.sort { $0.date < $1.date }
        state.favorites = ["builtin.greekyogurt", "builtin.banana", "builtin.latte", "builtin.whey"].compactMap { foods.item($0) }
        state.recentFoods = state.favorites
        return state
    }

    static func fitness(now: Date) -> FitnessState {
        var state = FitnessState()
        state.bodyWeightKg = 75
        let upper = Routine(name: "Haut du corps", exercises: [
            ExerciseTemplate(name: "Développé couché", sets: 4, reps: 8, weight: 60, restSeconds: 120),
            ExerciseTemplate(name: "Tractions", sets: 4, reps: 8, weight: 0, restSeconds: 90),
            ExerciseTemplate(name: "Développé militaire", sets: 3, reps: 10, weight: 35, restSeconds: 90),
            ExerciseTemplate(name: "Rowing haltère", sets: 3, reps: 10, weight: 24, restSeconds: 75),
        ], weekdays: [1, 4])
        let lower = Routine(name: "Bas du corps", exercises: [
            ExerciseTemplate(name: "Squat", sets: 4, reps: 6, weight: 80, restSeconds: 150),
            ExerciseTemplate(name: "Soulevé de terre roumain", sets: 3, reps: 8, weight: 70, restSeconds: 120),
            ExerciseTemplate(name: "Fentes", sets: 3, reps: 10, weight: 20, restSeconds: 90),
        ], weekdays: [2, 5])
        let full = Routine(name: "Full body", exercises: [
            ExerciseTemplate(name: "Soulevé de terre", sets: 3, reps: 5, weight: 100, restSeconds: 180),
            ExerciseTemplate(name: "Pompes", sets: 3, reps: 15, weight: 0, restSeconds: 60),
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
            (86.40, 1, "IGA"), (4.50, 2, "Café"), (32.00, 4, "Cinéma"), (112.75, 1, "Costco"), (3.75, 3, "Bus"),
            (18.90, 2, "Lunch"), (64.20, 5, "Quincaillerie"), (41.30, 1, "Marché"), (27.00, 2, "Pizza"), (90.00, 3, "Passe mensuelle"),
            (15.00, 4, "Musée"), (58.60, 1, "Épicerie"), (22.40, 2, "Resto"), (35.00, 6, "Cadeau"), (9.99, 6, "App"),
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
        state.quickExpenses = [
            QuickExpense(name: "Café", amount: 4.5, categoryID: cat(2), symbol: "cup.and.saucer.fill"),
            QuickExpense(name: "Bus", amount: 3.75, categoryID: cat(3), symbol: "bus.fill"),
            QuickExpense(name: "Lunch", amount: 15, categoryID: cat(2), symbol: "takeoutbag.and.cup.and.straw.fill"),
        ]
        state.bills = [
            Bill(name: "Loyer", amount: 1_250, anchorDate: day(3, 0, from: now), symbol: "house.fill"),
            Bill(name: "Hydro", amount: 86, anchorDate: day(9, 0, from: now), symbol: "bolt.fill"),
            Bill(name: "Internet", amount: 70, anchorDate: day(12, 0, from: now), symbol: "wifi"),
            Bill(name: "Netflix", amount: 16.99, anchorDate: day(5, 0, from: now), isSubscription: true, symbol: "play.tv.fill"),
            Bill(name: "Spotify", amount: 11.99, anchorDate: day(15, 0, from: now), isSubscription: true, symbol: "music.note"),
            Bill(name: "iCloud+", amount: 3.99, anchorDate: day(1, 0, from: now), isSubscription: true, symbol: "icloud.fill"),
            Bill(name: "Salle de sport", amount: 39.99, anchorDate: day(20, 0, from: now), isSubscription: true, symbol: "dumbbell.fill"),
        ]
        state.goals = [
            SavingsGoal(name: "Voyage au Japon", target: 5_000, saved: 2_150, deadline: day(240, 0, from: now)),
            SavingsGoal(name: "Fonds d'urgence", target: 10_000, saved: 6_400, deadline: nil),
        ]
        state.accounts = [
            Account(name: "Compte chèque", balance: 2_350),
            Account(name: "Épargne", balance: 6_400),
            Account(name: "CELI", balance: 12_500),
            Account(name: "Carte de crédit", balance: 850, isLiability: true),
            Account(name: "Prêt auto", balance: 9_800, isLiability: true),
        ]
        let worth = BudgetMath.netWorth(state)
        state.netWorthHistory = (0..<30).map { offset in
            ValuePoint(date: day(offset - 29, 0, from: now), value: worth - Double(29 - offset) * 38 + sin(Double(offset) / 3) * 120)
        }
        return state
    }

    static func business(now: Date) -> BusinessState {
        var state = BusinessState()
        state.name = "Atelier Nova"
        state.monthlyGoal = 12_000
        for offset in 0..<62 {
            let date = day(-offset, 8, from: now)
            let wave = sin(Double(offset) / 4) * 120
            let amount = 420 + wave + Double((offset * 37) % 150) - Double(offset) * 2
            let orders = 4 + (offset * 7) % 5
            state.sales.append(SalesEntry(date: date, amount: max(90, amount), orders: orders, newCustomers: 1 + offset % 3, visitors: 160 + (offset * 13) % 90))
        }
        state.expenses = [
            BusinessExpense(date: day(-2, from: now), amount: 900, label: "Publicité"),
            BusinessExpense(date: day(-6, from: now), amount: 620, label: "Matériel"),
            BusinessExpense(date: day(-9, from: now), amount: 49, label: "Hébergement"),
            BusinessExpense(date: day(-12, from: now), amount: 310, label: "Frais de paiement"),
            BusinessExpense(date: day(-15, from: now), amount: 1_450, label: "Sous-traitance"),
        ]
        let mrr: [Double] = [2_100, 2_380, 2_620, 2_890, 3_150, 3_420]
        state.subscriptions = mrr.enumerated().map { pair in
            SubscriptionSnapshot(month: DateMath.calendar.date(byAdding: .month, value: pair.offset - 5, to: now) ?? now, mrr: pair.element, subscribers: 70 + pair.offset * 8)
        }
        return state
    }

    static func portfolio(now: Date) -> PortfolioState {
        var state = PortfolioState()
        state.holdings = [
            Holding(kind: .etf, name: "iShares Core Equity", symbol: "XEQT", quantity: 120, costBasis: 3_300, manualPrice: 32.4),
            Holding(kind: .stock, name: "Exemple Inc.", symbol: "EXMP", quantity: 15, costBasis: 2_450, manualPrice: 186.4),
            Holding(kind: .crypto, name: "Bitcoin", symbol: "bitcoin", quantity: 0.08, costBasis: 4_200),
            Holding(kind: .crypto, name: "Ethereum", symbol: "ethereum", quantity: 1.2, costBasis: 3_000),
            Holding(kind: .cash, name: "Liquidités", symbol: "CAD", quantity: 1_500, costBasis: 1_500),
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
        let math = Course(name: "Mathématiques", colorHex: "3366FF", teacher: "Mme Tremblay", credits: 3)
        let bio = Course(name: "Biologie", colorHex: "D6409F", teacher: "M. Gagnon", credits: 3)
        let history = Course(name: "Histoire", colorHex: "F2A33A", teacher: "Mme Roy", credits: 2)
        let english = Course(name: "Anglais", colorHex: "1E9E75", teacher: "M. Smith", credits: 2)
        state.courses = [math, bio, history, english]
        var slots: [ClassSlot] = []
        for weekday in 1...5 {
            slots.append(ClassSlot(courseID: [math, bio, history, english, math][weekday - 1].id, weekday: weekday, startMinute: 8 * 60 + 30, endMinute: 10 * 60 + 20, room: ["B-204", "Labo 3", "A-110", "C-015", "B-204"][weekday - 1]))
            slots.append(ClassSlot(courseID: [bio, english, math, history, bio][weekday - 1].id, weekday: weekday, startMinute: 13 * 60, endMinute: 14 * 60 + 50, room: ["Labo 3", "C-015", "B-204", "A-110", "Labo 1"][weekday - 1]))
            slots.append(ClassSlot(courseID: [history, math, english, bio, english][weekday - 1].id, weekday: weekday, startMinute: 15 * 60, endMinute: 16 * 60 + 20, room: ["A-110", "B-204", "C-015", "Labo 3", "C-015"][weekday - 1]))
        }
        state.slots = slots
        state.exams = [
            Exam(courseID: bio.id, title: "Intra de biologie", date: day(6, 9, from: now), room: "Gymnase"),
            Exam(courseID: math.id, title: "Examen final de maths", date: day(21, 13, 30, from: now), room: "B-204"),
        ]
        state.assignments = [
            Assignment(courseID: bio.id, title: "Rapport de labo", due: day(2, 23, 59, from: now)),
            Assignment(courseID: history.id, title: "Dissertation", due: day(5, 17, from: now)),
            Assignment(courseID: math.id, title: "Exercices ch. 4", due: day(1, 9, from: now), isDone: true),
            Assignment(courseID: english.id, title: "Oral en équipe", due: day(9, 10, from: now)),
        ]
        state.grades = [
            Grade(courseID: math.id, title: "Quiz 1", score: 17, maxScore: 20, weight: 10),
            Grade(courseID: math.id, title: "Devoir 1", score: 82, maxScore: 100, weight: 15),
            Grade(courseID: bio.id, title: "Labo 1", score: 88, maxScore: 100, weight: 15),
            Grade(courseID: bio.id, title: "Quiz", score: 7, maxScore: 10, weight: 10),
            Grade(courseID: history.id, title: "Exposé", score: 91, maxScore: 100, weight: 20),
            Grade(courseID: english.id, title: "Rédaction", score: 76, maxScore: 100, weight: 20),
        ]
        state.cards = [
            Flashcard(deck: "Biologie", front: "Mitochondrie", back: "Organite qui produit l'énergie de la cellule (ATP).", box: 2, due: now.addingTimeInterval(-600)),
            Flashcard(deck: "Biologie", front: "Photosynthèse", back: "Production de glucose à partir de CO₂, d'eau et de lumière.", box: 1, due: now.addingTimeInterval(-300)),
            Flashcard(deck: "Histoire", front: "1867", back: "Confédération canadienne.", box: 3, due: day(2, 0, from: now)),
            Flashcard(deck: "Anglais", front: "To overcome", back: "Surmonter", box: 1, due: now.addingTimeInterval(-60)),
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
        state.trips = [Trip(destination: "Lisbonne", start: start, end: end, timeZoneID: "Europe/Lisbon", currencyCode: "EUR", latitude: 38.72, longitude: -9.14)]
        state.flights = [Flight(number: "TP 258", from: "YUL", to: "LIS", departure: start, arrival: start.addingTimeInterval(6.5 * 3600), terminal: "A", gate: "52", seat: "23C")]
        state.stays = [Stay(name: "Hôtel Alfama", address: "Rua de São Miguel 12, Lisbonne", checkIn: day(startOffset + 1, 15, from: now), checkOut: day(startOffset + 9, 11, from: now), confirmation: "HX4821")]
        let base = ongoing ? 0 : startOffset + 1
        state.activities = [
            TripActivity(title: "Château Saint-Georges", date: day(base, ongoing ? 15 : 10, from: now), place: "Alfama"),
            TripActivity(title: "Tram 28", date: day(base + 1, 11, from: now), place: "Martim Moniz"),
            TripActivity(title: "Pastéis de Belém", date: day(base + 2, 15, from: now), place: "Belém"),
        ]
        state.sampleAmount = 100
        return state
    }

    static func car(now: Date) -> CarState {
        var state = CarState()
        state.name = "Civic 2019"
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
            ServiceItem(name: "Vidange d'huile", intervalKm: 8_000, intervalMonths: 6, lastKm: current - 6_400, lastDate: DateMath.calendar.date(byAdding: .month, value: -4, to: now), cost: 90),
            ServiceItem(name: "Rotation des pneus", intervalKm: 10_000, intervalMonths: nil, lastKm: current - 3_100, lastDate: nil, cost: 40),
            ServiceItem(name: "Plaquettes de frein", intervalKm: 40_000, intervalMonths: nil, lastKm: current - 21_000, lastDate: nil, cost: 320),
        ]
        let year = DateMath.calendar.component(.year, from: now)
        let winter = Holidays.make(year, 12, 1)
        state.deadlines = [
            CarDeadline(title: "Pneus d'hiver", date: winter < now ? Holidays.make(year + 1, 12, 1) : winter, symbol: "snowflake"),
            CarDeadline(title: "Immatriculation", date: day(64, 0, from: now), symbol: "doc.text.fill"),
            CarDeadline(title: "Renouvellement assurance", date: day(142, 0, from: now), symbol: "shield.fill"),
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
            PriorityItem(title: "Finir la présentation", doneDayKey: today),
            PriorityItem(title: "Appeler le comptable"),
            PriorityItem(title: "30 minutes de sport"),
        ]
        let tasks = ["Maquettes", "Textes", "Photos", "Paiement en ligne", "Tests", "Nom de domaine", "Annonce", "Mise en ligne"]
        state.projects = [Project(name: "Lancement du site", colorHex: "3366FF", deadline: day(12, 17, from: now), tasks: tasks.enumerated().map { pair in
            ProjectTask(title: pair.element, isDone: pair.offset < 5, completedAt: pair.offset < 5 ? day(-pair.offset, from: now) : nil)
        })]
        state.deadlines = [Deadline(title: "Rendu du rapport", date: day(2, 17, from: now))]
        state.counters = [
            CounterItem(name: "Cafés", symbol: "cup.and.saucer.fill", colorHex: "B7791F", step: 1, goal: 3, resetsDaily: true, total: 2, dayKey: today),
            CounterItem(name: "Pompes", symbol: "figure.strengthtraining.functional", colorHex: "E5484D", step: 10, goal: 100, resetsDaily: true, total: 40, dayKey: today),
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
