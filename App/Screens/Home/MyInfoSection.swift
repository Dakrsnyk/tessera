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
        // The goal is one answer for Sport and Nutrition: one line, on the first of the two pages the person has.
        func showsGoal(on topic: ProfileTopic) -> Bool {
            let order = profile.topics
            let other: ProfileTopic = topic == .sport ? .nutrition : .sport
            guard let mine = order.firstIndex(of: topic), let theirs = order.firstIndex(of: other) else { return true }
            return mine < theirs
        }
        // The body (weight, height, age, activity) is one answer too: under Sport, and under Nutrition only when
        // the person does not follow Sport (the calculation of Nutrition uses it all the same).
        func addBody() {
            add("weight", "scalemass", tr("Poids"), profile.weightKg.map { Units.weightText(kilograms: $0, in: settings.unitSystem) })
            add("height", "ruler", tr("Taille", context: "height"), profile.heightCm.map { Units.heightText(centimetres: $0, in: settings.unitSystem) })
            add("age", "person", tr("Âge"), age.map { tr("\($0) ans") })
        }
        switch topic {
        case .sport:
            if showsGoal(on: .sport) { add("goal", "target", tr("Objectif"), profile.goal?.title) }
            addBody()
            add("workouts", "calendar", tr("Séances"), profile.knows(.weeklyWorkouts) ? tr("\(fitness.weeklyGoal) par semaine") : nil)
            add("level", "chart.bar.fill", tr("Niveau"), profile.fitnessLevel?.title)
        case .nutrition:
            if showsGoal(on: .nutrition) { add("goal", "target", tr("Objectif"), profile.goal?.title) }
            if !profile.topics.contains(.sport) {
                addBody()
                add("activity", "figure.walk", tr("Activité"), profile.calculatedActivity?.title ?? activityFromWorkouts?.title)
            }
            add("kcal", "flame", tr("Calories"), profile.knows(.kcalTarget) ? tr("\(TF.int(nutrition.goals.kcal)) kcal") : nil)
            add("protein", "bolt.heart", tr("Protéines"), profile.knows(.proteinTarget) ? "\(TF.int(nutrition.goals.protein)) g" : nil)
            add("carbs", "leaf", tr("Glucides"), profile.knows(.carbsTarget) ? "\(TF.int(nutrition.goals.carbs)) g" : nil)
            add("fat", "drop", tr("Lipides"), profile.knows(.fatTarget) ? "\(TF.int(nutrition.goals.fat)) g" : nil)
        case .money:
            add("income", "arrow.down.circle", tr("Revenu mensuel"), money(profile.monthlyIncome))
            add("budget", "creditcard", tr("Budget"), profile.knows(.monthlyBudget) ? TF.money(budget.monthlyBudget, currency) : nil)
            add("savings", "banknote", tr("Épargne visée"), money(profile.monthlySavingsGoal))
            add("expenses", "cart", tr("Dépenses"), profile.mainExpenses.isEmpty ? nil : profile.mainExpenses.prefix(2).joined(separator: ", "))
        case .business:
            add("name", "briefcase", tr("Activité"), profile.knows(.businessName) ? business.name : nil)
            add("goal", "target", tr("Objectif"), profile.knows(.businessGoal) ? tr("\(TF.money(business.monthlyGoal, currency)) / mois") : nil)
            add("clients", "person.2", tr("Clients"), profile.businessClients.map { Fmt.number($0) })
            add("revenue", "chart.line.uptrend.xyaxis", tr("Ce mois-ci"), business.sales.isEmpty ? nil : TF.money(BusinessMath.revenue(business, .month, at: Date()), currency))
        case .productivity:
            add("goal", "target", tr("Objectif"), profile.mainGoal.trimmed.nonEmpty)
            let open = content.tasks.filter { !$0.isDone }.count
            add("tasks", "checklist", tr("Tâches du jour"), content.tasks.isEmpty ? nil : Fmt.number(open))
            add("work", "clock", tr("Travail"), profile.dailyWorkHours.map { tr("\(ProfileNumberField.format($0)) h par jour") })
        case .studies:
            add("field", "graduationcap", tr("Études"), profile.studyField.trimmed.nonEmpty)
            add("hours", "clock", tr("Étude perso"), profile.knows(.studyGoal) ? tr("\(ProfileNumberField.format(student.weeklyStudyGoalHours)) h / sem.") : nil)
            add("focus", "brain.head.profile", tr("Concentration"), profile.knows(.focusGoal) ? tr("\(Fmt.hours(productivity.weeklyFocusGoalHours)) / sem.") : nil)
            add("courses", "book", tr("Cours"), student.courses.isEmpty ? nil : Fmt.number(student.courses.count))
        case .car:
            add("name", "car", tr("Voiture"), profile.knows(.carName) ? car.name : nil)
            add("km", "gauge.with.dots.needle.33percent", tr("Compteur"), CarMath.odometer(car).map { tr("\(TF.int($0)) km") })
        case .wellbeing:
            add("habits", "repeat", tr("Habitudes"), content.habits.isEmpty ? nil : Fmt.number(content.habits.count))
        }
        return facts
    }
}
