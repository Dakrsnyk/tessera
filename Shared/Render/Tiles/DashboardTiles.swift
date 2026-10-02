import Foundation

/// Widgets that combine several mini-apps, and the analyses written from the user's own data.
enum DashboardTiles {
    static func make(_ context: RenderContext) -> Tile {
        switch context.design.kind {
        case .myDay: return myDay(context)
        case .now: return now(context)
        case .morning: return morning(context)
        case .fitnessDashboard: return fitness(context)
        case .moneyDashboard: return money(context)
        case .studentDashboard: return student(context)
        case .aiSummary, .aiNutrition, .aiFinance, .aiProductivity: return insight(context)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    // MARK: Building blocks

    static func weatherRow(_ context: RenderContext) -> TileRow? {
        guard let weather = TF.weather(context.payload) else { return nil }
        let unit = context.settings.temperatureUnit
        return TileRow(id: "weather", title: "\(Fmt.temperature(weather.temperature, unit: unit)) · \(WeatherCode.description(weather.code))", value: "↑\(Fmt.temperature(weather.high, unit: unit)) ↓\(Fmt.temperature(weather.low, unit: unit))", symbol: WeatherCode.symbol(weather.code, isDay: weather.isDay))
    }

    static func eventRow(_ context: RenderContext) -> TileRow? {
        guard case let .ready(events) = context.payload.events, let next = events.first(where: { $0.end > context.date }) else { return nil }
        let time = next.isAllDay ? tr("Journée") : TF.time(next.start, context)
        return TileRow(id: "event", title: next.title, value: time, symbol: "calendar", colorHex: next.colorHex)
    }

    static func tasksRow(_ context: RenderContext) -> TileRow? {
        let tasks = context.payload.content.tasks
        guard !tasks.isEmpty else { return nil }
        let open = tasks.filter { !$0.isDone }
        return TileRow(id: "tasks", title: open.first?.title ?? tr("Toutes les tâches sont faites"), value: tr("\(open.count) à faire"), symbol: "checklist")
    }

    static func prioritiesRows(_ context: RenderContext) -> [TileRow] {
        let now = context.date
        return context.payload.domains.productivity.priorities.prefix(3).map { item in
            TileRow(id: item.id.uuidString, title: item.title, isDone: item.isDone(on: now), action: .togglePriority(item.id.uuidString))
        }
    }

    static func caloriesRow(_ context: RenderContext) -> TileRow? {
        let nutrition = context.payload.domains.nutrition
        guard !nutrition.entries.isEmpty else { return nil }
        let eaten = NutritionMath.totals(nutrition, on: context.date).kcal
        // Without the person's own target, only what was eaten: never a default goal.
        guard context.payload.domains.knows(.kcalTarget) else {
            return TileRow(id: "kcal", title: tr("Mangé aujourd'hui"), value: tr("\(TF.int(eaten)) kcal"), symbol: "flame")
        }
        let left = nutrition.goals.kcal - eaten
        return TileRow(id: "kcal", title: left >= 0 ? tr("Calories restantes") : tr("Calories en trop"), value: tr("\(TF.int(abs(left))) kcal"), symbol: "flame", progress: eaten / max(1, nutrition.goals.kcal))
    }

    static func waterRow(_ context: RenderContext) -> TileRow {
        let hydration = context.payload.content.hydration
        let glasses = hydration.glasses(on: context.date)
        guard context.payload.domains.knows(.hydrationGoal) else {
            return TileRow(id: "water", title: tr("Eau"), value: glasses > 1 ? tr("\(glasses) verres") : tr("\(glasses) verre"), symbol: "drop.fill")
        }
        return TileRow(id: "water", title: tr("Eau"), value: tr("\(glasses)/\(hydration.goal) verres"), symbol: "drop.fill", progress: Double(glasses) / Double(max(1, hydration.goal)))
    }

    static func habitsRow(_ context: RenderContext) -> TileRow? {
        let habits = context.payload.content.habits
        guard !habits.isEmpty else { return nil }
        let done = habits.filter { $0.isDone(on: context.date) }.count
        return TileRow(id: "habits", title: tr("Habitudes"), value: "\(done)/\(habits.count)", symbol: "repeat", progress: Double(done) / Double(habits.count))
    }

    static func budgetRow(_ context: RenderContext) -> TileRow? {
        let budget = context.payload.domains.budget
        let knowsBudget = context.payload.domains.knows(.monthlyBudget)
        guard !budget.expenses.isEmpty || knowsBudget else { return nil }
        guard knowsBudget else {
            let spent = BudgetMath.spentToday(budget, at: context.date)
            return TileRow(id: "budget", title: tr("Dépensé aujourd'hui"), value: TF.money(spent, context.settings.currencyCode), symbol: "creditcard")
        }
        let perDay = BudgetMath.perDayLeft(budget, at: context.date)
        return TileRow(id: "budget", title: tr("Budget du jour"), value: TF.money(perDay, context.settings.currencyCode), symbol: "creditcard")
    }

    static func workoutRow(_ context: RenderContext) -> TileRow? {
        let fitness = context.payload.domains.fitness
        guard fitness.isScheduled(context.date), let routine = fitness.routine(for: context.date) else { return nil }
        let done = FitnessMath.sessions(fitness).contains { DateMath.isSameDay($0.start, context.date) && $0.isFinished }
        return TileRow(id: "workout", title: routine.name, value: done ? tr("Faite") : tr("Prévue"), symbol: "figure.strengthtraining.traditional", isDone: done)
    }

    // MARK: Dashboards

    static func myDay(_ context: RenderContext) -> Tile {
        let now = context.date
        var tile = Tile(title: tr("Ma journée"), symbol: "sun.horizon")
        tile.value = Fmt.format(now, template: "EEEEd").capitalizedFirst
        tile.caption = TF.weather(context.payload).map { "\(Fmt.temperature($0.temperature, unit: context.settings.temperatureUnit)) · \(WeatherCode.description($0.code).lowercased()) à \($0.locationName)" } ?? Fmt.monthYear(now)
        tile.detail = tr("\(Fmt.percent(DateMath.progress(of: .day, at: now))) de la journée écoulée")
        tile.rows = [eventRow(context), tasksRow(context), caloriesRow(context), habitsRow(context)].compactMap { $0 } + [waterRow(context)]
        return tile
    }

    enum Moment {
        case morning, day, evening, night

        init(_ date: Date) {
            switch DateMath.calendar.component(.hour, from: date) {
            case 5..<11: self = .morning
            case 11..<18: self = .day
            case 18..<23: self = .evening
            default: self = .night
            }
        }
    }

    /// Changes with the time of day: plan in the morning, act during the day, review in the evening.
    static func now(_ context: RenderContext) -> Tile {
        let date = context.date
        switch Moment(date) {
        case .morning:
            var tile = Tile(title: tr("Ce matin"), symbol: "sunrise")
            if let weather = TF.weather(context.payload) {
                tile.value = Fmt.temperature(weather.temperature, unit: context.settings.temperatureUnit)
                tile.caption = WeatherCode.description(weather.code)
            } else {
                tile.value = TF.time(date, context)
                tile.caption = Fmt.longDay(date)
            }
            let priorities = prioritiesRows(context)
            var rows: [TileRow] = []
            if let event = eventRow(context) { rows.append(event) }
            if priorities.isEmpty {
                if let tasks = tasksRow(context) { rows.append(tasks) }
            } else {
                rows.append(contentsOf: priorities)
            }
            tile.rows = rows
            tile.detail = eventRow(context).map { "\($0.title) à \($0.value ?? "")" }
            return tile
        case .day:
            var tile = Tile(title: tr("Maintenant"), symbol: "bolt.fill")
            let open = context.payload.content.tasks.filter { !$0.isDone }
            tile.value = "\(open.count)"
            tile.unit = open.count > 1 ? tr("tâches") : tr("tâche")
            tile.caption = open.first.map { tr("Ensuite : \($0.title)") } ?? tr("Rien d'urgent, profites-en")
            tile.rows = [eventRow(context), workoutRow(context), caloriesRow(context)].compactMap { $0 } + [waterRow(context)]
            tile.buttons = [
                TileButton(title: tr("25 min"), symbol: "timer", action: .startFocus(25), isProminent: true),
                TileButton(title: tr("Eau"), symbol: "drop.fill", action: .addWater),
            ]
            return tile
        case .evening:
            var tile = Tile(title: tr("Ce soir"), symbol: "moon.stars")
            let done = context.payload.content.tasks.filter { $0.completedAt.map { DateMath.isSameDay($0, date) } ?? false }.count
            tile.value = "\(done)"
            tile.unit = done > 1 ? tr("tâches faites") : tr("tâche faite")
            tile.caption = tr("Le bilan de ta journée")
            let spent = BudgetMath.spentToday(context.payload.domains.budget, at: date)
            var rows = [habitsRow(context), caloriesRow(context)].compactMap { $0 }
            rows.append(waterRow(context))
            if spent > 0 {
                rows.append(TileRow(id: "spent", title: tr("Dépensé aujourd'hui"), value: TF.money(spent, context.settings.currencyCode), symbol: "creditcard"))
            }
            tile.rows = rows
            return tile
        case .night:
            var tile = Tile(title: tr("Demain"), symbol: "bed.double.fill")
            let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: date) ?? date
            tile.value = Fmt.format(tomorrow, template: "EEEE").capitalizedFirst
            if case let .ready(events) = context.payload.events, let first = events.first(where: { DateMath.isSameDay($0.start, tomorrow) }) {
                tile.caption = "\(first.title) à \(TF.time(first.start, context))"
            } else {
                tile.caption = tr("Rien de prévu tôt demain")
            }
            tile.detail = tr("Bonne nuit")
            tile.rows = [habitsRow(context)].compactMap { $0 }
            return tile
        }
    }

    static func morning(_ context: RenderContext) -> Tile {
        let now = context.date
        var tile = Tile(title: tr("Ce matin"), symbol: "sunrise")
        if let weather = TF.weather(context.payload) {
            let unit = context.settings.temperatureUnit
            tile.value = Fmt.temperature(weather.temperature, unit: unit)
            tile.caption = "\(WeatherCode.description(weather.code)) · ↑\(Fmt.temperature(weather.high, unit: unit))"
            if let rain = weather.day(for: now)?.precipitationProbability, rain >= 40 {
                tile.detail = tr("Prends un parapluie (\(rain) % de pluie)")
            }
        } else {
            tile.value = Fmt.format(now, template: "EEEEd").capitalizedFirst
            tile.caption = tr("Bonne journée")
        }
        var rows: [TileRow] = []
        if let event = eventRow(context) { rows.append(event) }
        rows.append(contentsOf: prioritiesRows(context))
        if let budget = budgetRow(context) { rows.append(budget) }
        tile.rows = rows
        if tile.rows.count < 3, let tasks = tasksRow(context) { tile.rows.append(tasks) }
        return tile
    }

    static func fitness(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.fitness
        guard !state.routines.isEmpty else { return .empty(tr("Tableau fitness"), symbol: "figure.run", message: FitnessTiles.hint) }
        let count = FitnessMath.workouts(inWeekOf: now, state)
        var tile = Tile(title: tr("Fitness"), symbol: "figure.run")
        tile.value = "\(count)/\(state.weeklyGoal)"
        tile.caption = tr("séances cette semaine · série \(FitnessMath.weekStreak(state, until: now))")
        var rows: [TileRow] = []
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        if let exercise = active?.currentExercise {
            rows.append(TileRow(id: "set", title: exercise.name, value: FitnessTiles.setText(exercise), symbol: "arrow.forward.circle.fill", isHighlighted: true))
        } else if let routine = state.routine(for: now) {
            rows.append(TileRow(id: "routine", title: routine.name, value: state.isScheduled(now) ? tr("Aujourd'hui") : tr("Prochaine"), symbol: "figure.strengthtraining.traditional"))
        }
        rows.append(TileRow(id: "volume", title: tr("Volume"), value: tr("\(TF.int(FitnessMath.weeklyVolume(state, weekOf: now).reduce(0, +))) kg"), symbol: "scalemass"))
        rows.append(TileRow(id: "burned", title: tr("Calories brûlées"), value: tr("\(TF.int(FitnessMath.caloriesBurned(state, on: now))) kcal"), symbol: "flame"))
        let nutrition = context.payload.domains.nutrition
        if !nutrition.entries.isEmpty {
            let protein = NutritionMath.totals(nutrition, on: now).protein
            rows.append(TileRow(id: "protein", title: tr("Protéines"), value: "\(TF.int(protein))/\(TF.int(nutrition.goals.protein)) g", symbol: "bolt.heart", progress: protein / max(1, nutrition.goals.protein)))
        }
        tile.rows = rows
        tile.visual = .week(DateMath.week(containing: now).map { day -> Bool? in
            let trained = FitnessMath.sessions(state).contains { DateMath.isSameDay($0.start, day) }
            if trained { return true }
            return day > now ? nil : false
        })
        tile.buttons = active == nil ? [] : [TileButton(title: tr("Série faite"), symbol: "checkmark", action: .completeSet, isProminent: true)]
        return tile
    }

    static func money(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.budget
        let currency = context.settings.currencyCode
        let remaining = BudgetMath.remaining(state, at: now)
        var tile = Tile(title: tr("Argent"), symbol: "dollarsign.circle")
        tile.value = TF.money(remaining, currency)
        tile.trend = remaining < 0 ? false : nil
        tile.caption = tr("reste ce mois · \(TF.money(BudgetMath.perDayLeft(state, at: now), currency))/jour")
        var rows = [TileRow(id: "today", title: tr("Dépensé aujourd'hui"), value: TF.money(BudgetMath.spentToday(state, at: now), currency, decimals: 2), symbol: "cart")]
        if let bill = BudgetMath.upcomingBills(state, at: now, within: 31).first {
            let cents = bill.bill.amount.rounded() == bill.bill.amount ? 0 : 2
            rows.append(TileRow(id: "bill", title: bill.bill.name, value: TF.money(bill.bill.amount, currency, decimals: cents), detail: TF.relativeDay(bill.due, from: now), symbol: bill.bill.symbol))
        }
        if let goal = state.goals.first {
            rows.append(TileRow(id: "goal", title: goal.name, value: Fmt.percent(goal.progress), symbol: "banknote", progress: goal.progress))
        }
        if !state.accounts.isEmpty {
            rows.append(TileRow(id: "worth", title: tr("Valeur nette"), value: TF.money(BudgetMath.netWorth(state), currency), symbol: "building.columns"))
        }
        tile.rows = rows
        tile.visual = .bar(BudgetMath.spentThisMonth(state, at: now) / max(1, state.monthlyBudget))
        return tile
    }

    static func student(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.student
        guard !state.courses.isEmpty || !state.exams.isEmpty else { return .empty(tr("Tableau études"), symbol: "graduationcap.circle", message: StudentTiles.hint) }
        var tile = Tile(title: tr("Études"), symbol: "graduationcap.circle")
        if let next = StudentMath.nextClass(state, at: now) {
            tile.value = next.start <= now ? tr("En cours") : TF.time(next.start, context)
            tile.caption = StudentTiles.courseName(state, next.slot.courseID) + (next.slot.room.isEmpty ? "" : " · \(next.slot.room)")
        } else {
            tile.value = tr("Libre")
            tile.caption = tr("Pas de cours prévu")
        }
        var rows: [TileRow] = []
        if let exam = StudentMath.nextExam(state, at: now) {
            rows.append(TileRow(id: "exam", title: exam.title, value: "J-\(DateMath.daysBetween(now, exam.date))", symbol: "pencil.and.list.clipboard", isHighlighted: DateMath.daysBetween(now, exam.date) <= 7))
        }
        for item in StudentMath.openAssignments(state).prefix(2) {
            rows.append(TileRow(id: item.id.uuidString, title: item.title, value: TF.relativeDay(item.due, from: now), isDone: false, action: .toggleAssignment(item.id.uuidString)))
        }
        let minutes = StudentMath.studyMinutes(state, weekOf: now)
        rows.append(TileRow(id: "study", title: tr("Étude cette semaine"), value: Fmt.minutes(minutes), symbol: "clock", progress: minutes / 60 / max(0.5, state.weeklyStudyGoalHours)))
        if let average = StudentMath.overallAverage(state) {
            rows.append(TileRow(id: "avg", title: tr("Moyenne"), value: "\(TF.decimal(average, 1)) %", symbol: "graduationcap"))
        }
        tile.rows = rows
        return tile
    }

    // MARK: Analyses

    static func insight(_ context: RenderContext) -> Tile {
        let kind = context.design.kind
        let insight = InsightEngine.insight(for: kind, payload: context.payload, now: context.date)
        var tile = Tile(title: insight.title, symbol: kind == .aiSummary ? "sparkles" : insight.symbol)
        tile.value = ""
        tile.caption = context.payload.domains.insights.phrasing(for: kind, insight: insight) ?? insight.text
        tile.rows = insight.points.prefix(5).enumerated().map { pair in
            TileRow(id: "\(pair.offset)", title: pair.element, symbol: "circle.fill")
        }
        tile.footnote = tr("Calculé à partir de tes données, sur ton iPhone")
        tile.inline = insight.text
        return tile
    }
}
