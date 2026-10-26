import Foundation
import WidgetKit

/// Families of widgets, used by the Store, the gallery and the Spaces.
enum WidgetCategory: String, CaseIterable, Codable, Identifiable {
    case dashboards
    case time
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
    case memories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboards: tr("Tableaux de bord")
        case .time: tr("Temps")
        case .productivity: tr("Productivité")
        case .wellbeing: tr("Habitudes")
        case .nutrition: tr("Nutrition")
        case .fitness: tr("Fitness")
        case .finance: tr("Budget")
        case .investing: tr("Placements")
        case .business: tr("Mon entreprise")
        case .markets: tr("Sociétés cotées")
        case .student: tr("Planning · études")
        case .travel: tr("Voyage")
        case .car: tr("Auto")
        case .memories: tr("Photos et citations")
        }
    }

    var symbol: String {
        switch self {
        case .dashboards: "rectangle.3.group"
        case .time: "clock"
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
        case .memories: "photo.on.rectangle.angled"
        }
    }

    var colorHex: String {
        switch self {
        case .dashboards: "5B6CFF"
        case .time: "2F8F7A"
        case .productivity: "6B7280"
        case .wellbeing: "7FA33A"
        case .nutrition: "F08A24"
        case .fitness: "E5484D"
        case .finance: "2F8F7A"
        case .investing: "8C6CFF"
        case .business: "C28A12"
        case .markets: "3366FF"
        case .student: "D6409F"
        case .travel: "12A4B5"
        case .car: "4B5563"
        case .memories: "D9608B"
        }
    }
}

/// Every widget type the app can render. The raw value is persisted: never rename one.
enum WidgetKind: String, CaseIterable, Codable, Identifiable {
    // Temps
    case clock, calendar, worldClock, progress, countdown, yearDots
    case ageProgress, birthday, weekView, holiday, moonPhase
    // Productivité
    case tasks, habits, focus, upNext, note
    case priorities, project, deadline, deepWork, counter
    // Habitudes et bien-être
    case hydration, habitStreak, habitWeek, habitRate
    // Nutrition
    case caloriesLeft, macros, proteinLeft, mealsToday, nutritionWeek, nutritionStreak, quickFood, nextMeal
    // Fitness
    case todaysWorkout, nextSet, restTimer, weeklyVolume, personalRecords, trainingStreak, caloriesBurned, workoutMonth
    // Budget
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
    case tripCountdown, flight, hotel, localTime, currency, tripProgress, nextActivity
    // Auto
    case carCost, nextService, mileage, fuelStats, carDeadlines
    // Tableaux de bord
    case myDay, now, morning, fitnessDashboard, moneyDashboard, studentDashboard
    case aiSummary, aiNutrition, aiFinance, aiProductivity
    // Photos et citations
    case photos, quote

    var id: String { rawValue }

    /// The identifier registered with WidgetKit for the 15 original widgets.
    var widgetKindID: String { "tessera.\(rawValue)" }

    var info: KindInfo { KindCatalog.info(self) }
    var title: String { info.title }
    var summary: String { info.summary }
    var category: WidgetCategory { info.category }
    var symbol: String { info.symbol }
    var isPremium: Bool { info.isPremium }
    var isNew: Bool { info.isNew }
    /// Whether the widget does something without opening the app (a button, a toggle) or right into
    /// an action (the Nutrition scanner). Shown with a badge in the creation screens.
    var isInteractive: Bool { info.isInteractive || NutritionTiles.scanKinds.contains(self) }
    var families: [WidgetFamily] { info.families }
    var keywords: [String] { info.keywords }
    /// The mini-app where the data behind this widget is entered, if any.
    var space: Space? { info.space }

    var homeFamilies: [WidgetFamily] {
        families.filter { $0 == .systemSmall || $0 == .systemMedium || $0 == .systemLarge }
    }

    var supportsLockScreen: Bool {
        families.contains { $0 == .accessoryCircular || $0 == .accessoryRectangular || $0 == .accessoryInline }
    }

    /// Widgets of features that were removed (the water mini-app): kept so saved data still reads, never
    /// offered again anywhere (catalog, Store, Créer, gallery). Saved ones are taken off at launch.
    static let retired: Set<WidgetKind> = [.hydration]

    var isRetired: Bool { Self.retired.contains(self) }

    /// Every widget that can be made today.
    static var offered: [WidgetKind] { allCases.filter { !$0.isRetired && !$0.isMadeInItsMiniApp } }

    static func kinds(in category: WidgetCategory) -> [WidgetKind] {
        offered.filter { $0.category == category }
    }

    static var freeKinds: [WidgetKind] { offered.filter { !$0.isPremium } }
}

extension WidgetFamily {
    var shortTitle: String {
        switch self {
        case .systemSmall: tr("Petit")
        case .systemMedium: tr("Moyen")
        case .systemLarge: tr("Grand")
        case .systemExtraLarge: tr("Très grand")
        case .accessoryCircular: tr("Rond")
        case .accessoryRectangular: tr("Rectangle")
        case .accessoryInline: tr("En ligne")
        @unknown default: tr("Widget")
        }
    }

    var isAccessory: Bool {
        self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline
    }
}
