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

/// Lock Screen sizes only: the Home Screen gallery shows « Mes widgets » alone (the person's own widgets).
private func lockScreenFamilies(_ families: [WidgetFamily]) -> [WidgetFamily] {
    families.filter { $0 == .accessoryCircular || $0 == .accessoryRectangular || $0 == .accessoryInline }
}

/// One of the essentials of a mini-app on the Lock Screen. The identifiers are those of the widgets of
/// earlier versions, so the ones already on the Lock Screen stay.
private func lockConfiguration(_ kind: WidgetKind) -> some WidgetConfiguration {
    AppIntentConfiguration(kind: kind.widgetKindID, intent: DesignWidgetIntent.self, provider: DesignProvider(kind: kind)) { entry in
        DesignWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(kind.title)
    .description(kind.summary)
    .supportedFamilies(lockScreenFamilies(kind.families))
    .contentMarginsDisabled()
}

private func lockConfiguration(_ group: WidgetGroup, title: String) -> some WidgetConfiguration {
    AppIntentConfiguration(kind: group.kindID, intent: DesignWidgetIntent.self, provider: DesignProvider(kind: group.flagship, group: group)) { entry in
        DesignWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(title)
    .description(group.summary)
    .supportedFamilies(lockScreenFamilies(group.families))
    .contentMarginsDisabled()
}

// MARK: - The essentials of each mini-app, on the Lock Screen

struct NutritionLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.nutrition, title: tr("Nutrition")) }
}

struct FitnessLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.fitness, title: tr("Fitness")) }
}

struct PlanningLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.student, title: tr("Planning")) }
}

struct TasksLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.tasks) }
}

struct UpNextLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.upNext) }
}

struct HabitsLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.habitsPlus, title: tr("Habitudes")) }
}

struct FinancesLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.budget, title: tr("Finances")) }
}

struct BusinessLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.business, title: tr("Business")) }
}

struct TravelLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.travel, title: tr("Voyage")) }
}

struct CarLockWidget: Widget {
    var body: some WidgetConfiguration { lockConfiguration(.car, title: tr("Auto")) }
}
