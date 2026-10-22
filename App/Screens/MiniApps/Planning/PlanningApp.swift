import SwiftUI

/// The Planning mini-app: the calendar (a day, the week, the month or the year, changed with a pinch or the
/// buttons above it; a touch on a free time creates an event there) and the chosen day in one timeline
/// (calendar, classes, tasks, deadlines, workouts), the three priorities, the tasks to do, then the
/// schedule, the studies, the projects, the habits and focus.
struct PlanningAppView: View {
    @Environment(AppModel.self) private var model
    @State private var events: [EventSnapshot] = []
    @State private var newPriority = ""
    @State private var askingCalendar = false
    /// The day the agenda shows (today by default; any day before or after).
    @State private var day = Date()
    /// How much time the calendar shows: the week by default.
    @State private var scale: CalendarScale = .week
    /// A task, or an event of the schedule, made or changed from the calendar.
    @State private var editors = PlanningEditors()
    @Environment(\.openURL) private var openURL

    private var accentHex: String { MiniApp.planning.colorHex }

    var body: some View {
        let now = Date()
        let isToday = DateMath.isSameDay(day, now)
        let today = Agenda.items(on: day, model: model, events: events)
        let tasks = model.content.tasks
        let overdue = tasks.filter { $0.isOverdue(at: now) }
        MiniAppScroll {
            VStack(alignment: .leading, spacing: 10) {
                PlanningCalendarCard(day: $day, scale: $scale, events: events, onCreate: { editors.create(on: $0, at: $1) }, onOpen: open)
                    .padding(.bottom, 6)
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
                .miniCard()
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
                editors.task = TaskItem(title: "", due: DateMath.startOfDay(day))
            }
            .accessibilityIdentifier("planning-new-task")

            priorities(now: now)

            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Tâches"))
                NavigationLink(value: HomeRoute.page(.planningTasks)) {
                    HStack(spacing: 10) {
                        countTile(tr("En retard"), overdue.count, overdue.isEmpty ? nil : MiniStyle.alertHex)
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
            MiniAppInfoSection(app: .planning)
        }
        .navigationTitle(tr("Planning"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: loadEvents)
        .onChange(of: day) { _, _ in loadEvents() }
        .onChange(of: scale) { _, _ in loadEvents() }
        .planningEditors($editors)
    }

    /// The calendar events of what the calendar shows (the month around the day, or the whole year).
    private func loadEvents() {
        let range = PlanningCalendar.range(for: scale, day: day)
        events = CalendarService.events(from: range.start, to: range.end)
    }

    /// A touch on something of the calendar: its own editor; a deadline or a workout shows its day.
    private func open(_ item: AgendaItem) {
        editors.open(item, on: day, model: model, openURL: openURL) { day = $0 }
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
        .miniTile()
    }

    // MARK: Priorities

    private func priorities(now: Date) -> some View {
        let items = model.productivity.priorities
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Top 3 du jour"), detail: items.isEmpty ? nil : "\(items.filter { $0.isDone(on: now) }.count)/\(items.count)")
            // Rows like the other lists of the mini-apps: a 34-point mark, the title, hairlines between.
            MiniRowsCard {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { MiniDivider() }
                    Button {
                        Haptics.tap()
                        model.update(\.productivity) { $0.togglePriority(item.id, on: now) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isDone(on: now) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(item.isDone(on: now) ? Color(hex: accentHex) : .secondary)
                                .frame(width: 34, height: 34)
                            Text(item.title)
                                .font(.body.weight(.medium))
                                .strikethrough(item.isDone(on: now))
                                .foregroundStyle(item.isDone(on: now) ? .secondary : .primary)
                            Spacer(minLength: 8)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            model.update(\.productivity) { $0.priorities.removeAll { $0.id == item.id } }
                        } label: {
                            Label(tr("Retirer"), systemImage: "trash")
                        }
                    }
                }
                if items.count < 3 {
                    if !items.isEmpty { MiniDivider() }
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundStyle(Color(hex: accentHex))
                            .frame(width: 34, height: 34)
                        TextField(tr("Ajouter une priorité"), text: $newPriority)
                            .submitLabel(.done)
                            .onSubmit(addPriority)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func addPriority() {
        let title = newPriority.trimmed
        guard !title.isEmpty else { return }
        model.update(\.productivity) { $0.priorities.append(PriorityItem(title: title)) }
        newPriority = ""
    }
}

/// The editors the Planning's calendar opens, shared by the Planning, its week page and the Planning card
/// of « Mon Quotidien »: a touch on a free time makes an event of the schedule there (its editor warns of
/// what happens at the same time), a touch on a block opens its own editor. Shown by `planningEditors(_:)`.
struct PlanningEditors {
    /// A task, opened from the calendar or new.
    var task: TaskItem?
    /// An event of the schedule, an exam or homework, made or changed from the calendar.
    var schedule: StudiesSheet?

    /// A touch on a free time: a new event of the schedule, that day, from that time, for an hour.
    mutating func create(on date: Date, at minute: Int) {
        let slot = ClassSlot(courseID: nil, weekday: FitnessMath.isoWeekday(date), startMinute: minute, endMinute: min(24 * 60, minute + 60),
                             kind: .appointment, title: "", date: DateMath.startOfDay(date))
        schedule = .slotOn(slot, date)
    }

    /// A touch on something of the calendar: its own editor (the calendar's events open in Calendar). What
    /// has no editor (a deadline, a workout) goes to `show` with its day; `day` stands for an item without a time.
    @MainActor
    mutating func open(_ item: AgendaItem, on day: Date, model: AppModel, openURL: OpenURLAction, show: (Date) -> Void) {
        let date = item.start ?? day
        switch item.kind {
        case .classSlot:
            if let id = item.slotID, let slot = model.student.slots.first(where: { $0.id == id }) { schedule = .slotOn(slot, date) }
        case .task:
            if let id = item.taskID, let found = model.content.tasks.first(where: { $0.id == id }) { task = found }
        case .exam:
            if let id = item.examID, let exam = model.student.exams.first(where: { $0.id == id }) { schedule = .exam(exam) }
        case .assignment:
            if let id = item.assignmentID, let assignment = model.student.assignments.first(where: { $0.id == id }) { schedule = .assignment(assignment) }
        case .event:
            if let url = URL(string: "calshow:\(Int(date.timeIntervalSinceReferenceDate))") { openURL(url) }
        case .deadline, .workout:
            show(date)
        }
    }
}

extension View {
    /// The sheets of `PlanningEditors`: the task editor and the editor of the schedule.
    func planningEditors(_ editors: Binding<PlanningEditors>) -> some View {
        sheet(item: editors.task) { TaskEditor(task: $0) }
            .sheet(item: editors.schedule) { $0.editor }
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
