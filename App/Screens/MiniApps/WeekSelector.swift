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

/// The week selector at the top of every mini-app (the look of the reference image, the one of `WeekCard`): the
/// seven days of a week side by side, each with its initial and its date in a circle. The selected day sits on a
/// rounded background tinted with the app's accent, its initial and today's in the accent; a day that holds
/// something has a ring (or a filled circle when done), the others a dotted gray ring; the dates of the days to
/// come are dimmed. A tap picks a day, the arrows or a swipe go to the week before or after, and the dates come
/// from the real calendar. A mini-app has one selector: the screen below it tells about the day picked. `mark`
/// tells what a day holds (planned, done, how far it got). A day caught up shows a tinted circle.
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
                Image(systemName: "chevron.left").font(.subheadline.weight(.bold)).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(Text(tr("Semaine précédente")))
            Text(WeekTitle.of(week, now: now))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.bold)).frame(width: 44, height: 44).contentShape(Rectangle())
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
            VStack(spacing: 8) {
                Text(String(Fmt.weekday(date).prefix(1)).uppercased())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(kind == .selected || kind == .today ? accent : Color.secondary)
                dateCircle(date, kind: kind, state: state)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44)
            // The selected day sits on a rounded background tinted with the accent.
            .background(kind == .selected ? accent.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isBlocked ? 0.4 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(isBlocked)
        .accessibilityLabel(Text(Fmt.longDay(date)))
        .accessibilityValue(Text(state.isCaughtUp ? tr("Séance rattrapée") : ""))
        .accessibilityAddTraits(kind == .selected ? .isSelected : [])
        .accessibilityIdentifier("week-day-\(DateMath.dayKey(date))")
    }

    /// The date in a circle: filled with a check when done, tinted with a return arrow when caught up, a ring of
    /// the accent when the day holds something (planned, or how far it got), a dotted gray ring when it holds
    /// nothing. The dates of the days to come are dimmed.
    private func dateCircle(_ date: Date, kind: WeekDayKind, state: WeekDayMark) -> some View {
        ZStack {
            if state.isDone {
                Circle().fill(accent)
                Image(systemName: "checkmark").font(.callout.weight(.bold)).foregroundStyle(Color.white)
            } else {
                if state.isCaughtUp {
                    Circle().fill(accent.opacity(0.16))
                    Circle().strokeBorder(accent.opacity(0.7), lineWidth: 2)
                } else {
                    let holdsSomething = state.isPlanned || state.progress > 0
                    Circle()
                        .strokeBorder(holdsSomething ? accent.opacity(0.7) : Color.secondary.opacity(0.28),
                                      style: StrokeStyle(lineWidth: 2.5, dash: holdsSomething ? [] : [3, 3]))
                    if state.progress > 0 {
                        Circle()
                            .trim(from: 0, to: min(1, state.progress))
                            .stroke(accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(1)
                    }
                }
                Text("\(DateMath.calendar.component(.day, from: date))")
                    .font(.body.weight(kind == .future ? .medium : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(kind == .future ? Color.secondary : Color.primary)
            }
        }
        .frame(width: 38, height: 38)
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
