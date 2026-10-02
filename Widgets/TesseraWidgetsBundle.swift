import SwiftUI
import WidgetKit

// WidgetBundleBuilder accepts a limited number of widgets per block,
// so the widgets are grouped by category and composed here.

@main
struct TesseraWidgetsBundle: WidgetBundle {
    init() {
        WidgetLog.logger.log("extension launched")
        // Lets the app's Réglages > Développeur show that iOS really runs the widgets.
        WidgetDiagnostics.recordLaunch()
    }

    var body: some Widget {
        QuickWidget()
        TimeWidgets().body
        CalendarWidgets().body
        ProductivityWidgets().body
        DataWidgets().body
        LifeGroups().body
        DomainGroups().body
        MoreGroups().body
        WorkoutLiveActivityWidget()
    }
}

struct TimeWidgets: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        WorldClockWidget()
        ProgressWidget()
    }
}

struct CalendarWidgets: WidgetBundle {
    var body: some Widget {
        CalendarWidget()
        CountdownWidget()
        YearDotsWidget()
    }
}

struct ProductivityWidgets: WidgetBundle {
    var body: some Widget {
        TasksWidget()
        HabitsWidget()
        FocusWidget()
        UpNextWidget()
        NoteWidget()
    }
}

struct DataWidgets: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
        CryptoWidget()
        MoneyFlowWidget()
        HydrationWidget()
    }
}

struct LifeGroups: WidgetBundle {
    var body: some Widget {
        DashboardsGroupWidget()
        DatesGroupWidget()
        SkyGroupWidget()
        FocusGroupWidget()
        HabitsGroupWidget()
    }
}

struct DomainGroups: WidgetBundle {
    var body: some Widget {
        NutritionGroupWidget()
        FitnessGroupWidget()
        BudgetGroupWidget()
        InvestingGroupWidget()
        BusinessGroupWidget()
    }
}

struct MoreGroups: WidgetBundle {
    var body: some Widget {
        StudentGroupWidget()
        TravelGroupWidget()
        CarGroupWidget()
        CompaniesGroupWidget()
        InsightsGroupWidget()
    }
}
