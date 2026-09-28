import SwiftUI

struct FitnessSpaceSections: View {
    @Environment(AppModel.self) private var model
    @State private var editingRoutine: Routine?

    var body: some View {
        let now = Date()
        let state = model.fitness
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        Section {
            if let active, let exercise = active.currentExercise {
                VStack(alignment: .leading, spacing: 8) {
                    Text(active.routineName).font(.caption.weight(.semibold)).foregroundStyle(Color.secondary)
                    Text(exercise.name).font(.title3.weight(.semibold))
                    Text("Série \(active.setIndex + 1)/\(exercise.sets) · \(FitnessTiles.setText(exercise))")
                        .foregroundStyle(Color.secondary)
                    if let rest = active.restEndsAt, rest > now {
                        HStack {
                            Image(systemName: "timer")
                            Text("Repos : ")
                            Text(timerInterval: now...rest, countsDown: true).monospacedDigit()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(hex: "E5484D"))
                    }
                    ProgressView(value: Double(active.sets.count), total: Double(max(1, active.totalSets)))
                        .tint(Color(hex: "E5484D"))
                }
                .padding(.vertical, 4)
                Button {
                    Haptics.success()
                    model.update(\.fitness) { $0.completeNextSet(at: Date()) }
                } label: {
                    Label("Série faite", systemImage: "checkmark.circle.fill").font(.headline)
                }
                Button("Terminer la séance", role: .destructive) {
                    model.update(\.fitness) { $0.finishActive(at: Date()) }
                }
            } else if let routine = state.routine(for: now) {
                ValueRow(title: routine.name, value: state.isScheduled(now) ? "Prévue aujourd'hui" : "Prochaine séance", symbol: "figure.strengthtraining.traditional")
                Button {
                    model.update(\.fitness) { $0.startSession(routine, at: Date()) }
                } label: {
                    Label("Commencer la séance", systemImage: "play.fill").font(.headline)
                }
            } else {
                HintRow(text: "Crée ta première séance : ses exercices, séries, charges et temps de repos. Le widget Prochaine série la suit ensuite depuis l'écran d'accueil.")
            }
        } header: {
            Text("Séance")
        }
        .sheet(item: $editingRoutine) { routine in
            RoutineEditor(routine: routine)
        }

        Section("Mes séances") {
            ForEach(state.routines) { routine in
                Button {
                    editingRoutine = routine
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.name).foregroundStyle(Color.primary)
                        Text("\(Fmt.plural(routine.exercises.count, "exercice", "exercices")) · \(weekdays(routine.weekdays))")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .onDelete { offsets in
                model.update(\.fitness) { $0.routines.remove(atOffsets: offsets) }
            }
            Button {
                editingRoutine = Routine(name: "", exercises: [ExerciseTemplate(name: "", sets: 3, reps: 10, weight: 0)])
            } label: {
                Label("Nouvelle séance", systemImage: "plus")
            }
        }

        Section {
            Stepper(value: Binding(get: { state.weeklyGoal }, set: { goal in model.update(\.fitness) { $0.weeklyGoal = goal } }), in: 1...7) {
                ValueRow(title: "Objectif", value: "\(state.weeklyGoal) séances / semaine")
            }
            NumberRow(title: "Poids", value: Binding(get: { state.bodyWeightKg }, set: { weight in model.update(\.fitness) { $0.bodyWeightKg = weight } }), unit: "kg")
            ValueRow(title: "Cette semaine", value: "\(FitnessMath.workouts(inWeekOf: now, state)) séances", symbol: "flame.fill")
            ValueRow(title: "Volume", value: "\(TF.int(FitnessMath.weeklyVolume(state, weekOf: now).reduce(0, +))) kg", symbol: "scalemass")
            if let best = FitnessMath.records(state).first {
                ValueRow(title: "Meilleur record", value: "\(best.exercise) · \(TF.int(best.weight)) kg", symbol: "trophy.fill")
            }
        } header: {
            Text("Suivi")
        } footer: {
            Text("Le poids sert à estimer les calories brûlées. Estimation indicative.")
        }
    }

    private func weekdays(_ days: [Int]) -> String {
        guard !days.isEmpty else { return "à la demande" }
        let names = ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."]
        return days.compactMap { names[safe: $0 - 1] }.joined(separator: ", ")
    }
}

struct RoutineEditor: View {
    @Environment(AppModel.self) private var model
    @State var routine: Routine

    var body: some View {
        SheetForm(title: routine.name.isEmpty ? "Nouvelle séance" : routine.name, canSave: !routine.name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField("Nom (haut du corps, jambes…)", text: $routine.name)
                WeekdayPicker(selection: $routine.weekdays)
            } footer: {
                Text("Les jours choisis décident de la séance proposée chaque jour.")
            }
            ForEach($routine.exercises) { $exercise in
                Section {
                    TextField("Exercice", text: $exercise.name)
                    Stepper("Séries : \(exercise.sets)", value: $exercise.sets, in: 1...12)
                    Stepper("Répétitions : \(exercise.reps)", value: $exercise.reps, in: 1...50)
                    NumberRow(title: "Charge", value: $exercise.weight, unit: "kg")
                    Stepper("Repos : \(exercise.restSeconds) s", value: $exercise.restSeconds, in: 15...600, step: 15)
                }
            }
            Section {
                Button {
                    routine.exercises.append(ExerciseTemplate(name: "", sets: 3, reps: 10, weight: 0))
                } label: {
                    Label("Ajouter un exercice", systemImage: "plus")
                }
                if routine.exercises.count > 1 {
                    Button("Retirer le dernier exercice", role: .destructive) {
                        routine.exercises.removeLast()
                    }
                }
            }
        }
    }

    private func save() {
        var saved = routine
        saved.name = saved.name.trimmed
        saved.exercises = saved.exercises.filter { !$0.name.trimmed.isEmpty }
        model.update(\.fitness) { state in
            if let index = state.routines.firstIndex(where: { $0.id == saved.id }) {
                state.routines[index] = saved
            } else {
                state.routines.append(saved)
            }
        }
    }
}
