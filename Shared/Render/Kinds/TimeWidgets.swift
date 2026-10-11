import SwiftUI
import WidgetKit

// MARK: - Clock

struct ClockWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let date = context.date
        let uses24 = context.settings.uses24HourClock
        let time = Fmt.time(date, uses24Hour: uses24)
        let dayProgress = DateMath.progress(of: .day, at: date)

        if context.isSmall {
            VStack(alignment: s.horizontalAlignment, spacing: 2) {
                if s.showsTitle { WLabel(text: Fmt.weekday(date), style: s) }
                Spacer(minLength: 0)
                timeText(time, meridiem: uses24 ? nil : Fmt.meridiem(date), size: 46)
                if context.options.clockShowsDate {
                    Text(Fmt.format(date, template: "dMMMM"))
                        .font(s.text(14, .medium))
                        .foregroundStyle(s.secondary)
                }
                if s.showsDetails {
                    BarView(progress: dayProgress, color: s.chart, track: s.track, height: 4)
                        .padding(.top, 8)
                }
            }
            .widgetFrame(s)
        } else {
            HStack(spacing: 12) {
                VStack(alignment: s.horizontalAlignment, spacing: 2) {
                    if s.showsTitle { WLabel(text: Fmt.weekday(date), style: s) }
                    Spacer(minLength: 0)
                    timeText(time, meridiem: uses24 ? nil : Fmt.meridiem(date), size: 60)
                    if context.options.clockShowsDate {
                        Text(Fmt.format(date, template: "dMMMMyyyy"))
                            .font(s.text(15, .medium))
                            .foregroundStyle(s.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment == .center ? .center : .leading)
                if s.showsDetails {
                    VStack(spacing: 6) {
                        ZStack {
                            RingView(progress: dayProgress, lineWidth: 7, color: s.chart, track: s.track)
                            Text(Fmt.percent(dayProgress))
                                .font(s.number(15))
                                .foregroundStyle(s.numberColor)
                        }
                        .frame(width: 74, height: 74)
                        Text(tr("de la journée"))
                            .font(s.text(11))
                            .foregroundStyle(s.secondary)
                    }
                }
            }
        }
    }

    private func timeText(_ time: String, meridiem: String?, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(time)
                .font(context.style.number(size))
                .foregroundStyle(context.style.primary)
            if let meridiem {
                Text(meridiem)
                    .font(context.style.text(size * 0.28, .semibold))
                    .foregroundStyle(context.style.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

// MARK: - Calendar

struct MonthGridView: View {
    let date: Date
    let style: ResolvedStyle
    var fontSize: CGFloat = 11
    var rowSpacing: CGFloat = 3

    var body: some View {
        let cells = DateMath.monthGrid(for: date)
        let rows = max(1, cells.count / 7)
        VStack(spacing: rowSpacing) {
            HStack(spacing: 0) {
                ForEach(Array(DateMath.weekdaySymbols().enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(style.text(fontSize - 2, .semibold))
                        .foregroundStyle(style.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        dayCell(cells[row * 7 + column])
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isToday = DateMath.isSameDay(day, date)
            Text("\(DateMath.calendar.component(.day, from: day))")
                .font(style.text(fontSize, isToday ? .bold : .regular).monospacedDigit())
                .foregroundStyle(isToday ? style.onAccent : (day < DateMath.startOfDay(date) ? style.secondary : style.primary))
                .frame(width: fontSize * 1.9, height: fontSize * 1.9)
                .background {
                    if isToday { Circle().fill(style.accent) }
                }
        } else {
            Text(" ")
                .font(style.text(fontSize))
                .frame(height: fontSize * 1.9)
        }
    }
}

struct CalendarWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let date = context.date
        switch context.family {
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    WLabel(text: Fmt.weekday(date), style: s, color: s.accent)
                    Text("\(DateMath.calendar.component(.day, from: date))")
                        .font(s.number(58))
                        .foregroundStyle(s.numberColor)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Text(Fmt.monthYear(date))
                        .font(s.text(13, .medium))
                        .foregroundStyle(s.secondary)
                    if s.showsDetails {
                        Text(tr("Semaine \(DateMath.calendar.component(.weekOfYear, from: date))"))
                            .font(s.text(12))
                            .foregroundStyle(s.secondary)
                    }
                }
                .frame(width: 104, alignment: .leading)
                MonthGridView(date: date, style: s, fontSize: 10.5, rowSpacing: 1)
            }
        case .systemLarge, .systemExtraLarge:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.month(date))
                        .font(s.text(26, s.titleWeight))
                        .foregroundStyle(s.primary)
                    Text(Fmt.format(date, template: "yyyy"))
                        .font(s.text(26, .regular))
                        .foregroundStyle(s.secondary)
                    Spacer()
                }
                MonthGridView(date: date, style: s, fontSize: 15, rowSpacing: 7)
                Spacer(minLength: 0)
                if s.showsDetails {
                    let day = DateMath.dayOfYear(date)
                    let total = DateMath.daysInYear(of: date)
                    HStack {
                        Text(Fmt.longDay(date))
                        Spacer()
                        Text(tr("Jour \(day) sur \(total)"))
                    }
                    .font(s.text(13, .medium))
                    .foregroundStyle(s.secondary)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                if s.showsTitle {
                    WLabel(text: Fmt.month(date), style: s, color: s.accent)
                }
                MonthGridView(date: date, style: s, fontSize: 9.5, rowSpacing: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - World clock

struct WorldClockWidgetView: View {
    let context: RenderContext

    private struct ZoneItem: Identifiable {
        let id: String
        let zone: TimeZone
        let index: Int
    }

    var body: some View {
        let s = context.style
        let zones = context.options.cities.compactMap { id in TimeZone(identifier: id).map { (id: id, zone: $0) } }
        let shown = zones.prefix(context.isSmall ? 2 : 4).enumerated().map { ZoneItem(id: $0.element.id, zone: $0.element.zone, index: $0.offset) }

        if shown.isEmpty {
            WidgetMessage(symbol: "globe", title: tr("Aucune ville"), message: tr("Choisis tes villes dans Ardane"), style: s)
        } else if context.isSmall {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(shown) { item in
                    row(id: item.id, zone: item.zone, compact: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(shown) { item in
                    if item.index > 0 {
                        Rectangle().fill(s.track).frame(width: 1).padding(.vertical, 4)
                    }
                    column(id: item.id, zone: item.zone)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func row(id: String, zone: TimeZone, compact: Bool) -> some View {
        let s = context.style
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: WorldCities.isDaytime(in: zone, at: context.date) ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(s.icon)
                WLabel(text: WorldCities.name(for: id), style: s)
            }
            Text(Fmt.time(context.date, uses24Hour: context.settings.uses24HourClock, timeZone: zone))
                .font(s.number(30))
                .foregroundStyle(s.numberColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if s.showsDetails {
                Text([WorldCities.dayShift(for: zone, at: context.date), WorldCities.offsetText(for: zone, at: context.date)].compactMap { $0 }.joined(separator: " · "))
                    .font(s.text(11))
                    .foregroundStyle(s.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func column(id: String, zone: TimeZone) -> some View {
        let s = context.style
        return VStack(spacing: 6) {
            Image(systemName: WorldCities.isDaytime(in: zone, at: context.date) ? "sun.max.fill" : "moon.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(s.icon)
            Text(WorldCities.name(for: id))
                .font(s.text(12, .semibold))
                .foregroundStyle(s.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(Fmt.time(context.date, uses24Hour: context.settings.uses24HourClock, timeZone: zone))
                .font(s.number(24))
                .foregroundStyle(s.numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if s.showsDetails {
                Text(WorldCities.dayShift(for: zone, at: context.date) ?? WorldCities.offsetText(for: zone, at: context.date))
                    .font(s.text(10))
                    .foregroundStyle(s.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Progress

enum ProgressText {
    static func title(_ unit: ProgressUnit, at date: Date) -> String {
        switch unit {
        case .day: tr("Aujourd'hui")
        case .week: tr("Semaine \(DateMath.calendar.component(.weekOfYear, from: date))")
        case .month: Fmt.month(date)
        case .year: Fmt.format(date, template: "yyyy")
        }
    }

    static func remaining(_ unit: ProgressUnit, at date: Date) -> String {
        let interval = DateMath.interval(of: unit, containing: date)
        if unit == .day {
            let minutes = max(0, Int(interval.end.timeIntervalSince(date) / 60))
            let hours = minutes / 60
            return hours > 0 ? tr("\(hours) h \(minutes % 60) min restantes") : tr("\(minutes) min restantes")
        }
        // Days after today, as in "L'année en points".
        let days = max(0, DateMath.daysBetween(date, interval.end) - 1)
        return days == 0 ? tr("Dernier jour") : Fmt.plural(days, tr("jour restant"), tr("jours restants"))
    }

    /// Segment count and how many are elapsed, for the segmented bar.
    static func segments(_ unit: ProgressUnit, at date: Date) -> (count: Int, elapsed: Double) {
        let cal = DateMath.calendar
        switch unit {
        case .day:
            let hour = Double(cal.component(.hour, from: date)) + Double(cal.component(.minute, from: date)) / 60
            return (24, hour)
        case .week:
            let weekday = (cal.component(.weekday, from: date) - cal.firstWeekday + 7) % 7
            return (7, Double(weekday) + DateMath.progress(of: .day, at: date))
        case .month:
            let days = cal.range(of: .day, in: .month, for: date)?.count ?? 30
            return (days, Double(cal.component(.day, from: date) - 1) + DateMath.progress(of: .day, at: date))
        case .year:
            let month = cal.component(.month, from: date)
            return (12, Double(month - 1) + DateMath.progress(of: .month, at: date))
        }
    }
}

struct SegmentedProgressView: View {
    let count: Int
    let elapsed: Double
    let style: ResolvedStyle
    var height: CGFloat = 22

    var body: some View {
        HStack(spacing: count > 20 ? 2 : 3) {
            ForEach(0..<count, id: \.self) { index in
                let fill = min(1, max(0, elapsed - Double(index)))
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous).fill(style.track)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(style.accent)
                            .frame(height: geo.size.height * fill)
                    }
                }
            }
        }
        .frame(height: height)
    }
}

struct ProgressWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let unit = context.options.progressUnit
        let value = DateMath.progress(of: unit, at: context.date)

        if context.isSmall {
            VStack(alignment: s.horizontalAlignment, spacing: 4) {
                if s.showsTitle { WLabel(text: ProgressText.title(unit, at: context.date), style: s) }
                Spacer(minLength: 0)
                Text(Fmt.percent(value))
                    .font(s.number(44))
                    .foregroundStyle(s.numberColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                BarView(progress: value, color: s.chart, track: s.track, height: 6)
                if s.showsDetails {
                    Text(ProgressText.remaining(unit, at: context.date))
                        .font(s.text(11))
                        .foregroundStyle(s.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 2)
                }
            }
            .widgetFrame(s)
        } else {
            let segments = ProgressText.segments(unit, at: context.date)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        if s.showsTitle { WLabel(text: ProgressText.title(unit, at: context.date), style: s) }
                        Text(Fmt.percent(value))
                            .font(s.number(46))
                            .foregroundStyle(s.numberColor)
                            .lineLimit(1)
                    }
                    Spacer()
                    if s.showsDetails {
                        Text(ProgressText.remaining(unit, at: context.date))
                            .font(s.text(12))
                            .foregroundStyle(s.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Spacer(minLength: 0)
                SegmentedProgressView(count: segments.count, elapsed: segments.elapsed, style: s, height: context.isLarge ? 60 : 24)
            }
        }
    }
}

// MARK: - Countdown

struct CountdownInfo {
    let days: Int
    let isToday: Bool
    let isPast: Bool
    let caption: String

    init(options: DesignOptions, now: Date) {
        switch options.countdownMode {
        case .until:
            let delta = DateMath.daysBetween(now, options.countdownDate)
            days = abs(delta)
            isToday = delta == 0
            isPast = delta < 0
            caption = delta == 0 ? tr("C'est aujourd'hui") : delta > 0 ? (abs(delta) > 1 ? tr("jours restants") : tr("jour restant")) : tr("jours passés")
        case .since:
            let delta = DateMath.daysBetween(options.countdownDate, now)
            days = max(0, delta)
            isToday = delta == 0
            isPast = false
            caption = delta == 0 ? tr("C'est aujourd'hui") : (delta > 1 ? tr("jours depuis") : tr("jour depuis"))
        }
    }

    /// "6 semaines et 3 jours"
    var breakdown: String? {
        guard days >= 7 else { return nil }
        if days >= 365 {
            let years = days / 365
            let rest = days % 365
            let months = rest / 30
            return months > 0
                ? tr("\(Fmt.plural(years, tr("an"), tr("ans", context: "duration"))) et \(Fmt.plural(months, tr("mois", context: "one"), tr("mois")))")
                : Fmt.plural(years, tr("an"), tr("ans", context: "duration"))
        }
        let weeks = days / 7
        let rest = days % 7
        return rest > 0
            ? tr("\(Fmt.plural(weeks, tr("semaine"), tr("semaines"))) et \(Fmt.plural(rest, tr("jour"), tr("jours")))")
            : Fmt.plural(weeks, tr("semaine"), tr("semaines"))
    }
}

struct CountdownWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let options = context.options
        let info = CountdownInfo(options: options, now: context.date)
        let title = options.countdownTitle.trimmed.isEmpty ? tr("Événement") : options.countdownTitle

        if context.isSmall {
            VStack(alignment: s.horizontalAlignment, spacing: 2) {
                if s.showsTitle {
                    Text(title)
                        .font(s.text(14, s.titleWeight))
                        .foregroundStyle(s.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(s.textAlignment)
                }
                Spacer(minLength: 0)
                bigValue(info, size: 52)
                Text(info.isToday ? "" : info.caption)
                    .font(s.text(12, .medium))
                    .foregroundStyle(s.accent)
                if s.showsDetails {
                    Text(Fmt.shortDay(options.countdownDate))
                        .font(s.text(11))
                        .foregroundStyle(s.secondary)
                        .padding(.top, 2)
                }
            }
            .widgetFrame(s)
        } else {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    bigValue(info, size: 64)
                    if !info.isToday {
                        Text(info.caption)
                            .font(s.text(13, .medium))
                            .foregroundStyle(s.accent)
                    }
                }
                .frame(minWidth: 96, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    if s.showsTitle {
                        Text(title)
                            .font(s.text(20, s.titleWeight))
                            .foregroundStyle(s.primary)
                            .lineLimit(2)
                    }
                    Text(Fmt.longDay(options.countdownDate) + " " + Fmt.format(options.countdownDate, template: "yyyy"))
                        .font(s.text(13))
                        .foregroundStyle(s.secondary)
                    if s.showsDetails, let breakdown = info.breakdown {
                        Text(breakdown)
                            .font(s.text(12))
                            .foregroundStyle(s.secondary)
                    }
                    if s.showsDetails, options.countdownMode == .until, !info.isPast {
                        BarView(progress: elapsedFraction, color: s.chart, track: s.track, height: 5)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// Share of the wait already behind us, measured from when the countdown was created.
    private var elapsedFraction: Double {
        let start = context.design.createdAt
        let end = context.options.countdownDate
        guard end > start else { return 1 }
        return min(1, max(0, context.date.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    @ViewBuilder
    private func bigValue(_ info: CountdownInfo, size: CGFloat) -> some View {
        let s = context.style
        if info.isToday {
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.7, weight: .semibold))
                .foregroundStyle(s.icon)
        } else {
            Text(Fmt.number(info.days))
                .font(s.number(size))
                .foregroundStyle(s.numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: - Year in dots

struct YearDotsView: View {
    let date: Date
    let style: ResolvedStyle

    var body: some View {
        let total = DateMath.daysInYear(of: date)
        let today = DateMath.dayOfYear(date) - 1
        GeometryReader { geo in
            let columns = Self.bestColumns(total: total, size: geo.size)
            ZStack {
                DotGridShape(total: total, columns: columns, range: (today + 1)..<total).fill(style.track)
                DotGridShape(total: total, columns: columns, range: 0..<today).fill(style.primary.opacity(0.85))
                DotGridShape(total: total, columns: columns, range: today..<(today + 1)).fill(style.accent)
            }
        }
    }

    /// Picks the column count that gives the largest dots for the available space.
    static func bestColumns(total: Int, size: CGSize) -> Int {
        guard size.width > 0, size.height > 0 else { return 20 }
        var best = 20
        var bestCell: CGFloat = 0
        for columns in 8...60 {
            let rows = Int(ceil(Double(total) / Double(columns)))
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            if cell > bestCell {
                bestCell = cell
                best = columns
            }
        }
        return best
    }
}

struct YearDotsWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let date = context.date
        let day = DateMath.dayOfYear(date)
        let total = DateMath.daysInYear(of: date)

        switch context.family {
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    WLabel(text: Fmt.format(date, template: "yyyy"), style: s)
                    Text(Fmt.percent(Double(day) / Double(total)))
                        .font(s.number(34))
                        .foregroundStyle(s.numberColor)
                    Spacer(minLength: 0)
                    if s.showsDetails {
                        Text(tr("Jour \(day)"))
                            .font(s.text(13, .medium))
                            .foregroundStyle(s.primary)
                        Text(tr("\(total - day) restants"))
                            .font(s.text(12))
                            .foregroundStyle(s.secondary)
                    }
                }
                .frame(width: 86, alignment: .leading)
                YearDotsView(date: date, style: s)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                if s.showsTitle || s.showsDetails {
                    HStack {
                        if s.showsTitle { WLabel(text: Fmt.format(date, template: "yyyy"), style: s) }
                        Spacer()
                        if s.showsDetails {
                            Text("\(day)/\(total)")
                                .font(s.text(11, .semibold).monospacedDigit())
                                .foregroundStyle(s.secondary)
                        }
                    }
                }
                YearDotsView(date: date, style: s)
                if context.isLarge, s.showsDetails {
                    HStack {
                        Text(Fmt.longDay(date))
                        Spacer()
                        Text(Fmt.percent(Double(day) / Double(total)) + tr(" de l'année"))
                    }
                    .font(s.text(13, .medium))
                    .foregroundStyle(s.secondary)
                }
            }
        }
    }
}
