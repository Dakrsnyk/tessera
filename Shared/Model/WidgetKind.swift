import Foundation
import WidgetKit

enum WidgetCategory: String, CaseIterable, Codable, Identifiable {
    case dashboards
    case time
    case weather
    case productivity
    case wellbeing
    case nutrition
    case fitness
    case finance
    case investing
    case business
    case markets
    case student
    case travel
    case car

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboards: "Tableaux de bord"
        case .time: "Temps"
        case .weather: "Météo"
        case .productivity: "Productivité"
        case .wellbeing: "Habitudes"
        case .nutrition: "Nutrition"
        case .fitness: "Fitness"
        case .finance: "Finances"
        case .investing: "Investissement"
        case .business: "Business"
        case .markets: "Entreprises"
        case .student: "Études"
        case .travel: "Voyage"
        case .car: "Auto"
        }
    }

    var symbol: String {
        switch self {
        case .dashboards: "rectangle.3.group"
        case .time: "clock"
        case .weather: "cloud.sun"
        case .productivity: "checklist"
        case .wellbeing: "leaf"
        case .nutrition: "fork.knife"
        case .fitness: "dumbbell"
        case .finance: "creditcard"
        case .investing: "chart.pie"
        case .business: "briefcase"
        case .markets: "building.columns"
        case .student: "graduationcap"
        case .travel: "airplane"
        case .car: "car"
        }
    }

    /// Accent used for the category in the app (tiles, headers).
    var colorHex: String {
        switch self {
        case .dashboards: "6B5CE7"
        case .time: "2F8F7A"
        case .weather: "3B82F6"
        case .productivity: "F2A33A"
        case .wellbeing: "7FA33A"
        case .nutrition: "F06A3C"
        case .fitness: "E0485D"
        case .finance: "1E9E75"
        case .investing: "3366FF"
        case .business: "B7791F"
        case .markets: "4B5563"
        case .student: "8C6CFF"
        case .travel: "0EA5B7"
        case .car: "64748B"
        }
    }
}

/// Every widget type the app can render. The raw value is persisted, never rename it.
enum WidgetKind: String, CaseIterable, Codable, Identifiable {
    // Temps
    case clock, calendar, worldClock, progress, countdown, yearDots
    case ageProgress, birthday, weekView, holiday, moonPhase
    // Météo
    case weather, sunCycle, rainNext, windUV, weatherDetails, weeklyForecast
    // Productivité
    case tasks, habits, focus, upNext, note
    case priorities, project, deadline, deepWork, counter
    // Habitudes et bien-être
    case hydration, habitStreak, habitWeek, habitRate
    // Nutrition
    case caloriesLeft, macros, proteinLeft, mealsToday, nutritionWeek, nutritionStreak, quickFood, nextMeal
    // Fitness
    case todaysWorkout, nextSet, restTimer, weeklyVolume, personalRecords, trainingStreak, caloriesBurned, workoutMonth
    // Finances
    case moneyFlow, budgetLeft, spendingByCategory, billsUpcoming, savingsGoal, netWorth, subscriptions, quickExpense
    // Investissement
    case crypto, portfolio, allocation, topMover, watchlist, marketOverview
    // Business
    case revenueGoal, revenueTrend, profit, businessKPIs, mrr, revenueToday, businessDashboard
    // Entreprises
    case companySnapshot, companyRevenue, companyStock, companyCompare
    // Études
    case nextClass, nextExam, assignments, gradeAverage, semesterProgress, flashcard, studyHours, timetable
    // Voyage
    case tripCountdown, flight, hotel, destinationWeather, localTime, currency, tripProgress, nextActivity
    // Auto
    case carCost, nextService, mileage, fuelStats, carDeadlines
    // Tableaux de bord et IA
    case myDay, now, morning, fitnessDashboard, moneyDashboard, studentDashboard
    case aiSummary, aiNutrition, aiFinance, aiProductivity

    var id: String { rawValue }

    private var info: KindInfo { KindCatalog.info(self) }

    /// The identifier registered with WidgetKit for the V1 widgets (kept stable).
    var widgetKindID: String { "tessera.\(rawValue)" }

    var title: String { info.title }
    var summary: String { info.summary }
    var category: WidgetCategory { info.category }
    var symbol: String { info.symbol }
    var isPremium: Bool { info.isPremium }
    var isNew: Bool { info.isNew }
    var isInteractive: Bool { info.isInteractive }
    var families: [WidgetFamily] { info.families }
    var keywords: [String] { info.keywords }
    /// The mini-app where the data shown by this widget is entered.
    var space: Space? { info.space }

    var homeFamilies: [WidgetFamily] {
        families.filter { $0 == .systemSmall || $0 == .systemMedium || $0 == .systemLarge }
    }

    var supportsLockScreen: Bool {
        families.contains { $0.isAccessory }
    }

    static func kinds(in category: WidgetCategory) -> [WidgetKind] {
        allCases.filter { $0.category == category }
    }

    static var freeKinds: [WidgetKind] { allCases.filter { !$0.isPremium } }
    static var premiumKinds: [WidgetKind] { allCases.filter(\.isPremium) }
}

extension WidgetFamily {
    var shortTitle: String {
        switch self {
        case .systemSmall: "Petit"
        case .systemMedium: "Moyen"
        case .systemLarge: "Grand"
        case .systemExtraLarge: "Très grand"
        case .accessoryCircular: "Rond"
        case .accessoryRectangular: "Rectangle"
        case .accessoryInline: "En ligne"
        @unknown default: "Widget"
        }
    }

    var isAccessory: Bool {
        self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline
    }
}

/// The mini-apps inside Tessera. Each one owns data that feeds its widgets.
enum Space: String, CaseIterable, Identifiable, Codable {
    case today, nutrition, fitness, habits, budget, investing, business, markets, projects, student, travel, car, life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Aujourd'hui"
        case .nutrition: "Nutrition"
        case .fitness: "Fitness"
        case .habits: "Habitudes"
        case .budget: "Budget"
        case .investing: "Portefeuille"
        case .business: "Business"
        case .markets: "Entreprises"
        case .projects: "Projets"
        case .student: "Études"
        case .travel: "Voyage"
        case .car: "Auto"
        case .life: "Mon année"
        }
    }

    var subtitle: String {
        switch self {
        case .today: "Tâches, priorités, eau, compteurs"
        case .nutrition: "Repas, calories et macros"
        case .fitness: "Séances, séries et records"
        case .habits: "Routines et séries"
        case .budget: "Dépenses, factures, épargne"
        case .investing: "Actions, ETF, crypto, cash"
        case .business: "Ventes, marge, MRR"
        case .markets: "Chiffres officiels des sociétés"
        case .projects: "Projets, échéances, deep work"
        case .student: "Cours, examens, notes, flashcards"
        case .travel: "Vols, hôtels, activités"
        case .car: "Pleins, entretien, coût réel"
        case .life: "Anniversaire, jours fériés"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .nutrition: "fork.knife"
        case .fitness: "dumbbell"
        case .habits: "repeat"
        case .budget: "creditcard"
        case .investing: "chart.pie"
        case .business: "briefcase"
        case .markets: "building.columns"
        case .projects: "folder"
        case .student: "graduationcap"
        case .travel: "airplane"
        case .car: "car"
        case .life: "calendar.circle"
        }
    }

    var colorHex: String {
        switch self {
        case .today: "2F8F7A"
        case .nutrition: "F06A3C"
        case .fitness: "E0485D"
        case .habits: "7FA33A"
        case .budget: "1E9E75"
        case .investing: "3366FF"
        case .business: "B7791F"
        case .markets: "4B5563"
        case .projects: "F2A33A"
        case .student: "8C6CFF"
        case .travel: "0EA5B7"
        case .car: "64748B"
        case .life: "6B5CE7"
        }
    }
}
