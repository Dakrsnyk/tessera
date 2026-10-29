import SwiftUI

struct ProductivitySpaceSections: View {
    @Environment(AppModel.self) private var model
    @State private var newPriority = ""
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    var body: some View {
        Section {
            ForEach(model.productivity.activePriorities) { item in
                Button {
                    Haptics.tap()
                    model.update(\.productivity) { $0.togglePriority(item.id) }
                } label: {
                    Label {
                        Text(item.title).foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "circle")
                    }
                }
            }
            .onDelete { offsets in
                // Offsets are those of the active list: only those tasks are removed.
                let active = model.productivity.activePriorities
                let ids = offsets.compactMap { active[safe: $0]?.id }
                model.update(\.productivity) { $0.priorities.removeAll { ids.contains($0.id) } }
            }
            NavigationLink {
                CompletedPrioritiesView()
            } label: {
                ValueRow(title: tr("Mes tâches réalisées"), value: "\(model.productivity.completedPriorities.count)", symbol: "checkmark.circle")
            }
            .accessibilityIdentifier("completed-priorities-link")
            if model.productivity.activePriorities.count < ProductivityState.maxPriorities {
                HStack {
                    TextField(tr("Nouvelle priorité"), text: $newPriority)
                        .submitLabel(.done)
                        .onSubmit(addPriority)
                    Button(tr("Ajouter"), action: addPriority)
                        .disabled(newPriority.trimmed.isEmpty)
                }
            }
        } header: {
            Text(tr("Top 3 du jour"))
        } footer: {
            Text(tr("Une tâche validée quitte le Top 3 et reste dans « Mes tâches réalisées »."))
        }

        Section(tr("Tâches")) {
            NavigationLink {
                TasksView()
            } label: {
                ValueRow(title: tr("Mes tâches"), value: tr("\(model.content.tasks.filter { !$0.isDone }.count) à faire"), symbol: "checklist")
            }
        }

        Section(tr("Projets")) {
            ForEach(model.productivity.projects) { project in
                Button {
                    sheets?.open { ProjectEditor(project: project) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(Color(hex: project.colorHex)).frame(width: 10, height: 10)
                            Text(project.name).foregroundStyle(Color.primary)
                            Spacer()
                            Text(Fmt.percent(project.progress)).foregroundStyle(Color.secondary).monospacedDigit()
                        }
                        ProgressView(value: project.progress).tint(Color(hex: project.colorHex))
                    }
                }
            }
            .onDelete { offsets in
                model.update(\.productivity) { $0.projects.remove(atOffsets: offsets) }
            }
            Button {
                sheets?.open { ProjectEditor(project: Project(name: "")) }
            } label: {
                Label(tr("Nouveau projet"), systemImage: "plus")
            }
        }

        Section(tr("Échéances")) {
            ForEach(model.productivity.deadlines.sorted { $0.date < $1.date }) { deadline in
                Button {
                    sheets?.open { DeadlineEditor(deadline: deadline) }
                } label: {
                    ValueRow(title: deadline.title, value: Fmt.format(deadline.date, template: "dMMMHHmm"), symbol: "flag.checkered")
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let sorted = model.productivity.deadlines.sorted { $0.date < $1.date }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.productivity) { $0.deadlines.removeAll { ids.contains($0.id) } }
            }
            Button {
                sheets?.open { DeadlineEditor(deadline: Deadline(title: "", date: Date().addingTimeInterval(3 * 86_400))) }
            } label: {
                Label(tr("Nouvelle échéance"), systemImage: "plus")
            }
        }

        Section {
            ForEach(model.productivity.counters) { counter in
                HStack {
                    Button {
                        sheets?.open { CounterEditor(counter: counter) }
                    } label: {
                        Label(counter.name, systemImage: counter.symbol)
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.pressable)
                    Spacer()
                    Text("\(counter.value(on: Date()))\(counter.goal.map { " / \($0)" } ?? "")")
                        .monospacedDigit()
                        .foregroundStyle(Color.secondary)
                    Button {
                        Haptics.tap()
                        model.update(\.productivity) { $0.stepCounter(counter.id, by: 1) }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .buttonStyle(.pressable)
                    .foregroundStyle(Color(hex: counter.colorHex))
                    .accessibilityLabel(Text(tr("Ajouter à \(counter.name)")))
                }
            }
            .onDelete { offsets in
                model.update(\.productivity) { $0.counters.remove(atOffsets: offsets) }
            }
            Button {
                sheets?.open { CounterEditor(counter: CounterItem(name: "")) }
            } label: {
                Label(tr("Nouveau compteur"), systemImage: "plus")
            }
        } header: {
            Text(tr("Compteurs"))
        } footer: {
            Text(tr("Cafés, pompes, pages lues… Le widget Compteur ajoute d'une touche."))
        }

        Section(tr("Travail profond")) {
            Stepper(value: Binding(
                get: { model.productivity.weeklyFocusGoalHours },
                set: { hours in model.setFocusGoal(hours) }
            ), in: 1...60, step: 1) {
                ValueRow(title: tr("Objectif par semaine"), value: Fmt.hours(model.productivity.weeklyFocusGoalHours))
            }
            ValueRow(title: tr("Cette semaine"), value: Fmt.minutes(ProductivityMath.focusMinutes(model.productivity, weekOf: Date())), symbol: "brain.head.profile")
            HintRow(text: tr("Chaque session lancée depuis le widget Focus compte ici."))
        }
    }

    private func addPriority() {
        let title = newPriority.trimmed
        guard !title.isEmpty else { return }
        model.update(\.productivity) { _ = $0.addQuickTask(title, on: Date()) }
        newPriority = ""
    }
}

/// « Mes tâches réalisées »: the validated Top 3 tasks, the most recent first, with their completion date when
/// known. They are never deleted; a touch puts one back among the active tasks (if the Top 3 has room).
struct CompletedPrioritiesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let items = model.productivity.completedPriorities
        List {
            if items.isEmpty {
                Section {
                    HintRow(text: tr("Les tâches que tu valides dans ton Top 3 apparaîtront ici."))
                }
            } else {
                Section {
                    ForEach(items) { item in
                        Button {
                            Haptics.tap()
                            model.update(\.productivity) { $0.togglePriority(item.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .strikethrough()
                                        .foregroundStyle(Color.secondary)
                                    if let date = item.completedAt {
                                        Text(tr("Terminée le \(Fmt.format(date, template: "dMMMHHmm"))"))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text(tr("Touche une tâche pour la remettre dans ton Top 3."))
                }
            }
        }
        .navigationTitle(tr("Mes tâches réalisées"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("completed-priorities")
    }
}

struct ProjectEditor: View {
    @Environment(AppModel.self) private var model
    @State var project: Project
    @State private var newTask = ""
    @State private var hasDeadline: Bool

    init(project: Project) {
        _project = State(initialValue: project)
        _hasDeadline = State(initialValue: project.deadline != nil)
    }

    var body: some View {
        SheetForm(title: project.name.isEmpty ? tr("Nouveau projet") : project.name, canSave: !project.name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField(tr("Nom du projet"), text: $project.name)
                ColorChoiceRow(hex: $project.colorHex)
                Toggle(tr("Échéance"), isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker(tr("Date"), selection: Binding(
                        get: { project.deadline ?? Date().addingTimeInterval(14 * 86_400) },
                        set: { project.deadline = $0 }
                    ), displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
                }
            }
            Section(tr("Tâches")) {
                ForEach($project.tasks) { $task in
                    HStack {
                        Button {
                            task.isDone.toggle()
                            task.completedAt = task.isDone ? Date() : nil
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.pressable)
                        TextField(tr("Tâche"), text: $task.title)
                    }
                }
                .onDelete { project.tasks.remove(atOffsets: $0) }
                HStack {
                    TextField(tr("Nouvelle tâche"), text: $newTask)
                        .onSubmit(addTask)
                    Button(tr("Ajouter"), action: addTask).disabled(newTask.trimmed.isEmpty)
                }
            }
        }
    }

    private func addTask() {
        let title = newTask.trimmed
        guard !title.isEmpty else { return }
        project.tasks.append(ProjectTask(title: title))
        newTask = ""
    }

    private func save() {
        var saved = project
        saved.name = saved.name.trimmed
        if !hasDeadline { saved.deadline = nil } else if saved.deadline == nil { saved.deadline = Date().addingTimeInterval(14 * 86_400) }
        model.update(\.productivity) { state in
            if let index = state.projects.firstIndex(where: { $0.id == saved.id }) {
                state.projects[index] = saved
            } else {
                state.projects.append(saved)
            }
        }
    }
}

struct DeadlineEditor: View {
    @Environment(AppModel.self) private var model
    @State var deadline: Deadline

    var body: some View {
        SheetForm(title: tr("Échéance"), canSave: !deadline.title.trimmed.isEmpty, onSave: save) {
            TextField(tr("Titre (rendu, dossier, examen…)"), text: $deadline.title)
            DatePicker(tr("Date et heure"), selection: $deadline.date)
                .environment(\.locale, Fmt.locale)
        }
    }

    private func save() {
        let saved = deadline
        model.update(\.productivity) { state in
            if let index = state.deadlines.firstIndex(where: { $0.id == saved.id }) {
                state.deadlines[index] = saved
            } else {
                state.deadlines.append(saved)
            }
        }
    }
}

struct CounterEditor: View {
    @Environment(AppModel.self) private var model
    @State var counter: CounterItem
    @State private var hasGoal = false

    private let symbols = ["plus.circle", "cup.and.saucer.fill", "figure.strengthtraining.functional", "book.fill", "drop.fill", "smoke", "pills.fill", "figure.walk", "phone.fill", "star.fill"]

    var body: some View {
        SheetForm(title: tr("Compteur"), canSave: !counter.name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField(tr("Nom (cafés, pompes…)"), text: $counter.name)
                Picker(tr("Icône"), selection: $counter.symbol) {
                    ForEach(symbols, id: \.self) { symbol in
                        Image(systemName: symbol).tag(symbol)
                    }
                }
                ColorChoiceRow(hex: $counter.colorHex)
            }
            Section {
                Stepper(value: $counter.step, in: 1...100) {
                    ValueRow(title: tr("Pas"), value: "+\(counter.step)")
                }
                Toggle(tr("Objectif"), isOn: $hasGoal)
                if hasGoal {
                    IntRow(title: tr("Objectif"), value: Binding(get: { counter.goal ?? 10 }, set: { counter.goal = $0 }))
                }
                Toggle(tr("Remettre à zéro chaque jour"), isOn: $counter.resetsDaily)
            }
        }
        .onAppear { hasGoal = counter.goal != nil }
    }

    private func save() {
        var saved = counter
        saved.name = saved.name.trimmed
        if !hasGoal { saved.goal = nil } else if saved.goal == nil { saved.goal = 10 }
        model.update(\.productivity) { state in
            if let index = state.counters.firstIndex(where: { $0.id == saved.id }) {
                state.counters[index] = saved
            } else {
                state.counters.append(saved)
            }
        }
    }
}

struct HabitsSpaceSections: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section(tr("Suivi")) {
            NavigationLink {
                HabitsView()
            } label: {
                ValueRow(title: tr("Mes habitudes"), value: "\(model.content.habits.count)", symbol: "repeat")
            }
        }
        Section(tr("Ce mois-ci")) {
            ForEach(model.content.habits) { habit in
                let streak = habit.streak(asOf: Date())
                ValueRow(title: habit.name, value: Fmt.plural(streak, tr("jour"), tr("jours")), symbol: habit.symbol, colorHex: habit.colorHex)
            }
            if model.content.habits.isEmpty {
                HintRow(text: tr("Crée une habitude pour suivre ta série."))
            }
        }
    }
}
