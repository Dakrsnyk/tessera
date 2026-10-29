import Foundation

enum FitnessTiles {
    static let hint = tr("Crée ta première séance dans Ardane, espace Fitness.")

    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.fitness
        let domains = context.payload.domains
        let system = context.settings.unitSystem
        switch context.design.kind {
        case .todaysWorkout: return todaysWorkout(state, now: now, system: system)
        case .nextSet: return nextSet(state, now: now, system: system)
        case .restTimer: return restTimer(state, now: now, system: system)
        case .weeklyVolume: return weeklyVolume(state, now: now, system: system)
        case .personalRecords: return records(state, system: system)
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
    /// The load is saved in kg and shown in the chosen unit ("60 kg" / "132,3 lb").
    static func setsText(_ exercise: ExerciseTemplate, system: UnitSystem = .metric) -> String {
        let base = "\(exercise.sets) × \(exercise.reps)"
        guard exercise.weight > 0 else { return base }
        return tr("\(base) · \(Units.loadText(kilograms: exercise.weight, in: system))")
    }

    static func setText(_ exercise: ExerciseTemplate, system: UnitSystem = .metric) -> String {
        exercise.weight > 0 ? tr("\(exercise.reps) × \(Units.loadText(kilograms: exercise.weight, in: system))") : tr("\(exercise.reps) répétitions")
    }

    /// The small back arrow next to « Série faite »: takes back the last set (also just after the set
    /// that finished the session), or cancels a session started by mistake, before any set.
    static func backButton(_ state: FitnessState, now: Date) -> TileButton? {
        if state.canUndoLastSet(at: now) {
            return TileButton(title: tr("Annuler la dernière série"), symbol: "arrow.uturn.backward", action: .undoSet(state.position), isIconOnly: true)
        }
        if state.activeHasNoSets {
            return TileButton(title: tr("Annuler la séance"), symbol: "xmark", action: .cancelWorkout, isIconOnly: true)
        }
        return nil
    }

    /// The small « Passer » next to « Série faite » during a session: the set shown is passed, not
    /// counted. Last in the list: dropped where only two buttons fit.
    static func skipButton(_ state: FitnessState) -> TileButton? {
        guard let active = state.active, !active.isFinished, active.currentExercise != nil else { return nil }
        return TileButton(title: tr("Passer la série"), symbol: "forward.fill", action: .skipSet(state.position), isIconOnly: true)
    }

    /// « Série faite » (or « Commencer »), then the back arrow, then « Passer ».
    static func setButtons(_ state: FitnessState, now: Date, title: String = tr("Série faite"), symbol: String = "checkmark") -> [TileButton] {
        var buttons = [TileButton(title: title, symbol: symbol, action: .completeSet(state.position), isProminent: true)]
        if let back = backButton(state, now: now) { buttons.append(back) }
        if let skip = skipButton(state) { buttons.append(skip) }
        return buttons
    }

    static func todaysWorkout(_ state: FitnessState, now: Date, system: UnitSystem = .metric) -> Tile {
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
            return TileRow(id: "\(pair.offset)", title: pair.element.name, value: setsText(pair.element, system: system), isDone: isDone, isHighlighted: isCurrent)
        }
        if doneToday {
            tile.buttons = []
            if let back = backButton(state, now: now) { tile.buttons.append(back) }
        } else {
            tile.buttons = setButtons(state, now: now, title: active == nil ? tr("Commencer") : tr("Série faite"), symbol: active == nil ? "play.fill" : "checkmark")
        }
        tile.inline = tr("\(tile.value) · \(totalSets) séries")
        return tile
    }

    static func nextSet(_ state: FitnessState, now: Date, system: UnitSystem = .metric) -> Tile {
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        guard let exercise = active?.currentExercise ?? state.routine(for: now)?.exercises.first else {
            return .empty(tr("Prochaine série"), symbol: "arrow.forward.circle.fill", message: hint)
        }
        var tile = Tile(title: tr("Prochaine série"), symbol: "arrow.forward.circle.fill")
        tile.value = setText(exercise, system: system)
        let setNumber = (active?.setIndex ?? 0) + 1
        tile.caption = tr("\(exercise.name) · série \(setNumber)/\(exercise.sets)")
        if let rest = active?.restEndsAt, rest > now {
            let start = active?.sets.last?.date ?? now
            tile.visual = .timer(min(start, now), rest)
            tile.detail = tr("Repos jusqu'à \(Fmt.time(rest, uses24Hour: true))")
        } else if active == nil {
            tile.detail = tr("Touche pour démarrer « \(state.routine(for: now)?.name ?? tr("ta séance")) »")
        }
        tile.buttons = setButtons(state, now: now)
        tile.inline = "\(exercise.name) : \(setText(exercise, system: system))"
        tile.shortValue = "\(setNumber)/\(exercise.sets)"
        return tile
    }

    static func restTimer(_ state: FitnessState, now: Date, system: UnitSystem = .metric) -> Tile {
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        var tile = Tile(title: tr("Repos"), symbol: "timer")
        if let active, let rest = active.restEndsAt, rest > now {
            let start = min(active.sets.last?.date ?? now, now)
            tile.timer = start...rest
            tile.visual = .timer(start, rest)
            if let next = active.currentExercise {
                tile.caption = tr("Ensuite : \(next.name)")
                tile.detail = setText(next, system: system)
            }
            // « Passer » passes the set coming (not counted), like on the Lock Screen.
            tile.buttons = [
                TileButton(title: tr("Passer"), symbol: "forward.fill", action: .skipSet(state.position)),
                TileButton(title: tr("Fait"), symbol: "checkmark", action: .completeSet(state.position), isProminent: true),
            ]
            // Third: dropped where only two buttons fit, « Fait » stays.
            if let back = backButton(state, now: now) { tile.buttons.append(back) }
            tile.inline = tr("Repos jusqu'à \(Fmt.time(rest, uses24Hour: true))")
        } else {
            tile.value = tr("Prêt")
            if let exercise = active?.currentExercise ?? state.routine(for: now)?.exercises.first {
                tile.caption = "\(exercise.name) · \(setText(exercise, system: system))"
            } else {
                tile.caption = tr("Valide une série pour lancer le repos")
            }
            tile.buttons = setButtons(state, now: now)
            tile.inline = tr("Repos : prêt")
        }
        tile.shortValue = tile.value
        return tile
    }

    static func weeklyVolume(_ state: FitnessState, now: Date, system: UnitSystem = .metric) -> Tile {
        let days = FitnessMath.weeklyVolume(state, weekOf: now)
        let total = days.reduce(0, +)
        let lastWeekDate = DateMath.calendar.date(byAdding: .day, value: -7, to: now) ?? now
        // Same days of last week, so a Monday isn't compared with a whole week.
        let lastWeek = FitnessMath.weeklyVolume(state, weekOf: lastWeekDate).prefix(TF.todayIndex(now) + 1).reduce(0, +)
        var tile = Tile(title: tr("Volume"), symbol: "scalemass")
        tile.value = Units.loadNumber(kilograms: total, in: system, digits: 0)
        tile.unit = system.weightUnit
        tile.caption = tr("soulevés cette semaine")
        if let change = Stats.change(from: lastWeek, to: total) {
            tile.detail = tr("Sem. dernière : \(Units.loadText(kilograms: lastWeek, in: system, digits: 0)) (\(Fmt.signedPercent(change * 100, decimals: 0)))")
        }
        tile.visual = .bars(days, labels: TF.weekdayLetters(), highlight: TF.todayIndex(now))
        tile.inline = tr("\(Units.loadText(kilograms: total, in: system, digits: 0)) cette semaine")
        return tile
    }

    static func records(_ state: FitnessState, system: UnitSystem = .metric) -> Tile {
        let records = FitnessMath.records(state)
        guard let best = records.first else { return .empty(tr("Records"), symbol: "trophy.fill", message: tr("Tes records apparaîtront après ta première séance.")) }
        var tile = Tile(title: tr("Records"), symbol: "trophy.fill")
        tile.value = Units.loadText(kilograms: best.weight, in: system, digits: 0)
        tile.caption = tr("\(best.exercise) · \(best.reps) rép.")
        tile.detail = tr("1RM estimé : \(Units.loadText(kilograms: best.oneRepMax, in: system, digits: 0))")
        tile.rows = records.prefix(6).map { record in
            TileRow(id: record.exercise, title: record.exercise, value: tr("\(Units.loadText(kilograms: record.weight, in: system, digits: 0)) × \(record.reps)"), detail: tr("1RM ≈ \(Units.loadText(kilograms: record.oneRepMax, in: system, digits: 0))"), symbol: "trophy")
        }
        tile.inline = tr("\(best.exercise) : \(Units.loadText(kilograms: best.weight, in: system, digits: 0))")
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
            tile.detail = tr("Objectif à définir dans Ardane")
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
