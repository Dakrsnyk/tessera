import Foundation
import WidgetKit

/// How the V2 widgets appear in the iOS widget gallery: one entry per theme instead of one per kind,
/// so the gallery stays readable. Each entry shows its flagship widget and can display any design
/// chosen with « Modifier le widget ». The 15 original widgets keep their own entries and identifiers.
enum WidgetGroup: String, CaseIterable, Identifiable {
    case dates, sky, focus, habitsPlus, nutrition, fitness, budget, investing, business, companies, student, travel, car, dashboards, insights

    var id: String { rawValue }

    /// Identifier registered with WidgetKit. Never change it: placed widgets would disappear.
    var kindID: String { "tessera.group.\(rawValue)" }

    var kinds: [WidgetKind] {
        switch self {
        case .dates: [.birthday, .holiday, .moonPhase, .weekView, .ageProgress]
        case .sky: [.sunCycle, .rainNext, .windUV, .weatherDetails, .weeklyForecast]
        case .focus: [.priorities, .counter, .project, .deadline, .deepWork]
        case .habitsPlus: [.habitStreak, .habitWeek, .habitRate]
        case .nutrition: [.caloriesLeft, .macros, .proteinLeft, .mealsToday, .nutritionWeek, .nutritionStreak, .quickFood, .nextMeal]
        case .fitness: [.todaysWorkout, .trainingStreak, .nextSet, .restTimer, .weeklyVolume, .personalRecords, .caloriesBurned, .workoutMonth]
        case .budget: [.budgetLeft, .savingsGoal, .spendingByCategory, .billsUpcoming, .netWorth, .subscriptions, .quickExpense]
        case .investing: [.watchlist, .portfolio, .allocation, .topMover, .marketOverview]
        case .business: [.revenueGoal, .revenueTrend, .profit, .businessKPIs, .mrr, .revenueToday, .businessDashboard]
        case .companies: [.companySnapshot, .companyRevenue, .companyStock, .companyCompare]
        case .student: [.nextClass, .nextExam, .semesterProgress, .assignments, .gradeAverage, .flashcard, .studyHours, .timetable]
        case .travel: [.tripCountdown, .localTime, .flight, .hotel, .destinationWeather, .currency, .tripProgress, .nextActivity]
        case .car: [.nextService, .carCost, .mileage, .fuelStats, .carDeadlines]
        case .dashboards: [.now, .myDay, .morning, .fitnessDashboard, .moneyDashboard, .studentDashboard]
        case .insights: [.aiSummary, .aiNutrition, .aiFinance, .aiProductivity]
        }
    }

    var flagship: WidgetKind { kinds[0] }

    var title: String {
        switch self {
        case .dates: tr("Dates et lune")
        case .sky: tr("Météo avancée")
        case .focus: tr("Priorités et projets")
        case .habitsPlus: tr("Suivi d'habitudes")
        case .nutrition: tr("Nutrition")
        case .fitness: tr("Fitness")
        case .budget: tr("Budget")
        case .investing: tr("Placements")
        case .business: tr("Mon entreprise")
        case .companies: tr("Sociétés cotées")
        case .student: tr("Études")
        case .travel: tr("Voyage")
        case .car: tr("Auto")
        case .dashboards: tr("Tableaux de bord")
        case .insights: tr("Analyses")
        }
    }

    var summary: String {
        switch self {
        case .dates: tr("Anniversaire, jours fériés, lune et semaine.")
        case .sky: tr("Soleil, pluie, vent, UV et prévisions de la semaine.")
        case .focus: tr("Top 3, compteurs, projets, échéances et deep work.")
        case .habitsPlus: tr("Séries, semaine et taux de réussite de tes habitudes.")
        case .nutrition: tr("Calories, macros, repas et ajout rapide.")
        case .fitness: tr("Séance du jour, séries, repos, volume et records.")
        case .budget: tr("Reste du mois, factures, épargne et dépenses rapides.")
        case .investing: tr("Portefeuille, répartition et cours suivis.")
        case .business: tr("Chiffre d'affaires, objectif, bénéfice et MRR.")
        case .companies: tr("Chiffres officiels des sociétés cotées.")
        case .student: tr("Cours, examens, devoirs, moyenne et fiches.")
        case .travel: tr("Départ, vol, hôtel, météo et devise sur place.")
        case .car: tr("Entretien, coût, kilométrage et carburant.")
        case .dashboards: tr("Plusieurs espaces réunis, selon le moment de la journée.")
        case .insights: tr("Ta journée et tes tendances résumées à partir de tes données.")
        }
    }

    /// Every size offered by at least one widget of the group, in the gallery's order.
    var families: [WidgetFamily] {
        let order: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        return order.filter { family in kinds.contains { $0.families.contains(family) } }
    }

    /// The widget shown for a size when no design is chosen.
    func defaultKind(for family: WidgetFamily) -> WidgetKind {
        kinds.first { $0.families.contains(family) } ?? flagship
    }

    static func group(for kind: WidgetKind) -> WidgetGroup? {
        allCases.first { $0.kinds.contains(kind) }
    }
}
