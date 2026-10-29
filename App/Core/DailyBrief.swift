import Foundation

/// « Mon Quotidien »: what matters today, built only from what the person entered. Nothing is
/// shown for a part of their life they haven't told Ardane about, and never a made-up number:
/// at most a discreet invitation for one of their interests. The order follows the moment of the
/// day: the first class in the morning, tasks and the workout during the day,
/// what's left to eat and the habits in the evening.
enum DailyBrief {
    enum Moment: Equatable {
        case morning, day, evening

        init(_ date: Date) {
            switch DateMath.calendar.component(.hour, from: date) {
            case 5..<11: self = .morning
            case 11..<18: self = .day
            default: self = .evening
            }
        }

        var title: String {
            switch self {
            case .morning: tr("Ta matinée")
            case .day: tr("Ta journée")
            case .evening: tr("Ta soirée")
            }
        }
    }

    /// Everything the brief reads, gathered once (the app passes its data, tests pass their own).
    struct Input {
        var now: Date
        var profile = UserProfile()
        var content = ContentState()
        var nutrition = NutritionState()
        var fitness = FitnessState()
        var budget = BudgetState()
        var student = StudentState()
        var productivity = ProductivityState()
        var travel = TravelState()
        var car = CarState()
        var events: [EventSnapshot] = []
        var steps: Int?
        /// The spaces of the person's interests, for the invitations and the empty cards.
        var interests: [Space] = []
        var currency = "CAD"
    }

    // MARK: Tiles

    struct Nutrition: Equatable {
        var eaten: NutritionTotals
        var goals: NutritionGoals
        var knowsKcal: Bool
        var knowsProtein: Bool
        var knowsCarbs: Bool
        var knowsFat: Bool
        var foods: Int
        var meals: Int
        /// The next main meal not logged yet, and what it could hold (only with a calorie target).
        var nextMeal: String?
        var nextMealKcal: Double?

        var kcalLeft: Double? { knowsKcal ? goals.kcal - eaten.kcal : nil }
    }

    struct Workout: Equatable {
        enum Stage: Equatable {
            case planned
            case inProgress(exercise: String, set: Int, sets: Int, reps: Int, weight: Double, restEndsAt: Date?)
            case done(sets: Int, volume: Double)
            case rest(nextName: String?, nextDay: String?)
        }

        var name: String
        var exercises: [String]
        var totalSets: Int
        var stage: Stage
    }

    struct TimedItem: Equatable, Identifiable {
        var id: String
        var date: Date
        var time: String
        var title: String
        var detail: String
        var isHighlighted = false
        /// The colour of its kind (a class, work, an appointment, a calendar).
        var colorHex: String?
    }

    struct Reminder: Equatable, Identifiable {
        var id: String
        var title: String
        var when: String
        var symbol: String
        var colorHex: String
        var date: Date
        /// Where a tap leads: the mini-app (or its page) holding it.
        var route: HomeRoute? = nil
    }

    struct Check: Equatable, Identifiable {
        var id: String
        var title: String
        var isDone: Bool
        /// A habit's own color, and its days in a row (priorities have neither).
        var colorHex: String? = nil
        var streak = 0
    }

    /// The sections Mon Quotidien always offers. Each one's id is the id of its card with data, so a
    /// category keeps its place, its size and its hidden state when it goes from empty to filled.
    enum Category: String, CaseIterable, Identifiable, Hashable {
        case nutrition, workout, planning, habits, budget, priorities, reminders, steps, business, travel, car

        /// The order of the empty cards (after the cards with data).
        static let defaultOrder: [Category] = allCases

        var tileID: String {
            switch self {
            case .business: "app-business"
            case .travel: "app-travel"
            case .car: "app-car"
            default: rawValue
            }
        }

        var id: String { tileID }

        /// The category whose card has this id (`tileID`), nil for any other.
        init?(tileID: String) {
            guard let found = Category.allCases.first(where: { $0.tileID == tileID }) else { return nil }
            self = found
        }

        /// The category an interest of the first form leads to (the same link the invitations used), nil
        /// for the spaces without a card (investments, markets, « Ma vie »).
        init?(space: Space) {
            switch space {
            case .nutrition: self = .nutrition
            case .fitness: self = .workout
            case .student: self = .planning
            case .budget: self = .budget
            case .habits: self = .habits
            case .productivity: self = .priorities
            case .business: self = .business
            case .travel: self = .travel
            case .car: self = .car
            case .investing, .markets, .life: return nil
            }
        }

        /// The category a mini-app added by hand (an old `dailyAdded` entry) stands for, nil without one.
        init?(app: MiniApp) {
            switch app {
            case .nutrition: self = .nutrition
            case .fitness: self = .workout
            case .planning: self = .planning
            case .finances: self = .budget
            case .business: self = .business
            case .travel: self = .travel
            case .car: self = .car
            case .photos: return nil
            }
        }

        /// The part of « Mes informations » that holds its data, where there is one.
        var area: InfoArea? {
            switch self {
            case .nutrition: .nutrition
            case .workout: .fitness
            case .planning: .student
            case .habits: .habits
            case .budget: .budget
            case .priorities: .productivity
            default: nil
            }
        }

        /// The mini-app a category without its own card shows through (a card with one figure).
        var app: MiniApp? {
            switch self {
            case .business: .business
            case .travel: .travel
            case .car: .car
            default: nil
            }
        }

        var title: String {
            if let area { return area.title }
            switch self {
            case .reminders: return tr("À ne pas oublier")
            case .steps: return tr("Pas")
            default: return app?.title ?? rawValue
            }
        }

        var symbol: String {
            if let area { return area.symbol }
            switch self {
            case .reminders: return "bell.fill"
            case .steps: return "figure.walk"
            default: return app?.symbol ?? "square"
            }
        }

        var colorHex: String {
            if let area { return area.colorHex }
            switch self {
            case .reminders: return "4B5563"
            case .steps: return "12A4B5"
            default: return app?.colorHex ?? "8E8E93"
            }
        }

        /// What the empty card says: what to give, and what will appear here once it is given.
        var invitation: String {
            switch self {
            case .nutrition: tr("Donne ton objectif calorique ou scanne un repas : tes calories du jour apparaîtront ici.")
            case .workout: tr("Crée ton programme : ta séance du jour apparaîtra ici.")
            case .planning: tr("Ajoute tes cours : ton horaire du jour apparaîtra ici.")
            case .budget: tr("Donne ton budget du mois pour voir ce qu'il te reste chaque jour.")
            case .habits: tr("Ajoute une habitude à suivre chaque jour.")
            case .priorities: tr("Ajoute tes tâches ou ton top 3 du jour.")
            case .reminders: tr("Examens, devoirs, factures, échéances : ce qui approche apparaîtra ici.")
            case .steps: tr("Autorise le compteur de pas : tes pas du jour apparaîtront ici.")
            case .business: tr("Note tes ventes : ton chiffre d'affaires du mois apparaîtra ici.")
            case .travel: tr("Ajoute un voyage : son compte à rebours apparaîtra ici.")
            case .car: tr("Note un plein ou le kilométrage : ta voiture apparaîtra ici.")
            }
        }

        /// Where a tap on the empty card leads: always the mini-app, which shows what is left to fill in.
        var route: HomeRoute {
            if let area { return area.homeRoute }
            switch self {
            case .reminders: return .app(.planning)
            case .steps: return .page(.fitnessActivity)
            case .business: return .app(.business)
            case .travel: return .app(.travel)
            default: return .app(.car)
            }
        }
    }

    enum Tile: Equatable, Identifiable {
        case nutrition(Nutrition)
        case workout(Workout)
        /// What comes next in the schedule and the Apple calendar, over the coming week.
        case planning(items: [TimedItem])
        case habits(done: Int, items: [Check])
        case steps(steps: Int, goal: Int?)
        case budget(spentToday: Double, perDayLeft: Double?)
        case reminders([Reminder])
        case priorities([Check])
        case invite(InfoArea)
        /// A category with nothing entered yet: a dotted card inviting to fill it, never a made-up figure.
        /// Same id as the card with data, so hiding it keeps it hidden when data comes.
        case empty(Category)
        /// A mini-app added to Mon Quotidien by the person: its name and one figure from its data (nil: nothing yet).
        case miniApp(String, caption: String?)

        var id: String {
            switch self {
            case .nutrition: "nutrition"
            case .workout: "workout"
            case .planning: "planning"
            case .habits: "habits"
            case .steps: "steps"
            case .budget: "budget"
            case .reminders: "reminders"
            case .priorities: "priorities"
            case let .invite(area): "invite-\(area.rawValue)"
            case let .empty(category): category.tileID
            case let .miniApp(app, _): "app-\(app)"
            }
        }

        /// The category this card stands for (every card of Mon Quotidien has one, except an old invitation).
        var category: Category? { Category(tileID: id) }

        /// Across the dashboard, or half of it.
        var isWide: Bool {
            switch self {
            // Planning: the week as a table, readable across the dashboard (half of it on demand).
            case .nutrition, .reminders, .invite, .empty, .planning: true
            default: false
            }
        }
    }

    // MARK: Building

    static func tiles(_ input: Input) -> [Tile] {
        let now = input.now
        let moment = Moment(now)
        var scored: [(tile: Tile, score: Int)] = []
        func add(_ tile: Tile?, _ score: Int) {
            if let tile { scored.append((tile, score)) }
        }

        // By default, what was entered for meals comes first, then today's session; a session in
        // progress, an exam or a reminder due today go before them.
        let nutrition = nutritionTile(input)
        add(nutrition.map(Tile.nutrition), 99)

        if let workout = workoutTile(input) {
            let score: Int
            switch workout.stage {
            case .inProgress: score = 110
            // From the afternoon on, a session still to do goes before the meals: it is the moment for it.
            case .planned: score = moment == .morning ? 95 : 100
            case .done: score = moment == .evening ? 78 : 60
            case .rest: score = 30
            }
            add(.workout(workout), score)
        }

        if let planning = planningTile(input) {
            // Something within two hours, or an exam today, goes first.
            let soon = planning.contains { $0.date < now.addingTimeInterval(2 * 3_600) || ($0.isHighlighted && DateMath.isSameDay($0.date, now)) }
            add(.planning(items: planning), planning.isEmpty ? 40 : (soon ? 102 : (moment == .morning ? 90 : (moment == .day ? 86 : 70))))
        }

        let reminders = remindersTile(input)
        if !reminders.isEmpty {
            let urgent = reminders.contains { DateMath.isSameDay($0.date, now) && $0.date >= now }
            add(.reminders(reminders), urgent ? 102 : (moment == .evening ? 72 : 84))
        }

        let priorities = priorityChecks(input.productivity, now: now)
        if !priorities.isEmpty {
            add(.priorities(priorities), moment == .evening ? 45 : 83)
        }

        let habits = input.content.habits.map { Check(id: $0.id.uuidString, title: $0.name, isDone: $0.isDone(on: now), colorHex: $0.colorHex, streak: $0.streak(asOf: now)) }
        if !habits.isEmpty {
            add(.habits(done: habits.filter(\.isDone).count, items: habits), moment == .evening ? 92 : 50)
        }

        if let steps = input.steps {
            add(.steps(steps: steps, goal: input.profile.stepGoal), moment == .evening ? 84 : 52)
        }

        let knowsBudget = input.profile.knows(.monthlyBudget)
        let spent = BudgetMath.spentToday(input.budget, at: now)
        if knowsBudget || spent > 0 {
            add(.budget(spentToday: spent, perDayLeft: knowsBudget ? BudgetMath.perDayLeft(input.budget, at: now) : nil), moment == .evening ? 62 : 56)
        }


        var tiles = scored.enumerated()
            .sorted { lhs, rhs in lhs.element.score == rhs.element.score ? lhs.offset < rhs.offset : lhs.element.score > rhs.element.score }
            .map(\.element.tile)

        // A discreet invitation for interests with nothing entered yet: two on an empty Home, one
        // next to a few real cards, none once Home is full of the person's own figures.
        let room = tiles.count >= 4 ? 0 : (tiles.count >= 2 ? 1 : 2)
        tiles += invitations(input, shown: tiles).prefix(room).map(Tile.invite)
        return tiles
    }

    /// What Mon Quotidien holds: the cards with data (`tiles`), then the figure of the
    /// mini-apps without their own card when there is something to show, then an empty dotted card for
    /// each category of `empty` still without data, in the default order. `empty` is what the person
    /// chose (their interests and the categories they added); by default every category. Legacy
    /// invitations are dropped: the empty cards replace them. Never a made-up figure.
    static func completing(_ tiles: [Tile], appCaptions: [Category: String] = [:],
                           empty: [Category] = Category.defaultOrder) -> [Tile] {
        var result = tiles.filter { if case .invite = $0 { false } else { true } }
        var ids = Set(result.map(\.id))
        func append(_ tile: Tile) {
            guard ids.insert(tile.id).inserted else { return }
            result.append(tile)
        }
        for category in Category.defaultOrder {
            if let app = category.app, let caption = appCaptions[category] { append(.miniApp(app.rawValue, caption: caption)) }
        }
        for category in Category.defaultOrder where empty.contains(category) { append(.empty(category)) }
        return result
    }

    /// The active Top 3 as checks (empty without any task; a validated task is no longer here).
    static func priorityChecks(_ state: ProductivityState, now: Date) -> [Check] {
        state.activePriorities.prefix(ProductivityState.maxPriorities).map { Check(id: $0.id.uuidString, title: $0.title, isDone: $0.isDone(on: now)) }
    }

    /// The cards as the person arranged them: hidden ones left out, the chosen order first (the
    /// others after, in the automatic order), invitations last.
    static func arranged(_ tiles: [Tile], order: [String], hidden: [String]) -> [Tile] {
        let invites = tiles.filter { if case .invite = $0 { true } else { false } }
        let cards = tiles.filter { tile in !invites.contains(tile) && !hidden.contains(tile.id) }
        guard !order.isEmpty else { return cards + invites }
        let sorted = cards.enumerated().sorted { lhs, rhs in
            let l = order.firstIndex(of: lhs.element.id) ?? order.count + lhs.offset
            let r = order.firstIndex(of: rhs.element.id) ?? order.count + rhs.offset
            return l < r
        }
        return sorted.map(\.element) + invites
    }

    /// Rows of the dashboard: wide tiles alone, the others two by two, in order. `wide` is the
    /// size the person chose for a card (full width or half), over the card's own size.
    static func rows(_ tiles: [Tile], wide: [String: Bool] = [:]) -> [[Tile]] {
        var rows: [[Tile]] = []
        var waiting: Tile?
        for tile in tiles {
            if wide[tile.id] ?? tile.isWide {
                rows.append([tile])
            } else if let first = waiting {
                rows.append([first, tile])
                waiting = nil
            } else {
                waiting = tile
            }
        }
        if let waiting { rows.append([waiting]) }
        return rows
    }

    // MARK: Nutrition

    static func nutritionTile(_ input: Input) -> Nutrition? {
        let state = input.nutrition
        let profile = input.profile
        let today = NutritionMath.entries(state, on: input.now)
        let knowsKcal = profile.knows(.kcalTarget)
        let knowsAny = knowsKcal || profile.knows(.proteinTarget) || profile.knows(.carbsTarget) || profile.knows(.fatTarget)
        // Nothing to show until the person gave a target or logged a food today.
        guard knowsAny || !today.isEmpty else { return nil }
        let next = knowsKcal ? NutritionMath.nextMealBudget(state, at: input.now) : nil
        return Nutrition(
            eaten: NutritionMath.totals(state, on: input.now),
            goals: state.goals,
            knowsKcal: knowsKcal,
            knowsProtein: profile.knows(.proteinTarget),
            knowsCarbs: profile.knows(.carbsTarget),
            knowsFat: profile.knows(.fatTarget),
            foods: today.count,
            meals: Set(today.map(\.meal)).count,
            nextMeal: next?.meal.title,
            nextMealKcal: next?.kcal
        )
    }

    // MARK: Workout

    static func workoutTile(_ input: Input) -> Workout? {
        let state = input.fitness
        let now = input.now
        guard !state.routines.isEmpty else { return nil }
        if let active = state.active, !active.isFinished, DateMath.isSameDay(active.start, now), let exercise = active.currentExercise {
            return Workout(
                name: active.routineName,
                exercises: active.exercises.map(\.name),
                totalSets: active.totalSets,
                stage: .inProgress(exercise: exercise.name, set: active.setIndex + 1, sets: exercise.sets, reps: exercise.reps, weight: exercise.weight, restEndsAt: active.restEndsAt)
            )
        }
        if let done = FitnessMath.sessions(state).last(where: { DateMath.isSameDay($0.start, now) && $0.isFinished }) {
            return Workout(name: done.routineName, exercises: done.exercises.map(\.name), totalSets: done.totalSets, stage: .done(sets: done.sets.count, volume: done.volume))
        }
        if state.isScheduled(now), let routine = state.routine(for: now) {
            return Workout(name: routine.name, exercises: routine.exercises.map(\.name), totalSets: routine.exercises.reduce(0) { $0 + $1.sets }, stage: .planned)
        }
        // A rest day: when the next planned session is, if any is planned.
        for offset in 1...7 {
            guard let day = DateMath.calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = FitnessMath.isoWeekday(day)
            if let routine = state.routines.first(where: { $0.weekdays.contains(weekday) }) {
                let when = offset == 1 ? tr("Demain") : Fmt.weekday(day)
                return Workout(name: tr("Repos"), exercises: [], totalSets: 0, stage: .rest(nextName: routine.name, nextDay: when))
            }
        }
        return nil
    }

    // MARK: Planning

    /// The next entries of the week: classes, work, appointments and other events of the schedule,
    /// exams, and the events of the Apple calendar, the nearest first. Nil without any of them.
    static func planningTile(_ input: Input) -> [TimedItem]? {
        let state = input.student
        let now = input.now
        guard !state.slots.isEmpty || !state.exams.isEmpty || !input.events.isEmpty else { return nil }
        let today = DateMath.startOfDay(now)
        let horizon = today.addingTimeInterval(7 * 86_400)
        func when(_ date: Date, allDay: Bool = false) -> String {
            let days = DateMath.daysBetween(today, date)
            let time = allDay ? tr("Journée") : Fmt.time(date, uses24Hour: true)
            switch days {
            case ...0: return time
            case 1: return tr("Demain \(time)")
            default: return "\(Fmt.weekday(date).capitalizedFirst) \(time)"
            }
        }
        var items: [TimedItem] = []
        for offset in 0..<7 {
            guard let day = DateMath.calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            for occurrence in StudentMath.occurrences(state, on: day) where occurrence.end > now {
                items.append(TimedItem(id: occurrence.slot.id.uuidString + DateMath.dayKey(day), date: occurrence.start, time: when(occurrence.start),
                                       title: state.title(of: occurrence.slot), detail: occurrence.slot.room, colorHex: state.colorHex(of: occurrence.slot)))
            }
        }
        for exam in state.exams where exam.date > now.addingTimeInterval(-2 * 3_600) && exam.date < horizon {
            items.append(TimedItem(id: exam.id.uuidString, date: exam.date, time: when(exam.date), title: tr("Examen : \(exam.title)"), detail: exam.room,
                                   isHighlighted: true, colorHex: ScheduleKind.course.colorHex))
        }
        for event in input.events where (event.isAllDay ? event.end > today : event.end > now) && event.start < horizon {
            items.append(TimedItem(id: event.id, date: max(event.start, today), time: when(max(event.start, today), allDay: event.isAllDay),
                                   title: event.title, detail: event.location ?? "", colorHex: event.colorHex))
        }
        return Array(items.sorted { $0.date < $1.date }.prefix(5))
    }

    // MARK: Reminders

    /// Dates not to miss soon: exams, homework, deadlines, bills, the car, a departure, the tasks left.
    static func remindersTile(_ input: Input) -> [Reminder] {
        let now = input.now
        let calendar = DateMath.calendar
        let todayStart = DateMath.startOfDay(now)
        func when(_ date: Date, withTime: Bool) -> String {
            let days = calendar.dateComponents([.day], from: todayStart, to: DateMath.startOfDay(date)).day ?? 0
            let time = withTime ? " \(Fmt.time(date, uses24Hour: true))" : ""
            switch days {
            case ..<0: return tr("En retard")
            case 0: return tr("Aujourd'hui\(time)")
            case 1: return tr("Demain\(time)")
            default: return Fmt.weekday(date)
            }
        }
        func within(_ date: Date, days: Int) -> Bool {
            date >= todayStart && date < todayStart.addingTimeInterval(TimeInterval(days + 1) * 86_400)
        }
        var reminders: [Reminder] = []
        for exam in input.student.exams where within(exam.date, days: 1) && exam.date > now {
            reminders.append(Reminder(id: exam.id.uuidString, title: tr("Examen : \(exam.title)"), when: when(exam.date, withTime: true), symbol: "pencil.and.list.clipboard", colorHex: "D6409F", date: exam.date, route: .page(.studiesExams)))
        }
        for work in input.student.assignments where !work.isDone && work.due < todayStart.addingTimeInterval(3 * 86_400) {
            reminders.append(Reminder(id: work.id.uuidString, title: work.title, when: when(work.due, withTime: false), symbol: "doc.text", colorHex: "D6409F", date: work.due, route: .page(.studiesAssignments)))
        }
        for deadline in input.productivity.deadlines where within(deadline.date, days: 2) && deadline.date > now {
            reminders.append(Reminder(id: deadline.id.uuidString, title: deadline.title, when: when(deadline.date, withTime: true), symbol: "flag.fill", colorHex: "6B7280", date: deadline.date, route: .app(.planning)))
        }
        for upcoming in BudgetMath.upcomingBills(input.budget, at: now, within: 3) {
            reminders.append(Reminder(id: upcoming.bill.id.uuidString, title: upcoming.bill.name, when: "\(when(upcoming.due, withTime: false)) · \(TF.money(upcoming.bill.amount, input.currency))", symbol: "doc.text.fill", colorHex: "2F8F7A", date: upcoming.due, route: .page(.financesBills)))
        }
        for deadline in input.car.deadlines where within(deadline.date, days: 7) {
            reminders.append(Reminder(id: deadline.id.uuidString, title: deadline.title, when: when(deadline.date, withTime: false), symbol: "car.fill", colorHex: "4B5563", date: deadline.date, route: .page(.carDeadlines)))
        }
        for trip in input.travel.trips where within(trip.start, days: 3) {
            reminders.append(Reminder(id: trip.id.uuidString, title: tr("Départ pour \(trip.destination)"), when: when(trip.start, withTime: false), symbol: "airplane", colorHex: "12A4B5", date: trip.start, route: .app(.travel)))
        }
        var result = Array(reminders.sorted { $0.date < $1.date }.prefix(4))
        let open = input.content.tasks.filter { !$0.isDone }
        if !open.isEmpty && result.count < 4 {
            let names = open.prefix(2).map(\.title).joined(separator: ", ")
            result.append(Reminder(id: "tasks", title: Fmt.plural(open.count, tr("tâche à faire"), tr("tâches à faire")), when: names, symbol: "checklist", colorHex: "6B7280", date: .distantFuture, route: .page(.planningTasks)))
        }
        return result
    }

    // MARK: Invitations

    static func invitations(_ input: Input, shown: [Tile]) -> [InfoArea] {
        let ids = Set(shown.map(\.id))
        var seen = Set<InfoArea>()
        return input.interests.compactMap { space -> InfoArea? in
            switch space {
            case .nutrition where !ids.contains("nutrition"): .nutrition
            case .fitness where !ids.contains("workout"): .fitness
            case .student where !ids.contains("planning") && input.student.courses.isEmpty && input.student.slots.isEmpty: .student
            case .budget where !ids.contains("budget"): .budget
            case .habits where !ids.contains("habits"): .habits
            case .productivity where !ids.contains("priorities") && !ids.contains("reminders"): .productivity
            default: nil
            }
        }
        .filter { seen.insert($0).inserted }
    }
}

extension DailyBrief.Input {
    @MainActor
    init(model: AppModel, now: Date = Date(), steps: Int?) {
        self.init(now: now)
        profile = model.profile
        content = model.content
        nutrition = model.nutrition
        fitness = model.fitness
        budget = model.budget
        student = model.student
        productivity = model.productivity
        travel = model.travel
        car = model.car
        if case let .ready(list) = model.events { events = list }
        self.steps = steps
        interests = model.profile.preferredSpaces
        currency = model.settings.currencyCode
    }
}
