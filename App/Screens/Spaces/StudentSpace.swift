import SwiftUI

struct StudentSpaceSections: View {
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?

    private let weekdayNames = [tr("Lundi"), tr("Mardi"), tr("Mercredi"), tr("Jeudi"), tr("Vendredi"), tr("Samedi"), tr("Dimanche")]

    var body: some View {
        let now = Date()
        let state = model.student
        Section {
            ForEach(state.courses) { course in
                Button {
                    sheets?.open { CourseEditor(course: course) }
                } label: {
                    HStack {
                        Circle().fill(Color(hex: course.colorHex)).frame(width: 10, height: 10)
                        Text(course.name).foregroundStyle(Color.primary)
                        Spacer()
                        if let average = StudentMath.courseAverage(state, course: course.id) {
                            Text("\(TF.decimal(average, 1)) %").foregroundStyle(Color.secondary).monospacedDigit()
                        }
                    }
                }
            }
            .onDelete { offsets in model.update(\.student) { $0.courses.remove(atOffsets: offsets) } }
            Button { sheets?.open { CourseEditor(course: Course(name: "")) } } label: { Label(tr("Nouveau cours"), systemImage: "plus") }
        } header: {
            Text(tr("Cours"))
        }

        Section(tr("Horaire")) {
            ForEach(state.slots.sorted { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }) { slot in
                Button {
                    sheets?.open { SlotEditor(slot: slot) }
                } label: {
                    HStack {
                        Circle().fill(Color(hex: state.course(slot.courseID)?.colorHex ?? "999999")).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(StudentTiles.courseName(state, slot.courseID)).foregroundStyle(Color.primary)
                            Text("\(weekdayNames[safe: slot.weekday - 1] ?? "") · \(minuteText(slot.startMinute))–\(minuteText(slot.endMinute))\(slot.room.isEmpty ? "" : " · \(slot.room)")")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in
                let sorted = state.slots.sorted { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.student) { $0.slots.removeAll { ids.contains($0.id) } }
            }
            Button {
                sheets?.open { SlotEditor(slot: ClassSlot(courseID: state.courses.first?.id, weekday: FitnessMath.isoWeekday(now), startMinute: 8 * 60 + 30, endMinute: 10 * 60 + 20)) }
            } label: {
                Label(tr("Ajouter un cours à l'horaire"), systemImage: "plus")
            }
            .disabled(state.courses.isEmpty)
        }

        Section(tr("Examens")) {
            ForEach(state.exams.sorted { $0.date < $1.date }) { exam in
                Button { sheets?.open { ExamEditor(exam: exam) } } label: {
                    ValueRow(title: exam.title, value: exam.date < now ? tr("passé") : "J-\(DateMath.daysBetween(now, exam.date))", symbol: "pencil.and.list.clipboard", colorHex: state.course(exam.courseID)?.colorHex)
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let sorted = state.exams.sorted { $0.date < $1.date }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.student) { $0.exams.removeAll { ids.contains($0.id) } }
            }
            Button { sheets?.open { ExamEditor(exam: Exam(courseID: state.courses.first?.id, title: "", date: now.addingTimeInterval(7 * 86_400))) } } label: { Label(tr("Nouvel examen"), systemImage: "plus") }
        }

        Section(tr("Devoirs")) {
            ForEach(state.assignments.sorted { $0.due < $1.due }) { item in
                HStack {
                    Button {
                        model.update(\.student) { $0.toggleAssignment(item.id) }
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    Button { sheets?.open { AssignmentEditor(assignment: item) } } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).strikethrough(item.isDone).foregroundStyle(item.isDone ? .secondary : .primary)
                            Text(TF.relativeDay(item.due, from: now).capitalizedFirst).font(.caption).foregroundStyle(Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .onDelete { offsets in
                let sorted = state.assignments.sorted { $0.due < $1.due }
                let ids = offsets.map { sorted[$0].id }
                model.update(\.student) { $0.assignments.removeAll { ids.contains($0.id) } }
            }
            Button { sheets?.open { AssignmentEditor(assignment: Assignment(courseID: state.courses.first?.id, title: "", due: now.addingTimeInterval(3 * 86_400))) } } label: { Label(tr("Nouveau devoir"), systemImage: "plus") }
        }

        Section {
            if let overall = StudentMath.overallAverage(state) {
                ValueRow(title: tr("Moyenne générale"), value: "\(TF.decimal(overall, 1)) %", symbol: "graduationcap")
            }
            ForEach(state.grades) { grade in
                Button { sheets?.open { GradeEditor(grade: grade) } } label: {
                    ValueRow(title: "\(StudentTiles.courseName(state, grade.courseID)) · \(grade.title)", value: "\(TF.decimal(grade.score, 1))/\(TF.decimal(grade.maxScore, 0)) (\(TF.int(grade.weight)) %)")
                }
                .tint(.primary)
            }
            .onDelete { offsets in model.update(\.student) { $0.grades.remove(atOffsets: offsets) } }
            Button { sheets?.open { GradeEditor(grade: Grade(courseID: state.courses.first?.id, title: "", score: 0)) } } label: { Label(tr("Nouvelle note"), systemImage: "plus") }
                .disabled(state.courses.isEmpty)
        } header: {
            Text(tr("Notes"))
        } footer: {
            Text(tr("La moyenne de chaque cours est pondérée par le poids des évaluations, la moyenne générale par les crédits."))
        }

        Section {
            ValueRow(title: tr("À réviser maintenant"), value: "\(StudentMath.dueCount(state, at: now))", symbol: "rectangle.on.rectangle.angled")
            ForEach(state.cards) { card in
                Button { sheets?.open { CardEditor(card: card) } } label: {
                    ValueRow(title: card.front, value: tr("boîte \(card.box)"))
                }
                .tint(.primary)
            }
            .onDelete { offsets in model.update(\.student) { $0.cards.remove(atOffsets: offsets) } }
            Button { sheets?.open { CardEditor(card: Flashcard(front: "", back: "")) } } label: { Label(tr("Nouvelle fiche"), systemImage: "plus") }
        } header: {
            Text(tr("Fiches de révision"))
        } footer: {
            Text(tr("Répétition espacée : une fiche sue revient dans 1, 2, 4, 8 puis 16 jours. Révise-les depuis le widget."))
        }

        Section(tr("Temps d'étude")) {
            ValueRow(title: tr("Cette semaine"), value: tr("\(Fmt.minutes(StudentMath.studyMinutes(state, weekOf: now))) sur \(Fmt.hours(state.weeklyStudyGoalHours))"), symbol: "clock")
            HStack {
                ForEach([25, 45, 60], id: \.self) { minutes in
                    Button(tr("+\(minutes) min")) {
                        Haptics.tap()
                        model.update(\.student) { $0.logStudy(minutes: minutes, courseID: nil) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            Stepper(value: Binding(get: { state.weeklyStudyGoalHours }, set: { hours in model.update(\.student) { $0.weeklyStudyGoalHours = hours } }), in: 1...60) {
                ValueRow(title: tr("Objectif"), value: tr("\(Fmt.hours(state.weeklyStudyGoalHours)) / semaine"))
            }
        }

        Section(tr("Session")) {
            DatePicker(tr("Début"), selection: Binding(get: { state.semesterStart ?? now }, set: { date in model.update(\.student) { $0.semesterStart = date } }), displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
            DatePicker(tr("Fin"), selection: Binding(get: { state.semesterEnd ?? now.addingTimeInterval(100 * 86_400) }, set: { date in model.update(\.student) { $0.semesterEnd = date } }), displayedComponents: .date)
                .environment(\.locale, Fmt.locale)
        }
    }

    private func minuteText(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

struct CourseEditor: View {
    @Environment(AppModel.self) private var model
    @State var course: Course

    var body: some View {
        SheetForm(title: tr("Cours"), canSave: !course.name.trimmed.isEmpty, onSave: save) {
            TextField(tr("Nom du cours"), text: $course.name)
            TextField(tr("Enseignant (facultatif)"), text: $course.teacher)
            NumberRow(title: tr("Crédits"), value: $course.credits)
            ColorChoiceRow(hex: $course.colorHex)
        }
    }

    private func save() {
        var saved = course
        saved.name = saved.name.trimmed
        model.update(\.student) { state in
            if let index = state.courses.firstIndex(where: { $0.id == saved.id }) { state.courses[index] = saved } else { state.courses.append(saved) }
        }
    }
}

struct CoursePicker: View {
    @Binding var selection: UUID?
    let courses: [Course]

    var body: some View {
        Picker(tr("Cours"), selection: $selection) {
            Text(tr("Aucun")).tag(UUID?.none)
            ForEach(courses) { Text($0.name).tag(Optional($0.id)) }
        }
    }
}

struct SlotEditor: View {
    @Environment(AppModel.self) private var model
    @State var slot: ClassSlot

    var body: some View {
        SheetForm(title: tr("Horaire"), canSave: slot.endMinute > slot.startMinute, onSave: save) {
            CoursePicker(selection: $slot.courseID, courses: model.student.courses)
            Picker(tr("Jour"), selection: $slot.weekday) {
                ForEach(1...7, id: \.self) { day in
                    Text([tr("Lundi"), tr("Mardi"), tr("Mercredi"), tr("Jeudi"), tr("Vendredi"), tr("Samedi"), tr("Dimanche")][day - 1]).tag(day)
                }
            }
            MinuteTimePicker(title: tr("Début"), minutes: $slot.startMinute)
            MinuteTimePicker(title: tr("Fin"), minutes: $slot.endMinute)
            TextField(tr("Salle (facultatif)"), text: $slot.room)
        }
    }

    private func save() {
        let saved = slot
        model.update(\.student) { state in
            if let index = state.slots.firstIndex(where: { $0.id == saved.id }) { state.slots[index] = saved } else { state.slots.append(saved) }
        }
    }
}

struct ExamEditor: View {
    @Environment(AppModel.self) private var model
    @State var exam: Exam

    var body: some View {
        SheetForm(title: tr("Examen"), canSave: !exam.title.trimmed.isEmpty, onSave: save) {
            TextField(tr("Titre (intra, final…)"), text: $exam.title)
            CoursePicker(selection: $exam.courseID, courses: model.student.courses)
            DatePicker(tr("Date et heure"), selection: $exam.date).environment(\.locale, Fmt.locale)
            TextField(tr("Salle (facultatif)"), text: $exam.room)
        }
    }

    private func save() {
        var saved = exam
        saved.title = saved.title.trimmed
        model.update(\.student) { state in
            if let index = state.exams.firstIndex(where: { $0.id == saved.id }) { state.exams[index] = saved } else { state.exams.append(saved) }
        }
    }
}

struct AssignmentEditor: View {
    @Environment(AppModel.self) private var model
    @State var assignment: Assignment

    var body: some View {
        SheetForm(title: tr("Devoir"), canSave: !assignment.title.trimmed.isEmpty, onSave: save) {
            TextField(tr("Titre"), text: $assignment.title)
            CoursePicker(selection: $assignment.courseID, courses: model.student.courses)
            DatePicker(tr("À rendre le"), selection: $assignment.due).environment(\.locale, Fmt.locale)
            Toggle(tr("Rendu"), isOn: $assignment.isDone)
        }
    }

    private func save() {
        var saved = assignment
        saved.title = saved.title.trimmed
        model.update(\.student) { state in
            if let index = state.assignments.firstIndex(where: { $0.id == saved.id }) { state.assignments[index] = saved } else { state.assignments.append(saved) }
        }
    }
}

struct GradeEditor: View {
    @Environment(AppModel.self) private var model
    @State var grade: Grade

    var body: some View {
        SheetForm(title: tr("Note"), canSave: !grade.title.trimmed.isEmpty && grade.maxScore > 0, onSave: save) {
            CoursePicker(selection: $grade.courseID, courses: model.student.courses)
            TextField(tr("Évaluation (quiz, examen…)"), text: $grade.title)
            NumberRow(title: tr("Note obtenue"), value: $grade.score)
            NumberRow(title: tr("Sur"), value: $grade.maxScore)
            NumberRow(title: tr("Poids dans le cours"), value: $grade.weight, unit: "%")
        }
    }

    private func save() {
        var saved = grade
        saved.title = saved.title.trimmed
        model.update(\.student) { state in
            if let index = state.grades.firstIndex(where: { $0.id == saved.id }) { state.grades[index] = saved } else { state.grades.append(saved) }
        }
    }
}

struct CardEditor: View {
    @Environment(AppModel.self) private var model
    @State var card: Flashcard

    var body: some View {
        SheetForm(title: tr("Fiche"), canSave: !card.front.trimmed.isEmpty && !card.back.trimmed.isEmpty, onSave: save) {
            TextField(tr("Paquet (biologie, anglais…)"), text: $card.deck)
            TextField(tr("Question ou mot"), text: $card.front, axis: .vertical)
            TextField(tr("Réponse"), text: $card.back, axis: .vertical)
        }
    }

    private func save() {
        var saved = card
        saved.front = saved.front.trimmed
        saved.back = saved.back.trimmed
        model.update(\.student) { state in
            if let index = state.cards.firstIndex(where: { $0.id == saved.id }) { state.cards[index] = saved } else { state.cards.append(saved) }
        }
    }
}
