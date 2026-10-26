import XCTest
@testable import Tessera

/// « À remplir » in the mini-apps: what each one still asks for follows the same « filled » rule as
/// « Mes informations », a card leaves once its answer is given, and nothing is left to show when all is given.
@MainActor
final class MiniAppToFillTests: XCTestCase {
    private func temporaryModel() -> AppModel {
        AppModel(store: SharedStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)))
    }

    private func toFill(_ model: AppModel, _ app: MiniApp) -> Set<DataItem> {
        Set(model.toFillItems(in: app))
    }

    /// The mini-apps that ask something (all but « Photos et citations »).
    private var asking: [MiniApp] { MiniApp.allCases.filter { !$0.toFillItems.isEmpty } }

    /// Gives the four answers Fitness asks for.
    private func fillFitness(_ model: AppModel) {
        model.update(\.fitness) {
            $0.routines = [Routine(name: "Jambes", exercises: [ExerciseTemplate(name: "Squat", sets: 2, reps: 8, weight: 80)], weekdays: [3])]
        }
        model.setWeeklyWorkouts(3)
        model.setWeight(70)
        model.setStepGoal(8_000)
    }

    /// Everything the mini-apps ask for.
    private func fillEverything(_ model: AppModel) {
        model.update(\.profile) { $0.provided.formUnion([.kcalTarget, .proteinTarget]) }
        fillFitness(model)
        model.updateContent { $0.habits = [Habit(name: "Lire", symbol: "book", colorHex: "7FA33A")] }
        let course = Course(name: "Mathématiques")
        model.update(\.student) {
            $0.courses = [course]
            $0.slots = [ClassSlot(courseID: course.id, weekday: 3, startMinute: 14 * 60, endMinute: 15 * 60 + 30, room: "B-204")]
            $0.exams = [Exam(title: "Chimie", date: Date().addingTimeInterval(7 * 86_400), room: "A-110")]
        }
        model.setMonthlyBudget(500)
        model.setBusinessGoal(2_000)
        model.update(\.travel) { $0.trips = [Trip(destination: "Rome", start: Date().addingTimeInterval(30 * 86_400), end: Date().addingTimeInterval(37 * 86_400))] }
        model.setCarName("Civic")
    }

    func testEmptyProfileEveryAskingMiniAppHasCardsToFill() {
        let model = temporaryModel()
        for app in asking {
            XCTAssertFalse(model.toFillItems(in: app).isEmpty, "\(app.rawValue) asks something of an empty profile")
            XCTAssertEqual(model.toFillProgress(in: app).filled, 0, "\(app.rawValue): nothing given")
            XCTAssertEqual(model.toFillProgress(in: app).total, app.toFillItems.count)
        }
        XCTAssertTrue(MiniApp.photos.toFillItems.isEmpty, "Photos et citations asks nothing")
        XCTAssertTrue(model.toFillItems(in: .photos).isEmpty)
    }

    func testFitnessAsksTheProgramTheSessionsPerWeekTheWeightAndTheStepGoal() {
        let model = temporaryModel()
        XCTAssertEqual(toFill(model, .fitness), [.routines, .weeklyWorkouts, .weight, .stepGoal])
        XCTAssertEqual(model.toFillItems(in: .fitness), [.routines, .weeklyWorkouts, .weight, .stepGoal], "In the order of the cards")
    }

    func testPartialProfileAsksLessAndOnlyForWhatIsMissing() {
        let model = temporaryModel()
        model.setWeight(70)
        model.setWeeklyWorkouts(3)
        XCTAssertEqual(toFill(model, .fitness), [.routines, .stepGoal])
        let progress = model.toFillProgress(in: .fitness)
        XCTAssertEqual(progress.filled, 2)
        XCTAssertEqual(progress.total, 4)
        XCTAssertEqual(toFill(model, .nutrition), [.kcalTarget, .macroTargets], "Another mini-app is untouched")
    }

    func testGivingAnAnswerRemovesItsCardOnly() {
        let model = temporaryModel()
        XCTAssertTrue(toFill(model, .fitness).contains(.weight))
        model.setWeight(72.5)
        XCTAssertFalse(toFill(model, .fitness).contains(.weight), "The weight is given: its card leaves")
        XCTAssertEqual(toFill(model, .fitness), [.routines, .weeklyWorkouts, .stepGoal])
        // Taking the answer back brings the card back.
        model.setWeight(nil)
        XCTAssertTrue(toFill(model, .fitness).contains(.weight))
    }

    func testTheSessionsPerWeekCardLeavesWithAnAnswerAndComesBackWhenForgotten() {
        let model = temporaryModel()
        model.setWeeklyWorkouts(4)
        XCTAssertFalse(toFill(model, .fitness).contains(.weeklyWorkouts))
        model.forget(.weeklyWorkouts)
        XCTAssertTrue(toFill(model, .fitness).contains(.weeklyWorkouts))
    }

    func testADefaultIsNotAnAnswer() {
        // The calorie goal has a default value; only what the person gave counts.
        let model = temporaryModel()
        XCTAssertTrue(toFill(model, .nutrition).contains(.kcalTarget))
        model.update(\.profile) { $0.provided.insert(.kcalTarget) }
        XCTAssertFalse(toFill(model, .nutrition).contains(.kcalTarget))
        XCTAssertTrue(toFill(model, .nutrition).contains(.macroTargets), "The macros are a separate card")
    }

    func testCompleteProfileHasNothingLeftToFill() {
        let model = temporaryModel()
        fillEverything(model)
        for app in asking {
            XCTAssertTrue(model.toFillItems(in: app).isEmpty, "\(app.rawValue) has nothing left: \(model.toFillItems(in: app))")
            let progress = model.toFillProgress(in: app)
            XCTAssertEqual(progress.filled, progress.total, app.rawValue)
        }
    }

    /// The money questions had no home but the page by category that was removed: Finances keeps them in « Mes paramètres ».
    func testFinancesSettingsKeepTheMoneyQuestionsWithoutRepeats() {
        XCTAssertEqual(MiniApp.finances.infoTopics, [.money])
        XCTAssertTrue(MiniApp.finances.hasInfo)
        XCTAssertEqual(MiniApp.finances.settingsTopic, .money)
        XCTAssertEqual(MiniApp.finances.settingsItems, [.moneyFlow], "The fixed expenses keep their own row, not repeated in the questions")
        // The first habit is added on the Habitudes page and by its « À remplir » card: no second form in Planning.
        XCTAssertFalse(MiniApp.planning.infoTopics.contains(.wellbeing))
        XCTAssertTrue(MiniApp.planning.toFillItems.contains(.habits))
        // A topic is never listed twice across the mini-apps' settings.
        let topics = MiniApp.allCases.flatMap(\.infoTopics)
        XCTAssertEqual(topics.count, Set(topics).count)
    }

    func testEveryItemOfABlockCountsAsMissingWhenEmpty() {
        // A log (meals, expenses…) with nothing yet is not « to fill »: no mini-app lists one.
        for app in MiniApp.allCases {
            XCTAssertTrue(app.toFillItems.allSatisfy(\.countsAsMissing), "\(app.rawValue) lists a log")
        }
    }
}
