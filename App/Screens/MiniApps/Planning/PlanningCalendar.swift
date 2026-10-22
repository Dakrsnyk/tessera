import SwiftUI

/// How much of time the Planning shows: a day hour by hour, the week, the month or the year.
enum CalendarScale: Int, CaseIterable, Identifiable {
    case day, week, month, year
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .day: tr("Jour")
        case .week: tr("Semaine")
        case .month: tr("Mois")
        case .year: tr("Année")
        }
    }

    /// The unit the arrows and a swipe move by.
    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// Pinching in shows less time, in more detail; pinching out, more time.
    var closer: CalendarScale? { CalendarScale(rawValue: rawValue - 1) }
    var wider: CalendarScale? { CalendarScale(rawValue: rawValue + 1) }

    /// The span of time shown around a day.
    func interval(containing day: Date) -> DateInterval {
        DateMath.calendar.dateInterval(of: component, for: day) ?? DateInterval(start: DateMath.startOfDay(day), duration: 86_400)
    }

    /// What a pinch did: a clear spread zooms in, a clear pinch zooms out, anything in between nothing.
    static func step(for magnification: CGFloat) -> Int {
        if magnification > 1.3 { return -1 }
        if magnification < 0.77 { return 1 }
        return 0
    }
}

/// The Planning's calendar: a day, the week, the month or the year, at the chosen day. A pinch with two
/// fingers goes from one scale to the next (spread: closer, pinch: wider) and keeps the day looked at;
/// the buttons above do the same for whoever prefers them. A touch on a free time of a day or of the week
/// creates an event there; a touch on a day of the month or a month of the year goes to it.
struct PlanningCalendarCard: View {
    @Binding var day: Date
    @Binding var scale: CalendarScale
    let events: [EventSnapshot]
    let onCreate: (Date, Int) -> Void
    let onOpen: (AgendaItem) -> Void
    @Environment(AppModel.self) private var model
    @State private var pinch: CGFloat = 1
    @State private var isPinching = false

    private var accentHex: String { MiniApp.planning.colorHex }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Picker(tr("Échelle"), selection: Binding(get: { scale }, set: { change(to: $0) })) {
                ForEach(CalendarScale.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("planning-scale")
            content
                .scaleEffect(isPinching ? min(1.12, max(0.88, pinch)) : 1, anchor: .center)
                .opacity(isPinching ? 0.85 : 1)
                .id("\(scale.rawValue)-\(DateMath.dayKey(scale.interval(containing: day).start))")
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                .simultaneousGesture(magnify)
                .simultaneousGesture(swipe)
            MiniFootnote(text: hint)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("planning-calendar")
    }

    // MARK: Header

    /// Calendar's head: the period big and bold on the left, « Aujourd'hui » and the arrows discreet on the right.
    private var header: some View {
        let now = Date()
        let isCurrent = scale.interval(containing: day).contains(now)
        return HStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if !isCurrent {
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { day = now }
                } label: {
                    Text(tr("Aujourd'hui"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 40, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(Text(tr("Période précédente")))
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold)).frame(width: 40, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(Text(tr("Période suivante")))
            .accessibilityIdentifier("planning-next")
        }
        .tint(Color(hex: accentHex))
    }

    /// The period, big: the month and year for the week and the month (as in Calendar), the day in full for the day.
    private var title: String {
        switch scale {
        case .day: Fmt.longDay(day)
        case .week, .month: Fmt.monthYear(day)
        case .year: "\(DateMath.calendar.component(.year, from: day))"
        }
    }

    private var hint: String {
        switch scale {
        case .day, .week: tr("Touche une heure libre pour créer un événement. Pince avec deux doigts pour voir plus ou moins de temps.")
        case .month: tr("Touche un jour pour le voir en détail. Écarte deux doigts pour zoomer, pince pour voir l'année.")
        case .year: tr("Touche un mois pour l'ouvrir. Écarte deux doigts pour zoomer.")
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch scale {
        case .day:
            WeekTimetable(days: [(day: day, items: Agenda.items(on: day, model: model, events: events))], selected: day, hourHeight: 52, hours: 6...22,
                          onCreate: create, onOpen: onOpen, accent: Color(hex: accentHex))
                .card(padding: 10)
        case .week:
            WeekTimetable(days: Agenda.week(containing: day, model: model, events: events), selected: day,
                          onSelect: { picked in withAnimation(.snappy) { day = picked } },
                          onCreate: create, onOpen: onOpen, accent: Color(hex: accentHex))
                .card(padding: 10)
        case .month:
            monthGrid
        case .year:
            yearGrid
        }
    }

    private var monthGrid: some View {
        PlanningMonthGrid(month: day, selected: day, accent: Color(hex: accentHex),
                          items: { Agenda.items(on: $0, model: model, events: events) },
                          onPick: { date in
                              guard !isPinching else { return }
                              Haptics.tap()
                              day = date
                              change(to: .day)
                          })
            .card(padding: 12)
            .accessibilityIdentifier("planning-month-grid")
    }

    private var yearGrid: some View {
        let calendar = DateMath.calendar
        let year = calendar.component(.year, from: day)
        let marked = PlanningCalendar.markedDays(year: year, model: model, events: events)
        let months = (1...12).compactMap { calendar.date(from: DateComponents(year: year, month: $0, day: 1)) }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
            ForEach(months, id: \.self) { month in
                Button {
                    guard !isPinching else { return }
                    Haptics.tap()
                    let sameDay = calendar.date(bySetting: .month, value: calendar.component(.month, from: month), of: day)
                    day = sameDay.map { calendar.component(.year, from: $0) == year ? $0 : month } ?? month
                    change(to: .month)
                } label: {
                    MiniMonth(month: month, marked: marked, accentHex: accentHex,
                              isCurrent: calendar.isDate(month, equalTo: Date(), toGranularity: .month))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Fmt.monthYear(month)))
            }
        }
        .card(padding: 12)
        .accessibilityIdentifier("planning-year-grid")
    }

    // MARK: Actions

    private func create(_ date: Date, _ minute: Int) {
        // Never while two fingers zoom.
        guard !isPinching else { return }
        Haptics.tap()
        onCreate(date, minute)
    }

    private func change(to newScale: CalendarScale) {
        guard newScale != scale else { return }
        Haptics.tap()
        withAnimation(.snappy(duration: 0.32)) { scale = newScale }
    }

    private func shift(_ amount: Int) {
        Haptics.tap()
        withAnimation(.snappy) {
            day = DateMath.calendar.date(byAdding: scale.component, value: amount, to: day) ?? day
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.04)
            .onChanged { value in
                isPinching = true
                pinch = value.magnification
            }
            .onEnded { value in
                switch CalendarScale.step(for: value.magnification) {
                case -1: if let closer = scale.closer { change(to: closer) }
                case 1: if let wider = scale.wider { change(to: wider) }
                default: break
                }
                withAnimation(.snappy) { pinch = 1 }
                // A touch lifted right after the pinch must not create anything.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    isPinching = false
                }
            }
    }

    /// A clear horizontal swipe: the period before or after (not while zooming).
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard !isPinching else { return }
                let dx = value.translation.width
                guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.6 else { return }
                shift(dx < 0 ? 1 : -1)
            }
    }
}

/// A month of the year view: its days, marked when something happens once that day (an event, an
/// exam, a deadline, a task due), the weekly schedule left out so the year stays readable.
private struct MiniMonth: View {
    let month: Date
    let marked: Set<String>
    let accentHex: String
    let isCurrent: Bool

    var body: some View {
        let cells = DateMath.monthGrid(for: month)
        let accent = Color(hex: accentHex)
        VStack(alignment: .leading, spacing: 4) {
            // The month's name in the accent for the current one, as in Calendar's year.
            Text(Fmt.month(month))
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isCurrent ? accent : Color.primary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isMarked = marked.contains(DateMath.dayKey(date))
                        let isToday = DateMath.isSameDay(date, Date())
                        // Very small on purpose: the whole month is one touch, read by its name.
                        Text("\(DateMath.calendar.component(.day, from: date))")
                            .font(.system(size: 8, weight: isMarked || isToday ? .bold : .regular))
                            .monospacedDigit()
                            .foregroundStyle(isToday ? Color.white : (isMarked ? accent : Color.secondary))
                            .frame(maxWidth: .infinity, minHeight: 11)
                            .background(isToday ? accent : Color.clear, in: Circle())
                    } else {
                        Color.clear.frame(minHeight: 11)
                    }
                }
            }
            .accessibilityHidden(true)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(isCurrent ? Color(hex: accentHex).opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// A month as a grid, Calendar's way: the days' numbers, today in a filled circle of the accent, the day
/// picked ringed, up to three small dots under a number (the colors of what that day holds), the days of the
/// neighbouring months in grey. A touch on a day goes to `onPick`.
struct PlanningMonthGrid: View {
    /// Any date of the month shown.
    let month: Date
    let selected: Date
    let accent: Color
    let items: (Date) -> [AgendaItem]
    let onPick: (Date) -> Void

    /// A cell of the grid; `inMonth` is false for the days of the weeks that straddle the month.
    struct MonthDay: Identifiable {
        let date: Date
        let inMonth: Bool
        var id: Date { date }
    }

    var body: some View {
        let now = Date()
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(DateMath.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Self.days(for: month)) { entry in
                    cell(entry, now: now)
                }
            }
        }
    }

    /// The month's days with the days of the neighbouring months that fill its first and last weeks.
    static func days(for month: Date) -> [MonthDay] {
        let calendar = DateMath.calendar
        let cells = DateMath.monthGrid(for: month)
        guard let anchorIndex = cells.firstIndex(where: { $0 != nil }), let anchor = cells[anchorIndex] else { return [] }
        return cells.indices.compactMap { index -> MonthDay? in
            if let date = cells[index] { return MonthDay(date: date, inMonth: true) }
            guard let date = calendar.date(byAdding: .day, value: index - anchorIndex, to: anchor) else { return nil }
            return MonthDay(date: date, inMonth: false)
        }
    }

    private func cell(_ entry: MonthDay, now: Date) -> some View {
        let date = entry.date
        let list = items(date)
        let isSelected = DateMath.isSameDay(date, selected)
        let isToday = DateMath.isSameDay(date, now)
        let ink: Color = isToday ? Color.white : (entry.inMonth ? Color.primary : Color.secondary.opacity(0.7))
        return Button {
            onPick(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(DateMath.calendar.component(.day, from: date))")
                    .font(.callout.weight(isToday || isSelected ? .bold : .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(ink)
                    .frame(width: 32, height: 32)
                    .background(isToday ? accent : Color.clear, in: Circle())
                    .overlay {
                        if isSelected {
                            Circle().strokeBorder(accent, lineWidth: 2).frame(width: 36, height: 36)
                        }
                    }
                HStack(spacing: 2) {
                    ForEach(Array(list.prefix(3).enumerated()), id: \.offset) { _, item in
                        Circle().fill(Color(hex: item.colorHex)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
                .opacity(entry.inMonth ? 1 : 0.45)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Fmt.longDay(date)))
        .accessibilityValue(Text(list.isEmpty ? tr("Libre") : Fmt.plural(list.count, tr("élément"), tr("éléments"))))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// What the calendar needs beyond one day at a time.
@MainActor
enum PlanningCalendar {
    /// The days of a year with something that happens once: events of the calendar, events of the schedule
    /// on a date, exams, homework, tasks due and deadlines.
    static func markedDays(year: Int, model: AppModel, events: [EventSnapshot]) -> Set<String> {
        let calendar = DateMath.calendar
        func inYear(_ date: Date) -> Bool { calendar.component(.year, from: date) == year }
        var keys = Set<String>()
        for event in events where inYear(event.start) { keys.insert(DateMath.dayKey(event.start)) }
        for slot in model.student.slots { if let date = slot.date, inYear(date) { keys.insert(DateMath.dayKey(date)) } }
        for exam in model.student.exams where inYear(exam.date) { keys.insert(DateMath.dayKey(exam.date)) }
        for assignment in model.student.assignments where inYear(assignment.due) { keys.insert(DateMath.dayKey(assignment.due)) }
        for task in model.content.tasks { if let due = task.due, inYear(due) { keys.insert(DateMath.dayKey(due)) } }
        for deadline in model.productivity.deadlines where inYear(deadline.date) { keys.insert(DateMath.dayKey(deadline.date)) }
        return keys
    }

    /// The calendar events to read for what is shown (the whole year when it is shown, else the month
    /// around the day, enough for the week and the day too).
    static func range(for scale: CalendarScale, day: Date) -> DateInterval {
        let calendar = DateMath.calendar
        let interval = scale == .year ? scale.interval(containing: day) : CalendarScale.month.interval(containing: day)
        // The weeks that straddle the month.
        let start = calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start
        let end = calendar.date(byAdding: .day, value: 7, to: interval.end) ?? interval.end
        return DateInterval(start: start, end: end)
    }

    /// Something of the schedule overlapping a time of a day (the slot itself left out), for the editor.
    static func conflicts(_ slot: ClassSlot, on day: Date, model: AppModel, events: [EventSnapshot]) -> [AgendaItem] {
        guard slot.endMinute > slot.startMinute else { return [] }
        return Agenda.items(on: day, model: model, events: events).filter { item in
            guard let start = item.start, item.slotID != slot.id else { return false }
            let from = DateMath.minuteOfDay(start)
            let to = WeekTimetable.end(item)
            return from < slot.endMinute && to > slot.startMinute
        }
    }
}
