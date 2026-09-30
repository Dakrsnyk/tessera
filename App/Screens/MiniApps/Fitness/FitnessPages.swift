import Charts
import SwiftUI

// MARK: - Program

/// The week of training: which session each day, the sessions themselves, and the weekly goal.
struct FitnessProgramPage: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Routine?

    private var accentHex: String { MiniApp.fitness.colorHex }
    private let dayNames = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"]

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
                            Text("Crée d'abord une séance")
                        }
                    } label: {
                        HStack {
                            Text(dayNames[weekday - 1])
                                .foregroundStyle(Color.primary)
                                .frame(width: 100, alignment: .leading)
                            Text(planned.isEmpty ? "Repos" : planned.map(\.name).joined(separator: " + "))
                                .foregroundStyle(planned.isEmpty ? Color.secondary : Color(hex: accentHex))
                                .fontWeight(planned.isEmpty ? .regular : .semibold)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("program-day-\(weekday)")
                }
            } header: {
                Text("Ma semaine")
            } footer: {
                Text("Touche un jour pour lui donner une séance. Tessera te propose chaque jour celle qui est prévue.")
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
                            Text("\(Fmt.plural(routine.exercises.count, "exercice", "exercices")) · environ \(FitnessPlan.minutes(routine)) min")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    model.update(\.fitness) { $0.routines.remove(atOffsets: offsets) }
                }
                Button {
                    editing = Routine(name: "", exercises: [ExerciseTemplate(name: "", sets: 3, reps: 10, weight: 0)])
                } label: {
                    Label("Nouvelle séance", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("program-new")
            } header: {
                Text("Mes séances")
            }

            Section {
                Stepper(value: Binding(get: { state.weeklyGoal }, set: { model.setWeeklyWorkouts($0) }), in: 1...7) {
                    ValueRow(title: "Objectif", value: "\(state.weeklyGoal) séances / semaine")
                }
            }
        }
        .styledList()
        .tint(Color(hex: accentHex))
        .navigationTitle("Programme")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing) { routine in
            RoutineEditor(routine: routine)
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

    var body: some View {
        let sessions = FitnessMath.sessions(model.fitness).sorted { $0.start > $1.start }
        let months = Dictionary(grouping: sessions) { Fmt.monthYear($0.start) }
        let order = sessions.map { Fmt.monthYear($0.start) }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        List {
            if sessions.isEmpty {
                Text("Aucune séance pour l'instant. Commence celle du jour depuis Fitness : elle s'enregistre ici.")
                    .foregroundStyle(Color.secondary)
            }
            ForEach(order, id: \.self) { month in
                Section(month) {
                    ForEach(months[month] ?? []) { session in
                        NavigationLink(value: HomeRoute.page(.fitnessSessionDetail(session.id))) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(session.routineName).font(.headline)
                                    Spacer()
                                    Text(Fmt.shortDay(session.start)).font(.subheadline).foregroundStyle(Color.secondary)
                                }
                                Text("\(TF.int(session.duration / 60)) min · \(Fmt.plural(session.sets.count, "série", "séries")) · \(TF.int(session.volume)) kg")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
            }
        }
        .styledList()
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct FitnessSessionDetailPage: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var model
    @State private var editingSet: SetLog?
    @State private var info: ExerciseInfo?

    var body: some View {
        let session = FitnessMath.sessions(model.fitness).first { $0.id == sessionID }
        List {
            if let session {
                Section {
                    ValueRow(title: "Date", value: Fmt.longDay(session.start))
                    ValueRow(title: "Durée", value: "\(TF.int(session.duration / 60)) min")
                    ValueRow(title: "Volume", value: "\(TF.int(session.volume)) kg")
                }
                let names = session.sets.map(\.exercise).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                ForEach(names, id: \.self) { name in
                    Section {
                        ForEach(session.sets.filter { $0.exercise == name }) { set in
                            Button {
                                editingSet = set
                            } label: {
                                HStack {
                                    Text(set.weight > 0 ? "\(ProfileNumberField.format(set.weight)) kg × \(set.reps)" : "\(set.reps) répétitions")
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
                                Button {
                                    info = known
                                } label: {
                                    Image(systemName: "info.circle")
                                }
                                .textCase(nil)
                            }
                        }
                    }
                }
            } else {
                Text("Séance introuvable.").foregroundStyle(Color.secondary)
            }
        }
        .styledList()
        .navigationTitle(session?.routineName ?? "Séance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSet) { SetEditor(set: $0) }
        .sheet(item: $info) { ExerciseInfoSheet(exercise: $0) }
    }
}

// MARK: - Progress

/// Records and the exercises followed regularly; each one opens its sheet with its chart.
struct FitnessProgressPage: View {
    @Environment(AppModel.self) private var model

    private var accentHex: String { MiniApp.fitness.colorHex }

    var body: some View {
        let state = model.fitness
        let records = FitnessMath.records(state)
        let volumes = weeklyVolumes(state)
        MiniAppScroll {
            if records.isEmpty {
                EmptyStateView(symbol: "chart.line.uptrend.xyaxis", title: "Pas encore de progression", message: "Fais quelques séances : tes charges, ton volume et tes records apparaîtront ici.")
                    .card()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: "Volume par semaine")
                    Chart {
                        ForEach(volumes) { item in
                            BarMark(x: .value("Semaine", item.date, unit: .weekOfYear), y: .value("kg", item.value))
                                .foregroundStyle(Color(hex: accentHex).gradient)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 170)
                    .card()
                }
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: "Records")
                    MiniRowsCard {
                        ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                            let info = ExerciseLibrary.match(name: record.exercise)
                            Group {
                                if let info {
                                    NavigationLink(value: HomeRoute.page(.fitnessExercise(info.id))) {
                                        row(record, state: state)
                                    }
                                } else {
                                    row(record, state: state, chevron: false)
                                }
                            }
                            .buttonStyle(.plain)
                            if index < records.count - 1 { MiniDivider() }
                        }
                    }
                }
            }
        }
        .navigationTitle("Progression")
        .navigationBarTitleDisplayMode(.large)
    }

    private func row(_ record: FitnessMath.Record, state: FitnessState, chevron: Bool = true) -> some View {
        let sessions = FitnessMath.history(named: record.exercise, state)
        let first = sessions.first?.topWeight ?? record.weight
        let change = record.weight - first
        return MiniRow(symbol: "trophy.fill", colorHex: "F2A33A", title: record.exercise,
                       detail: sessions.count > 1 && change > 0 ? "+\(ProfileNumberField.format(change)) kg depuis le début · \(sessions.count) séances" : "\(sessions.count) séance\(sessions.count > 1 ? "s" : "")",
                       value: "\(ProfileNumberField.format(record.weight)) × \(record.reps)", showsChevron: chevron)
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

    private let tint = "12A4B5"

    var body: some View {
        MiniAppScroll {
            switch steps.status {
            case .allowed:
                let today = steps.today
                let count = today?.steps ?? steps.stepsToday ?? 0
                let goal = model.profile.stepGoal
                HStack(spacing: 10) {
                    MiniStat(title: "Pas", value: Fmt.number(count), detail: goal.map { "objectif \(Fmt.number($0))" }, colorHex: tint)
                    MiniStat(title: "Distance", value: today?.distance.map { TF.decimal($0 / 1_000, 1) } ?? "—", unit: "km")
                }
                HStack(spacing: 10) {
                    MiniStat(title: "Étages", value: today?.floors.map { "\($0)" } ?? "—")
                    MiniStat(title: "Calories actives", value: "~\(TF.int(StepCounter.estimatedCalories(steps: count, weightKg: model.profile.weightKg)))", unit: "kcal", detail: "estimées d'après les pas")
                }
                if !steps.week.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        MiniSectionTitle(title: "7 derniers jours", detail: "moyenne \(Fmt.number(steps.week.reduce(0) { $0 + $1.steps } / max(1, steps.week.count)))")
                        Chart {
                            ForEach(steps.week) { day in
                                BarMark(x: .value("Jour", day.date, unit: .day), y: .value("Pas", day.steps))
                                    .foregroundStyle(Color(hex: tint).gradient)
                                    .cornerRadius(3)
                            }
                            if let goal {
                                RuleMark(y: .value("Objectif", goal))
                                    .foregroundStyle(Color.secondary)
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
                        }
                        .frame(height: 180)
                        .card()
                    }
                }
                Text("L'objectif de pas se règle dans « Mes informations ». Pour le détail de tes calories, l'app Santé reste la référence.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .notAsked:
                EmptyStateView(symbol: "figure.walk", title: "Tes pas", message: "Tessera lit tes pas, ta distance et tes étages depuis le capteur de ton iPhone.", actionTitle: "Autoriser") {
                    Task {
                        await steps.refresh(asking: true)
                        await steps.refreshWeek()
                    }
                }
                .card()
            case .denied:
                EmptyStateView(symbol: "figure.walk", title: "Accès refusé", message: "Autorise « Mouvements et forme » pour Tessera dans les Réglages de l'iPhone pour voir tes pas.")
                    .card()
            case .unavailable:
                EmptyStateView(symbol: "figure.walk", title: "Pas disponible", message: "Cet appareil ne compte pas les pas.")
                    .card()
            }
        }
        .navigationTitle("Activité")
        .navigationBarTitleDisplayMode(.large)
        .task { await steps.refreshWeek() }
    }
}
