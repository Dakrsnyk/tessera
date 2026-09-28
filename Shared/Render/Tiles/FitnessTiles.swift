import Foundation

enum FitnessTiles {
    static let hint = "Crée ta première séance dans Tessera, espace Fitness."

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.fitness
        switch context.design.kind {
        case .todaysWorkout: return todaysWorkout(state, now: now)
        case .nextSet: return nextSet(state, now: now)
        case .restTimer: return restTimer(state, now: now)
        case .weeklyVolume: return weeklyVolume(state, now: now)
        case .personalRecords: return records(state)
        case .trainingStreak: return streak(state, now: now)
        case .caloriesBurned: return calories(state, now: now)
        case .workoutMonth: return month(state, now: now)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    static func setText(_ exercise: ExerciseTemplate) -> String {
        exercise.weight > 0 ? "\(exercise.reps) × \(TF.decimal(exercise.weight, exercise.weight.rounded() == exercise.weight ? 0 : 1)) kg" : "\(exercise.reps) répétitions"
    }

    static func todaysWorkout(_ state: FitnessState, now: Date) -> Tile {
        guard let routine = state.routine(for: now) else { return .empty("Séance du jour", symbol: "figure.strengthtraining.traditional", message: hint) }
        let doneToday = FitnessMath.sessions(state).contains { DateMath.isSameDay($0.start, now) && $0.isFinished }
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        let planned = state.isScheduled(now)
        var tile = Tile(title: planned ? "Séance du jour" : "Prochaine séance", symbol: "figure.strengthtraining.traditional")
        tile.value = active?.routineName ?? routine.name
        let exercises = active?.exercises ?? routine.exercises
        let totalSets = exercises.reduce(0) { $0 + $1.sets }
        if let active {
            tile.caption = "En cours · \(active.sets.count)/\(active.totalSets) séries"
            tile.visual = .bar(Double(active.sets.count) / Double(max(1, active.totalSets)))
        } else if doneToday {
            tile.caption = "Séance faite aujourd'hui"
            tile.visual = .bar(1)
        } else {
            tile.caption = "\(Fmt.plural(exercises.count, "exercice", "exercices")) · \(totalSets) séries"
        }
        tile.rows = exercises.enumerated().map { pair -> TileRow in
            let isCurrent = active.map { $0.exerciseIndex == pair.offset } ?? false
            let isDone = active.map { $0.exerciseIndex > pair.offset } ?? doneToday
            return TileRow(id: "\(pair.offset)", title: pair.element.name, value: "\(pair.element.sets) × \(setText(pair.element))", isDone: isDone, isHighlighted: isCurrent)
        }
        tile.buttons = doneToday ? [] : [TileButton(title: active == nil ? "Commencer" : "Série faite", symbol: active == nil ? "play.fill" : "checkmark", action: .completeSet, isProminent: true)]
        tile.inline = "\(tile.value) · \(totalSets) séries"
        return tile
    }

    static func nextSet(_ state: FitnessState, now: Date) -> Tile {
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        guard let exercise = active?.currentExercise ?? state.routine(for: now)?.exercises.first else {
            return .empty("Prochaine série", symbol: "arrow.forward.circle.fill", message: hint)
        }
        var tile = Tile(title: "Prochaine série", symbol: "arrow.forward.circle.fill")
        tile.value = setText(exercise)
        let setNumber = (active?.setIndex ?? 0) + 1
        tile.caption = "\(exercise.name) · série \(setNumber)/\(exercise.sets)"
        if let rest = active?.restEndsAt, rest > now {
            let start = active?.sets.last?.date ?? now
            tile.visual = .timer(min(start, now), rest)
            tile.detail = "Repos jusqu'à \(Fmt.time(rest, uses24Hour: true))"
        } else if active == nil {
            tile.detail = "Touche pour démarrer « \(state.routine(for: now)?.name ?? "ta séance") »"
        }
        tile.buttons = [TileButton(title: "Série faite", symbol: "checkmark", action: .completeSet, isProminent: true)]
        tile.inline = "\(exercise.name) : \(setText(exercise))"
        tile.shortValue = "\(setNumber)/\(exercise.sets)"
        return tile
    }

    static func restTimer(_ state: FitnessState, now: Date) -> Tile {
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        var tile = Tile(title: "Repos", symbol: "timer")
        if let active, let rest = active.restEndsAt, rest > now {
            let start = min(active.sets.last?.date ?? now, now)
            tile.timer = start...rest
            tile.visual = .timer(start, rest)
            if let next = active.currentExercise {
                tile.caption = "Ensuite : \(next.name)"
                tile.detail = setText(next)
            }
            tile.buttons = [
                TileButton(title: "Passer", symbol: "forward.fill", action: .skipRest),
                TileButton(title: "Série faite", symbol: "checkmark", action: .completeSet, isProminent: true),
            ]
            tile.inline = "Repos jusqu'à \(Fmt.time(rest, uses24Hour: true))"
        } else {
            tile.value = "Prêt"
            if let exercise = active?.currentExercise ?? state.routine(for: now)?.exercises.first {
                tile.caption = "\(exercise.name) · \(setText(exercise))"
            } else {
                tile.caption = "Valide une série pour lancer le repos"
            }
            tile.buttons = [TileButton(title: "Série faite", symbol: "checkmark", action: .completeSet, isProminent: true)]
            tile.inline = "Repos : prêt"
        }
        tile.shortValue = tile.value
        return tile
    }

    static func weeklyVolume(_ state: FitnessState, now: Date) -> Tile {
        let days = FitnessMath.weeklyVolume(state, weekOf: now)
        let total = days.reduce(0, +)
        let lastWeekDate = DateMath.calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let lastWeek = FitnessMath.weeklyVolume(state, weekOf: lastWeekDate).reduce(0, +)
        var tile = Tile(title: "Volume", symbol: "scalemass")
        tile.value = TF.int(total)
        tile.unit = "kg"
        tile.caption = "soulevés cette semaine"
        if let change = Stats.change(from: lastWeek, to: total) {
            tile.detail = "Semaine dernière : \(TF.int(lastWeek)) kg (\(Fmt.signedPercent(change * 100)))"
        }
        tile.visual = .bars(days, labels: TF.weekdayLetters(), highlight: TF.todayIndex(now))
        tile.inline = "\(TF.int(total)) kg cette semaine"
        return tile
    }

    static func records(_ state: FitnessState) -> Tile {
        let records = FitnessMath.records(state)
        guard let best = records.first else { return .empty("Records", symbol: "trophy.fill", message: "Tes records apparaîtront après ta première séance.") }
        var tile = Tile(title: "Records", symbol: "trophy.fill")
        tile.value = "\(TF.int(best.weight)) kg"
        tile.caption = "\(best.exercise) · \(best.reps) rép."
        tile.detail = "1RM estimé : \(TF.int(best.oneRepMax)) kg"
        tile.rows = records.prefix(6).map { record in
            TileRow(id: record.exercise, title: record.exercise, value: "\(TF.int(record.weight)) kg × \(record.reps)", detail: "1RM ≈ \(TF.int(record.oneRepMax)) kg", symbol: "trophy")
        }
        tile.inline = "\(best.exercise) : \(TF.int(best.weight)) kg"
        return tile
    }

    static func streak(_ state: FitnessState, now: Date) -> Tile {
        let count = FitnessMath.workouts(inWeekOf: now, state)
        let goal = max(1, state.weeklyGoal)
        let streak = FitnessMath.weekStreak(state, until: now)
        let trained = Set(FitnessMath.sessions(state).map { DateMath.dayKey($0.start) })
        var tile = Tile(title: "Régularité", symbol: "flame.fill")
        tile.value = "\(count)/\(goal)"
        tile.caption = "séances cette semaine"
        tile.detail = streak > 0 ? "Série : \(Fmt.plural(streak, "semaine", "semaines"))" : "Objectif : \(goal) par semaine"
        tile.visual = .week(DateMath.week(containing: now).map { day -> Bool? in
            if trained.contains(DateMath.dayKey(day)) { return true }
            return day > now ? nil : false
        })
        tile.gauge = Double(count) / Double(goal)
        tile.shortValue = "\(count)/\(goal)"
        tile.inline = "\(count)/\(goal) séances · série \(streak)"
        return tile
    }

    static func calories(_ state: FitnessState, now: Date) -> Tile {
        let today = FitnessMath.caloriesBurned(state, on: now)
        let week = DateMath.week(containing: now).map { FitnessMath.caloriesBurned(state, on: $0) }
        var tile = Tile(title: "Calories brûlées", symbol: "flame")
        tile.value = TF.int(today)
        tile.unit = "kcal"
        tile.caption = "estimées aujourd'hui"
        tile.detail = "Semaine : \(TF.int(week.reduce(0, +))) kcal"
        tile.visual = .bars(week, labels: TF.weekdayLetters(), highlight: TF.todayIndex(now))
        tile.footnote = "Estimation selon la durée des séances et ton poids"
        tile.inline = "\(TF.int(today)) kcal brûlées"
        return tile
    }

    static func month(_ state: FitnessState, now: Date) -> Tile {
        let trained = FitnessMath.trainedDays(state, inMonthOf: now)
        let first = DateMath.calendar.dateInterval(of: .month, for: now)?.start ?? now
        let days = DateMath.calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        var marked = Set<Int>()
        for day in 1...days {
            if let date = DateMath.calendar.date(byAdding: .day, value: day - 1, to: first), trained.contains(DateMath.dayKey(date)) {
                marked.insert(day)
            }
        }
        var tile = Tile(title: Fmt.month(now), symbol: "calendar")
        tile.value = Fmt.number(trained.count)
        tile.unit = trained.count > 1 ? "séances" : "séance"
        tile.caption = "ce mois-ci"
        tile.visual = .month(days: days, offset: FitnessMath.isoWeekday(first) - 1, marked: marked, today: DateMath.calendar.component(.day, from: now))
        tile.inline = "\(trained.count) séances en \(Fmt.month(now).lowercased())"
        return tile
    }
}
