import SwiftUI

struct ProductivitySpaceSections: View {
    @Environment(AppModel.self) private var model
    @State private var newPriority = ""
    @State private var editingProject: Project?
    @State private var editingDeadline: Deadline?
    @State private var editingCounter: CounterItem?

    var body: some View {
        Section {
            ForEach(model.productivity.priorities) { item in
                let done = item.isDone(on: Date())
                Button {
                    Haptics.tap()
                    model.update(\.productivity) { $0.togglePriority(item.id) }
                } label: {
                    Label {
                        Text(item.title).strikethrough(done).foregroundStyle(done ? Color.secondary : Color.primary)
                    } icon: {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            .onDelete { offsets in
                model.update(\.productivity) { $0.priorities.remove(atOffsets: offsets) }
            }
            if model.productivity.priorities.count < 3 {
                HStack {
                    TextField("Nouvelle priorité", text: $newPriority)
                        .submitLabel(.done)
                        .onSubmit(addPriority)
                    Button("Ajouter", action: addPriority)
                        .disabled(newPriority.trimmed.isEmpty)
                }
            }
        } header: {
            Text("Top 3 du jour")
        } footer: {
            Text("Les cases se décochent chaque matin. Coche-les depuis le widget.")
        }
        .sheet(item: $editingProject) { project in
            ProjectEditor(project: project)
        }
        .sheet(item: $editingDeadline) { deadline in
            DeadlineEditor(deadline: deadline)
        }
        .sheet(item: $editingCounter) { counter in
            CounterEditor(counter: counter)
        }

        Section("Tâches") {
            NavigationLink {
                TasksView()
            } label: {
                ValueRow(title: "Mes tâches", value: "\(model.content.tasks.filter { !$0.isDone }.count) à faire", symbol: "checklist")
            }
        }

        Section("Projets") {
            ForEach(model.productivity.projects) { project in
                Button {
                    editingProject = project
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
                editingProject = Project(name: "")
            } label: {
                Label("Nouveau projet", systemImage: "plus")
            }
        }

        Section("Échéances") {
            ForEach(model.productivity.deadlines.sorted { $0.date < $1.date }) { deadline in
                Button {
                    editingDeadline = deadline
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
                editingDeadline = Deadline(title: "", date: Date().addingTimeInterval(3 * 86_400))
            } label: {
                Label("Nouvelle échéance", systemImage: "plus")
            }
        }

        Section {
            ForEach(model.productivity.counters) { counter in
                HStack {
                    Button {
                        editingCounter = counter
                    } label: {
                        Label(counter.name, systemImage: counter.symbol)
                            .foregroundStyle(Color.primary)
                    }
                    .buttonStyle(.plain)
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
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(hex: counter.colorHex))
                    .accessibilityLabel(Text("Ajouter à \(counter.name)"))
                }
            }
            .onDelete { offsets in
                model.update(\.productivity) { $0.counters.remove(atOffsets: offsets) }
            }
            Button {
                editingCounter = CounterItem(name: "")
            } label: {
                Label("Nouveau compteur", systemImage: "plus")
            }
        } header: {
            Text("Compteurs")
        } footer: {
            Text("Cafés, pompes, pages lues… Le widget Compteur ajoute d'une touche.")
        }

        Section("Travail profond") {
            Stepper(value: Binding(
                get: { model.productivity.weeklyFocusGoalHours },
                set: { hours in model.update(\.productivity) { $0.weeklyFocusGoalHours = hours } }
            ), in: 1...60, step: 1) {
                ValueRow(title: "Objectif par semaine", value: Fmt.hours(model.productivity.weeklyFocusGoalHours))
            }
            ValueRow(title: "Cette semaine", value: Fmt.minutes(ProductivityMath.focusMinutes(model.productivity, weekOf: Date())), symbol: "brain.head.profile")
            HintRow(text: "Chaque session lancée depuis le widget Focus compte ici.")
        }
    }

    private func addPriority() {
        let title = newPriority.trimmed
        guard !title.isEmpty else { return }
        model.update(\.productivity) { $0.priorities.append(PriorityItem(title: title)) }
        newPriority = ""
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
        SheetForm(title: project.name.isEmpty ? "Nouveau projet" : project.name, canSave: !project.name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField("Nom du projet", text: $project.name)
                ColorChoiceRow(hex: $project.colorHex)
                Toggle("Échéance", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("Date", selection: Binding(
                        get: { project.deadline ?? Date().addingTimeInterval(14 * 86_400) },
                        set: { project.deadline = $0 }
                    ), displayedComponents: .date)
                    .environment(\.locale, Fmt.locale)
                }
            }
            Section("Tâches") {
                ForEach($project.tasks) { $task in
                    HStack {
                        Button {
                            task.isDone.toggle()
                            task.completedAt = task.isDone ? Date() : nil
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        TextField("Tâche", text: $task.title)
                    }
                }
                .onDelete { project.tasks.remove(atOffsets: $0) }
                HStack {
                    TextField("Nouvelle tâche", text: $newTask)
                        .onSubmit(addTask)
                    Button("Ajouter", action: addTask).disabled(newTask.trimmed.isEmpty)
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
        SheetForm(title: "Échéance", canSave: !deadline.title.trimmed.isEmpty, onSave: save) {
            TextField("Titre (rendu, dossier, examen…)", text: $deadline.title)
            DatePicker("Date et heure", selection: $deadline.date)
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
        SheetForm(title: "Compteur", canSave: !counter.name.trimmed.isEmpty, onSave: save) {
            Section {
                TextField("Nom (cafés, pompes…)", text: $counter.name)
                Picker("Icône", selection: $counter.symbol) {
                    ForEach(symbols, id: \.self) { symbol in
                        Image(systemName: symbol).tag(symbol)
                    }
                }
                ColorChoiceRow(hex: $counter.colorHex)
            }
            Section {
                Stepper(value: $counter.step, in: 1...100) {
                    ValueRow(title: "Pas", value: "+\(counter.step)")
                }
                Toggle("Objectif", isOn: $hasGoal)
                if hasGoal {
                    IntRow(title: "Objectif", value: Binding(get: { counter.goal ?? 10 }, set: { counter.goal = $0 }))
                }
                Toggle("Remettre à zéro chaque jour", isOn: $counter.resetsDaily)
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
        Section("Suivi") {
            NavigationLink {
                HabitsView()
            } label: {
                ValueRow(title: "Mes habitudes", value: "\(model.content.habits.count)", symbol: "repeat")
            }
            NavigationLink {
                HydrationView()
            } label: {
                ValueRow(title: "Hydratation", value: "\(model.content.hydration.glasses(on: Date()))/\(model.content.hydration.goal) verres", symbol: "drop.fill")
            }
        }
        Section("Ce mois-ci") {
            ForEach(model.content.habits) { habit in
                let streak = habit.streak(asOf: Date())
                ValueRow(title: habit.name, value: Fmt.plural(streak, "jour", "jours"), symbol: habit.symbol, colorHex: habit.colorHex)
            }
            if model.content.habits.isEmpty {
                HintRow(text: "Crée une habitude pour suivre ta série.")
            }
        }
    }
}
