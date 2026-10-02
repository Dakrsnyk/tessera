import Foundation

enum ProductivityTiles {
    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let state = context.payload.domains.productivity
        let content = context.payload.content
        let target = context.options.targetID
        switch context.design.kind {
        case .priorities: return priorities(state, now: now)
        case .project: return project(state, target: target, now: now)
        case .deadline: return deadline(state, target: target, now: now, context: context)
        case .deepWork: return deepWork(state, now: now)
        case .counter: return counter(state, target: target, now: now)
        case .habitStreak: return habitStreak(content, target: target, context: context)
        case .habitWeek: return habitWeek(content, now: now)
        case .habitRate: return habitRate(content, now: now)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    static func priorities(_ state: ProductivityState, now: Date) -> Tile {
        let items = Array(state.priorities.prefix(3))
        guard !items.isEmpty else {
            return .empty(tr("Top 3 du jour"), symbol: "3.circle", message: tr("Choisis tes trois priorités dans Tessera, espace Productivité."))
        }
        let done = items.filter { $0.isDone(on: now) }.count
        var tile = Tile(title: tr("Top 3 du jour"), symbol: "3.circle")
        tile.value = "\(done)/\(items.count)"
        tile.caption = done == items.count ? tr("Journée gagnée") : tr("priorités faites")
        tile.rows = items.map { item in
            TileRow(id: item.id.uuidString, title: item.title, isDone: item.isDone(on: now), action: .togglePriority(item.id.uuidString))
        }
        tile.compactRows = true
        tile.gauge = Double(done) / Double(items.count)
        tile.shortValue = "\(done)/\(items.count)"
        tile.inline = tr("Priorités \(done)/\(items.count)")
        return tile
    }

    static func project(_ state: ProductivityState, target: String?, now: Date) -> Tile {
        let chosen = state.projects.first { $0.id.uuidString == target } ?? ProductivityMath.mainProject(state, at: now)
        guard let project = chosen else {
            return .empty(tr("Projet"), symbol: "folder.fill", message: tr("Crée un projet et ses tâches dans Tessera, espace Productivité."))
        }
        var tile = Tile(title: project.name, symbol: "folder.fill")
        tile.value = Fmt.percent(project.progress)
        let remaining = project.remaining.count
        var caption = remaining == 0 ? tr("Terminé") : tr("\(remaining) tâche\(remaining > 1 ? "s" : "") restante\(remaining > 1 ? "s" : "")")
        if let deadline = project.deadline {
            caption += " · \(TF.relativeDay(deadline, from: now))"
            tile.detail = tr("Échéance : \(Fmt.longDay(deadline))")
        }
        tile.caption = caption
        tile.visual = .ring(project.progress)
        tile.rows = project.remaining.prefix(5).map { task in
            TileRow(id: task.id.uuidString, title: task.title, isDone: false, action: .toggleProjectTask(project.id.uuidString, task.id.uuidString))
        }
        tile.gauge = project.progress
        tile.shortValue = Fmt.percent(project.progress)
        tile.inline = "\(project.name) · \(Fmt.percent(project.progress))"
        return tile
    }

    static func deadline(_ state: ProductivityState, target: String?, now: Date, context: RenderContext) -> Tile {
        let chosen = state.deadlines.first { $0.id.uuidString == target && $0.date > now } ?? ProductivityMath.nextDeadline(state, after: now)
        guard let deadline = chosen else {
            return .empty(tr("Échéance"), symbol: "flag.checkered", message: tr("Ajoute une échéance dans Tessera, espace Productivité."))
        }
        var tile = Tile(title: deadline.title, symbol: "flag.checkered")
        let seconds = deadline.date.timeIntervalSince(now)
        if seconds < 86_400 {
            tile.timer = now...deadline.date
            tile.caption = tr("avant \(TF.time(deadline.date, context))")
        } else {
            let days = Int(seconds / 86_400)
            let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3600)
            tile.value = "\(days) j \(hours) h"
            tile.caption = "\(Fmt.longDay(deadline.date)) à \(TF.time(deadline.date, context))"
        }
        tile.detail = seconds < 3600 ? tr("Dernière ligne droite") : nil
        tile.shortValue = seconds < 86_400 ? "\(Int(seconds / 3600)) h" : "\(Int(seconds / 86_400)) j"
        tile.inline = "\(deadline.title) · \(TF.relativeTime(deadline.date, from: now))"
        return tile
    }

    static func deepWork(_ state: ProductivityState, now: Date) -> Tile {
        let minutes = ProductivityMath.focusMinutes(state, weekOf: now)
        let goal = max(0.5, state.weeklyFocusGoalHours)
        let hours = minutes / 60
        var tile = Tile(title: tr("Travail profond"), symbol: "brain.head.profile")
        tile.value = Fmt.hours(hours)
        tile.caption = tr("sur \(Fmt.hours(goal)) · \(Fmt.percent(min(9.99, hours / goal)))")
        let today = ProductivityMath.focusByDay(state, weekOf: now)
        tile.visual = .bars(today, labels: TF.weekdayLetters(), highlight: TF.todayIndex(now))
        let todayMinutes = today[safe: TF.todayIndex(now)] ?? 0
        tile.detail = tr("Aujourd'hui : \(Fmt.minutes(todayMinutes))")
        tile.buttons = [TileButton(title: tr("25 min"), symbol: "play.fill", action: .startFocus(25), isProminent: true)]
        tile.gauge = min(1, hours / goal)
        tile.shortValue = "\(Int(hours.rounded())) h"
        tile.inline = tr("Focus \(Fmt.hours(hours)) cette semaine")
        return tile
    }

    static func counter(_ state: ProductivityState, target: String?, now: Date) -> Tile {
        guard let counter = state.counters.first(where: { $0.id.uuidString == target }) ?? state.counters.first else {
            return .empty(tr("Compteur"), symbol: "plusminus.circle", message: tr("Crée un compteur dans Tessera, espace Productivité."))
        }
        let value = counter.value(on: now)
        var tile = Tile(title: counter.name, symbol: counter.symbol)
        tile.value = Fmt.number(value)
        if let goal = counter.goal, goal > 0 {
            tile.unit = "/ \(Fmt.number(goal))"
            tile.gauge = Double(value) / Double(goal)
            tile.caption = value >= goal ? tr("Objectif atteint") : tr("encore \(Fmt.number(goal - value))")
        } else {
            tile.caption = counter.resetsDaily ? tr("aujourd'hui") : tr("au total")
        }
        let step = max(1, counter.step)
        tile.buttons = [
            TileButton(title: "\(step)", symbol: "minus", action: .counter(counter.id.uuidString, -1)),
            TileButton(title: "\(step)", symbol: "plus", action: .counter(counter.id.uuidString, 1), isProminent: true),
        ]
        tile.shortValue = Fmt.number(value)
        tile.inline = "\(counter.name) : \(Fmt.number(value))"
        return tile
    }

    // MARK: Habits

    static func habitStreak(_ content: ContentState, target: String?, context: RenderContext) -> Tile {
        let now = context.date
        let picked = content.habits.first { $0.id.uuidString == target }
            ?? content.habits.max { $0.streak(asOf: now) < $1.streak(asOf: now) }
        guard let habit = picked else {
            return .empty(tr("Série"), symbol: "flame.fill", message: tr("Crée une habitude dans Tessera pour suivre ta série."))
        }
        let streak = habit.streak(asOf: now)
        var tile = Tile(title: habit.name, symbol: "flame.fill")
        tile.value = Fmt.number(streak)
        tile.unit = TF.days(streak)
        tile.caption = habit.isDone(on: now) ? tr("fait aujourd'hui") : tr("pas encore fait aujourd'hui")
        if context.isSmall {
            let week = DateMath.week(containing: now)
            tile.visual = .week(week.map { day -> Bool? in day > now && !DateMath.isSameDay(day, now) ? nil : habit.isDone(on: day) })
        } else {
            let days = DateMath.calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            let first = DateMath.calendar.dateInterval(of: .month, for: now)?.start ?? now
            let offset = FitnessMath.isoWeekday(first) - 1
            var marked = Set<Int>()
            for day in 1...days {
                if let date = DateMath.calendar.date(byAdding: .day, value: day - 1, to: first), habit.isDone(on: date) { marked.insert(day) }
            }
            tile.visual = .month(days: days, offset: offset, marked: marked, today: DateMath.calendar.component(.day, from: now))
            let best = bestStreak(habit, until: now)
            tile.detail = tr("Record : \(Fmt.plural(best, tr("jour"), tr("jours")))")
        }
        if !habit.isDone(on: now) && !context.isSmall {
            tile.buttons = [TileButton(title: tr("Fait"), symbol: "checkmark", action: .toggleHabit(habit.id.uuidString), isProminent: true)]
        }
        tile.gauge = min(1, Double(streak) / 30)
        tile.shortValue = Fmt.number(streak)
        tile.inline = "\(habit.name) : \(Fmt.plural(streak, tr("jour"), tr("jours")))"
        return tile
    }

    /// Longest run of consecutive days over the last year.
    static func bestStreak(_ habit: Habit, until date: Date) -> Int {
        let keys = Set(habit.completedDays)
        var best = 0
        var run = 0
        for offset in (0..<366).reversed() {
            guard let day = DateMath.calendar.date(byAdding: .day, value: -offset, to: date) else { continue }
            if keys.contains(DateMath.dayKey(day)) {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    static func habitWeek(_ content: ContentState, now: Date) -> Tile {
        guard !content.habits.isEmpty else {
            return .empty(tr("Semaine d'habitudes"), symbol: "square.grid.3x3.fill", message: tr("Crée tes habitudes dans Tessera."))
        }
        let week = DateMath.week(containing: now)
        let habits = Array(content.habits.prefix(6))
        let rows = habits.map { habit in
            week.map { day -> Bool? in day > now && !DateMath.isSameDay(day, now) ? nil : habit.isDone(on: day) }
        }
        let done = habits.reduce(0) { total, habit in total + week.filter { habit.isDone(on: $0) }.count }
        let elapsed = TF.todayIndex(now) + 1
        var tile = Tile(title: tr("Semaine d'habitudes"), symbol: "square.grid.3x3.fill")
        tile.value = Fmt.number(done)
        tile.unit = "/ \(elapsed * habits.count)"
        tile.caption = tr("validations cette semaine")
        tile.visual = .grid(names: habits.map(\.name), rows: rows, colors: habits.map(\.colorHex))
        tile.inline = tr("Habitudes : \(done) cette semaine")
        return tile
    }

    static func habitRate(_ content: ContentState, now: Date) -> Tile {
        guard !content.habits.isEmpty else {
            return .empty(tr("Taux de réussite"), symbol: "percent", message: tr("Crée tes habitudes dans Tessera."))
        }
        let first = DateMath.calendar.dateInterval(of: .month, for: now)?.start ?? now
        let days = DateMath.daysBetween(first, now) + 1
        var total = 0
        var rows: [TileRow] = []
        for habit in content.habits {
            var count = 0
            for offset in 0..<days {
                if let day = DateMath.calendar.date(byAdding: .day, value: offset, to: first), habit.isDone(on: day) { count += 1 }
            }
            total += count
            let rate = Double(count) / Double(max(1, days))
            rows.append(TileRow(id: habit.id.uuidString, title: habit.name, value: Fmt.percent(rate), symbol: habit.symbol, colorHex: habit.colorHex, progress: rate))
        }
        let rate = Double(total) / Double(max(1, days * content.habits.count))
        var tile = Tile(title: tr("Taux de réussite"), symbol: "percent")
        tile.value = Fmt.percent(rate)
        tile.caption = tr("des habitudes tenues en \(Fmt.month(now).lowercased())")
        tile.visual = .ring(rate)
        tile.rows = rows.sorted { ($0.progress ?? 0) > ($1.progress ?? 0) }
        tile.gauge = rate
        tile.shortValue = Fmt.percent(rate)
        tile.inline = tr("Habitudes : \(Fmt.percent(rate)) ce mois-ci")
        return tile
    }
}
