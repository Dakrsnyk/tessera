import Foundation

/// What the « Décompte » widget (kind `birthday`) counts to: the name and the date its options give,
/// else « Anniversaire » and the birthday of « Ma vie », else a day a month after the widget was made.
enum DayCountdown {
    static var defaultTitle: String { tr("Anniversaire") }

    /// The name drawn: the chosen one, « Anniversaire » while none is chosen, « Événement » when it was emptied.
    static func title(_ options: DesignOptions) -> String {
        guard let chosen = options.dayTitle else { return defaultTitle }
        let trimmed = chosen.trimmed
        return trimmed.isEmpty ? tr("Événement") : trimmed
    }

    /// True for the default name: the birthday wording (« Joyeux anniversaire ! ») stays.
    static func usesBirthdayWording(_ options: DesignOptions) -> Bool {
        title(options).caseInsensitiveCompare(defaultTitle) == .orderedSame
    }

    /// The date counted to, at the start of its day.
    static func date(for design: WidgetDesign, birthday: Date?) -> Date {
        if let chosen = design.options.dayDate { return DateMath.startOfDay(chosen) }
        if let birthday { return DateMath.startOfDay(birthday) }
        let created = DateMath.startOfDay(design.createdAt)
        return DateMath.calendar.date(byAdding: .day, value: 30, to: created) ?? created
    }

    /// True when the widget counts to the person's own birthday (« avant tes N ans »).
    static func followsBirthday(_ options: DesignOptions, birthday: Date?) -> Bool {
        guard let birthday, usesBirthdayWording(options) else { return false }
        guard let chosen = options.dayDate else { return true }
        return DateMath.calendar.isDate(chosen, inSameDayAs: birthday)
    }
}

enum TimeTiles {
    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let life = context.payload.domains.life
        switch context.design.kind {
        case .ageProgress: return age(life, now: now)
        case .birthday: return birthday(context.design, life: life, now: now)
        case .weekView: return week(now: now)
        case .holiday: return holiday(life, now: now)
        case .moonPhase: return moon(now: now)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    private static let lifeHint = tr("Ajoute ta date de naissance dans Ardane, espace Ma vie.")

    static func age(_ life: LifeState, now: Date) -> Tile {
        guard let birthday = life.birthday else {
            return .empty(tr("Mon âge"), symbol: "person.crop.circle.badge.clock", message: lifeHint)
        }
        let age = LifeMath.age(birthday: birthday, at: now)
        let next = LifeMath.nextBirthday(birthday: birthday, after: now)
        let fraction = age - age.rounded(.down)
        let days = DateMath.daysBetween(now, next.date)
        var tile = Tile(title: tr("Mon âge"), symbol: "person.crop.circle.badge.clock")
        tile.value = TF.decimal(age, 2)
        tile.unit = tr("ans")
        tile.caption = days == 0 ? tr("Joyeux anniversaire !") : tr("\(next.age) ans dans \(days) \(TF.days(days))")
        tile.detail = tr("\(Fmt.percent(fraction)) de ton année en cours")
        tile.visual = .bar(fraction)
        tile.gauge = fraction
        tile.shortValue = "\(Int(age.rounded(.down)))"
        tile.inline = tr("\(TF.decimal(age, 2)) ans")
        return tile
    }

    /// The « Décompte » widget (kind `birthday`): the days to a date and a name chosen by the person, each
    /// year or once. Left at its defaults it is the birthday widget it used to be, word for word.
    static func birthday(_ design: WidgetDesign, life: LifeState, now: Date) -> Tile {
        let options = design.options
        let title = DayCountdown.title(options)
        let usesBirthdayWording = DayCountdown.usesBirthdayWording(options)
        let target = DayCountdown.date(for: design, birthday: life.birthday)
        var tile = Tile(title: title, symbol: usesBirthdayWording ? "gift" : "hourglass")
        if options.dayRepeatsYearly {
            let today = DateMath.startOfDay(now)
            // A date still ahead is its own first occurrence; one behind comes back each year.
            let next = target > today ? (date: target, age: 0) : LifeMath.nextBirthday(birthday: target, after: now)
            let days = DateMath.daysBetween(now, next.date)
            if days == 0 {
                if next.age > 0 {
                    tile.value = "\(next.age)"
                    tile.unit = tr("ans")
                } else {
                    tile.value = tr("Aujourd'hui")
                }
                tile.caption = usesBirthdayWording ? tr("Joyeux anniversaire !") : tr("C'est aujourd'hui")
                tile.visual = .ring(1)
                tile.gauge = 1
                tile.inline = usesBirthdayWording ? tr("Joyeux anniversaire !") : tr("\(title) aujourd'hui")
            } else {
                tile.value = Fmt.number(days)
                tile.unit = TF.days(days)
                if DayCountdown.followsBirthday(options, birthday: life.birthday) {
                    tile.caption = tr("avant tes \(next.age) ans")
                } else if next.age > 0 {
                    tile.caption = tr("avant les \(next.age) ans")
                }
                tile.detail = Fmt.longDay(next.date)
                tile.visual = .ring(max(0.02, 1 - Double(days) / 365))
                tile.gauge = max(0, 1 - Double(days) / 365)
                tile.inline = usesBirthdayWording ? tr("Anniversaire dans \(days) j") : tr("\(title) dans \(days) j")
            }
            tile.shortValue = days == 0 ? (usesBirthdayWording ? "🎂" : "🎉") : Fmt.number(days)
            return tile
        }
        // Once: the days until the date, then the days since it.
        let delta = DateMath.daysBetween(now, target)
        let days = abs(delta)
        let fullDate = Fmt.longDay(target) + " " + Fmt.format(target, template: "yyyy")
        if delta == 0 {
            tile.value = tr("Aujourd'hui")
            tile.detail = fullDate
            tile.visual = .ring(1)
            tile.gauge = 1
            tile.inline = tr("\(title) aujourd'hui")
            tile.shortValue = "🎉"
        } else if delta > 0 {
            tile.value = Fmt.number(days)
            tile.caption = days > 1 ? tr("jours restants") : tr("jour restant")
            tile.detail = fullDate
            // Share of the wait already behind us, from the day the widget was made.
            let start = DateMath.startOfDay(design.createdAt)
            let span = target.timeIntervalSince(start)
            let elapsed = span > 0 ? min(1, max(0, now.timeIntervalSince(start) / span)) : 0
            tile.visual = .ring(max(0.02, elapsed))
            tile.gauge = elapsed
            tile.inline = tr("\(title) dans \(days) j")
            tile.shortValue = Fmt.number(days)
        } else {
            tile.value = Fmt.number(days)
            tile.caption = days > 1 ? tr("jours depuis") : tr("jour depuis")
            tile.detail = fullDate
            let fraction = min(1, Double(days) / 365)
            tile.visual = .ring(max(0.02, fraction))
            tile.gauge = fraction
            tile.inline = tr("\(title) depuis \(days) j")
            tile.shortValue = Fmt.number(days)
        }
        return tile
    }

    static func week(now: Date) -> Tile {
        let week = DateMath.calendar.component(.weekOfYear, from: now)
        let progress = DateMath.progress(of: .week, at: now)
        let todayIndex = TF.todayIndex(now)
        var tile = Tile(title: tr("Semaine \(week)"), symbol: "calendar.day.timeline.left")
        tile.value = Fmt.weekday(now)
        tile.caption = tr("\(Fmt.format(now, template: "dMMMM")) · \(Fmt.percent(progress)) de la semaine")
        tile.visual = .week((0..<7).map { index -> Bool? in index <= todayIndex ? true : nil })
        tile.gauge = progress
        tile.shortValue = "S\(week)"
        tile.inline = tr("Semaine \(week) · \(Fmt.percent(progress))")
        return tile
    }

    static func holiday(_ life: LifeState, now: Date) -> Tile {
        let upcoming = Holidays.upcoming(life.holidayRegion, from: now, count: 5)
        guard let next = upcoming.first else {
            return .empty(tr("Jour férié"), symbol: "sun.max", message: tr("Aucun jour férié trouvé."))
        }
        let days = DateMath.daysBetween(now, next.date)
        var tile = Tile(title: tr("Prochain férié"), symbol: "sun.max")
        tile.value = days == 0 ? tr("Aujourd'hui") : Fmt.number(days)
        tile.unit = days == 0 ? nil : TF.days(days)
        tile.caption = next.name
        tile.detail = "\(Fmt.longDay(next.date)) · \(life.holidayRegion.title)"
        tile.rows = upcoming.dropFirst().map { holiday in
            TileRow(id: holiday.name, title: holiday.name, value: Fmt.shortDay(holiday.date), symbol: "calendar")
        }
        tile.inline = days == 0 ? tr("\(next.name) aujourd'hui") : tr("\(next.name) dans \(days) j")
        tile.shortValue = Fmt.number(days)
        return tile
    }

    static func moon(now: Date) -> Tile {
        let illumination = MoonPhase.illumination(at: now)
        let full = MoonPhase.next(0.5, after: now)
        let new = MoonPhase.next(0, after: now)
        var tile = Tile(title: tr("Lune"), symbol: MoonPhase.symbol(at: now))
        tile.value = Fmt.percent(illumination)
        tile.unit = tr("éclairée")
        tile.caption = MoonPhase.name(at: now)
        tile.detail = tr("Pleine lune \(TF.relativeDay(full, from: now))")
        tile.visual = .symbol(MoonPhase.symbol(at: now))
        tile.rows = [
            TileRow(id: "full", title: tr("Pleine lune"), value: Fmt.shortDay(full), symbol: "moonphase.full.moon"),
            TileRow(id: "new", title: tr("Nouvelle lune"), value: Fmt.shortDay(new), symbol: "moonphase.new.moon"),
        ].sorted { ($0.id == "full" ? full : new) < ($1.id == "full" ? full : new) }
        tile.gauge = illumination
        tile.shortValue = Fmt.percent(illumination)
        tile.inline = "\(MoonPhase.name(at: now)) · \(Fmt.percent(illumination))"
        return tile
    }
}
