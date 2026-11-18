import SwiftUI

// Direction 5 « Hybride » of Études (2026-11-17): the « Échéances » page, the history of the study sessions and the
// small calculations behind them. Nothing here changes the format of what is saved.

/// One date to come: an exam, a piece of homework or the end of the session.
struct StudyDeadline: Identifiable, Hashable {
    enum Kind: Hashable {
        case exam(UUID)
        case assignment(UUID)
        case session
    }

    let kind: Kind
    let date: Date

    var id: String {
        switch kind {
        case let .exam(id): "exam-\(id)"
        case let .assignment(id): "assignment-\(id)"
        case .session: "session"
        }
    }

    var isExam: Bool { if case .exam = kind { return true } else { return false } }
    var isAssignment: Bool { if case .assignment = kind { return true } else { return false } }
}

extension Studies {
    /// Exams to come, homework still to hand in (late ones too) and the end of the session, the nearest date first.
    static func deadlines(_ state: StudentState, at now: Date) -> [StudyDeadline] {
        var list: [StudyDeadline] = []
        for exam in StudentMath.upcomingExams(state, at: now) { list.append(StudyDeadline(kind: .exam(exam.id), date: exam.date)) }
        for assignment in StudentMath.openAssignments(state) { list.append(StudyDeadline(kind: .assignment(assignment.id), date: assignment.due)) }
        if let end = state.semesterEnd, DateMath.startOfDay(end) >= DateMath.startOfDay(now) {
            list.append(StudyDeadline(kind: .session, date: end))
        }
        return list.sorted { $0.date < $1.date }
    }

    /// The dates split like the « Devoirs » page: late (homework only), within seven days, later.
    static func deadlineGroups(_ list: [StudyDeadline], at now: Date) -> (late: [StudyDeadline], thisWeek: [StudyDeadline], later: [StudyDeadline]) {
        var late: [StudyDeadline] = []
        var week: [StudyDeadline] = []
        var later: [StudyDeadline] = []
        let limit = now.addingTimeInterval(7 * 86_400)
        for item in list {
            if item.isAssignment && item.date < now { late.append(item) } else if item.date <= limit { week.append(item) } else { later.append(item) }
        }
        return (late, week, later)
    }

    /// The badge of an exam: « J-4 », or « Auj. » on the day itself.
    static func examBadge(daysLeft days: Int) -> String {
        days <= 0 ? tr("Auj.") : tr("J-\(days)")
    }

    /// Revision time of an exam: what the course got in the last 14 days, against the goal set on the exam.
    /// Nil without a course or without a goal.
    static func examPreparation(_ state: StudentState, exam: Exam, now: Date) -> (studied: Int, goal: Int)? {
        guard let course = exam.courseID, let goal = exam.studyGoalMinutes, goal > 0 else { return nil }
        let studied = StudentMath.studyMinutes(state, course: course, from: now.addingTimeInterval(-14 * 86_400), to: now)
        return (studied, goal)
    }

    /// Which kinds of date fall on a day (for the dots of the calendar).
    static func marks(on day: Date, in list: [StudyDeadline]) -> (exam: Bool, assignment: Bool, session: Bool) {
        var exam = false, assignment = false, session = false
        for item in list where DateMath.isSameDay(item.date, day) {
            switch item.kind {
            case .exam: exam = true
            case .assignment: assignment = true
            case .session: session = true
            }
        }
        return (exam, assignment, session)
    }
}

extension StudentState {
    /// Removes one noted study session (a « +25 min » added by mistake).
    mutating func removeSession(_ session: StudySession) {
        if let index = sessions.firstIndex(of: session) { sessions.remove(at: index) }
    }

    /// Corrects the minutes of a noted session (a minute at least, four hours at most, like the timer).
    mutating func updateSession(_ session: StudySession, minutes: Int) {
        guard let index = sessions.firstIndex(of: session) else { return }
        sessions[index].minutes = min(240, max(1, minutes))
    }
}

// MARK: - A row of the dates to come

/// An exam, a piece of homework or the end of the session, in a card of rows.
struct StudyDeadlineRow: View {
    let deadline: StudyDeadline
    let state: StudentState
    let now: Date
    let open: (StudiesSheet) -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        switch deadline.kind {
        case let .exam(id):
            if let exam = state.exams.first(where: { $0.id == id }) {
                Button { open(.exam(exam)) } label: { ExamRow(exam: exam, state: state, now: now) }
                    .buttonStyle(.pressable)
            }
        case let .assignment(id):
            if let assignment = state.assignments.first(where: { $0.id == id }) {
                AssignmentRow(assignment: assignment, state: state, now: now) { open(.assignment(assignment)) }
            }
        case .session:
            if let end = state.semesterEnd {
                NavigationLink(value: HomeRoute.page(.studiesCourses)) {
                    MiniRow(symbol: "calendar", colorHex: Studies.accentHex, title: tr("Session"), detail: tr("Fin le \(Fmt.shortDay(end))"),
                            value: StudentMath.semesterProgress(state, at: now).map { Fmt.percent($0) })
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

// MARK: - Échéances

/// Exams, homework and the end of the session in one place: three weeks of calendar, then the dates by group.
struct StudiesDeadlinesPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var sheet: StudiesSheet?
    @State private var filter = Filter.all

    enum Filter: String, CaseIterable, Identifiable {
        case all, exams, assignments
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: tr("Tout")
            case .exams: tr("Examens")
            case .assignments: tr("Devoirs")
            }
        }

        func accepts(_ item: StudyDeadline) -> Bool {
            switch self {
            case .all: true
            case .exams: item.isExam
            case .assignments: item.isAssignment
            }
        }
    }

    var body: some View {
        let state = model.student
        let now = Date()
        let all = Studies.deadlines(state, at: now)
        let shown = all.filter { filter.accepts($0) }
        let groups = Studies.deadlineGroups(shown, at: now)
        MiniAppScroll {
            Picker(tr("Afficher"), selection: $filter) {
                ForEach(Filter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("deadlines-filter")
            calendar(all, now: now)
            group(tr("En retard"), groups.late, state: state, now: now)
            group(tr("Cette semaine"), groups.thisWeek, state: state, now: now)
            group(tr("Plus tard"), groups.later, state: state, now: now)
            if shown.isEmpty {
                Text(tr("Rien à venir pour l'instant."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            HStack(spacing: 10) {
                MiniActionButton(title: tr("Nouvel examen"), symbol: "plus", colorHex: Studies.accentHex, isProminent: false) {
                    sheet = .exam(Studies.newExam(state))
                }
                .accessibilityIdentifier("deadlines-new-exam")
                MiniActionButton(title: tr("Nouveau devoir"), symbol: "plus", colorHex: Studies.accentHex, isProminent: false) {
                    sheet = .assignment(Studies.newAssignment(state))
                }
                .accessibilityIdentifier("deadlines-new-assignment")
            }
            // The existing page of the exams (countdown, passed ones, delete by long press).
            MiniRowsCard {
                NavigationLink(value: HomeRoute.page(.studiesExams)) {
                    MiniRow(symbol: "pencil.and.list.clipboard", colorHex: MiniStyle.alertHex, title: tr("Examens"), detail: tr("Compte à rebours et préparation"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("deadlines-exams-page")
            }
        }
        .navigationTitle(tr("Échéances"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [StudyDeadline], state: StudentState, now: Date) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: title, detail: "\(items.count)")
                MiniRowsCard {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        StudyDeadlineRow(deadline: item, state: state, now: now) { sheet = $0 }
                    }
                }
            }
        }
    }

    /// Three weeks from this Monday: a day with an exam gets a red dot, a day with homework an amber one.
    private func calendar(_ all: [StudyDeadline], now: Date) -> some View {
        let monday = DateMath.week(containing: now).first ?? DateMath.startOfDay(now)
        let days = (0..<21).compactMap { DateMath.calendar.date(byAdding: .day, value: $0, to: monday) }
        let letters = DateMath.weekdaySymbols()
        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<3, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(days.dropFirst(week * 7).prefix(7), id: \.self) { day in
                        dayCell(day, all: all, now: now)
                    }
                }
            }
            HStack(spacing: 14) {
                legend(MiniStyle.alertHex, tr("Examen"))
                legend("F2A33A", tr("Devoir"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .padding(14)
        .miniCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deadlines-calendar")
    }

    private func dayCell(_ day: Date, all: [StudyDeadline], now: Date) -> some View {
        let marks = Studies.marks(on: day, in: all)
        let isToday = DateMath.isSameDay(day, now)
        return VStack(spacing: 3) {
            Text("\(DateMath.calendar.component(.day, from: day))")
                .font(.subheadline.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? style.onAccent : Color.primary)
                .frame(width: 30, height: 30)
                .background(isToday ? style.cristal.strong(Studies.accentHex) : Color.clear, in: Circle())
            HStack(spacing: 3) {
                Circle().fill(style.cristal.strong(MiniStyle.alertHex)).frame(width: 5, height: 5).opacity(marks.exam ? 1 : 0)
                Circle().fill(style.cristal.strong("F2A33A")).frame(width: 5, height: 5).opacity(marks.assignment ? 1 : 0)
                Circle().fill(style.cristal.strong(Studies.accentHex)).frame(width: 5, height: 5).opacity(marks.session ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legend(_ hex: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(style.cristal.strong(hex)).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Historique des sessions

/// Every study session noted (the timer, « +25 min »): corrected or removed, so an addition made by mistake can go.
struct StudiesHistoryPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var editing: StudySession?

    var body: some View {
        let state = model.student
        let list = state.sessions.sorted { $0.date > $1.date }
        List {
            if list.isEmpty {
                Text(tr("Aucune session notée pour l'instant. Le chrono et les boutons « +25 min » en ajoutent."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(list.enumerated()), id: \.offset) { _, session in
                Button { editing = session } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.course(session.courseID)?.name ?? tr("Étude"))
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(Fmt.shortDay(session.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.minutes(Double(session.minutes)))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        Haptics.tap()
                        model.update(\.student) { $0.removeSession(session) }
                    } label: {
                        Label(tr("Supprimer"), systemImage: "trash")
                    }
                }
            }
        }
        .styledList()
        .tint(style.cristal.strong(Studies.accentHex))
        .navigationTitle(tr("Historique des sessions"))
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("studies-history")
        .sheet(item: $editing) { StudySessionEditor(session: $0) }
    }
}

extension StudySession: Identifiable {
    /// Two sessions noted at the same second with the same minutes and course are the same to the history.
    var id: String { "\(date.timeIntervalSince1970)-\(minutes)-\(courseID?.uuidString ?? "")" }
}

/// Corrects the minutes of one noted session.
struct StudySessionEditor: View {
    @Environment(AppModel.self) private var model
    let session: StudySession
    @State private var minutes: Int

    init(session: StudySession) {
        self.session = session
        _minutes = State(initialValue: session.minutes)
    }

    var body: some View {
        SheetForm(title: tr("Session d'étude"), canSave: minutes >= 1, onSave: save) {
            Stepper(value: $minutes, in: 1...240, step: 5) {
                Text(Fmt.minutes(Double(minutes))).monospacedDigit()
            }
            .accessibilityIdentifier("session-minutes")
        }
    }

    private func save() {
        let original = session
        let value = minutes
        model.update(\.student) { $0.updateSession(original, minutes: value) }
    }
}
