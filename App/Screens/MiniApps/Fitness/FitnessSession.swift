import SwiftUI

/// The workout as it happens: the exercise and set now, what to lift (changeable before the set),
/// the rest, what was done, and the exercise sheet one tap away without leaving the session.
/// Free: running any session and logging its sets, adding an exercise the person writes. Premium: the
/// library (sheets, picking from it) and what was lifted last time on an exercise.
struct FitnessSessionPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var reps = 10
    @State private var weight: Double = 0
    @State private var info: ExerciseInfo?
    @State private var editingSet: SetLog?
    @State private var picking = false
    /// An exercise the person writes (or one of « Mes exercices »), added to the session.
    @State private var writing = false
    @State private var paywall: PaywallContext?
    @State private var confirmFinish = false
    /// « Annuler la séance » once sets were logged: asked first, they would be lost.
    @State private var confirmCancel = false

    private var accentHex: String { MiniApp.fitness.colorHex }

    var body: some View {
        let state = model.fitness
        Group {
            if let session = state.active, !session.isFinished, let exercise = session.currentExercise {
                live(session: session, exercise: exercise, state: state)
            } else {
                chooser(state: state)
            }
        }
        .navigationTitle(tr("Séance"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $info) { exercise in
            ExerciseInfoSheet(exercise: exercise)
        }
        .sheet(item: $editingSet) { set in
            SetEditor(set: set)
        }
        .sheet(isPresented: $picking) {
            NavigationStack {
                ExerciseLibraryPage { picked in
                    let template = FitnessMath.sessionTemplate(for: picked, model.fitness)
                    model.update(\.fitness) { state in
                        state.active?.append(template)
                        state.noteUsed(picked.id)
                    }
                    picking = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(tr("Fermer")) { picking = false }
                    }
                }
            }
        }
        .sheet(isPresented: $writing) {
            SessionExerciseForm { template in
                model.update(\.fitness) { $0.active?.append(template) }
            }
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    /// The library: picking from it is Premium.
    private func openLibrary() {
        if model.isPremium { picking = true } else { paywall = .exerciseLibrary }
    }

    /// The ⓘ of a library exercise: its sheet with Premium, else the small Premium badge and the paywall.
    @ViewBuilder
    private func infoLabel(_ exercise: ExerciseInfo, font: Font) -> some View {
        if model.canOpenExercise(exercise.id) {
            Image(systemName: "info.circle")
                .font(font)
                .foregroundStyle(Color(hex: accentHex))
        } else {
            PremiumBadge(compact: true)
        }
    }

    private func openInfo(_ exercise: ExerciseInfo) {
        if model.canOpenExercise(exercise.id) { info = exercise } else { paywall = .exerciseLibrary }
    }

    // MARK: Live

    private func live(session: WorkoutSession, exercise: ExerciseTemplate, state: FitnessState) -> some View {
        let now = Date()
        // What was lifted last time is the exercise's data: Premium.
        let last: FitnessMath.ExerciseSession? = exercise.info.flatMap { known in
            guard model.canOpenExercise(known.id) else { return nil }
            return FitnessMath.history(of: known, state).last(where: { past in !DateMath.isSameDay(past.date, now) })
        }
        return MiniAppScroll {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.routineName).font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text(session.start, style: .timer).monospacedDigit()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(tr("\(session.sets.count)/\(session.totalSets) séries"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(session.sets.count), total: Double(max(1, session.totalSets)))
                .tint(Color(hex: accentHex))

            // The exercise now.
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Série \(session.setIndex + 1) sur \(exercise.sets)"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: accentHex))
                        Text(exercise.name).font(.title2.weight(.bold))
                        if let last, let best = last.best {
                            Text(tr("La dernière fois : \(Units.loadText(kilograms: best.weight, in: model.settings.unitSystem)) × \(best.reps)"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let exerciseInfo = exercise.info {
                        Button {
                            openInfo(exerciseInfo)
                        } label: {
                            infoLabel(exerciseInfo, font: .title2)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Text(tr("Fiche de l'exercice")))
                        .accessibilityIdentifier("session-info")
                    }
                }
                HStack(spacing: 12) {
                    adjuster(title: tr("Répétitions"), value: "\(reps)") {
                        reps = max(1, reps - 1)
                    } plus: {
                        reps = min(100, reps + 1)
                    }
                    adjuster(title: tr("Charge"), value: weight > 0 ? Units.loadText(kilograms: weight, in: model.settings.unitSystem) : tr("Corps")) {
                        weight = Units.steppedLoad(kilograms: weight, direction: -1, in: model.settings.unitSystem)
                    } plus: {
                        weight = Units.steppedLoad(kilograms: weight, direction: 1, in: model.settings.unitSystem)
                    }
                }
                if let rest = session.restEndsAt, rest > now {
                    HStack {
                        Label {
                            Text(timerInterval: now...rest, countsDown: true).monospacedDigit()
                        } icon: {
                            Image(systemName: "hourglass")
                        }
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                        Spacer()
                        Button {
                            model.update(\.fitness) { $0.pauseRest(at: Date()) }
                        } label: {
                            Image(systemName: "pause.fill")
                        }
                        .accessibilityLabel(Text(tr("Mettre le repos en pause")))
                        Button(tr("Passer le repos")) {
                            model.update(\.fitness) { $0.skipRest() }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(12)
                    .background(Color(hex: accentHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if let paused = session.restPausedRemaining {
                    HStack {
                        Label(tr("Repos en pause · \(Duration.seconds(paused).formatted(.time(pattern: .minuteSecond)))"), systemImage: "pause.circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(hex: accentHex))
                        Spacer()
                        Button(tr("Reprendre")) {
                            model.update(\.fitness) { $0.resumeRest(at: Date()) }
                        }
                        .font(.subheadline.weight(.semibold))
                        Button(tr("Passer le repos")) {
                            model.update(\.fitness) { $0.skipRest() }
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(12)
                    .background(Color(hex: accentHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                MiniActionButton(title: tr("Série faite"), symbol: "checkmark.circle.fill", colorHex: accentHex) {
                    completeSet()
                }
                .accessibilityIdentifier("session-set-done")
                // The set shown is passed: not done, not counted; the session moves to the next one.
                Button {
                    var accepted = false
                    model.update(\.fitness) { accepted = $0.skipSet(at: Date()) }
                    if accepted { Haptics.tap() }
                } label: {
                    Label(tr("Passer la série"), systemImage: "forward.fill")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("session-skip-set")
                if session.hasSteps {
                    // A « Série faite » or « Passer » touched by mistake (here, on the Lock Screen or a widget).
                    Button {
                        var accepted = false
                        model.update(\.fitness) { accepted = $0.undoLastSet(at: Date()) }
                        if accepted { Haptics.tap() }
                    } label: {
                        Label(tr("Annuler la dernière série"), systemImage: "arrow.uturn.backward")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("session-undo-set")
                }
                Button(tr("Passer cet exercice")) {
                    model.update(\.fitness) { $0.active?.skipExercise(at: Date()) }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
            .card()

            // The whole session.
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("La séance"))
                MiniRowsCard {
                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, item in
                        exerciseRow(item, index: index, session: session)
                        if index < session.exercises.count - 1 { MiniDivider() }
                    }
                }
                Button {
                    openLibrary()
                } label: {
                    HStack(spacing: 8) {
                        Label(tr("Choisir dans la bibliothèque"), systemImage: "books.vertical").font(.subheadline.weight(.semibold))
                        if !model.isPremium { PremiumBadge() }
                    }
                }
                .accessibilityIdentifier("session-library")
                Button {
                    writing = true
                } label: {
                    Label(tr("Ajouter un exercice"), systemImage: "plus.circle.fill").font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("session-add")
            }

            Button(role: .destructive) {
                confirmFinish = true
            } label: {
                Text(tr("Terminer la séance")).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("session-finish")
            .confirmationDialog(tr("Terminer la séance ?"), isPresented: $confirmFinish, titleVisibility: .visible) {
                Button(tr("Terminer et enregistrer")) {
                    model.update(\.fitness) { $0.finishActive(at: Date()) }
                    Haptics.success()
                    dismiss()
                }
            } message: {
                Text(tr("Les séries faites sont enregistrées dans l'historique."))
            }

            // Started by mistake: the session goes away and counts for nothing.
            Button(role: .destructive) {
                if session.sets.isEmpty { cancelSession() } else { confirmCancel = true }
            } label: {
                Label(tr("Annuler la séance"), systemImage: "xmark")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .accessibilityIdentifier("session-cancel")
            .confirmationDialog(tr("Annuler la séance ? Elle ne sera pas comptée."), isPresented: $confirmCancel, titleVisibility: .visible) {
                Button(tr("Annuler la séance"), role: .destructive) { cancelSession() }
            }
        }
        .onAppear { load(exercise) }
        .onChange(of: "\(session.exerciseIndex)-\(session.setIndex)") { _, _ in
            if let current = model.fitness.active?.currentExercise { load(current) }
        }
    }

    /// Drops the session in progress: never in the history, nor in the week, streak or records.
    private func cancelSession() {
        Haptics.tap()
        model.update(\.fitness) { $0.cancelActive() }
        dismiss()
    }

    private func load(_ exercise: ExerciseTemplate) {
        reps = exercise.reps
        weight = exercise.weight
    }

    private func completeSet() {
        let doneReps = reps
        let doneWeight = weight
        var accepted = false
        model.update(\.fitness) { state in
            guard var session = state.active, session.currentExercise != nil else { return }
            _ = session.completeSet(at: Date(), reps: doneReps, weight: doneWeight)
            accepted = true
            // What was really lifted becomes the plan for the next sets of this exercise.
            if session.setIndex > 0, session.exercises.indices.contains(session.exerciseIndex) {
                session.exercises[session.exerciseIndex].reps = doneReps
                session.exercises[session.exerciseIndex].weight = doneWeight
            }
            state.active = session
            if let id = session.sets.last?.exerciseID { state.noteUsed(id) }
            if session.isFinished { state.finishActive(at: Date()) }
        }
        // Light and once, for a set really logged.
        if accepted { Haptics.tap() }
    }

    private func adjuster(title: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Button(action: minus) {
                    Image(systemName: "minus").font(.headline).frame(width: 36, height: 36)
                }
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                Button(action: plus) {
                    Image(systemName: "plus").font(.headline).frame(width: 36, height: 36)
                }
            }
            .foregroundStyle(Color(hex: accentHex))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func exerciseRow(_ item: ExerciseTemplate, index: Int, session: WorkoutSession) -> some View {
        let done = session.sets.filter { $0.exercise == item.name && (item.exerciseID == nil || $0.exerciseID == nil || $0.exerciseID == item.exerciseID) }
        let passed = session.skipped.filter { $0.exerciseIndex == index }.count
        let isCurrent = index == session.exerciseIndex
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: index < session.exerciseIndex ? "checkmark.circle.fill" : (isCurrent ? "play.circle.fill" : "circle"))
                    .foregroundStyle(index <= session.exerciseIndex ? Color(hex: accentHex) : .secondary)
                Text(item.name).font(.subheadline.weight(isCurrent ? .semibold : .regular))
                Spacer()
                Text(FitnessPlan.setText(item, system: model.settings.unitSystem)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if let exerciseInfo = item.info {
                    Button {
                        openInfo(exerciseInfo)
                    } label: {
                        infoLabel(exerciseInfo, font: .body)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(tr("Fiche de \(item.name)")))
                }
            }
            if !done.isEmpty || passed > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(done) { set in
                            Button {
                                editingSet = set
                            } label: {
                                Text(set.weight > 0 ? "\(Units.loadNumber(kilograms: set.weight, in: model.settings.unitSystem)) × \(set.reps)" : tr("\(set.reps) reps"))
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: accentHex).opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.pressable)
                        }
                        // The sets passed: shown apart, neither done nor left to do.
                        ForEach(0..<passed, id: \.self) { _ in
                            Label(tr("Passée"), systemImage: "forward.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: No session

    private func chooser(state: FitnessState) -> some View {
        MiniAppScroll {
            if state.justFinishedSession(at: Date()) != nil {
                // The last « Série faite » or « Passer » finished the session by mistake: it comes back in progress.
                Button {
                    var accepted = false
                    model.update(\.fitness) { accepted = $0.undoLastSet(at: Date()) }
                    if accepted { Haptics.tap() }
                } label: {
                    Label(tr("Annuler la dernière série"), systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("session-undo-finish")
            }
            Text(tr("Choisis la séance à faire."))
                .font(.headline)
            if state.routines.isEmpty {
                Text(tr("Aucune séance dans ton programme : crée-en une dans Programme."))
                    .foregroundStyle(.secondary)
            }
            MiniRowsCard {
                ForEach(Array(state.routines.enumerated()), id: \.element.id) { index, routine in
                    Button {
                        Haptics.success()
                        model.update(\.fitness) { $0.startSession(routine, at: Date()) }
                    } label: {
                        MiniRow(symbol: "play.fill", colorHex: accentHex, title: routine.name,
                                detail: tr("\(Fmt.plural(routine.exercises.count, tr("exercice"), tr("exercices"))) · environ \(FitnessPlan.minutes(routine)) min"))
                    }
                    .buttonStyle(.pressable)
                    if index < state.routines.count - 1 { MiniDivider() }
                }
                if !state.routines.isEmpty { MiniDivider() }
                Button {
                    model.update(\.fitness) { state in
                        state.startSession(Routine(name: tr("Séance libre"), exercises: []), at: Date())
                    }
                    // From the library with Premium, else written by the person.
                    if model.isPremium { picking = true } else { writing = true }
                } label: {
                    MiniRow(symbol: "sparkles", colorHex: accentHex, title: tr("Séance libre"), detail: tr("Ajoute les exercices au fur et à mesure"))
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

/// An exercise written by the person, or one of « Mes exercices », added to the session in progress
/// with its sets, reps, load and rest (free, without the library).
struct SessionExerciseForm: View {
    let onAdd: (ExerciseTemplate) -> Void
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight: Double = 0
    @State private var rest = 90

    var body: some View {
        let mine = model.fitness.customExercises
        SheetForm(title: tr("Ajouter un exercice"), canSave: !name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField(tr("Exercice"), text: $name)
                    .accessibilityIdentifier("session-exercise-name")
            }
            if !mine.isEmpty {
                Section(tr("Mes exercices")) {
                    ForEach(mine) { custom in
                        Button {
                            choose(custom)
                        } label: {
                            HStack {
                                Text(custom.name).foregroundStyle(Color.primary)
                                Spacer()
                                if custom.name == name.trimmed {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            Section(tr("Séries")) {
                Stepper(tr("Séries : \(sets)"), value: $sets, in: 1...12)
                Stepper(tr("Répétitions : \(reps)"), value: $reps, in: 1...100)
                NumberRow(title: tr("Charge"), value: $weight.weight(in: model.settings.unitSystem), unit: model.settings.unitSystem.weightUnit)
                Stepper(tr("Repos : \(rest) s"), value: $rest, in: 15...600, step: 15)
            }
        }
    }

    private func choose(_ custom: CustomExercise) {
        name = custom.name
        if custom.type != .strength {
            sets = 1
            reps = 1
        }
    }

    private func save() {
        onAdd(ExerciseTemplate(name: name.trimmed, sets: sets, reps: reps, weight: weight, restSeconds: rest))
        Haptics.success()
    }
}

/// Changes a set already done (what was really lifted), or removes it.
struct SetEditor: View {
    let set: SetLog
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var reps = 0
    @State private var weight: Double = 0

    var body: some View {
        SheetForm(title: set.exercise, canSave: reps > 0, onSave: save) {
            Section {
                Stepper(tr("Répétitions : \(reps)"), value: $reps, in: 1...100)
                NumberRow(title: tr("Charge"), value: $weight.weight(in: model.settings.unitSystem), unit: model.settings.unitSystem.weightUnit)
            }
            Section {
                Button(role: .destructive) {
                    let id = set.id
                    model.update(\.fitness) { state in
                        state.active?.sets.removeAll { $0.id == id }
                        for index in state.history.indices { state.history[index].sets.removeAll { $0.id == id } }
                    }
                    dismiss()
                } label: {
                    Label(tr("Supprimer cette série"), systemImage: "trash")
                }
            }
        }
        .onAppear {
            reps = set.reps
            weight = set.weight
        }
    }

    private func save() {
        let id = set.id
        let newReps = reps
        let newWeight = weight
        model.update(\.fitness) { state in
            if let index = state.active?.sets.firstIndex(where: { $0.id == id }) {
                state.active?.sets[index].reps = newReps
                state.active?.sets[index].weight = newWeight
            }
            for sessionIndex in state.history.indices {
                if let index = state.history[sessionIndex].sets.firstIndex(where: { $0.id == id }) {
                    state.history[sessionIndex].sets[index].reps = newReps
                    state.history[sessionIndex].sets[index].weight = newWeight
                }
            }
        }
    }
}
