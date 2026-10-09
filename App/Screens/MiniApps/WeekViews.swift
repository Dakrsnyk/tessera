import SwiftUI

// MARK: - Week title

enum WeekTitle {
    /// « Cette semaine », « Semaine dernière », « Semaine prochaine », or « Semaine du 28 sept. ».
    static func of(_ week: [Date], now: Date = Date()) -> String {
        guard let first = week.first else { return "" }
        let contains = { (date: Date) in week.contains { DateMath.isSameDay($0, date) } }
        if contains(now) { return tr("Cette semaine") }
        if let last = DateMath.calendar.date(byAdding: .day, value: -7, to: now), contains(last) { return tr("Semaine dernière") }
        if let next = DateMath.calendar.date(byAdding: .day, value: 7, to: now), contains(next) { return tr("Semaine prochaine") }
        return tr("Semaine du \(Fmt.format(first, template: "dMMM"))")
    }

    /// The same day a week before or after; never after today when the future isn't allowed.
    static func shifted(_ day: Date, by weeks: Int, allowsFuture: Bool, now: Date = Date()) -> Date {
        let moved = DateMath.calendar.date(byAdding: .day, value: 7 * weeks, to: day) ?? day
        return !allowsFuture && moved > now ? now : moved
    }
}

// MARK: - Week of rounds

/// How a day reads in a week of rounds: done (filled, with a check), how far it got (a ring),
/// planned (a full outline) or nothing (a dotted outline).
struct WeekDayMark {
    var progress: Double = 0
    var isDone = false
    var isPlanned = false
}

/// A week as seven rounds under its title: a tap on a round picks that day, a swipe across the
/// card (or the arrows by the title) goes to the week before or after. Below the rounds, what the
/// screen tells about that week.
struct WeekCard<Content: View>: View {
    @Binding var day: Date
    let colorHex: String
    let allowsFuture: Bool
    let detail: ([Date]) -> String?
    let mark: (Date) -> WeekDayMark
    let content: ([Date]) -> Content
    @State private var forward = true

    init(day: Binding<Date>, colorHex: String, allowsFuture: Bool = true, detail: @escaping ([Date]) -> String? = { _ in nil },
         mark: @escaping (Date) -> WeekDayMark, @ViewBuilder content: @escaping ([Date]) -> Content) {
        _day = day
        self.colorHex = colorHex
        self.allowsFuture = allowsFuture
        self.detail = detail
        self.mark = mark
        self.content = content
    }

    private var accent: Color { Color(hex: colorHex) }

    var body: some View {
        let now = Date()
        let week = DateMath.week(containing: day)
        let canGoForward = allowsFuture || !(week.contains { DateMath.isSameDay($0, now) })
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Button { shift(-1) } label: {
                    Image(systemName: "chevron.left").font(.subheadline.weight(.bold)).frame(width: 26, height: 26)
                }
                .accessibilityLabel(Text(tr("Semaine précédente")))
                Text(WeekTitle.of(week, now: now))
                    .font(.title3.weight(.semibold))
                    .contentTransition(.numericText())
                    .accessibilityAddTraits(.isHeader)
                Button { shift(1) } label: {
                    Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).frame(width: 26, height: 26)
                }
                .disabled(!canGoForward)
                .accessibilityLabel(Text(tr("Semaine suivante")))
                Spacer(minLength: 8)
                if let text = detail(week) {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .tint(accent)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { date in
                        round(date, now: now)
                    }
                }
                content(week)
            }
            .card()
            .id(DateMath.dayKey(week.first ?? day))
            .transition(.push(from: forward ? .trailing : .leading))
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > 50, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                        if dx < 0, !canGoForward { return }
                        shift(dx < 0 ? 1 : -1)
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("week-card")
        }
    }

    private func round(_ date: Date, now: Date) -> some View {
        let state = mark(date)
        let isSelected = DateMath.isSameDay(date, day)
        let isToday = DateMath.isSameDay(date, now)
        let isFuture = DateMath.startOfDay(date) > now
        return Button {
            guard allowsFuture || !isFuture else { return }
            Haptics.tap()
            withAnimation(.snappy) { day = date }
        } label: {
            VStack(spacing: 6) {
                Text(String(Fmt.weekday(date).prefix(1)).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected || isToday ? accent : .secondary)
                ZStack {
                    if state.isDone {
                        Circle().fill(accent)
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Color.white)
                    } else {
                        Circle()
                            .strokeBorder(state.isPlanned ? accent.opacity(0.6) : Color.secondary.opacity(0.25),
                                          style: StrokeStyle(lineWidth: 2, dash: state.isPlanned || state.progress > 0 ? [] : [3, 3]))
                        if state.progress > 0 {
                            Circle()
                                .trim(from: 0, to: min(1, state.progress))
                                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .padding(1)
                        }
                        Text("\(DateMath.calendar.component(.day, from: date))")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(isFuture ? Color.secondary : Color.primary)
                    }
                }
                .frame(width: 32, height: 32)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? accent.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Fmt.longDay(date)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shift(_ weeks: Int) {
        Haptics.tap()
        forward = weeks > 0
        withAnimation(.snappy) {
            day = WeekTitle.shifted(day, by: weeks, allowsFuture: allowsFuture)
        }
    }
}

// MARK: - The week as a table

/// The week as a table, in the style of the app: a column a day (Monday first), the hours down the
/// side, each thing of the day a colored block at its time (side by side when they overlap), and what
/// has no time (a workout, a task of the day) in a band above the hours. A tap on a day's header picks
/// that day. `compact`: the small version of « Mon Quotidien », blocks without text.
struct WeekTimetable: View {
    let days: [(day: Date, items: [AgendaItem])]
    let selected: Date?
    let compact: Bool
    let hourHeight: CGFloat
    let onSelect: ((Date) -> Void)?

    init(days: [(day: Date, items: [AgendaItem])], selected: Date? = nil, compact: Bool = false, hourHeight: CGFloat? = nil, onSelect: ((Date) -> Void)? = nil) {
        self.days = days
        self.selected = selected
        self.compact = compact
        self.hourHeight = hourHeight ?? (compact ? 15 : 38)
        self.onSelect = onSelect
    }

    private var gutter: CGFloat { compact ? 16 : 28 }
    private var spacing: CGFloat { compact ? 2 : 3 }

    var body: some View {
        let now = Date()
        let timed = days.map { $0.items.filter { $0.start != nil } }
        let untimed = days.map { $0.items.filter { $0.start == nil } }
        let starts = timed.flatMap { $0 }.compactMap(\.start).map(Self.minute)
        let ends = timed.flatMap { $0 }.map { Self.end($0) }
        let first = min(8 * 60, starts.min() ?? 8 * 60) / 60 * 60
        let last = max(18 * 60, ((ends.max() ?? 17 * 60) + 59) / 60 * 60)
        let height = CGFloat(last - first) / 60 * hourHeight
        VStack(spacing: compact ? 4 : 8) {
            header(now: now)
            if untimed.contains(where: { !$0.isEmpty }) {
                HStack(alignment: .top, spacing: spacing) {
                    Color.clear.frame(width: gutter, height: 1)
                    ForEach(Array(untimed.enumerated()), id: \.offset) { _, items in
                        allDay(items)
                    }
                }
            }
            HStack(alignment: .top, spacing: spacing) {
                ZStack(alignment: .topTrailing) {
                    ForEach(Array(stride(from: first, through: last, by: compact ? 120 : 60)), id: \.self) { minute in
                        Text("\(minute / 60)")
                            .font(.system(size: compact ? 8 : 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .offset(y: CGFloat(minute - first) / 60 * hourHeight - 6)
                    }
                }
                .frame(width: gutter - 4, height: height, alignment: .topTrailing)
                .padding(.trailing, 4)
                ForEach(Array(timed.enumerated()), id: \.offset) { index, items in
                    column(items, day: days[index].day, first: first, last: last, height: height, now: now)
                }
            }
            .background(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(stride(from: first, through: last, by: 60)), id: \.self) { minute in
                        Rectangle()
                            .fill(Color.primary.opacity(0.07))
                            .frame(height: 0.5)
                            .offset(y: CGFloat(minute - first) / 60 * hourHeight)
                    }
                }
                .padding(.leading, gutter)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("week-timetable")
    }

    private func header(now: Date) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: gutter, height: 1)
            ForEach(Array(days.enumerated()), id: \.offset) { _, entry in
                let isSelected = selected.map { DateMath.isSameDay($0, entry.day) } ?? false
                let isToday = DateMath.isSameDay(entry.day, now)
                let label = VStack(spacing: 0) {
                        Text(String(Fmt.weekday(entry.day).prefix(compact ? 1 : 3)).uppercased())
                            .font(.system(size: compact ? 8 : 10, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(DateMath.calendar.component(.day, from: entry.day))")
                            .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                    .frame(maxWidth: .infinity, minHeight: compact ? 28 : 40)
                    .background(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.12) : Color.clear),
                                in: RoundedRectangle(cornerRadius: compact ? 7 : 10, style: .continuous))
                if let onSelect {
                    Button {
                        Haptics.tap()
                        onSelect(entry.day)
                    } label: {
                        label
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(Fmt.longDay(entry.day)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                } else {
                    label
                }
            }
        }
    }

    /// What has no time: a few chips, then « +2 ».
    private func allDay(_ items: [AgendaItem]) -> some View {
        let shown = Array(items.prefix(compact ? 2 : 3))
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(shown) { item in
                Group {
                    if compact {
                        Capsule().fill(Color(hex: item.colorHex)).frame(height: 4)
                    } else {
                        Text(item.title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .padding(.horizontal, 3)
                            .frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
                            .background(Color(hex: item.colorHex), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                .opacity(item.isDone == true ? 0.45 : 1)
            }
            if items.count > shown.count, !compact {
                Text("+\(items.count - shown.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func column(_ items: [AgendaItem], day: Date, first: Int, last: Int, height: CGFloat, now: Date) -> some View {
        let isSelected = selected.map { DateMath.isSameDay($0, day) } ?? false
        let placed = Self.layout(items)
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: compact ? 4 : 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.025))
                ForEach(placed, id: \.item.id) { block in
                    let width: CGFloat = geo.size.width / CGFloat(block.lanes)
                    let minutes: CGFloat = CGFloat(min(block.end, last) - max(block.start, first))
                    let length: CGFloat = max(compact ? 4 : 16, minutes / 60 * hourHeight - 1)
                    let top: CGFloat = CGFloat(max(block.start, first) - first) / 60 * hourHeight
                    blockView(block)
                        .frame(width: max(4, width - 1), height: length)
                        .offset(x: CGFloat(block.lane) * width, y: top)
                }
                // Now, on today's column.
                if DateMath.isSameDay(day, now) {
                    let minute = Self.minute(now)
                    if minute >= first, minute <= last {
                        Rectangle()
                            .fill(Color.red)
                            .frame(height: compact ? 1 : 1.5)
                            .offset(y: CGFloat(minute - first) / 60 * hourHeight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    @ViewBuilder
    private func blockView(_ block: Placed) -> some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 2.5 : 5, style: .continuous)
        if compact {
            shape.fill(Color(hex: block.item.colorHex))
                .opacity(block.item.isDone == true ? 0.45 : 1)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(block.item.title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                if block.end - block.start >= 50, let start = block.item.start {
                    Text(Fmt.time(start, uses24Hour: true))
                        .font(.system(size: 8, weight: .medium))
                        .monospacedDigit()
                        .opacity(0.85)
                }
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(hex: block.item.colorHex), in: shape)
            .opacity(block.item.isDone == true ? 0.45 : 1)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Layout

    struct Placed {
        let item: AgendaItem
        let start: Int
        let end: Int
        var lane = 0
        var lanes = 1
    }

    static func minute(_ date: Date) -> Int {
        let parts = DateMath.calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Where an item ends on its day (45 minutes when it has no end, at midnight at the latest).
    static func end(_ item: AgendaItem) -> Int {
        guard let start = item.start else { return 0 }
        let from = minute(start)
        guard let end = item.end else { return min(24 * 60, from + 45) }
        let to = DateMath.isSameDay(start, end) ? minute(end) : 24 * 60
        return min(24 * 60, max(from + 20, to))
    }

    /// Items that overlap share their time side by side: each one in the first free lane of its group.
    static func layout(_ items: [AgendaItem]) -> [Placed] {
        let sorted = items.compactMap { item -> Placed? in
            guard let start = item.start else { return nil }
            return Placed(item: item, start: minute(start), end: end(item))
        }
        .sorted { $0.start < $1.start }
        var result: [Placed] = []
        var group: [Placed] = []
        var laneEnds: [Int] = []
        var groupEnd = -1
        func close() {
            let lanes = max(1, laneEnds.count)
            result += group.map { placed in
                var copy = placed
                copy.lanes = lanes
                return copy
            }
            group = []
            laneEnds = []
        }
        for var placed in sorted {
            if placed.start >= groupEnd, !group.isEmpty { close() }
            if let free = laneEnds.firstIndex(where: { $0 <= placed.start }) {
                placed.lane = free
                laneEnds[free] = placed.end
            } else {
                placed.lane = laneEnds.count
                laneEnds.append(placed.end)
            }
            group.append(placed)
            groupEnd = max(groupEnd, placed.end)
        }
        close()
        return result
    }
}

// MARK: - The week as a table, with its title

/// The agenda of a week as a table under its title: a tap on a day picks it, a swipe across the
/// table (or the arrows by the title) goes to the week before or after.
struct WeekTableCard: View {
    @Binding var day: Date
    let days: [(day: Date, items: [AgendaItem])]
    @State private var forward = true

    init(day: Binding<Date>, days: [(day: Date, items: [AgendaItem])]) {
        _day = day
        self.days = days
    }

    var body: some View {
        let now = Date()
        let week = days.map { $0.day }
        let isThisWeek = week.contains { DateMath.isSameDay($0, now) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Button { shift(-1) } label: {
                    Image(systemName: "chevron.left").font(.subheadline.weight(.bold)).frame(width: 26, height: 26)
                }
                .accessibilityLabel(Text(tr("Semaine précédente")))
                Text(WeekTitle.of(week, now: now))
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Button { shift(1) } label: {
                    Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).frame(width: 26, height: 26)
                }
                .accessibilityLabel(Text(tr("Semaine suivante")))
                .accessibilityIdentifier("week-next")
                Spacer(minLength: 8)
                if !isThisWeek {
                    Button(tr("Aujourd'hui")) {
                        Haptics.tap()
                        forward = now > day
                        withAnimation(.snappy) { day = now }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            WeekTimetable(days: days, selected: day) { picked in
                withAnimation(.snappy) { day = picked }
            }
            .card(padding: 12)
            .id(DateMath.dayKey(week.first ?? day))
            .transition(.push(from: forward ? .trailing : .leading))
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let dx = value.translation.width
                        guard abs(dx) > 50, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                        shift(dx < 0 ? 1 : -1)
                    }
            )
        }
    }

    private func shift(_ weeks: Int) {
        Haptics.tap()
        forward = weeks > 0
        withAnimation(.snappy) {
            day = WeekTitle.shifted(day, by: weeks, allowsFuture: true)
        }
    }
}
