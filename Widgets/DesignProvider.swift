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
/// Group widgets (V2) show the first widget of their group that fits the size, until a design is chosen.
struct DesignProvider: AppIntentTimelineProvider {
    let kind: WidgetKind
    var group: WidgetGroup? = nil

    private func defaultKind(for family: WidgetFamily) -> WidgetKind {
        group?.defaultKind(for: family) ?? kind
    }

    func placeholder(in context: Context) -> DesignEntry {
        let shown = defaultKind(for: context.family)
        let design = WidgetDesign.starter(for: shown)
        return DesignEntry(date: Date(), design: design, isSaved: false, payload: SamplePayload.make(for: shown), isPremium: true)
    }

    func snapshot(for configuration: DesignWidgetIntent, in context: Context) async -> DesignEntry {
        let now = Date()
        WidgetLog.logger.log("snapshot start \(kind.rawValue, privacy: .public) preview=\(context.isPreview)")
        defer { WidgetLog.logger.log("snapshot done \(kind.rawValue, privacy: .public) in \(Date().timeIntervalSince(now), format: .fixed(precision: 3))s") }
        let (design, isSaved) = resolveDesign(configuration, family: context.family)
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
        let (design, isSaved) = resolveDesign(configuration, family: context.family)
        let payload = await PayloadLoader.load(for: design, allowNetwork: true, now: now)
        let isPremium = SharedStore.shared.premium.isPremium(at: now)
        let plan = TimelinePlanner.plan(for: design, payload: payload, now: now)
        let entries = plan.dates.map {
            DesignEntry(date: $0, design: design, isSaved: isSaved, payload: payload, isPremium: isPremium)
        }
        return Timeline(entries: entries, policy: plan.policy)
    }

    private func resolveDesign(_ configuration: DesignWidgetIntent, family: WidgetFamily) -> (WidgetDesign, Bool) {
        if let id = configuration.design?.id {
            if let uuid = UUID(uuidString: id), let saved = SharedStore.shared.design(id: uuid) {
                return (saved, true)
            }
            if let starter = DesignEntity.starterKind(id) {
                return (WidgetDesign.starter(for: starter), false)
            }
        }
        return (WidgetDesign.starter(for: defaultKind(for: family)), false)
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
        if design.isCombo {
            // Every moment one of the widgets inside changes, and a refresh within half an hour.
            let dates = Array(Set(design.partDesigns.flatMap { plan(for: $0, payload: payload, now: now).dates })).sorted().prefix(60)
            return Plan(dates: dates.isEmpty ? [now] : Array(dates), policy: .after(min(now.addingTimeInterval(30 * 60), midnight.addingTimeInterval(60))))
        }
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
        default:
            return planMiniApp(design: design, payload: payload, now: now, midnight: midnight)
        }
    }

    /// Mini-app widgets: redraw at the moments their content changes, and at least every half hour.
    private static func planMiniApp(design: WidgetDesign, payload: WidgetPayload, now: Date, midnight: Date) -> Plan {
        let halfHour = now.addingTimeInterval(30 * 60)
        func every(_ minutes: Int, count: Int) -> [Date] {
            (0..<count).compactMap { DateMath.calendar.date(byAdding: .minute, value: $0 * minutes, to: now) }
        }
        switch design.kind {
        case .localTime:
            let start = DateMath.calendar.dateInterval(of: .minute, for: now)?.start ?? now
            let dates = (0..<60).compactMap { DateMath.calendar.date(byAdding: .minute, value: $0, to: start) }
            return Plan(dates: dates, policy: .atEnd)
        case .restTimer, .nextSet, .todaysWorkout, .fitnessDashboard:
            var dates = [now]
            if let rest = payload.domains.fitness.active?.restEndsAt, rest > now { dates.append(rest) }
            return Plan(dates: dates, policy: .after(min(halfHour, midnight)))
        case .deadline, .nextClass, .timetable, .studentDashboard, .flight, .nextActivity, .now, .myDay, .morning, .sunCycle:
            return Plan(dates: every(15, count: 4), policy: .after(now.addingTimeInterval(60 * 60)))
        case .rainNext, .windUV, .weatherDetails, .weeklyForecast, .destinationWeather:
            return Plan(dates: [now], policy: .after(now.addingTimeInterval(WeatherService.refreshInterval)))
        case .portfolio, .allocation, .topMover, .watchlist, .marketOverview:
            return Plan(dates: [now], policy: .after(now.addingTimeInterval(MarketService.refreshInterval)))
        case .companySnapshot, .companyRevenue, .companyStock, .companyCompare:
            return Plan(dates: [now], policy: .after(now.addingTimeInterval(3 * 3600)))
        case .currency:
            return Plan(dates: [now], policy: .after(now.addingTimeInterval(FXService.refreshInterval)))
        case .ageProgress, .birthday, .weekView, .holiday, .moonPhase, .semesterProgress, .tripCountdown, .tripProgress, .carDeadlines:
            return Plan(dates: [now, midnight], policy: .after(midnight.addingTimeInterval(60)))
        default:
            return Plan(dates: [now, midnight].filter { $0 < halfHour || $0 == now }, policy: .after(min(halfHour, midnight.addingTimeInterval(60))))
        }
    }
}
