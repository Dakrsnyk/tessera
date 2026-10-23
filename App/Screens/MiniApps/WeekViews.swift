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

/// How a day reads in a week of rounds: done (filled, with a check), caught up another day (tinted,
/// with a return arrow), how far it got (a ring), planned (a full outline) or nothing (a dotted outline).
struct WeekDayMark {
    var progress: Double = 0
    var isDone = false
    var isPlanned = false
    var isCaughtUp = false
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
                    } else if state.isCaughtUp {
                        Circle().fill(accent.opacity(0.16))
                        Circle().strokeBorder(accent.opacity(0.7), lineWidth: 2)
                        Image(systemName: "arrow.uturn.forward").font(.caption2.weight(.bold)).foregroundStyle(accent)
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
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(Fmt.longDay(date)))
        .accessibilityValue(Text(state.isCaughtUp ? tr("Séance rattrapée") : ""))
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
/// side, each thing of the day a colored block at its time (side by side when they overlap, with its
/// name, then where it takes place and its start time when there is room), and what
/// has no time (a workout, a task of the day) in a band above the hours. A tap on a day's header picks
/// that day. `compact`: the small version of « Mon Quotidien », blocks without text.
struct WeekTimetable: View {
    let days: [(day: Date, items: [AgendaItem])]
    let selected: Date?
    let compact: Bool
    let hourHeight: CGFloat
    let onSelect: ((Date) -> Void)?
    /// A touch on a free time of a day: that day and the time touched (minutes after midnight, by
    /// half-hours), to create something there.
    let onCreate: ((Date, Int) -> Void)?
    /// A touch on something of the day.
    let onOpen: ((AgendaItem) -> Void)?
    /// The hours shown at least (more when something falls outside).
    let hours: ClosedRange<Int>
    /// The color of today's mark and of the selected day (the app's accent unless the screen has its own).
    let accent: Color
    /// False: no strip of days above the table, because a week selector right above it plays that part (see
    /// `fullLeadingInset`). The band of what has no time stays, and a touch on a column picks its day (`onSelect`).
    let showsHeader: Bool
    @Environment(\.colorScheme) private var scheme

    init(days: [(day: Date, items: [AgendaItem])], selected: Date? = nil, compact: Bool = false, hourHeight: CGFloat? = nil,
         hours: ClosedRange<Int> = 8...18, onSelect: ((Date) -> Void)? = nil, onCreate: ((Date, Int) -> Void)? = nil,
         onOpen: ((AgendaItem) -> Void)? = nil, accent: Color = Color.accentColor, showsHeader: Bool = true) {
        self.days = days
        self.selected = selected
        self.compact = compact
        self.hourHeight = hourHeight ?? (compact ? 15 : 38)
        self.hours = hours
        self.onSelect = onSelect
        self.onCreate = onCreate
        self.onOpen = onOpen
        self.accent = accent
        self.showsHeader = showsHeader
    }

    /// A color written over its own translucent tint (Calendar's blocks): darker on a light screen, lighter on a dark one.
    private var inkShift: Double { scheme == .dark ? 0.12 : -0.28 }

    /// The hours column and the gap between columns of the full table.
    private static let fullGutter: CGFloat = 28
    private static let fullSpacing: CGFloat = 3
    /// Where the first day column of the full table starts: the `leadingInset` a week selector placed right
    /// above it needs, so that its seven days sit exactly over the seven columns (same side margins).
    static let fullLeadingInset: CGFloat = fullGutter + fullSpacing

    private var gutter: CGFloat { compact ? 16 : Self.fullGutter }
    private var spacing: CGFloat { compact ? 2 : Self.fullSpacing }

    var body: some View {
        let now = Date()
        let timed = days.map { $0.items.filter { $0.start != nil } }
        let untimed = days.map { $0.items.filter { $0.start == nil } }
        let starts = timed.flatMap { $0 }.compactMap(\.start).map(Self.minute)
        let ends = timed.flatMap { $0 }.map { Self.end($0) }
        let first = min(hours.lowerBound * 60, starts.min() ?? hours.lowerBound * 60) / 60 * 60
        let last = max(hours.upperBound * 60, ((ends.max() ?? (hours.upperBound - 1) * 60) + 59) / 60 * 60)
        let height = CGFloat(last - first) / 60 * hourHeight
        VStack(spacing: compact ? 4 : 8) {
            if showsHeader {
                header(now: now)
            }
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
                            .foregroundStyle(.secondary)
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
                            .fill(Color.primary.opacity(compact ? 0.07 : 0.12))
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
                let label = dayLabel(entry.day, isSelected: isSelected, isToday: isToday)
                if let onSelect {
                    Button {
                        Haptics.tap()
                        onSelect(entry.day)
                    } label: {
                        label
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(Fmt.longDay(entry.day)))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                } else {
                    label
                }
            }
        }
    }

    /// A day's head: Calendar's way (a letter, then the number, in a filled circle for today and a soft one
    /// for the day picked) in the full table; the small colored block in the compact one.
    @ViewBuilder
    private func dayLabel(_ date: Date, isSelected: Bool, isToday: Bool) -> some View {
        if compact {
            VStack(spacing: 0) {
                Text(String(Fmt.weekday(date).prefix(1)).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(DateMath.calendar.component(.day, from: date))")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(isSelected ? Color.white : (isToday ? accent : Color.primary))
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(isSelected ? accent : (isToday ? accent.opacity(0.12) : Color.clear),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        } else {
            let circle: Color = isToday ? accent : (isSelected ? Color.primary.opacity(0.14) : Color.clear)
            VStack(spacing: 2) {
                Text(String(Fmt.weekday(date).prefix(days.count > 1 ? 1 : 3)).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? accent : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(DateMath.calendar.component(.day, from: date))")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isToday ? Color.white : Color.primary)
                    .frame(width: 30, height: 30)
                    .background(circle, in: Circle())
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
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
                        let color = Color(hex: item.colorHex)
                        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                        Text(item.title)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(color)
                            .brightness(inkShift)
                            .lineLimit(1)
                            .padding(.leading, 5)
                            .padding(.trailing, 2)
                            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
                            .background(color.opacity(0.2), in: shape)
                            .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 2) }
                            .clipShape(shape)
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
        // The compact table keeps a soft tile a day; the full one, like Calendar, only a hairline between
        // the days and a faint tint on the day picked.
        let tint: Color = compact
            ? (isSelected ? accent.opacity(0.08) : Color.primary.opacity(0.025))
            : (isSelected && days.count > 1 ? accent.opacity(0.06) : Color.clear)
        let background = RoundedRectangle(cornerRadius: compact ? 4 : 8, style: .continuous).fill(tint)
        // Without a strip of days, a touch on a column picks its day.
        let picksDay = !showsHeader && onSelect != nil
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Without `onCreate`, no gesture: a touch reaches the link the table may sit in.
                if let onCreate {
                    background
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { location in
                            if picksDay { onSelect?(day) }
                            // Down to the half-hour touched, never past the last one of the day.
                            let touched = first + Int(location.y / hourHeight * 60)
                            onCreate(day, min(23 * 60 + 30, max(0, touched / 30 * 30)))
                        }
                        .accessibilityAction(named: Text(tr("Créer un événement ce jour-là"))) {
                            onCreate(day, 9 * 60)
                        }
                } else if picksDay {
                    background
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect?(day) }
                } else {
                    background
                }
                if !compact, days.count > 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 0.5)
                        .frame(maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
                ForEach(placed, id: \.item.id) { block in
                    let width: CGFloat = geo.size.width / CGFloat(block.lanes)
                    let minutes: CGFloat = CGFloat(min(block.end, last) - max(block.start, first))
                    let length: CGFloat = max(compact ? 4 : 16, minutes / 60 * hourHeight - 1)
                    let top: CGFloat = CGFloat(max(block.start, first) - first) / 60 * hourHeight
                    Group {
                        if let onOpen {
                            Button { onOpen(block.item) } label: { blockView(block, height: length) }
                                .buttonStyle(.pressable)
                        } else {
                            blockView(block, height: length)
                        }
                    }
                    .frame(width: max(4, width - 1), height: length)
                    .offset(x: CGFloat(block.lane) * width, y: top)
                }
                // Now, on today's column.
                if DateMath.isSameDay(day, now) {
                    let minute = Self.minute(now)
                    if minute >= first, minute <= last {
                        let y: CGFloat = CGFloat(minute - first) / 60 * hourHeight
                        if compact {
                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 1)
                                .offset(y: y)
                                .allowsHitTesting(false)
                        } else {
                            // A dot at the start of the line, as in Calendar.
                            HStack(spacing: 0) {
                                Circle().fill(Color.red).frame(width: 7, height: 7)
                                Rectangle().fill(Color.red).frame(height: 1.5)
                            }
                            .frame(height: 7)
                            .offset(y: y - 3.5)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    /// `height`: the block's height on screen, which says what fits under its title.
    @ViewBuilder
    private func blockView(_ block: Placed, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: compact ? 2.5 : 5, style: .continuous)
        if compact {
            shape.fill(Color(hex: block.item.colorHex))
                .opacity(block.item.isDone == true ? 0.45 : 1)
        } else {
            let color = Color(hex: block.item.colorHex)
            let minutes = block.end - block.start
            let lines = Self.lines(height: height, minutes: minutes, hasPlace: block.item.place != nil)
            // Without its place, the block as before the places.
            let plainTime = Self.lines(height: height, minutes: minutes, hasPlace: false).time
            Group {
                if lines.place, let place = block.item.place {
                    // A name on two lines takes the room of the time, then of the place, rather than
                    // being cut to its first line.
                    ViewThatFits(in: .vertical) {
                        if lines.time {
                            blockText(block.item, place: place, time: true)
                        }
                        blockText(block.item, place: place, time: false)
                        blockText(block.item, place: nil, time: plainTime)
                    }
                } else {
                    blockText(block.item, place: nil, time: lines.time)
                }
            }
            // Calendar's block: a soft tint of the color, a thin solid bar on the left, the text in the color.
            .foregroundStyle(color)
            .brightness(inkShift)
            .padding(.leading, 6)
            .padding(.trailing, 2)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(color.opacity(0.2), in: shape)
            .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 3) }
            .clipShape(shape)
            .opacity(block.item.isDone == true ? 0.45 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Self.spoken(block.item)))
        }
    }

    /// The text of a block of the full table: its name, then `place` and its start time when given.
    private func blockText(_ item: AgendaItem, place: String?, time: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            if let place {
                Text(place)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            if time, let start = item.start {
                Text(Fmt.time(start, uses24Hour: true))
                    .font(.system(size: 8, weight: .medium))
                    .monospacedDigit()
                    .opacity(0.85)
            }
        }
    }

    /// What a block of the full table may write under its title (15 points for the padding and the
    /// title's first line, 10 for each line under it): where it takes place when there is room for it,
    /// then its start time (from 50 minutes) when there is room for that too. A block without a place,
    /// or too short for it, keeps its start time from 50 minutes. An upper bound: a name on several lines
    /// first drops the time, then the place (the block as before). With a place, the start time is thus
    /// left to the hours down the side on Planning's classes of 50 to 56 minutes (38 points an hour) and
    /// on those of 71 to 98 minutes of Mon Quotidien's full-width card (22 points an hour).
    static func lines(height: CGFloat, minutes: Int, hasPlace: Bool) -> (place: Bool, time: Bool) {
        let showsTime = minutes >= 50
        let below = height - 15
        guard hasPlace, below >= 10 else { return (false, showsTime) }
        return (true, showsTime && below >= 20)
    }

    /// What VoiceOver says of a block: its name, its time and its detail (the room of a class, the
    /// place of an event), even when the block is too short to show them.
    static func spoken(_ item: AgendaItem) -> String {
        [item.title, item.timeText, item.detail ?? item.place].compactMap { $0 }.joined(separator: ", ")
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
/// table (or the arrows by the title) goes to the week before or after. `onCreate` and `onOpen`: see
/// `WeekTimetable`.
struct WeekTableCard: View {
    @Binding var day: Date
    let days: [(day: Date, items: [AgendaItem])]
    let onCreate: ((Date, Int) -> Void)?
    let onOpen: ((AgendaItem) -> Void)?
    let accent: Color
    @State private var forward = true

    init(day: Binding<Date>, days: [(day: Date, items: [AgendaItem])], onCreate: ((Date, Int) -> Void)? = nil,
         onOpen: ((AgendaItem) -> Void)? = nil, accent: Color = Color.accentColor) {
        _day = day
        self.days = days
        self.onCreate = onCreate
        self.onOpen = onOpen
        self.accent = accent
    }

    var body: some View {
        let now = Date()
        let week = days.map { $0.day }
        let isThisWeek = week.contains { DateMath.isSameDay($0, now) }
        VStack(alignment: .leading, spacing: 6) {
            // Calendar's head: the month and year big and bold, the arrows and « Aujourd'hui » discreet.
            HStack(alignment: .center, spacing: 0) {
                Text(Fmt.monthYear(day))
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if !isThisWeek {
                    Button {
                        Haptics.tap()
                        forward = now > day
                        withAnimation(.snappy) { day = now }
                    } label: {
                        Text(tr("Aujourd'hui"))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 6)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                Button { shift(-1) } label: {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold)).frame(width: 40, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tr("Semaine précédente")))
                Button { shift(1) } label: {
                    Image(systemName: "chevron.right").font(.body.weight(.semibold)).frame(width: 40, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(Text(tr("Semaine suivante")))
                .accessibilityIdentifier("week-next")
            }
            .tint(accent)
            WeekTimetable(days: days, selected: day, onSelect: { picked in
                withAnimation(.snappy) { day = picked }
            }, onCreate: onCreate, onOpen: onOpen, accent: accent)
            .card(padding: 10)
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
