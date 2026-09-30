import Foundation

/// One thing of a day, whatever part of Tessera it comes from: a calendar event, a class, an exam, a
/// piece of homework, a task, a deadline, a workout.
struct AgendaItem: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case event, classSlot, exam, assignment, task, deadline, workout
    }

    var id: String
    var kind: Kind
    var title: String
    var detail: String?
    /// Nil for something of the day without a time (a task, homework to hand in).
    var start: Date?
    var end: Date?
    var colorHex: String
    var symbol: String
    /// For what can be checked off here (tasks, homework).
    var isDone: Bool?

    var taskID: UUID? { kind == .task ? UUID(uuidString: String(id.dropFirst(5))) : nil }
    var assignmentID: UUID? { kind == .assignment ? UUID(uuidString: String(id.dropFirst(11))) : nil }

    /// "14:00" or "Journée".
    var timeText: String {
        guard let start else { return "Journée" }
        return Fmt.time(start, uses24Hour: true)
    }
}

/// Gathers a day from every source, in the order of the day. The calendar events are read once by
/// the screen (EventKit) and passed in.
enum Agenda {
    static func items(on day: Date, model: AppModel, events: [EventSnapshot], includeDone: Bool = true) -> [AgendaItem] {
        var items: [AgendaItem] = []
        for event in events where DateMath.isSameDay(event.start, day) || (event.isAllDay && event.start <= day && event.end > DateMath.startOfDay(day)) {
            items.append(AgendaItem(
                id: "event-\(event.id)", kind: .event, title: event.title, detail: event.location,
                start: event.isAllDay ? nil : event.start, end: event.isAllDay ? nil : event.end,
                colorHex: event.colorHex, symbol: "calendar"
            ))
        }
        let student = model.student
        for occurrence in StudentMath.occurrences(student, on: day) {
            let course = student.course(occurrence.slot.courseID)
            items.append(AgendaItem(
                id: "class-\(occurrence.slot.id)-\(DateMath.dayKey(day))", kind: .classSlot, title: course?.name ?? "Cours",
                detail: occurrence.slot.room.isEmpty ? nil : "Salle \(occurrence.slot.room)",
                start: occurrence.start, end: occurrence.end, colorHex: course?.colorHex ?? "D6409F", symbol: "graduationcap.fill"
            ))
        }
        for exam in student.exams where DateMath.isSameDay(exam.date, day) {
            items.append(AgendaItem(
                id: "exam-\(exam.id)", kind: .exam, title: "Examen : \(exam.title)", detail: exam.room.isEmpty ? nil : "Salle \(exam.room)",
                start: exam.date, colorHex: "E5484D", symbol: "exclamationmark.circle.fill"
            ))
        }
        for assignment in student.assignments where DateMath.isSameDay(assignment.due, day) && (includeDone || !assignment.isDone) {
            items.append(AgendaItem(
                id: "assignment-\(assignment.id)", kind: .assignment, title: assignment.title,
                detail: student.course(assignment.courseID)?.name, start: nil, colorHex: "D6409F", symbol: "doc.text.fill", isDone: assignment.isDone
            ))
        }
        for task in model.content.tasks where task.isDue(on: day) && (includeDone || !task.isDone) {
            items.append(AgendaItem(
                id: "task-\(task.id)", kind: .task, title: task.title, detail: task.priority == .none ? nil : "Priorité \(task.priority.title.lowercased())",
                start: task.hasTime ? task.due : nil, colorHex: task.priority.colorHex ?? "3366FF", symbol: "checkmark.circle", isDone: task.isDone
            ))
        }
        for deadline in model.productivity.deadlines where DateMath.isSameDay(deadline.date, day) {
            items.append(AgendaItem(
                id: "deadline-\(deadline.id)", kind: .deadline, title: deadline.title, detail: "Échéance",
                start: deadline.date, colorHex: "F2A33A", symbol: "flag.fill"
            ))
        }
        let weekday = FitnessMath.isoWeekday(day)
        for routine in model.fitness.routines where routine.weekdays.contains(weekday) {
            items.append(AgendaItem(
                id: "workout-\(routine.id)-\(DateMath.dayKey(day))", kind: .workout, title: routine.name,
                detail: "Séance · environ \(max(5, routine.exercises.reduce(0) { $0 + $1.sets * (40 + $1.restSeconds) } / 60)) min",
                start: nil, colorHex: "E5484D", symbol: "figure.strengthtraining.traditional"
            ))
        }
        return items.sorted { lhs, rhs in
            switch (lhs.start, rhs.start) {
            case (nil, nil): return lhs.kind.rawValue < rhs.kind.rawValue
            case (nil, _): return true
            case (_, nil): return false
            case let (a?, b?): return a < b
            }
        }
    }

    /// Everything a week holds, day by day (Monday first).
    static func week(containing date: Date, model: AppModel, events: [EventSnapshot]) -> [(day: Date, items: [AgendaItem])] {
        DateMath.week(containing: date).map { day in (day, items(on: day, model: model, events: events)) }
    }
}
