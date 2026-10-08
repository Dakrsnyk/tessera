import SwiftUI

/// The Planning mini-app: today in one timeline (calendar, classes, tasks, deadlines, workouts), the
/// three priorities, the tasks to do, then the week, the month, the projects, the habits and focus.
struct PlanningAppView: View {
    @Environment(AppModel.self) private var model
    @State private var events: [EventSnapshot] = []
    @State private var editing: TaskItem?
    @State private var newPriority = ""
    @State private var askingCalendar = false
    /// The day the agenda shows (today by default; any day before or after).
    @State private var day = Date()

    private var accentHex: String { MiniApp.planning.colorHex }

    var body: some View {
        let now = Date()
        let isToday = DateMath.isSameDay(day, now)
        let today = Agenda.items(on: day, model: model, events: events)
        let tasks = model.content.tasks
        let overdue = tasks.filter { $0.isOverdue(at: now) }
        MiniAppScroll {
            VStack(alignment: .leading, spacing: 10) {
                DaySwitcher(day: $day, colorHex: accentHex, allowsFuture: true)
                MiniSectionTitle(title: Fmt.longDay(day), detail: today.isEmpty ? nil : Fmt.plural(today.count, tr("élément"), tr("éléments")))
                VStack(alignment: .leading, spacing: 0) {
                    if today.isEmpty {
                        Text(isToday ? tr("Rien de prévu aujourd'hui. Ajoute une tâche ou un rendez-vous dans ton calendrier.")
                                     : tr("Rien de prévu ce jour-là."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    }
                    ForEach(Array(today.enumerated()), id: \.element.id) { index, item in
                        AgendaRow(item: item, isNow: isToday && (item.start.map { $0 <= now && (item.end ?? $0) > now } ?? false))
                        if index < today.count - 1 { Divider().padding(.leading, 62) }
                    }
                }
                .padding(.horizontal, 14)
                .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("planning-today")
                if !CalendarService.hasAccess {
                    Button {
                        Task {
                            _ = await CalendarService.requestAccess()
                            loadEvents()
                        }
                    } label: {
                        Label(tr("Ajouter les événements de mon calendrier"), systemImage: "calendar.badge.plus")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(Color(hex: accentHex))
                }
            }

            MiniActionButton(title: tr("Nouvelle tâche"), symbol: "plus", colorHex: accentHex) {
                editing = TaskItem(title: "", due: DateMath.startOfDay(day))
            }
            .accessibilityIdentifier("planning-new-task")

            priorities(now: now)

            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Tâches"))
                NavigationLink(value: HomeRoute.page(.planningTasks)) {
                    HStack(spacing: 10) {
                        countTile(tr("En retard"), overdue.count, overdue.isEmpty ? nil : "E5484D")
                        countTile(tr("Aujourd'hui"), tasks.filter { !$0.isDone && $0.isDue(on: now) }.count, nil)
                        countTile(tr("À faire"), tasks.filter { !$0.isDone }.count, nil)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("planning-tasks")
            }

            MiniRowsCard {
                // The week's schedule (classes, work, appointments, other events) and the studies.
                NavigationLink(value: HomeRoute.page(.studiesTimetable)) {
                    MiniRow(symbol: "calendar.day.timeline.left", colorHex: accentHex, title: tr("Horaire de la semaine"),
                            detail: tr("Cours, travail, rendez-vous et autres événements"),
                            value: model.student.slots.isEmpty ? nil : "\(model.student.slots.count)")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("planning-schedule")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.studiesHome)) {
                    MiniRow(symbol: "graduationcap.fill", colorHex: ScheduleKind.course.colorHex, title: tr("Études"),
                            detail: tr("Cours, examens, devoirs, notes et fiches"))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("planning-studies")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.planningWeek)) {
                    MiniRow(symbol: "calendar.day.timeline.left", colorHex: accentHex, title: tr("Semaine"), detail: tr("Tout ce qui t'attend, jour par jour"))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("planning-week")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.planningMonth)) {
                    MiniRow(symbol: "calendar", colorHex: accentHex, title: tr("Mois"), detail: tr("Le calendrier du mois"))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("planning-month")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.planningProjects)) {
                    MiniRow(symbol: "folder.fill", colorHex: accentHex, title: tr("Projets"), detail: tr("Tâches regroupées par projet"),
                            value: model.productivity.projects.isEmpty ? nil : "\(model.productivity.projects.count)")
                }
                .buttonStyle(.plain)
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.planningHabits)) {
                    MiniRow(symbol: "repeat", colorHex: "7FA33A", title: tr("Habitudes"), detail: tr("Séries et régularité"),
                            value: model.content.habits.isEmpty ? nil : "\(model.content.habits.filter { $0.isDone(on: now) }.count)/\(model.content.habits.count)")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("planning-habits")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.planningFocus)) {
                    MiniRow(symbol: "timer", colorHex: "8C6CFF", title: tr("Concentration"),
                            detail: tr("\(TF.int(ProductivityMath.focusMinutes(model.productivity, weekOf: now) / 60)) h sur \(TF.int(model.productivity.weeklyFocusGoalHours)) h cette semaine"))
                }
                .buttonStyle(.plain)
            }
            MiniAppSettingsSection(app: .planning)
        }
        .navigationTitle(tr("Planning"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: loadEvents)
        .onChange(of: day) { _, _ in loadEvents() }
        .sheet(item: $editing) { task in
            TaskEditor(task: task)
        }
    }

    private func loadEvents() {
        let start = DateMath.startOfDay(day)
        events = CalendarService.events(from: start, to: start.addingTimeInterval(86_400))
    }

    private func countTile(_ title: String, _ count: Int, _ hex: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(hex.map { Color(hex: $0) } ?? Color.primary)
                .monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Priorities

    private func priorities(now: Date) -> some View {
        let items = model.productivity.priorities
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Top 3 du jour"), detail: items.isEmpty ? nil : "\(items.filter { $0.isDone(on: now) }.count)/\(items.count)")
            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        Haptics.tap()
                        model.update(\.productivity) { $0.togglePriority(item.id, on: now) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isDone(on: now) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(item.isDone(on: now) ? Color(hex: accentHex) : .secondary)
                            Text(item.title)
                                .strikethrough(item.isDone(on: now))
                                .foregroundStyle(item.isDone(on: now) ? .secondary : .primary)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            model.update(\.productivity) { $0.priorities.removeAll { $0.id == item.id } }
                        } label: {
                            Label(tr("Retirer"), systemImage: "trash")
                        }
                    }
                    Divider()
                }
                if items.count < 3 {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle").font(.title3).foregroundStyle(Color(hex: accentHex))
                        TextField(tr("Ajouter une priorité"), text: $newPriority)
                            .submitLabel(.done)
                            .onSubmit(addPriority)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func addPriority() {
        let title = newPriority.trimmed
        guard !title.isEmpty else { return }
        model.update(\.productivity) { $0.priorities.append(PriorityItem(title: title)) }
        newPriority = ""
    }
}

/// One line of a day: its time, a colored mark, the title and where it comes from. Tasks and
/// homework can be checked off right here.
struct AgendaRow: View {
    let item: AgendaItem
    var isNow = false
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(item.timeText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isNow ? Color(hex: item.colorHex) : .secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 54, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: item.colorHex))
                .frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(item.isDone == true)
                    .foregroundStyle(item.isDone == true ? .secondary : .primary)
                    .lineLimit(2)
                if let detail = item.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let done = item.isDone {
                Button {
                    Haptics.tap()
                    toggle()
                } label: {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(done ? Color(hex: item.colorHex) : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(done ? tr("Marquer comme à faire") : tr("Marquer comme fait")))
            } else {
                Image(systemName: item.symbol)
                    .font(.caption)
                    .foregroundStyle(Color(hex: item.colorHex))
            }
        }
        .padding(.vertical, 10)
    }

    private func toggle() {
        if let id = item.taskID {
            model.updateContent { $0.toggleTask(id) }
        } else if let id = item.assignmentID {
            model.update(\.student) { $0.toggleAssignment(id) }
        }
    }
}

/// A task: title, priority, due date (and time), repeat and notes.
struct TaskEditor: View {
    @State var task: TaskItem
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var hasDue = false

    var body: some View {
        // An existing task opens like a detail page: a back arrow to leave it.
        let exists = model.content.tasks.contains { $0.id == task.id }
        SheetForm(title: task.title.isEmpty ? tr("Nouvelle tâche") : tr("Tâche"), canSave: !task.title.trimmed.isEmpty, closesWithBackArrow: exists, onSave: save) {
            Section {
                TextField(tr("Titre"), text: $task.title)
                    .accessibilityIdentifier("task-title")
                Picker(tr("Priorité"), selection: $task.priority) {
                    ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                }
            }
            Section {
                Toggle(tr("Échéance"), isOn: $hasDue)
                if hasDue {
                    DatePicker(tr("Jour"), selection: Binding(get: { task.due ?? Date() }, set: { task.due = $0 }), displayedComponents: .date)
                    Toggle(tr("À une heure précise"), isOn: $task.hasTime)
                    if task.hasTime {
                        DatePicker(tr("Heure"), selection: Binding(get: { task.due ?? Date() }, set: { task.due = $0 }), displayedComponents: .hourAndMinute)
                    }
                    Picker(tr("Répéter"), selection: $task.repeats) {
                        ForEach(TaskRepeat.allCases) { Text($0.title).tag($0) }
                    }
                }
            } footer: {
                if task.repeats != .never && hasDue {
                    Text(tr("Une fois faite, la tâche revient à sa prochaine date."))
                }
            }
            Section(tr("Notes", context: "text")) {
                TextField(tr("Notes", context: "text"), text: $task.notes, axis: .vertical)
            }
            if model.content.tasks.contains(where: { $0.id == task.id }) {
                Section {
                    Button(tr("Supprimer la tâche"), role: .destructive) {
                        let id = task.id
                        model.updateContent { $0.tasks.removeAll { $0.id == id } }
                        dismiss()
                    }
                }
            }
        }
        .onAppear { hasDue = task.due != nil }
    }

    private func save() {
        var saved = task
        saved.title = saved.title.trimmed
        if !hasDue {
            saved.due = nil
            saved.hasTime = false
            saved.repeats = .never
        }
        model.updateContent { content in
            if let index = content.tasks.firstIndex(where: { $0.id == saved.id }) {
                content.tasks[index] = saved
            } else {
                content.tasks.append(saved)
            }
        }
        Haptics.success()
    }
}
