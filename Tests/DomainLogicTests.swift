import WidgetKit
import XCTest
@testable import Tessera

/// Logic of the V2 mini-apps and of the widgets they feed.
final class DomainLogicTests: XCTestCase {
    private var cal: Calendar { DateMath.calendar }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: Nutrition

    func testNutritionTotalsAndStreak() {
        var state = NutritionState()
        let apple = FoodDatabase.item("builtin.apple")!
        let now = date(2026, 9, 28, 13)
        state.log(apple, grams: 200, meal: .lunch, at: now)
        state.log(apple, grams: 100, meal: .snack, at: date(2026, 9, 27, 16))
        let today = NutritionMath.totals(state, on: now)
        XCTAssertEqual(today.kcal, 104, accuracy: 0.01)
        XCTAssertEqual(NutritionMath.trackingStreak(state, until: now), 2)
        XCTAssertEqual(NutritionMath.entries(state, on: now).count, 1)
    }

    func testCalculatorGivesPlausibleGoals() {
        let goals = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .maintain)
        XCTAssertEqual(goals.kcal, 2_759, accuracy: 5)
        XCTAssertEqual(goals.protein, 128, accuracy: 1)
        XCTAssertGreaterThan(goals.carbs, 0)
    }

    // MARK: Fitness

    func testCompletingSetsMovesThroughTheRoutineAndStartsRest() {
        var state = FitnessState()
        state.routines = [Routine(name: "Test", exercises: [
            ExerciseTemplate(name: "A", sets: 2, reps: 10, weight: 50, restSeconds: 60),
            ExerciseTemplate(name: "B", sets: 1, reps: 5, weight: 100, restSeconds: 90),
        ], weekdays: [])]
        let start = date(2026, 9, 28, 18)
        state.completeNextSet(at: start)
        XCTAssertEqual(state.active?.sets.count, 1)
        XCTAssertEqual(state.active?.restEndsAt, start.addingTimeInterval(60))
        state.completeNextSet(at: start.addingTimeInterval(120))
        XCTAssertEqual(state.active?.currentExercise?.name, "B")
        state.completeNextSet(at: start.addingTimeInterval(240))
        XCTAssertNil(state.active, "The finished session moves to history")
        XCTAssertEqual(state.history.count, 1)
        XCTAssertEqual(FitnessMath.records(state).first?.exercise, "B")
    }

    // MARK: Budget

    func testBudgetRemainingAndBills() {
        var state = BudgetState()
        state.monthlyBudget = 1_000
        let now = date(2026, 9, 20)
        state.add(Expense(amount: 250, categoryID: BudgetState.fixedID(1), note: "", date: date(2026, 9, 5)))
        state.add(Expense(amount: 100, categoryID: BudgetState.fixedID(2), note: "", date: date(2026, 8, 30)))
        XCTAssertEqual(BudgetMath.remaining(state, at: now), 750, accuracy: 0.001)
        XCTAssertEqual(BudgetMath.byCategory(state, in: BudgetMath.monthInterval(now)).first?.name, "Épicerie")
        let rent = Bill(name: "Loyer", amount: 1_200, anchorDate: date(2026, 1, 1))
        XCTAssertEqual(DateMath.dayKey(rent.nextDue(after: now)), "2026-10-01")
        XCTAssertEqual(DateMath.dayKey(rent.nextDue(after: date(2026, 10, 1, 8))), "2026-10-01")
    }

    // MARK: Business

    func testBusinessGoalProfitAndKPIs() {
        var state = BusinessState()
        state.monthlyGoal = 2_000
        let now = date(2026, 9, 15)
        state.sales = [
            SalesEntry(date: date(2026, 9, 2), amount: 600, orders: 3, newCustomers: 2, visitors: 100),
            SalesEntry(date: date(2026, 9, 10), amount: 400, orders: 2, newCustomers: 1, visitors: 100),
        ]
        state.expenses = [BusinessExpense(date: date(2026, 9, 3), amount: 250, label: "Pub")]
        XCTAssertEqual(BusinessMath.goalProgress(state, at: now), 0.5, accuracy: 0.001)
        let profit = BusinessMath.profit(state, month: now)
        XCTAssertEqual(profit.profit, 750, accuracy: 0.001)
        XCTAssertEqual(profit.margin ?? 0, 0.75, accuracy: 0.001)
        let kpis = BusinessMath.kpis(state, month: now)
        XCTAssertEqual(kpis.orders, 5)
        XCTAssertEqual(kpis.averageBasket ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(kpis.conversion ?? 0, 0.025, accuracy: 0.0001)
    }

    // MARK: Student

    func testWeightedAverageAndSpacedRepetition() {
        var state = StudentState()
        let math = Course(name: "Maths", credits: 3)
        let art = Course(name: "Art", credits: 1)
        state.courses = [math, art]
        state.grades = [
            Grade(courseID: math.id, title: "A", score: 80, maxScore: 100, weight: 50),
            Grade(courseID: math.id, title: "B", score: 60, maxScore: 100, weight: 50),
            Grade(courseID: art.id, title: "C", score: 18, maxScore: 20, weight: 100),
        ]
        XCTAssertEqual(StudentMath.courseAverage(state, course: math.id) ?? 0, 70, accuracy: 0.001)
        XCTAssertEqual(StudentMath.overallAverage(state) ?? 0, 75, accuracy: 0.001)

        let now = date(2026, 9, 28, 9)
        state.cards = [Flashcard(front: "Q", back: "R", box: 1, due: now.addingTimeInterval(-60))]
        state.gradeDueCard(known: true, at: now)
        XCTAssertEqual(state.cards[0].box, 2)
        XCTAssertEqual(DateMath.daysBetween(now, state.cards[0].due), 2)
        XCTAssertNil(StudentMath.dueCard(state, at: now))
    }

    func testNextClassFindsTheOngoingThenTheNextOne() {
        var state = StudentState()
        let course = Course(name: "Bio")
        state.courses = [course]
        let monday = date(2026, 9, 28, 9)
        state.slots = [
            ClassSlot(courseID: course.id, weekday: 1, startMinute: 8 * 60 + 30, endMinute: 10 * 60),
            ClassSlot(courseID: course.id, weekday: 3, startMinute: 13 * 60, endMinute: 14 * 60),
        ]
        XCTAssertEqual(StudentMath.nextClass(state, at: monday)?.slot.weekday, 1)
        XCTAssertEqual(StudentMath.nextClass(state, at: date(2026, 9, 28, 11))?.slot.weekday, 3)
    }

    // MARK: Travel, car, productivity

    func testTripDayAndOffsets() {
        let trip = Trip(destination: "Lisbonne", start: date(2026, 10, 1, 21), end: date(2026, 10, 10, 18), timeZoneID: "Europe/Lisbon")
        XCTAssertEqual(TravelMath.tripDay(trip, at: date(2026, 10, 4)).day, 4)
        XCTAssertEqual(TravelMath.tripDay(trip, at: date(2026, 10, 4)).total, 10)
        var state = TravelState()
        state.trips = [trip]
        XCTAssertTrue(TravelMath.isOngoing(trip, at: date(2026, 10, 1, 8)))
        XCTAssertEqual(TravelMath.currentTrip(state, at: date(2026, 9, 1))?.destination, "Lisbonne")
    }

    func testFuelConsumptionFullToFull() {
        var state = CarState()
        state.fills = [
            FuelFill(date: date(2026, 9, 1), liters: 40, total: 64, odometer: 10_000),
            FuelFill(date: date(2026, 9, 10), liters: 35, total: 56, odometer: 10_500),
            FuelFill(date: date(2026, 9, 20), liters: 36, total: 60, odometer: 11_000),
        ]
        XCTAssertEqual(CarMath.consumption(state) ?? 0, 7.1, accuracy: 0.001)
        XCTAssertEqual(CarMath.odometer(state), 11_000)
        state.services = [ServiceItem(name: "Vidange", intervalKm: 8_000, lastKm: 5_000)]
        XCTAssertEqual(CarMath.serviceStatus(state, at: date(2026, 9, 21)).first?.kmLeft ?? 0, 2_000, accuracy: 0.001)
    }

    func testCountersResetDailyAndFocusStopsEarly() {
        var state = ProductivityState()
        let counter = CounterItem(name: "Cafés", step: 1, goal: 3)
        state.counters = [counter]
        let today = date(2026, 9, 28, 9)
        state.stepCounter(counter.id, by: 1, on: today)
        state.stepCounter(counter.id, by: 1, on: today)
        XCTAssertEqual(state.counters[0].value(on: today), 2)
        XCTAssertEqual(state.counters[0].value(on: date(2026, 9, 29, 9)), 0)

        state.logFocusStart(at: today, minutes: 50)
        state.logFocusStop(at: today.addingTimeInterval(20 * 60))
        XCTAssertEqual(state.focusLog.last?.minutes, 20)
        XCTAssertEqual(ProductivityMath.focusMinutes(state, weekOf: today.addingTimeInterval(3600)), 20, accuracy: 0.01)
    }

    // MARK: Dates, holidays, moon

    func testHolidays() {
        XCTAssertEqual(DateMath.dayKey(Holidays.easter(2026)), "2026-04-05")
        XCTAssertEqual(DateMath.dayKey(Holidays.easter(2027)), "2027-03-28")
        let quebec = Holidays.list(.quebec, year: 2026).map { DateMath.dayKey($0.date) }
        XCTAssertTrue(quebec.contains("2026-05-18"), "Journée nationale des patriotes")
        XCTAssertTrue(quebec.contains("2026-09-07"), "Fête du Travail")
        XCTAssertTrue(quebec.contains("2026-10-12"), "Action de grâce")
        let france = Holidays.list(.france, year: 2026).map { DateMath.dayKey($0.date) }
        XCTAssertTrue(france.contains("2026-05-14"), "Ascension")
        XCTAssertEqual(Holidays.upcoming(.quebec, from: date(2026, 12, 26), count: 1).first.map { DateMath.dayKey($0.date) }, "2027-01-01")
    }

    func testMoonPhaseAroundAKnownFullMoon() {
        let fullMoon = Date(timeIntervalSince1970: 1_790_441_340) // 26 septembre 2026, 16 h 49 UTC
        XCTAssertEqual(MoonPhase.phase(at: fullMoon), 0.5, accuracy: 0.05)
        XCTAssertGreaterThan(MoonPhase.illumination(at: fullMoon), 0.95)
    }

    func testAgeAndNextBirthday() {
        let birthday = date(2000, 3, 14)
        XCTAssertEqual(LifeMath.age(birthday: birthday, at: date(2026, 3, 14)), 26, accuracy: 0.01)
        let next = LifeMath.nextBirthday(birthday: birthday, after: date(2026, 9, 28))
        XCTAssertEqual(next.age, 27)
        XCTAssertEqual(DateMath.dayKey(next.date), "2027-03-14")
    }

    // MARK: Analyses

    func testPhrasingsMayNotInventNumbers() {
        let facts = ["Reste : 1 240 kcal", "Protéines restantes : 45 g"]
        XCTAssertTrue(InsightCache.isGrounded("Encore 1240 kcal et 45 g de protéines.", facts: facts))
        XCTAssertFalse(InsightCache.isGrounded("Encore 1300 kcal.", facts: facts))
        XCTAssertEqual(InsightCache.fingerprint("abc"), InsightCache.fingerprint("abc"))
        XCTAssertNotEqual(InsightCache.fingerprint("abc"), InsightCache.fingerprint("abd"))
    }

    // MARK: Catalog and widgets

    func testEveryNewWidgetBelongsToOneGalleryGroup() {
        let original: Set<WidgetKind> = [.clock, .calendar, .worldClock, .progress, .countdown, .yearDots, .tasks, .habits, .focus, .upNext, .note, .weather, .crypto, .moneyFlow, .hydration]
        for kind in WidgetKind.allCases where !original.contains(kind) {
            XCTAssertEqual(WidgetGroup.allCases.filter { $0.kinds.contains(kind) }.count, 1, "\(kind)")
        }
        XCTAssertEqual(Set(WidgetGroup.allCases.map(\.kindID)).count, WidgetGroup.allCases.count)
        XCTAssertTrue((20...30).contains(WidgetKind.freeKinds.count))
        XCTAssertTrue((60...100).contains(WidgetKind.allCases.count - WidgetKind.freeKinds.count))
    }

    func testEveryWidgetRendersItsSampleContent() {
        let now = date(2026, 9, 28, 10)
        for kind in WidgetKind.allCases {
            let payload = SamplePayload.make(for: kind, now: now)
            let design = WidgetDesign(kind: kind)
            for family in kind.families {
                let context = RenderContext(design: design, style: ResolvedStyle(design: design), family: family, date: now, payload: payload, isInteractive: false)
                let tile = TileFactory.make(context)
                XCTAssertFalse(tile.title.isEmpty, "\(kind)")
                if WidgetGroup.group(for: kind) != nil {
                    XCTAssertNil(tile.empty, "\(kind) \(family) should show its sample data")
                }
            }
        }
    }

    func testSpaceDeepLinkRoundTrip() {
        XCTAssertEqual(DeepLink(url: DeepLink.space("nutrition").url), .space("nutrition"))
        XCTAssertEqual(DeepLink(url: DeepLink.store.url), .store)
    }

    func testOldSavedDataStillDecodes() throws {
        let empty = Data("{}".utf8)
        XCTAssertNoThrow(try JSONDecoder().decode(NutritionState.self, from: empty))
        XCTAssertNoThrow(try JSONDecoder().decode(StudentState.self, from: empty))
        XCTAssertNoThrow(try JSONDecoder().decode(CarState.self, from: empty))
        XCTAssertEqual(try JSONDecoder().decode(BudgetState.self, from: empty).categories.count, BudgetState.defaultCategories.count)
    }

    func testPurchaseStateWithoutDebugUnlock() {
        let state = PremiumState()
        XCTAssertFalse(state.hasPurchase())
        #if DEBUG
        let previous = DebugPremium.isUnlocked
        DebugPremium.setUnlocked(false)
        XCTAssertFalse(state.isPremium(), "Without a purchase and without the test switch, Premium stays locked")
        DebugPremium.setUnlocked(true)
        XCTAssertTrue(state.isPremium())
        DebugPremium.setUnlocked(previous)
        #endif
    }
}
