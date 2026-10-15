import WidgetKit
import XCTest
@testable import Tessera

/// The requests of 2026-10-15: nutrition needs calculated from the body (and kept when typed by hand),
/// more nutrients, the water mini-app removed without losing data, photo widgets laid out by their number
/// of photos, habit regularity, the free part of the exercise library, and data never overwritten.
@MainActor
final class OctoberRequestsTests: XCTestCase {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func temporaryModel(_ directory: URL? = nil) -> AppModel {
        AppModel(store: SharedStore(directory: directory ?? temporaryDirectory()))
    }

    private func bodyFilled(_ model: AppModel) {
        model.setAge(30)
        model.setWeight(70)
        model.update(\.profile) {
            $0.heightCm = 165
            $0.sex = .female
        }
    }

    // MARK: Nutrition needs

    func testTheCalculatorGivesEveryTargetFromRecognizedReferences() {
        let female = NutritionCalculator.goals(sex: .female, age: 30, heightCm: 165, weightKg: 60, activity: .light, goal: .maintain)
        // Mifflin-St Jeor: 10 × 60 + 6,25 × 165 − 5 × 30 − 161 = 1 320,25 kcal; × 1,375 = 1 815.
        XCTAssertEqual(female.kcal, 1_815, accuracy: 1)
        XCTAssertEqual(female.protein, (60 * 1.2).rounded(), "1,2 g/kg to maintain with a light activity")
        XCTAssertEqual(female.fat, (1_815 * 0.28 / 9).rounded())
        XCTAssertEqual(female.carbs, ((1_815 - female.protein * 4 - female.fat * 9) / 4).rounded(), accuracy: 1)
        XCTAssertEqual(female.fiber, (1_815 / 1_000 * 14).rounded(), "14 g per 1 000 kcal")
        XCTAssertEqual(female.sugarsMax, (1_815 * 0.1 / 4).rounded(), "Under 10 % of the calories")
        XCTAssertEqual(female.saturatedFatMax, (1_815 * 0.1 / 9).rounded())
        XCTAssertEqual(female.sodiumMaxMg, 2_300)
        XCTAssertEqual(female.ironMg, 18, "Women under 51")
        XCTAssertEqual(female.calciumMg, 1_000)
        XCTAssertEqual(female.potassiumMg, 2_600)
        XCTAssertEqual(female.vitaminCMg, 75)

        let older = NutritionCalculator.goals(sex: .female, age: 60, heightCm: 165, weightKg: 60, activity: .light, goal: .maintain)
        XCTAssertEqual(older.ironMg, 8)
        XCTAssertEqual(older.calciumMg, 1_200)

        let male = NutritionCalculator.goals(sex: .male, age: 75, heightCm: 180, weightKg: 80, activity: .active, goal: .gain)
        XCTAssertEqual(male.protein, 160, "2 g/kg to gain muscle")
        XCTAssertEqual(male.vitaminDMcg, 20, "Over 70")
        XCTAssertEqual(male.calciumMg, 1_200)
        XCTAssertEqual(male.magnesiumMg, 420)

        let neutral = NutritionCalculator.goals(sex: .neutral, age: 30, heightCm: 170, weightKg: 70, activity: .light, goal: .maintain)
        XCTAssertEqual(neutral.ironMg, 13, "The average of both references")

        let losing = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .lose)
        let keeping = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .maintain)
        XCTAssertEqual(losing.kcal, (keeping.kcal * 0.85).rounded(), accuracy: 1, "−15 % to lose weight")
        XCTAssertEqual(losing.protein, 144, "1,8 g/kg to keep muscle while losing weight")
    }

    func testANewPersonGetsCalculatedNeedsWithoutTypingAnything() {
        let model = temporaryModel()
        XCTAssertTrue(model.profile.followsNutritionCalculation)
        XCTAssertNil(model.recommendedNutritionGoals(), "Nothing calculated without the body")
        XCTAssertFalse(model.profile.knows(.kcalTarget), "No default target shown as the person's")
        XCTAssertEqual(model.nutritionCalculationMissing.count, 4)

        bodyFilled(model)
        let recommended = try? XCTUnwrap(model.recommendedNutritionGoals())
        XCTAssertEqual(model.nutrition.goals.kcal, recommended?.kcal)
        XCTAssertEqual(model.nutrition.goals.ironMg, 18)
        XCTAssertTrue(model.profile.knows(.kcalTarget), "Calculated from their body: the widgets use it")
        XCTAssertEqual(model.profile.nutritionAuto, true, "The mode is kept, not guessed again")

        // The aim changes: the needs follow.
        let before = model.nutrition.goals.kcal
        model.update(\.profile) { $0.nutritionAim = .lose }
        XCTAssertLessThan(model.nutrition.goals.kcal, before)
        // The activity changes: the needs follow.
        let lighter = model.nutrition.goals.kcal
        model.setNutritionActivity(.active)
        XCTAssertGreaterThan(model.nutrition.goals.kcal, lighter)
    }

    func testATargetTypedByHandIsNeverReplacedSilently() {
        let model = temporaryModel()
        bodyFilled(model)
        model.setNutritionTarget(.protein, 150)
        XCTAssertTrue(model.profile.customTargets.contains(.protein))
        model.setWeight(64)
        XCTAssertEqual(model.nutrition.goals.protein, 150, "Kept as typed")
        let advice = model.recommendedNutritionGoals()?.protein
        XCTAssertNotNil(advice)
        XCTAssertNotEqual(advice, 150, "The new recommendation is shown beside it")
        model.resetNutritionTarget(.protein)
        XCTAssertEqual(model.nutrition.goals.protein, advice)
    }

    func testTargetsOfAnEarlierVersionTypedByHandStayAsTheyAre() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)
        var profile = UserProfile()
        profile.provided = [.kcalTarget]
        profile.migrated = true
        profile.heightCm = 180
        profile.weightKg = 80
        profile.birthYear = DateMath.calendar.component(.year, from: Date()) - 30
        profile.sex = .male
        store.save(profile)
        var nutrition = NutritionState()
        nutrition.goals.kcal = 3_100
        store.save(nutrition)
        let model = temporaryModel(directory)
        XCTAssertFalse(model.profile.followsNutritionCalculation, "Typed by hand before: kept, not recalculated")
        model.setWeight(82)
        XCTAssertEqual(model.nutrition.goals.kcal, 3_100)
        // Turned on by the person: every target follows the calculation.
        model.setNutritionCalculation(true)
        XCTAssertEqual(model.nutrition.goals.kcal, model.recommendedNutritionGoals()?.kcal)
    }

    // MARK: More nutrients

    func testMineralsAndVitaminsAddUpWithoutMakingUpZeros() throws {
        var spinach = FoodItem(id: "a", name: "Épinards", kcal: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 2.2, servingGrams: 100, servingName: "100 g", source: .nutrientFile)
        spinach.sodiumMg = 79
        spinach.micros = Micronutrients(potassiumMg: 558, calciumMg: 99, ironMg: 2.7)
        let bread = FoodItem(id: "b", name: "Pain", kcal: 265, protein: 9, carbs: 49, fat: 3.2, fiber: 2.7, servingGrams: 50, servingName: "1 tranche", source: .custom)
        var state = NutritionState()
        let now = Date()
        state.log(spinach, grams: 200, meal: .lunch, at: now)
        state.log(bread, grams: 50, meal: .lunch, at: now)
        let totals = NutritionMath.totals(state, on: now)
        XCTAssertEqual(try XCTUnwrap(totals.micros.potassiumMg), 1_116, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(totals.micros.ironMg), 5.4, accuracy: 0.01)
        XCTAssertNil(totals.micros.vitaminCMg, "Unknown for every food: never shown as zero")
        XCTAssertEqual(try XCTUnwrap(totals.saltG), 158 * 2.5 / 1_000, accuracy: 0.001)
        let entries = NutritionMath.entries(state, on: now)
        XCTAssertEqual(NutritionMath.coverage(entries, \.micros?.potassiumMg), NutritionMath.Coverage(known: 1, total: 2), "Marked partial")
        XCTAssertEqual(NutritionTarget.potassium.eaten(totals), totals.micros.potassiumMg)
    }

    func testFoodsAndGoalsSavedBeforeStillRead() throws {
        let food = try JSONDecoder().decode(FoodItem.self, from: Data(#"{"id":"x","name":"Pomme","kcal":52,"protein":0.3,"carbs":14,"fat":0.2,"fiber":2.4,"servingGrams":150,"servingName":"1","source":"builtin"}"#.utf8))
        XCTAssertNil(food.micros)
        let goals = try JSONDecoder().decode(NutritionGoals.self, from: Data(#"{"kcal":2500,"protein":150}"#.utf8))
        XCTAssertEqual(goals.kcal, 2_500)
        XCTAssertEqual(goals.calciumMg, NutritionGoals().calciumMg)
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"customTargets":["kcal","unknownTarget"]}"#.utf8))
        XCTAssertEqual(profile.customTargets, [.kcal], "A target of a newer version is dropped, the rest kept")
        XCTAssertNil(profile.nutritionAuto)
    }

    // MARK: Water removed

    func testTheWaterWidgetsLeaveButTheDataStays() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)
        let water = WidgetDesign(kind: .hydration)
        let clock = WidgetDesign(kind: .clock)
        var combo = WidgetDesign(kind: .hydration)
        combo.options.parts = [ComboPart(kind: .hydration, options: DesignOptions(), name: "Eau", size: .small),
                               ComboPart(kind: .habitStreak, options: DesignOptions(), name: "Série", size: .small)]
        store.designs = [water, clock, combo]
        var content = ContentState()
        content.hydration.add(4, on: Date())
        store.content = content
        let model = temporaryModel(directory)
        XCTAssertEqual(model.designs.map(\.id), [clock.id, combo.id])
        XCTAssertEqual(model.designs.last?.options.parts.map(\.kind), [.habitStreak])
        XCTAssertEqual(model.designs.last?.kind, .habitStreak)
        XCTAssertEqual(model.content.hydration.glasses(on: Date()), 4, "The glasses noted stay saved")
        XCTAssertFalse(WidgetKind.offered.contains(.hydration))
        XCTAssertFalse(WidgetKind.kinds(in: .wellbeing).contains(.hydration))
    }

    // MARK: Photos and quotes

    func testPhotosAreLaidOutByTheirNumber() {
        for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
            for count in 1...4 {
                let cells = PhotoLayout.cells(count: count, family: family)
                XCTAssertEqual(cells.count, count)
                let area = cells.reduce(0) { $0 + $1.width * $1.height }
                XCTAssertEqual(area, 1, accuracy: 0.0001, "\(count) photos fill the widget (\(family))")
                for cell in cells {
                    XCTAssertGreaterThanOrEqual(cell.minX, 0)
                    XCTAssertLessThanOrEqual(cell.maxX, 1.0001)
                    XCTAssertLessThanOrEqual(cell.maxY, 1.0001)
                }
            }
        }
        // More than four: four at once, the next ones the hour after, all of them in turn.
        let photos = (0..<6).map { PhotoSlot(file: "\($0).jpg") }
        let hour = Date(timeIntervalSince1970: 3_600 * 1_000)
        let first = PhotoLayout.visible(photos, at: hour)
        let next = PhotoLayout.visible(photos, at: hour.addingTimeInterval(3_600))
        XCTAssertEqual(first.count, 4)
        XCTAssertNotEqual(first.map(\.file), next.map(\.file))
        XCTAssertEqual(PhotoLayout.visible(Array(photos.prefix(3)), at: hour).count, 3)
        XCTAssertNil(PhotoLayout.nextChange(Array(photos.prefix(4)), after: hour))
    }

    func testAFramedPhotoNeverShowsAnEmptyEdge() {
        let image = CGSize(width: 1_200, height: 800)
        let cell = CGSize(width: 170, height: 170)
        for (x, y, zoom) in [(0.5, 0.5, 1.0), (0.0, 0.0, 1.0), (1.0, 1.0, 2.5), (0.2, 0.9, 4.0), (-3.0, 7.0, 9.0)] {
            let frame = PhotoLayout.frame(image: image, cell: cell, slot: PhotoSlot(file: "a", centerX: x, centerY: y, zoom: zoom))
            XCTAssertGreaterThanOrEqual(frame.size.width + 0.001, cell.width)
            XCTAssertGreaterThanOrEqual(frame.size.height + 0.001, cell.height)
            XCTAssertLessThanOrEqual(frame.offset.x, 0.001)
            XCTAssertLessThanOrEqual(frame.offset.y, 0.001)
            XCTAssertGreaterThanOrEqual(frame.offset.x + frame.size.width, cell.width - 0.001)
            XCTAssertGreaterThanOrEqual(frame.offset.y + frame.size.height, cell.height - 0.001)
        }
    }

    func testPhotoAndQuoteWidgetsKeepTheirContentWhenSavedAndRead() throws {
        var design = WidgetDesign(kind: .photos, format: .medium)
        design.options.photos = [PhotoSlot(file: "a.jpg", centerX: 0.2, centerY: 0.7, zoom: 1.8)]
        var quote = WidgetDesign(kind: .quote, format: .small)
        quote.options.quote = QuoteContent(text: "Courage", author: "Moi")
        let read = try JSONDecoder().decode([WidgetDesign].self, from: JSONEncoder().encode([design, quote]))
        XCTAssertEqual(read[0].options.photos, design.options.photos)
        XCTAssertEqual(read[1].options.quote, quote.options.quote)
        let old = try JSONDecoder().decode(DesignOptions.self, from: Data("{}".utf8))
        XCTAssertTrue(old.photos.isEmpty)
        XCTAssertNil(old.quote)
        XCTAssertFalse(WidgetKind.offered.contains(.photos), "Made in their mini-app, not from the catalog")
    }

    // MARK: Habits

    func testHabitRegularityCountsFromTheFirstDayDone() {
        let calendar = DateMath.calendar
        let today = DateMath.startOfDay(Date())
        func key(_ daysAgo: Int) -> String { DateMath.dayKey(calendar.date(byAdding: .day, value: -daysAgo, to: today)!) }
        var habit = Habit(name: "Lire", symbol: "book", colorHex: "000000")
        XCTAssertNil(habit.regularity(days: 30), "Nothing to count before the first day")
        habit.completedDays = [key(9), key(8), key(7), key(3), key(0)]
        let month = habit.regularity(days: 30)
        XCTAssertEqual(month?.total, 10, "From the first day done")
        XCTAssertEqual(month?.done, 5)
        XCTAssertEqual(habit.bestStreak, 3)
    }

    // MARK: Exercise library

    func testTheFreeLibraryKeepsWhatThePersonAlreadyUses() {
        XCTAssertTrue((30...45).contains(ExerciseLibrary.freeCount), "Enough to build a whole program")
        XCTAssertEqual(ExerciseLibrary.freeCount, ExerciseLibrary.freeIDs.count, "Every free exercise exists")
        let model = temporaryModel()
        XCTAssertTrue(ExerciseLibrary.isOpen("bench-press", isPremium: false, owned: model.ownedExerciseIDs))
        XCTAssertFalse(ExerciseLibrary.isOpen("pec-deck", isPremium: false, owned: model.ownedExerciseIDs))
        XCTAssertTrue(ExerciseLibrary.isOpen("pec-deck", isPremium: true, owned: []))
        model.update(\.fitness) { $0.routines = [Routine(name: "Pecs", exercises: [ExerciseTemplate(name: "Pec deck", sets: 3, reps: 10, weight: 30, exerciseID: "pec-deck")])] }
        XCTAssertTrue(ExerciseLibrary.isOpen("pec-deck", isPremium: false, owned: model.ownedExerciseIDs), "Used in a routine: stays open")
    }

    func testAnExerciseAddedDuringASessionTakesWhatWasLiftedLastTime() throws {
        var state = FitnessState()
        let bench = try XCTUnwrap(ExerciseLibrary.info("bench-press"))
        XCTAssertEqual(FitnessMath.sessionTemplate(for: bench, state).sets, 3)
        state.startSession(Routine(name: "Libre", exercises: [ExerciseTemplate(name: bench.name, sets: 2, reps: 8, weight: 70, exerciseID: bench.id)]), at: Date().addingTimeInterval(-86_400))
        state.completeNextSet(at: Date().addingTimeInterval(-86_000))
        state.completeNextSet(at: Date().addingTimeInterval(-85_800))
        state.finishActive(at: Date().addingTimeInterval(-85_000))
        let template = FitnessMath.sessionTemplate(for: bench, state)
        XCTAssertEqual(template.weight, 70)
        XCTAssertEqual(template.reps, 8)
        XCTAssertEqual(template.exerciseID, "bench-press")
    }

    // MARK: Data never overwritten

    func testAButtonNeverWritesAnEmptyStateOverAFileItCantRead() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)
        // A file the store can't read (here, a folder in its place): the change is refused, nothing replaced.
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("fitness.json", isDirectory: true), withIntermediateDirectories: true)
        XCTAssertFalse(store.update(FitnessState.self) { $0.weeklyGoal = 5 })
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("fitness.json").path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        // A file that isn't there yet is created as usual.
        XCTAssertTrue(store.update(NutritionState.self) { $0.goals.kcal = 2_000 })
        XCTAssertEqual(store.state(NutritionState.self).goals.kcal, 2_000)
    }

    // MARK: Business: sales from elsewhere

    func testAStripeExportIsImportedOnceEvenTwice() throws {
        let csv = """
        id,Created date (UTC),Amount,Amount Refunded,Currency,Status,Description,Fee
        ch_1,2026-10-01 14:05:10,49.00,0.00,cad,Paid,Abonnement,1.72
        ch_2,2026-10-02 09:00:00,"1,200.00",200.00,cad,Paid,Atelier,35.10
        ch_3,2026-10-03 10:00:00,15.00,0.00,cad,Failed,Essai,0
        """
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.count, 2, "The failed payment is left out")
        XCTAssertEqual(batch.skipped, 1)
        XCTAssertEqual(batch.sales[1].amount, 1_000, accuracy: 0.001, "Refunded part taken off")
        XCTAssertEqual(batch.expenses.map(\.amount).reduce(0, +), 36.82, accuracy: 0.001, "Fees become costs")
        XCTAssertEqual(batch.currencies, ["cad"])
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(utc.component(.hour, from: batch.sales[0].date), 14, "Stripe's times are UTC")

        var state = BusinessState()
        state.sales = [SalesEntry(amount: 80, note: "Typed by hand")]
        let first = state.merge(batch)
        XCTAssertEqual(first.added, 4)
        let again = state.merge(try BusinessCSV.parse(csv))
        XCTAssertEqual(again.added, 0, "The same file again adds nothing")
        XCTAssertEqual(again.unchanged, 4)
        XCTAssertEqual(state.sales.count, 3)
        XCTAssertTrue(state.sales.contains { $0.note == "Typed by hand" }, "What was typed by hand stays")
        state.removeEntries(from: .csv)
        XCTAssertEqual(state.sales.count, 1)
    }

    func testAShopifyOrderOnSeveralLinesCountsOnce() throws {
        let csv = """
        Name,Financial Status,Paid at,Total,Lineitem name,Currency
        #1001,paid,2026-10-01 10:12:13 -0400,59.90,T-shirt,CAD
        #1001,,,,Casquette,
        #1002,refunded,2026-10-02 11:00:00 -0400,25.00,Mug,CAD
        #1003,voided,2026-10-03 11:00:00 -0400,10.00,Badge,CAD
        """
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.map(\.externalID), ["#1001"])
        XCTAssertEqual(batch.sales[0].amount, 59.90, accuracy: 0.001)
        XCTAssertEqual(batch.skipped, 3, "The second line of an order has no total; refunded and voided orders are left out")
    }

    func testABankStyleFileWithSemicolonsAndCommas() throws {
        let csv = "Date;Libellé;Montant\r\n15/10/2026;Vente marché;\"1 234,50\"\r\n16/10/2026;Loyer atelier;-450,00\r\n;Sans date;10"
        let batch = try BusinessCSV.parse(csv)
        XCTAssertEqual(batch.sales.first?.amount ?? 0, 1_234.5, accuracy: 0.001)
        XCTAssertEqual(batch.expenses.first?.amount ?? 0, 450, accuracy: 0.001, "A negative amount is a cost")
        XCTAssertEqual(batch.expenses.first?.label, "Loyer atelier")
        XCTAssertEqual(batch.skipped, 1, "No date: never guessed")
        XCTAssertNotNil(batch.sales.first?.externalID, "Without an id, the line itself is its id")
        XCTAssertThrowsError(try BusinessCSV.parse("Nom;Ville\nA;B")) { error in
            XCTAssertEqual(error as? BusinessCSV.ImportError, .missingColumns)
        }
    }

    func testAmountsOfEveryRegion() {
        XCTAssertEqual(BusinessCSV.amount("1 234,56 $"), 1_234.56)
        XCTAssertEqual(BusinessCSV.amount("$1,234.56"), 1_234.56)
        XCTAssertEqual(BusinessCSV.amount("1.234,56"), 1_234.56)
        XCTAssertEqual(BusinessCSV.amount("-12.00"), -12)
        XCTAssertEqual(BusinessCSV.amount("(12.00)"), -12)
        XCTAssertEqual(BusinessCSV.amount("1,200"), 1_200)
        XCTAssertNil(BusinessCSV.amount("—"))
    }

    func testStripeTransactionsBecomeSalesRefundsAndDailyFees() throws {
        let json = """
        {"object":"list","has_more":false,"data":[
          {"id":"txn_1","amount":4900,"fee":172,"created":1790000000,"currency":"cad","type":"charge","description":"Abonnement"},
          {"id":"txn_2","amount":-1000,"fee":0,"created":1790000500,"currency":"cad","type":"refund","description":null},
          {"id":"txn_3","amount":-20000,"fee":0,"created":1790001000,"currency":"cad","type":"payout","description":"Virement"},
          {"id":"txn_4","amount":500,"fee":0,"created":1790002000,"currency":"jpy","type":"payment","description":"Yen"}
        ]}
        """
        let page = try JSONDecoder().decode(StripeTransactions.Page.self, from: Data(json.utf8))
        let batch = StripeTransactions.batch(from: page.data)
        XCTAssertEqual(batch.sales.map(\.amount), [49, -10, 500], "Cents, except for currencies without them")
        XCTAssertEqual(batch.skipped, 1, "A payout moves money already counted")
        XCTAssertEqual(batch.expenses.count, 1)
        XCTAssertEqual(batch.expenses.first?.amount ?? 0, 1.72, accuracy: 0.001)
        XCTAssertEqual(batch.expenses.first?.externalID, "fees-\(DateMath.dayKey(Date(timeIntervalSince1970: 1_790_000_000)))")
        var state = BusinessState()
        state.merge(batch)
        XCTAssertEqual(state.merge(batch).added, 0, "A second sync adds nothing")
    }

    func testBusinessSavedBeforeStillReads() throws {
        let state = try JSONDecoder().decode(BusinessState.self, from: Data(#"{"sales":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"amount":10,"orders":1,"newCustomers":0,"visitors":0,"note":""}]}"#.utf8))
        XCTAssertEqual(state.sales.count, 1)
        XCTAssertNil(state.sales[0].source)
        XCTAssertNil(state.connections.stripe)
    }

    // MARK: Planning

    func testAPinchMovesOneScaleAtATime() {
        XCTAssertEqual(CalendarScale.step(for: 1.6), -1, "Spread: closer")
        XCTAssertEqual(CalendarScale.step(for: 0.6), 1, "Pinch: wider")
        XCTAssertEqual(CalendarScale.step(for: 1.1), 0, "A hesitant gesture changes nothing")
        XCTAssertEqual(CalendarScale.week.closer, .day)
        XCTAssertEqual(CalendarScale.week.wider, .month)
        XCTAssertNil(CalendarScale.day.closer)
        XCTAssertNil(CalendarScale.year.wider)
        let day = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9))!
        for scale in CalendarScale.allCases {
            XCTAssertTrue(scale.interval(containing: day).contains(day), "The day looked at stays in view (\(scale))")
        }
    }

    func testAnEventOverlappingAnotherIsFound() {
        let model = temporaryModel()
        let day = DateMath.calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 9))!
        let dentist = ClassSlot(courseID: nil, weekday: FitnessMath.isoWeekday(day), startMinute: 10 * 60, endMinute: 11 * 60,
                                kind: .appointment, title: "Dentiste", date: DateMath.startOfDay(day))
        model.update(\.student) { $0.slots = [dentist] }
        var new = ClassSlot(courseID: nil, weekday: FitnessMath.isoWeekday(day), startMinute: 10 * 60 + 30, endMinute: 11 * 60 + 30,
                            kind: .work, title: "Réunion", date: DateMath.startOfDay(day))
        XCTAssertEqual(PlanningCalendar.conflicts(new, on: day, model: model, events: []).map(\.title), ["Dentiste"])
        new.startMinute = 11 * 60
        new.endMinute = 12 * 60
        XCTAssertTrue(PlanningCalendar.conflicts(new, on: day, model: model, events: []).isEmpty, "Back to back is not a conflict")
        XCTAssertTrue(PlanningCalendar.conflicts(dentist, on: day, model: model, events: []).isEmpty, "Never with itself")
    }
}
