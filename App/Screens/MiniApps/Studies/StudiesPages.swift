import Charts
import SwiftUI

// MARK: - Timetable

/// A week at a glance (a grid, one column a day), then what the chosen day holds. Weeks follow one
/// another: events that happen once show in their week, a weekly one cancelled once shows crossed out.
struct StudiesTimetablePage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?
    @State private var weekday = min(5, FitnessMath.isoWeekday(Date()))
    /// 0: this week, 1: the next one, -1: the last one…
    @State private var weekOffset = 0

    private var week: [Date] {
        DateMath.week(containing: DateMath.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date())
    }

    var body: some View {
        let state = model.student
        let week = self.week
        let day = week[safe: weekday - 1] ?? Date()
        MiniAppScroll {
            if state.slots.isEmpty {
                EmptyStateView(symbol: "calendar.day.timeline.left", title: tr("Ton horaire"),
                               message: tr("Cours, travail, rendez-vous… Ajoute ce qui revient chaque semaine ou ce qui arrive une seule fois : ta semaine s'organise ici et dans le widget Horaire."),
                               actionTitle: tr("Ajouter un événement")) {
                    sheet = .slotOn(Studies.newSlot(state), day)
                }
                .tint(Color(hex: Studies.accentHex))
            } else {
                weekSwitcher(week)
                TimetableGrid(state: state, week: week, selected: $weekday) { sheet = .slotOn($0.slot, $0.start) }
                dayList(state: state, day: day)
                MiniActionButton(title: tr("Ajouter un événement"), symbol: "plus", colorHex: Studies.accentHex, isProminent: false) {
                    var slot = Studies.newSlot(state)
                    slot.weekday = weekday
                    sheet = .slotOn(slot, day)
                }
                .accessibilityIdentifier("timetable-add")
            }
        }
        .navigationTitle(tr("Horaire"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { $0.editor }
    }

    private func weekSwitcher(_ week: [Date]) -> some View {
        HStack {
            Button {
                Haptics.tap()
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 36, height: 36)
            }
            .accessibilityLabel(Text(tr("Semaine précédente")))
            Spacer(minLength: 8)
            Button {
                weekOffset = 0
            } label: {
                Text(weekOffset == 0 ? tr("Cette semaine") : tr("Semaine du \(Fmt.shortDay(week.first ?? Date()))"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timetable-week")
            Spacer(minLength: 8)
            Button {
                Haptics.tap()
                weekOffset += 1
            } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold)).frame(width: 36, height: 36)
            }
            .accessibilityLabel(Text(tr("Semaine suivante")))
            .accessibilityIdentifier("timetable-next-week")
        }
        .tint(Color(hex: Studies.accentHex))
        .card(padding: 6)
    }

    private func dayList(state: StudentState, day: Date) -> some View {
        let entries = StudentMath.occurrences(state, on: day, includingCancelled: true)
        let count = entries.filter { !$0.isCancelled }.count
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: Fmt.longDay(day), detail: count == 0 ? nil : Fmt.plural(count, tr("élément"), tr("éléments")))
            if entries.isEmpty {
                Text(tr("Rien de prévu ce jour-là.")).font(.subheadline).foregroundStyle(.secondary).card(padding: 14)
            } else {
                MiniRowsCard {
                    ForEach(Array(entries.enumerated()), id: \.element.slot.id) { index, entry in
                        if index > 0 { MiniDivider() }
                        row(entry, state: state)
                    }
                }
            }
        }
    }

    private func row(_ entry: StudentMath.ClassOccurrence, state: StudentState) -> some View {
        let slot = entry.slot
        let place = slot.room.isEmpty ? nil : (slot.kind == .course ? tr("Salle \(slot.room)") : slot.room)
        let detail = entry.isCancelled ? tr("Annulé cette fois-ci") : [slot.date == nil ? nil : tr("Une seule fois"), place].compactMap { $0 }.joined(separator: " · ")
        return Button { sheet = .slotOn(slot, entry.start) } label: {
            MiniRow(symbol: slot.kind.symbol, colorHex: state.colorHex(of: slot),
                    title: state.title(of: slot),
                    detail: detail.isEmpty ? nil : detail,
                    value: "\(Studies.minuteText(slot.startMinute))–\(Studies.minuteText(slot.endMinute))", showsChevron: false)
                .strikethrough(entry.isCancelled)
                .opacity(entry.isCancelled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if slot.date == nil {
                Button {
                    model.update(\.student) { $0.setCancelled(!entry.isCancelled, slot: slot.id, on: entry.start) }
                } label: {
                    Label(entry.isCancelled ? tr("Rétablir cette fois-ci") : tr("Annuler cette fois-ci"),
                          systemImage: entry.isCancelled ? "arrow.uturn.backward" : "calendar.badge.minus")
                }
            }
            Button(role: .destructive) {
                model.update(\.student) { $0.slots.removeAll { $0.id == slot.id } }
            } label: {
                Label(tr("Supprimer"), systemImage: "trash")
            }
        }
    }
}

/// Monday to Friday (and the weekend when something falls on it), each entry a colored block; a
/// weekly entry cancelled that day shows faded.
struct TimetableGrid: View {
    let state: StudentState
    let week: [Date]
    @Binding var selected: Int
    let onTap: (StudentMath.ClassOccurrence) -> Void

    private let perMinute: CGFloat = 0.8
    private let letters = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        let entries = week.map { StudentMath.occurrences(state, on: $0, includingCancelled: true) }
        let hasWeekend = entries.dropFirst(5).contains { !$0.isEmpty }
        let all = entries.flatMap { $0 }
        let days = Array(1...(hasWeekend ? 7 : 5))
        let first = (all.map(\.slot.startMinute).min() ?? 8 * 60) / 60 * 60
        let last = ((all.map(\.slot.endMinute).max() ?? 17 * 60) + 59) / 60 * 60
        let height = CGFloat(last - first) * perMinute
        let today = week.firstIndex { DateMath.isSameDay($0, Date()) }.map { $0 + 1 }
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Color.clear.frame(width: 26, height: 1)
                ForEach(days, id: \.self) { day in
                    Button {
                        Haptics.tap()
                        selected = day
                    } label: {
                        // The day and its date, so the week reads at a glance.
                        VStack(spacing: 0) {
                            Text(letters[day - 1])
                                .font(.caption2.weight(.bold))
                            Text(week[safe: day - 1].map { "\(DateMath.calendar.component(.day, from: $0))" } ?? "")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(day == selected ? Color.white : (day == today ? Color(hex: Studies.accentHex) : Color.primary))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(day == selected ? Color(hex: Studies.accentHex) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .top, spacing: 4) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(stride(from: first, through: last, by: 60)), id: \.self) { minute in
                        Text("\(minute / 60)h")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .offset(y: CGFloat(minute - first) * perMinute - 5)
                    }
                }
                .frame(width: 26, height: height, alignment: .topLeading)
                ForEach(days, id: \.self) { day in
                    column(day: day, entries: entries[safe: day - 1] ?? [], first: first, height: height)
                }
            }
            // A thin line at each hour, across the days.
            .background(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(stride(from: first, through: last, by: 60)), id: \.self) { minute in
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 0.5)
                            .offset(y: CGFloat(minute - first) * perMinute)
                    }
                }
                .padding(.leading, 30)
            }
        }
        .card(padding: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timetable-grid")
    }

    private func column(day: Int, entries: [StudentMath.ClassOccurrence], first: Int, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(day == selected ? Color(hex: Studies.accentHex).opacity(0.07) : Color.primary.opacity(0.03))
            ForEach(entries, id: \.slot.id) { entry in
                let slot = entry.slot
                let hex = state.colorHex(of: slot)
                Button { onTap(entry) } label: {
                    Text(TF.shortName(state.title(of: slot), words: 1))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(hex: hex), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(entry.isCancelled ? 0.35 : 1)
                .frame(height: max(14, CGFloat(slot.endMinute - slot.startMinute) * perMinute - 2))
                .offset(y: CGFloat(slot.startMinute - first) * perMinute)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
    }
}

// MARK: - Courses

struct StudiesCoursesPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?

    var body: some View {
        let state = model.student
        let now = Date()
        List {
            Section {
                ForEach(state.courses) { course in
                    NavigationLink(value: HomeRoute.page(.studiesCourse(course.id))) {
                        row(course, state: state)
                    }
                    .accessibilityIdentifier("course-row")
                }
                .onDelete { offsets in
                    let ids = offsets.map { state.courses[$0].id }
                    model.update(\.student) { student in ids.forEach { student.deleteCourse($0) } }
                }
                Button { sheet = .course(Course(name: "")) } label: { Label(tr("Nouveau cours"), systemImage: "plus") }
                    .accessibilityIdentifier("courses-new")
            } footer: {
                if !state.courses.isEmpty {
                    Text(tr("Supprimer un cours retire aussi ses plages de l'horaire ; ses notes, examens et devoirs restent."))
                }
            }
            Section {
                DatePicker(tr("Début"), selection: Binding(get: { state.semesterStart ?? now }, set: { date in model.update(\.student) { $0.semesterStart = date } }), displayedComponents: .date)
                DatePicker(tr("Fin"), selection: Binding(get: { state.semesterEnd ?? now.addingTimeInterval(100 * 86_400) }, set: { date in model.update(\.student) { $0.semesterEnd = date } }), displayedComponents: .date)
            } header: {
                Text(tr("Session"))
            } footer: {
                Text(tr("Sert à suivre l'avancement de ta session."))
            }
            .environment(\.locale, Fmt.locale)
        }
        .styledList()
        .tint(Color(hex: Studies.accentHex))
        .navigationTitle(tr("Cours"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func courseDetail(_ course: Course, hours: Double) -> String {
        var parts: [String] = []
        if !course.teacher.isEmpty { parts.append(course.teacher) }
        if hours > 0 { parts.append(tr("\(Fmt.hours(hours)) / semaine")) }
        return parts.joined(separator: " · ")
    }

    private func row(_ course: Course, state: StudentState) -> some View {
        let average = StudentMath.courseAverage(state, course: course.id)
        let hours = Double(StudentMath.weeklyClassMinutes(state, course: course.id)) / 60
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: course.colorHex)).frame(width: 6, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name).font(.body.weight(.medium))
                Text(courseDetail(course, hours: hours))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let average {
                Text("\(TF.decimal(average, 1)) %").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
        }
    }
}

/// One course: its figures, what it takes to reach a goal, its classes, exams, homework and grades.
struct StudiesCoursePage: View {
    let courseID: UUID
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var sheet: StudiesSheet?
    @State private var target = 80.0
    @State private var confirmingDelete = false

    var body: some View {
        let state = model.student
        let now = Date()
        Group {
            if let course = state.course(courseID) {
                MiniAppScroll {
                    header(course, state: state, now: now)
                    goal(course, state: state)
                    classes(course, state: state)
                    exams(course, state: state, now: now)
                    homework(course, state: state, now: now)
                    grades(course, state: state)
                }
                .navigationTitle(course.name)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { sheet = .course(course) } label: { Label(tr("Modifier le cours"), systemImage: "pencil") }
                            Button(role: .destructive) { confirmingDelete = true } label: { Label(tr("Supprimer le cours"), systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityIdentifier("course-menu")
                    }
                }
                .confirmationDialog(tr("Supprimer « \(course.name) » ?"), isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button(tr("Supprimer le cours"), role: .destructive) {
                        model.update(\.student) { $0.deleteCourse(courseID) }
                        if !router.homePath.isEmpty { router.homePath.removeLast() }
                    }
                } message: {
                    Text(tr("Ses plages quittent l'horaire. Ses notes, examens et devoirs restent, sans cours."))
                }
            } else {
                ContentUnavailableView(tr("Cours supprimé"), systemImage: "books.vertical")
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func header(_ course: Course, state: StudentState, now: Date) -> some View {
        let weekStart = DateMath.week(containing: now).first ?? now
        let studied = StudentMath.studyMinutes(state, course: course.id, from: weekStart, to: now.addingTimeInterval(1))
        let hours = Double(StudentMath.weeklyClassMinutes(state, course: course.id)) / 60
        return VStack(alignment: .leading, spacing: 10) {
            if !course.teacher.isEmpty || hours > 0 {
                Text(headerDetail(course, hours: hours))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                MiniStat(title: tr("Moyenne"), value: StudentMath.courseAverage(state, course: course.id).map { "\(TF.decimal($0, 1)) %" } ?? "–", colorHex: course.colorHex)
                MiniStat(title: tr("Évalué"), value: "\(TF.int(StudentMath.evaluatedWeight(state, course: course.id))) %", detail: tr("de la note finale"))
                MiniStat(title: tr("Étude"), value: Fmt.minutes(Double(studied)), detail: tr("cette semaine"))
            }
        }
    }

    private func headerDetail(_ course: Course, hours: Double) -> String {
        var parts: [String] = []
        if !course.teacher.isEmpty { parts.append(course.teacher) }
        parts.append(tr("\(TF.decimal(course.credits, 1)) crédits"))
        if hours > 0 { parts.append(tr("\(Fmt.hours(hours)) de cours / semaine")) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func goal(_ course: Course, state: StudentState) -> some View {
        if StudentMath.evaluatedWeight(state, course: course.id) > 0, let needed = StudentMath.neededAverage(state, course: course.id, target: target) {
            let left = 100 - StudentMath.evaluatedWeight(state, course: course.id)
            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: $target, in: 50...100, step: 5) {
                    Text(tr("Objectif : \(TF.int(target)) %")).font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("course-goal")
                Group {
                    if needed <= 0 {
                        Text(tr("C'est acquis : même sans point sur les \(TF.int(left)) % qui restent, tu finis à \(TF.int(target)) % ou plus."))
                    } else if needed > 100 {
                        Text(tr("Hors d'atteinte : il faudrait \(TF.int(needed)) % sur les \(TF.int(left)) % qui restent."))
                    } else {
                        Text("Il te faut en moyenne **\(TF.int(needed.rounded(.up))) %** sur les \(TF.int(left)) % qui restent.")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .card(padding: 14)
        }
    }

    private func classes(_ course: Course, state: StudentState) -> some View {
        let slots = state.slots.filter { $0.courseID == course.id && $0.date == nil }.sorted { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
        return section(tr("Horaire"), add: tr("Ajouter une plage"), onAdd: { sheet = .slot(Studies.newSlot(state, course: course.id)) }) {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                if index > 0 { MiniDivider() }
                Button { sheet = .slot(slot) } label: {
                    MiniRow(symbol: "clock", colorHex: course.colorHex, title: Studies.weekdayNames[slot.weekday - 1],
                            detail: slot.room.isEmpty ? nil : tr("Salle \(slot.room)"),
                            value: "\(Studies.minuteText(slot.startMinute))–\(Studies.minuteText(slot.endMinute))", showsChevron: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func exams(_ course: Course, state: StudentState, now: Date) -> some View {
        let exams = state.exams.filter { $0.courseID == course.id }.sorted { $0.date < $1.date }
        return section(tr("Examens"), add: tr("Ajouter un examen"), onAdd: { sheet = .exam(Studies.newExam(state, course: course.id)) }) {
            ForEach(Array(exams.enumerated()), id: \.element.id) { index, exam in
                if index > 0 { Divider() }
                Button { sheet = .exam(exam) } label: { ExamRow(exam: exam, state: state, now: now) }
                    .buttonStyle(.plain)
                    .opacity(exam.date < now ? 0.55 : 1)
            }
        }
    }

    private func homework(_ course: Course, state: StudentState, now: Date) -> some View {
        let open = state.assignments.filter { $0.courseID == course.id && !$0.isDone }.sorted { $0.due < $1.due }
        return section(tr("Devoirs à rendre"), add: tr("Ajouter un devoir"), onAdd: { sheet = .assignment(Studies.newAssignment(state, course: course.id)) }) {
            ForEach(Array(open.enumerated()), id: \.element.id) { index, assignment in
                if index > 0 { Divider() }
                AssignmentRow(assignment: assignment, state: state, now: now) { sheet = .assignment(assignment) }
            }
        }
    }

    private func grades(_ course: Course, state: StudentState) -> some View {
        let grades = state.grades.filter { $0.courseID == course.id }
        return section(tr("Notes"), add: tr("Ajouter une note"), onAdd: { sheet = .grade(Studies.newGrade(state, course: course.id)) }) {
            ForEach(Array(grades.enumerated()), id: \.element.id) { index, grade in
                if index > 0 { MiniDivider() }
                Button { sheet = .grade(grade) } label: {
                    MiniRow(symbol: "checkmark.seal.fill", colorHex: course.colorHex, title: grade.title,
                            detail: tr("\(TF.decimal(grade.score, 1))/\(TF.decimal(grade.maxScore, 0)) · compte pour \(TF.int(grade.weight)) %"),
                            value: "\(TF.int(grade.ratio * 100)) %", showsChevron: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A titled card with its rows and an « add » line at the bottom.
    private func section<Rows: View>(_ title: String, add: String, onAdd: @escaping () -> Void, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: title)
            VStack(spacing: 0) {
                rows()
                Divider()
                Button(action: onAdd) {
                    Label(add, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: Studies.accentHex))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Exams

struct StudiesExamsPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?

    var body: some View {
        let state = model.student
        let now = Date()
        let upcoming = StudentMath.upcomingExams(state, at: now)
        let past = StudentMath.pastExams(state, at: now)
        MiniAppScroll {
            MiniActionButton(title: tr("Nouvel examen"), symbol: "plus", colorHex: Studies.accentHex) {
                sheet = .exam(Studies.newExam(state))
            }
            .accessibilityIdentifier("exams-new")
            if upcoming.isEmpty && past.isEmpty {
                Text(tr("Aucun examen noté. Ajoute-les dès que tu connais les dates : le compte à rebours et le temps révisé s'affichent ici."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            if !upcoming.isEmpty {
                list(tr("À venir"), upcoming, state: state, now: now)
                if let first = upcoming.first, DateMath.daysBetween(now, first.date) <= 7 {
                    Label(tr("Prochain examen \(TF.relativeDay(first.date, from: now)) : lance le chrono d'étude dans « Révisions » pour suivre le temps passé sur ce cours."), systemImage: "lightbulb")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if !past.isEmpty {
                list(tr("Passés"), past, state: state, now: now)
                    .opacity(0.7)
            }
        }
        .navigationTitle(tr("Examens"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func list(_ title: String, _ exams: [Exam], state: StudentState, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: title)
            VStack(spacing: 0) {
                ForEach(Array(exams.enumerated()), id: \.element.id) { index, exam in
                    if index > 0 { Divider() }
                    Button { sheet = .exam(exam) } label: { ExamRow(exam: exam, state: state, now: now) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                model.update(\.student) { $0.exams.removeAll { $0.id == exam.id } }
                            } label: {
                                Label(tr("Supprimer"), systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 14)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Homework

struct StudiesAssignmentsPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?

    var body: some View {
        let state = model.student
        let now = Date()
        let groups = StudentMath.assignmentGroups(state, at: now)
        let done = state.assignments.filter(\.isDone).sorted { $0.due > $1.due }
        List {
            Section {
                Button { sheet = .assignment(Studies.newAssignment(state)) } label: { Label(tr("Nouveau devoir"), systemImage: "plus") }
                    .accessibilityIdentifier("assignments-new")
            }
            section(tr("En retard"), groups.late, state: state, now: now)
            section(tr("Cette semaine"), groups.thisWeek, state: state, now: now)
            section(tr("Plus tard"), groups.later, state: state, now: now)
            section(tr("Rendus"), Array(done.prefix(20)), state: state, now: now)
        }
        .styledList()
        .tint(Color(hex: Studies.accentHex))
        .navigationTitle(tr("Devoirs"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [Assignment], state: StudentState, now: Date) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { assignment in
                    AssignmentRow(assignment: assignment, state: state, now: now) { sheet = .assignment(assignment) }
                }
                .onDelete { offsets in
                    let ids = offsets.map { items[$0].id }
                    model.update(\.student) { $0.assignments.removeAll { ids.contains($0.id) } }
                }
            }
        }
    }
}

// MARK: - Grades

struct StudiesGradesPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?

    var body: some View {
        let state = model.student
        MiniAppScroll {
            if let overall = StudentMath.overallAverage(state) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Moyenne générale")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(TF.decimal(overall, 1)) %")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: Studies.accentHex))
                        .monospacedDigit()
                    Text(tr("Pondérée par les crédits de chaque cours.")).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("grades-overall")
            }
            MiniActionButton(title: tr("Nouvelle note"), symbol: "plus", colorHex: Studies.accentHex) {
                sheet = .grade(Studies.newGrade(state))
            }
            .accessibilityIdentifier("grades-new")
            if state.grades.isEmpty {
                Text(tr("Aucune note pour l'instant. Chaque note compte pour un pourcentage de son cours : Ardane en tire la moyenne du cours, puis ta moyenne générale."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            let graded = state.courses.filter { StudentMath.courseAverage(state, course: $0.id) != nil }
            if !graded.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Par cours"))
                    VStack(spacing: 0) {
                        ForEach(Array(graded.enumerated()), id: \.element.id) { index, course in
                            if index > 0 { Divider() }
                            NavigationLink(value: HomeRoute.page(.studiesCourse(course.id))) {
                                courseBar(course, state: state)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
            if !state.grades.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MiniSectionTitle(title: tr("Toutes les notes"), detail: "\(state.grades.count)")
                    MiniRowsCard {
                        ForEach(Array(state.grades.reversed().enumerated()), id: \.element.id) { index, grade in
                            if index > 0 { MiniDivider() }
                            Button { sheet = .grade(grade) } label: {
                                MiniRow(symbol: "checkmark.seal.fill", colorHex: state.course(grade.courseID)?.colorHex ?? Studies.accentHex,
                                        title: grade.title, detail: gradeDetail(grade, state: state),
                                        value: "\(TF.int(grade.ratio * 100)) %", showsChevron: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(tr("Notes"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func gradeDetail(_ grade: Grade, state: StudentState) -> String {
        let score = "\(TF.decimal(grade.score, 1))/\(TF.decimal(grade.maxScore, 0))"
        guard let name = state.course(grade.courseID)?.name else { return score }
        return "\(name) · \(score)"
    }

    private func courseBar(_ course: Course, state: StudentState) -> some View {
        let average = StudentMath.courseAverage(state, course: course.id) ?? 0
        let evaluated = StudentMath.evaluatedWeight(state, course: course.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(course.name).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(TF.decimal(average, 1)) %").font(.subheadline.weight(.bold)).monospacedDigit()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            ProgressView(value: min(100, average), total: 100).tint(Color(hex: course.colorHex))
            Text(tr("\(TF.int(evaluated)) % de la note finale évalué")).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Revision

/// Study time (timer, quick add, the week and the last weeks) and the flashcards to review.
struct StudiesRevisionPage: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: StudiesSheet?
    @State private var revealed = false
    @State private var openDeck: String?

    private var accentHex: String { Studies.accentHex }

    var body: some View {
        let state = model.student
        let now = Date()
        MiniAppScroll {
            StudyTimerCard()
            week(state: state, now: now)
            weeks(state: state, now: now)
            cards(state: state, now: now)
        }
        .navigationTitle(tr("Révisions"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet) { $0.editor }
    }

    private func week(state: StudentState, now: Date) -> some View {
        let studied = StudentMath.studyMinutes(state, weekOf: now)
        let byDay = StudentMath.studyByDay(state, weekOf: now)
        let days = DateMath.week(containing: now)
        let points = DayValue.list(days, byDay)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Cette semaine"), detail: tr("\(Fmt.minutes(studied)) sur \(Fmt.hours(state.weeklyStudyGoalHours))"))
            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: min(studied, state.weeklyStudyGoalHours * 60), total: max(1, state.weeklyStudyGoalHours * 60))
                    .tint(Color(hex: accentHex))
                Chart(points) { point in
                    BarMark(x: .value("Jour", point.date, unit: .day), y: .value("Minutes", point.value))
                        .foregroundStyle(Color(hex: accentHex).gradient)
                        .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .frame(height: 120)
                HStack(spacing: 8) {
                    ForEach([25, 45, 60], id: \.self) { minutes in
                        Button(tr("+\(minutes) min")) {
                            Haptics.tap()
                            model.update(\.student) { $0.logStudy(minutes: minutes, courseID: nil) }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color(hex: accentHex))
                    }
                }
                .accessibilityIdentifier("revision-quick-add")
                Stepper(value: Binding(get: { state.weeklyStudyGoalHours }, set: { hours in model.update(\.student) { $0.weeklyStudyGoalHours = hours } }), in: 1...60) {
                    Text(tr("Objectif : \(Fmt.hours(state.weeklyStudyGoalHours)) par semaine")).font(.subheadline)
                }
            }
            .card(padding: 14)
        }
    }

    @ViewBuilder
    private func weeks(state: StudentState, now: Date) -> some View {
        let history = StudentMath.studyByWeek(state, weeks: 6, at: now)
        if history.dropLast().contains(where: { $0.minutes > 0 }) {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("6 dernières semaines"))
                Chart {
                    ForEach(history) { week in
                        BarMark(x: .value("Semaine", week.start, unit: .weekOfYear), y: .value("Heures", Double(week.minutes) / 60))
                            .foregroundStyle(Color(hex: accentHex).gradient)
                            .cornerRadius(3)
                    }
                    RuleMark(y: .value("Objectif", state.weeklyStudyGoalHours))
                        .foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .frame(height: 150)
                .card()
            }
        }
    }

    private func cards(state: StudentState, now: Date) -> some View {
        let decks = StudentMath.decks(state, at: now)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Fiches"), detail: state.cards.isEmpty ? nil : tr("\(StudentMath.dueCount(state, at: now)) à réviser"))
            if let card = StudentMath.dueCard(state, at: now) {
                review(card)
            } else if !state.cards.isEmpty {
                Label(tr("Tout est révisé pour l'instant."), systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .card(padding: 14)
            }
            MiniRowsCard {
                ForEach(decks) { deck in
                    Button {
                        withAnimation(.snappy) { openDeck = openDeck == deck.name ? nil : deck.name }
                    } label: {
                        MiniRow(symbol: "rectangle.stack.fill", colorHex: "8C6CFF", title: deck.name,
                                detail: deck.due > 0 ? tr("\(deck.due) à réviser") : tr("à jour"), value: "\(deck.total)", showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    if openDeck == deck.name {
                        ForEach(state.cards.filter { $0.deck == deck.name }) { card in
                            Button { sheet = .card(card) } label: {
                                HStack {
                                    Text(card.front).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                                    Spacer()
                                    Text(tr("boîte \(card.box)")).font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.leading, 46)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    MiniDivider()
                }
                Button { sheet = .card(Flashcard(deck: openDeck ?? decks.first?.name ?? tr("Général"), front: "", back: "")) } label: {
                    Label(tr("Nouvelle fiche"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: accentHex))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cards-new")
            }
            Text(tr("Répétition espacée : une fiche sue revient dans 1, 2, 4, 8 puis 16 jours ; une fiche ratée revient dans 10 minutes."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func review(_ card: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(card.deck.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Color(hex: "8C6CFF"))
            Text(card.front).font(.title3.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            if revealed {
                Text(card.back).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    MiniActionButton(title: tr("À revoir"), symbol: "arrow.counterclockwise", colorHex: "E5484D", isProminent: false) { grade(false) }
                    MiniActionButton(title: tr("Je savais"), symbol: "checkmark", colorHex: "1E9E75") { grade(true) }
                        .accessibilityIdentifier("card-known")
                }
            } else {
                MiniActionButton(title: tr("Voir la réponse"), symbol: "eye", colorHex: "8C6CFF", isProminent: false) {
                    withAnimation(.snappy) { revealed = true }
                }
                .accessibilityIdentifier("card-reveal")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card-review")
    }

    private func grade(_ known: Bool) {
        Haptics.tap()
        model.update(\.student) { $0.gradeDueCard(known: known) }
        withAnimation(.snappy) { revealed = false }
    }
}
