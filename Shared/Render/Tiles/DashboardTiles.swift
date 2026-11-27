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

    static func eventRow(_ context: RenderContext) -> TileRow? {
        guard case let .ready(events) = context.payload.events, let next = events.first(where: { $0.end > context.date }) else { return nil }
        let time = next.isAllDay ? tr("Journée") : TF.time(next.start, context)
        return TileRow(id: "event", title: next.title, value: time, symbol: "calendar", colorHex: next.colorHex)
    }

    /// How many lines a size can hold: the essentials in small, more in medium, the full picture in large.
    static func limit(_ context: RenderContext, small: Int, medium: Int, large: Int) -> Int {
        context.isSmall ? small : context.isMedium ? medium : large
    }

    /// The next events of the day that are not over (the first keeps the id `event`).
    static func eventRows(_ context: RenderContext, limit: Int) -> [TileRow] {
        guard limit > 0, case let .ready(events) = context.payload.events else { return [] }
        return events.filter { $0.end > context.date }.prefix(limit).enumerated().map { pair in
            let time = pair.element.isAllDay ? tr("Journée") : TF.time(pair.element.start, context)
            return TileRow(id: pair.offset == 0 ? "event" : "event\(pair.offset)", title: pair.element.title, value: time, symbol: "calendar", colorHex: pair.element.colorHex)
        }
    }

    static func tasksRow(_ context: RenderContext) -> TileRow? {
        let tasks = context.payload.content.tasks
        guard !tasks.isEmpty else { return nil }
        let open = tasks.filter { !$0.isDone }
        return TileRow(id: "tasks", title: open.first?.title ?? tr("Toutes les tâches sont faites"), value: tr("\(open.count) à faire"), symbol: "checklist")
    }

    /// The first tasks still to do.
    static func openTaskRows(_ context: RenderContext, limit: Int = 3) -> [TileRow] {
        context.payload.content.tasks.filter { !$0.isDone }.prefix(limit).map { task in
            TileRow(id: task.id.uuidString, title: task.title, symbol: "circle")
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
            return TileRow(id: "budget", title: tr("Dépensé aujourd'hui"), value: TF.money(spent, context.settings.currencyCode), symbol: "creditcard", isSensitive: true)
        }
        let perDay = BudgetMath.perDayLeft(budget, at: context.date)
        return TileRow(id: "budget", title: tr("Budget du jour"), value: TF.money(perDay, context.settings.currencyCode), symbol: "creditcard", isSensitive: true)
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
        tile.caption = Fmt.monthYear(now)
        tile.detail = tr("\(Fmt.percent(DateMath.progress(of: .day, at: now))) de la journée écoulée")
        // Medium: the next events then the day's counts. Large: the next tasks by name and the day's spending too.
        var rows = eventRows(context, limit: limit(context, small: 1, medium: 2, large: 3))
        if context.isLarge {
            let open = openTaskRows(context, limit: 3)
            rows.append(contentsOf: open)
            if open.isEmpty, let tasks = tasksRow(context) { rows.append(tasks) }
        } else if let tasks = tasksRow(context) {
            rows.append(tasks)
        }
        rows.append(contentsOf: [workoutRow(context), caloriesRow(context), habitsRow(context)].compactMap { $0 })
        if context.isLarge, let budget = budgetRow(context) { rows.append(budget) }
        tile.rows = Array(rows.prefix(limit(context, small: 3, medium: 4, large: 9)))
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
            tile.value = TF.time(date, context)
            tile.caption = Fmt.longDay(date)
            var rows = eventRows(context, limit: limit(context, small: 1, medium: 2, large: 3))
            let open = openTaskRows(context, limit: limit(context, small: 3, medium: 2, large: 5))
            if open.isEmpty {
                if let tasks = tasksRow(context) { rows.append(tasks) }
            } else {
                rows.append(contentsOf: open)
            }
            if !context.isSmall { rows.append(contentsOf: [workoutRow(context), habitsRow(context)].compactMap { $0 }) }
            tile.rows = Array(rows.prefix(limit(context, small: 3, medium: 4, large: 9)))
            // The event is already a row beyond small.
            if context.isSmall { tile.detail = eventRow(context).map { "\($0.title) à \($0.value ?? "")" } }
            return tile
        case .day:
            var tile = Tile(title: tr("Maintenant"), symbol: "bolt.fill")
            let open = context.payload.content.tasks.filter { !$0.isDone }
            tile.value = "\(open.count)"
            tile.unit = open.count > 1 ? tr("tâches") : tr("tâche")
            tile.caption = open.first.map { tr("Ensuite : \($0.title)") } ?? tr("Rien d'urgent, profites-en")
            var rows = [eventRow(context), workoutRow(context), caloriesRow(context), habitsRow(context)].compactMap { $0 }
            if context.isLarge {
                rows.append(contentsOf: open.dropFirst().prefix(3).map { TileRow(id: $0.id.uuidString, title: $0.title, symbol: "circle") })
                if let budget = budgetRow(context) { rows.append(budget) }
            }
            tile.rows = Array(rows.prefix(limit(context, small: 3, medium: 4, large: 9)))
            tile.buttons = [
                TileButton(title: tr("25 min"), symbol: "timer", action: .startFocus(25), isProminent: true),
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
            if spent > 0 {
                rows.append(TileRow(id: "spent", title: tr("Dépensé aujourd'hui"), value: TF.money(spent, context.settings.currencyCode), symbol: "creditcard"))
            }
            if context.isLarge {
                // What is left for tomorrow, so the evening review also looks ahead.
                let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: date) ?? date
                if case let .ready(events) = context.payload.events, let first = events.first(where: { DateMath.isSameDay($0.start, tomorrow) }) {
                    rows.append(TileRow(id: "tomorrow", title: first.title, value: first.isAllDay ? tr("Journée") : TF.time(first.start, context), detail: tr("Demain"), symbol: "calendar", colorHex: first.colorHex))
                }
                let left = context.payload.content.tasks.filter { !$0.isDone }.count
                if left > 0 { rows.append(TileRow(id: "left", title: tr("Tâches restantes"), value: "\(left)", symbol: "checklist")) }
            }
            tile.rows = Array(rows.prefix(limit(context, small: 3, medium: 4, large: 9)))
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
            var rows: [TileRow] = []
            if !context.isSmall, case let .ready(events) = context.payload.events {
                let tomorrowEvents = events.filter { DateMath.isSameDay($0.start, tomorrow) }.prefix(limit(context, small: 0, medium: 2, large: 5))
                rows.append(contentsOf: tomorrowEvents.enumerated().map { pair in
                    TileRow(id: "event\(pair.offset)", title: pair.element.title, value: pair.element.isAllDay ? tr("Journée") : TF.time(pair.element.start, context), symbol: "calendar", colorHex: pair.element.colorHex)
                })
            }
            if let habits = habitsRow(context) { rows.append(habits) }
            if context.isLarge {
                rows.append(contentsOf: context.payload.content.tasks.filter { !$0.isDone }.prefix(3).map { TileRow(id: $0.id.uuidString, title: $0.title, symbol: "circle") })
            }
            tile.rows = Array(rows.prefix(limit(context, small: 1, medium: 4, large: 9)))
            if context.isSmall { tile.detail = tr("Bonne nuit") }
            return tile
        }
    }

    static func morning(_ context: RenderContext) -> Tile {
        let now = context.date
        var tile = Tile(title: tr("Ce matin"), symbol: "sunrise")
        tile.value = Fmt.format(now, template: "EEEEd").capitalizedFirst
        let left = context.payload.content.tasks.filter { !$0.isDone }.count
        tile.caption = left > 0 ? Fmt.plural(left, tr("tâche restante"), tr("tâches restantes")) : tr("Bonne journée")
        var rows = eventRows(context, limit: limit(context, small: 1, medium: 2, large: 4))
        rows.append(contentsOf: openTaskRows(context, limit: limit(context, small: 3, medium: 2, large: 5)))
        if !context.isSmall {
            rows.append(contentsOf: [workoutRow(context), habitsRow(context)].compactMap { $0 })
        }
        if let budget = budgetRow(context) { rows.append(budget) }
        if rows.count < 3, let tasks = tasksRow(context) { rows.append(tasks) }
        tile.rows = Array(rows.prefix(limit(context, small: 3, medium: 4, large: 9)))
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
            rows.append(TileRow(id: "set", title: exercise.name, value: FitnessTiles.setText(exercise, system: context.settings.unitSystem), symbol: "arrow.forward.circle.fill", isHighlighted: true))
        } else if let routine = state.routine(for: now) {
            rows.append(TileRow(id: "routine", title: routine.name, value: state.isScheduled(now) ? tr("Aujourd'hui") : tr("Prochaine"), symbol: "figure.strengthtraining.traditional"))
        }
        rows.append(TileRow(id: "volume", title: tr("Volume"), value: Units.loadText(kilograms: FitnessMath.weeklyVolume(state, weekOf: now).reduce(0, +), in: context.settings.unitSystem, digits: 0), symbol: "scalemass"))
        // No calories without the person's weight (the state's 70 kg default is not theirs).
        if context.payload.domains.knowsWeight {
            rows.append(TileRow(id: "burned", title: tr("Calories brûlées"), value: tr("\(TF.int(FitnessMath.caloriesBurned(state, on: now))) kcal"), symbol: "flame"))
        }
        let nutrition = context.payload.domains.nutrition
        if !nutrition.entries.isEmpty {
            let protein = NutritionMath.totals(nutrition, on: now).protein
            rows.append(TileRow(id: "protein", title: tr("Protéines"), value: "\(TF.int(protein))/\(TF.int(nutrition.goals.protein)) g", symbol: "bolt.heart", progress: protein / max(1, nutrition.goals.protein)))
        }
        tile.rows = Array(rows.prefix(limit(context, small: 2, medium: 4, large: 6)))
        tile.visual = .week(DateMath.week(containing: now).map { day -> Bool? in
            let trained = FitnessMath.sessions(state).contains { DateMath.isSameDay($0.start, day) }
            if trained { return true }
            return day > now ? nil : false
        })
        tile.buttons = active == nil ? [] : FitnessTiles.setButtons(state, now: now)
        return tile
    }

    static func money(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.budget
        let currency = context.settings.currencyCode
        var tile = Tile(title: tr("Argent"), symbol: "dollarsign.circle")
        if context.payload.domains.knows(.monthlyBudget) {
            let remaining = BudgetMath.remaining(state, at: now)
            tile.value = TF.money(remaining, currency)
            tile.trend = remaining < 0 ? false : nil
            tile.caption = tr("reste ce mois · \(TF.money(BudgetMath.perDayLeft(state, at: now), currency))/jour")
        } else {
            // No budget given: what was spent, never a remainder of a made-up budget.
            tile.value = TF.money(BudgetMath.spentThisMonth(state, at: now), currency)
            tile.caption = tr("dépensés ce mois-ci · budget à définir")
        }
        var rows = [TileRow(id: "today", title: tr("Dépensé aujourd'hui"), value: TF.money(BudgetMath.spentToday(state, at: now), currency, decimals: 2), symbol: "cart")]
        if context.isLarge, context.payload.domains.knows(.monthlyBudget) {
            rows.append(TileRow(id: "month", title: tr("Dépensé ce mois-ci"), value: TF.money(BudgetMath.spentThisMonth(state, at: now), currency), symbol: "chart.bar"))
        }
        for (index, bill) in BudgetMath.upcomingBills(state, at: now, within: 31).prefix(context.isLarge ? 3 : 1).enumerated() {
            let cents = bill.bill.amount.rounded() == bill.bill.amount ? 0 : 2
            rows.append(TileRow(id: index == 0 ? "bill" : "bill\(index)", title: bill.bill.name, value: TF.money(bill.bill.amount, currency, decimals: cents), detail: TF.relativeDay(bill.due, from: now), symbol: bill.bill.symbol))
        }
        for (index, goal) in state.goals.prefix(context.isLarge ? 2 : 1).enumerated() {
            rows.append(TileRow(id: index == 0 ? "goal" : "goal\(index)", title: goal.name, value: Fmt.percent(goal.progress), symbol: "banknote", progress: goal.progress))
        }
        if !state.accounts.isEmpty {
            rows.append(TileRow(id: "worth", title: tr("Valeur nette"), value: TF.money(BudgetMath.netWorth(state), currency), symbol: "building.columns"))
        }
        tile.rows = Array(rows.prefix(limit(context, small: 2, medium: 4, large: 8)))
        // The bar compares with the person's budget: without one, nothing to compare, no bar.
        if context.payload.domains.knows(.monthlyBudget) {
            tile.visual = .bar(BudgetMath.spentThisMonth(state, at: now) / max(1, state.monthlyBudget))
        }
        return tile
    }

    static func student(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.student
        guard !state.courses.isEmpty || !state.exams.isEmpty else { return .empty(tr("Tableau études"), symbol: "graduationcap.circle", message: StudentTiles.hint) }
        var tile = Tile(title: tr("Études"), symbol: "graduationcap.circle")
        if let next = StudentMath.nextClass(state, at: now) {
            tile.value = next.start <= now ? tr("En cours") : TF.time(next.start, context)
            tile.caption = state.title(of: next.slot) + (next.slot.room.isEmpty ? "" : " · \(next.slot.room)")
        } else {
            tile.value = tr("Libre")
            tile.caption = tr("Pas de cours prévu")
        }
        var rows: [TileRow] = []
        if let exam = StudentMath.nextExam(state, at: now) {
            rows.append(TileRow(id: "exam", title: exam.title, value: tr("J-\(DateMath.daysBetween(now, exam.date))"), symbol: "pencil.and.list.clipboard", isHighlighted: DateMath.daysBetween(now, exam.date) <= 7))
        }
        for item in StudentMath.openAssignments(state).prefix(limit(context, small: 1, medium: 1, large: 4)) {
            rows.append(TileRow(id: item.id.uuidString, title: item.title, value: TF.relativeDay(item.due, from: now), isDone: false, action: .toggleAssignment(item.id.uuidString)))
        }
        let minutes = StudentMath.studyMinutes(state, weekOf: now)
        rows.append(TileRow(id: "study", title: tr("Étude cette semaine"), value: Fmt.minutes(minutes), symbol: "clock", progress: minutes / 60 / max(0.5, state.weeklyStudyGoalHours)))
        if let average = StudentMath.overallAverage(state) {
            rows.append(TileRow(id: "avg", title: tr("Moyenne"), value: "\(TF.decimal(average, 1)) %", symbol: "graduationcap"))
        }
        tile.rows = Array(rows.prefix(limit(context, small: 2, medium: 4, large: 8)))
        return tile
    }

    // MARK: Analyses

    static func insight(_ context: RenderContext) -> Tile {
        let kind = context.design.kind
        let insight = InsightEngine.insight(for: kind, payload: context.payload, now: context.date)
        var tile = Tile(title: insight.title, symbol: kind == .aiSummary ? "sparkles" : insight.symbol)
        tile.value = ""
        tile.caption = context.payload.domains.insights.phrasing(for: kind, insight: insight) ?? insight.text
        tile.rows = insight.points.prefix(limit(context, small: 0, medium: 3, large: 5)).enumerated().map { pair in
            TileRow(id: "\(pair.offset)", title: pair.element, symbol: "circle.fill")
        }
        tile.footnote = tr("Calculé à partir de tes données, sur ton iPhone")
        tile.inline = insight.text
        return tile
    }
}
