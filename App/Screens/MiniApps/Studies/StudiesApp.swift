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
        default: return tr("J-\(days)")
        }
    }

    /// A new exam, homework or grade starts on the course being looked at, or the first one.
    static func newExam(_ state: StudentState, course: UUID? = nil, now: Date = Date()) -> Exam {
        Exam(courseID: course ?? state.courses.first?.id, title: "", date: DateMath.date(on: DateMath.calendar.date(byAdding: .day, value: 7, to: now) ?? now, minute: 9 * 60))
    }

    static func newAssignment(_ state: StudentState, course: UUID? = nil, now: Date = Date()) -> Assignment {
        Assignment(courseID: course ?? state.courses.first?.id, title: "", due: DateMath.date(on: DateMath.calendar.date(byAdding: .day, value: 3, to: now) ?? now, minute: 23 * 60 + 59))
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

/// The Études mini-app (direction 5 « Hybride », 2026-11-17): « what comes, then the work ». Header: the next exam
/// as a countdown (« J-4 »), the class now or next and the figures (average, study time, cards). Sheet, top to
/// bottom: « À venir » (exams, homework and the end of the session by date; « Tout voir » opens « Échéances »),
/// « Mes cours » (one list; « Tout voir » opens the page of the courses), « Organisation étudiante » (timetable,
/// homework, grades, revision, focus), « Mes paramètres » last. The study timer is the floating action.
struct StudiesAppView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?
    /// The sheet that reads a photo or a PDF of the timetable (the courses it finds join « Mes cours »).
    @State private var importingSchedule = false
    /// The course a menu asked to delete, until confirmed.
    @State private var deletingCourse: Course?
    /// The choice of the course the floating « Démarrer le chrono » asks for.
    @State private var choosingTimerCourse = false
    @Environment(\.appStyle) private var style

    private var accentHex: String { MiniApp.studies.colorHex }

    var body: some View {
        let now = Date()
        let state = model.student
        let fresh = state.courses.isEmpty && state.exams.isEmpty && state.assignments.isEmpty
        MiniAppScaffold(colorHex: accentHex, action: timerAction(state)) {
            if fresh {
                start
            } else {
                // A timer in progress sits on top, with its « Annuler » and « Terminer et noter ».
                if state.timerStart != nil { StudyTimerCard() }
                if let exam = StudentMath.upcomingExams(state, at: now).first { examHero(exam, state: state, now: now) }
                NextClassCard(state: state, now: now)
                stats(state: state, now: now)
            }
        } sheet: {
            MiniAppToFillSection(app: .studies)
            if !fresh {
                upcoming(state: state, now: now)
                courses(state: state, now: now)
            }
            organisation(state: state, now: now)
            MiniAppInfoSection(app: .studies)
        }
        .navigationTitle(tr("Études"))
        .miniAppTour(.studies)
        .sheet(item: $sheet) { $0.editor }
        .sheet(isPresented: $importingSchedule) { ScheduleImportView() }
        .confirmationDialog(tr("Chrono d'étude"), isPresented: $choosingTimerCourse, titleVisibility: .visible) {
            Button(tr("Sans cours précis")) { startTimer(nil) }
            ForEach(state.courses) { course in
                Button(course.name) { startTimer(course.id) }
            }
        }
        // `presenting:` hands the course to the button: the dialog may clear `deletingCourse` before the action runs.
        .confirmationDialog(tr("Supprimer ce cours ?"), isPresented: Binding(get: { deletingCourse != nil }, set: { if !$0 { deletingCourse = nil } }),
                            titleVisibility: .visible, presenting: deletingCourse) { course in
            Button(tr("Supprimer le cours"), role: .destructive) {
                model.update(\.student) { $0.deleteCourse(course.id) }
                deletingCourse = nil
            }
        } message: { _ in
            Text(tr("Ses plages quittent l'horaire. Ses notes, examens et devoirs restent, sans cours."))
        }
    }

    /// « Démarrer le chrono » floats above the tab bar while no timer runs (a running one has its card on top).
    private func timerAction(_ state: StudentState) -> MiniFloatingAction? {
        guard state.timerStart == nil else { return nil }
        return MiniFloatingAction(title: tr("Démarrer le chrono"), symbol: "play.fill", colorHex: accentHex, identifier: "studies-timer-start") {
            choosingTimerCourse = true
        }
    }

    /// Starts the study timer for a course (or none), and its Live Activity.
    private func startTimer(_ course: UUID?) {
        Haptics.tap()
        model.update(\.student) { $0.startTimer(courseID: course) }
        let state = model.student
        Task { await StudyLiveActivity.sync(state) }
    }

    // MARK: Empty

    /// First opening: the welcome card, with its two ways in (a course by hand, or the timetable read from a photo).
    private var start: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 30))
                .foregroundStyle(style.cristal.strong(accentHex))
            Text(tr("Ton année en un coup d'œil"))
                .font(.title3.weight(.bold))
            Text(tr("Ajoute tes cours : ton horaire, tes devoirs, tes examens et tes notes viendront s'y ranger. Ardane calcule ensuite tes moyennes et ce qu'il te reste à faire."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            MiniActionButton(title: tr("Ajouter un cours"), symbol: "plus", colorHex: accentHex) {
                sheet = .course(Course(name: ""))
            }
            .accessibilityIdentifier("studies-add-course")
            .tourAnchor(.studies, 0)
            HStack(spacing: 8) {
                MiniActionButton(title: tr("Importer mon horaire"), symbol: "doc.viewfinder", colorHex: accentHex, isProminent: false) {
                    importingSchedule = true
                }
                .accessibilityIdentifier("studies-import-schedule")
                .tourAnchor(.studies, 1)
                if !model.isPremium { PremiumBadge() }
            }
        }
        .card()
    }

    // MARK: Next exam

    /// The hero: the countdown of the next exam (the same « J-4 » as the card of Mon quotidien), then what it is.
    private func examHero(_ exam: Exam, state: StudentState, now: Date) -> some View {
        let course = state.course(exam.courseID)
        var parts = [exam.title, tr("\(Fmt.shortDay(exam.date)) à \(Fmt.time(exam.date, uses24Hour: true))")]
        if let course { parts.append(course.name) }
        if !exam.room.isEmpty { parts.append(exam.room) }
        if let course {
            let studied = StudentMath.studyMinutes(state, course: course.id, from: now.addingTimeInterval(-14 * 86_400), to: now)
            if studied > 0 { parts.append(tr("\(Fmt.minutes(Double(studied))) révisé")) }
        }
        return Button { sheet = .exam(exam) } label: {
            MiniHero(label: tr("Prochain examen"), value: Studies.examBadge(daysLeft: DateMath.daysBetween(now, exam.date)),
                     caption: parts.joined(separator: " · "), valueSize: 44)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("studies-hero")
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
            .buttonStyle(.pressable)
            .accessibilityIdentifier("studies-average")
            NavigationLink(value: HomeRoute.page(.studiesRevision)) {
                MiniStat(title: tr("Étude"), value: Fmt.minutes(studied), detail: tr("sur \(Fmt.hours(state.weeklyStudyGoalHours))"),
                         colorHex: studied >= state.weeklyStudyGoalHours * 60 ? "1E9E75" : nil)
            }
            .buttonStyle(.pressable)
            if !state.cards.isEmpty {
                NavigationLink(value: HomeRoute.page(.studiesRevision)) {
                    MiniStat(title: tr("Fiches"), value: "\(due)", detail: due == 0 ? tr("à jour") : tr("à réviser"), colorHex: due > 0 ? accentHex : nil)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    // MARK: Coming up

    /// A section title with a « Tout voir » link on the right.
    private func sectionHeader(_ title: String, count: String? = nil, route: MiniAppPage, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            MiniSectionTitle(title: title, detail: count)
            NavigationLink(value: HomeRoute.page(route)) {
                Text(tr("Tout voir"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(style.cristal.strong(accentHex))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier(identifier)
        }
    }

    /// 1. « À venir »: the next dates (the exam of the hero apart), nearest first. Creating an exam or homework is on « Échéances ».
    private func upcoming(state: StudentState, now: Date) -> some View {
        let hero = StudentMath.upcomingExams(state, at: now).first
        let items = Studies.deadlines(state, at: now).filter { item in
            if case let .exam(id) = item.kind { return id != hero?.id }
            return true
        }
        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(tr("À venir"), route: .studiesDeadlines, identifier: "studies-deadlines")
            if items.isEmpty {
                Text(tr("Rien à venir pour l'instant."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
            } else {
                MiniRowsCard {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        StudyDeadlineRow(deadline: item, state: state, now: now) { sheet = $0 }
                    }
                }
            }
        }
    }

    // MARK: Courses

    /// 2. « Mes cours »: every course, one under the other (the ones read from a timetable are here too).
    private func courses(state: StudentState, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if state.courses.isEmpty {
                MiniSectionTitle(title: tr("Mes cours"))
            } else {
                sectionHeader(tr("Mes cours"), count: "\(state.courses.count)", route: .studiesCourses, identifier: "studies-courses")
            }
            MiniRowsCard {
                ForEach(state.courses) { course in
                    HStack(spacing: 4) {
                        NavigationLink(value: HomeRoute.page(.studiesCourse(course.id))) {
                            courseRow(course, state: state, now: now)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("course-row")
                        Menu {
                            Button { sheet = .course(course) } label: { Label(tr("Modifier le cours"), systemImage: "pencil") }
                            Button(role: .destructive) { deletingCourse = course } label: { Label(tr("Supprimer le cours"), systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text(tr("Modifier le cours")))
                        .accessibilityIdentifier("course-row-menu")
                    }
                    MiniDivider()
                }
                Button { sheet = .course(Course(name: "")) } label: {
                    MiniRow(symbol: "plus", colorHex: accentHex, title: tr("Ajouter un cours"), showsChevron: false)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("studies-add-course")
            }
        }
    }

    /// The color, the name, then the teacher and the next class of the course.
    private func courseRow(_ course: Course, state: StudentState, now: Date) -> some View {
        var parts: [String] = []
        if !course.teacher.trimmed.isEmpty { parts.append(course.teacher) }
        if let next = nextSlot(of: course, state: state, now: now) { parts.append(next) }
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(style.cristal.category(course.colorHex)).frame(width: 6, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !parts.isEmpty {
                    Text(parts.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    /// The next time the course meets in the coming week (« Demain · 9:00 »), nil without a class in the timetable.
    private func nextSlot(of course: Course, state: StudentState, now: Date) -> String? {
        for offset in 0..<8 {
            guard let day = DateMath.calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let found = StudentMath.occurrences(state, on: day).first { $0.slot.courseID == course.id && $0.end > now && $0.end > $0.start }
            if let found { return "\(TF.relativeDay(found.start, from: now).capitalizedFirst) · \(Fmt.time(found.start, uses24Hour: true))" }
        }
        return nil
    }

    // MARK: Organisation

    /// 3. « Organisation étudiante »: the timetable, homework, grades, revision and the focus time. The import of a
    /// timetable and the dates of the session are on the page of the courses.
    private func organisation(state: StudentState, now: Date) -> some View {
        let groups = StudentMath.assignmentGroups(state, at: now)
        let weekly = state.slots.filter { $0.date == nil }
        let due = StudentMath.dueCount(state, at: now)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Organisation étudiante"))
            MiniRowsCard {
                NavigationLink(value: HomeRoute.page(.studiesTimetable)) {
                    MiniRow(symbol: "calendar.day.timeline.left", colorHex: accentHex, title: tr("Horaire"),
                            detail: weekly.isEmpty ? tr("Tes cours de la semaine") : tr("\(Fmt.plural(weekly.count, tr("cours", context: "one"), tr("cours"))) par semaine"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("studies-timetable")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.studiesAssignments)) {
                    MiniRow(symbol: "doc.text.fill", colorHex: "F2A33A", title: tr("Devoirs"),
                            detail: groups.late.isEmpty ? tr("À rendre, rendus") : tr("\(groups.late.count) en retard"),
                            value: groups.isEmpty ? nil : "\(groups.late.count + groups.thisWeek.count + groups.later.count)")
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("studies-assignments")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.studiesGrades)) {
                    MiniRow(symbol: "chart.bar.fill", colorHex: "3366FF", title: tr("Notes"), detail: tr("Moyennes et ce qu'il te faut pour ton objectif"),
                            value: StudentMath.overallAverage(state).map { "\(TF.decimal($0, 1)) %" })
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("studies-grades")
                MiniDivider()
                NavigationLink(value: HomeRoute.page(.studiesRevision)) {
                    MiniRow(symbol: "rectangle.on.rectangle.angled", colorHex: "8C6CFF", title: tr("Révisions"), detail: tr("Temps d'étude et fiches"),
                            value: due > 0 ? tr("\(due) à réviser") : nil)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("studies-revision")
                MiniDivider()
                // The focus page of Planning, opened from here with all its functions.
                NavigationLink(value: HomeRoute.page(.planningFocus)) {
                    MiniRow(symbol: "timer", colorHex: "8C6CFF", title: tr("Temps de concentration"),
                            detail: tr("\(TF.decimal(ProductivityMath.focusMinutes(model.productivity, weekOf: now) / 60, 1)) h sur \(TF.int(model.productivity.weeklyFocusGoalHours)) h cette semaine"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("studies-focus")
            }
        }
    }
}

// MARK: - Shared pieces

/// The class in progress or the next one, with its room and the homework of that course.
struct NextClassCard: View {
    let state: StudentState
    let now: Date
    @Environment(\.appStyle) private var style

    var body: some View {
        if let next = StudentMath.nextClass(state, at: now) {
            let course = state.course(next.slot.courseID)
            let hex = next.slot.colorHex ?? course?.colorHex ?? Studies.accentHex
            let isNow = next.start <= now
            NavigationLink(value: course.map { HomeRoute.page(.studiesCourse($0.id)) } ?? HomeRoute.page(.studiesTimetable)) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(isNow ? tr("En cours") : tr("Prochain cours"), systemImage: isNow ? "dot.radiowaves.left.and.right" : "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.cristal.strong(hex))
                    Text(state.title(of: next.slot))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(detail(next))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if isNow {
                        ProgressView(value: now.timeIntervalSince(next.start), total: max(1, next.end.timeIntervalSince(next.start)))
                            .accessibilityLabel(tr("Progression"))
                            .accessibilityValue(Fmt.percent(min(1, max(0, now.timeIntervalSince(next.start) / max(1, next.end.timeIntervalSince(next.start))))))
                            .tint(style.cristal.category(hex))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(style.cristal.category(hex).opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .cristalPanel(radius: 22)
            }
            .buttonStyle(.pressable)
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
    @Environment(\.appStyle) private var style

    var body: some View {
        let late = !assignment.isDone && assignment.due < now
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                withAnimation { model.update(\.student) { $0.toggleAssignment(assignment.id) } }
            } label: {
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(style.cristal.category(assignment.isDone ? Studies.accentHex : (state.course(assignment.courseID)?.colorHex ?? "8A8A8E")))
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
                        .foregroundStyle(late ? style.cristal.strong(MiniStyle.alertHex) : Color.secondary)
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
    @Environment(\.appStyle) private var style

    var body: some View {
        let course = state.course(exam.courseID)
        let days = DateMath.daysBetween(now, exam.date)
        let examHex = days <= 3 ? MiniStyle.alertHex : (course?.colorHex ?? Studies.accentHex)
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text(days <= 0 ? tr("Auj.") : tr("J-\(days)"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(style.cristal.strong(examHex))
                    .monospacedDigit()
            }
            .frame(width: 52, height: 44)
            .background(style.cristal.category(examHex).opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        var parts = [tr("\(Fmt.shortDay(exam.date)) à \(Fmt.time(exam.date, uses24Hour: true))")]
        if let course { parts.append(course.name) }
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
    @Environment(\.appStyle) private var style

    private var accentHex: String { Studies.accentHex }

    var body: some View {
        let state = model.student
        VStack(alignment: .leading, spacing: 12) {
            if let began = state.timerStart {
                HStack(alignment: .firstTextBaseline) {
                    Label(state.course(state.timerCourseID)?.name ?? tr("Étude"), systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.cristal.strong(accentHex))
                    Spacer()
                    TimelineView(.periodic(from: began, by: 1)) { context in
                        Text(elapsed(from: began, to: context.date))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                    }
                }
                HStack(spacing: 8) {
                    // A timer started by mistake: cleared, nothing is logged.
                    MiniActionButton(title: tr("Annuler"), symbol: "xmark", colorHex: accentHex, isProminent: false) {
                        model.update(\.student) {
                            $0.timerStart = nil
                            $0.timerCourseID = nil
                        }
                        Haptics.tap()
                        logged = nil
                        syncLiveActivity()
                    }
                    .frame(maxWidth: 130)
                    .accessibilityIdentifier("studies-timer-cancel")
                    MiniActionButton(title: tr("Terminer et noter"), symbol: "stop.fill", colorHex: accentHex) {
                        var minutes = 0
                        model.update(\.student) { minutes = $0.stopTimer() }
                        Haptics.success()
                        logged = minutes
                        syncLiveActivity()
                    }
                    .accessibilityIdentifier("studies-timer-stop")
                }
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
                            .foregroundStyle(style.onAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(style.cristal.strong(accentHex), in: Capsule())
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
        syncLiveActivity()
    }

    /// The timer on the Lock Screen and in the Dynamic Island follows the card (started, stopped, cancelled).
    private func syncLiveActivity() {
        let state = model.student
        Task { await StudyLiveActivity.sync(state) }
    }

    private func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
