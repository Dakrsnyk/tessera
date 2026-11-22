import SwiftUI

/// The Planning mini-app, direction 5 « Hybride » (« ce qui vient, puis la semaine »). On the band: the week
/// selector (the one date selector, `day` is the truth of the screen) and, for the current week, the card
/// « Prochain événement ». On the sheet: the scale picker and the week as a table right under it, whose columns
/// fall under the selector's days (a day, the month or the year instead with the picker or a pinch; a touch on a
/// free time creates an event there), then the three priorities, the task counters, the projects,
/// the calendar and the import as two rows, and « Mes infos » last (the studies and the focus are in the Études
/// mini-app, the habits have their own page; no « À remplir » block here). The two actions « Nouvelle tâche » and « Nouvel événement » float above the tab bar.
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
    /// The sheet that reads a photo or a PDF of the timetable.
    @State private var importingSchedule = false
    @Environment(\.openURL) private var openURL
    @Environment(\.appStyle) private var style

    private var accentHex: String { MiniApp.planning.colorHex }

    var body: some View {
        let now = Date()
        let isToday = DateMath.isSameDay(day, now)
        let items = Agenda.items(on: day, model: model, events: events)
        let tasks = model.content.tasks
        let overdue = tasks.filter { $0.isOverdue(at: now) }
        // What comes next, read in today's own agenda (events are loaded around the day picked, which holds today
        // as long as the current week is shown).
        let showsNext = scale == .week && DateMath.calendar.isDate(day, equalTo: now, toGranularity: .weekOfYear)
        MiniAppScaffold(
            colorHex: accentHex,
            // The two actions float above the tab bar (see the overlay), not one main action.
            compact: true
        ) {
            // 1. The only date selector of the screen, with room on the left for the hours of the table below it.
            // The same card as in the other mini-apps (PDG, 2026-11-22): the days spread over the whole card. The
            // room kept on the left for the hours of the table left the card lopsided (an empty strip on the left,
            // Sunday's pill against the right edge), and the table no longer sits right under it.
            WeekSelector(day: $day, colorHex: accentHex, allowsFuture: true, mark: mark)
            // 2. « Prochain événement »: the answer to « qu'est-ce qui vient ? », for the current week.
            if showsNext {
                // Read again every minute: « dans 40 min » and « En cours » follow the clock.
                TimelineView(.everyMinute) { context in
                    nextCard(PlanningNext.pick(from: Agenda.items(on: context.date, model: model, events: events), now: context.date))
                }
            }
        } sheet: {
            // 3. The planning: the scale picker, then the week as a table (or the day, the month, the year).
            VStack(alignment: .leading, spacing: 18) {
                PlanningCalendarCard(day: $day, scale: $scale, events: events, onCreate: { editors.create(on: $0, at: $1) }, onOpen: open)
                    .tourAnchor(.planning, 0)
                // The month and the year show no hours: the day picked is listed under them, to open and check off.
                // The day and the week show the hours: only what has no hour (a task, a homework) is listed, as the
                // table keeps just a few chips for them.
                if scale == .month || scale == .year {
                    dayAgenda(items: items, now: now, isToday: isToday)
                } else if items.contains(where: { $0.start == nil }) {
                    dayAgenda(items: items.filter { $0.start == nil }, now: now, isToday: isToday)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("planning-today")

            // 4. The tasks: the three priorities, then the counters.
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
                .buttonStyle(.pressable)
                .accessibilityIdentifier("planning-tasks")
            }

            // 5. The other categories.
            MiniRowsCard {
                // Projects. The studies are their own mini-app (Études) and the habits have their own page (Mon
                // quotidien); the week, the month and the focus pages stay reachable but have no row here.
                NavigationLink(value: HomeRoute.page(.planningProjects)) {
                    MiniRow(symbol: "folder.fill", colorHex: accentHex, title: tr("Projets"), detail: tr("Tâches regroupées par projet"),
                            value: model.productivity.projects.isEmpty ? nil : "\(model.productivity.projects.count)")
                }
                .buttonStyle(.pressable)
            }
            // 6. The calendar of the iPhone and the import of a timetable (Premium), as two rows.
            sourcesCard
            // 7. Last: « Mes infos ».
            MiniAppInfoSection(app: .planning)
            // Room for the floating actions.
            Color.clear.frame(height: 80)
        }
        .overlay(alignment: .bottom) {
            PlanningFloatingActions(colorHex: accentHex,
                                    newTask: { editors.task = TaskItem(title: "", due: DateMath.startOfDay(day)) },
                                    newEvent: { editors.create(on: day, at: PlanningNext.defaultStartMinute(now: Date(), isToday: DateMath.isSameDay(day, Date()))) })
                .tourAnchor(.planning, 1)
                .padding(.bottom, 12)
        }
        .navigationTitle(tr("Planning"))
        .miniAppTour(.planning)
        .onAppear(perform: loadEvents)
        .onChange(of: day) { _, _ in loadEvents() }
        .onChange(of: scale) { _, _ in loadEvents() }
        .planningEditors($editors)
        .sheet(isPresented: $importingSchedule) { ScheduleImportView() }
        .permissionSheet(.calendar, isPresented: $askingCalendar, request: requestCalendar) { _ in loadEvents() }
    }

    /// A day of the selector holds something when the agenda has an element that day.
    private func mark(_ date: Date) -> WeekDayMark {
        let items = Agenda.items(on: date, model: model, events: events)
        // Done when everything that can be checked off is, planned when something is still to do.
        let checkable = items.compactMap(\.isDone)
        let allDone = !checkable.isEmpty && checkable.allSatisfy { $0 }
        return WeekDayMark(isDone: allDone, isPlanned: !items.isEmpty)
    }

    /// « Prochain événement »: the time of what comes next (or is going on), how long until it, and where.
    private func nextCard(_ next: PlanningNext.Pick?) -> some View {
        let card: MiniHero
        if let next {
            let item = next.item
            let length = PlanningNext.lengthText(minutes: next.minutes)
            let when = next.inProgress ? tr("En cours · encore \(length)") : tr("dans \(length)")
            let place = (item.place ?? "").trimmed
            let caption = place.isEmpty ? "\(when) · \(item.title)" : "\(when) · \(item.title) · \(place)"
            card = MiniHero(label: tr("Prochain événement"), value: item.timeText, caption: caption, valueSize: 44)
        } else {
            card = MiniHero(label: tr("Prochain événement"), value: "—", caption: tr("Rien de prévu ce jour-là."), valueSize: 44)
        }
        return Button {
            if let item = next?.item { open(item) }
        } label: {
            card
        }
        .buttonStyle(.pressable)
        .disabled(next == nil)
        .accessibilityIdentifier("planning-next")
    }

    /// The calendar of the iPhone (while access is not given) and the import of a timetable, as two rows. The
    /// import carries the Premium badge for a free account: the lock used to show only when the sheet opened.
    private var sourcesCard: some View {
        MiniRowsCard {
            if !CalendarService.hasAccess {
                Button {
                    Task {
                        // Explanation first (once); refused, the sheet offers the settings and Planning works without.
                        if await AppPermission.calendar.requestOrExplain(isPresented: $askingCalendar, request: requestCalendar) != nil {
                            loadEvents()
                        }
                    }
                } label: {
                    MiniRow(symbol: "calendar.badge.plus", colorHex: accentHex, title: tr("Ajouter les événements de mon calendrier"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("planning-add-calendar")
                MiniDivider()
            }
            // A photo or a PDF of the timetable becomes classes of the schedule.
            Button {
                importingSchedule = true
            } label: {
                HStack(spacing: 6) {
                    MiniRow(symbol: "doc.viewfinder", colorHex: accentHex, title: tr("Importer mon horaire"),
                            detail: tr("À partir d'une photo ou d'un PDF"), showsChevron: model.isPremium)
                    if !model.isPremium {
                        PremiumBadge(compact: true)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("planning-import-schedule")
        }
    }

    private func requestCalendar() async {
        _ = await CalendarService.requestAccess()
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
                .foregroundStyle(hex.map { style.cristal.strong($0) } ?? Color.primary)
                .monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .miniTile()
    }

    // MARK: Priorities

    /// The day picked, line by line: what it holds, with the tasks to check off right here.
    private func dayAgenda(items: [AgendaItem], now: Date, isToday: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: isToday ? tr("Aujourd'hui") : Fmt.longDay(day),
                             detail: items.isEmpty ? nil : Fmt.plural(items.count, tr("élément"), tr("éléments")))
            VStack(alignment: .leading, spacing: 0) {
                if items.isEmpty {
                    Text(tr("Rien de prévu ce jour-là."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    AgendaRow(item: item, isNow: isToday && (item.start.map { $0 <= now && (item.end ?? $0) > now } ?? false), onOpen: { open(item) })
                    if index < items.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .padding(.horizontal, 14)
            .miniCard()
        }
    }

    private func priorities(now: Date) -> some View {
        let items = model.productivity.activePriorities
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Top 3 du jour"), detail: items.isEmpty ? nil : "\(items.count)/\(ProductivityState.maxPriorities)")
            // The history of the priorities checked off (it was only on the Top 3 card of « Mon quotidien »).
            NavigationLink {
                CompletedPrioritiesView()
            } label: {
                HStack(spacing: 4) {
                    Text(tr("Mes tâches réalisées"))
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(style.cristal.strong(accentHex))
            }
            .accessibilityIdentifier("planning-completed-priorities")
            // Rows like the other lists of the mini-apps: a 34-point mark, the title, hairlines between.
            MiniRowsCard {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { MiniDivider() }
                    Button {
                        Haptics.tap()
                        model.update(\.productivity) { $0.togglePriority(item.id, on: now) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 34, height: 34)
                            Text(item.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .contextMenu {
                        Button(role: .destructive) {
                            model.update(\.productivity) { $0.priorities.removeAll { $0.id == item.id } }
                        } label: {
                            Label(tr("Retirer"), systemImage: "trash")
                        }
                    }
                }
                if items.count < ProductivityState.maxPriorities {
                    if !items.isEmpty { MiniDivider() }
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                            .foregroundStyle(style.cristal.strong(accentHex))
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
        model.update(\.productivity) { _ = $0.addQuickTask(title, on: Date()) }
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
    /// A touch on the line opens the item (its own editor); the round of a task or homework alone checks it off.
    var onOpen: (() -> Void)? = nil
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(item.timeText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isNow ? style.cristal.strong(item.colorHex) : Color.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 54, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(style.cristal.category(item.colorHex))
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
                        .foregroundStyle(done ? style.cristal.category(item.colorHex) : Color.secondary)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(done ? tr("Marquer comme à faire") : tr("Marquer comme fait")))
            } else {
                Image(systemName: item.symbol)
                    .font(.caption)
                    .foregroundStyle(style.cristal.category(item.colorHex))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
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
        var saved = task.normalizedForSave(hasDue: hasDue)
        saved.title = saved.title.trimmed
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

/// The two actions floating above the tab bar: « Nouvelle tâche » (filled) and « Nouvel événement » (glass). A
/// double tap runs an action once.
private struct PlanningFloatingActions: View {
    let colorHex: String
    let newTask: () -> Void
    let newEvent: () -> Void
    @State private var tapGuard = TapGuard()
    @Environment(\.appStyle) private var style
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strong = CristalPalette.of(style.id).strongHex(colorHex)
        let hex = scheme == .dark ? strong.dark : strong.light
        HStack(spacing: 10) {
            Button {
                tapGuard.run(newTask)
            } label: {
                Label(tr("Nouvelle tâche"), systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.readableInk(on: hex))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 50)
                    .background(Color(hex: hex), in: Capsule())
                    .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("planning-new-task")
            Button {
                tapGuard.run(newEvent)
            } label: {
                Label(tr("Nouvel événement"), systemImage: "calendar.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .cristalGlass(in: Capsule())
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("planning-new-event")
        }
    }
}
