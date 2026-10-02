import SwiftUI
import WidgetKit

/// Lock Screen widgets. The system tints these, so they ignore the design's colors
/// and rely on hierarchy and `widgetAccentable()` instead.
struct AccessoryWidgetView: View {
    let context: RenderContext

    var body: some View {
        switch context.design.kind {
        case .progress: progress
        case .countdown: countdown
        case .weather: weather
        case .tasks: tasks
        case .focus: focus
        case .hydration: hydration
        case .upNext: upNext
        case .crypto: crypto
        case .clock, .calendar, .worldClock, .yearDots, .habits, .note, .moneyFlow: fallback
        default: TileAccessoryView(tile: TileFactory.make(context), family: family, isLive: context.isInteractive, now: context.date)
        }
    }

    private var family: WidgetFamily { context.family }

    // MARK: Progress

    @ViewBuilder private var progress: some View {
        let unit = context.options.progressUnit
        let value = DateMath.progress(of: unit, at: context.date)
        switch family {
        case .accessoryCircular:
            Gauge(value: value) {
                Text(shortTitle(unit))
            } currentValueLabel: {
                Text("\(Int((value * 100).rounded()))")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(ProgressText.title(unit, at: context.date))
                    .font(.headline)
                    .widgetAccentable()
                ProgressView(value: value)
                Text("\(Fmt.percent(value)) · \(ProgressText.remaining(unit, at: context.date))")
                    .font(.caption)
                    .lineLimit(1)
            }
        default:
            Text("\(ProgressText.title(unit, at: context.date)) · \(Fmt.percent(value))")
        }
    }

    private func shortTitle(_ unit: ProgressUnit) -> String {
        switch unit {
        case .day: tr("JOUR")
        case .week: "SEM."
        case .month: tr("MOIS")
        case .year: tr("AN")
        }
    }

    // MARK: Countdown

    @ViewBuilder private var countdown: some View {
        let options = context.options
        let info = CountdownInfo(options: options, now: context.date)
        let title = options.countdownTitle.trimmed.isEmpty ? tr("Événement") : options.countdownTitle
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -2) {
                    if info.isToday {
                        Image(systemName: "sparkles").font(.title3)
                    } else {
                        Text(Fmt.number(info.days))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.6)
                        Text(info.days > 1 ? tr("jours") : tr("jour"))
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .widgetAccentable()
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                Text(info.isToday ? tr("C'est aujourd'hui") : "\(Fmt.number(info.days)) \(info.caption)")
                    .font(.body)
                Text(Fmt.shortDay(options.countdownDate))
                    .font(.caption)
            }
        default:
            Text(info.isToday ? tr("\(title) · aujourd'hui") : "\(title) · \(Fmt.number(info.days)) j")
        }
    }

    // MARK: Weather

    @ViewBuilder private var weather: some View {
        switch context.payload.weather {
        case let .ready(w): weatherContent(w)
        case let .unavailable(.some(w)): weatherContent(w)
        default: Label(tr("Météo"), systemImage: "location.slash")
        }
    }

    @ViewBuilder private func weatherContent(_ w: WeatherSnapshot) -> some View {
        let unit = context.settings.temperatureUnit
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: WeatherCode.symbol(w.code, isDay: w.isDay))
                        .font(.system(size: 16))
                    Text(Fmt.temperature(w.temperature, unit: unit))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .widgetAccentable()
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(w.locationName)
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                Label(Fmt.temperature(w.temperature, unit: unit) + " " + WeatherCode.description(w.code), systemImage: WeatherCode.symbol(w.code, isDay: w.isDay))
                    .lineLimit(1)
                Text("↑\(Fmt.temperature(w.high, unit: unit)) ↓\(Fmt.temperature(w.low, unit: unit))")
                    .font(.caption)
            }
        default:
            Label(Fmt.temperature(w.temperature, unit: unit) + " " + WeatherCode.description(w.code), systemImage: WeatherCode.symbol(w.code, isDay: w.isDay))
        }
    }

    // MARK: Tasks

    private var tasks: some View {
        let open = context.payload.content.tasks.filter { !$0.isDone }
        return VStack(alignment: .leading, spacing: 1) {
            Text(open.isEmpty ? tr("Tout est fait") : tr("\(open.count) à faire"))
                .font(.headline)
                .widgetAccentable()
            ForEach(open.prefix(2)) { task in
                Text("• \(task.title)")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Focus

    @ViewBuilder private var focus: some View {
        let session = context.payload.content.focus
        if session.isRunning(at: context.date), let end = session.endDate {
            let start = session.startDate ?? end.addingTimeInterval(-Double(session.lastDurationMinutes) * 60)
            let range = start...max(end, start.addingTimeInterval(1))
            if family == .accessoryCircular {
                TimerRing(range: range, symbol: "timer", isLive: context.isInteractive, now: context.date)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Focus")).font(.headline).widgetAccentable()
                    Text(timerInterval: range, countsDown: true)
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                    ProgressView(timerInterval: range, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                }
            }
        } else if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "timer").font(.title2).widgetAccentable()
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("Focus")).font(.headline).widgetAccentable()
                Text(tr("Lance une session depuis l'écran d'accueil"))
                    .font(.caption)
                    .lineLimit(2)
            }
        }
    }

    // MARK: Hydration

    private var hydration: some View {
        let state = context.payload.content.hydration
        let count = state.glasses(on: context.date)
        let goal = max(1, state.goal)
        return Gauge(value: min(Double(count), Double(goal)), in: 0...Double(goal)) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text("\(count)")
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }

    // MARK: Up next

    @ViewBuilder private var upNext: some View {
        switch context.payload.events {
        case let .ready(events):
            if let event = events.first {
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)
                        .widgetAccentable()
                    Text(event.isAllDay ? tr("Toute la journée") : Fmt.time(event.start, uses24Hour: context.settings.uses24HourClock))
                    if !event.isAllDay, event.start > context.date {
                        Text(event.start, style: .relative).font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading) {
                    Text(tr("À venir")).font(.headline).widgetAccentable()
                    Text(tr("Rien de prévu")).font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .needsAccess:
            Label(tr("Calendrier"), systemImage: "calendar.badge.exclamationmark")
        }
    }

    // MARK: Crypto

    @ViewBuilder private var crypto: some View {
        switch context.payload.crypto {
        case let .ready(coin): cryptoContent(coin)
        case let .unavailable(.some(coin)): cryptoContent(coin)
        case .unavailable(.none): Label(tr("Crypto"), systemImage: "wifi.slash")
        }
    }

    private func cryptoContent(_ coin: CoinSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(coin.symbol).font(.headline).widgetAccentable()
            Text(Fmt.price(coin.price, currency: coin.currency))
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.6)
            Text(Fmt.signedPercent(coin.change24h) + tr(" sur 24 h")).font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Fallback

    @ViewBuilder private var fallback: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: context.design.kind.symbol).font(.title3).widgetAccentable()
            }
        } else {
            Label(context.design.name, systemImage: context.design.kind.symbol)
        }
    }
}
