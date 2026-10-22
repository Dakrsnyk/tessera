import SwiftUI

/// How a day of the selector reads: the selected one, today, a day gone by or a day to come.
enum WeekDayKind: Equatable {
    case selected, today, past, future

    /// The kind of `date`, by priority: selected, then today, then before or after today.
    static func of(_ date: Date, selected: Date, now: Date = Date()) -> WeekDayKind {
        if DateMath.isSameDay(date, selected) { return .selected }
        if DateMath.isSameDay(date, now) { return .today }
        return DateMath.startOfDay(date) < DateMath.startOfDay(now) ? .past : .future
    }
}

/// The week selector at the top of every mini-app: the seven days of a week side by side, each with its
/// initial and its date in a circle. The selected day sits on a rounded background in the app's accent;
/// today, the days gone by and the days to come are drawn differently. A tap picks a day, the arrows or a
/// swipe go to the week before or after, and the dates come from the real calendar. A mini-app has one
/// selector: the screen below it tells about the day picked. `mark` adds what a day holds (a dot when done,
/// an empty dot when planned, a ring for how far it got).
struct WeekSelector: View {
    @Binding var day: Date
    let colorHex: String
    /// Logs (meals, spending) stop at today; plans look ahead too.
    var allowsFuture = true
    var mark: (Date) -> WeekDayMark = { _ in WeekDayMark() }
    @State private var forward = true

    private var accent: Color { Color(hex: colorHex) }

    var body: some View {
        let now = Date()
        let week = DateMath.week(containing: day)
        let isCurrentWeek = week.contains { DateMath.isSameDay($0, now) }
        let canGoForward = allowsFuture || !isCurrentWeek
        VStack(spacing: 6) {
            header(week: week, now: now, canGoForward: canGoForward)
            HStack(spacing: 2) {
                ForEach(week, id: \.self) { date in
                    dayButton(date, now: now)
                }
            }
            .id(DateMath.dayKey(week.first ?? day))
            .transition(.push(from: forward ? .trailing : .leading))
            .simultaneousGesture(swipe(canGoForward: canGoForward))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("week-card")
    }

    // MARK: Header

    private func header(week: [Date], now: Date, canGoForward: Bool) -> some View {
        HStack(spacing: 2) {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.subheadline.weight(.bold)).frame(width: 40, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(Text(tr("Semaine précédente")))
            Text(WeekTitle.of(week, now: now))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).frame(width: 40, height: 44).contentShape(Rectangle())
            }
            .disabled(!canGoForward)
            .accessibilityLabel(Text(tr("Semaine suivante")))
            .accessibilityIdentifier("week-next")
            Spacer(minLength: 8)
            if !DateMath.isSameDay(day, now) {
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
        }
        .tint(accent)
    }

    // MARK: A day

    private func dayButton(_ date: Date, now: Date) -> some View {
        let kind = WeekDayKind.of(date, selected: day, now: now)
        let state = mark(date)
        let isBlocked = !allowsFuture && DateMath.startOfDay(date) > DateMath.startOfDay(now)
        return Button {
            guard !isBlocked else { return }
            Haptics.tap()
            withAnimation(.snappy) { day = date }
        } label: {
            VStack(spacing: 4) {
                Text(String(Fmt.weekday(date).prefix(1)).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(initialColor(kind))
                dateCircle(date, kind: kind, state: state)
                dot(state, kind: kind)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(kind == .selected ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isBlocked ? 0.35 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(isBlocked)
        .accessibilityLabel(Text(Fmt.longDay(date)))
        .accessibilityAddTraits(kind == .selected ? .isSelected : [])
        .accessibilityIdentifier("week-day-\(DateMath.dayKey(date))")
    }

    private func dateCircle(_ date: Date, kind: WeekDayKind, state: WeekDayMark) -> some View {
        ZStack {
            switch kind {
            case .selected:
                Circle().fill(Color.white)
            case .today:
                Circle().fill(accent.opacity(0.16))
                Circle().strokeBorder(accent, lineWidth: 2)
            case .past:
                Circle().fill(Color.secondary.opacity(0.14))
            case .future:
                Circle().strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
            }
            if state.progress > 0 {
                Circle()
                    .trim(from: 0, to: min(1, state.progress))
                    .stroke(kind == .selected ? accent : accent.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1)
            }
            Text("\(DateMath.calendar.component(.day, from: date))")
                .font(.callout.weight(kind == .future ? .medium : .semibold))
                .monospacedDigit()
                .foregroundStyle(dateColor(kind))
        }
        .frame(width: 34, height: 34)
    }

    /// A dot under the date: filled when the day is done, an outline when it is planned, nothing otherwise.
    @ViewBuilder private func dot(_ state: WeekDayMark, kind: WeekDayKind) -> some View {
        let tint = kind == .selected ? Color.white : accent
        if state.isDone || state.isCaughtUp {
            Circle().fill(tint).frame(width: 6, height: 6)
        } else if state.isPlanned {
            Circle().strokeBorder(tint.opacity(0.8), lineWidth: 1.5).frame(width: 6, height: 6)
        } else {
            Color.clear.frame(width: 6, height: 6)
        }
    }

    private func initialColor(_ kind: WeekDayKind) -> Color {
        switch kind {
        case .selected: Color.white.opacity(0.9)
        case .today: accent
        case .past: Color.secondary
        case .future: Color.secondary.opacity(0.7)
        }
    }

    private func dateColor(_ kind: WeekDayKind) -> Color {
        switch kind {
        case .selected: accent
        case .today: accent
        case .past: Color.primary
        case .future: Color.secondary
        }
    }

    // MARK: Moving

    private func swipe(canGoForward: Bool) -> some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 50, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                if dx < 0, !canGoForward { return }
                shift(dx < 0 ? 1 : -1)
            }
    }

    private func shift(_ weeks: Int) {
        Haptics.tap()
        forward = weeks > 0
        withAnimation(.snappy) {
            day = WeekTitle.shifted(day, by: weeks, allowsFuture: allowsFuture)
        }
    }
}
