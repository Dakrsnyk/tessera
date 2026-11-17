import XCTest
@testable import Ardane

/// Whole-person scenarios for the changes of 2026-11-17 (Mon Quotidien by default, Planning and Études apart, the
/// one goal shared by Sport and Nutrition): a new person, a complete profile, someone who changes goal, someone
/// who picks only a few interests, someone who uses Planning without Études, and an account that comes from
/// the previous version with its old settings and its old files. Each test is a story built on an `AppModel` over a
/// temporary store; the details of each rule are in the tests of its own file (`DailyDefaultsTests`,
/// `SharedGoalTests`, `StudiesMiniAppTests`…).
@MainActor
final class NightScenariosTests: XCTestCase {
    private let five = ["nutrition", "workout", "planning", "habits", "priorities"]

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    /// Wednesday 30 September 2026 at 9:00.
    private var now: Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 9))!
    }

    private func at(_ hour: Int) -> Date {
        DateMath.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: hour))!
    }

    private func ids(_ tiles: [DailyBrief.Tile]) -> [String] { tiles.map(\.id) }

    private func isInvitation(_ tile: DailyBrief.Tile) -> Bool {
        if case .empty = tile { return true }
        return false
    }

    /// What Mon Quotidien shows: the cards of Home with what the person removed and ordered applied.
    private func screen(_ model: AppModel) -> [DailyBrief.Tile] {
        DailyBrief.arranged(DailyCategories.home(model: model, now: now, steps: nil),
                            order: model.settings.dailyOrder, hidden: model.settings.dailyHidden)
    }

    private func rank(_ id: String) -> Int {
        DailyBrief.Category(tileID: id).flatMap { DailyDefaults.order.firstIndex(of: $0) } ?? DailyDefaults.order.count
    }

    /// A man of 30, 180 cm, 80 kg (the body of `SharedGoalTests`), moderately active.
    private func giveTheBody(_ model: AppModel, activity: NutritionCalculator.Activity = .moderate) {
        model.setAge(30)
        model.setWeight(80)
        model.update(\.profile) {
            $0.heightCm = 180
            $0.sex = .male
            $0.calculatedActivity = activity
        }
        model.followCalculatedNutritionGoals()
    }

    // MARK: A new person

    func testANewPersonSeesTheFiveCardsEmptyAndNothingIsInventedForThem() {
        let model = AppModel(store: SharedStore(directory: temporaryDirectory()))
        XCTAssertEqual(model.settings.dailyLayoutVersion, DailyDefaults.layoutVersion, "A new install starts on the current layout")
        XCTAssertTrue(model.settings.dailyOrder.isEmpty)
        XCTAssertNil(model.profile.goal, "No goal chosen yet")
        XCTAssertNil(model.recommendedNutritionGoals(), "Nothing calculated without the body")
        XCTAssertTrue(model.student.courses.isEmpty)

        let tiles = screen(model)
        XCTAssertEqual(ids(tiles), five)
        XCTAssertEqual(DailyBrief.rows(tiles).count, 5, "The five are across the width")
        guard case let .planning(items) = tiles[2] else { return XCTFail("Planning is the week table") }
        XCTAssertTrue(items.isEmpty, "An empty week")
        XCTAssertTrue([0, 1, 3, 4].allSatisfy { isInvitation(tiles[$0]) }, "The others are dotted cards, with no figure")
        XCTAssertEqual(DailyCategories.addable(shown: tiles), [.studies, .budget, .reminders, .steps, .business, .travel, .car],
                       "The « + » offers the rest, Études included")
    }

    // MARK: A complete profile

    func testACompleteProfileKeepsTheFixedOrderAndItsGoalDrivesTheTargets() throws {
        let directory = temporaryDirectory()
        let model = AppModel(store: SharedStore(directory: directory))
        model.update(\.profile) { $0.interests = Interest.allCases }
        giveTheBody(model)
        model.setGoal(.recomposition)
        model.update(\.fitness) {
            $0.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])]
        }
        model.updateContent { $0.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")] }
        let course = Course(name: "Mathématiques")
        model.update(\.student) {
            $0.courses = [course]
            $0.slots = [ClassSlot(courseID: course.id, weekday: 3, startMinute: 14 * 60, endMinute: 15 * 60 + 30, room: "B-204")]
            $0.exams = [Exam(title: "Chimie", date: self.at(16), room: "A-110")]
        }
        model.update(\.budget) { $0.add(Expense(amount: 12, categoryID: nil, date: self.now)) }

        // The goal of the one list gives the targets: a recomposition keeps the energy and asks 2 g of protein a kilo.
        let expected = NutritionCalculator.goals(sex: .male, age: 30, heightCm: 180, weightKg: 80, activity: .moderate, goal: .recomposition)
        XCTAssertEqual(model.nutrition.goals.kcal, expected.kcal, accuracy: 0.5)
        XCTAssertEqual(model.nutrition.goals.protein, 160, accuracy: 0.5)
        XCTAssertEqual(model.profile.fitnessGoal, .recomposition, "Sport reads the same goal")
        XCTAssertEqual(model.profile.nutritionAim, .maintain, "The older field follows it")

        let found = ids(screen(model))
        XCTAssertEqual(Array(found.prefix(5)), five)
        XCTAssertEqual(found, found.sorted { rank($0) < rank($1) }, "The default order, not the order of the hour")
        XCTAssertTrue(found.contains("app-studies"), "Études, from the interest and from the classes")
        XCTAssertEqual(found.count, Set(found).count, "Each card once")
        guard case .miniApp? = screen(model).first(where: { $0.id == "app-studies" }) else { return XCTFail("Études shows its figure") }

        // Everything is still there after a relaunch.
        let relaunched = AppModel(store: SharedStore(directory: directory))
        XCTAssertEqual(ids(screen(relaunched)), found)
        XCTAssertEqual(relaunched.profile.goal, .recomposition)
        XCTAssertEqual(relaunched.nutrition.goals.kcal, model.nutrition.goals.kcal, accuracy: 0.01)
    }

    // MARK: Someone who changes goal

    func testChangingGoalMovesTheCalculatedTargetsAndNeverOverwritesWhatWasTyped() throws {
        let model = AppModel(store: SharedStore(directory: temporaryDirectory()))
        giveTheBody(model)
        model.setGoal(.weightLoss)
        model.followCalculatedNutritionGoals()
        let lose = model.nutrition.goals
        model.setGoal(.cut)
        let cut = model.nutrition.goals
        XCTAssertLessThan(cut.kcal, lose.kcal, "−20 % rather than −15 %")
        XCTAssertGreaterThan(cut.protein, lose.protein, "2,2 g/kg rather than 1,8 g/kg")
        model.setGoal(.bulk)
        XCTAssertGreaterThan(model.nutrition.goals.kcal, lose.kcal)
        XCTAssertEqual(model.profile.fitnessGoal, .bulk, "One goal for Sport")
        XCTAssertEqual(model.profile.nutritionAim, .gain, "and for Nutrition")
        XCTAssertEqual(model.nutritionGoal, .massGain)

        // The same story with calories typed by hand: they stay, and the new calculation is only proposed.
        let typed = AppModel(store: SharedStore(directory: temporaryDirectory()))
        giveTheBody(typed)
        typed.setGoal(.maintain)
        typed.followCalculatedNutritionGoals()
        typed.setNutritionTarget(.kcal, 2_500)
        typed.setGoal(.cut)
        XCTAssertEqual(typed.nutrition.goals.kcal, 2_500, accuracy: 0.01, "Typed by hand: never written over")
        let proposal = try XCTUnwrap(typed.goalChangeProposal)
        XCTAssertLessThan(proposal.kcal, 2_500)
        typed.keepNutritionTargets()
        XCTAssertNil(typed.goalChangeProposal)
        XCTAssertEqual(typed.nutrition.goals.kcal, 2_500, accuracy: 0.01)

        // Taking the goal back leaves no goal at all, in both fields.
        typed.setGoal(nil)
        XCTAssertNil(typed.profile.goal)
        XCTAssertNil(typed.profile.fitnessGoal)
        XCTAssertNil(typed.profile.nutritionAim)
    }

    // MARK: Someone who picks only a few interests

    func testOnlyTheChosenInterestsAddCardsToTheFive() {
        let model = AppModel(store: SharedStore(directory: temporaryDirectory()))
        model.update(\.profile) { $0.interests = [.budget, .travel] }
        let tiles = screen(model)
        XCTAssertEqual(ids(tiles), five + ["budget", "app-travel"], "The five, then the two interests in the default order")
        XCTAssertFalse(ids(tiles).contains("app-studies"))
        XCTAssertFalse(ids(tiles).contains("app-business"))
        XCTAssertFalse(ids(tiles).contains("app-car"))
        XCTAssertTrue(tiles.prefix(5).allSatisfy(\.isWide), "The five are across the width")
        XCTAssertTrue(tiles.suffix(2).allSatisfy { !$0.isWide }, "The interests are at half width")
        XCTAssertEqual(DailyCategories.addable(shown: tiles), [.studies, .reminders, .steps, .business, .car])

        // The person adds one more with the « + »: it comes at its place.
        model.updateSettings { DailyCategories.add(.car, in: &$0) }
        XCTAssertEqual(ids(screen(model)), five + ["budget", "app-travel", "app-car"])
        // And takes a default card off: it stays off and the « + » offers it back.
        model.updateSettings { DailyCategories.remove(tileID: "habits", in: &$0) }
        XCTAssertFalse(ids(screen(model)).contains("habits"))
        XCTAssertTrue(DailyCategories.addable(shown: screen(model)).contains(.habits))
    }

    // MARK: Planning without Études

    func testPlanningCanBeUsedWithoutEtudes() {
        let model = AppModel(store: SharedStore(directory: temporaryDirectory()))
        model.update(\.profile) { $0.interests = [.productivity] }
        model.updateContent { $0.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")] }
        model.update(\.productivity) { _ = $0.addQuickTask("Appeler", on: self.now) }

        let tiles = screen(model)
        XCTAssertEqual(ids(tiles), five, "Planning, Habitudes and Top 3 are there, without any studies card")
        XCTAssertFalse(ids(tiles).contains("app-studies"))
        XCTAssertTrue(model.student.courses.isEmpty)
        let dotted = tiles.filter(isInvitation).map(\.id)
        XCTAssertEqual(dotted, ["nutrition", "workout"], "Habits and the Top 3 hold data, the week is the Planning card")

        // The mini-app is Planning's own: its questions and cards do not ask for courses or exams.
        XCTAssertEqual(MiniApp(space: .productivity), .planning)
        XCTAssertEqual(InfoArea.productivity.homeRoute, .app(.planning))
        XCTAssertEqual(MiniApp.planning.toFillItems, [.habits, .timetable])
        XCTAssertFalse(MiniApp.planning.toFillItems.contains(.exams))
        XCTAssertEqual(MiniApp.planning.infoTopics, [.productivity])
        XCTAssertFalse(model.toFillItems(in: .planning).contains(.habits), "The habit was given")

        // Études only comes with classes (or when added by hand).
        model.update(\.student) { $0.courses = [Course(name: "Mathématiques")] }
        XCTAssertTrue(ids(screen(model)).contains("app-studies"))
    }

    // MARK: An account that comes from the previous version

    func testAnExistingAccountKeepsEverythingWhenItOpensThisVersion() throws {
        let directory = temporaryDirectory()
        let store = SharedStore(directory: directory)

        // Settings written by the previous version: a hand order and sizes, a removed card, categories added with the
        // « + » in their three older forms, a page chosen on a card. No `dailyLayoutVersion`.
        let oldSettings = #"""
        {"profileName":"Léa","hasCompletedOnboarding":true,"hasSeenTutorial":true,"currencyCode":"EUR",
         "dailyOrder":["budget","nutrition"],"dailyHidden":["habits","app-car"],"dailyWide":{"workout":false,"budget":true},
         "dailyAdded":["cat-travel","quick-productivity","business"],"dailyCardPages":{"nutrition":1}}
        """#
        store.settings = try JSONDecoder().decode(AppSettings.self, from: Data(oldSettings.utf8))
        XCTAssertEqual(store.settings.dailyLayoutVersion, 0)

        // A profile with the two older goal fields, the body and calories typed by hand.
        let year = DateMath.calendar.component(.year, from: Date())
        let oldProfile = #"""
        {"interests":["studies","nutrition"],"fitnessGoal":"bulk","nutritionAim":"gain","weightKg":80,"heightCm":180,
         "sex":"male","birthYear":\#(year - 30),"calculatedActivity":1.55,"nutritionAuto":false,"migrated":true}
        """#
        store.save(try JSONDecoder().decode(UserProfile.self, from: Data(oldProfile.utf8)))
        var nutrition = NutritionState()
        nutrition.goals.kcal = 3_100
        store.save(nutrition)

        // A student file without any of the newer fields.
        let courseID = UUID()
        let oldStudent = """
        {"courses":[{"id":"\(courseID.uuidString)","name":"Maths","teacher":"M. Roy"}],"exams":[{"title":"Final","date":0}],"weeklyStudyGoalHours":8}
        """
        store.save(try JSONDecoder().decode(StudentState.self, from: Data(oldStudent.utf8)))
        var content = ContentState()
        content.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")]
        store.content = content

        let model = AppModel(store: store)

        // Settings: the layout version is applied once; what the person arranged by size and order goes, what they
        // removed, added or chose on the cards stays.
        XCTAssertEqual(model.settings.dailyLayoutVersion, DailyDefaults.layoutVersion)
        XCTAssertTrue(model.settings.dailyOrder.isEmpty)
        XCTAssertTrue(model.settings.dailyWide.isEmpty)
        XCTAssertEqual(model.settings.dailyHidden, ["habits", "app-car"])
        XCTAssertEqual(model.settings.dailyAdded, ["cat-travel", "quick-productivity", "business"])
        XCTAssertEqual(model.settings.dailyCardPages, ["nutrition": 1])
        XCTAssertEqual(model.settings.profileName, "Léa")
        XCTAssertEqual(model.settings.currencyCode, "EUR")
        XCTAssertTrue(model.settings.hasSeenTutorial, "Someone who already knew the app is not shown the tutorial")
        XCTAssertEqual(DailyLayoutRules.size(of: .empty(.workout), wide: model.settings.dailyWide), .wide, "The old half-width choice is gone")

        // Mon Quotidien: the five minus the removed Habitudes, Études (interest and classes), and the added ones.
        XCTAssertEqual(ids(screen(model)),
                       ["nutrition", "workout", "planning", "priorities", "app-studies", "app-business", "app-travel"])

        // Profile: the goal is read from the two older fields, the calories typed by hand are untouched.
        XCTAssertEqual(model.profile.goal, .bulk)
        XCTAssertEqual(model.profile.aim, .gain)
        XCTAssertEqual(model.nutritionGoal, .massGain)
        XCTAssertEqual(model.nutrition.goals.kcal, 3_100, accuracy: 0.01, "Typed by hand: not recalculated by the update")
        XCTAssertEqual(model.profile.weightKg, 80)
        XCTAssertEqual(model.profile.interests, [.studies, .nutrition])

        // Student and habits: nothing lost, and the course is found by its name.
        XCTAssertEqual(model.student.courses.map(\.id), [courseID])
        XCTAssertEqual(model.student.exams.count, 1)
        XCTAssertEqual(model.student.weeklyStudyGoalHours, 8)
        XCTAssertEqual(model.student.course(matching: "maths")?.id, courseID)
        XCTAssertEqual(model.content.habits.map(\.name), ["Lire"])

        // A second launch changes nothing, and an order the person sets afterwards is kept.
        model.updateSettings { $0.dailyOrder = ["priorities"] }
        let again = AppModel(store: store)
        XCTAssertEqual(again.settings.dailyOrder, ["priorities"], "The migration runs once")
        XCTAssertEqual(again.settings.dailyHidden, ["habits", "app-car"])
        XCTAssertEqual(ids(screen(again)).first, "priorities")
    }

    /// The oldest accounts have only one of the two goal fields: each is read, neither is rewritten by reading.
    func testAnOldAccountWithOnlyOneGoalFieldKeepsItsCalculation() throws {
        let accounts: [(String, FitnessGoal, NutritionCalculator.Goal)] = [
            (#"{"fitnessGoal":"cut"}"#, .cut, .cut),
            (#"{"nutritionAim":"lose"}"#, .weightLoss, .lose),
            (#"{"fitnessGoal":"endurance"}"#, .endurance, .performance)
        ]
        for (field, goal, expected) in accounts {
            let directory = temporaryDirectory()
            let store = SharedStore(directory: directory)
            var profile = try JSONDecoder().decode(UserProfile.self, from: Data(field.utf8))
            profile.migrated = true
            store.save(profile)
            let model = AppModel(store: store)
            XCTAssertEqual(model.profile.goal, goal, field)
            XCTAssertEqual(model.nutritionGoal, expected, field)
        }
    }
}
