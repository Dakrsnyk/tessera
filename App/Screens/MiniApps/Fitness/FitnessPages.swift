import Charts
import SwiftUI

// MARK: - Program

/// The week of training: which session each day, the sessions themselves, and the weekly goal.
struct FitnessProgramPage: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Routine?
    /// Sessions of the program swiped to delete, once confirmed.
    @State private var deletingRoutines: [UUID] = []
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    private var accentHex: String { MiniApp.fitness.colorHex }
    private let dayNames = [tr("Lundi"), tr("Mardi"), tr("Mercredi"), tr("Jeudi"), tr("Vendredi"), tr("Samedi"), tr("Dimanche")]

    var body: some View {
        let state = model.fitness
        List {
            Section {
                ForEach(1...7, id: \.self) { weekday in
                    let planned = state.routines.filter { $0.weekdays.contains(weekday) }
                    Menu {
                        ForEach(state.routines) { routine in
                            Button {
                                toggle(routine.id, weekday)
                            } label: {
                                if routine.weekdays.contains(weekday) {
                                    Label(routine.name, systemImage: "checkmark")
                                } else {
                                    Text(routine.name)
                                }
                            }
                        }
                        if state.routines.isEmpty {
                            Text(tr("Crée d'abord une séance"))
                        }
                    } label: {
                        HStack {
                            Text(dayNames[weekday - 1])
                                .foregroundStyle(Color.primary)
                                .frame(width: 100, alignment: .leading)
                            Text(planned.isEmpty ? tr("Repos") : planned.map(\.name).joined(separator: " + "))
                                .foregroundStyle(planned.isEmpty ? Color.secondary : palette.fitnessText)
                                .fontWeight(planned.isEmpty ? .regular : .semibold)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("program-day-\(weekday)")
                }
            } header: {
                Text(tr("Ma semaine"))
            } footer: {
                Text(tr("Touche un jour pour lui donner une séance. Ardane te propose chaque jour celle qui est prévue."))
            }

            Section {
                ForEach(state.routines) { routine in
                    Button {
                        editing = routine
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(routine.name).font(.headline).foregroundStyle(Color.primary)
                            Text(routine.exercises.map(\.name).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(2)
                            Text(tr("\(Fmt.plural(routine.exercises.count, tr("exercice"), tr("exercices"))) · environ \(FitnessPlan.minutes(routine)) min"))
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    deletingRoutines = offsets.compactMap { state.routines[safe: $0]?.id }
                }
                Button {
                    editing = Routine(name: "", exercises: [ExerciseTemplate(name: "", sets: 3, reps: 10, weight: 0)])
                } label: {
                    Label(tr("Nouvelle séance"), systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("program-new")
                // A session without a plan: the session page offers « Séance libre » (exercises added as you go).
                NavigationLink(value: HomeRoute.page(.fitnessSession)) {
                    Label(tr("Séance libre"), systemImage: "sparkles")
                }
                .accessibilityIdentifier("program-free")
            } header: {
                Text(tr("Mes séances"))
            }

            Section {
                Stepper(value: Binding(get: { state.weeklyGoal }, set: { model.setWeeklyWorkouts($0) }), in: 1...7) {
                    ValueRow(title: tr("Objectif"), value: tr("\(state.weeklyGoal) séances / semaine"))
                }
            }
        }
        .styledList()
        .tint(palette.fitnessText)
        .navigationTitle(tr("Programme"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing) { routine in
            RoutineEditor(routine: routine)
        }
        .confirmationDialog(tr("Supprimer cette séance du programme ?"), isPresented: Binding(get: { !deletingRoutines.isEmpty }, set: { if !$0 { deletingRoutines = [] } }), titleVisibility: .visible) {
            Button(tr("Supprimer"), role: .destructive) {
                let ids = deletingRoutines
                model.update(\.fitness) { $0.routines.removeAll { ids.contains($0.id) } }
                deletingRoutines = []
            }
        } message: {
            Text(tr("Les séances déjà faites restent dans l'historique."))
        }
    }

    private func toggle(_ routineID: UUID, _ weekday: Int) {
        model.update(\.fitness) { state in
            guard let index = state.routines.firstIndex(where: { $0.id == routineID }) else { return }
            if state.routines[index].weekdays.contains(weekday) {
                state.routines[index].weekdays.removeAll { $0 == weekday }
            } else {
                state.routines[index].weekdays.append(weekday)
                state.routines[index].weekdays.sort()
            }
        }
        Haptics.tap()
    }
}

// MARK: - History

struct FitnessHistoryPage: View {
    @Environment(AppModel.self) private var model
    /// The session to delete, once confirmed.
    @State private var deleting: UUID?
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let sessions = FitnessMath.sessions(model.fitness).sorted { $0.start > $1.start }
        let months = Dictionary(grouping: sessions) { Fmt.monthYear($0.start) }
        let order = sessions.map { Fmt.monthYear($0.start) }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        List {
            if sessions.isEmpty {
                Text(tr("Aucune séance pour l'instant. Commence celle du jour depuis Fitness : elle s'enregistre ici."))
                    .foregroundStyle(Color.secondary)
            } else {
                // The total of the sessions done (it was on the main page before the hybrid layout).
                Text(Fmt.plural(sessions.count, tr("séance faite"), tr("séances faites")))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityIdentifier("history-total")
            }
            ForEach(order, id: \.self) { month in
                Section(month) {
                    ForEach(months[month] ?? []) { session in
                        NavigationLink(value: HomeRoute.page(.fitnessSessionDetail(session.id))) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(session.routineName).font(.headline)
                                    if session.isCatchUp {
                                        Label(tr("Rattrapée"), systemImage: "arrow.uturn.forward")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(palette.fitnessText)
                                    }
                                    Spacer()
                                    Text(Fmt.shortDay(session.start)).font(.subheadline).foregroundStyle(Color.secondary)
                                }
                                Text(tr("\(TF.int(session.duration / 60)) min · \(Fmt.plural(session.sets.count, tr("série"), tr("séries"))) · \(Units.loadText(kilograms: session.volume, in: model.settings.unitSystem, digits: 0))"))
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                deleting = session.id
                            } label: {
                                Label(tr("Supprimer"), systemImage: "trash")
                            }
                        }
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
        }
        .styledList()
        .navigationTitle(tr("Historique"))
        .navigationBarTitleDisplayMode(.large)
        .confirmsWorkoutDeletion($deleting)
    }
}

struct FitnessSessionDetailPage: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var model
    @State private var editingSet: SetLog?
    @State private var info: ExerciseInfo?
    @State private var paywall: PaywallContext?
    @State private var deleting: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let session = FitnessMath.sessions(model.fitness).first { $0.id == sessionID }
        List {
            if let session {
                Section {
                    ValueRow(title: tr("Date"), value: Fmt.longDay(session.start))
                    if let missed = session.catchUpFor {
                        ValueRow(title: tr("Séance rattrapée"), value: tr("Prévue le \(Fmt.format(missed, template: "EEEEdMMMM"))"))
                    }
                    ValueRow(title: tr("Durée"), value: tr("\(TF.int(session.duration / 60)) min"))
                    ValueRow(title: tr("Volume"), value: Units.loadText(kilograms: session.volume, in: model.settings.unitSystem, digits: 0))
                }
                let names = session.sets.map(\.exercise).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                ForEach(names, id: \.self) { name in
                    Section {
                        ForEach(session.sets.filter { $0.exercise == name }) { set in
                            Button {
                                editingSet = set
                            } label: {
                                HStack {
                                    Text(set.weight > 0 ? tr("\(Units.loadText(kilograms: set.weight, in: model.settings.unitSystem)) × \(set.reps)") : tr("\(set.reps) répétitions"))
                                        .foregroundStyle(Color.primary)
                                        .monospacedDigit()
                                    Spacer()
                                    Text(Fmt.time(set.date, uses24Hour: true)).font(.caption).foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(name)
                            Spacer()
                            if let known = ExerciseLibrary.match(name: name) {
                                // The exercise sheet and its data are Premium; the sets of this session stay free.
                                let isOpen = model.canOpenExercise(known.id)
                                Button {
                                    if isOpen { info = known } else { paywall = .exerciseLibrary }
                                } label: {
                                    if isOpen {
                                        Image(systemName: "info.circle")
                                    } else {
                                        PremiumBadge(compact: true)
                                    }
                                }
                                .textCase(nil)
                                .accessibilityLabel(Text(isOpen ? tr("Fiche de \(name)") : tr("\(name), Premium")))
                            }
                        }
                    }
                }
                // Recorded by mistake: it goes away as if never done.
                Section {
                    Button(role: .destructive) {
                        deleting = session.id
                    } label: {
                        Label(tr("Supprimer la séance"), systemImage: "trash")
                    }
                    .accessibilityIdentifier("session-delete")
                }
            } else {
                Text(tr("Séance introuvable.")).foregroundStyle(Color.secondary)
            }
        }
        .styledList()
        .navigationTitle(session?.routineName ?? tr("Séance"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmsWorkoutDeletion($deleting) { dismiss() }
        .sheet(item: $editingSet) { SetEditor(set: $0) }
        .sheet(item: $info) { ExerciseInfoSheet(exercise: $0) }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }
}

// MARK: - Progress

/// The volume over the weeks, then the exercises done filed by category (chest, back, legs...); a
/// category opens the exercises of it with their demonstration sheet and personal numbers. Premium.
struct FitnessProgressPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    var body: some View {
        let state = model.fitness
        let groups = FitnessProgressCategories.groups(state)
        let volumes = weeklyVolumes(state)
        MiniAppScroll {
            if !model.isPremium {
                // The records, their evolution and the volume over weeks are Premium; the sessions stay recorded.
                PremiumLockCard(symbol: "chart.line.uptrend.xyaxis", title: tr("La progression est dans Premium"),
                                message: tr("Ton volume semaine après semaine, l'évolution de tes charges et tous tes records, exercice par exercice. Tes séances restent enregistrées : tout s'affiche dès que tu passes à Premium."))
            } else if groups.isEmpty {
                EmptyStateView(symbol: "chart.line.uptrend.xyaxis", title: tr("Pas encore de progression"), message: tr("Fais quelques séances : tes charges, ton volume et tes records apparaîtront ici."))
                    .card()
            } else {
                VStack(alignment: .leading, spacing: 22) {
                    let streak = FitnessMath.weekStreak(state, until: Date())
                    if streak >= 1 {
                        Label(Fmt.plural(streak, tr("semaine de suite à l'objectif"), tr("semaines de suite à l'objectif")), systemImage: "flame.fill")
                            .font(.headline)
                            .foregroundStyle(palette.fitnessText)
                            .accessibilityIdentifier("progress-streak")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        MiniSectionTitle(title: tr("Volume par semaine"))
                        Chart {
                            ForEach(volumes) { item in
                                BarMark(x: .value("Semaine", item.date, unit: .weekOfYear), y: .value(model.settings.unitSystem.weightUnit, Units.weightValue(kilograms: item.value, in: model.settings.unitSystem)))
                                    .foregroundStyle(palette.fitness.gradient)
                                    .cornerRadius(3)
                            }
                        }
                        .accessibilityLabel(tr("Volume par semaine"))
                        .frame(height: 170)
                        .card()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        MiniSectionTitle(title: tr("Par catégorie"))
                        MiniRowsCard {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                NavigationLink(value: HomeRoute.page(.fitnessProgressCategory(group.category.rawValue))) {
                                    categoryRow(group)
                                }
                                .buttonStyle(.pressable)
                                .accessibilityIdentifier("progress-category-\(group.category.rawValue)")
                                if index < groups.count - 1 { MiniDivider() }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(tr("Progression"))
        .navigationBarTitleDisplayMode(.large)
    }

    /// A category: its name, how many exercises it holds and the best record of them (the most practised one).
    private func categoryRow(_ group: ProgressCategoryGroup) -> some View {
        let system = model.settings.unitSystem
        let top = group.exercises.first
        return MiniRow(symbol: group.category.symbol, colorHex: MiniApp.fitness.colorHex, title: group.category.title,
                       detail: Fmt.plural(group.exercises.count, tr("exercice"), tr("exercices")),
                       value: top.map { $0.bestText(in: system) })
    }

    /// Volume of the last eight weeks, oldest first.
    private func weeklyVolumes(_ state: FitnessState) -> [DayValue] {
        (0..<8).reversed().compactMap { offset in
            guard let date = DateMath.calendar.date(byAdding: .weekOfYear, value: -offset, to: Date()),
                  let start = DateMath.calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return nil }
            return DayValue(date: start, value: FitnessMath.weeklyVolume(state, weekOf: date).reduce(0, +))
        }
    }
}

// MARK: - Activity

/// Steps, distance and floors from the iPhone's motion sensor (no Health access needed).
struct FitnessActivityPage: View {
    @Environment(AppModel.self) private var model
    private var steps: StepCounter { .shared }
    /// The day shown: today, or any day before (each day read is kept with its date).
    @State private var day = Date()
    @State private var dayData: StepCounter.Day?
    @State private var asksMotion = false
    @Environment(\.openURL) private var openURL
    @Environment(\.appStyle) private var style
    private var palette: CristalPalette { CristalPalette.of(style.id) }

    private let tint = "12A4B5"

    /// The first read of the steps: the only moment the Motion prompt of the system can appear.
    private func readSteps() async {
        await steps.refresh(asking: true)
        await steps.refreshWeek()
    }

    var body: some View {
        let isToday = DateMath.isSameDay(day, Date())
        MiniAppScroll {
            switch steps.status {
            case .allowed:
                DaySwitcher(day: $day, colorHex: tint)
                let today = isToday ? steps.today : dayData
                let count = today?.steps ?? (isToday ? steps.stepsToday ?? 0 : 0)
                if !isToday && dayData == nil {
                    Text(tr("Pas de données de pas pour ce jour : l'iPhone garde environ une semaine, Ardane garde ensuite chaque jour lu."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                let goal = model.profile.stepGoal
                HStack(spacing: 10) {
                    MiniStat(title: tr("Pas"), value: Fmt.number(count), detail: goal.map { tr("objectif \(Fmt.number($0))") }, colorHex: tint)
                    MiniStat(title: tr("Distance"), value: today?.distance.map { TF.decimal($0 / 1_000, 1) } ?? "—", unit: tr("km"))
                }
                HStack(spacing: 10) {
                    MiniStat(title: tr("Étages"), value: today?.floors.map { "\($0)" } ?? "—")
                    // The minutes of the day's workouts are counted by the workout, not again by the steps.
                    let sessionMinutes = CalorieModel.minutes(of: FitnessMath.sessions(model.fitness), on: day)
                    if let kcal = StepCounter.estimatedCalories(steps: count, weightKg: model.profile.weightKg, minutesInSessions: sessionMinutes) {
                        MiniStat(title: tr("Calories actives"), value: "~\(TF.int(kcal))", unit: "kcal", detail: sessionMinutes > 0 ? tr("estimées d'après les pas, hors séance") : tr("estimées d'après les pas"))
                    } else {
                        MiniStat(title: tr("Calories actives"), value: "—", detail: tr("ajoute ton poids dans « Mes informations »"))
                    }
                }
                if !steps.week.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        MiniSectionTitle(title: tr("7 derniers jours"), detail: tr("moyenne \(Fmt.number(steps.week.reduce(0) { $0 + $1.steps } / max(1, steps.week.count)))"))
                        Chart {
                            ForEach(steps.week) { day in
                                BarMark(x: .value("Jour", day.date, unit: .day), y: .value("Pas", day.steps))
                                    .foregroundStyle(palette.category(tint).gradient)
                                    .cornerRadius(3)
                            }
                            if let goal {
                                RuleMark(y: .value("Objectif", goal))
                                    .foregroundStyle(Color.secondary)
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                        }
                        .accessibilityLabel(tr("7 derniers jours"))
                        .frame(height: 180)
                        .card()
                    }
                }
                Text(tr("L'objectif de pas se règle dans « Mes informations ». Pour le détail de tes calories, l'app Santé reste la référence."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .notAsked:
                EmptyStateView(symbol: "figure.walk", title: tr("Tes pas"), message: tr("Ardane lit tes pas, ta distance et tes étages depuis le capteur de ton iPhone."), actionTitle: tr("Autoriser")) {
                    // The explanation sheet comes first (once); the system prompt follows « Continuer ».
                    Task { _ = await AppPermission.motion.requestOrExplain(isPresented: $asksMotion, request: readSteps) }
                }
                .card()
            case .denied:
                EmptyStateView(symbol: "figure.walk", title: tr("Accès refusé"), message: tr("Autorise « Mouvements et forme » pour Ardane dans les Réglages de l'iPhone pour voir tes pas."), actionTitle: tr("Ouvrir Réglages")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .card()
            case .unavailable:
                EmptyStateView(symbol: "figure.walk", title: tr("Pas disponible"), message: tr("Cet appareil ne compte pas les pas."))
                    .card()
            }
        }
        .navigationTitle(tr("Activité"))
        .navigationBarTitleDisplayMode(.large)
        .permissionSheet(.motion, isPresented: $asksMotion, request: readSteps)
        .task { await steps.refreshWeek() }
        .task(id: day) {
            if DateMath.isSameDay(day, Date()) {
                dayData = nil
            } else {
                dayData = await steps.day(day)
            }
        }
    }
}

// MARK: - Deleting a session

/// « Supprimer la séance »: a session recorded by mistake goes away as if never done (week, streak,
/// records, calories, « Séance faite »), so the day's routine can be started again. Always confirmed.
private struct WorkoutDeletion: ViewModifier {
    @Binding var sessionID: UUID?
    let onDeleted: () -> Void
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.confirmationDialog(tr("Supprimer cette séance ? Elle ne sera plus comptée et tu pourras la refaire."),
                                   isPresented: Binding(get: { sessionID != nil }, set: { if !$0 { sessionID = nil } }),
                                   titleVisibility: .visible, presenting: sessionID) { id in
            Button(tr("Supprimer la séance"), role: .destructive) {
                model.update(\.fitness) { _ = $0.deleteSession(id: id) }
                Haptics.tap()
                sessionID = nil
                onDeleted()
            }
        }
    }
}

extension View {
    /// Asks before deleting the session whose id is set, then calls `onDeleted`.
    func confirmsWorkoutDeletion(_ sessionID: Binding<UUID?>, onDeleted: @escaping () -> Void = {}) -> some View {
        modifier(WorkoutDeletion(sessionID: sessionID, onDeleted: onDeleted))
    }
}
