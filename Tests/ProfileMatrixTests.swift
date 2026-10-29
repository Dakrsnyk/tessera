import XCTest
@testable import Ardane

/// The same checks for three kinds of person: nobody (no interest, no data), a partial profile (three interests and a
/// few answers) and a complete one (everything given). Pure logic on an `AppModel` over a temporary store: « Mon
/// Quotidien », the « À remplir » blocks, the routes of the empty cards, the age, the calculated nutrition needs,
/// the Apple Pay expenses and what survives a relaunch. All the data is built here, in the tests: nothing is
/// written in the real app and no figure is ever made up for someone who gave nothing.
@MainActor
final class ProfileMatrixTests: XCTestCase {
    private enum Level: CaseIterable {
        case empty, partial, complete
    }

    // MARK: Helpers

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    /// Wednesday 30 September 2026 at the given hour.
    private func day(_ hour: Int, minute: Int = 0) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour, minute: minute))!
    }

    private var now: Date { day(9) }

    private func ids(_ tiles: [DailyBrief.Tile]) -> [String] { tiles.map(\.id) }

    private func isEmptyCard(_ tile: DailyBrief.Tile) -> Bool {
        if case .empty = tile { return true }
        return false
    }

    private func emptyCategories(_ tiles: [DailyBrief.Tile]) -> [DailyBrief.Category] {
        tiles.compactMap { tile in
            if case let .empty(category) = tile { return category }
            return nil
        }
    }

    private func steps(_ level: Level) -> Int? { level == .complete ? 4_000 : nil }

    /// What is on screen in « Mon Quotidien »: the cards with the person's removals and order applied.
    private func tiles(_ model: AppModel, steps: Int? = nil) -> [DailyBrief.Tile] {
        DailyBrief.arranged(DailyCategories.home(model: model, now: now, steps: steps),
                            order: model.settings.dailyOrder, hidden: model.settings.dailyHidden)
    }

    private func addEveryCategory(_ model: AppModel) {
        model.updateSettings { settings in
            for category in DailyBrief.Category.allCases { DailyCategories.add(category, in: &settings) }
        }
    }

    /// The mini-apps that ask something in « À remplir » (all but « Photos et citations »).
    private var asking: [MiniApp] { MiniApp.allCases.filter { !$0.toFillItems.isEmpty } }

    private func toFill(_ model: AppModel, _ app: MiniApp) -> Set<DataItem> { Set(model.toFillItems(in: app)) }

    private func birthday(yearsAgo years: Int) -> Date {
        let date = DateMath.calendar.date(byAdding: .year, value: -years, to: Date())!
        // A day more than the whole years, so the age is exact whatever the hour of the test.
        return date.addingTimeInterval(-86_400)
    }

    // MARK: The three profiles

    private func makeModel(_ level: Level, directory: URL? = nil) -> AppModel {
        let model = AppModel(store: SharedStore(directory: directory ?? temporaryDirectory()))
        switch level {
        case .empty: break
        case .partial: fillPartial(model)
        case .complete: fillComplete(model)
        }
        return model
    }

    /// Three interests and a few answers: a weight, a calorie target, a habit and an expense noted today.
    private func fillPartial(_ model: AppModel) {
        let now = self.now
        model.update(\.profile) { $0.interests = [.nutrition, .sport, .budget] }
        model.setWeight(70)
        model.setNutritionTargets(kcal: 2_200)
        model.updateContent { $0.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")] }
        model.update(\.budget) { $0.add(Expense(amount: 12, categoryID: nil, date: now)) }
    }

    /// Every interest and every answer the « À remplir » blocks ask for.
    private func fillComplete(_ model: AppModel) {
        let now = self.now
        model.update(\.profile) {
            $0.interests = Interest.allCases
            $0.heightCm = 178
            $0.sex = .male
        }
        model.update(\.life) { $0.birthday = birthday(yearsAgo: 30) }
        model.setAge(28)
        model.setWeight(72)
        model.setNutritionTargets(kcal: 2_400, protein: 150, carbs: 250, fat: 70)
        model.setWeeklyWorkouts(3)
        model.setStepGoal(8_000)
        model.update(\.fitness) {
            $0.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])]
        }
        model.updateContent { $0.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")] }
        let course = Course(name: "Mathématiques")
        model.update(\.student) {
            $0.courses = [course]
            $0.slots = [ClassSlot(courseID: course.id, weekday: 3, startMinute: 14 * 60, endMinute: 15 * 60 + 30, room: "B-204")]
            $0.exams = [Exam(title: "Chimie", date: now.addingTimeInterval(7 * 3_600), room: "A-110")]
        }
        model.setMonthlyBudget(500)
        model.update(\.budget) { $0.add(Expense(amount: 12, categoryID: nil, date: now)) }
        model.update(\.productivity) { _ = $0.addQuickTask("Appeler", on: now) }
        model.setBusinessGoal(2_000)
        model.update(\.business) { $0.sales = [SalesEntry(date: now, amount: 1_000)] }
        model.update(\.travel) { $0.trips = [Trip(destination: "Rome", start: now.addingTimeInterval(12 * 86_400), end: now.addingTimeInterval(19 * 86_400))] }
        model.setCarName("Civic")
        model.update(\.car) { $0.fills = [FuelFill(date: now, liters: 40, total: 60, odometer: 12_000)] }
    }

    /// Everything the mini-apps keep for the person, to prove that taking a card off « Mon Quotidien » deletes nothing.
    private struct DataSnapshot: Equatable {
        var profile: UserProfile
        var nutrition: NutritionState
        var habits: [Habit]
        var routines: [Routine]
        var budget: BudgetState
        var student: StudentState
        var priorities: [PriorityItem]
        var sales: [SalesEntry]
        var trips: [Trip]
        var car: CarState

        @MainActor init(_ model: AppModel) {
            profile = model.profile
            nutrition = model.nutrition
            habits = model.content.habits
            routines = model.fitness.routines
            budget = model.budget
            student = model.student
            priorities = model.productivity.priorities
            sales = model.business.sales
            trips = model.travel.trips
            car = model.car
        }
    }

    // MARK: - (a) Mon Quotidien

    func testEmptyProfileMonQuotidienShowsNothingButThePlus() {
        let model = makeModel(.empty)
        XCTAssertTrue(model.profile.interests.isEmpty)
        let shown = tiles(model)
        XCTAssertTrue(shown.isEmpty, "No interest, no data: no card")
        XCTAssertTrue(DailyBrief.rows(shown).isEmpty)
        XCTAssertEqual(DailyCategories.addable(shown: shown), DailyBrief.Category.defaultOrder, "The « + » offers every category")
        XCTAssertTrue(DailyBrief.tiles(DailyBrief.Input(model: model, now: now, steps: nil)).isEmpty)
    }

    func testEmptyProfileAddingEveryCategoryGivesOnlyEmptyCardsInTheDefaultOrder() {
        let model = makeModel(.empty)
        addEveryCategory(model)
        let shown = tiles(model)
        XCTAssertEqual(emptyCategories(shown), DailyBrief.Category.defaultOrder)
        XCTAssertEqual(shown.count, DailyBrief.Category.allCases.count, "Only dotted cards, not one card with data")
        XCTAssertEqual(ids(shown), DailyBrief.Category.defaultOrder.map(\.tileID))
        XCTAssertTrue(DailyCategories.addable(shown: shown).isEmpty)
    }

    func testPartialProfileShowsItsDataFirstThenTheEmptyCardOfItsInterest() throws {
        let model = makeModel(.partial)
        let shown = tiles(model)
        // Morning: the meals (99), the money noted today (56), then the habits (50); the sport interest has no data yet.
        XCTAssertEqual(ids(shown), ["nutrition", "budget", "habits", "workout"])
        XCTAssertEqual(emptyCategories(shown), [.workout], "The sport interest waits for a program")
        XCTAssertTrue(shown.prefix(3).allSatisfy { !isEmptyCard($0) }, "Cards with data first")
        XCTAssertEqual(DailyCategories.addable(shown: shown),
                       [.planning, .priorities, .reminders, .steps, .business, .travel, .car],
                       "Everything not shown is in the « + », in the default order")
        guard case let .nutrition(nutrition)? = shown.first else { return XCTFail("The calorie target gives the nutrition card") }
        XCTAssertTrue(nutrition.knowsKcal)
        XCTAssertEqual(nutrition.goals.kcal, 2_200)
        XCTAssertFalse(nutrition.knowsProtein, "The macros were not given: never shown as the person's")
        XCTAssertFalse(nutrition.knowsCarbs)
        XCTAssertFalse(nutrition.knowsFat)
        let budget = try XCTUnwrap(shown.first { $0.id == "budget" })
        guard case let .budget(spent, perDay) = budget else { return XCTFail("The budget card") }
        XCTAssertEqual(spent, 12, accuracy: 0.001)
        XCTAssertNil(perDay, "No monthly budget given: no « per day » figure")
    }

    func testCompleteProfileShowsEveryCategoryWithItsData() throws {
        let model = makeModel(.complete)
        let shown = tiles(model, steps: 4_000)
        XCTAssertEqual(Set(ids(shown)), Set(DailyBrief.Category.allCases.map(\.tileID)))
        XCTAssertEqual(shown.count, DailyBrief.Category.allCases.count, "Each category once")
        XCTAssertTrue(emptyCategories(shown).isEmpty, "Everything is given: no dotted card")
        XCTAssertTrue(DailyCategories.addable(shown: shown).isEmpty, "Everything is there: no « + »")
        // The most pressing first: the class and the exam of the day, then the rest by what matters at this hour.
        XCTAssertEqual(Array(ids(shown).prefix(2)), ["planning", "reminders"])
        // The mini-apps without their own card show one figure from their data, in the default order.
        let apps = ids(shown).filter { $0.hasPrefix("app-") }
        XCTAssertEqual(apps, ["app-business", "app-travel", "app-car"])
        for tile in shown where tile.id.hasPrefix("app-") {
            guard case let .miniApp(_, caption) = tile else { return XCTFail("\(tile.id) is a mini-app card") }
            XCTAssertNotNil(caption, "\(tile.id) shows a figure from the person's data")
        }
        guard case let .budget(_, perDay)? = shown.first(where: { $0.id == "budget" }) else { return XCTFail("The budget card") }
        XCTAssertNotNil(perDay, "The monthly budget was given")
        guard case let .steps(count, goal)? = shown.first(where: { $0.id == "steps" }) else { return XCTFail("The steps card") }
        XCTAssertEqual(count, 4_000)
        XCTAssertEqual(goal, 8_000)
    }

    func testTheMoreIsGivenTheFewerDottedCardsRemain() {
        let counts = Level.allCases.map { level -> Int in
            let model = makeModel(level)
            addEveryCategory(model)
            return emptyCategories(tiles(model, steps: steps(level))).count
        }
        XCTAssertEqual(counts[0], DailyBrief.Category.allCases.count, "Empty: every category is a dotted card")
        XCTAssertLessThan(counts[1], counts[0])
        XCTAssertLessThan(counts[2], counts[1])
        XCTAssertEqual(counts[2], 0, "Complete: no dotted card left")
    }

    // MARK: - (b) « À remplir »

    func testEmptyProfileEveryAskingMiniAppHasAllItsCardsToFill() {
        let model = makeModel(.empty)
        for app in asking {
            XCTAssertEqual(model.toFillItems(in: app), app.toFillItems, "\(app.rawValue) asks for everything, in the order of its cards")
            XCTAssertEqual(model.toFillProgress(in: app).filled, 0, app.rawValue)
            XCTAssertEqual(model.toFillProgress(in: app).total, app.toFillItems.count, app.rawValue)
        }
        XCTAssertTrue(model.toFillItems(in: .photos).isEmpty, "Photos et citations asks nothing")
    }

    func testPartialProfileAsksOnlyForWhatIsMissing() {
        let model = makeModel(.partial)
        XCTAssertEqual(model.toFillItems(in: .nutrition), [.macroTargets], "The calorie target was given")
        XCTAssertEqual(model.toFillItems(in: .fitness), [.routines, .weeklyWorkouts, .stepGoal], "The weight was given")
        XCTAssertEqual(model.toFillItems(in: .planning), [.timetable, .exams], "The habit was given")
        XCTAssertEqual(model.toFillItems(in: .finances), [.monthlyBudget], "An expense is not the monthly budget, and the default amount is not an answer")
        XCTAssertEqual(model.toFillItems(in: .business), [.businessGoal])
        XCTAssertEqual(model.toFillItems(in: .travel), [.trip])
        XCTAssertEqual(model.toFillItems(in: .car), [.carName])
        XCTAssertEqual(model.toFillProgress(in: .nutrition).filled, 1)
        XCTAssertEqual(model.toFillProgress(in: .nutrition).total, 2)
        XCTAssertEqual(model.toFillProgress(in: .fitness).filled, 1)
        XCTAssertEqual(model.toFillProgress(in: .fitness).total, 4)
        XCTAssertEqual(model.toFillProgress(in: .planning).filled, 1)
        XCTAssertEqual(model.toFillProgress(in: .finances).filled, 0)
    }

    func testCompleteProfileHasNothingLeftToFill() {
        let model = makeModel(.complete)
        for app in asking {
            XCTAssertTrue(model.toFillItems(in: app).isEmpty, "\(app.rawValue) has \(model.toFillItems(in: app)) left")
            let progress = model.toFillProgress(in: app)
            XCTAssertEqual(progress.filled, progress.total, app.rawValue)
        }
    }

    func testTheCardsToFillShrinkFromEmptyToPartialToComplete() {
        let counts = Level.allCases.map { level -> Int in
            let model = makeModel(level)
            return MiniApp.allCases.reduce(0) { $0 + model.toFillItems(in: $1).count }
        }
        XCTAssertEqual(counts[0], MiniApp.allCases.reduce(0) { $0 + $1.toFillItems.count })
        XCTAssertLessThan(counts[1], counts[0])
        XCTAssertLessThan(counts[2], counts[1])
        XCTAssertEqual(counts[2], 0, "Nothing left to fill")
        // A mini-app never has more given than it has cards, and a profile never loses an answer going up.
        for app in asking {
            let filled = Level.allCases.map { makeModel($0).toFillProgress(in: app).filled }
            XCTAssertLessThanOrEqual(filled[0], filled[1], app.rawValue)
            XCTAssertLessThanOrEqual(filled[1], filled[2], app.rawValue)
        }
    }

    // MARK: - (c) Routes

    func testEveryEmptyCardOpensItsMiniAppForEveryProfile() {
        let expected: [DailyBrief.Category: HomeRoute] = [
            .nutrition: .app(.nutrition), .workout: .app(.fitness), .planning: .app(.planning),
            .habits: .app(.planning), .budget: .app(.finances), .priorities: .app(.planning),
            .reminders: .app(.planning), .steps: .page(.fitnessActivity),
            .business: .app(.business), .travel: .app(.travel), .car: .app(.car)
        ]
        XCTAssertEqual(Set(expected.keys), Set(DailyBrief.Category.allCases))
        for level in Level.allCases {
            let model = makeModel(level)
            addEveryCategory(model)
            for category in emptyCategories(tiles(model, steps: steps(level))) {
                let route = category.route
                XCTAssertEqual(route, expected[category], "\(level) \(category)")
                if case .infoArea = route { XCTFail("\(level) \(category) opens the old page « Tes données »") }
                // A card with nothing in it opens a mini-app that still asks for something.
                if case let .app(app) = route {
                    XCTAssertFalse(model.toFillItems(in: app).isEmpty, "\(level) \(category): \(app.rawValue) has nothing to fill in")
                }
            }
        }
    }

    func testEveryAreaLeadsToItsMiniAppAndNeverToTheOldPage() {
        for area in InfoArea.allCases {
            if case .infoArea = area.homeRoute { XCTFail("\(area) opens the old page") }
            if let app = area.miniApp { XCTAssertEqual(area.homeRoute, .app(app), "\(area)") }
        }
        XCTAssertEqual(InfoArea.general.homeRoute, .info)
        XCTAssertEqual(InfoArea.habits.homeRoute, .app(.planning))
        XCTAssertEqual(InfoArea.student.homeRoute, .app(.planning))
        XCTAssertEqual(InfoArea.budget.homeRoute, .app(.finances))
    }

    func testTheFillInCardFollowsTheProfile() {
        // Nobody: no interest, the general information.
        XCTAssertEqual(makeModel(.empty).firstMissingInfoRoute, .info)

        // Partial: the first mini-app with something its block asks for, in the order of the interests.
        let model = makeModel(.partial)
        XCTAssertEqual(model.firstMissingInfoRoute, .app(.nutrition), "The macros are missing")
        model.setNutritionTargets(protein: 150)
        XCTAssertEqual(model.firstMissingInfoRoute, .app(.fitness), "Nutrition is done: the program is next")
        model.update(\.fitness) {
            $0.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])]
        }
        model.setWeeklyWorkouts(3)
        model.setStepGoal(8_000)
        XCTAssertEqual(model.firstMissingInfoRoute, .app(.finances), "Sport is done: the monthly budget is next")
        model.setMonthlyBudget(500)
        // What is left (the bills, the city) is asked by no block: « Mes informations ».
        XCTAssertEqual(model.firstMissingInfoRoute, .info)

        // Complete: what no mini-app block shows never picks a mini-app, and never the old page.
        let complete = makeModel(.complete)
        XCTAssertEqual(complete.firstMissingInfoRoute, .info)
        let outside: Set<DataItem> = [.holdings, .tasks, .bills]
        XCTAssertTrue(Set(complete.completion.missing).isSubset(of: outside), "Missing: \(complete.completion.missing)")
        for level in Level.allCases {
            if case .infoArea = makeModel(level).firstMissingInfoRoute { XCTFail("\(level) opens the old page") }
        }
    }

    // MARK: - (d) Age

    func testWithoutABirthdayTheAgeFieldIsFree() {
        let model = makeModel(.empty)
        XCTAssertNil(model.life.birthday, "The field is not locked")
        XCTAssertNil(model.age, "No age is invented")
        model.setAge(31)
        XCTAssertNil(model.life.birthday)
        XCTAssertEqual(model.age, 31)
        XCTAssertEqual(model.profile.birthYear, DateMath.calendar.component(.year, from: Date()) - 31)
        model.setAge(nil)
        XCTAssertNil(model.age, "Clearing the field forgets it")
        for impossible in [0, -3, 120, 200] {
            model.setAge(31)
            model.setAge(impossible)
            XCTAssertNil(model.age, "\(impossible) is not an age")
        }
    }

    func testABirthdayGivesTheAgeAndTheTypedAgeComesBackWithoutIt() {
        let model = makeModel(.partial)
        XCTAssertNil(model.life.birthday)
        model.setAge(29)
        XCTAssertEqual(model.age, 29)
        // « Ajouter mon anniversaire »: the age is calculated from it and the field locks (`life.birthday != nil`).
        model.update(\.life) { $0.birthday = birthday(yearsAgo: 25) }
        XCTAssertEqual(model.age, 25, "The birthday wins over the typed age")
        // Taking the birthday away gives the typed age back.
        model.update(\.life) { $0.birthday = nil }
        XCTAssertEqual(model.age, 29)
    }

    func testCompleteProfileAgeIsCalculatedAndNeverOverwritten() {
        let model = makeModel(.complete)
        XCTAssertNotNil(model.life.birthday)
        XCTAssertEqual(model.age, 30, "From the birthday, not from the birth year typed before")
        model.setAge(50)
        XCTAssertEqual(model.age, 30, "The locked field cannot change the age")
        XCTAssertNotNil(model.life.birthday)
        XCTAssertTrue(model.isFilled(.birthday))
    }

    // MARK: - (e) Calculated nutrition needs

    func testEmptyProfileHasNoCalculatedNeeds() {
        let model = makeModel(.empty)
        for activity in NutritionCalculator.Activity.allCases {
            XCTAssertNil(model.calculatedNutritionGoals(activity: activity))
        }
        XCTAssertNil(model.recommendedNutritionGoals())
        XCTAssertNil(model.nutritionBreakdown)
        XCTAssertEqual(model.nutritionCalculationMissing.count, 4, "Age, height, weight and gender are all asked")
    }

    func testNeedsAreCalculatedOnlyOnceAgeHeightWeightAndGenderAreKnown() throws {
        // The partial profile has a weight and a typed calorie target, nothing else of the body.
        let model = makeModel(.partial)
        XCTAssertNil(model.calculatedNutritionGoals(activity: .moderate))
        XCTAssertEqual(model.nutritionCalculationMissing.count, 3, "Only the weight is known")
        model.setAge(30)
        XCTAssertNil(model.calculatedNutritionGoals(activity: .moderate))
        model.update(\.profile) { $0.heightCm = 178 }
        XCTAssertNil(model.calculatedNutritionGoals(activity: .moderate), "The gender is still missing")
        XCTAssertEqual(model.nutritionCalculationMissing.count, 1)
        model.update(\.profile) { $0.sex = .male }
        XCTAssertNotNil(model.calculatedNutritionGoals(activity: .moderate))
        XCTAssertTrue(model.nutritionCalculationMissing.isEmpty)
        // The calorie target typed by hand is the person's own: the calculation never replaces it.
        XCTAssertEqual(model.nutrition.goals.kcal, 2_200)
        // Taking one of the four away stops the calculation.
        model.setWeight(nil)
        XCTAssertNil(model.calculatedNutritionGoals(activity: .moderate))
    }

    func testTheBirthdayAloneSuppliesTheAgeOfTheCalculation() {
        let model = makeModel(.empty)
        model.setWeight(80)
        model.update(\.profile) {
            $0.heightCm = 180
            $0.sex = .female
        }
        XCTAssertNil(model.calculatedNutritionGoals(activity: .light), "No age yet")
        model.update(\.life) { $0.birthday = birthday(yearsAgo: 35) }
        XCTAssertNotNil(model.calculatedNutritionGoals(activity: .light), "The birthday is enough, no birth year typed")
        XCTAssertNil(model.profile.birthYear)
    }

    func testCompleteProfileNeedsGrowWithTheActivityAndKeepTheTypedTargets() throws {
        let model = makeModel(.complete)
        var previous = 0.0
        for activity in NutritionCalculator.Activity.allCases {
            let goals = try XCTUnwrap(model.calculatedNutritionGoals(activity: activity), "\(activity)")
            XCTAssertGreaterThan(goals.kcal, previous, "More activity, more calories (\(activity))")
            XCTAssertGreaterThan(goals.protein, 0)
            previous = goals.kcal
        }
        XCTAssertEqual(model.nutrition.goals.kcal, 2_400, "The targets typed by hand stay the person's own")
        XCTAssertEqual(model.nutrition.goals.protein, 150)
        XCTAssertEqual(model.nutrition.goals.carbs, 250)
        XCTAssertEqual(model.nutrition.goals.fat, 70)
    }

    func testTheTargetsFollowTheBodyAndTheActivityWhenNothingIsTyped() throws {
        let model = makeModel(.empty)
        XCTAssertEqual(model.toFillItems(in: .nutrition), [.kcalTarget, .macroTargets])
        model.setAge(30)
        model.setWeight(80)
        XCTAssertEqual(model.toFillItems(in: .nutrition), [.kcalTarget, .macroTargets], "Body incomplete: nothing calculated, nothing invented")
        model.update(\.profile) {
            $0.heightCm = 180
            $0.sex = .male
        }
        // The calculation is the person's own as soon as the four are known (light activity without workouts given).
        XCTAssertTrue(model.toFillItems(in: .nutrition).isEmpty)
        let light = try XCTUnwrap(model.calculatedNutritionGoals(activity: .light))
        XCTAssertEqual(model.nutrition.goals.kcal, light.kcal)
        XCTAssertEqual(model.nutrition.goals.protein, light.protein)

        model.setWeeklyWorkouts(6)
        let active = try XCTUnwrap(model.calculatedNutritionGoals(activity: .active))
        XCTAssertGreaterThan(active.kcal, light.kcal)
        XCTAssertEqual(model.nutrition.goals.kcal, active.kcal, "Six sessions a week: the high activity")

        model.setNutritionActivity(.sedentary)
        let sedentary = try XCTUnwrap(model.calculatedNutritionGoals(activity: .sedentary))
        XCTAssertLessThan(sedentary.kcal, light.kcal)
        XCTAssertEqual(model.nutrition.goals.kcal, sedentary.kcal, "The activity chosen leads the workouts per week")
    }

    // MARK: - (f) Apple Pay

    func testAnApplePayExpenseCountsIsToReviewThenLearnsTheMerchantForEveryProfile() throws {
        for level in Level.allCases {
            let directory = temporaryDirectory()
            let model = makeModel(level, directory: directory)
            let month = BudgetMath.monthInterval(now)
            func spent() -> Double { BudgetMath.spent(model.budget, in: month, now: now) }
            let start = spent()
            XCTAssertNil(ApplePayStatus.lastDate(model.budget), "\(level): nothing received yet (« À configurer »)")
            XCTAssertEqual(ApplePayStatus.reviewCount(model.budget), 0)

            // The Shortcuts automation delivers a payment.
            var first: ApplePayResult?
            model.update(\.budget) { first = $0.addApplePay(amount: 12.5, merchant: "Boutique Zorglub", card: "Visa", date: self.now) }
            guard case let .added(expense)? = first else { return XCTFail("\(level): the payment is recorded") }
            XCTAssertEqual(expense.source, .applePay)
            XCTAssertNil(expense.categoryID, "\(level): no category is invented for an unknown shop")
            XCTAssertEqual(expense.needsReview, true)
            XCTAssertEqual(spent() - start, 12.5, accuracy: 0.001, "\(level): counted in the month")
            XCTAssertEqual(ApplePayStatus.lastDate(model.budget), now, "\(level): the row of Finances is « Active »")
            XCTAssertEqual(ApplePayStatus.reviewCount(model.budget), 1, "\(level): one expense carries « À vérifier »")

            // The same payment delivered twice (the automation can fire twice): once.
            var again: ApplePayResult?
            model.update(\.budget) { again = $0.addApplePay(amount: 12.5, merchant: "Boutique Zorglub", card: "Visa", date: self.now.addingTimeInterval(20)) }
            if case .duplicate? = again {} else { XCTFail("\(level): a double delivery is one expense") }
            XCTAssertEqual(spent() - start, 12.5, accuracy: 0.001)

            // The person chooses a category in the list of the operations: the shop is learned, « À vérifier » leaves.
            var checked = expense
            checked.categoryID = BudgetState.fixedID(4)
            checked.needsReview = false
            model.update(\.budget) {
                $0.save(checked)
                $0.learnMerchantCategory(for: checked)
            }
            XCTAssertEqual(ApplePayStatus.reviewCount(model.budget), 0)

            // Later, the same shop written like a statement takes the category without a check.
            var second: ApplePayResult?
            model.update(\.budget) { second = $0.addApplePay(amount: 18, merchant: "BOUTIQUE ZORGLUB #55 LAVAL QC", card: nil, date: self.now.addingTimeInterval(3 * 3_600)) }
            guard case let .added(learned)? = second else { return XCTFail("\(level): the second payment is recorded") }
            XCTAssertEqual(learned.categoryID, BudgetState.fixedID(4), "\(level)")
            XCTAssertEqual(learned.needsReview, false)
            XCTAssertEqual(spent() - start, 30.5, accuracy: 0.001)
            XCTAssertEqual(ApplePayStatus.reviewCount(model.budget), 0)

            // After a relaunch the expenses and the learned rule are still there.
            let relaunched = makeModel(.empty, directory: directory)
            XCTAssertEqual(relaunched.budget.expenses.filter { $0.source == .applePay }.count, 2, "\(level)")
            XCTAssertEqual(relaunched.budget.merchantRules[ApplePayExpense.normalizedMerchant("Boutique Zorglub")], BudgetState.fixedID(4))
            XCTAssertEqual(ApplePayStatus.reviewCount(relaunched.budget), 0)
            XCTAssertEqual(BudgetMath.spent(relaunched.budget, in: month, now: now) - start, 30.5, accuracy: 0.001)
        }
    }

    func testAnApplePayExpenseNeverMakesUpABudgetForSomeoneWhoGaveNone() throws {
        let model = makeModel(.empty)
        model.update(\.budget) { _ = $0.addApplePay(amount: 12.5, merchant: "IGA", card: nil, date: self.now) }
        XCTAssertFalse(model.profile.knows(.monthlyBudget))
        let shown = tiles(model)
        XCTAssertEqual(ids(shown), ["budget"], "The money really spent today shows")
        guard case let .budget(spent, perDay)? = shown.first else { return XCTFail("The budget card") }
        XCTAssertEqual(spent, 12.5, accuracy: 0.001)
        XCTAssertNil(perDay, "The default amount of the budget is not shown as the person's")
        XCTAssertEqual(model.toFillItems(in: .finances), [.monthlyBudget], "The budget is still asked")
    }

    func testTheBudgetCardCountsEveryExpenseAndOnlyShowsAPerDayFigureWithABudget() throws {
        for level in Level.allCases {
            let model = makeModel(level)
            model.update(\.budget) { _ = $0.addApplePay(amount: 8, merchant: "Starbucks", card: nil, date: self.now.addingTimeInterval(600)) }
            guard case let .budget(spent, perDay)? = tiles(model).first(where: { $0.id == "budget" }) else { return XCTFail("\(level): the budget card") }
            XCTAssertEqual(spent, BudgetMath.spentToday(model.budget, at: now), accuracy: 0.001, "\(level)")
            XCTAssertEqual(perDay != nil, model.profile.knows(.monthlyBudget), "\(level): a per-day figure only with a monthly budget given")
        }
    }

    // MARK: - (g) Persistence

    func testEveryProfileSurvivesARelaunch() {
        for level in Level.allCases {
            let directory = temporaryDirectory()
            let model = makeModel(level, directory: directory)
            if level != .empty {
                model.updateSettings {
                    $0.profileName = "Léa"
                    DailyCategories.remove(tileID: "habits", in: &$0)
                    $0.dailyOrder = ["budget", "nutrition"]
                }
            }
            let relaunched = AppModel(store: SharedStore(directory: directory))

            XCTAssertEqual(relaunched.settings, model.settings, "\(level): the settings")
            XCTAssertEqual(relaunched.profile.interests, model.profile.interests, "\(level)")
            XCTAssertEqual(relaunched.profile.provided, model.profile.provided, "\(level)")
            XCTAssertEqual(relaunched.profile.weightKg, model.profile.weightKg)
            XCTAssertEqual(relaunched.profile.heightCm, model.profile.heightCm)
            XCTAssertEqual(relaunched.profile.birthYear, model.profile.birthYear)
            XCTAssertEqual(relaunched.profile.sex, model.profile.sex)
            XCTAssertEqual(relaunched.profile.stepGoal, model.profile.stepGoal)
            XCTAssertEqual(relaunched.profile.nutritionAuto, model.profile.nutritionAuto)
            XCTAssertEqual(relaunched.profile.customTargets, model.profile.customTargets)
            XCTAssertEqual(relaunched.life.birthday == nil, model.life.birthday == nil, "\(level): the birthday")
            if let before = model.life.birthday, let after = relaunched.life.birthday {
                XCTAssertEqual(after.timeIntervalSince1970, before.timeIntervalSince1970, accuracy: 1)
            }
            XCTAssertEqual(relaunched.age, model.age, "\(level): the age")
            XCTAssertEqual(relaunched.nutrition.goals, model.nutrition.goals, "\(level)")
            XCTAssertEqual(relaunched.fitness.routines, model.fitness.routines)
            XCTAssertEqual(relaunched.fitness.weeklyGoal, model.fitness.weeklyGoal)
            XCTAssertEqual(relaunched.content.habits, model.content.habits)
            XCTAssertEqual(relaunched.budget.monthlyBudget, model.budget.monthlyBudget)
            XCTAssertEqual(relaunched.budget.expenses.map(\.id), model.budget.expenses.map(\.id))
            XCTAssertEqual(relaunched.student.courses, model.student.courses)
            XCTAssertEqual(relaunched.student.exams.count, model.student.exams.count)
            XCTAssertEqual(relaunched.business.sales.count, model.business.sales.count)
            XCTAssertEqual(relaunched.travel.trips.map(\.destination), model.travel.trips.map(\.destination))
            XCTAssertEqual(relaunched.car.name, model.car.name)
            XCTAssertEqual(relaunched.car.fills.count, model.car.fills.count)

            // The screens built from it are the same ones.
            XCTAssertEqual(ids(tiles(relaunched, steps: steps(level))), ids(tiles(model, steps: steps(level))), "\(level): Mon Quotidien")
            for app in MiniApp.allCases {
                XCTAssertEqual(relaunched.toFillItems(in: app), model.toFillItems(in: app), "\(level) \(app.rawValue): À remplir")
            }
            XCTAssertEqual(relaunched.firstMissingInfoRoute, model.firstMissingInfoRoute, "\(level)")
        }
    }

    func testEveryProfileStateDecodesFromItsOwnEncoding() throws {
        for level in Level.allCases {
            let model = makeModel(level)
            addEveryCategory(model)
            model.updateSettings {
                $0.profileName = "Léa"
                DailyCategories.remove(tileID: "steps", in: &$0)
            }
            let settings = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(model.settings))
            XCTAssertEqual(settings, model.settings, "\(level): AppSettings")
            let profile = try JSONDecoder().decode(UserProfile.self, from: JSONEncoder().encode(model.profile))
            XCTAssertEqual(profile, model.profile, "\(level): UserProfile")
            let budget = try JSONDecoder().decode(BudgetState.self, from: JSONEncoder().encode(model.budget))
            XCTAssertEqual(budget, model.budget, "\(level): BudgetState")
            let life = try JSONDecoder().decode(LifeState.self, from: JSONEncoder().encode(model.life))
            XCTAssertEqual(life, model.life, "\(level): LifeState")
        }
    }

    func testSettingsKeepEveryChoiceThroughAnEncodingRoundTrip() throws {
        var settings = AppSettings()
        settings.profileName = "Léa"
        settings.currencyCode = "EUR"
        settings.uses24HourClock = false
        settings.appearance = .dark
        settings.hasCompletedOnboarding = true
        settings.hasCompletedProfileSetup = true
        settings.hasSeenTutorial = true
        settings.dailyOrder = ["budget", "nutrition"]
        settings.dailyHidden = ["habits", "app-car"]
        settings.dailyWide = ["nutrition": true, "steps": false]
        settings.dailyAdded = ["cat-steps", "quick-productivity"]
        settings.dailyCardPages = ["nutrition": 1]
        settings.remindsWorkout = false
        settings.workoutReminderHour = 7
        settings.encourages = false
        settings.openCount = 12
        settings.lastCountedOpen = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(back, settings)
    }

    func testStatesSavedByAnOlderVersionStillDecodeWithTheirMissingKeysAtDefault() throws {
        // Settings from before the layout of Mon Quotidien, the « + » and the encouragements.
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"profileName":"Léa","hasCompletedOnboarding":true,"currencyCode":"EUR"}"#.utf8))
        XCTAssertEqual(settings.profileName, "Léa")
        XCTAssertEqual(settings.currencyCode, "EUR")
        XCTAssertTrue(settings.hasSeenTutorial, "Someone who already knew the app is not shown the tutorial")
        XCTAssertTrue(settings.dailyOrder.isEmpty)
        XCTAssertTrue(settings.dailyHidden.isEmpty)
        XCTAssertTrue(settings.dailyAdded.isEmpty)
        XCTAssertTrue(settings.encourages)
        XCTAssertTrue(settings.remindsWorkout)
        // Settings saved while the weather existed: its city and unit are ignored, everything else is kept.
        let weather = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"profileName":"Léa","temperatureUnit":"fahrenheit","weatherLocation":{"name":"Montréal","latitude":45.5,"longitude":-73.6},"currencyCode":"EUR"}"#.utf8))
        XCTAssertEqual(weather.profileName, "Léa")
        XCTAssertEqual(weather.currencyCode, "EUR")
        let fresh = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"profileName":"Léa"}"#.utf8))
        XCTAssertFalse(fresh.hasSeenTutorial)
        // A value out of shape (a style a newer version added) doesn't lose the rest.
        let odd = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"appStyle":"nope","currencyCode":"GBP","dailyHidden":["budget"]}"#.utf8))
        XCTAssertEqual(odd.appStyle, .sapphire)
        XCTAssertEqual(odd.currencyCode, "GBP")
        XCTAssertEqual(odd.dailyHidden, ["budget"])

        // A budget from before Apple Pay: no source, no merchant, no rules.
        let budget = try JSONDecoder().decode(BudgetState.self, from: Data(#"{"monthlyBudget":900,"expenses":[{"id":"11111111-1111-1111-1111-111111111111","amount":12.5,"note":"Café","date":780000000}]}"#.utf8))
        XCTAssertEqual(budget.monthlyBudget, 900)
        XCTAssertEqual(budget.expenses.count, 1)
        XCTAssertNil(budget.expenses.first?.source)
        XCTAssertNotEqual(budget.expenses.first?.needsReview, true)
        XCTAssertTrue(budget.merchantRules.isEmpty)
        XCTAssertEqual(budget.categories.count, BudgetState.defaultCategories.count)

        // « Ma vie » without a birthday.
        let life = try JSONDecoder().decode(LifeState.self, from: Data("{}".utf8))
        XCTAssertNil(life.birthday)
    }

    func testAnOldProfileOnDiskOpensWithoutInventingAnything() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)
        let old = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"interests":["sport","nutrition"],"weightKg":80,"birthYear":1990}"#.utf8))
        store.save(old)
        let model = AppModel(store: store)
        XCTAssertEqual(model.profile.interests, [.sport, .nutrition])
        XCTAssertEqual(model.profile.weightKg, 80)
        XCTAssertEqual(model.age, DateMath.calendar.component(.year, from: Date()) - 1990, "From the birth year, no birthday")
        XCTAssertNil(model.life.birthday)
        XCTAssertFalse(model.profile.knows(.kcalTarget), "A default is never the person's own")
        let shown = tiles(model)
        XCTAssertEqual(Set(ids(shown)), ["nutrition", "workout"])
        XCTAssertEqual(shown.count, 2)
        XCTAssertTrue(shown.allSatisfy(isEmptyCard), "Interests without data: dotted cards only")
        XCTAssertTrue(model.toFillItems(in: .fitness).contains(.routines))
        XCTAssertFalse(model.toFillItems(in: .fitness).contains(.weight), "The weight of the old profile counts as given")
        XCTAssertNil(model.calculatedNutritionGoals(activity: .light), "Height and gender are unknown")
    }

    // MARK: - (h) Taking a category off Mon Quotidien

    func testTakingCardsOffMonQuotidienDeletesNoDataAndTheyStayOff() {
        for level in [Level.partial, .complete] {
            let directory = temporaryDirectory()
            let model = makeModel(level, directory: directory)
            let before = DataSnapshot(model)
            let toFillBefore = MiniApp.allCases.map { model.toFillItems(in: $0) }
            let shownBefore = tiles(model, steps: steps(level))

            // Every card on screen is removed, the ones with data and the dotted ones.
            for tile in shownBefore {
                model.updateSettings { DailyCategories.remove(tileID: tile.id, in: &$0) }
            }
            let after = tiles(model, steps: steps(level))
            XCTAssertTrue(after.isEmpty, "\(level): every card is off")
            XCTAssertEqual(Set(DailyCategories.addable(shown: after).map(\.tileID)), Set(DailyBrief.Category.allCases.map(\.tileID)),
                           "\(level): all back in the « + »")
            XCTAssertEqual(DataSnapshot(model), before, "\(level): nothing deleted from the mini-apps")
            XCTAssertEqual(MiniApp.allCases.map { model.toFillItems(in: $0) }, toFillBefore, "\(level): À remplir unchanged")

            // New data and the interests don't bring a card back.
            model.updateContent { $0.habits.append(Habit(name: "Marcher", symbol: "figure.walk", colorHex: "12A4B5")) }
            model.setNutritionTargets(protein: 140)
            model.update(\.budget) { $0.add(Expense(amount: 5, categoryID: nil, date: self.now)) }
            XCTAssertTrue(tiles(model, steps: steps(level)).isEmpty, "\(level): data does not bring a removed card back")

            // Nor does a relaunch.
            let relaunched = AppModel(store: SharedStore(directory: directory))
            XCTAssertTrue(tiles(relaunched, steps: steps(level)).isEmpty, "\(level): removed for good")
            XCTAssertEqual(relaunched.content.habits.count, model.content.habits.count)

            // The « + » puts one back, with its data.
            relaunched.updateSettings { DailyCategories.add(.nutrition, in: &$0) }
            XCTAssertEqual(ids(tiles(relaunched, steps: steps(level))), ["nutrition"], "\(level)")
        }
    }

    func testRemovingOneEmptyCardKeepsTheInterestAndTheData() {
        let model = makeModel(.partial)
        let before = DataSnapshot(model)
        XCTAssertTrue(ids(tiles(model)).contains("workout"))
        model.updateSettings { DailyCategories.remove(tileID: "workout", in: &$0) }
        XCTAssertEqual(ids(tiles(model)), ["nutrition", "budget", "habits"])
        XCTAssertEqual(model.profile.interests, [.nutrition, .sport, .budget], "The interest itself stays")
        XCTAssertEqual(DataSnapshot(model), before)
        XCTAssertEqual(DailyCategories.addable(shown: tiles(model)).first, .workout)
    }

    // MARK: - (i) No invented figure for the empty profile

    func testEmptyProfileNeverShowsAMadeUpFigure() {
        let model = makeModel(.empty)
        let input = DailyBrief.Input(model: model, now: now, steps: nil)
        XCTAssertNil(DailyBrief.nutritionTile(input), "No kcal")
        XCTAssertNil(DailyBrief.workoutTile(input), "No session")
        XCTAssertNil(DailyBrief.planningTile(input))
        XCTAssertTrue(DailyBrief.remindersTile(input).isEmpty)
        XCTAssertTrue(DailyBrief.priorityChecks(model.productivity, now: now).isEmpty)
        XCTAssertTrue(input.budget.expenses.isEmpty, "No spending")
        XCTAssertFalse(model.profile.knows(.kcalTarget))
        XCTAssertFalse(model.profile.knows(.proteinTarget))
        XCTAssertFalse(model.profile.knows(.monthlyBudget))
        XCTAssertFalse(model.profile.knows(.weeklyWorkouts))
        XCTAssertNil(model.profile.weightKg)
        XCTAssertNil(model.profile.stepGoal)
        XCTAssertEqual(model.completion.filled, 0)
        // Nothing in the mini-apps either: the defaults behind (2 000 kcal, a 2 000 budget) are not data.
        XCTAssertTrue(model.nutrition.entries.isEmpty)
        XCTAssertTrue(model.fitness.routines.isEmpty)
        XCTAssertTrue(model.fitness.history.isEmpty)
        XCTAssertTrue(model.budget.expenses.isEmpty)
        XCTAssertTrue(model.budget.bills.isEmpty)
        XCTAssertTrue(model.budget.goals.isEmpty)
        XCTAssertTrue(model.content.habits.isEmpty)
        XCTAssertTrue(model.content.tasks.isEmpty)
        XCTAssertTrue(model.student.courses.isEmpty)
        XCTAssertTrue(model.student.slots.isEmpty)
        XCTAssertTrue(model.student.exams.isEmpty)
        XCTAssertTrue(model.business.sales.isEmpty)
        XCTAssertTrue(model.travel.trips.isEmpty)
        XCTAssertTrue(model.car.fills.isEmpty)
        // Nothing to say about any of it, in a card or a summary.
        for item in DataItem.allCases where item != .companies && item != .calendar {
            XCTAssertFalse(model.isFilled(item), "\(item.rawValue)")
            XCTAssertNil(model.summary(item, now: now), "\(item.rawValue)")
        }
        for app in MiniApp.allCases {
            XCTAssertFalse(MiniAppSummary.hasData(app, model), app.rawValue)
            XCTAssertNil(MiniAppSummary.caption(app, model, now: now), "\(app.rawValue) shows no figure")
        }
        XCTAssertTrue(tiles(model).isEmpty)
        addEveryCategory(model)
        XCTAssertTrue(emptyCategories(tiles(model)).count == DailyBrief.Category.allCases.count, "Only invitations, with their words and no number")
    }

    func testPartialProfileShowsNoFigureItDidNotGive() throws {
        let model = makeModel(.partial)
        addEveryCategory(model)
        let shown = tiles(model)
        // Only nutrition, the budget of today and the habit carry data; the other cards are dotted.
        let withData = shown.filter { !isEmptyCard($0) }
        XCTAssertEqual(ids(withData), ["nutrition", "budget", "habits"])
        XCTAssertEqual(emptyCategories(shown).count, DailyBrief.Category.allCases.count - 3)
        for app in [MiniApp.business, .travel, .car, .fitness, .planning] {
            XCTAssertNil(MiniAppSummary.caption(app, model, now: now), "\(app.rawValue) has nothing to say")
        }
        XCTAssertNil(DailyBrief.workoutTile(DailyBrief.Input(model: model, now: now, steps: nil)), "A weight is not a session")
    }
}
