import SwiftUI

/// The Fitness mini-app, « Hybride » direction: one page whose first card follows the moment (before, during, after
/// the session, or a rest day). On the band: the week selector (the only one of the screen), then the card of the
/// moment (today's session or the next one, the one running, or what was done). On the sheet: what is missing,
/// a fixed row of four round shortcuts (« Programme », « Exercices », « Historique », « Progression »), the week's
/// four figures (2 × 2 tiles), the session of the day (its details and secondary actions), the steps, and last
/// the footnote and the settings button. The action floating above the tab bar follows the moment: « Commencer »
/// before; « Série faite » with the rest beside it while a session runs; nothing after.
struct FitnessAppView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var editing: Routine?
    /// The day the band shows: today's session, or what was done or planned another day.
    @State private var day = Date()
    /// A session recorded by mistake, to delete once confirmed (it can then be done again).
    @State private var deleting: UUID?
    private var steps: StepCounter { .shared }
    /// The explanation before the Motion prompt of the system.
    @State private var asksMotion = false
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    private var accentHex: String { MiniApp.fitness.colorHex }

    private func readSteps() async {
        await steps.refresh(asking: true)
        await steps.refreshWeek()
    }

    var body: some View {
        let now = Date()
        let state = model.fitness
        let content = dayContent(state: state, now: now)
        let runningSession: WorkoutSession? = {
            if case .running(let active) = content { return active }
            return nil
        }()
        MiniAppScaffold(colorHex: accentHex, action: floatingAction(content, state: state, now: now)) {
            weekSelector(state: state)
            dayHeader(content, state: state, now: now)
        } sheet: {
            MiniAppToFillSection(app: .fitness)
            shortcuts(state: state)
            weekSummary(state: state, now: now)
            if content.hasExtras {
                daySection(content, state: state, now: now)
            }
            activity
            MiniFootnote(text: tr("Calories et volumes estimés à partir de tes séances et de ton poids : des repères, pas des mesures."))
            MiniAppInfoSection(app: .fitness)
            if runningSession != nil {
                // Room for the double action.
                Color.clear.frame(height: 80)
            }
        }
        .overlay(alignment: .bottom) {
            // While a session runs: « Série faite » and the rest, without leaving the page.
            if let runningSession {
                FitnessRunningActions(session: runningSession, colorHex: accentHex,
                                      setDone: { completeSetFromPage() },
                                      open: { router.homePath.append(.page(.fitnessSession)) })
                    .padding(.bottom, 12)
            }
        }
        .navigationTitle(tr("Fitness"))
        .task {
            // A session left behind (app killed, forgotten) is closed at its last set, not left « en cours ».
            if model.fitness.active?.isIdle(at: Date()) == true {
                model.update(\.fitness) { $0.closeIdleSession(at: Date()) }
            }
            await steps.refreshWeek()
        }
        .sheet(item: $editing) { routine in
            RoutineEditor(routine: routine)
        }
        .confirmsWorkoutDeletion($deleting)
        .permissionSheet(.motion, isPresented: $asksMotion, request: readSteps)
    }

    // MARK: The day picked

    /// What the day picked holds: today (a session running, done, planned, a rest day or no program yet) or
    /// another day (sessions done, one caught up, one planned, a rest day).
    private func dayContent(state: FitnessState, now: Date) -> FitnessDayContent {
        if DateMath.isSameDay(day, now) {
            let active = state.active.flatMap { $0.isFinished || $0.isIdle(at: now) ? nil : $0 }
            if let active, active.currentExercise != nil { return .running(active) }
            if let doneToday = FitnessMath.sessions(state).filter({ DateMath.isSameDay($0.start, now) && $0.isFinished }).last {
                return .done(doneToday)
            }
            if let routine = state.routines.first(where: { $0.weekdays.contains(FitnessMath.isoWeekday(now)) }) {
                return .planned(routine)
            }
            return state.routines.isEmpty ? .empty : .rest
        }
        let done = FitnessMath.sessions(state).filter { DateMath.isSameDay($0.start, day) && $0.isFinished }
        if !done.isEmpty { return .sessions(done) }
        let planned = state.routines.first { $0.weekdays.contains(FitnessMath.isoWeekday(day)) }
        guard let planned else { return .free }
        if let caughtUp = FitnessMath.catchUp(of: day, state) { return .caughtUp(planned, caughtUp) }
        return .upcoming(planned)
    }

    /// The essential figure on the band, without a card: the session of the day (or its state). The text takes
    /// the screen's color, so it reads on the band.
    private func dayHeader(_ content: FitnessDayContent, state: FitnessState, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            dayHero(content, state: state, now: now)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(DateMath.isSameDay(day, now) ? "fitness-today" : "fitness-day")
    }

    @ViewBuilder
    private func dayHero(_ content: FitnessDayContent, state: FitnessState, now: Date) -> some View {
        switch content {
        case .running(let active):
            // A tap on the card opens the session.
            Button {
                router.homePath.append(.page(.fitnessSession))
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    MiniHero(label: active.isCatchUp ? tr("Rattrapage en cours") : tr("Séance en cours"),
                             value: active.routineName, caption: runningCaption(active))
                    if let plan = runningPlan(active) {
                        Text(plan).font(.title3.weight(.semibold)).monospacedDigit()
                    }
                    ProgressView(value: Double(active.sets.count), total: Double(max(1, active.totalSets)))
                        .accessibilityLabel(tr("Progression"))
                        .accessibilityValue(tr("\(active.sets.count)/\(active.totalSets) séries"))
                        .tint(palette.fitnessText)
                    Text(tr("\(active.sets.count)/\(active.totalSets) séries"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fitness-resume-card")
        case .done(let session):
            MiniHero(label: session.isCatchUp ? tr("Séance rattrapée") : tr("Séance faite"),
                     value: session.routineName, caption: sessionLine([session]))
            if let missed = session.catchUpFor {
                catchUpNote(missed)
            }
        case .planned(let routine):
            MiniHero(label: tr("Séance du jour"), value: routine.name, caption: routineCaption(routine))
        case .rest:
            MiniHero(label: tr("Repos aujourd'hui"), value: tr("Repos"), caption: nextSessionText(state, now: now))
        case .empty:
            MiniHero(label: tr("Aujourd'hui"), value: tr("Ton programme"),
                     caption: tr("Crée tes séances (exercices, séries, charges, repos) et choisis leurs jours : Ardane te propose chaque jour la bonne."))
        case .sessions(let done):
            MiniHero(label: Fmt.plural(done.count, tr("séance faite"), tr("séances faites")),
                     value: done.map { $0.routineName }.joined(separator: ", "), caption: sessionLine(done))
            if done.count == 1, let missed = done[0].catchUpFor {
                catchUpNote(missed)
            }
        case .caughtUp(_, let caughtUp):
            MiniHero(label: tr("Séance rattrapée"), value: caughtUp.routineName,
                     caption: caughtUp.isFinished ? tr("Faite le \(Fmt.format(caughtUp.start, template: "EEEEdMMMM")) à la place.") : tr("Rattrapage en cours."))
        case .upcoming(let routine):
            MiniHero(label: day > now ? tr("Prévu") : tr("Prévu, pas fait"), value: routine.name,
                     caption: routineCaption(routine))
        case .free:
            MiniHero(label: Fmt.longDay(day), value: tr("Repos"),
                     caption: state.routines.isEmpty ? tr("Aucune séance ce jour-là.") : tr("Aucune séance prévue ce jour-là."))
        }
    }

    /// The one main action of the day, floating above the tab bar.
    private func floatingAction(_ content: FitnessDayContent, state: FitnessState, now: Date) -> MiniFloatingAction? {
        switch content {
        case .running:
            // The double action (« Série faite » and the rest) is drawn by `FitnessRunningActions`.
            return nil
        case .planned(let routine):
            return MiniFloatingAction(title: tr("Commencer"), symbol: "play.fill", colorHex: accentHex, identifier: "fitness-start") {
                start(routine)
            }
        case .rest:
            // Yesterday's session wasn't done: one tap to catch it up today.
            guard let missed = missedYesterday(state, now: now) else { return nil }
            return MiniFloatingAction(title: tr("Rattraper « \(missed.routine.name) » d'hier"), symbol: "arrow.uturn.forward", colorHex: accentHex, identifier: "fitness-catch-up") {
                start(missed.routine, catchingUp: missed.day)
            }
        case .empty:
            return MiniFloatingAction(title: tr("Créer une séance"), symbol: "plus", colorHex: accentHex, identifier: "fitness-create") {
                editing = Routine(name: "", exercises: [])
            }
        case .upcoming(let planned):
            // A session missed that day: done now instead, and marked as caught up.
            guard day < now, state.active.map({ $0.isFinished }) ?? true else { return nil }
            return MiniFloatingAction(title: tr("Rattraper la séance"), symbol: "arrow.uturn.forward", colorHex: accentHex, identifier: "fitness-catch-up") {
                let missed = day
                day = Date()
                start(planned, catchingUp: missed)
            }
        case .done, .sessions, .caughtUp, .free:
            return nil
        }
    }

    /// The details and secondary actions of the day, under its own title (« Séance du jour », or the date).
    private func daySection(_ content: FitnessDayContent, state: FitnessState, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: DateMath.isSameDay(day, now) ? tr("Séance du jour") : Fmt.longDay(day))
            dayExtras(content, state: state)
        }
    }

    /// The secondary actions and details of the day.
    @ViewBuilder
    private func dayExtras(_ content: FitnessDayContent, state: FitnessState) -> some View {
        switch content {
        case .done(let session):
            HStack {
                detailLink(session.id)
                Spacer()
                deleteMenu(session.id)
            }
        case .planned(let routine), .upcoming(let routine):
            exercisePreview(routine)
        case .rest:
            Menu {
                ForEach(state.routines) { routine in
                    Button(routine.name) { start(routine) }
                }
            } label: {
                Label(tr("Faire une séance quand même"), systemImage: "play.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityIdentifier("fitness-start-anyway")
        case .sessions(let done):
            if done.count == 1 {
                detailLink(done[0].id)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleting = done[0].id
                        } label: {
                            Label(tr("Supprimer la séance"), systemImage: "trash")
                        }
                    }
            } else {
                MiniRowsCard {
                    ForEach(Array(done.enumerated()), id: \.element.id) { index, session in
                        if index > 0 {
                            MiniDivider()
                        }
                        NavigationLink(value: HomeRoute.page(.fitnessSessionDetail(session.id))) {
                            MiniRow(symbol: "checkmark.seal.fill", colorHex: accentHex, title: session.routineName, detail: sessionLine([session]))
                        }
                        .buttonStyle(.pressable)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleting = session.id
                            } label: {
                                Label(tr("Supprimer la séance"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        case .caughtUp(let planned, let caughtUp):
            if caughtUp.isFinished {
                detailLink(caughtUp.id)
            } else if planned.id != caughtUp.routineID {
                exercisePreview(planned)
            }
        case .running, .empty, .free:
            EmptyView()
        }
    }

    private func detailLink(_ id: UUID) -> some View {
        NavigationLink(value: HomeRoute.page(.fitnessSessionDetail(id))) {
            Text(tr("Voir le détail"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
    }

    /// The small « … » of a session done: « Supprimer la séance » (confirmed), to do it again.
    private func deleteMenu(_ id: UUID) -> some View {
        Menu {
            Button(role: .destructive) {
                deleting = id
            } label: {
                Label(tr("Supprimer la séance"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 30)
                .tapAreaOutset(7)
        }
        .accessibilityLabel(Text(tr("Supprimer la séance")))
        .accessibilityIdentifier("fitness-delete-session")
    }

    /// « Bench · série 2 sur 4 » for the session running.
    private func runningCaption(_ active: WorkoutSession) -> String? {
        guard let exercise = active.currentExercise else { return nil }
        return tr("\(exercise.name) · série \(active.setIndex + 1) sur \(exercise.sets)")
    }

    /// « 10 × 60 kg »: what the set shown asks for (« Corps » for no load).
    private func runningPlan(_ active: WorkoutSession) -> String? {
        guard let exercise = active.currentExercise else { return nil }
        let load = exercise.weight > 0 ? Units.loadText(kilograms: exercise.weight, in: model.settings.unitSystem) : tr("Corps")
        return "\(exercise.reps) × \(load)"
    }

    /// « Série faite » from the page: the set as planned (the reps and load shown on the card), like the session's own.
    private func completeSetFromPage() {
        // The one-time offer of the rest alerts (notifications) lives in the session page: until it was made, the
        // first set is logged there, so that a person who only uses this page still gets the end-of-rest alert.
        if !RestAlertOffer.wasMade() {
            router.homePath.append(.page(.fitnessSession))
            return
        }
        var accepted = false
        model.update(\.fitness) { state in
            guard var session = state.active, session.currentExercise != nil else { return }
            _ = session.completeSet(at: Date())
            accepted = true
            state.active = session
            if let id = session.sets.last?.exerciseID { state.noteUsed(id) }
            if session.isFinished { state.finishActive(at: Date()) }
        }
        if accepted { Haptics.tap() }
    }

    /// « 12 séries · 48 min · 3 200 kg soulevés » for the sessions of a day.
    private func sessionLine(_ sessions: [WorkoutSession]) -> String {
        let sets = sessions.reduce(0) { $0 + $1.sets.count }
        let minutes = sessions.reduce(0.0) { $0 + $1.duration } / 60
        let volume = sessions.reduce(0.0) { $0 + $1.volume }
        return tr("\(Fmt.plural(sets, tr("série"), tr("séries"))) · \(TF.int(minutes)) min · \(Units.loadText(kilograms: volume, in: model.settings.unitSystem, digits: 0)) soulevés")
    }

    /// « 5 exercices · 18 séries · environ 45 min » for a session planned.
    private func routineCaption(_ routine: Routine) -> String {
        tr("\(Fmt.plural(routine.exercises.count, tr("exercice"), tr("exercices"))) · \(Fmt.plural(routine.exercises.reduce(0) { $0 + $1.sets }, tr("série"), tr("séries"))) · environ \(FitnessPlan.minutes(routine)) min")
    }

    /// « Prochaine séance : Haut du corps, demain » on a rest day.
    private func nextSessionText(_ state: FitnessState, now: Date) -> String? {
        guard let next = FitnessMath.nextPlanned(after: now, state) else { return nil }
        return tr("Prochaine séance : \(next.routine.name), \(dayText(next.day))")
    }

    /// The first exercises of a session planned, with their sets.
    private func exercisePreview(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(routine.exercises.prefix(4)) { exercise in
                HStack {
                    Text(exercise.name).font(.subheadline)
                    Spacer()
                    Text(FitnessPlan.setText(exercise, system: model.settings.unitSystem))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if routine.exercises.count > 4 {
                Text(tr("+ \(routine.exercises.count - 4) autres")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .miniCard()
    }

    /// The routine planned yesterday, when no session was done that day nor caught up since.
    private func missedYesterday(_ state: FitnessState, now: Date) -> (routine: Routine, day: Date)? {
        guard let yesterday = DateMath.calendar.date(byAdding: .day, value: -1, to: now),
              let planned = state.routines.first(where: { $0.weekdays.contains(FitnessMath.isoWeekday(yesterday)) }) else { return nil }
        let done = FitnessMath.sessions(state).contains { DateMath.isSameDay($0.start, yesterday) && $0.isFinished }
        return done || FitnessMath.catchUp(of: yesterday, state) != nil ? nil : (planned, yesterday)
    }

    /// « Rattrapage de la séance du mardi 6 octobre ».
    private func catchUpNote(_ missed: Date) -> some View {
        Label(tr("Rattrapage de la séance du \(Fmt.format(missed, template: "EEEEdMMMM"))"), systemImage: "arrow.uturn.forward")
            .font(.caption.weight(.semibold))
            .opacity(0.85)
    }

    /// Starts a routine now; `missedDay`: the day it was planned for, when it is caught up.
    private func start(_ routine: Routine, catchingUp missedDay: Date? = nil) {
        Haptics.success()
        model.update(\.fitness) { $0.startSession(routine, at: Date(), catchingUp: missedDay) }
        router.homePath.append(.page(.fitnessSession))
    }

    private func dayText(_ day: Date) -> String {
        if let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: Date()), DateMath.isSameDay(day, tomorrow) { return tr("demain") }
        return Fmt.weekday(day).lowercased()
    }

    // MARK: Week

    /// The week selector at the top: a tap on a day shows that day just below, a swipe changes week. A day
    /// is done (session finished), planned by the program, or caught up (missed, done another day).
    private func weekSelector(state: FitnessState) -> some View {
        WeekSelector(day: $day, colorHex: accentHex, allowsFuture: true,
                     mark: { date in
                         let trained = FitnessMath.sessions(state).contains { DateMath.isSameDay($0.start, date) && $0.isFinished }
                         let planned = state.routines.contains { $0.weekdays.contains(FitnessMath.isoWeekday(date)) }
                         let caughtUp = !trained && FitnessMath.catchUp(of: date, state)?.isFinished == true
                         return WeekDayMark(isDone: trained, isPlanned: planned, isCaughtUp: caughtUp)
                     })
    }

    /// The totals of the week of the day picked (« Cette semaine », « Semaine du … »): four tiles in a 2 × 2 grid,
    /// without a second selector.
    private func weekSummary(state: FitnessState, now: Date) -> some View {
        let first = DateMath.week(containing: day).first ?? day
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: WeekTitle.of(DateMath.week(containing: day), now: now))
            HStack(spacing: 10) {
                MiniStat(title: tr("Durée"), value: Fmt.minutes(FitnessMath.minutes(inWeekOf: first, state)))
                MiniStat(title: tr("Volume"), value: Units.loadNumber(kilograms: FitnessMath.weeklyVolume(state, weekOf: first).reduce(0, +), in: model.settings.unitSystem, digits: 0), unit: model.settings.unitSystem.weightUnit)
            }
            HStack(spacing: 10) {
                MiniStat(title: tr("Calories"), value: weekCalories(state, weekOf: first))
                MiniStat(title: tr("Séances"), value: "\(FitnessMath.workouts(inWeekOf: first, state)) / \(state.weeklyGoal)")
            }
        }
    }

    /// The week's active calories, with the weight of « Mes informations »; without it, no number (the screen
    /// keeps no weight of its own: the 70 kg default of the state is not the person's weight).
    private func weekCalories(_ state: FitnessState, weekOf day: Date) -> String {
        guard let weight = model.profile.weightKg else { return "—" }
        var weighed = state
        weighed.bodyWeightKg = weight
        return "≈ \(TF.int(FitnessMath.caloriesThisWeek(weighed, weekOf: day)))"
    }

    // MARK: Activity

    @ViewBuilder private var activity: some View {
        switch steps.status {
        case .allowed:
            let today = steps.today
            let count = today?.steps ?? steps.stepsToday ?? 0
            let goal = model.profile.stepGoal
            NavigationLink(value: HomeRoute.page(.fitnessActivity)) {
                HStack(spacing: 16) {
                    ZStack {
                        RingView(progress: goal.map { Double(count) / Double(max(1, $0)) } ?? 0, lineWidth: 8, color: palette.category(MiniStyle.stepsHex), track: palette.category(MiniStyle.stepsHex).opacity(0.15))
                        Image(systemName: "figure.walk").font(.title3).foregroundStyle(palette.category(MiniStyle.stepsHex))
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("\(Fmt.number(count)) pas")).font(.title3.weight(.bold)).monospacedDigit()
                        Text(activityDetail(today, goal: goal))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
                .card()
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("fitness-activity")
        case .notAsked:
            Button {
                // Explanation first (once); the system prompt follows « Continuer ».
                Task { _ = await AppPermission.motion.requestOrExplain(isPresented: $asksMotion, request: readSteps) }
            } label: {
                MiniRow(symbol: "figure.walk", colorHex: MiniStyle.stepsHex, title: tr("Afficher mes pas"), detail: tr("Pas, distance et étages, depuis le capteur de ton iPhone"))
                    .card(padding: 12)
            }
            .buttonStyle(.pressable)
        default:
            EmptyView()
        }
    }

    private func activityDetail(_ day: StepCounter.Day?, goal: Int?) -> String {
        var parts: [String] = []
        if let goal { parts.append(tr("objectif \(Fmt.number(goal))")) }
        if let distance = day?.distance { parts.append(tr("\(TF.decimal(distance / 1_000, 1)) km")) }
        if let floors = day?.floors, floors > 0 { parts.append(Fmt.plural(floors, tr("étage"), tr("étages"))) }
        return parts.isEmpty ? tr("Aujourd'hui") : parts.joined(separator: " · ")
    }

    // MARK: Shortcuts

    /// The fixed row of four round shortcuts under the card, always in the same place: « Programme », « Exercices »,
    /// « Historique », « Progression » (the favorites are one tap away, at the top of « Exercices »).
    private func shortcuts(state: FitnessState) -> some View {
        HStack(alignment: .top, spacing: 4) {
            shortcut(symbol: "dumbbell.fill", title: tr("Programme"), value: HomeRoute.page(.fitnessProgram), identifier: "fitness-program")
            // Open to everyone (« Mes exercices » is free); every exercise in it is Premium.
            shortcut(symbol: "list.bullet", title: tr("Exercices"), value: HomeRoute.page(.fitnessLibrary), identifier: "fitness-library", premium: true)
            shortcut(symbol: "clock.arrow.circlepath", title: tr("Historique"), value: HomeRoute.page(.fitnessHistory), identifier: "fitness-history")
            shortcut(symbol: "chart.bar.fill", title: tr("Progression"), value: HomeRoute.page(.fitnessProgress), identifier: "fitness-progress", premium: true)
        }
    }

    private func shortcut(symbol: String, title: String, value: HomeRoute, identifier: String, premium: Bool = false) -> some View {
        NavigationLink(value: value) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(palette.fitness.opacity(0.16))
                    Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(palette.fitnessText)
                }
                .frame(width: 56, height: 56)
                .overlay(alignment: .topTrailing) {
                    if premium && !model.isPremium {
                        PremiumBadge(compact: true).offset(x: 6, y: -4)
                    }
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
    }
}

/// The action floating while a session runs: « Série faite » (the set as planned) and, beside it, the rest with its
/// pause, or a way back to the session when no rest runs. Drawn like the other floating actions of the Cristal style.
private struct FitnessRunningActions: View {
    let session: WorkoutSession
    let colorHex: String
    let setDone: () -> Void
    let open: () -> Void
    @Environment(AppModel.self) private var model
    @State private var tapGuard = TapGuard()
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strong = CristalPalette.of(style.id).strongHex(colorHex)
        let hex = scheme == .dark ? strong.dark : strong.light
        HStack(spacing: 10) {
            Button {
                tapGuard.run(setDone)
            } label: {
                Label(tr("Série faite"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.readableInk(on: hex))
                    .padding(.horizontal, 22)
                    .frame(minHeight: 50)
                    .background(Color(hex: hex), in: Capsule())
                    .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("fitness-set-done")
            side
        }
    }

    /// The rest (counting down, with its pause or resume), or a way back to the session.
    @ViewBuilder private var side: some View {
        if let rest = session.restEndsAt {
            HStack(spacing: 4) {
                TimelineView(.periodic(from: Date(), by: 1)) { context in
                    Group {
                        if rest > context.date {
                            Label {
                                Text(timerInterval: context.date...rest, countsDown: true).monospacedDigit()
                            } icon: {
                                Image(systemName: "hourglass")
                            }
                        } else {
                            Label(tr("Prêt"), systemImage: "checkmark.circle")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                }
                Button {
                    model.update(\.fitness) { $0.pauseRest(at: Date()) }
                } label: {
                    Image(systemName: "pause.fill")
                        .foregroundStyle(Color.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tr("Mettre le repos en pause")))
                .accessibilityIdentifier("fitness-rest-pause")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .frame(minHeight: 50)
            .cristalGlass(in: Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
        } else if let paused = session.restPausedRemaining {
            HStack(spacing: 4) {
                Label(Duration.seconds(paused).formatted(.time(pattern: .minuteSecond)), systemImage: "pause.circle")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .monospacedDigit()
                Button {
                    model.update(\.fitness) { $0.resumeRest(at: Date()) }
                } label: {
                    Image(systemName: "play.fill")
                        .foregroundStyle(Color.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tr("Reprendre")))
                .accessibilityIdentifier("fitness-rest-resume")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .frame(minHeight: 50)
            .cristalGlass(in: Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
        } else {
            Button {
                tapGuard.run(open)
            } label: {
                Label(tr("Séance"), systemImage: "arrow.right")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 50)
                    .cristalGlass(in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("fitness-resume")
        }
    }
}

extension CristalPalette {
    /// La couleur de Fitness traduite en Cristal : `fitness` pour une pastille, un graphique, un fond ;
    /// `fitnessText` pour du texte dans cette couleur.
    var fitness: Color { category(MiniApp.fitness.colorHex) }
    var fitnessText: Color { strong(MiniApp.fitness.colorHex) }
}

/// How a routine reads and lasts.
enum FitnessPlan {
    /// "4 × 8 · 80 kg"
    static func setText(_ exercise: ExerciseTemplate, system: UnitSystem = .metric) -> String {
        let load = exercise.weight > 0 ? tr(" · \(Units.loadText(kilograms: exercise.weight, in: system))") : ""
        return "\(exercise.sets) × \(exercise.reps)\(load)"
    }

    /// About 40 s a set plus the rest.
    static func minutes(_ routine: Routine) -> Int {
        let seconds = routine.exercises.reduce(0) { $0 + $1.sets * (40 + $1.restSeconds) }
        return max(5, Int((Double(seconds) / 60).rounded()))
    }
}

/// What the day picked on the Fitness screen holds.
private enum FitnessDayContent {
    /// Today: a session running, one done, one planned, a rest day, no program yet.
    case running(WorkoutSession), done(WorkoutSession), planned(Routine), rest, empty
    /// Another day: sessions done, the session planned (and the one that caught it up), a rest day.
    case sessions([WorkoutSession]), caughtUp(Routine, WorkoutSession), upcoming(Routine), free

    /// Whether the sheet has something to show for the day, above the week's totals.
    var hasExtras: Bool {
        switch self {
        case .running, .empty, .free: return false
        case .done, .rest, .sessions: return true
        case .planned(let routine), .upcoming(let routine): return !routine.exercises.isEmpty
        case .caughtUp(let planned, let caughtUp): return caughtUp.isFinished || planned.id != caughtUp.routineID
        }
    }
}
