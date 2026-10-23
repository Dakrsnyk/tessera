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

/// The week selector at the top of every mini-app (the « Signature » style): the seven days of a week side by
/// side, each with its initial, its date and a dot when it holds something. It sits on the colored band of the
/// screen: the selected day is a rounded pill (white on a dark screen, the app's color on a light one), today
/// is outlined, the days gone by are plain and the days to come are dimmed. A tap picks a day, the arrows or a
/// swipe go to the week before or after, and the dates come from the real calendar. A mini-app has one
/// selector: the screen below it tells about the day picked. `mark` tells what a day holds (planned, done,
/// how far it got). `leadingInset` leaves room on the left for the hours column of a week table placed
/// right below, so that its columns sit under the days.
struct WeekSelector: View {
    @Binding var day: Date
    let colorHex: String
    /// Logs (meals, spending) stop at today; plans look ahead too.
    var allowsFuture = true
    var mark: (Date) -> WeekDayMark = { _ in WeekDayMark() }
    var leadingInset: CGFloat = 0
    @State private var forward = true
    @Environment(\.colorScheme) private var scheme

    private var accent: Color { Color(hex: colorHex) }

    var body: some View {
        let now = Date()
        let week = DateMath.week(containing: day)
        let isCurrentWeek = week.contains { DateMath.isSameDay($0, now) }
        let canGoForward = allowsFuture || !isCurrentWeek
        VStack(spacing: 2) {
            header(week: week, now: now, canGoForward: canGoForward)
            HStack(spacing: 3) {
                ForEach(week, id: \.self) { date in
                    dayButton(date, now: now)
                }
            }
            .padding(.leading, leadingInset)
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

    private var selectedFill: Color { scheme == .dark ? Color.white : accent }
    private var selectedInk: Color { scheme == .dark ? accent : Color.white }

    private func dayButton(_ date: Date, now: Date) -> some View {
        let kind = WeekDayKind.of(date, selected: day, now: now)
        let state = mark(date)
        let isBlocked = !allowsFuture && DateMath.startOfDay(date) > DateMath.startOfDay(now)
        let holdsSomething = state.isDone || state.isPlanned || state.isCaughtUp || state.progress > 0
        return Button {
            guard !isBlocked else { return }
            Haptics.tap()
            withAnimation(.snappy) { day = date }
        } label: {
            VStack(spacing: 5) {
                Text(String(Fmt.weekday(date).prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .opacity(0.75)
                Text("\(DateMath.calendar.component(.day, from: date))")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Circle()
                    .fill(holdsSomething ? Color.primary : Color.clear)
                    .frame(width: 5, height: 5)
                    .opacity(0.85)
            }
            .foregroundStyle(kind == .selected ? selectedInk : Color.primary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background {
                if kind == .selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selectedFill)
                        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)
                } else if kind == .today {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.5)
                }
            }
            .opacity(isBlocked ? 0.3 : (kind == .future ? 0.55 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(isBlocked)
        .accessibilityLabel(Text(Fmt.longDay(date)))
        .accessibilityValue(Text(state.isCaughtUp ? tr("Séance rattrapée") : ""))
        .accessibilityAddTraits(kind == .selected ? .isSelected : [])
        .accessibilityIdentifier("week-day-\(DateMath.dayKey(date))")
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
