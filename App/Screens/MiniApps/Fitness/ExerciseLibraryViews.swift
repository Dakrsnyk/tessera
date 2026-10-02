import Charts
import SwiftUI

/// The exercise library: search as you type (names, other names, muscles, equipment), filters,
/// favorites, recent and frequent exercises, and « Mes exercices ». Picking mode adds to a session.
struct ExerciseLibraryPage: View {
    var onPick: ((ExerciseInfo) -> Void)?
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var filters = ExerciseLibrary.Filters()
    @State private var info: ExerciseInfo?
    @State private var creating = false

    init(onPick: ((ExerciseInfo) -> Void)? = nil) {
        self.onPick = onPick
    }

    private var accentHex: String { MiniApp.fitness.colorHex }
    private var isBrowsing: Bool { query.trimmed.isEmpty && filters.isEmpty }

    var body: some View {
        let state = model.fitness
        List {
            Section {
                filterBar
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listRowBackground(Color.clear)

            if isBrowsing {
                shortcut(tr("Favoris"), ids: state.favoriteExercises)
                shortcut(tr("Récents"), ids: state.recentExercises.filter { !state.favoriteExercises.contains($0) })
                shortcut(tr("Les plus faits"), ids: FitnessMath.frequentExercises(state).filter { !state.favoriteExercises.contains($0) && !state.recentExercises.contains($0) })
                Section {
                    ForEach(state.customExercises) { custom in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(custom.name)
                            Text("\(custom.muscle.title) · \(custom.equipment.title)").font(.caption).foregroundStyle(Color.secondary)
                        }
                    }
                    .onDelete { offsets in
                        model.update(\.fitness) { $0.customExercises.remove(atOffsets: offsets) }
                    }
                    Button {
                        creating = true
                    } label: {
                        Label(tr("Créer un exercice"), systemImage: "plus.circle")
                    }
                } header: {
                    Text(tr("Mes exercices"))
                }
                Section(tr("Par muscle")) {
                    ForEach(MuscleGroup.allCases) { group in
                        Button {
                            filters.group = group
                        } label: {
                            HStack {
                                Text(group.title).foregroundStyle(Color.primary)
                                Spacer()
                                Text("\(ExerciseLibrary.all.filter { ExerciseLibrary.Filters(group: group).allows($0) }.count)")
                                    .foregroundStyle(Color.secondary)
                                    .monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            } else {
                let results = ExerciseLibrary.search(query, filters: filters)
                Section {
                    if results.isEmpty {
                        Text(tr("Aucun exercice ne correspond. Essaie un autre mot ou retire un filtre."))
                            .foregroundStyle(Color.secondary)
                    }
                    ForEach(results) { exercise in
                        row(exercise)
                    }
                } header: {
                    Text(Fmt.plural(results.count, tr("exercice"), tr("exercices")))
                }
            }
        }
        .styledList()
        .tint(Color(hex: accentHex))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Développé, squat, dos, haltères…"))
        .navigationTitle(onPick == nil ? tr("Exercices") : tr("Ajouter un exercice"))
        .navigationBarTitleDisplayMode(onPick == nil ? .large : .inline)
        .sheet(item: $info) { exercise in
            ExerciseInfoSheet(exercise: exercise)
        }
        .sheet(isPresented: $creating) {
            CustomExerciseEditor()
        }
    }

    // MARK: Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterMenu(title: filters.group?.title ?? tr("Muscle"), isActive: filters.group != nil) {
                    Button(tr("Tous")) { filters.group = nil }
                    ForEach(MuscleGroup.allCases) { group in Button(group.title) { filters.group = group } }
                }
                filterMenu(title: filters.equipment?.title ?? tr("Équipement"), isActive: filters.equipment != nil) {
                    Button(tr("Tous")) { filters.equipment = nil }
                    ForEach(Equipment.allCases) { item in Button(item.title) { filters.equipment = item } }
                }
                filterMenu(title: filters.type?.title ?? tr("Type"), isActive: filters.type != nil) {
                    Button(tr("Tous")) { filters.type = nil }
                    ForEach(ExerciseType.allCases) { item in Button(item.title) { filters.type = item } }
                }
                filterMenu(title: filters.difficulty?.title ?? tr("Niveau"), isActive: filters.difficulty != nil) {
                    Button(tr("Tous")) { filters.difficulty = nil }
                    ForEach(Difficulty.allCases) { item in Button(item.title) { filters.difficulty = item } }
                }
                if !filters.isEmpty {
                    Button {
                        filters = ExerciseLibrary.Filters()
                    } label: {
                        Label(tr("Effacer"), systemImage: "xmark")
                            .font(.subheadline.weight(.medium))
                    }
                    .accessibilityIdentifier("filters-clear")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterMenu<Content: View>(title: String, isActive: Bool, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isActive ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.primary))
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(isActive ? AnyShapeStyle(Color(hex: accentHex)) : AnyShapeStyle(.cardFill), in: Capsule())
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func shortcut(_ title: String, ids: [String]) -> some View {
        let exercises = ids.compactMap(ExerciseLibrary.info).prefix(6)
        if !exercises.isEmpty {
            Section(title) {
                ForEach(Array(exercises)) { exercise in
                    row(exercise)
                }
            }
        }
    }

    private func row(_ exercise: ExerciseInfo) -> some View {
        let isFavorite = model.fitness.favoriteExercises.contains(exercise.id)
        return HStack(spacing: 10) {
            Group {
                if let onPick {
                    Button {
                        onPick(exercise)
                    } label: {
                        ExerciseRowLabel(exercise: exercise)
                    }
                    .buttonStyle(.borderless)
                } else {
                    NavigationLink(value: HomeRoute.page(.fitnessExercise(exercise.id))) {
                        ExerciseRowLabel(exercise: exercise)
                    }
                }
            }
            .accessibilityIdentifier("exercise-row")
            Button {
                info = exercise
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(Color(hex: accentHex))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(tr("Fiche de \(exercise.name)")))
            .accessibilityIdentifier("exercise-info")
        }
        .swipeActions {
            Button {
                model.update(\.fitness) { $0.toggleFavorite(exercise.id) }
            } label: {
                Label(isFavorite ? tr("Retirer") : tr("Favori"), systemImage: isFavorite ? "star.slash" : "star")
            }
            .tint(.orange)
        }
    }
}

struct ExerciseRowLabel: View {
    let exercise: ExerciseInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name).foregroundStyle(Color.primary).lineLimit(1)
            Text("\(exercise.summary) · \(exercise.difficulty.title.lowercased())")
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// The exercise sheet over a session or the library: closing it returns exactly where the person was.
struct ExerciseInfoSheet: View {
    let exercise: ExerciseInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExerciseDetailView(exercise: exercise, inSheet: true)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(tr("Fermer")) { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
    }
}

// MARK: - The exercise sheet

/// One exercise: the demonstration, the muscles, how to do it, what to avoid, the person's own
/// performances, and the alternatives. Essentials first, details further down.
struct ExerciseDetailView: View {
    let exercise: ExerciseInfo
    var inSheet = false
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var alternative: ExerciseInfo?

    private var accentHex: String { MiniApp.fitness.colorHex }

    var body: some View {
        let technique = exercise.technique
        let history = FitnessMath.history(of: exercise, model.fitness)
        let isFavorite = model.fitness.favoriteExercises.contains(exercise.id)
        MiniAppScroll {
            VStack(spacing: 8) {
                ExerciseDemoView(exercise: exercise, colorHex: accentHex)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: accentHex)).frame(width: 7, height: 7)
                    Text(tr("Muscles principaux"))
                    Circle().fill(Color(hex: accentHex).opacity(0.45)).frame(width: 7, height: 7)
                        .padding(.leading, 6)
                    Text(tr("secondaires"))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("exercise-demo")

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    badge(exercise.type.title)
                    badge(exercise.difficulty.title)
                    ForEach(exercise.equipment, id: \.self) { badge($0.title) }
                }
                muscleLine(tr("Principalement"), exercise.primary, strong: true)
                if !exercise.secondary.isEmpty {
                    muscleLine(tr("Aussi"), exercise.secondary, strong: false)
                }
            }

            infoCard(title: tr("Position de départ"), symbol: "figure.stand") {
                Text(technique.start).fixedSize(horizontal: false, vertical: true)
            }

            infoCard(title: tr("Exécution"), symbol: "list.number") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array((technique.steps + exercise.cues).enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Color(hex: accentHex), in: Circle())
                            Text(step).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Divider()
                    Label(technique.range, systemImage: "arrow.up.and.down").font(.subheadline)
                    Label(technique.breathing, systemImage: "wind").font(.subheadline)
                }
            }

            infoCard(title: tr("Points importants"), symbol: "checkmark.circle") {
                bullets(technique.tips, symbol: "checkmark", hex: "2F8F7A")
            }

            infoCard(title: tr("À éviter"), symbol: "exclamationmark.triangle") {
                bullets(technique.mistakes, symbol: "xmark", hex: "E5484D")
            }

            performances(history)

            let alternatives = ExerciseLibrary.alternatives(to: exercise)
            if !alternatives.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Alternatives"))
                    MiniRowsCard {
                        ForEach(Array(alternatives.enumerated()), id: \.element.id) { index, other in
                            Group {
                                if inSheet {
                                    Button {
                                        alternative = other
                                    } label: {
                                        MiniRow(symbol: other.pattern == exercise.pattern ? "arrow.triangle.branch" : "arrow.left.arrow.right", colorHex: accentHex,
                                                title: other.name, detail: other.pattern == exercise.pattern ? tr("Variante") : tr("Mêmes muscles"))
                                    }
                                } else {
                                    NavigationLink(value: HomeRoute.page(.fitnessExercise(other.id))) {
                                        MiniRow(symbol: other.pattern == exercise.pattern ? "arrow.triangle.branch" : "arrow.left.arrow.right", colorHex: accentHex,
                                                title: other.name, detail: other.pattern == exercise.pattern ? tr("Variante") : tr("Mêmes muscles"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            if index < alternatives.count - 1 { MiniDivider() }
                        }
                    }
                }
            }

            Text(tr("Consignes générales : adapte la charge à ton niveau et arrête en cas de douleur. En cas de doute, demande à un professionnel."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                MiniActionButton(title: tr("Ajouter à ma séance"), symbol: "plus", colorHex: accentHex) {
                    adding = true
                }
                .accessibilityIdentifier("exercise-add")
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(.bar)
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.update(\.fitness) { $0.toggleFavorite(exercise.id) }
                    Haptics.tap()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(Text(isFavorite ? tr("Retirer des favoris") : tr("Ajouter aux favoris")))
                .accessibilityIdentifier("exercise-favorite")
            }
        }
        .sheet(isPresented: $adding) {
            AddToRoutineSheet(exercise: exercise)
        }
        .navigationDestination(item: $alternative) { other in
            ExerciseDetailView(exercise: other, inSheet: true)
        }
        .onAppear {
            model.update(\.fitness) { $0.noteUsed(exercise.id) }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }

    private func muscleLine(_ title: String, _ muscles: [Muscle], strong: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(muscles.map(\.title).joined(separator: ", "))
                .font(.subheadline.weight(strong ? .semibold : .regular))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func infoCard<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Color(hex: accentHex))
            content()
                .font(.body)
        }
        .card()
    }

    private func bullets(_ items: [String], symbol: String, hex: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: symbol).font(.caption.weight(.bold)).foregroundStyle(Color(hex: hex))
                    Text(item).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Performances

    @ViewBuilder
    private func performances(_ history: [FitnessMath.ExerciseSession]) -> some View {
        if let last = history.last {
            let best = history.compactMap(\.best).max { FitnessMath.oneRepMax($0) < FitnessMath.oneRepMax($1) }
            let recent = history.filter { $0.date > Date().addingTimeInterval(-30 * 86_400) }.count
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Mes performances"))
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DateMath.isSameDay(last.date, Date()) ? tr("Aujourd'hui") : tr("Dernière séance · \(Fmt.shortDay(last.date))"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(last.sets.map { $0.weight > 0 ? tr("\(ProfileNumberField.format($0.weight)) kg × \($0.reps)") : tr("\($0.reps) reps") }.joined(separator: " · "))
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 10) {
                        if let best, best.weight > 0 {
                            MiniStat(title: tr("Record"), value: "\(ProfileNumberField.format(best.weight))", unit: tr("kg × \(best.reps)"), detail: tr("1RM ≈ \(TF.int(FitnessMath.oneRepMax(best))) kg"))
                        }
                        MiniStat(title: tr("Volume"), value: TF.int(last.volume), unit: tr("kg"), detail: tr("dernière séance"))
                        MiniStat(title: tr("Fréquence"), value: "\(recent)", unit: "×", detail: tr("en 30 jours"))
                    }
                    if history.count >= 3 {
                        Chart {
                            ForEach(history) { session in
                                LineMark(x: .value("Date", session.date), y: .value("Charge", session.topWeight))
                                    .foregroundStyle(Color(hex: accentHex))
                                    .interpolationMethod(.monotone)
                                PointMark(x: .value("Date", session.date), y: .value("Charge", session.topWeight))
                                    .foregroundStyle(Color(hex: accentHex))
                                    .symbolSize(24)
                            }
                        }
                        .frame(height: 150)
                        .accessibilityIdentifier("exercise-chart")
                        Text(tr("Charge la plus lourde de chaque séance")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .card()
            }
        }
    }
}

// MARK: - Adding to a routine

/// Puts an exercise in a routine of the program (or a new one) with its sets, reps, load, rest,
/// tempo and notes.
struct AddToRoutineSheet: View {
    let exercise: ExerciseInfo
    @Environment(AppModel.self) private var model
    @State private var routineID: UUID?
    @State private var newName = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weight: Double = 0
    @State private var rest = 90
    @State private var tempo = ""
    @State private var notes = ""

    var body: some View {
        let routines = model.fitness.routines
        SheetForm(title: exercise.name, canSave: routineID != nil || !newName.trimmed.isEmpty || routines.isEmpty, onSave: save) {
            Section {
                Picker(tr("Séance"), selection: $routineID) {
                    ForEach(routines) { routine in Text(routine.name).tag(Optional(routine.id)) }
                    Text(tr("Nouvelle séance")).tag(UUID?.none)
                }
                if routineID == nil {
                    TextField(tr("Nom de la nouvelle séance"), text: $newName)
                        .accessibilityIdentifier("add-routine-name")
                }
            } header: {
                Text(tr("Dans quelle séance"))
            }
            Section(tr("Séries")) {
                Stepper(tr("Séries : \(sets)"), value: $sets, in: 1...12)
                Stepper(tr("Répétitions : \(reps)"), value: $reps, in: 1...100)
                NumberRow(title: tr("Charge"), value: $weight, unit: tr("kg"))
                Stepper(tr("Repos : \(rest) s"), value: $rest, in: 15...600, step: 15)
            }
            Section {
                TextField(tr("Tempo (ex. 3-1-1-0)"), text: $tempo)
                TextField(tr("Notes"), text: $notes, axis: .vertical)
            } footer: {
                Text(tr("Tempo : secondes en descente, pause, montée, pause."))
            }
        }
        .onAppear {
            routineID = model.fitness.routines.first?.id
            if exercise.type != .strength {
                sets = 1
                reps = 1
            }
        }
    }

    private func save() {
        let template = ExerciseTemplate(name: exercise.name, sets: sets, reps: reps, weight: weight, restSeconds: rest,
                                        exerciseID: exercise.id, tempo: tempo.trimmed, notes: notes.trimmed)
        let target = routineID
        let name = newName
        model.update(\.fitness) { $0.add(template, toRoutine: target, newRoutineName: name) }
        Haptics.success()
    }
}

/// An exercise the library doesn't have, kept in « Mes exercices ».
struct CustomExerciseEditor: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var muscle: Muscle = .chest
    @State private var equipment: Equipment = .dumbbells
    @State private var type: ExerciseType = .strength
    @State private var notes = ""

    var body: some View {
        SheetForm(title: tr("Nouvel exercice"), canSave: !name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField(tr("Nom"), text: $name)
                Picker(tr("Muscle"), selection: $muscle) {
                    ForEach(Muscle.allCases) { Text($0.title).tag($0) }
                }
                Picker(tr("Équipement"), selection: $equipment) {
                    ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                }
                Picker(tr("Type"), selection: $type) {
                    ForEach(ExerciseType.allCases) { Text($0.title).tag($0) }
                }
                TextField(tr("Notes"), text: $notes, axis: .vertical)
            }
        }
    }

    private func save() {
        let custom = CustomExercise(name: name.trimmed, muscle: muscle, equipment: equipment, type: type, notes: notes.trimmed)
        model.update(\.fitness) { $0.customExercises.insert(custom, at: 0) }
    }
}
