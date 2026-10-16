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
    /// The Lock Screen offers the essentials of each mini-app, with the food scanner after Nutrition.
    /// Then the workout and the study timer in progress, and the scanner among the controls (iOS 18).
    var body: some Widget {
        QuickWidget()
        LockScreenEssentials().body
        LockScreenMore().body
        WorkoutLiveActivityWidget()
        StudyLiveActivityWidget()
        if #available(iOS 18.0, *) {
            ScanFoodControl()
        }
    }
}

struct LockScreenEssentials: WidgetBundle {
    var body: some Widget {
        NutritionLockWidget()
        ScanFoodLockWidget()
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
