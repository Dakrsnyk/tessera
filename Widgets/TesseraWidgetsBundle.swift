import SwiftUI
import WidgetKit

// WidgetBundleBuilder accepts a limited number of widgets per block,
// so the widgets are grouped by category and composed here.

@main
struct TesseraWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TimeWidgets().body
        CalendarWidgets().body
        ProductivityWidgets().body
        DataWidgets().body
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
