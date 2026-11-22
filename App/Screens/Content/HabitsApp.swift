import SwiftUI

/// The figures of the hybrid Habits page (refonte du 2026-11-17): the split « À faire » / « Faites », the week of
/// the habits, the global regularity, the days when every habit was done and the rate of each of the last weeks.
/// Pure functions, added beside the existing calculations (streaks, `regularity`, the heatmap), none of which changes.
enum HabitsHybrid {
    /// The habits of a day split in two groups, each keeping the person's order.
    static func split(_ habits: [Habit], on day: Date) -> (todo: [Habit], done: [Habit]) {
        (habits.filter { !$0.isDone(on: day) }, habits.filter { $0.isDone(on: day) })
    }

    /// The longest streak in progress among the habits (what the card of Mon quotidien shows).
    static func longestStreak(_ habits: [Habit], asOf date: Date = Date()) -> Int {
        habits.map { $0.streak(asOf: date) }.max() ?? 0
    }

    /// The first day a habit was done (nothing is counted before it), nil without any day done.
    static func firstDay(_ habit: Habit) -> Date? {
        habit.completedDays.compactMap(DateMath.date(fromKey:)).min()
    }

    /// The seven days of the week containing `date`, in the calendar's order: `true` = done, `false` = not done,
    /// `nil` = a day still to come after `now`.
    static func weekCells(for habit: Habit, weekOf date: Date, asOf now: Date = Date()) -> [Bool?] {
        let today = DateMath.startOfDay(now)
        return DateMath.week(containing: date).map { day in day <= today ? habit.isDone(on: day) : nil }
    }

    /// The checks of the current week out of the days gone by times the habits (the calculation of the
    /// « Semaine d'habitudes » widget: the first six habits).
    static func weekTotals(_ habits: [Habit], asOf now: Date = Date()) -> (done: Int, total: Int) {
        var done = 0
        var total = 0
        for habit in habits.prefix(6) {
            let cells = weekCells(for: habit, weekOf: now, asOf: now).compactMap { $0 }
            total += cells.count
            done += cells.filter { $0 }.count
        }
        return (done, total)
    }

    /// The regularity of all the habits together over the last `days` days: the sum of the days done over the sum
    /// of the days counted by `Habit.regularity`. Nil while no habit has a day done.
    static func overallRate(_ habits: [Habit], days: Int = HabitHeatmap.rateDays, asOf now: Date = Date()) -> Double? {
        var done = 0
        var total = 0
        for habit in habits {
            guard let counts = habit.regularity(days: days, asOf: now) else { continue }
            done += counts.done
            total += counts.total
        }
        return total > 0 ? Double(done) / Double(total) : nil
    }

    /// The days of the last `days` days when every habit already started was done, out of the days with at least
    /// one habit started.
    static func completeDays(_ habits: [Habit], days: Int = 30, asOf now: Date = Date()) -> (complete: Int, counted: Int) {
        let today = DateMath.startOfDay(now)
        let starts = habits.map { (habit: $0, first: firstDay($0)) }
        var complete = 0
        var counted = 0
        for offset in 0..<max(0, days) {
            guard let day = DateMath.calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let active = starts.filter { entry in entry.first.map { $0 <= day } ?? false }
            guard !active.isEmpty else { continue }
            counted += 1
            if active.allSatisfy({ $0.habit.isDone(on: day) }) { complete += 1 }
        }
        return (complete, counted)
    }

    struct WeekRate: Equatable {
        let monday: Date
        /// The checks of the week out of the days gone by times the habits started; nil when nothing was counted.
        let rate: Double?
        let isCurrent: Bool
    }

    /// The rate of each of the last `weeks` weeks, oldest first, the current week last.
    static func weeklyRates(_ habits: [Habit], weeks: Int = 8, asOf now: Date = Date()) -> [WeekRate] {
        guard weeks > 0, let thisWeek = DateMath.week(containing: now).first else { return [] }
        let today = DateMath.startOfDay(now)
        let starts = habits.map { (habit: $0, first: firstDay($0)) }
        return (0..<weeks).compactMap { index in
            let offset = index - (weeks - 1)
            guard let monday = DateMath.calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeek) else { return nil }
            var done = 0
            var possible = 0
            for day in DateMath.week(containing: monday) where day <= today {
                for entry in starts {
                    guard let first = entry.first, first <= day else { continue }
                    possible += 1
                    if entry.habit.isDone(on: day) { done += 1 }
                }
            }
            return WeekRate(monday: monday, rate: possible > 0 ? Double(done) / Double(possible) : nil, isCurrent: offset == 0)
        }
    }

    /// The days of the month of `date` on which the habit was done.
    static func doneCount(_ habit: Habit, inMonthOf date: Date) -> Int {
        DateMath.monthGrid(for: date).compactMap { $0 }.filter { habit.isDone(on: $0) }.count
    }
}

/// The Habits mini-app page, direction « Hybride »: the day selector and the figure « 3/5 » on the band, the habits
/// still to do and the ones done (a round to check, a touch on the name opens its detail), the week (Premium), then
/// the doors to « Bilan », « Mes habitudes » and « Mes paramètres », and the action « Ajouter une habitude ».
/// Reached from Mon quotidien and from Planning (`MiniAppPage.planningHabits`).
struct HabitsApp: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @State private var creating = false
    @State private var paywall: PaywallContext?
    /// The day the habits are checked for: a habit forgotten yesterday can still be checked.
    @State private var day = Date()
    @State private var quickName = ""

    static let accentHex = "7FA33A"
    private var accentHex: String { Self.accentHex }

    /// The editor opens while the free plan has room (`canAddHabit`, the rule of `addHabit`); else the paywall.
    private func startCreating() {
        if model.canAddHabit { creating = true } else { paywall = .habitLimit }
    }

    var body: some View {
        let habits = model.content.habits
        let groups = HabitsHybrid.split(habits, on: day)
        MiniAppScaffold(colorHex: accentHex, action: habits.isEmpty ? nil : addAction) {
            if !habits.isEmpty {
                DaySwitcher(day: $day, colorHex: accentHex)
                hero(habits: habits, done: groups.done.count)
            }
        } sheet: {
            if habits.isEmpty {
                firstOpening
            } else {
                if !groups.todo.isEmpty { group(title: tr("À faire"), habits: groups.todo) }
                if !groups.done.isEmpty { group(title: tr("Faites"), habits: groups.done) }
                weekCard(habits)
                doors(habits)
                if !model.isPremium {
                    MiniFootnote(text: tr("\(min(habits.count, AppModel.freeHabitLimit)) sur \(AppModel.freeHabitLimit) habitudes en version gratuite."))
                }
                MiniAppSettingsDoor()
            }
        }
        .navigationTitle(tr("Habitudes"))
        .miniAppTour(id: MiniAppTourContent.habitsID)
        .onAppear {
            // Habits is not a `MiniApp` (no open counter): someone who already has habits is an existing user.
            MiniAppTourController.shared.begin(MiniAppTourContent.habitsID, priorOpens: 0, hasData: !model.content.habits.isEmpty)
        }
        .sheet(isPresented: $creating) {
            HabitEditor(habit: Habit(name: "", symbol: HabitEditor.symbols[0], colorHex: Palette.freeAccents[0].hex), isNew: true)
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
    }

    private var addAction: MiniFloatingAction {
        MiniFloatingAction(title: tr("Ajouter une habitude"), symbol: "plus", colorHex: accentHex, identifier: "habits-add") {
            startCreating()
        }
    }

    // MARK: The figure of the day

    private func hero(habits: [Habit], done: Int) -> some View {
        let streak = HabitsHybrid.longestStreak(habits)
        let isToday = DateMath.isSameDay(day, Date())
        return MiniHero(
            label: isToday ? tr("faites aujourd'hui") : tr("faites ce jour-là"),
            value: "\(done)/\(habits.count)",
            caption: streak > 0 ? tr("Série de \(Fmt.plural(streak, tr("jour"), tr("jours")))") : nil
        )
        .accessibilityIdentifier("habits-hero")
    }

    // MARK: The groups

    private func group(title: String, habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: title, detail: "\(habits.count)")
            MiniRowsCard {
                ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                    if index > 0 { MiniDivider() }
                    HabitCheckRow(habit: habit, day: day) {
                        Haptics.tap()
                        model.updateContent { $0.toggleHabit(habit.id, on: day) }
                    }
                    .tourAnchor(MiniAppTourContent.habitsID, 1, enabled: index == 0)
                }
            }
        }
    }

    // MARK: The week (Premium)

    @ViewBuilder
    private func weekCard(_ habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isPremium {
                let totals = HabitsHybrid.weekTotals(habits)
                MiniSectionTitle(title: tr("Cette semaine"), detail: totals.total > 0 ? tr("\(totals.done) sur \(totals.total)") : nil)
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Spacer(minLength: 0)
                        ForEach(Array(DateMath.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                        }
                    }
                    .accessibilityHidden(true)
                    ForEach(Array(habits.prefix(6))) { habit in
                        HabitWeekLine(habit: habit)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .miniCard()
                .accessibilityIdentifier("habits-week")
            } else {
                MiniSectionTitle(title: tr("Cette semaine"))
                PremiumLockCard(symbol: "calendar", title: tr("La semaine est dans Premium"),
                                message: tr("Tes habitudes sur les sept jours de la semaine, d'un coup d'œil. Tes jours cochés restent enregistrés."))
            }
        }
    }

    // MARK: The doors

    private func doors(_ habits: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Aller plus loin"))
            MiniRowsCard {
                NavigationLink { HabitsReportView() } label: {
                    MiniRow(symbol: "chart.bar.fill", colorHex: accentHex, title: tr("Bilan"), detail: tr("Régularité, semaines, jours complets"))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("habits-report")
                MiniDivider()
                NavigationLink { HabitsView() } label: {
                    MiniRow(symbol: "repeat", colorHex: accentHex, title: tr("Gérer mes habitudes"), detail: Fmt.plural(habits.count, tr("habitude"), tr("habitudes")))
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("habits-manage")
            }
        }
    }

    // MARK: First opening

    private var firstOpening: some View {
        VStack(alignment: .leading, spacing: 22) {
            EmptyStateView(symbol: "repeat", title: tr("Tes habitudes"), message: tr("Lire, marcher, méditer… Coche-les chaque jour et regarde ta série grandir."), actionTitle: tr("Ajouter une habitude")) {
                startCreating()
            }
            .card()
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Une habitude à suivre"))
                HStack(spacing: 10) {
                    TextField(tr("Ex. : méditer, lire, marcher"), text: $quickName)
                        .submitLabel(.done)
                        .onSubmit(quickAdd)
                        .accessibilityIdentifier("habits-quick-add")
                    Button(action: quickAdd) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .buttonStyle(.pressable)
                    .disabled(quickName.trimmed.isEmpty)
                    .accessibilityLabel(Text(tr("Ajouter une habitude")))
                }
                .padding(14)
                .miniCard()
                .tourAnchor(MiniAppTourContent.habitsID, 0)
            }
        }
    }

    /// A habit by its name alone: the icon and the color are set (the same ones as the quick add of « À remplir »).
    private func quickAdd() {
        let name = quickName.trimmed
        guard !name.isEmpty else { return }
        if model.addHabit(Habit(name: name, symbol: "checkmark.circle", colorHex: accentHex)) {
            quickName = ""
        } else {
            paywall = .habitLimit
        }
    }
}

/// The settings door of the page, last of the page like in the other mini-apps.
private struct MiniAppSettingsDoor: View {
    var body: some View {
        MiniRowsCard {
            NavigationLink { HabitsSettingsView() } label: {
                MiniRow(symbol: "gearshape.fill", colorHex: HabitsApp.accentHex, title: tr("Mes paramètres"), detail: tr("Rappels et notifications"))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("habits-settings")
        }
    }
}

/// One habit of the page: its round to check (44 points), then its name, streak and regularity; a touch on the
/// name opens the detail of the habit.
private struct HabitCheckRow: View {
    let habit: Habit
    let day: Date
    let onToggle: () -> Void
    @Environment(\.appStyle) private var style

    var body: some View {
        let color = style.cristal.category(habit.colorHex)
        let done = habit.isDone(on: day)
        let streak = habit.streak()
        let rate = HabitHeatmap.rate(of: habit)
        HStack(spacing: 2) {
            Button(action: onToggle) {
                ZStack {
                    Circle().fill(done ? style.cristal.strong(habit.colorHex) : color.opacity(0.14))
                    Circle().strokeBorder(color.opacity(done ? 0 : 0.7), lineWidth: 1.5)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(done ? style.onAccent : color.opacity(0.5))
                }
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(done ? tr("Marquer \(habit.name) comme non fait") : tr("Valider \(habit.name)")))

            NavigationLink { HabitDetailView(habitID: habit.id) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: habit.symbol)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(color)
                                .accessibilityHidden(true)
                            Text(habit.name)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        Text(streak > 0 ? tr("Série de \(Fmt.plural(streak, tr("jour"), tr("jours")))") : tr("Pas encore de série"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if let rate {
                        Text(Fmt.percent(rate))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("\(tr("Régularité")) : \(Fmt.percent(rate))"))
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
        }
    }
}

/// A habit and its seven days of the week (a square a day, full in its color when done).
private struct HabitWeekLine: View {
    let habit: Habit
    @Environment(\.appStyle) private var style

    var body: some View {
        let color = style.cristal.category(habit.colorHex)
        let cells = HabitsHybrid.weekCells(for: habit, weekOf: Date())
        HStack(spacing: 4) {
            Image(systemName: habit.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(habit.name)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 6)
            ForEach(Array(cells.enumerated()), id: \.offset) { _, state in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(state == true ? style.cristal.strong(habit.colorHex) : color.opacity(state == nil ? 0.05 : 0.16))
                    .frame(width: 22, height: 22)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(habit.name) : \(cells.filter { $0 == true }.count)/\(cells.compactMap { $0 }.count)"))
    }
}

// MARK: - Detail of a habit

/// A habit explained: the check of today, its streak, its regularity, the month in a calendar and the weeks in a grid.
/// « Meilleure série » and « 90 jours » are Premium, like the « Régularité » list they come from.
struct HabitDetailView: View {
    let habitID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Habit?

    var body: some View {
        if let habit = model.content.habits.first(where: { $0.id == habitID }) {
            content(habit)
        } else {
            // Deleted from the editor: nothing left to show, so the page closes itself.
            Color.clear
                .accessibilityHidden(true)
                .onAppear { dismiss() }
        }
    }

    private func content(_ habit: Habit) -> some View {
        let color = style.cristal.category(habit.colorHex)
        let strong = style.cristal.strong(habit.colorHex)
        let today = Date()
        let done = habit.isDone(on: today)
        let streak = habit.streak()
        let month = HabitsHybrid.doneCount(habit, inMonthOf: today)
        let weeks = HabitHeatmap.weeks(for: habit, columns: sizeClass == .regular ? 52 : 26)
        return MiniAppScroll {
            // Today's check.
            HStack(spacing: 6) {
                Button {
                    Haptics.tap()
                    model.updateContent { $0.toggleHabit(habit.id, on: today) }
                } label: {
                    ZStack {
                        Circle().fill(done ? strong : color.opacity(0.14))
                        Circle().strokeBorder(color.opacity(done ? 0 : 0.7), lineWidth: 1.5)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(done ? style.onAccent : color.opacity(0.5))
                    }
                    .frame(width: 30, height: 30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(done ? tr("Marquer \(habit.name) comme non fait") : tr("Valider \(habit.name)")))
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? tr("Faite aujourd'hui") : tr("À faire aujourd'hui"))
                        .font(.headline)
                    Text(streak > 0 ? tr("Série de \(Fmt.plural(streak, tr("jour"), tr("jours")))") : tr("Pas encore de série"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .miniCard()

            // The figures. Streak and 30 days are free; the best streak and 90 days are Premium.
            let thirty = HabitHeatmap.rate(of: habit, days: 30)
            let ninety = HabitHeatmap.rate(of: habit, days: 90) ?? thirty
            let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: columns, spacing: 10) {
                MiniStat(title: tr("Série"), value: "\(streak)", unit: tr("jours"), colorHex: habit.colorHex)
                MiniStat(title: tr("Meilleure série"), value: model.isPremium ? "\(habit.bestStreak)" : "—",
                         unit: model.isPremium ? tr("jours") : tr("Premium"), colorHex: habit.colorHex)
                MiniStat(title: tr("30 jours"), value: thirty.map { Fmt.percent($0) } ?? "—", colorHex: habit.colorHex)
                MiniStat(title: tr("90 jours"), value: model.isPremium ? (ninety.map { Fmt.percent($0) } ?? "—") : "—",
                         unit: model.isPremium ? nil : tr("Premium"), colorHex: habit.colorHex)
            }

            // The month.
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: Fmt.monthYear(today), detail: Fmt.plural(month, tr("jour fait"), tr("jours faits")))
                monthCalendar(habit, today: today)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .miniCard()
            }

            // The weeks.
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("26 dernières semaines"))
                HabitHeatmapGrid(columns: weeks, doneColor: color, emptyColor: color.opacity(0.16))
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .miniCard()
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(tr("Modifier")) { editing = habit }
                    .accessibilityIdentifier("habit-edit")
            }
        }
        .sheet(item: $editing) { HabitEditor(habit: $0, isNew: false) }
    }

    /// The days of the current month: a round per day, full when done, the days to come faint.
    private func monthCalendar(_ habit: Habit, today: Date) -> some View {
        let cells = DateMath.monthGrid(for: today)
        let rows = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0 + 7, cells.count)]) }
        let color = style.cristal.category(habit.colorHex)
        let strong = style.cristal.strong(habit.colorHex)
        let start = DateMath.startOfDay(today)
        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(DateMath.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, date in
                        if let date {
                            let isDone = habit.isDone(on: date)
                            let future = DateMath.startOfDay(date) > start
                            ZStack {
                                Circle().fill(isDone ? strong : color.opacity(future ? 0.05 : 0.14))
                                Text("\(DateMath.calendar.component(.day, from: date))")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(isDone ? style.onAccent : (future ? Color.secondary.opacity(0.6) : Color.primary))
                            }
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxHeight: 36)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 1)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Fmt.monthYear(today)) : \(Fmt.plural(HabitsHybrid.doneCount(habit, inMonthOf: today), tr("jour fait"), tr("jours faits")))"))
    }
}

// MARK: - Bilan

/// « Bilan » (Premium): the regularity of all the habits, the longest streak, the days when everything was done,
/// the weeks in bars, then the list « Régularité » of each habit (30 and 90 days, best streak).
struct HabitsReportView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appStyle) private var style

    var body: some View {
        let habits = model.content.habits
        MiniAppScroll {
            if !model.isPremium {
                PremiumLockCard(symbol: "chart.bar.doc.horizontal", title: tr("La régularité est dans Premium"),
                                message: tr("Le taux de réussite de chaque habitude sur 30 et 90 jours, et sa plus longue série. Tes jours cochés restent enregistrés."))
            } else if habits.isEmpty {
                EmptyStateView(symbol: "chart.bar", title: tr("Pas encore de bilan"), message: tr("Coche une habitude pour voir ta régularité."))
                    .card()
            } else {
                overview(habits)
                weeks(habits)
                regularity(habits)
            }
        }
        .navigationTitle(tr("Bilan"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func overview(_ habits: [Habit]) -> some View {
        let rate = HabitsHybrid.overallRate(habits)
        let best = habits.map(\.bestStreak).max() ?? 0
        let full = HabitsHybrid.completeDays(habits)
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            MiniStat(title: tr("Régularité · 30 jours"), value: rate.map { Fmt.percent($0) } ?? "—", colorHex: HabitsApp.accentHex)
            MiniStat(title: tr("Série la plus longue"), value: "\(best)", unit: tr("j"), colorHex: HabitsApp.accentHex)
            MiniStat(title: tr("Jours complets"), value: full.counted > 0 ? "\(full.complete)/\(full.counted)" : "—", colorHex: HabitsApp.accentHex)
        }
    }

    /// The last eight weeks, a bar each (the share of the checks), the current week hatched lighter.
    private func weeks(_ habits: [Habit]) -> some View {
        let rates = HabitsHybrid.weeklyRates(habits)
        let strong = style.cristal.strong(HabitsApp.accentHex)
        let track = style.cristal.category(HabitsApp.accentHex).opacity(0.16)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Toutes les habitudes"), detail: tr("par semaine, lundi indiqué"))
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(rates.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(track)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(strong.opacity(week.isCurrent ? 0.6 : 1))
                                .frame(height: 78 * CGFloat(week.rate ?? 0))
                        }
                        .frame(height: 78)
                        Text("\(DateMath.calendar.component(.day, from: week.monday))")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(Fmt.shortDay(week.monday)) : \(week.rate.map { Fmt.percent($0) } ?? "—")"))
                }
            }
            .padding(14)
            .miniCard()
        }
    }

    /// The detailed statistics: how regular each habit is over 30 and 90 days, and its best streak.
    private func regularity(_ habits: [Habit]) -> some View {
        let now = Date()
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Régularité"), detail: tr("30 j · 90 j"))
            MiniRowsCard {
                ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                    if index > 0 { MiniDivider() }
                    MiniRow(symbol: habit.symbol, colorHex: habit.colorHex, title: habit.name,
                            detail: tr("Meilleure série : \(Fmt.plural(habit.bestStreak, tr("jour"), tr("jours")))"),
                            value: regularityText(habit, now: now), showsChevron: false)
                }
            }
            .accessibilityIdentifier("habits-regularity")
            Text(tr("Compté depuis le premier jour coché, sur 30 et 90 jours."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func regularityText(_ habit: Habit, now: Date) -> String {
        guard let month = habit.regularity(days: 30, asOf: now) else { return "—" }
        let quarter = habit.regularity(days: 90, asOf: now) ?? month
        return "\(Fmt.percent(Double(month.done) / Double(max(1, month.total)))) · \(Fmt.percent(Double(quarter.done) / Double(max(1, quarter.total))))"
    }
}

// MARK: - Mes paramètres

/// « Mes paramètres » of Habits: the daily reminder of each habit (a touch opens the habit to change it), and the
/// smart reminders of the habits, with the way to all the others.
struct HabitsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Habit?
    @State private var showsExplainer = false

    var body: some View {
        let habits = model.content.habits
        MiniAppScroll {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Rappels d'habitudes"))
                if habits.isEmpty {
                    Text(tr("Aucune habitude pour l'instant"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    MiniRowsCard {
                        ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                            if index > 0 { MiniDivider() }
                            Button { editing = habit } label: {
                                MiniRow(symbol: habit.symbol, colorHex: habit.colorHex, title: habit.name,
                                        detail: habit.reminderDate == nil ? tr("Aucun rappel") : tr("Rappel quotidien"),
                                        value: habit.reminderDate.map { Fmt.time($0, uses24Hour: model.settings.uses24HourClock) } ?? "—")
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .accessibilityIdentifier("habits-reminders")
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Rappels intelligents"))
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: remindsBinding) {
                        Text(tr("Habitudes")).font(.body.weight(.medium))
                    }
                    .accessibilityIdentifier("habits-smart-toggle")
                    Text(tr("Les habitudes qu'il te reste à faire, ta série, un record battu et le bilan de la semaine."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .miniCard()
                MiniRowsCard {
                    NavigationLink { SmartRemindersView() } label: {
                        MiniRow(symbol: "bell.badge.fill", colorHex: HabitsApp.accentHex, title: tr("Rappels intelligents"))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .navigationTitle(tr("Mes paramètres"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { HabitEditor(habit: $0, isNew: false) }
        .permissionSheet(.notifications, isPresented: $showsExplainer, request: requestNotifications) { _ in
            model.syncReminders()
        }
    }

    /// Turning it on explains and asks for notifications first (once), like the Smart reminders screen.
    private var remindsBinding: Binding<Bool> {
        Binding(
            get: { model.settings.remindsHabits },
            set: { isOn in
                model.updateSettings { $0.remindsHabits = isOn }
                if isOn {
                    Task {
                        if await AppPermission.notifications.requestOrExplain(isPresented: $showsExplainer, request: requestNotifications) != nil {
                            model.syncReminders()
                        }
                    }
                }
            }
        )
    }

    private func requestNotifications() async {
        _ = await NotificationScheduler.requestAuthorization()
    }
}
