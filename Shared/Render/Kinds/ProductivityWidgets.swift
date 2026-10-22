import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Tasks

struct TasksWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let content = context.payload.content
        let visible = content.visibleTasks(showingCompleted: context.options.showsCompletedTasks, now: context.date)
        let openCount = content.tasks.filter { !$0.isDone }.count
        let limit = context.isSmall ? 3 : context.isMedium ? 4 : 10

        VStack(alignment: .leading, spacing: context.isLarge ? 10 : 7) {
            if s.showsTitle {
                HStack {
                    WLabel(text: context.design.name, style: s)
                    Spacer()
                    if s.showsDetails, !content.tasks.isEmpty {
                        Text(openCount == 0 ? tr("Terminé") : tr("\(openCount) à faire"))
                            .font(s.text(11, .semibold))
                            .foregroundStyle(s.accent)
                    }
                }
            }
            if content.tasks.isEmpty {
                WidgetMessage(symbol: "plus.circle", title: tr("Aucune tâche"), message: tr("Ajoute-les dans Ardane"), style: s)
            } else if visible.isEmpty {
                WidgetMessage(symbol: "checkmark.circle", title: tr("Tout est fait"), message: context.isSmall ? nil : tr("Belle journée."), style: s)
            } else {
                ForEach(visible.prefix(limit)) { task in
                    IntentButton(intent: ToggleTaskIntent(taskID: task.id), isEnabled: context.isInteractive) {
                        HStack(spacing: 8) {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: context.isLarge ? 19 : 17, weight: .medium))
                                .foregroundStyle(task.isDone ? s.accent : s.secondary)
                            Text(task.title)
                                .font(s.text(context.isLarge ? 15 : 13, .medium))
                                .foregroundStyle(task.isDone ? s.secondary : s.primary)
                                .strikethrough(task.isDone, color: s.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                }
                if visible.count > limit {
                    let hidden = visible.dropFirst(limit)
                    let hiddenOpen = hidden.filter { !$0.isDone }.count
                    Text(hiddenOpen > 0 ? tr("+ \(hiddenOpen) à faire") : "+ \(Fmt.plural(hidden.count, tr("terminée"), tr("terminées")))")
                        .font(s.text(11))
                        .foregroundStyle(s.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Habits

/// One band per habit: a header (the check of today, the name, the streak and the regularity over 30 days)
/// over a grid of its last weeks, like a contribution chart. When the room is too short for seven rows per
/// week, the grid becomes one row of the recent days.
struct HabitsWidgetView: View {
    let context: RenderContext

    private static let headerHeight: CGFloat = 18
    private static let headerGap: CGFloat = 4

    private var limit: Int { context.isLarge ? 7 : 3 }

    var body: some View {
        let s = context.style
        let habits = context.payload.content.habits
        let doneToday = habits.filter { $0.isDone(on: context.date) }.count

        VStack(alignment: .leading, spacing: 8) {
            if s.showsTitle {
                HStack {
                    WLabel(text: context.design.name, style: s)
                    Spacer()
                    if s.showsDetails, !habits.isEmpty {
                        Text("\(doneToday)/\(habits.count)")
                            .font(s.text(11, .semibold).monospacedDigit())
                            .foregroundStyle(s.accent)
                    }
                }
            }
            if habits.isEmpty {
                WidgetMessage(symbol: "repeat", title: tr("Aucune habitude"), message: tr("Crée-les dans Ardane"), style: s)
            } else {
                bands(Array(habits.prefix(limit)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func bands(_ habits: [Habit]) -> some View {
        GeometryReader { proxy in
            let spacing: CGFloat = context.isLarge ? 10 : 7
            let count = CGFloat(max(1, habits.count))
            let bandHeight = (proxy.size.height - (count - 1) * spacing) / count
            let gridHeight = bandHeight - Self.headerHeight - Self.headerGap
            let layout = HabitHeatmap.layout(width: proxy.size.width, height: gridHeight)
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(habits) { habit in
                    band(habit, layout: layout)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    /// The habit's color; without colors (« Clair », « Teinté »), the style's.
    private func habitColor(_ habit: Habit) -> Color {
        context.style.isAccented ? context.style.accent : Color(hex: habit.colorHex)
    }

    private var roundness: CGFloat {
        switch context.style.options.shape {
        case .square: 0.08
        case .capsule: 0.5
        default: 0.26
        }
    }

    private func band(_ habit: Habit, layout: (rows: Int, columns: Int)) -> some View {
        let s = context.style
        let color = habitColor(habit)
        let cells = HabitHeatmap.cells(for: habit, layout: layout, asOf: context.date)
        // Done in full, not done faint: no text sits on a cell, so without colors the style's track does.
        return VStack(alignment: .leading, spacing: Self.headerGap) {
            header(habit)
            HabitHeatmapGrid(columns: cells, doneColor: color, emptyColor: s.isAccented ? s.track : color.opacity(0.16), roundness: roundness)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ habit: Habit) -> some View {
        let s = context.style
        let streak = habit.streak(asOf: context.date)
        let rate = HabitHeatmap.rate(of: habit, asOf: context.date)
        return HStack(spacing: 4) {
            checkButton(habit)
            Text(habit.name)
                .font(s.text(12, .semibold))
                .foregroundStyle(s.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            if s.showsDetails, streak > 0, !context.isSmall {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill").font(.system(size: 8, weight: .semibold))
                    Text(Fmt.number(streak)).font(s.text(11, .semibold).monospacedDigit())
                }
                .foregroundStyle(s.isAccented ? s.secondary : habitColor(habit))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(tr("Série de \(Fmt.plural(streak, tr("jour"), tr("jours")))")))
            }
            if s.showsDetails, let rate {
                Text(Fmt.percent(rate))
                    .font(s.text(11, .semibold).monospacedDigit())
                    .foregroundStyle(s.secondary)
                    .lineLimit(1)
                    .accessibilityLabel(Text("\(tr("Régularité")) : \(Fmt.percent(rate))"))
            }
        }
        .padding(.trailing, 6)
        .frame(height: Self.headerHeight)
        .background { RoundedRectangle(cornerRadius: s.radius(6), style: .continuous).fill(s.panel) }
    }

    /// The check of today: a filled disc when done, a ring when to do. It is the widget's button (its intent
    /// toggles today); the touch area is wider than the disc.
    private func checkButton(_ habit: Habit) -> some View {
        let s = context.style
        let done = habit.isDone(on: context.date)
        let color = habitColor(habit)
        return IntentButton(intent: ToggleHabitIntent(habitID: habit.id), isEnabled: context.isInteractive) {
            ZStack {
                // Without colors a filled disc would be a solid white shape hiding its check: lit and outlined instead.
                if done {
                    Circle().textBackdrop(color, isAccented: s.isAccented, isProminent: true)
                } else {
                    Circle().strokeBorder(color.opacity(AccentedStyle.pendingRingOpacity(isMonochrome: s.isAccented)),
                                          lineWidth: AccentedStyle.pendingRingWidth(isMonochrome: s.isAccented))
                }
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(done ? Color.white : color.opacity(s.isAccented ? AccentedStyle.secondaryOpacity : 0.45))
            }
            .frame(width: 15, height: 15)
            .frame(width: 26, height: Self.headerHeight)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("\(habit.name), \(done ? tr("fait") : tr("à faire"))"))
    }
}

// MARK: - Focus

struct FocusWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let focus = context.payload.content.focus

        if focus.isRunning(at: context.date), let end = focus.endDate {
            let start = focus.startDate ?? end.addingTimeInterval(-Double(focus.lastDurationMinutes) * 60)
            let range = start...max(end, start.addingTimeInterval(1))
            VStack(alignment: s.horizontalAlignment, spacing: 6) {
                HStack {
                    WLabel(text: tr("Focus"), style: s, color: s.accent)
                    Spacer()
                    if !context.isSmall {
                        Text(tr("Fin à \(Fmt.time(end, uses24Hour: context.settings.uses24HourClock))"))
                            .font(s.text(11))
                            .foregroundStyle(s.secondary)
                    }
                }
                Spacer(minLength: 0)
                Text(timerInterval: range, countsDown: true)
                    .font(s.number(context.isSmall ? 40 : 52))
                    .foregroundStyle(s.numberColor)
                    .multilineTextAlignment(s.textAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .widgetAccentable()
                ProgressView(timerInterval: range, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .progressViewStyle(.linear)
                    .tint(s.accent)
                IntentButton(intent: StopFocusIntent(), isEnabled: context.isInteractive) {
                    Label(tr("Arrêter"), systemImage: "stop.fill")
                        .font(s.text(12, .semibold))
                        .foregroundStyle(s.secondary)
                        .padding(.top, 2)
                }
            }
            .widgetFrame(s)
        } else {
            let finished = focus.hasJustFinished(at: context.date)
            VStack(alignment: .leading, spacing: 8) {
                WLabel(text: tr("Focus"), style: s, color: s.accent)
                Text(finished ? tr("Session terminée") : tr("Prêt à te concentrer ?"))
                    .font(s.text(context.isSmall ? 15 : 17, s.titleWeight))
                    .foregroundStyle(s.primary)
                    .lineLimit(2)
                if !context.isSmall, s.showsDetails {
                    Text(finished ? tr("Prends une vraie pause avant la suivante.") : tr("Lance une session, le minuteur défile ici."))
                        .font(s.text(12))
                        .foregroundStyle(s.secondary)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ForEach(context.isSmall ? [25, 50] : [15, 25, 50], id: \.self) { minutes in
                        IntentButton(intent: StartFocusIntent(minutes: minutes), isEnabled: context.isInteractive) {
                            Text(tr("\(minutes) min"))
                                .font(s.text(12, .semibold))
                                .foregroundStyle(s.onAccent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background { Capsule().textBackdrop(s.accent, isAccented: s.isAccented, isProminent: true) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Up next (calendar)

struct UpNextWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        switch context.payload.events {
        case .needsAccess:
            WidgetMessage(symbol: "calendar.badge.exclamationmark", title: tr("Accès au calendrier"), message: tr("Touche pour l'autoriser dans Ardane"), style: s)
        case let .ready(events):
            if events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    WLabel(text: tr("À venir"), style: s, color: s.accent)
                    Spacer(minLength: 0)
                    Text(tr("Rien de prévu"))
                        .font(s.text(17, s.titleWeight))
                        .foregroundStyle(s.primary)
                    Text(tr("pour les prochaines 48 h"))
                        .font(s.text(12))
                        .foregroundStyle(s.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if context.isSmall {
                nextEvent(events[0])
            } else {
                list(events)
            }
        }
    }

    private func timeRange(_ event: EventSnapshot) -> String {
        if event.isAllDay { return tr("Toute la journée") }
        let uses24 = context.settings.uses24HourClock
        return "\(Fmt.time(event.start, uses24Hour: uses24)) – \(Fmt.time(event.end, uses24Hour: uses24))"
    }

    private func dayLabel(_ date: Date) -> String {
        let delta = DateMath.daysBetween(context.date, date)
        switch delta {
        case ...0: return tr("Aujourd'hui")
        case 1: return tr("Demain")
        default: return Fmt.weekday(date)
        }
    }

    private func nextEvent(_ event: EventSnapshot) -> some View {
        let s = context.style
        return VStack(alignment: .leading, spacing: 4) {
            WLabel(text: event.isOngoing(at: context.date) ? tr("En cours") : dayLabel(event.start), style: s, color: s.accent)
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: event.colorHex)).frame(width: 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(s.text(16, s.titleWeight))
                        .foregroundStyle(s.primary)
                        .lineLimit(3)
                    Text(timeRange(event))
                        .font(s.text(12))
                        .foregroundStyle(s.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            if s.showsDetails, !event.isAllDay, event.start > context.date {
                HStack(spacing: 3) {
                    Text(tr("Dans"))
                    Text(event.start, style: .relative)
                }
                .font(s.text(12, .semibold))
                .foregroundStyle(s.accent)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func list(_ events: [EventSnapshot]) -> some View {
        let s = context.style
        let limit = context.isMedium ? 3 : 7
        let shown = Array(events.prefix(limit))
        return VStack(alignment: .leading, spacing: context.isLarge ? 10 : 7) {
            WLabel(text: tr("À venir"), style: s, color: s.accent)
            ForEach(Array(shown.enumerated()), id: \.element.id) { pair in
                let event = pair.element
                let previous = pair.offset > 0 ? shown[pair.offset - 1] : nil
                if context.isLarge, previous == nil || !DateMath.isSameDay(previous!.start, event.start) {
                    Text(dayLabel(event.start))
                        .font(s.text(12, .semibold))
                        .foregroundStyle(s.secondary)
                        .padding(.top, pair.offset > 0 ? 4 : 0)
                }
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: event.colorHex)).frame(width: 4, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(s.text(14, .semibold))
                            .foregroundStyle(s.primary)
                            .lineLimit(1)
                        Text(context.isLarge ? timeRange(event) : "\(dayLabel(event.start)) · \(timeRange(event))")
                            .font(s.text(11))
                            .foregroundStyle(s.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if event.isOngoing(at: context.date) {
                        Text(tr("En cours"))
                            .font(s.text(10, .semibold))
                            .foregroundStyle(s.onAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background { Capsule().textBackdrop(s.accent, isAccented: s.isAccented, isProminent: true) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Note

struct NoteWidgetView: View {
    let context: RenderContext

    var body: some View {
        let s = context.style
        let title = context.options.noteTitle.trimmed
        let text = context.options.noteText.trimmed
        let size: CGFloat = context.isSmall ? 16 : context.isMedium ? 19 : 26

        HStack(alignment: .top, spacing: 10) {
            if s.alignment == .leading, s.showsDetails {
                Capsule().fill(s.accent).frame(width: 3)
            }
            VStack(alignment: s.horizontalAlignment, spacing: 6) {
                if s.showsTitle, !title.isEmpty {
                    WLabel(text: title, style: s, color: s.accent)
                }
                Text(text.isEmpty ? tr("Écris ta note dans Ardane") : text)
                    .font(s.text(size, s.titleWeight))
                    .foregroundStyle(text.isEmpty ? s.secondary : s.primary)
                    .multilineTextAlignment(s.textAlignment)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: s.alignment == .center ? .center : .leading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
