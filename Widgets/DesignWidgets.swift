import SwiftUI
import WidgetKit

struct DesignWidgetEntryView: View {
    let entry: DesignEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let _ = WidgetLog.logger.log("render \(entry.design.kind.rawValue, privacy: .public) \(String(describing: family), privacy: .public) at \(entry.date.timeIntervalSince1970, format: .fixed(precision: 0))")
        let shown = WidgetCanvas.displayedDesign(entry.design, isPremium: entry.isPremium, isPreview: false)
        WidgetCanvas(
            design: shown,
            family: family,
            date: entry.date,
            payload: entry.payload,
            isPremium: entry.isPremium,
            isInteractive: true
        )
        .widgetURL(WidgetLinks.url(for: entry.design, payload: entry.payload, isPremium: entry.isPremium, isSaved: entry.isSaved))
        .containerBackground(for: .widget) {
            if family.isAccessory {
                Color.clear
            } else {
                DesignBackground(design: shown)
            }
        }
    }
}

private func designConfiguration(_ kind: WidgetKind) -> some WidgetConfiguration {
    AppIntentConfiguration(kind: kind.widgetKindID, intent: DesignWidgetIntent.self, provider: DesignProvider(kind: kind)) { entry in
        DesignWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(kind.title)
    .description(kind.summary)
    .supportedFamilies(kind.families)
    .contentMarginsDisabled()
}

struct ClockWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.clock) }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.calendar) }
}

struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.worldClock) }
}

struct ProgressWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.progress) }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.countdown) }
}

struct YearDotsWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.yearDots) }
}

struct TasksWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.tasks) }
}

struct HabitsWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.habits) }
}

struct FocusWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.focus) }
}

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.upNext) }
}

struct NoteWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.note) }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.weather) }
}

struct CryptoWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.crypto) }
}

struct MoneyFlowWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.moneyFlow) }
}

struct HydrationWidget: Widget {
    var body: some WidgetConfiguration { designConfiguration(.hydration) }
}

// MARK: - V2 group widgets

private func groupConfiguration(_ group: WidgetGroup) -> some WidgetConfiguration {
    AppIntentConfiguration(kind: group.kindID, intent: DesignWidgetIntent.self, provider: DesignProvider(kind: group.flagship, group: group)) { entry in
        DesignWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(group.title)
    .description(group.summary)
    .supportedFamilies(group.families)
    .contentMarginsDisabled()
}

struct DatesGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.dates) }
}

struct SkyGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.sky) }
}

struct FocusGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.focus) }
}

struct HabitsGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.habitsPlus) }
}

struct NutritionGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.nutrition) }
}

struct FitnessGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.fitness) }
}

struct BudgetGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.budget) }
}

struct InvestingGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.investing) }
}

struct BusinessGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.business) }
}

struct CompaniesGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.companies) }
}

struct StudentGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.student) }
}

struct TravelGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.travel) }
}

struct CarGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.car) }
}

struct DashboardsGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.dashboards) }
}

struct InsightsGroupWidget: Widget {
    var body: some WidgetConfiguration { groupConfiguration(.insights) }
}
