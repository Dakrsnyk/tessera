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

    /// The Home Screen gallery offers « Mes widgets » only: the person's own widgets, made in Ardane.
    /// The Lock Screen offers the essentials of each mini-app. Then the workout in progress.
    var body: some Widget {
        QuickWidget()
        LockScreenEssentials().body
        LockScreenMore().body
        WorkoutLiveActivityWidget()
    }
}

struct LockScreenEssentials: WidgetBundle {
    var body: some Widget {
        NutritionLockWidget()
        FitnessLockWidget()
        PlanningLockWidget()
        TasksLockWidget()
        UpNextLockWidget()
    }
}

struct LockScreenMore: WidgetBundle {
    var body: some Widget {
        HabitsLockWidget()
        FinancesLockWidget()
        BusinessLockWidget()
        TravelLockWidget()
        CarLockWidget()
        WeatherLockWidget()
    }
}
