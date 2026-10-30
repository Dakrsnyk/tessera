import XCTest
@testable import Ardane

/// The notification engine (`NotificationEngine.plan`): pure, with the states and the date injected.
final class SmartNotificationEngineTests: XCTestCase {
    private let calendar = DateMath.calendar

    /// October 2026: Thursday the 8th, Friday the 9th, Sunday the 11th.
    private func day(_ d: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour, minute: minute))!
    }

    private func thursday(_ hour: Int, _ minute: Int = 0) -> Date { day(8, hour, minute) }
    private func friday(_ hour: Int, _ minute: Int = 0) -> Date { day(9, hour, minute) }
    private func sunday(_ hour: Int, _ minute: Int = 0) -> Date { day(11, hour, minute) }

    private func habit(doneDaysAgo offsets: [Int], from now: Date, name: String = "Lire") -> Habit {
        var habit = Habit(name: name, symbol: "book", colorHex: "3366FF")
        habit.completedDays = offsets.compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }.map(DateMath.dayKey)
        return habit
    }

    private func food() -> FoodItem {
        FoodItem(id: "test.engine", name: "Test", brand: nil, kcal: 100, protein: 5, carbs: 8, fat: 3, fiber: 0,
                 servingGrams: 100, servingName: "100 g", source: .custom)
    }

    private func kinds(_ plan: [NotificationEngine.Candidate], _ kind: NotificationEngine.Kind) -> [NotificationEngine.Candidate] {
        plan.filter { $0.kind == kind }
    }

    /// No spacing and a high ceiling: to look at one rule at a time.
    private func loose() -> NotificationEngine.Inputs {
        var inputs = NotificationEngine.Inputs()
        inputs.settings.minNotificationSpacingMinutes = 0
        inputs.settings.dailyNotificationCap = 10
        return inputs
    }

    // MARK: Data absent

    func testNoDataGivesNoMessage() {
        XCTAssertTrue(NotificationEngine.plan(NotificationEngine.Inputs(), now: thursday(9)).isEmpty)
        XCTAssertTrue(NotificationEngine.plan(NotificationEngine.Inputs(), now: sunday(9)).isEmpty, "no recap without a figure")
    }

    func testWaterOnlyWhenGlassesAreNotedToday() {
        var inputs = loose()
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .hydration).isEmpty)
        inputs.content.hydration.log[DateMath.dayKey(thursday(9))] = 3
        XCTAssertEqual(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .hydration).count, 1)
    }

    func testStepsNeedTheMotionData() {
        var inputs = loose()
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .steps).isEmpty, "no steps given: no reminder")
        inputs.steps = NotificationEngine.Steps(today: 1_000, goal: 8_000)
        XCTAssertEqual(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .steps).count, 1)
        inputs.steps = NotificationEngine.Steps(today: 9_000, goal: 8_000)
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .steps).isEmpty, "goal reached")
    }

    // MARK: No duplicate, nothing obsolete

    func testNothingIsPlannedTwiceNorSentAgain() {
        var inputs = NotificationEngine.Inputs()
        inputs.content.habits = [habit(doneDaysAgo: [1, 2], from: thursday(9))]
        let plan = NotificationEngine.plan(inputs, now: thursday(9))
        let left = kinds(plan, .habitsLeft)
        XCTAssertEqual(left.count, 1)
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count, "every id once")

        // The same one already sent earlier: not again.
        var log = NotificationLog()
        log.entries = [NotificationLog.Entry(id: left[0].id, categoryName: "habits", date: thursday(8))]
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, log: log, now: thursday(9)), .habitsLeft).isEmpty)

        // One still waiting (in the future) is replaced, not blocking.
        log.entries = [NotificationLog.Entry(id: left[0].id, categoryName: "habits", date: thursday(19))]
        var waiting = log
        waiting.entries.removeAll { $0.date > thursday(9) }
        XCTAssertEqual(kinds(NotificationEngine.plan(inputs, log: waiting, now: thursday(9)), .habitsLeft).count, 1)
    }

    func testTheActionDoneTakesTheNotificationBack() {
        var inputs = loose()
        inputs.content.habits = [habit(doneDaysAgo: [1, 2], from: thursday(9))]
        XCTAssertEqual(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .habitsLeft).count, 1)
        // The habit is done today: nothing left to say.
        inputs.content.habits = [habit(doneDaysAgo: [0, 1, 2], from: thursday(9))]
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .habitsLeft).isEmpty)
    }

    func testTheLunchNotNotedFollowsTheUsualHours() {
        var inputs = loose()
        for d in 5...7 { inputs.nutrition.log(food(), grams: 100, meal: .lunch, at: day(d, 12, 30)) }
        var plan = NotificationEngine.plan(inputs, now: thursday(9))
        XCTAssertEqual(kinds(plan, .lunch).first?.date, thursday(13, 30), "an hour after the usual 12:30")
        // Not enough past lunches: nothing guessed.
        var fewer = loose()
        for d in 6...7 { fewer.nutrition.log(food(), grams: 100, meal: .lunch, at: day(d, 12, 30)) }
        XCTAssertTrue(kinds(NotificationEngine.plan(fewer, now: thursday(9)), .lunch).isEmpty)
        // The lunch noted today: no reminder.
        inputs.nutrition.log(food(), grams: 100, meal: .lunch, at: thursday(9, 30))
        plan = NotificationEngine.plan(inputs, now: thursday(10))
        XCTAssertTrue(kinds(plan, .lunch).isEmpty)
    }

    // MARK: Quiet hours, ceiling, spacing, switches

    func testQuietHoursAreRespected() {
        var inputs = loose()
        inputs.content.habits = [habit(doneDaysAgo: [1, 2], from: thursday(9))]
        inputs.settings.summaryReminderHour = 23
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .habitsLeft).isEmpty, "23:00 is quiet by default")
        inputs.settings.summaryReminderHour = 19
        inputs.settings.quietStartHour = 19
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .habitsLeft).isEmpty, "quiet from 19:00")
        inputs.settings.quietStartHour = 21
        XCTAssertEqual(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .habitsLeft).count, 1)
        XCTAssertTrue(NotificationEngine.isQuiet(thursday(7, 59), settings: AppSettings()))
        XCTAssertFalse(NotificationEngine.isQuiet(thursday(8), settings: AppSettings()))
        XCTAssertTrue(NotificationEngine.isQuiet(thursday(22), settings: AppSettings()))
    }

    /// A habit left, a high task due today and the steps: three notifications for Thursday.
    private func busyThursday() -> NotificationEngine.Inputs {
        var inputs = loose()
        inputs.content.habits = [habit(doneDaysAgo: [1, 2], from: thursday(9))]
        inputs.content.tasks = [TaskItem(title: "Rendre le dossier", priority: .high, due: thursday(12))]
        inputs.steps = NotificationEngine.Steps(today: 1_000, goal: 8_000)
        return inputs
    }

    private func onThursday(_ plan: [NotificationEngine.Candidate]) -> [NotificationEngine.Candidate] {
        plan.filter { DateMath.isSameDay($0.date, thursday(9)) }
    }

    func testTheDailyCeilingIsKept() {
        var inputs = busyThursday()
        XCTAssertEqual(onThursday(NotificationEngine.plan(inputs, now: thursday(9))).count, 3)
        inputs.settings.dailyNotificationCap = 2
        let plan = onThursday(NotificationEngine.plan(inputs, now: thursday(9)))
        XCTAssertEqual(plan.count, 2)
        XCTAssertTrue(kinds(plan, .steps).isEmpty, "the least important one goes")

        // The encouragements already sent count in the day's total.
        inputs.settings.dailyNotificationCap = 3
        var encouragements = EncouragementLog()
        encouragements.entries = [
            EncouragementLog.Entry(kindName: "workout", id: "e1", date: thursday(8)),
            EncouragementLog.Entry(kindName: "meal", id: "e2", date: thursday(8, 30)),
        ]
        XCTAssertEqual(onThursday(NotificationEngine.plan(inputs, encouragements: encouragements, now: thursday(9))).count, 1)
    }

    func testTheSpacingPushesALaterOneOrDropsIt() {
        var inputs = busyThursday()
        inputs.settings.minNotificationSpacingMinutes = 90
        let plan = onThursday(NotificationEngine.plan(inputs, now: thursday(9))).sorted { $0.date < $1.date }
        for pair in zip(plan, plan.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1.date.timeIntervalSince(pair.0.date), 90 * 60)
        }
        // The task (priority) keeps 19:00, the habit follows 90 minutes later.
        XCTAssertEqual(kinds(plan, .tasksLeft).first?.date, thursday(19))
        XCTAssertEqual(kinds(plan, .habitsLeft).first?.date, thursday(20, 30))
    }

    func testADisabledCategoryGivesNothing() {
        var inputs = busyThursday()
        inputs.settings.remindsHabits = false
        let plan = NotificationEngine.plan(inputs, now: thursday(9))
        XCTAssertTrue(kinds(plan, .habitsLeft).isEmpty)
        XCTAssertFalse(kinds(plan, .tasksLeft).isEmpty, "the other categories stay")
        inputs.settings.remindsPlanning = false
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .tasksLeft).isEmpty)
    }

    func testTheFormerSwitchesStillCount() {
        var inputs = loose()
        let routine = Routine(name: "Haut du corps", exercises: [ExerciseTemplate(name: "Développé couché", sets: 1, reps: 8, weight: 60)], weekdays: [4])
        inputs.fitness.routines = [routine]
        XCTAssertEqual(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .legacyWorkout).count, 1)
        inputs.settings.remindsWorkout = false
        XCTAssertTrue(kinds(NotificationEngine.plan(inputs, now: thursday(9)), .legacyWorkout).isEmpty)
    }

    // MARK: Rest day

    func testNoFitnessReminderOnARestDay() {
        var inputs = loose()
        inputs.steps = NotificationEngine.Steps(today: 1_000, goal: 8_000)
        // Planned on Fridays only: Thursday is a rest day.
        inputs.fitness.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 1, reps: 8, weight: 60)], weekdays: [5])]
        var plan = NotificationEngine.plan(inputs, now: thursday(9))
        for kind in [NotificationEngine.Kind.steps, .sessionsLeft, .legacyWorkout] {
            XCTAssertTrue(onThursday(kinds(plan, kind)).isEmpty, "\(kind) on a rest day")
        }
        // Planned on Thursdays: the steps and the sessions left are back.
        inputs.fitness.routines[0].weekdays = [4]
        plan = NotificationEngine.plan(inputs, now: thursday(9))
        XCTAssertEqual(onThursday(kinds(plan, .steps)).count, 1)
        XCTAssertEqual(onThursday(kinds(plan, .sessionsLeft)).count, 1)
    }

    // MARK: Planning

    func testNothingForADeletedOrCancelledEvent() {
        var inputs = loose()
        let appointment = ClassSlot(courseID: nil, weekday: 5, startMinute: 14 * 60, endMinute: 15 * 60, kind: .appointment, title: "Dentiste", date: friday(0))
        inputs.student.slots = [appointment]
        var plan = NotificationEngine.plan(inputs, now: thursday(9))
        XCTAssertEqual(kinds(plan, .eventTomorrow).first?.date, thursday(19))
        XCTAssertTrue(kinds(plan, .eventTomorrow).first?.body.contains("Dentiste") == true)

        inputs.student.slots = []
        plan = NotificationEngine.plan(inputs, now: thursday(9))
        XCTAssertTrue(kinds(plan, .eventTomorrow).isEmpty, "event deleted")

        // A class every Friday: 30 minutes before, unless cancelled that day.
        var course = ClassSlot(courseID: nil, weekday: 5, startMinute: 10 * 60, endMinute: 11 * 60, kind: .course, title: "Maths")
        inputs.student.slots = [course]
        plan = NotificationEngine.plan(inputs, now: thursday(9))
        XCTAssertEqual(kinds(plan, .classSoon).first?.date, friday(9, 30))
        course.skippedDays = [DateMath.dayKey(friday(0))]
        inputs.student.slots = [course]
        plan = NotificationEngine.plan(inputs, now: thursday(9))
        XCTAssertTrue(kinds(plan, .classSoon).isEmpty, "class cancelled")
    }

    // MARK: Habits

    func testRegularityDoesNotCountTheDaysNotPlanned() {
        var inputs = loose()
        var reading = habit(doneDaysAgo: [], from: sunday(12))
        reading.completedDays = [DateMath.dayKey(day(5, 12)), DateMath.dayKey(day(7, 12))]   // Monday and Wednesday
        inputs.content.habits = [reading]

        // Every day: from the first day done, seven days, two done.
        var week = NotificationEngine.weekRegularity(inputs, now: sunday(12))
        XCTAssertEqual(week.done, 2)
        XCTAssertEqual(week.total, 7)

        // Monday, Wednesday and Friday only: Friday missed, the four other days don't count.
        inputs.habitSchedule = [reading.id: [1, 3, 5]]
        week = NotificationEngine.weekRegularity(inputs, now: sunday(12))
        XCTAssertEqual(week.done, 2)
        XCTAssertEqual(week.total, 3)

        // Sunday is not a planned day: nothing left to do, but the week's summary comes.
        let plan = NotificationEngine.plan(inputs, now: sunday(12))
        XCTAssertTrue(kinds(plan, .habitsLeft).isEmpty)
        XCTAssertEqual(kinds(plan, .habitsWeek).count, 1)
    }

    // MARK: Settings

    func testSettingsFromBeforeKeepEverythingAndGetDefaults() throws {
        let old = #"{"remindsWorkout": false, "workoutReminderHour": 7, "remindsBills": true}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        XCTAssertFalse(settings.remindsWorkout)
        XCTAssertEqual(settings.workoutReminderHour, 7)
        XCTAssertTrue(settings.remindsHabits)
        XCTAssertEqual(settings.dailyNotificationCap, 4)
        XCTAssertEqual(settings.quietStartHour, 22)
        XCTAssertEqual(settings.quietEndHour, 8)
        XCTAssertEqual(settings.summaryReminderHour, 19)
        let log = try JSONDecoder().decode(NotificationLog.self, from: Data(#"{"entries":[{"id":"a"}]}"#.utf8))
        XCTAssertEqual(log.entries.count, 1)
    }
}
