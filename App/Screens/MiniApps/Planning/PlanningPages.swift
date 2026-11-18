import Charts
import SwiftUI

// MARK: - Tasks

/// Every task: overdue, today, coming, without date, done; each one editable, with a repeat.
struct PlanningTasksPage: View {
    enum Filter: String, CaseIterable, Identifiable {
        case open, today, upcoming, done
        var id: String { rawValue }
        var title: String {
            switch self {
            case .open: tr("À faire")
            case .today: tr("Aujourd'hui")
            case .upcoming: tr("À venir")
            case .done: tr("Terminées")
            }
        }
    }

    @Environment(AppModel.self) private var model
    @State private var filter: Filter = .open
    @State private var editing: TaskItem?
    @State private var quickTitle = ""
    /// The day shown by the « Aujourd'hui » filter: any day, before or after.
    @State private var day = Date()
    @Environment(\.appStyle) private var style

    private var accentHex: String { MiniApp.planning.colorHex }

    var body: some View {
        let now = Date()
        let tasks = model.content.tasks
        let open = tasks.filter { !$0.isDone }
        List {
            Section {
                Picker(tr("Filtre"), selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(style.cristal.strong(accentHex))
                    TextField(tr("Ajouter une tâche"), text: $quickTitle)
                        .submitLabel(.done)
                        .onSubmit(addQuick)
                        .accessibilityIdentifier("tasks-quick-add")
                }
            }
            switch filter {
            case .open:
                section(tr("En retard"), open.filter { $0.isOverdue(at: now) })
                section(tr("Aujourd'hui"), open.filter { !$0.isOverdue(at: now) && $0.isDue(on: now) })
                section(tr("Plus tard"), open.filter { ($0.due.map { DateMath.startOfDay($0) > DateMath.startOfDay(now) } ?? false) })
                section(tr("Sans date"), open.filter { $0.due == nil })
            case .today:
                Section {
                    DaySwitcher(day: $day, colorHex: accentHex, allowsFuture: true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                if DateMath.isSameDay(day, now) {
                    section(tr("Aujourd'hui"), tasks.filter { $0.isDue(on: now) || $0.isOverdue(at: now) })
                } else {
                    section(Fmt.longDay(day), tasks.filter { $0.isDue(on: day) })
                }
            case .upcoming:
                let upcoming = open.filter { $0.due.map { DateMath.startOfDay($0) > DateMath.startOfDay(now) } ?? false }.sorted { ($0.due ?? now) < ($1.due ?? now) }
                section(tr("À venir"), upcoming)
            case .done:
                let done = tasks.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                section(tr("Terminées"), done)
                if !done.isEmpty {
                    Section {
                        Button(tr("Effacer les tâches terminées"), role: .destructive) {
                            model.updateContent { $0.tasks.removeAll(where: \.isDone) }
                        }
                    }
                }
            }
        }
        .styledList()
        .tint(style.cristal.strong(accentHex))
        .navigationTitle(tr("Tâches"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing) { TaskEditor(task: $0) }
    }

    @ViewBuilder
    private func section(_ title: String, _ tasks: [TaskItem]) -> some View {
        if !tasks.isEmpty {
            Section(title) {
                ForEach(tasks.sorted { $0.priority > $1.priority }) { task in
                    TaskRow(task: task) { editing = task }
                }
                .onDelete { offsets in
                    let sorted = tasks.sorted { $0.priority > $1.priority }
                    let ids = offsets.map { sorted[$0].id }
                    model.updateContent { $0.tasks.removeAll { ids.contains($0.id) } }
                }
            }
        }
    }

    private func addQuick() {
        let title = quickTitle.trimmed
        guard !title.isEmpty else { return }
        let due: Date? = filter == .today ? DateMath.startOfDay(day) : nil
        model.updateContent { $0.tasks.append(TaskItem(title: title, due: due)) }
        quickTitle = ""
        Haptics.tap()
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onEdit: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    var body: some View {
        HStack(spacing: 12) {
            CheckCircleButton(
                isDone: task.isDone,
                label: task.title,
                doneColor: style.cristal.category(MiniApp.planning.colorHex),
                todoColor: style.cristal.category(task.priority.colorHex ?? "8A8A8E")
            ) {
                Haptics.tap()
                withAnimation { model.updateContent { $0.toggleTask(task.id) } }
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("task-toggle")
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .strikethrough(task.isDone)
                        .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(task.isOverdue() ? style.cristal.strong(MiniStyle.alertHex) : Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
    }

    private var detail: String? {
        var parts: [String] = []
        if let due = task.due {
            parts.append(DateMath.isSameDay(due, Date()) ? (task.hasTime ? tr("Aujourd'hui \(Fmt.time(due, uses24Hour: true))") : tr("Aujourd'hui")) : Fmt.shortDay(due))
        }
        if task.repeats != .never { parts.append(task.repeats.title.lowercased()) }
        if task.priority != .none { parts.append(tr("priorité \(task.priority.title.lowercased())")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Week and month

/// The week as a table (a column a day, the hours down the side), then what the chosen day holds.
/// A swipe on the table, or its arrows, changes week; a touch on a free time creates an event there,
/// a touch on a block opens it (as in the Planning).
struct PlanningWeekPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var day = Date()
    @State private var events: [EventSnapshot] = []
    @State private var editors = PlanningEditors()
    @Environment(\.appStyle) private var style

    var body: some View {
        let week = Agenda.week(containing: day, model: model, events: events)
        let items = week.first { DateMath.isSameDay($0.day, day) }?.items ?? []
        MiniAppScroll {
            WeekTableCard(day: $day, days: week, onCreate: { date, minute in
                Haptics.tap()
                editors.create(on: date, at: minute)
            }, onOpen: { item in
                editors.open(item, on: day, model: model, openURL: openURL) { day = $0 }
            }, accent: style.cristal.strong(MiniApp.planning.colorHex))
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: Fmt.longDay(day), detail: items.isEmpty ? nil : Fmt.plural(items.count, tr("élément"), tr("éléments")))
                if items.isEmpty {
                    Text(tr("Libre")).font(.subheadline).foregroundStyle(.secondary).card(padding: 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { item in AgendaRow(item: item) }
                    }
                    .padding(.horizontal, 14)
                    .miniCard()
                }
            }
        }
        .navigationTitle(tr("Semaine"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: day) { _, _ in load() }
        .planningEditors($editors)
    }

    private func load() {
        guard let first = DateMath.week(containing: day).first else { return }
        events = CalendarService.events(from: first, to: first.addingTimeInterval(7 * 86_400))
    }
}

struct PlanningMonthPage: View {
    @Environment(AppModel.self) private var model
    @State private var month = Date()
    @State private var selected = Date()
    @State private var events: [EventSnapshot] = []
    @Environment(\.appStyle) private var style

    private var accentHex: String { MiniApp.planning.colorHex }

    var body: some View {
        let items = Agenda.items(on: selected, model: model, events: events)
        MiniAppScroll {
            // Calendar's head: the month big and bold, the arrows on the right.
            HStack(spacing: 0) {
                Text(Fmt.monthYear(month))
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button { move(-1) } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tr("Période précédente")))
                Button { move(1) } label: {
                    Image(systemName: "chevron.right").font(.body.weight(.semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tr("Période suivante")))
            }
            .tint(style.cristal.strong(accentHex))
            PlanningMonthGrid(month: month, selected: selected, accent: style.cristal.strong(accentHex),
                              items: { Agenda.items(on: $0, model: model, events: events) },
                              onPick: { selected = $0 })
                .card(padding: 12)
            VStack(alignment: .leading, spacing: 8) {
                MiniSectionTitle(title: Fmt.longDay(selected))
                if items.isEmpty {
                    Text(tr("Rien de prévu.")).font(.subheadline).foregroundStyle(.secondary).card(padding: 12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { item in AgendaRow(item: item) }
                    }
                    .padding(.horizontal, 14)
                    .miniCard()
                }
            }
        }
        .navigationTitle(tr("Mois"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: month) { _, _ in load() }
    }

    private var monthInterval: DateInterval? { DateMath.calendar.dateInterval(of: .month, for: month) }

    private func move(_ months: Int) {
        month = DateMath.calendar.date(byAdding: .month, value: months, to: month) ?? month
        if let start = monthInterval?.start { selected = start }
    }

    private func load() {
        guard let interval = monthInterval else { return }
        // A week more on each side: the grey days of the neighbouring months show their dots too.
        let start = DateMath.calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start
        let end = DateMath.calendar.date(byAdding: .day, value: 7, to: interval.end) ?? interval.end
        events = CalendarService.events(from: start, to: end)
    }
}

// MARK: - Projects

struct PlanningProjectsPage: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Project?
    @Environment(\.appStyle) private var style

    var body: some View {
        let projects = model.productivity.projects
        List {
            if projects.isEmpty {
                Text(tr("Regroupe les tâches d'un même projet (un déménagement, un rapport, un voyage) et suis leur avancement."))
                    .foregroundStyle(Color.secondary)
            }
            ForEach(projects) { project in
                Section {
                    ForEach(project.tasks) { task in
                        Button {
                            Haptics.tap()
                            model.update(\.productivity) { $0.toggleProjectTask(project: project.id, task: task.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? style.cristal.category(project.colorHex) : Color.secondary)
                                Text(task.title)
                                    .strikethrough(task.isDone)
                                    .foregroundStyle(task.isDone ? Color.secondary : Color.primary)
                            }
                        }
                    }
                    Button(tr("Modifier le projet")) { editing = project }
                } header: {
                    HStack {
                        Circle().fill(style.cristal.category(project.colorHex)).frame(width: 8, height: 8)
                        Text(project.name)
                        Spacer()
                        Text("\(project.doneCount)/\(project.tasks.count)")
                    }
                } footer: {
                    if let deadline = project.deadline {
                        Text(tr("Échéance : \(Fmt.longDay(deadline))"))
                    }
                }
            }
            Section {
                Button {
                    editing = Project(name: "")
                } label: {
                    Label(tr("Nouveau projet"), systemImage: "folder.badge.plus")
                }
            }
        }
        .styledList()
        .tint(style.cristal.strong(MiniApp.planning.colorHex))
        .navigationTitle(tr("Projets"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing) { ProjectEditor(project: $0) }
    }
}

// MARK: - Habits

/// The Habits page of Planning is the Habits mini-app page (direction « Hybride », `HabitsApp`): one page for Mon
/// quotidien, Planning and the notifications.
struct PlanningHabitsPage: View {
    var body: some View {
        HabitsApp()
    }
}

// MARK: - Focus

struct PlanningFocusPage: View {
    @Environment(AppModel.self) private var model
    private let choices = [15, 25, 45, 60, 90]
    @Environment(\.appStyle) private var style
    /// The focus color (violet) as Cristal translates it: a fill, and its strong version for text.
    private var focusFill: Color { style.cristal.category("8C6CFF") }
    private var focusStrong: Color { style.cristal.strong("8C6CFF") }

    var body: some View {
        let now = Date()
        let focus = model.content.focus
        let week = ProductivityMath.focusByDay(model.productivity, weekOf: now)
        let hours = ProductivityMath.focusMinutes(model.productivity, weekOf: now) / 60
        MiniAppScroll {
            VStack(spacing: 14) {
                if focus.isRunning(at: now), let end = focus.endDate {
                    Text(tr("Session en cours")).font(.subheadline.weight(.semibold)).foregroundStyle(focusStrong)
                    Text(timerInterval: now...end, countsDown: true)
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Button(tr("Arrêter"), role: .destructive) { stop() }
                        .buttonStyle(.bordered)
                } else {
                    Text(tr("Lance une session de concentration")).font(.headline)
                    HStack(spacing: 8) {
                        ForEach(choices, id: \.self) { minutes in
                            Button {
                                start(minutes)
                            } label: {
                                Text("\(minutes)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(minutes == focus.lastDurationMinutes ? focusStrong : focusFill.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(minutes == focus.lastDurationMinutes ? style.onAccent : focusStrong)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    Text(tr("minutes")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .card()
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Cette semaine"), detail: "\(TF.decimal(hours, 1)) h / \(TF.int(model.productivity.weeklyFocusGoalHours)) h")
                Chart {
                    ForEach(DayValue.list(DateMath.week(containing: now), week)) { item in
                        BarMark(x: .value("Jour", item.date, unit: .day), y: .value("Minutes", item.value))
                            .foregroundStyle(focusFill.gradient)
                            .cornerRadius(3)
                    }
                }
                .accessibilityLabel(tr("Cette semaine"))
                .frame(height: 160)
                .card()
            }
        }
        .navigationTitle(tr("Concentration"))
        .navigationBarTitleDisplayMode(.large)
    }

    private func start(_ minutes: Int) {
        let now = Date()
        let end = now.addingTimeInterval(TimeInterval(minutes) * 60)
        model.updateContent { $0.focus = FocusSession(startDate: now, endDate: end, lastDurationMinutes: minutes) }
        model.update(\.productivity) { $0.logFocusStart(at: now, minutes: minutes) }
        Task { await FocusNotifier.schedule(end: end, minutes: minutes) }
        Haptics.success()
    }

    private func stop() {
        let now = Date()
        model.updateContent {
            $0.focus.startDate = nil
            $0.focus.endDate = nil
        }
        model.update(\.productivity) { $0.logFocusStop(at: now) }
        // A session stopped early: its « focus over » alert must not come later (like the widget's Stop button).
        FocusNotifier.cancel()
    }
}
