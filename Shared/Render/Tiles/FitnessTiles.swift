import Foundation

enum FitnessTiles {
    static let hint = tr("Crée ta première séance dans Tessera, espace Fitness.")

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.fitness
        let domains = context.payload.domains
        switch context.design.kind {
        case .todaysWorkout: return todaysWorkout(state, now: now)
        case .nextSet: return nextSet(state, now: now)
        case .restTimer: return restTimer(state, now: now)
        case .weeklyVolume: return weeklyVolume(state, now: now)
        case .personalRecords: return records(state)
        case .trainingStreak: return streak(state, now: now, knowsGoal: domains.knows(.weeklyWorkouts))
        case .caloriesBurned:
            // The estimate needs the user's weight: without it, no number is made up.
            guard domains.knowsWeight else {
                return .empty(tr("Calories brûlées"), symbol: "flame", message: tr("Ajoute ton poids dans « Mes informations » pour estimer tes calories brûlées."))
            }
            return calories(state, now: now)
        case .workoutMonth: return month(state, now: now)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    /// "4 × 8 · 60 kg" or "3 × 12".
    static func setsText(_ exercise: ExerciseTemplate) -> String {
        let base = "\(exercise.sets) × \(exercise.reps)"
        guard exercise.weight > 0 else { return base }
        return tr("\(base) · \(TF.decimal(exercise.weight, exercise.weight.rounded() == exercise.weight ? 0 : 1)) kg")
    }

    static func setText(_ exercise: ExerciseTemplate) -> String {
        exercise.weight > 0 ? tr("\(exercise.reps) × \(TF.decimal(exercise.weight, exercise.weight.rounded() == exercise.weight ? 0 : 1)) kg") : tr("\(exercise.reps) répétitions")
    }

    static func todaysWorkout(_ state: FitnessState, now: Date) -> Tile {
        guard let routine = state.routine(for: now) else { return .empty(tr("Séance du jour"), symbol: "figure.strengthtraining.traditional", message: hint) }
        let doneToday = FitnessMath.sessions(state).contains { DateMath.isSameDay($0.start, now) && $0.isFinished }
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        let planned = state.isScheduled(now)
        var tile = Tile(title: planned ? tr("Séance du jour") : tr("Prochaine séance"), symbol: "figure.strengthtraining.traditional")
        tile.value = active?.routineName ?? routine.name
        let exercises = active?.exercises ?? routine.exercises
        let totalSets = exercises.reduce(0) { $0 + $1.sets }
        if let active {
            tile.caption = tr("En cours · \(active.sets.count)/\(active.totalSets) séries")
            tile.visual = .bar(Double(active.sets.count) / Double(max(1, active.totalSets)))
        } else if doneToday {
            tile.caption = tr("Séance faite aujourd'hui")
            tile.visual = .bar(1)
        } else {
            tile.caption = tr("\(Fmt.plural(exercises.count, tr("exercice"), tr("exercices"))) · \(totalSets) séries")
        }
        tile.rows = exercises.enumerated().map { pair -> TileRow in
            let isCurrent = active.map { $0.exerciseIndex == pair.offset } ?? false
            let isDone = active.map { $0.exerciseIndex > pair.offset } ?? doneToday
            return TileRow(id: "\(pair.offset)", title: pair.element.name, value: setsText(pair.element), isDone: isDone, isHighlighted: isCurrent)
        }
        tile.buttons = doneToday ? [] : [TileButton(title: active == nil ? tr("Commencer") : tr("Série faite"), symbol: active == nil ? "play.fill" : "checkmark", action: .completeSet, isProminent: true)]
        tile.inline = tr("\(tile.value) · \(totalSets) séries")
        return tile
    }

    static func nextSet(_ state: FitnessState, now: Date) -> Tile {
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        guard let exercise = active?.currentExercise ?? state.routine(for: now)?.exercises.first else {
            return .empty(tr("Prochaine série"), symbol: "arrow.forward.circle.fill", message: hint)
        }
        var tile = Tile(title: tr("Prochaine série"), symbol: "arrow.forward.circle.fill")
        tile.value = setText(exercise)
        let setNumber = (active?.setIndex ?? 0) + 1
        tile.caption = tr("\(exercise.name) · série \(setNumber)/\(exercise.sets)")
        if let rest = active?.restEndsAt, rest > now {
            let start = active?.sets.last?.date ?? now
            tile.visual = .timer(min(start, now), rest)
            tile.detail = tr("Repos jusqu'à \(Fmt.time(rest, uses24Hour: true))")
        } else if active == nil {
            tile.detail = tr("Touche pour démarrer « \(state.routine(for: now)?.name ?? tr("ta séance")) »")
        }
        tile.buttons = [TileButton(title: tr("Série faite"), symbol: "checkmark", action: .completeSet, isProminent: true)]
        tile.inline = "\(exercise.name) : \(setText(exercise))"
        tile.shortValue = "\(setNumber)/\(exercise.sets)"
        return tile
    }

    static func restTimer(_ state: FitnessState, now: Date) -> Tile {
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        var tile = Tile(title: tr("Repos"), symbol: "timer")
        if let active, let rest = active.restEndsAt, rest > now {
            let start = min(active.sets.last?.date ?? now, now)
            tile.timer = start...rest
            tile.visual = .timer(start, rest)
            if let next = active.currentExercise {
                tile.caption = tr("Ensuite : \(next.name)")
                tile.detail = setText(next)
            }
            tile.buttons = [
                TileButton(title: tr("Passer"), symbol: "forward.fill", action: .skipRest),
                TileButton(title: tr("Fait"), symbol: "checkmark", action: .completeSet, isProminent: true),
            ]
            tile.inline = tr("Repos jusqu'à \(Fmt.time(rest, uses24Hour: true))")
        } else {
            tile.value = tr("Prêt")
            if let exercise = active?.currentExercise ?? state.routine(for: now)?.exercises.first {
                tile.caption = "\(exercise.name) · \(setText(exercise))"
            } else {
                tile.caption = tr("Valide une série pour lancer le repos")
            }
            tile.buttons = [TileButton(title: tr("Série faite"), symbol: "checkmark", action: .completeSet, isProminent: true)]
            tile.inline = tr("Repos : prêt")
        }
        tile.shortValue = tile.value
        return tile
    }

    static func weeklyVolume(_ state: FitnessState, now: Date) -> Tile {
        let days = FitnessMath.weeklyVolume(state, weekOf: now)
        let total = days.reduce(0, +)
        let lastWeekDate = DateMath.calendar.date(byAdding: .day, value: -7, to: now) ?? now
        // Same days of last week, so a Monday isn't compared with a whole week.
        let lastWeek = FitnessMath.weeklyVolume(state, weekOf: lastWeekDate).prefix(TF.todayIndex(now) + 1).reduce(0, +)
        var tile = Tile(title: tr("Volume"), symbol: "scalemass")
        tile.value = TF.int(total)
        tile.unit = tr("kg")
        tile.caption = tr("soulevés cette semaine")
        if let change = Stats.change(from: lastWeek, to: total) {
            tile.detail = tr("Sem. dernière : \(TF.int(lastWeek)) kg (\(Fmt.signedPercent(change * 100, decimals: 0)))")
        }
        tile.visual = .bars(days, labels: TF.weekdayLetters(), highlight: TF.todayIndex(now))
        tile.inline = tr("\(TF.int(total)) kg cette semaine")
        return tile
    }

    static func records(_ state: FitnessState) -> Tile {
        let records = FitnessMath.records(state)
        guard let best = records.first else { return .empty(tr("Records"), symbol: "trophy.fill", message: tr("Tes records apparaîtront après ta première séance.")) }
        var tile = Tile(title: tr("Records"), symbol: "trophy.fill")
        tile.value = tr("\(TF.int(best.weight)) kg")
        tile.caption = tr("\(best.exercise) · \(best.reps) rép.")
        tile.detail = tr("1RM estimé : \(TF.int(best.oneRepMax)) kg")
        tile.rows = records.prefix(6).map { record in
            TileRow(id: record.exercise, title: record.exercise, value: tr("\(TF.int(record.weight)) kg × \(record.reps)"), detail: tr("1RM ≈ \(TF.int(record.oneRepMax)) kg"), symbol: "trophy")
        }
        tile.inline = tr("\(best.exercise) : \(TF.int(best.weight)) kg")
        return tile
    }

    static func streak(_ state: FitnessState, now: Date, knowsGoal: Bool = true) -> Tile {
        let count = FitnessMath.workouts(inWeekOf: now, state)
        let goal = max(1, state.weeklyGoal)
        let streak = FitnessMath.weekStreak(state, until: now)
        let trained = Set(FitnessMath.sessions(state).map { DateMath.dayKey($0.start) })
        var tile = Tile(title: tr("Régularité"), symbol: "flame.fill")
        tile.visual = .week(DateMath.week(containing: now).map { day -> Bool? in
            if trained.contains(DateMath.dayKey(day)) { return true }
            return day > now ? nil : false
        })
        guard knowsGoal else {
            // No weekly goal given: the sessions done, without a target the user never set.
            tile.value = Fmt.number(count)
            tile.caption = count > 1 ? tr("séances cette semaine") : tr("séance cette semaine")
            tile.detail = tr("Objectif à définir dans Tessera")
            tile.shortValue = Fmt.number(count)
            tile.inline = tr("\(Fmt.plural(count, tr("séance"), tr("séances"))) cette semaine")
            return tile
        }
        tile.value = "\(count)/\(goal)"
        tile.caption = tr("séances cette semaine")
        tile.detail = streak > 0 ? tr("Série : \(Fmt.plural(streak, tr("semaine"), tr("semaines")))") : tr("Objectif : \(goal) par semaine")
        tile.gauge = Double(count) / Double(goal)
        tile.shortValue = "\(count)/\(goal)"
        tile.inline = tr("\(count)/\(goal) séances · série \(streak)")
        return tile
    }

    static func calories(_ state: FitnessState, now: Date) -> Tile {
        let today = FitnessMath.caloriesBurned(state, on: now)
        let week = DateMath.week(containing: now).map { FitnessMath.caloriesBurned(state, on: $0) }
        var tile = Tile(title: tr("Calories brûlées"), symbol: "flame")
        tile.value = TF.int(today)
        tile.unit = "kcal"
        tile.caption = tr("estimées aujourd'hui")
        tile.detail = tr("Semaine : \(TF.int(week.reduce(0, +))) kcal")
        tile.visual = .bars(week, labels: TF.weekdayLetters(), highlight: TF.todayIndex(now))
        tile.footnote = tr("Estimation selon la durée des séances et ton poids")
        tile.inline = tr("\(TF.int(today)) kcal brûlées")
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
        tile.unit = trained.count > 1 ? tr("séances") : tr("séance")
        tile.caption = tr("ce mois-ci")
        tile.visual = .month(days: days, offset: FitnessMath.isoWeekday(first) - 1, marked: marked, today: DateMath.calendar.component(.day, from: now))
        tile.inline = tr("\(trained.count) séances en \(Fmt.month(now).lowercased())")
        return tile
    }
}
