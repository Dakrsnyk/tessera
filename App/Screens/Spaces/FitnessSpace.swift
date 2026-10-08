import SwiftUI

struct FitnessSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    var body: some View {
        let now = Date()
        let state = model.fitness
        let active = state.active.flatMap { $0.isFinished ? nil : $0 }
        Section {
            if let active, let exercise = active.currentExercise {
                VStack(alignment: .leading, spacing: 8) {
                    Text(active.routineName).font(.caption.weight(.semibold)).foregroundStyle(Color.secondary)
                    Text(exercise.name).font(.title3.weight(.semibold))
                    Text(tr("Série \(active.setIndex + 1)/\(exercise.sets) · \(FitnessTiles.setText(exercise))"))
                        .foregroundStyle(Color.secondary)
                    if let rest = active.restEndsAt, rest > now {
                        HStack {
                            Image(systemName: "timer")
                            Text(tr("Repos : "))
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
                    Label(tr("Série faite"), systemImage: "checkmark.circle.fill").font(.headline)
                }
                Button(tr("Terminer la séance"), role: .destructive) {
                    model.update(\.fitness) { $0.finishActive(at: Date()) }
                }
            } else if let routine = state.routine(for: now) {
                ValueRow(title: routine.name, value: state.isScheduled(now) ? tr("Prévue aujourd'hui") : tr("Prochaine séance"), symbol: "figure.strengthtraining.traditional")
                Button {
                    model.update(\.fitness) { $0.startSession(routine, at: Date()) }
                } label: {
                    Label(tr("Commencer la séance"), systemImage: "play.fill").font(.headline)
                }
            } else {
                HintRow(text: tr("Crée ta première séance : ses exercices, séries, charges et temps de repos. Le widget Prochaine série la suit ensuite depuis l'écran d'accueil."))
            }
        } header: {
            Text(tr("Séance"))
        }

        Section(tr("Mes séances")) {
            ForEach(state.routines) { routine in
                Button {
                    sheets?.open { RoutineEditor(routine: routine) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(routine.name).foregroundStyle(Color.primary)
                        Text("\(Fmt.plural(routine.exercises.count, tr("exercice"), tr("exercices"))) · \(weekdays(routine.weekdays))")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .onDelete { offsets in
                model.update(\.fitness) { $0.routines.remove(atOffsets: offsets) }
            }
            Button {
                sheets?.open { RoutineEditor(routine: Routine(name: "", exercises: [ExerciseTemplate(name: "", sets: 3, reps: 10, weight: 0)])) }
            } label: {
                Label(tr("Nouvelle séance"), systemImage: "plus")
            }
        }

        Section {
            Stepper(value: Binding(get: { state.weeklyGoal }, set: { goal in model.setWeeklyWorkouts(goal) }), in: 1...7) {
                ValueRow(title: tr("Objectif"), value: tr("\(state.weeklyGoal) séances / semaine"))
            }
            // The weight lives in « Mes informations »: changing it here changes it everywhere.
            OptionalNumberRow(title: tr("Poids"), value: Binding(get: { model.profile.weightKg }, set: { model.setWeight($0) }), unit: tr("kg"))
            ValueRow(title: tr("Cette semaine"), value: tr("\(FitnessMath.workouts(inWeekOf: now, state)) séances"), symbol: "flame.fill")
            ValueRow(title: tr("Volume"), value: tr("\(TF.int(FitnessMath.weeklyVolume(state, weekOf: now).reduce(0, +))) kg"), symbol: "scalemass")
            if let best = FitnessMath.records(state).first {
                ValueRow(title: tr("Meilleur record"), value: tr("\(best.exercise) · \(TF.int(best.weight)) kg"), symbol: "trophy.fill")
            }
        } header: {
            Text(tr("Suivi"))
        } footer: {
            Text(tr("Le poids sert à estimer les calories brûlées. Estimation indicative."))
        }
    }

    private func weekdays(_ days: [Int]) -> String {
        guard !days.isEmpty else { return tr("à la demande") }
        let names = ["lun.", "mar.", "mer.", "jeu.", "ven.", "sam.", "dim."]
        return days.compactMap { names[safe: $0 - 1] }.joined(separator: ", ")
    }
}

struct RoutineEditor: View {
    @Environment(AppModel.self) private var model
    @State var routine: Routine
    @State private var picking = false
    @State private var info: ExerciseInfo?

    var body: some View {
        SheetForm(title: routine.name.isEmpty ? tr("Nouvelle séance") : routine.name, canSave: !routine.name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField(tr("Nom (haut du corps, jambes…)"), text: $routine.name)
                    .accessibilityIdentifier("routine-name")
                WeekdayPicker(selection: $routine.weekdays)
            } footer: {
                Text(tr("Les jours choisis décident de la séance proposée chaque jour."))
            }
            ForEach($routine.exercises) { $exercise in
                Section {
                    HStack {
                        TextField(tr("Exercice"), text: $exercise.name)
                            .accessibilityIdentifier("exercise-name")
                        if let known = exercise.info {
                            Button {
                                info = known
                            } label: {
                                Image(systemName: "info.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Text(tr("Fiche de l'exercice")))
                        }
                    }
                    // Suggestions from the library while the name is typed.
                    if exercise.info == nil, exercise.name.trimmed.count >= 2 {
                        ForEach(ExerciseLibrary.search(exercise.name).prefix(3)) { suggestion in
                            Button {
                                exercise.name = suggestion.name
                                exercise.exerciseID = suggestion.id
                            } label: {
                                Label(suggestion.name, systemImage: "sparkle.magnifyingglass")
                                    .font(.subheadline)
                            }
                        }
                    }
                    Stepper(tr("Séries : \(exercise.sets)"), value: $exercise.sets, in: 1...12)
                    Stepper(tr("Répétitions : \(exercise.reps)"), value: $exercise.reps, in: 1...50)
                    NumberRow(title: tr("Charge"), value: $exercise.weight, unit: tr("kg"))
                    Stepper(tr("Repos : \(exercise.restSeconds) s"), value: $exercise.restSeconds, in: 15...600, step: 15)
                    TextField(tr("Tempo (ex. 3-1-1-0)"), text: $exercise.tempo)
                    TextField(tr("Notes", context: "text"), text: $exercise.notes)
                }
            }
            Section {
                Button {
                    picking = true
                } label: {
                    Label(tr("Choisir dans la bibliothèque"), systemImage: "books.vertical")
                }
                Button {
                    routine.exercises.append(ExerciseTemplate(name: "", sets: 3, reps: 10, weight: 0))
                } label: {
                    Label(tr("Ajouter un exercice"), systemImage: "plus")
                }
                if routine.exercises.count > 1 {
                    Button(tr("Retirer le dernier exercice"), role: .destructive) {
                        routine.exercises.removeLast()
                    }
                }
            }
        }
        .sheet(isPresented: $picking) {
            NavigationStack {
                ExerciseLibraryPage { picked in
                    routine.exercises.removeAll { $0.name.trimmed.isEmpty }
                    routine.exercises.append(ExerciseTemplate(name: picked.name, sets: 3, reps: 10, weight: 0, exerciseID: picked.id))
                    picking = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("Fermer")) { picking = false }
                    }
                }
            }
        }
        .sheet(item: $info) { ExerciseInfoSheet(exercise: $0) }
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
