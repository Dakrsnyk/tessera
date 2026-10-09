import SwiftUI

/// Everything the Studies mini-app edits in a sheet, from any of its screens.
enum StudiesSheet: Identifiable {
    case course(Course)
    case slot(ClassSlot)
    /// An entry opened from one day of the week: it can be cancelled that day only.
    case slotOn(ClassSlot, Date)
    case exam(Exam)
    case assignment(Assignment)
    case grade(Grade)
    case card(Flashcard)

    var id: String {
        switch self {
        case let .course(course): "course-\(course.id)"
        case let .slot(slot): "slot-\(slot.id)"
        case let .slotOn(slot, day): "slot-\(slot.id)-\(DateMath.dayKey(day))"
        case let .exam(exam): "exam-\(exam.id)"
        case let .assignment(assignment): "assignment-\(assignment.id)"
        case let .grade(grade): "grade-\(grade.id)"
        case let .card(card): "card-\(card.id)"
        }
    }

    @ViewBuilder
    var editor: some View {
        switch self {
        case let .course(course): CourseEditor(course: course)
        case let .slot(slot): SlotEditor(slot: slot)
        case let .slotOn(slot, day): SlotEditor(slot: slot, day: day)
        case let .exam(exam): ExamEditor(exam: exam)
        case let .assignment(assignment): AssignmentEditor(assignment: assignment)
        case let .grade(grade): GradeEditor(grade: grade)
        case let .card(card): CardEditor(card: card)
        }
    }
}

enum Studies {
    static var accentHex: String { ScheduleKind.course.colorHex }
    static let weekdayNames = [tr("Lundi"), tr("Mardi"), tr("Mercredi"), tr("Jeudi"), tr("Vendredi"), tr("Samedi"), tr("Dimanche")]

    static func minuteText(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    static func countdown(_ date: Date, from now: Date) -> String {
        let days = DateMath.daysBetween(now, date)
        switch days {
        case ..<0: return tr("passé")
        case 0: return tr("aujourd'hui")
        case 1: return tr("demain")
        default: return "J-\(days)"
        }
    }

    /// A new exam, homework or grade starts on the course being looked at, or the first one.
    static func newExam(_ state: StudentState, course: UUID? = nil, now: Date = Date()) -> Exam {
        Exam(courseID: course ?? state.courses.first?.id, title: "", date: DateMath.startOfDay(now).addingTimeInterval(7 * 86_400 + 9 * 3_600))
    }

    static func newAssignment(_ state: StudentState, course: UUID? = nil, now: Date = Date()) -> Assignment {
        Assignment(courseID: course ?? state.courses.first?.id, title: "", due: DateMath.startOfDay(now).addingTimeInterval(3 * 86_400 + 23 * 3_600 + 59 * 60))
    }

    static func newGrade(_ state: StudentState, course: UUID? = nil) -> Grade {
        Grade(courseID: course ?? state.courses.first?.id, title: "", score: 0)
    }

    /// A new entry of the schedule: a class when there are courses, another event otherwise.
    static func newSlot(_ state: StudentState, course: UUID? = nil, now: Date = Date()) -> ClassSlot {
        let courseID = course ?? state.courses.first?.id
        return ClassSlot(courseID: courseID, weekday: min(5, FitnessMath.isoWeekday(now)), startMinute: 8 * 60 + 30, endMinute: 10 * 60 + 20,
                         kind: courseID == nil ? .other : .course)
    }
}

/// The Studies mini-app: the class now or next, homework to hand in, exams coming, the average and
/// the study time; then the timetable, the courses, the grades and revision one tap away.
struct StudiesAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?

    private var accentHex: String { Studies.accentHex }

    var body: some View {
        let now = Date()
        let state = model.student
        MiniAppScroll {
            if state.courses.isEmpty && state.exams.isEmpty && state.assignments.isEmpty {
                start
            } else {
                NextClassCard(state: state, now: now)
                stats(state: state, now: now)
                StudyTimerCard()
                homework(state: state, now: now)
                exams(state: state, now: now)
                semester(state: state, now: now)
            }
            more(state: state, now: now)
        }
        .navigationTitle(tr("Études"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    // MARK: Empty

    private var start: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 30))
                .foregroundStyle(Color(hex: accentHex))
            Text(tr("Ton année en un coup d'œil"))
                .font(.title3.weight(.bold))
            Text(tr("Ajoute tes cours : ton horaire, tes devoirs, tes examens et tes notes viendront s'y ranger. Tessera calcule ensuite tes moyennes et ce qu'il te reste à faire."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            MiniActionButton(title: tr("Ajouter un cours"), symbol: "plus", colorHex: accentHex) {
                sheet = .course(Course(name: ""))
            }
            .accessibilityIdentifier("studies-add-course")
        }
        .card()
    }

    // MARK: Figures

    private func stats(state: StudentState, now: Date) -> some View {
        let studied = StudentMath.studyMinutes(state, weekOf: now)
        let due = StudentMath.dueCount(state, at: now)
        return HStack(spacing: 10) {
            NavigationLink(value: HomeRoute.page(.studiesGrades)) {
                MiniStat(title: tr("Moyenne"), value: StudentMath.overallAverage(state).map { "\(TF.decimal($0, 1)) %" } ?? "–",
                         detail: state.grades.isEmpty ? tr("aucune note") : Fmt.plural(state.grades.count, tr("note"), tr("notes")))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("studies-average")
            NavigationLink(value: HomeRoute.page(.studiesRevision)) {
                MiniStat(title: tr("Étude"), value: Fmt.minutes(studied), detail: tr("sur \(Fmt.hours(state.weeklyStudyGoalHours))"),
                         colorHex: studied >= state.weeklyStudyGoalHours * 60 ? "1E9E75" : nil)
            }
            .buttonStyle(.plain)
            if !state.cards.isEmpty {
                NavigationLink(value: HomeRoute.page(.studiesRevision)) {
                    MiniStat(title: tr("Fiches"), value: "\(due)", detail: due == 0 ? tr("à jour") : tr("à réviser"), colorHex: due > 0 ? accentHex : nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Homework

    @ViewBuilder
    private func homework(state: StudentState, now: Date) -> some View {
        let open = StudentMath.openAssignments(state)
        if !open.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("À rendre"), detail: Fmt.plural(open.count, tr("devoir"), tr("devoirs")))
                VStack(spacing: 0) {
                    ForEach(open.prefix(3)) { assignment in
                        AssignmentRow(assignment: assignment, state: state, now: now) { sheet = .assignment(assignment) }
                        Divider()
                    }
                    NavigationLink(value: HomeRoute.page(.studiesAssignments)) {
                        HStack {
                            Text(open.count > 3 ? tr("Voir les \(open.count) devoirs") : tr("Tous les devoirs"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(hex: accentHex))
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("studies-assignments")
                }
                .padding(.horizontal, 14)
                .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    // MARK: Exams

    @ViewBuilder
    private func exams(state: StudentState, now: Date) -> some View {
        let upcoming = StudentMath.upcomingExams(state, at: now)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Examens"))
                NavigationLink(value: HomeRoute.page(.studiesExams)) {
                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.prefix(2).enumerated()), id: \.element.id) { index, exam in
                            if index > 0 { Divider() }
                            ExamRow(exam: exam, state: state, now: now)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("studies-exams")
            }
        }
    }

    // MARK: Semester

    @ViewBuilder
    private func semester(state: StudentState, now: Date) -> some View {
        if let progress = StudentMath.semesterProgress(state, at: now), let end = state.semesterEnd {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("Session")).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(tr("\(Fmt.percent(progress)) · fin \(Fmt.shortDay(end))"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress).tint(Color(hex: accentHex))
            }
            .card(padding: 14)
        }
    }

    // MARK: More

    private func more(state: StudentState, now: Date) -> some View {
        let groups = StudentMath.assignmentGroups(state, at: now)
        let weekly = state.slots.filter { $0.date == nil }
        return MiniRowsCard {
            NavigationLink(value: HomeRoute.page(.studiesTimetable)) {
                MiniRow(symbol: "calendar.day.timeline.left", colorHex: accentHex, title: tr("Horaire"),
                        detail: weekly.isEmpty ? tr("Tes cours de la semaine") : tr("\(Fmt.plural(weekly.count, tr("cours", context: "one"), tr("cours"))) par semaine"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("studies-timetable")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.studiesCourses)) {
                MiniRow(symbol: "books.vertical.fill", colorHex: accentHex, title: tr("Cours"), detail: tr("Moyennes, horaire et devoirs par cours"),
                        value: state.courses.isEmpty ? nil : "\(state.courses.count)")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("studies-courses")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.studiesAssignments)) {
                MiniRow(symbol: "doc.text.fill", colorHex: "F2A33A", title: tr("Devoirs"),
                        detail: groups.late.isEmpty ? tr("À rendre, rendus") : tr("\(groups.late.count) en retard"),
                        value: groups.isEmpty ? nil : "\(groups.late.count + groups.thisWeek.count + groups.later.count)")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.studiesExams)) {
                MiniRow(symbol: "pencil.and.list.clipboard", colorHex: "E5484D", title: tr("Examens"), detail: tr("Compte à rebours et préparation"),
                        value: StudentMath.upcomingExams(state, at: now).isEmpty ? nil : "\(StudentMath.upcomingExams(state, at: now).count)")
            }
            .buttonStyle(.plain)
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.studiesGrades)) {
                MiniRow(symbol: "chart.bar.fill", colorHex: "3366FF", title: tr("Notes"), detail: tr("Moyennes et ce qu'il te faut pour ton objectif"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("studies-grades")
            MiniDivider()
            NavigationLink(value: HomeRoute.page(.studiesRevision)) {
                MiniRow(symbol: "rectangle.on.rectangle.angled", colorHex: "8C6CFF", title: tr("Révisions"), detail: tr("Temps d'étude et fiches"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("studies-revision")
        }
    }
}

// MARK: - Shared pieces

/// The class in progress or the next one, with its room and the homework of that course.
struct NextClassCard: View {
    let state: StudentState
    let now: Date

    var body: some View {
        if let next = StudentMath.nextClass(state, at: now) {
            let course = state.course(next.slot.courseID)
            let hex = course?.colorHex ?? Studies.accentHex
            let isNow = next.start <= now
            NavigationLink(value: course.map { HomeRoute.page(.studiesCourse($0.id)) } ?? HomeRoute.page(.studiesTimetable)) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(isNow ? tr("En cours") : tr("Prochain cours"), systemImage: isNow ? "dot.radiowaves.left.and.right" : "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: hex))
                    Text(course?.name ?? tr("Cours"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(detail(next))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if isNow {
                        ProgressView(value: now.timeIntervalSince(next.start), total: max(1, next.end.timeIntervalSince(next.start)))
                            .tint(Color(hex: hex))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(hex: hex).opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("studies-next-class")
        }
    }

    private func detail(_ next: StudentMath.ClassOccurrence) -> String {
        var parts: [String] = []
        if next.start <= now {
            parts.append(tr("jusqu'à \(Fmt.time(next.end, uses24Hour: true))"))
        } else if DateMath.isSameDay(next.start, now) {
            parts.append("\(Fmt.time(next.start, uses24Hour: true))–\(Fmt.time(next.end, uses24Hour: true))")
        } else {
            parts.append("\(TF.relativeDay(next.start, from: now).capitalizedFirst) à \(Fmt.time(next.start, uses24Hour: true))")
        }
        if !next.slot.room.isEmpty { parts.append(tr("salle \(next.slot.room)")) }
        if let teacher = state.course(next.slot.courseID)?.teacher, !teacher.isEmpty { parts.append(teacher) }
        return parts.joined(separator: " · ")
    }
}

/// A piece of homework, checked off right here.
struct AssignmentRow: View {
    let assignment: Assignment
    let state: StudentState
    let now: Date
    let onEdit: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        let late = !assignment.isDone && assignment.due < now
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                withAnimation { model.update(\.student) { $0.toggleAssignment(assignment.id) } }
            } label: {
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(assignment.isDone ? Color(hex: Studies.accentHex) : Color(hex: state.course(assignment.courseID)?.colorHex ?? "8A8A8E"))
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("assignment-toggle")
            .accessibilityLabel(Text(assignment.isDone ? tr("Marquer comme à rendre") : tr("Marquer comme rendu")))
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(assignment.title)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(assignment.isDone)
                        .foregroundStyle(assignment.isDone ? Color.secondary : Color.primary)
                    Text(state.course(assignment.courseID).map { "\($0.name) · \(dueText)" } ?? dueText)
                        .font(.caption)
                        .foregroundStyle(late ? Color(hex: "E5484D") : Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 10)
    }

    private var dueText: String {
        let day = TF.relativeDay(assignment.due, from: now)
        let calendar = DateMath.calendar
        let hour = calendar.component(.hour, from: assignment.due)
        let minute = calendar.component(.minute, from: assignment.due)
        if hour == 23 && minute == 59 { return day }
        return "\(day) à \(Fmt.time(assignment.due, uses24Hour: true))"
    }
}

/// An exam with its countdown and the time studied for that course in the last two weeks.
struct ExamRow: View {
    let exam: Exam
    let state: StudentState
    let now: Date

    var body: some View {
        let course = state.course(exam.courseID)
        let days = DateMath.daysBetween(now, exam.date)
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(days <= 0 ? "Auj." : "J-\(days)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(days <= 3 ? Color(hex: "E5484D") : Color(hex: course?.colorHex ?? Studies.accentHex))
                    .monospacedDigit()
            }
            .frame(width: 52, height: 44)
            .background((days <= 3 ? Color(hex: "E5484D") : Color(hex: course?.colorHex ?? Studies.accentHex)).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(exam.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(detail(course: course))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 10)
    }

    private func detail(course: Course?) -> String {
        var parts = [Fmt.shortDay(exam.date) + " à " + Fmt.time(exam.date, uses24Hour: true)]
        if !exam.room.isEmpty { parts.append(exam.room) }
        if let course, exam.date > now {
            let studied = StudentMath.studyMinutes(state, course: course.id, from: now.addingTimeInterval(-14 * 86_400), to: now)
            if studied > 0 { parts.append(tr("\(Fmt.minutes(Double(studied))) révisé")) }
        }
        return parts.joined(separator: " · ")
    }
}

/// The study timer: start it for a course, stop it and the time is added to the week.
struct StudyTimerCard: View {
    @Environment(AppModel.self) private var model
    @State private var logged: Int?

    private var accentHex: String { Studies.accentHex }

    var body: some View {
        let state = model.student
        VStack(alignment: .leading, spacing: 12) {
            if let began = state.timerStart {
                HStack(alignment: .firstTextBaseline) {
                    Label(state.course(state.timerCourseID)?.name ?? tr("Étude"), systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                    Spacer()
                    TimelineView(.periodic(from: began, by: 1)) { context in
                        Text(elapsed(from: began, to: context.date))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                    }
                }
                MiniActionButton(title: tr("Terminer et noter"), symbol: "stop.fill", colorHex: accentHex) {
                    var minutes = 0
                    model.update(\.student) { minutes = $0.stopTimer() }
                    Haptics.success()
                    logged = minutes
                }
                .accessibilityIdentifier("studies-timer-stop")
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Chrono d'étude")).font(.subheadline.weight(.semibold))
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Menu {
                        Button(tr("Sans cours précis")) { start(nil) }
                        ForEach(state.courses) { course in
                            Button(course.name) { start(course.id) }
                        }
                    } label: {
                        Label(tr("Démarrer"), systemImage: "play.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color(hex: accentHex), in: Capsule())
                    }
                    .accessibilityIdentifier("studies-timer-start")
                }
            }
        }
        .card(padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("studies-timer")
    }

    private var hint: String {
        guard let logged else { return tr("Lance-le quand tu t'y mets, le temps s'ajoute à ta semaine.") }
        return logged > 0 ? tr("\(Fmt.minutes(Double(logged))) ajoutées à ta semaine") : tr("Moins d'une minute : rien n'a été noté")
    }

    private func start(_ course: UUID?) {
        Haptics.tap()
        logged = nil
        model.update(\.student) { $0.startTimer(courseID: course) }
    }

    private func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
