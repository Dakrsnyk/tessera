import Foundation

/// « Mon Quotidien »: what matters today, built only from what the person entered. Nothing is
/// shown for a part of their life they haven't told Tessera about, and never a made-up number:
/// at most a discreet invitation for one of their interests. The order follows the moment of the
/// day: the weather and the first class in the morning, tasks and the workout during the day,
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
        var weather: WeatherSnapshot?
        var events: [EventSnapshot] = []
        var steps: Int?
        /// The spaces of the person's interests, for the invitations.
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
    }

    enum Tile: Equatable, Identifiable {
        case nutrition(Nutrition)
        case workout(Workout)
        case classes(title: String, items: [TimedItem])
        case agenda(title: String, items: [TimedItem])
        case habits(done: Int, items: [Check])
        case water(glasses: Int, goal: Int?)
        case steps(steps: Int, goal: Int?)
        case budget(spentToday: Double, perDayLeft: Double?)
        case weather(WeatherSnapshot)
        case reminders([Reminder])
        case priorities([Check])
        case invite(InfoArea)
        /// A mini-app added to Mon Quotidien by the person: its name and one figure from its data (nil: nothing yet).
        case miniApp(String, caption: String?)

        var id: String {
            switch self {
            case .nutrition: "nutrition"
            case .workout: "workout"
            case .classes: "classes"
            case .agenda: "agenda"
            case .habits: "habits"
            case .water: "water"
            case .steps: "steps"
            case .budget: "budget"
            case .weather: "weather"
            case .reminders: "reminders"
            case .priorities: "priorities"
            case let .invite(area): "invite-\(area.rawValue)"
            case let .miniApp(app, _): "app-\(app)"
            }
        }

        /// Across the dashboard, or half of it.
        var isWide: Bool {
            switch self {
            case .nutrition, .reminders, .invite: true
            case let .agenda(_, items), let .classes(_, items): items.count > 3
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
            case .planned: score = 95
            case .done: score = moment == .evening ? 78 : 60
            case .rest: score = 30
            }
            add(.workout(workout), score)
        }

        if let classes = classesTile(input) {
            let score = classes.items.contains(where: \.isHighlighted) ? 100 : (moment == .morning ? 90 : (moment == .day ? 86 : 50))
            add(.classes(title: classes.title, items: classes.items), score)
        }

        if let agenda = agendaTile(input) {
            add(.agenda(title: agenda.title, items: agenda.items), moment == .evening ? 55 : 88)
        }

        let reminders = remindersTile(input)
        if !reminders.isEmpty {
            let urgent = reminders.contains { DateMath.isSameDay($0.date, now) && $0.date >= now }
            add(.reminders(reminders), urgent ? 100 : (moment == .evening ? 72 : 84))
        }

        let priorities = input.productivity.priorities.prefix(3).map { Check(id: $0.id.uuidString, title: $0.title, isDone: $0.isDone(on: now)) }
        if !priorities.isEmpty {
            add(.priorities(Array(priorities)), moment == .evening ? 45 : 83)
        }

        let habits = input.content.habits.map { Check(id: $0.id.uuidString, title: $0.name, isDone: $0.isDone(on: now)) }
        if !habits.isEmpty {
            add(.habits(done: habits.filter(\.isDone).count, items: habits), moment == .evening ? 92 : 50)
        }

        let glasses = input.content.hydration.glasses(on: now)
        let knowsWater = input.profile.knows(.hydrationGoal)
        if knowsWater || glasses > 0 {
            add(.water(glasses: glasses, goal: knowsWater ? input.content.hydration.goal : nil), moment == .evening ? 80 : 58)
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

    // MARK: Classes and agenda

    static func classesTile(_ input: Input) -> (title: String, items: [TimedItem])? {
        let state = input.student
        let now = input.now
        guard !state.courses.isEmpty || !state.exams.isEmpty else { return nil }
        func items(on day: Date, from start: Date?) -> [TimedItem] {
            let classes = StudentMath.occurrences(state, on: day)
                .filter { start == nil || $0.end > start! }
                .map { occurrence -> TimedItem in
                    let title = state.title(of: occurrence.slot)
                    return TimedItem(
                        id: occurrence.slot.id.uuidString + DateMath.dayKey(day),
                        date: occurrence.start,
                        time: Fmt.time(occurrence.start, uses24Hour: true),
                        title: title,
                        detail: occurrence.slot.room
                    )
                }
            let exams = state.exams
                .filter { DateMath.isSameDay($0.date, day) && (start == nil || $0.date > start!.addingTimeInterval(-2 * 3_600)) }
                .map { exam in
                    TimedItem(id: exam.id.uuidString, date: exam.date, time: Fmt.time(exam.date, uses24Hour: true), title: tr("Examen : \(exam.title)"), detail: exam.room, isHighlighted: true)
                }
            return (classes + exams).sorted { $0.date < $1.date }
        }
        let moment = Moment(now)
        let today = items(on: now, from: now)
        if moment != .evening, !today.isEmpty { return (tr("Cours aujourd'hui"), today) }
        guard let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        if moment == .evening, !today.isEmpty { return (tr("Cours ce soir"), today) }
        let next = items(on: tomorrow, from: nil)
        // Tomorrow's classes only in the evening, to prepare the bag.
        if moment == .evening, !next.isEmpty { return (tr("Cours demain"), next) }
        return nil
    }

    static func agendaTile(_ input: Input) -> (title: String, items: [TimedItem])? {
        let now = input.now
        let today = input.events
            .filter { DateMath.isSameDay($0.start, now) && ($0.isAllDay || $0.end > now) }
            .sorted { $0.start < $1.start }
        guard !today.isEmpty else { return nil }
        let items = today.prefix(4).map { event in
            TimedItem(id: event.id, date: event.start, time: event.isAllDay ? tr("Journée") : Fmt.time(event.start, uses24Hour: true), title: event.title, detail: event.location ?? "")
        }
        return (tr("Agenda"), Array(items))
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
            case .student where !ids.contains("classes") && input.student.courses.isEmpty: .student
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
        if case let .ready(snapshot) = model.weather { weather = snapshot }
        if case let .ready(list) = model.events { events = list }
        self.steps = steps
        interests = model.profile.preferredSpaces
        currency = model.settings.currencyCode
    }
}
