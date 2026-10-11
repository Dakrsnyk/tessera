import Foundation

enum TimeTiles {
    static func make(_ context: RenderContext) -> Tile {
        let now = context.date
        let life = context.payload.domains.life
        switch context.design.kind {
        case .ageProgress: return age(life, now: now)
        case .birthday: return birthday(life, now: now)
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

    static func birthday(_ life: LifeState, now: Date) -> Tile {
        guard let birthday = life.birthday else {
            return .empty(tr("Anniversaire"), symbol: "gift", message: lifeHint)
        }
        let next = LifeMath.nextBirthday(birthday: birthday, after: now)
        let days = DateMath.daysBetween(now, next.date)
        var tile = Tile(title: tr("Anniversaire"), symbol: "gift")
        if days == 0 {
            tile.value = "\(next.age)"
            tile.unit = tr("ans")
            tile.caption = tr("Joyeux anniversaire !")
            tile.visual = .ring(1)
            tile.gauge = 1
            tile.inline = tr("Joyeux anniversaire !")
        } else {
            tile.value = Fmt.number(days)
            tile.unit = TF.days(days)
            tile.caption = tr("avant tes \(next.age) ans")
            tile.detail = Fmt.longDay(next.date)
            tile.visual = .ring(max(0.02, 1 - Double(days) / 365))
            tile.gauge = 1 - Double(days) / 365
            tile.inline = tr("Anniversaire dans \(days) j")
        }
        tile.shortValue = days == 0 ? "🎂" : Fmt.number(days)
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
