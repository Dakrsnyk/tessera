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
                        Text(openCount == 0 ? "Terminé" : "\(openCount) à faire")
                            .font(s.text(11, .semibold))
                            .foregroundStyle(s.accent)
                    }
                }
            }
            if content.tasks.isEmpty {
                WidgetMessage(symbol: "plus.circle", title: "Aucune tâche", message: "Ajoute-les dans Tessera", style: s)
            } else if visible.isEmpty {
                WidgetMessage(symbol: "checkmark.circle", title: "Tout est fait", message: context.isSmall ? nil : "Belle journée.", style: s)
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
                    Text(hiddenOpen > 0 ? "+ \(hiddenOpen) à faire" : "+ \(Fmt.plural(hidden.count, "terminée", "terminées"))")
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

struct HabitsWidgetView: View {
    let context: RenderContext

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
                WidgetMessage(symbol: "repeat", title: "Aucune habitude", message: "Crée-les dans Tessera", style: s)
            } else if context.isSmall {
                smallGrid(Array(habits.prefix(4)))
            } else {
                let limit = context.isMedium ? 3 : 7
                VStack(spacing: context.isLarge ? 12 : 8) {
                    ForEach(habits.prefix(limit)) { habit in
                        habitRow(habit)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func smallGrid(_ habits: [Habit]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(habits) { habit in
                toggleButton(habit, size: 50)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func toggleButton(_ habit: Habit, size: CGFloat) -> some View {
        let s = context.style
        let done = habit.isDone(on: context.date)
        let color = Color(hex: habit.colorHex)
        return IntentButton(intent: ToggleHabitIntent(habitID: habit.id), isEnabled: context.isInteractive) {
            ZStack {
                Circle().fill(done ? color : s.panel)
                Circle().strokeBorder(done ? Color.clear : color.opacity(0.7), lineWidth: 2)
                Image(systemName: habit.symbol)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(done ? .white : color)
            }
            .frame(width: size, height: size)
        }
        .accessibilityLabel(Text("\(habit.name), \(done ? "fait" : "à faire")"))
    }

    private func habitRow(_ habit: Habit) -> some View {
        let s = context.style
        let week = DateMath.week(containing: context.date)
        let color = Color(hex: habit.colorHex)
        let streak = habit.streak(asOf: context.date)
        return HStack(spacing: 10) {
            toggleButton(habit, size: context.isLarge ? 34 : 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(habit.name)
                    .font(s.text(14, .semibold))
                    .foregroundStyle(s.primary)
                    .lineLimit(1)
                if s.showsDetails {
                    Text(streak > 0 ? "Série de \(streak) j" : "Pas encore de série")
                        .font(s.text(11))
                        .foregroundStyle(s.secondary)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                ForEach(week, id: \.self) { day in
                    let done = habit.isDone(on: day)
                    let isToday = DateMath.isSameDay(day, context.date)
                    Circle()
                        .fill(done ? color : s.track)
                        .overlay {
                            if isToday { Circle().strokeBorder(s.primary.opacity(0.6), lineWidth: 1.2) }
                        }
                        .frame(width: 9, height: 9)
                }
            }
        }
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
                    WLabel(text: "Focus", style: s, color: s.accent)
                    Spacer()
                    if !context.isSmall {
                        Text("Fin à \(Fmt.time(end, uses24Hour: context.settings.uses24HourClock))")
                            .font(s.text(11))
                            .foregroundStyle(s.secondary)
                    }
                }
                Spacer(minLength: 0)
                Text(timerInterval: range, countsDown: true)
                    .font(s.number(context.isSmall ? 40 : 52))
                    .foregroundStyle(s.primary)
                    .multilineTextAlignment(s.textAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                ProgressView(timerInterval: range, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .progressViewStyle(.linear)
                    .tint(s.accent)
                IntentButton(intent: StopFocusIntent(), isEnabled: context.isInteractive) {
                    Label("Arrêter", systemImage: "stop.fill")
                        .font(s.text(12, .semibold))
                        .foregroundStyle(s.secondary)
                        .padding(.top, 2)
                }
            }
            .widgetFrame(s)
        } else {
            let finished = focus.hasJustFinished(at: context.date)
            VStack(alignment: .leading, spacing: 8) {
                WLabel(text: "Focus", style: s, color: s.accent)
                Text(finished ? "Session terminée" : "Prêt à te concentrer ?")
                    .font(s.text(context.isSmall ? 15 : 17, s.titleWeight))
                    .foregroundStyle(s.primary)
                    .lineLimit(2)
                if !context.isSmall, s.showsDetails {
                    Text(finished ? "Prends une vraie pause avant la suivante." : "Lance une session, le minuteur défile ici.")
                        .font(s.text(12))
                        .foregroundStyle(s.secondary)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    ForEach(context.isSmall ? [25, 50] : [15, 25, 50], id: \.self) { minutes in
                        IntentButton(intent: StartFocusIntent(minutes: minutes), isEnabled: context.isInteractive) {
                            Text("\(minutes) min")
                                .font(s.text(12, .semibold))
                                .foregroundStyle(s.onAccent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(s.accent, in: Capsule())
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
            WidgetMessage(symbol: "calendar.badge.exclamationmark", title: "Accès au calendrier", message: "Touche pour l'autoriser dans Tessera", style: s)
        case let .ready(events):
            if events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    WLabel(text: "À venir", style: s, color: s.accent)
                    Spacer(minLength: 0)
                    Text("Rien de prévu")
                        .font(s.text(17, s.titleWeight))
                        .foregroundStyle(s.primary)
                    Text("pour les prochaines 48 h")
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
        if event.isAllDay { return "Toute la journée" }
        let uses24 = context.settings.uses24HourClock
        return "\(Fmt.time(event.start, uses24Hour: uses24)) – \(Fmt.time(event.end, uses24Hour: uses24))"
    }

    private func dayLabel(_ date: Date) -> String {
        let delta = DateMath.daysBetween(context.date, date)
        switch delta {
        case ...0: return "Aujourd'hui"
        case 1: return "Demain"
        default: return Fmt.weekday(date)
        }
    }

    private func nextEvent(_ event: EventSnapshot) -> some View {
        let s = context.style
        return VStack(alignment: .leading, spacing: 4) {
            WLabel(text: event.isOngoing(at: context.date) ? "En cours" : dayLabel(event.start), style: s, color: s.accent)
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
                    Text("Dans")
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
            WLabel(text: "À venir", style: s, color: s.accent)
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
                        Text("En cours")
                            .font(s.text(10, .semibold))
                            .foregroundStyle(s.onAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(s.accent, in: Capsule())
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
                Text(text.isEmpty ? "Écris ta note dans Tessera" : text)
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
