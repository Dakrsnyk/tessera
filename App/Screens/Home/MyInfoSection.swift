import SwiftUI

/// One line of « Mes informations »: a value the user gave, or data they entered.
struct InfoFact: Identifiable, Hashable {
    let id: String
    let symbol: String
    let title: String
    let value: String
}

extension AppModel {
    /// What « Mes informations » shows for a topic: only what the user gave, never a default.
    func facts(for topic: ProfileTopic) -> [InfoFact] {
        let currency = settings.currencyCode
        var facts: [InfoFact] = []
        func add(_ id: String, _ symbol: String, _ title: String, _ value: String?) {
            guard let value, !value.trimmed.isEmpty else { return }
            facts.append(InfoFact(id: id, symbol: symbol, title: title, value: value))
        }
        func money(_ value: Double?) -> String? { value.map { TF.money($0, currency) } }
        switch topic {
        case .sport:
            add("goal", "target", "Objectif", profile.fitnessGoal?.title)
            add("weight", "scalemass", "Poids", profile.weightKg.map { "\(ProfileNumberField.format($0)) kg" })
            add("height", "ruler", "Taille", profile.heightCm.map(Self.heightText))
            add("age", "person", "Âge", age.map { "\($0) ans" })
            add("workouts", "calendar", "Séances", profile.knows(.weeklyWorkouts) ? "\(fitness.weeklyGoal) par semaine" : nil)
            add("level", "chart.bar.fill", "Niveau", profile.fitnessLevel?.title)
        case .nutrition:
            add("aim", "target", "Objectif", profile.nutritionAim?.title)
            add("kcal", "flame", "Calories", profile.knows(.kcalTarget) ? "\(TF.int(nutrition.goals.kcal)) kcal" : nil)
            add("protein", "bolt.heart", "Protéines", profile.knows(.proteinTarget) ? "\(TF.int(nutrition.goals.protein)) g" : nil)
            add("carbs", "leaf", "Glucides", profile.knows(.carbsTarget) ? "\(TF.int(nutrition.goals.carbs)) g" : nil)
            add("fat", "drop", "Lipides", profile.knows(.fatTarget) ? "\(TF.int(nutrition.goals.fat)) g" : nil)
        case .money:
            add("income", "arrow.down.circle", "Revenu mensuel", money(profile.monthlyIncome))
            add("budget", "creditcard", "Budget", profile.knows(.monthlyBudget) ? TF.money(budget.monthlyBudget, currency) : nil)
            add("savings", "banknote", "Épargne visée", money(profile.monthlySavingsGoal))
            add("expenses", "cart", "Dépenses", profile.mainExpenses.isEmpty ? nil : profile.mainExpenses.prefix(2).joined(separator: ", "))
        case .business:
            add("name", "briefcase", "Activité", profile.knows(.businessName) ? business.name : nil)
            add("goal", "target", "Objectif", profile.knows(.businessGoal) ? "\(TF.money(business.monthlyGoal, currency)) / mois" : nil)
            add("clients", "person.2", "Clients", profile.businessClients.map { Fmt.number($0) })
            add("revenue", "chart.line.uptrend.xyaxis", "Ce mois-ci", business.sales.isEmpty ? nil : TF.money(BusinessMath.revenue(business, .month, at: Date()), currency))
        case .productivity:
            add("goal", "target", "Objectif", profile.mainGoal.trimmed.nonEmpty)
            let open = content.tasks.filter { !$0.isDone }.count
            add("tasks", "checklist", "Tâches du jour", content.tasks.isEmpty ? nil : Fmt.number(open))
            add("work", "clock", "Travail", profile.dailyWorkHours.map { "\(ProfileNumberField.format($0)) h par jour" })
            add("focus", "brain.head.profile", "Concentration", profile.knows(.focusGoal) ? "\(Fmt.hours(productivity.weeklyFocusGoalHours)) / sem." : nil)
        case .studies:
            add("field", "graduationcap", "Études", profile.studyField.trimmed.nonEmpty)
            add("hours", "clock", "Étude perso", profile.weeklyStudyHours.map { "\(ProfileNumberField.format($0)) h / sem." })
            add("courses", "book", "Cours", student.courses.isEmpty ? nil : Fmt.number(student.courses.count))
        case .car:
            add("name", "car", "Voiture", profile.knows(.carName) ? car.name : nil)
            add("km", "gauge.with.dots.needle.33percent", "Compteur", CarMath.odometer(car).map { "\(TF.int($0)) km" })
        case .weather:
            add("city", "location", "Ville", settings.weatherLocation?.name)
        case .wellbeing:
            add("water", "drop.fill", "Eau", profile.knows(.hydrationGoal) ? "\(content.hydration.goal) verres / jour" : nil)
            add("habits", "repeat", "Habitudes", content.habits.isEmpty ? nil : Fmt.number(content.habits.count))
        }
        return facts
    }

    /// How many of a topic's main questions are still unanswered.
    func missingCount(for topic: ProfileTopic) -> Int {
        let answered: [Bool]
        switch topic {
        case .sport:
            answered = [profile.fitnessGoal != nil, profile.weightKg != nil, profile.heightCm != nil, age != nil, profile.knows(.weeklyWorkouts)]
        case .nutrition:
            answered = [profile.knows(.kcalTarget), profile.knows(.proteinTarget), profile.knows(.carbsTarget), profile.knows(.fatTarget)]
        case .money:
            answered = [profile.monthlyIncome != nil, profile.knows(.monthlyBudget), profile.monthlySavingsGoal != nil]
        case .business:
            answered = [profile.knows(.businessName), profile.knows(.businessGoal)]
        case .productivity:
            answered = [!profile.mainGoal.trimmed.isEmpty, profile.dailyWorkHours != nil, profile.knows(.focusGoal)]
        case .studies:
            answered = [!profile.studyField.trimmed.isEmpty, profile.weeklyStudyHours != nil]
        case .car:
            answered = [profile.knows(.carName), CarMath.odometer(car) != nil]
        case .weather:
            answered = [settings.weatherLocation != nil]
        case .wellbeing:
            answered = [profile.knows(.hydrationGoal)]
        }
        return answered.filter { !$0 }.count
    }

    /// The topics « Mes informations » shows: the user's interests first, then any topic they gave values for.
    var infoTopics: [ProfileTopic] {
        let chosen = profile.topics
        let others = ProfileTopic.allCases.filter { !chosen.contains($0) && !facts(for: $0).isEmpty && $0 != .weather }
        return chosen + others
    }

    static func heightText(_ centimetres: Double) -> String {
        let metres = centimetres / 100
        return String(format: "%.2f m", metres).replacingOccurrences(of: ".", with: ",")
    }
}
