import SwiftUI

/// The Fitness mini-app in the « Signature » style, in the order a workout is prepared and done. On the band:
/// the week selector (the only one of the screen), then the session of the day picked as the essential figure
/// (today's or the next one, or what was done), with its one main action floating above the tab bar. On the
/// sheet, as in the mockup: the week's four figures (2 × 2 tiles), the session of the day (its details and
/// secondary actions), « Programme » (program, sessions done, exercises, progress), the favorite exercises and
/// the steps, and last the footnote and the settings button.
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

    private var accentHex: String { MiniApp.fitness.colorHex }

    private func readSteps() async {
        await steps.refresh(asking: true)
        await steps.refreshWeek()
    }

    var body: some View {
        let now = Date()
        let state = model.fitness
        let content = dayContent(state: state, now: now)
        MiniAppScaffold(colorHex: accentHex, action: floatingAction(content, state: state, now: now)) {
            weekSelector(state: state)
            dayHeader(content, state: state, now: now)
        } sheet: {
            MiniAppToFillSection(app: .fitness)
            weekSummary(state: state, now: now)
            if content.hasExtras {
                daySection(content, state: state, now: now)
            }
            program(state: state)
            favorites(state: state)
            activity
            MiniFootnote(text: tr("Calories et volumes estimés à partir de tes séances et de ton poids : des repères, pas des mesures."))
            MiniAppInfoSection(app: .fitness)
        }
        .navigationTitle(tr("Fitness"))
        .task { await steps.refreshWeek() }
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
            let active = state.active.flatMap { $0.isFinished ? nil : $0 }
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
            MiniHero(label: active.isCatchUp ? tr("Rattrapage en cours") : tr("Séance en cours"),
                     value: active.routineName, caption: runningCaption(active))
            ProgressView(value: Double(active.sets.count), total: Double(max(1, active.totalSets)))
                .tint(Color.primary)
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
            return MiniFloatingAction(title: tr("Reprendre la séance"), symbol: "play.fill", colorHex: accentHex, identifier: "fitness-resume") {
                router.homePath.append(.page(.fitnessSession))
            }
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
                    .foregroundStyle(Color(hex: accentHex))
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
                .foregroundStyle(Color(hex: accentHex))
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
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(tr("Supprimer la séance")))
        .accessibilityIdentifier("fitness-delete-session")
    }

    /// « Bench · série 2 sur 4 » for the session running.
    private func runningCaption(_ active: WorkoutSession) -> String? {
        guard let exercise = active.currentExercise else { return nil }
        return tr("\(exercise.name) · série \(active.setIndex + 1) sur \(exercise.sets)")
    }

    /// « 12 séries · 48 min · 3 200 kg soulevés » for the sessions of a day.
    private func sessionLine(_ sessions: [WorkoutSession]) -> String {
        let sets = sessions.reduce(0) { $0 + $1.sets.count }
        let minutes = sessions.reduce(0.0) { $0 + $1.duration } / 60
        let volume = sessions.reduce(0.0) { $0 + $1.volume }
        return tr("\(Fmt.plural(sets, tr("série"), tr("séries"))) · \(TF.int(minutes)) min · \(TF.int(volume)) kg soulevés")
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
                    Text(FitnessPlan.setText(exercise))
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
                MiniStat(title: tr("Volume"), value: TF.int(FitnessMath.weeklyVolume(state, weekOf: first).reduce(0, +)), unit: "kg")
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
                        RingView(progress: goal.map { Double(count) / Double(max(1, $0)) } ?? 0, lineWidth: 8, color: Color(hex: MiniStyle.stepsHex), track: Color(hex: MiniStyle.stepsHex).opacity(0.15))
                        Image(systemName: "figure.walk").font(.title3).foregroundStyle(Color(hex: MiniStyle.stepsHex))
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

    // MARK: Program

    /// « Programme »: the program, the sessions done, the exercises (library) and the progress, as rows.
    private func program(state: FitnessState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Programme"))
            MiniRowsCard {
                NavigationLink(value: HomeRoute.page(.fitnessProgram)) {
                    MiniRow(symbol: "dumbbell.fill", colorHex: accentHex, title: tr("Programme et séances"),
                            detail: state.routines.isEmpty ? tr("Tes séances de la semaine") : Fmt.plural(state.routines.count, tr("séance"), tr("séances")))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("fitness-program")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.fitnessHistory)) {
                    MiniRow(symbol: "clock.arrow.circlepath", colorHex: accentHex, title: tr("Séances faites"), detail: tr("Toutes tes séances"), value: FitnessMath.sessions(state).isEmpty ? nil : "\(FitnessMath.sessions(state).count)")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("fitness-history")
                MiniDivider()
                // Open to everyone (« Mes exercices » is free); every exercise in it is Premium.
                NavigationLink(value: HomeRoute.page(.fitnessLibrary)) {
                    premiumRow(symbol: "list.bullet", title: tr("Exercices"),
                               detail: tr("\(ExerciseLibrary.all.count) exercices, fiches et démonstrations"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("fitness-library")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.fitnessProgress)) {
                    premiumRow(symbol: "chart.bar.fill", title: tr("Progression"), detail: tr("Charges, volume, records et évolution"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("fitness-progress")
            }
        }
    }

    /// The favorite exercises (recent ones are not shown here), under their own title; nothing without favorites.
    @ViewBuilder
    private func favorites(state: FitnessState) -> some View {
        let quick = Array(state.favoriteExercises.compactMap(ExerciseLibrary.info).prefix(6))
        if !quick.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Exercices"))
                MiniRowsCard {
                    ForEach(Array(quick.enumerated()), id: \.element.id) { index, exercise in
                        if index > 0 {
                            MiniDivider()
                        }
                        NavigationLink(value: HomeRoute.page(.fitnessExercise(exercise.id))) {
                            premiumRow(symbol: "star.fill", title: exercise.name, detail: exercise.summary)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }

    /// A row of a Premium feature: the small Premium badge before the chevron while the person is not Premium.
    private func premiumRow(symbol: String, title: String, detail: String?) -> some View {
        HStack(spacing: 8) {
            MiniRow(symbol: symbol, colorHex: accentHex, title: title, detail: detail, showsChevron: false)
            if !model.isPremium {
                PremiumBadge(compact: true)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// How a routine reads and lasts.
enum FitnessPlan {
    /// "4 × 8 · 80 kg"
    static func setText(_ exercise: ExerciseTemplate) -> String {
        let load = exercise.weight > 0 ? tr(" · \(ProfileNumberField.format(exercise.weight)) kg") : ""
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
