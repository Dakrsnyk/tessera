import SwiftUI
import WidgetKit

struct DesignEntry: TimelineEntry {
    let date: Date
    let design: WidgetDesign
    let isSaved: Bool
    let payload: WidgetPayload
    let isPremium: Bool
}

/// One provider type serves every widget kind; the kind decides the default design and refresh rhythm.
struct DesignProvider: AppIntentTimelineProvider {
    let kind: WidgetKind

    func placeholder(in context: Context) -> DesignEntry {
        let design = WidgetDesign.starter(for: kind)
        return DesignEntry(date: Date(), design: design, isSaved: false, payload: SamplePayload.make(for: kind), isPremium: true)
    }

    func snapshot(for configuration: DesignWidgetIntent, in context: Context) async -> DesignEntry {
        let now = Date()
        WidgetLog.logger.log("snapshot start \(kind.rawValue, privacy: .public) preview=\(context.isPreview)")
        defer { WidgetLog.logger.log("snapshot done \(kind.rawValue, privacy: .public) in \(Date().timeIntervalSince(now), format: .fixed(precision: 3))s") }
        let (design, isSaved) = resolveDesign(configuration)
        if context.isPreview && !isSaved {
            // The widget gallery shows each kind at its best, with example content.
            return DesignEntry(date: now, design: design, isSaved: false, payload: SamplePayload.make(for: design, now: now), isPremium: true)
        }
        let payload = await PayloadLoader.load(for: design, allowNetwork: true, now: now)
        return DesignEntry(date: now, design: design, isSaved: isSaved, payload: payload, isPremium: SharedStore.shared.premium.isPremium(at: now))
    }

    func timeline(for configuration: DesignWidgetIntent, in context: Context) async -> Timeline<DesignEntry> {
        let now = Date()
        WidgetLog.logger.log("timeline start \(kind.rawValue, privacy: .public) family=\(String(describing: context.family), privacy: .public)")
        defer { WidgetLog.logger.log("timeline done \(kind.rawValue, privacy: .public) in \(Date().timeIntervalSince(now), format: .fixed(precision: 3))s") }
        let (design, isSaved) = resolveDesign(configuration)
        let payload = await PayloadLoader.load(for: design, allowNetwork: true, now: now)
        let isPremium = SharedStore.shared.premium.isPremium(at: now)
        let plan = TimelinePlanner.plan(for: design, payload: payload, now: now)
        let entries = plan.dates.map {
            DesignEntry(date: $0, design: design, isSaved: isSaved, payload: payload, isPremium: isPremium)
        }
        return Timeline(entries: entries, policy: plan.policy)
    }

    private func resolveDesign(_ configuration: DesignWidgetIntent) -> (WidgetDesign, Bool) {
        if let id = configuration.design?.id, let uuid = UUID(uuidString: id), let saved = SharedStore.shared.design(id: uuid) {
            return (saved, true)
        }
        return (WidgetDesign.starter(for: kind), false)
    }
}

/// Decides when each widget needs a new frame. Widgets that only change at midnight get
/// one entry; clocks get one per minute; network-backed widgets refresh on their cache interval.
enum TimelinePlanner {
    struct Plan {
        let dates: [Date]
        let policy: TimelineReloadPolicy
    }

    static func plan(for design: WidgetDesign, payload: WidgetPayload, now: Date) -> Plan {
        let midnight = DateMath.nextMidnight(after: now)
        switch design.kind {
        case .clock, .worldClock:
            let start = DateMath.calendar.dateInterval(of: .minute, for: now)?.start ?? now
            let dates = (0..<60).compactMap { DateMath.calendar.date(byAdding: .minute, value: $0, to: start) }
            return Plan(dates: dates, policy: .atEnd)
        case .progress:
            let step: Int = design.options.progressUnit == .day ? 5 : 60
            let dates = (0..<24).compactMap { DateMath.calendar.date(byAdding: .minute, value: $0 * step, to: now) }
            return Plan(dates: dates, policy: .atEnd)
        case .moneyFlow:
            let dates = (0..<16).compactMap { DateMath.calendar.date(byAdding: .minute, value: $0 * 15, to: now) }
            return Plan(dates: dates, policy: .atEnd)
        case .focus:
            if let end = payload.content.focus.endDate, end > now {
                return Plan(dates: [now, end], policy: .after(end.addingTimeInterval(60 * 60)))
            }
            return Plan(dates: [now], policy: .after(midnight))
        case .upNext:
            var dates = [now]
            if case let .ready(events) = payload.events {
                for event in events.prefix(6) {
                    if event.start > now { dates.append(event.start) }
                    if event.end > now { dates.append(event.end) }
                }
            }
            let unique = Array(Set(dates)).sorted().filter { $0 < midnight.addingTimeInterval(86_400) }
            return Plan(dates: unique, policy: .after(min(midnight, now.addingTimeInterval(60 * 60))))
        case .weather:
            return Plan(dates: [now], policy: .after(now.addingTimeInterval(WeatherService.refreshInterval)))
        case .crypto:
            return Plan(dates: [now], policy: .after(now.addingTimeInterval(CryptoService.refreshInterval)))
        case .tasks, .habits, .hydration:
            return Plan(dates: [now, midnight], policy: .after(midnight.addingTimeInterval(60)))
        case .calendar, .countdown, .yearDots, .note:
            return Plan(dates: [now, midnight], policy: .after(midnight.addingTimeInterval(60)))
        }
    }
}
