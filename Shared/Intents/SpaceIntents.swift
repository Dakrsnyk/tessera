import AppIntents
import Foundation
import WidgetKit

// Buttons of the mini-app widgets. Each one writes to the shared store, then refreshes the widgets.

private func refreshWidgets() {
    WidgetCenter.shared.reloadAllTimelines()
}

extension Notification.Name {
    /// The workout was changed outside the app's screens (Lock Screen, Dynamic Island, a widget):
    /// the app reads it back, so the session has a single state everywhere.
    static let workoutSavedOutside = Notification.Name("tessera.workoutSavedOutside")
}

/// Saves a workout change made by a button outside the app, then updates the widgets, the app
/// (when it is running) and the Live Activity.
private func changeWorkout(_ change: (inout FitnessState) -> Void) async {
    SharedStore.shared.update(FitnessState.self, change)
    refreshWidgets()
    await MainActor.run { NotificationCenter.default.post(name: .workoutSavedOutside, object: nil) }
    await WorkoutLiveActivity.sync(SharedStore.shared.state(FitnessState.self))
    // The workout begun: no reminder for it tonight.
    await SmartReminders.refresh()
}

/// A Live Activity intent: from a widget, the Lock Screen or the Live Activity, it runs in the app's
/// process, so it can start the workout's Live Activity and update its rest countdown.
struct CompleteSetIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Valider la série"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await changeWorkout { $0.completeNextSet(at: Date()) }
        return .result()
    }
}

struct PauseRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Mettre le repos en pause"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await changeWorkout { $0.pauseRest(at: Date()) }
        return .result()
    }
}

struct ResumeRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Reprendre le repos"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await changeWorkout { $0.resumeRest(at: Date()) }
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Passer le repos"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await changeWorkout { $0.skipRest() }
        return .result()
    }
}

struct LogFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Ajouter un aliment"
    static var isDiscoverable = false

    @Parameter(title: "Aliment")
    var foodID: String

    init() {}

    init(foodID: String) {
        self.foodID = foodID
    }

    func perform() async throws -> some IntentResult {
        let id = foodID
        SharedStore.shared.update(NutritionState.self) { state in
            let known = state.favorites + state.customFoods + state.recentFoods
            guard let food = known.first(where: { $0.id == id }) ?? FoodDatabase.item(id) else { return }
            let now = Date()
            state.log(food, grams: food.servingGrams, meal: MealType.current(at: now), at: now)
        }
        refreshWidgets()
        // A meal noted: no « Rien de noté aujourd'hui » this evening.
        await SmartReminders.refresh()
        return .result()
    }
}

struct QuickExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Noter une dépense"
    static var isDiscoverable = false

    @Parameter(title: "Dépense")
    var expenseID: String

    init() {}

    init(expenseID: String) {
        self.expenseID = expenseID
    }

    func perform() async throws -> some IntentResult {
        let id = expenseID
        SharedStore.shared.update(BudgetState.self) { state in
            guard let quick = state.quickExpenses.first(where: { $0.id.uuidString == id }) else { return }
            state.add(Expense(amount: quick.amount, categoryID: quick.categoryID, note: quick.name, date: Date()))
        }
        refreshWidgets()
        return .result()
    }
}

struct CounterStepIntent: AppIntent {
    static var title: LocalizedStringResource = "Compter"
    static var isDiscoverable = false

    @Parameter(title: "Compteur")
    var counterID: String

    @Parameter(title: "Pas")
    var delta: Int

    init() {
        delta = 1
    }

    init(counterID: String, delta: Int) {
        self.counterID = counterID
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: counterID) else { return .result() }
        let step = delta
        SharedStore.shared.update(ProductivityState.self) { $0.stepCounter(id, by: step) }
        refreshWidgets()
        return .result()
    }
}

struct TogglePriorityIntent: AppIntent {
    static var title: LocalizedStringResource = "Cocher une priorité"
    static var isDiscoverable = false

    @Parameter(title: "Priorité")
    var priorityID: String

    init() {}

    init(priorityID: String) {
        self.priorityID = priorityID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: priorityID) else { return .result() }
        SharedStore.shared.update(ProductivityState.self) { $0.togglePriority(id) }
        refreshWidgets()
        return .result()
    }
}

struct ToggleProjectTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Cocher une tâche du projet"
    static var isDiscoverable = false

    @Parameter(title: "Projet")
    var projectID: String

    @Parameter(title: "Tâche")
    var taskID: String

    init() {}

    init(projectID: String, taskID: String) {
        self.projectID = projectID
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let project = UUID(uuidString: projectID), let task = UUID(uuidString: taskID) else { return .result() }
        SharedStore.shared.update(ProductivityState.self) { $0.toggleProjectTask(project: project, task: task) }
        refreshWidgets()
        return .result()
    }
}

struct RevealCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Retourner la fiche"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        SharedStore.shared.update(StudentState.self) { $0.isCardRevealed.toggle() }
        refreshWidgets()
        return .result()
    }
}

struct GradeCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Noter la fiche"
    static var isDiscoverable = false

    @Parameter(title: "Je savais")
    var known: Bool

    init() {
        known = true
    }

    init(known: Bool) {
        self.known = known
    }

    func perform() async throws -> some IntentResult {
        let wasKnown = known
        SharedStore.shared.update(StudentState.self) { $0.gradeDueCard(known: wasKnown) }
        refreshWidgets()
        return .result()
    }
}

struct ToggleAssignmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Cocher un devoir"
    static var isDiscoverable = false

    @Parameter(title: "Devoir")
    var assignmentID: String

    init() {}

    init(assignmentID: String) {
        self.assignmentID = assignmentID
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: assignmentID) else { return .result() }
        SharedStore.shared.update(StudentState.self) { $0.toggleAssignment(id) }
        refreshWidgets()
        return .result()
    }
}
