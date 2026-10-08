import Foundation

enum StudentTiles {
    static let hint = tr("Ajoute tes cours dans Tessera, espace Études.")

    static func make(_ context: RenderContext) -> Tile {
        let state = context.payload.domains.student
        switch context.design.kind {
        case .nextClass: return nextClass(state, context: context)
        case .nextExam: return nextExam(state, context: context)
        case .assignments: return assignments(state, now: context.date)
        case .gradeAverage: return average(state)
        case .semesterProgress: return semester(state, now: context.date)
        case .flashcard: return flashcard(state, now: context.date)
        case .studyHours: return studyHours(state, now: context.date)
        case .timetable: return timetable(state, context: context)
        default: return TileFactory.placeholder(context.design.kind)
        }
    }

    static func courseName(_ state: StudentState, _ id: UUID?) -> String {
        state.course(id)?.name ?? tr("Cours")
    }

    static func nextClass(_ state: StudentState, context: RenderContext) -> Tile {
        let now = context.date
        guard let next = StudentMath.nextClass(state, at: now) else {
            return .empty(tr("Prochain cours"), symbol: "book.closed", message: hint)
        }
        let course = state.course(next.slot.courseID)
        let ongoing = next.start <= now
        var tile = Tile(title: ongoing ? tr("Cours actuel") : tr("Prochain cours"), symbol: "book.closed")
        var detail: [String] = []
        if !next.slot.room.isEmpty { detail.append(tr("Salle \(next.slot.room)")) }
        if ongoing {
            // The course in progress is the headline; when it ends is the caption.
            tile.value = course?.name ?? tr("Cours")
            tile.caption = tr("En cours · fin à \(TF.time(next.end, context))")
        } else {
            tile.value = TF.time(next.start, context)
            tile.caption = course?.name ?? tr("Cours")
            detail.append(TF.relativeTime(next.start, from: now))
        }
        tile.detail = detail.isEmpty ? nil : detail.joined(separator: " · ")
        if ongoing {
            tile.visual = .timer(next.start, next.end)
        }
        let later = StudentMath.occurrences(state, on: next.start).filter { $0.start > next.start }
        tile.rows = later.prefix(3).map { item in
            TileRow(id: item.slot.id.uuidString, title: courseName(state, item.slot.courseID), value: TF.time(item.start, context), detail: item.slot.room.isEmpty ? nil : tr("Salle \(item.slot.room)"), colorHex: state.course(item.slot.courseID)?.colorHex)
        }
        tile.inline = ongoing ? tr("\(course?.name ?? tr("Cours")) en cours") : "\(course?.name ?? tr("Cours")) à \(TF.time(next.start, context))"
        tile.shortValue = TF.time(next.start, context)
        return tile
    }

    static func nextExam(_ state: StudentState, context: RenderContext) -> Tile {
        let now = context.date
        guard let exam = StudentMath.nextExam(state, at: now) else {
            return .empty(tr("Prochain examen"), symbol: "pencil.and.list.clipboard", message: tr("Ajoute tes examens dans Tessera, espace Études."))
        }
        let days = DateMath.daysBetween(now, exam.date)
        var tile = Tile(title: tr("Prochain examen"), symbol: "pencil.and.list.clipboard")
        tile.value = days == 0 ? tr("Aujourd'hui") : Fmt.number(days)
        tile.unit = days == 0 ? nil : TF.days(days)
        tile.caption = exam.title
        tile.detail = "\(Fmt.shortDay(exam.date)) à \(TF.time(exam.date, context))\(exam.room.isEmpty ? "" : " · \(exam.room)")"
        let later = state.exams.filter { $0.date > exam.date }.sorted { $0.date < $1.date }
        tile.rows = later.prefix(3).map { item in
            TileRow(id: item.id.uuidString, title: item.title, value: Fmt.shortDay(item.date), colorHex: state.course(item.courseID)?.colorHex)
        }
        tile.gauge = max(0, 1 - Double(days) / 30)
        tile.shortValue = days == 0 ? "J" : "J-\(days)"
        tile.inline = days == 0 ? tr("\(exam.title) aujourd'hui") : tr("\(exam.title) dans \(days) j")
        return tile
    }

    static func assignments(_ state: StudentState, now: Date) -> Tile {
        let open = StudentMath.openAssignments(state)
        guard !state.assignments.isEmpty else {
            return .empty(tr("Devoirs"), symbol: "doc.text", message: tr("Ajoute tes travaux à rendre dans Tessera, espace Études."))
        }
        var tile = Tile(title: tr("Devoirs"), symbol: "doc.text")
        tile.value = Fmt.number(open.count)
        tile.unit = open.count > 1 ? tr("à rendre") : tr("à rendre")
        if let first = open.first {
            tile.caption = "\(first.title) · \(TF.relativeDay(first.due, from: now))"
        } else {
            tile.caption = tr("Tout est rendu")
        }
        tile.rows = open.prefix(5).map { item in
            TileRow(
                id: item.id.uuidString, title: item.title,
                value: TF.shortRelativeDay(item.due, from: now),
                colorHex: state.course(item.courseID)?.colorHex,
                isDone: false, action: .toggleAssignment(item.id.uuidString),
                isHighlighted: DateMath.daysBetween(now, item.due) <= 1
            )
        }
        tile.compactRows = true
        tile.shortValue = Fmt.number(open.count)
        tile.inline = Fmt.plural(open.count, tr("devoir à rendre"), tr("devoirs à rendre"))
        return tile
    }

    static func average(_ state: StudentState) -> Tile {
        guard let overall = StudentMath.overallAverage(state) else {
            return .empty(tr("Moyenne"), symbol: "graduationcap", message: tr("Ajoute tes notes dans Tessera, espace Études."))
        }
        var tile = Tile(title: tr("Moyenne"), symbol: "graduationcap")
        tile.value = TF.decimal(overall, 1)
        tile.unit = "%"
        tile.caption = tr("moyenne générale pondérée")
        tile.rows = state.courses.compactMap { course -> TileRow? in
            guard let average = StudentMath.courseAverage(state, course: course.id) else { return nil }
            return TileRow(id: course.id.uuidString, title: course.name, value: "\(TF.decimal(average, 1)) %", colorHex: course.colorHex, progress: average / 100)
        }
        tile.visual = .ring(overall / 100)
        tile.gauge = overall / 100
        tile.inline = tr("Moyenne \(TF.decimal(overall, 1)) %")
        return tile
    }

    static func semester(_ state: StudentState, now: Date) -> Tile {
        guard let progress = StudentMath.semesterProgress(state, at: now), let end = state.semesterEnd else {
            return .empty(tr("Session"), symbol: "calendar.badge.clock", message: tr("Indique les dates de ta session dans Tessera, espace Études."))
        }
        let left = max(0, DateMath.daysBetween(now, end))
        var tile = Tile(title: tr("Session"), symbol: "calendar.badge.clock")
        tile.value = Fmt.percent(progress)
        tile.caption = tr("\(left) \(TF.days(left)) restants")
        tile.detail = tr("Fin le \(Fmt.format(end, template: "dMMMM"))")
        tile.visual = .bar(progress)
        tile.gauge = progress
        tile.shortValue = Fmt.percent(progress)
        tile.inline = tr("Session \(Fmt.percent(progress)) · \(left) j")
        return tile
    }

    static func flashcard(_ state: StudentState, now: Date) -> Tile {
        guard !state.cards.isEmpty else {
            return .empty(tr("Fiches"), symbol: "rectangle.on.rectangle.angled", message: tr("Crée tes fiches de révision dans Tessera, espace Études."))
        }
        guard let card = StudentMath.dueCard(state, at: now) else {
            var tile = Tile(title: tr("Fiches"), symbol: "checkmark.seal")
            tile.value = tr("À jour")
            tile.caption = tr("Aucune fiche à réviser pour l'instant")
            if let next = state.cards.map(\.due).min() {
                tile.detail = tr("Prochaine révision \(TF.relativeTime(next, from: now))")
            }
            return tile
        }
        let due = StudentMath.dueCount(state, at: now)
        var tile = Tile(title: card.deck, symbol: "rectangle.on.rectangle.angled")
        tile.value = card.front
        if state.isCardRevealed {
            tile.caption = card.back
            tile.buttons = [
                TileButton(title: tr("À revoir"), symbol: "arrow.counterclockwise", action: .gradeCard(false)),
                TileButton(title: tr("Je savais"), symbol: "checkmark", action: .gradeCard(true), isProminent: true),
            ]
        } else {
            tile.caption = tr("Touche « Réponse » pour vérifier")
            tile.buttons = [TileButton(title: tr("Réponse"), symbol: "eye", action: .revealCard, isProminent: true)]
        }
        tile.detail = Fmt.plural(due, tr("fiche à réviser"), tr("fiches à réviser"))
        tile.inline = tr("\(due) fiches à réviser")
        return tile
    }

    static func studyHours(_ state: StudentState, now: Date) -> Tile {
        let minutes = StudentMath.studyMinutes(state, weekOf: now)
        let goal = max(0.5, state.weeklyStudyGoalHours)
        var tile = Tile(title: tr("Heures d'étude"), symbol: "clock.badge.checkmark")
        tile.value = Fmt.minutes(minutes)
        tile.caption = tr("sur \(Fmt.hours(goal)) cette semaine")
        tile.visual = .bars(StudentMath.studyByDay(state, weekOf: now), labels: TF.weekdayLetters(), highlight: TF.todayIndex(now))
        tile.gauge = min(1, minutes / 60 / goal)
        tile.detail = tr("\(Fmt.percent(min(9.99, minutes / 60 / goal))) de l'objectif")
        tile.inline = tr("Étude \(Fmt.minutes(minutes))")
        return tile
    }

    static func timetable(_ state: StudentState, context: RenderContext) -> Tile {
        let now = context.date
        var day = now
        var classes = StudentMath.occurrences(state, on: now)
        if classes.allSatisfy({ $0.end < now }) {
            for offset in 1..<8 {
                guard let next = DateMath.calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                let found = StudentMath.occurrences(state, on: next)
                if !found.isEmpty { classes = found; day = next; break }
            }
        }
        guard !classes.isEmpty else { return .empty(tr("Horaire"), symbol: "list.bullet.rectangle.portrait", message: hint) }
        let isToday = DateMath.isSameDay(day, now)
        var tile = Tile(title: isToday ? tr("Horaire du jour") : tr("Horaire · \(Fmt.weekday(day))"), symbol: "list.bullet.rectangle.portrait")
        tile.value = Fmt.number(classes.count)
        tile.unit = classes.count > 1 ? tr("cours") : tr("cours", context: "one")
        tile.caption = "\(TF.time(classes[0].start, context)) – \(TF.time(classes[classes.count - 1].end, context))"
        tile.rows = classes.map { item in
            TileRow(
                id: item.slot.id.uuidString,
                title: courseName(state, item.slot.courseID),
                value: TF.time(item.start, context),
                detail: item.slot.room.isEmpty ? nil : tr("Salle \(item.slot.room)"),
                colorHex: state.course(item.slot.courseID)?.colorHex,
                isDone: nil,
                isHighlighted: isToday && item.start <= now && item.end > now
            )
        }
        tile.compactRows = true
        return tile
    }
}
