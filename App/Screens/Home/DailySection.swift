import SwiftUI

/// Where a tap on Home leads, inside the Home tab.
enum HomeRoute: Hashable {
    case space(Space)
    case info
    case infoArea(InfoArea)
    /// A mini-app (Nutrition, Fitness…), and one of its detailed pages.
    case app(MiniApp)
    case page(MiniAppPage)
}

/// « Mon Quotidien »: the figures of the day as a dashboard of tiles, only for what the person
/// entered, ordered by what matters now (see `DailyBrief`).
struct DailySection: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    private var steps: StepCounter { .shared }

    var body: some View {
        let now = Date()
        let tiles = DailyBrief.tiles(DailyBrief.Input(model: model, now: now, steps: steps.status == .allowed ? steps.stepsToday : nil))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Mon Quotidien").uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.accentColor)
                    Text(DailyBrief.Moment(now).title)
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                NavigationLink(value: HomeRoute.info) {
                    Text(tr("Mes données"))
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("daily-data")
            }
            if tiles.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(DailyBrief.rows(tiles).enumerated()), id: \.offset) { pair in
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(pair.element) { tile in
                                DailyTileView(tile: tile)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-section")
        .task { await steps.refresh() }
    }

    /// Nothing entered yet: what « Mon Quotidien » will show, and where to start. No fake figure.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("Ton quotidien apparaîtra ici"), systemImage: "sun.max")
                .font(.headline)
            Text(tr("Tes repas, ta séance, tes cours, tes habitudes… Renseigne ce qui te concerne : Tessera réunit chaque jour ce qui compte."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink(value: HomeRoute.info) {
                Text(tr("Ajouter mes informations"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("daily-empty-add")
        }
        .card()
    }
}

// MARK: - Tiles

private struct DailyTileView: View {
    let tile: DailyBrief.Tile
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        switch tile {
        case let .nutrition(nutrition):
            DailyPager(id: "nutrition", titles: [tr("Aujourd'hui"), tr("Repas"), tr("7 jours")], accentHex: "F08A24") { page in
                switch page {
                case 1: NutritionMealsTile(nutrition: nutrition)
                case 2: NutritionWeekTile(nutrition: nutrition)
                default: NutritionDayTile(nutrition: nutrition)
                }
            }
        case let .workout(workout):
            DailyPager(id: "workout", titles: [tr("Séance"), tr("Semaine")], accentHex: "E5484D") { page in
                if page == 1 { WorkoutWeekTile() } else { WorkoutDayTile(workout: workout) }
            }
        case let .classes(title, items): TimedListTile(title: title, symbol: "graduationcap.fill", colorHex: "D6409F", items: items, space: .student)
        case let .agenda(title, items): TimedListTile(title: title, symbol: "calendar", colorHex: "3366FF", items: items, space: .productivity)
        case let .habits(done, items): HabitsDayTile(done: done, items: items)
        case let .water(glasses, goal):
            DailyPager(id: "water", titles: [tr("Aujourd'hui"), tr("7 jours")], accentHex: "3A8DDE") { page in
                if page == 1 { WaterWeekTile(goal: goal) } else { WaterDayTile(glasses: glasses, goal: goal) }
            }
        case let .steps(steps, goal):
            DailyPager(id: "steps", titles: [tr("Aujourd'hui"), tr("7 jours")], accentHex: "12A4B5") { page in
                if page == 1 { StepsWeekTile(goal: goal) } else { StepsDayTile(steps: steps, goal: goal) }
            }
        case let .budget(spent, perDay): BudgetDayTile(spent: spent, perDayLeft: perDay)
        case let .weather(snapshot):
            DailyPager(id: "weather", titles: [tr("Maintenant"), tr("Prochaines heures")], accentHex: "3A8DDE") { page in
                if page == 1 { WeatherHoursTile(weather: snapshot) } else { WeatherDayTile(weather: snapshot) }
            }
        case let .reminders(items): RemindersDayTile(items: items)
        case let .priorities(items): PrioritiesDayTile(items: items)
        case let .invite(area): InviteDayTile(area: area)
        }
    }
}

/// The frame of a tile: its label on top, the content below, on a card.
private struct DayCard<Content: View>: View {
    let title: String
    let symbol: String
    let colorHex: String
    var isDark = false
    var route: HomeRoute?
    @ViewBuilder let content: () -> Content

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if route != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .opacity(0.5)
                }
            }
            .foregroundStyle(isDark ? Color(hex: "FF8A8D") : Color(hex: colorHex))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isDark ? AnyShapeStyle(Color(hex: "141416")) : AnyShapeStyle(.cardFill), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

        if let route {
            NavigationLink(value: route) { themed(card) }
                .buttonStyle(.plain)
        } else {
            themed(card)
                .accessibilityElement(children: .contain)
        }
    }

    /// A dark tile (the workout) reads white in light mode too.
    @ViewBuilder private func themed<V: View>(_ view: V) -> some View {
        if isDark {
            view.environment(\.colorScheme, .dark)
        } else {
            view
        }
    }
}

private struct NutritionDayTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(Router.self) private var router

    var body: some View {
        let accent = Color(hex: "F08A24")
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: HomeRoute.app(.nutrition)) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RingView(progress: nutrition.knowsKcal ? nutrition.eaten.kcal / max(1, nutrition.goals.kcal) : 0, lineWidth: 10, color: accent, track: accent.opacity(0.16))
                    VStack(spacing: 0) {
                        if let left = nutrition.kcalLeft {
                            Text(TF.int(abs(left)))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                            Text(left >= 0 ? tr("kcal restantes") : tr("kcal en trop"))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(TF.int(nutrition.eaten.kcal))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                            Text(tr("kcal mangées"))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .minimumScaleFactor(0.7)
                    .padding(8)
                }
                .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Label(tr("Nutrition"), systemImage: "fork.knife")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                        Spacer()
                        Text(nutrition.knowsKcal ? "\(TF.int(nutrition.eaten.kcal)) / \(TF.int(nutrition.goals.kcal))" : tr("Objectif à définir"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    macro(tr("Protéines"), nutrition.eaten.protein, nutrition.knowsProtein ? nutrition.goals.protein : nil, "E5484D")
                    macro(tr("Glucides"), nutrition.eaten.carbs, nutrition.knowsCarbs ? nutrition.goals.carbs : nil, "F2A33A")
                    macro(tr("Lipides"), nutrition.eaten.fat, nutrition.knowsFat ? nutrition.goals.fat : nil, "3366FF")
                }
            }
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("daily-nutrition-open")
            HStack(spacing: 8) {
                Button {
                    router.isFoodScanPresented = true
                } label: {
                    Label(tr("Scanner"), systemImage: "barcode.viewfinder")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("daily-scan")
                NavigationLink(value: HomeRoute.app(.nutrition)) {
                    Text(mealsText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: "CF6414"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(accent.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            if let meal = nutrition.nextMeal, let kcal = nutrition.nextMealKcal, kcal > 0 {
                Text(tr("Prochain repas : \(meal.lowercased()), environ \(TF.int(kcal)) kcal"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-nutrition")
    }

    private var mealsText: String {
        nutrition.foods == 0 ? tr("Rien noté") : Fmt.plural(nutrition.meals, tr("repas"), tr("repas"))
    }

    private func macro(_ name: String, _ eaten: Double, _ goal: Double?, _ hex: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(name).font(.caption.weight(.semibold))
                Spacer()
                Text(goal.map { "\(TF.int(eaten))/\(TF.int($0)) g" } ?? "\(TF.int(eaten)) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let goal {
                BarView(progress: eaten / max(1, goal), color: Color(hex: hex), track: Color(hex: hex).opacity(0.15), height: 5)
            }
        }
    }
}

private struct WorkoutDayTile: View {
    let workout: DailyBrief.Workout
    @Environment(AppModel.self) private var model

    var body: some View {
        DayCard(title: title, symbol: "figure.strengthtraining.traditional", colorHex: "E5484D", isDark: true, route: .space(.fitness)) {
            switch workout.stage {
            case .planned:
                Text(workout.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(Fmt.plural(workout.exercises.count, tr("exercice"), tr("exercices"))) · \(Fmt.plural(workout.totalSets, tr("série"), tr("séries")))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 4)
                actionButton(tr("Commencer")) {
                    model.update(\.fitness) { state in
                        if let routine = state.routine(for: Date()) { state.startSession(routine, at: Date()) }
                    }
                }
            case let .inProgress(exercise, set, sets, reps, weight, restEndsAt):
                Text(exercise)
                    .font(.headline)
                    .lineLimit(1)
                Text(tr("Série \(set)/\(sets) · \(reps) × \(weight > 0 ? tr("\(ProfileNumberField.format(weight)) kg") : tr("poids du corps"))"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                if let restEndsAt, restEndsAt > Date() {
                    Text(timerInterval: Date()...restEndsAt, countsDown: true)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: "FF8A8D"))
                }
                Spacer(minLength: 4)
                actionButton(tr("Série faite")) {
                    model.update(\.fitness) { $0.completeNextSet(at: Date()) }
                    Haptics.tap()
                }
            case let .done(sets, volume):
                Text(workout.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                Label(tr("Faite · \(Fmt.plural(sets, tr("série"), tr("séries")))"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "7FD6A8"))
                if volume > 0 {
                    Text(tr("\(TF.int(volume)) kg soulevés"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            case let .rest(nextName, nextDay):
                Text(tr("Repos aujourd'hui"))
                    .font(.headline)
                if let nextName, let nextDay {
                    Text("\(nextDay) : \(nextName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .accessibilityIdentifier("daily-workout")
    }

    private var title: String {
        switch workout.stage {
        case .inProgress: tr("Séance en cours")
        case .done: tr("Séance du jour")
        case .rest: tr("Sport")
        case .planned: tr("Séance du jour")
        }
    }

    private func actionButton(_ title: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Color(hex: "E5484D"), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TimedListTile: View {
    let title: String
    let symbol: String
    let colorHex: String
    let items: [DailyBrief.TimedItem]
    let space: Space?

    var body: some View {
        DayCard(title: title, symbol: symbol, colorHex: colorHex, route: space.map(HomeRoute.space)) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.prefix(4)) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.time)
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .frame(minWidth: 44, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title)
                                .font(.subheadline.weight(item.isHighlighted ? .bold : .regular))
                                .foregroundStyle(item.isHighlighted ? Color(hex: colorHex) : .primary)
                                .lineLimit(2)
                            if !item.detail.isEmpty {
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(space == .student ? "daily-classes" : "daily-agenda")
    }
}

private struct HabitsDayTile: View {
    let done: Int
    let items: [DailyBrief.Check]
    @Environment(AppModel.self) private var model

    var body: some View {
        DayCard(title: tr("Habitudes"), symbol: "repeat", colorHex: "5C8424", route: .page(.planningHabits)) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(done)")
                    .font(.title.weight(.bold))
                Text("/\(items.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(items) { item in
                    Capsule()
                        .fill(item.isDone ? Color(hex: "7FA33A") : Color.secondary.opacity(0.2))
                        .frame(height: 6)
                }
            }
            Text(items.map { $0.isDone ? "\($0.title) ✓" : $0.title }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityIdentifier("daily-habits")
    }
}

private struct WaterDayTile: View {
    let glasses: Int
    let goal: Int?
    @Environment(AppModel.self) private var model

    var body: some View {
        DayCard(title: tr("Eau"), symbol: "drop.fill", colorHex: "3A8DDE") {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(glasses)")
                    .font(.title.weight(.bold))
                    .contentTransition(.numericText())
                Text(goal.map { tr("/\($0) verres") } ?? (glasses > 1 ? tr(" verres") : tr(" verre")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let goal {
                BarView(progress: Double(glasses) / Double(max(1, goal)), color: Color(hex: "3A8DDE"), track: Color(hex: "3A8DDE").opacity(0.15), height: 6)
            }
            Spacer(minLength: 4)
            Button {
                withAnimation(.snappy) { model.updateContent { $0.hydration.add(1, on: Date()) } }
                Haptics.tap()
            } label: {
                Label(tr("Un verre"), systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: "3A8DDE"))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .overlay { Capsule().strokeBorder(Color(hex: "3A8DDE"), lineWidth: 1.5) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("daily-water-add")
        }
        .accessibilityIdentifier("daily-water")
    }
}

private struct StepsDayTile: View {
    let steps: Int
    let goal: Int?

    var body: some View {
        DayCard(title: tr("Pas"), symbol: "figure.walk", colorHex: "12A4B5", route: .page(.fitnessActivity)) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Fmt.number(steps))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                if let goal {
                    Text("/ \(Fmt.number(goal))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if let goal {
                BarView(progress: Double(steps) / Double(max(1, goal)), color: Color(hex: "12A4B5"), track: Color(hex: "12A4B5").opacity(0.15), height: 6)
            } else {
                Text(tr("Objectif à définir"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("daily-steps")
    }
}

private struct BudgetDayTile: View {
    let spent: Double
    let perDayLeft: Double?
    @Environment(AppModel.self) private var model

    var body: some View {
        let currency = model.settings.currencyCode
        DayCard(title: tr("Budget"), symbol: "creditcard.fill", colorHex: "2F8F7A", route: .space(.budget)) {
            if let perDayLeft {
                Text(TF.money(perDayLeft, currency))
                    .font(.title2.weight(.bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(tr("à dépenser par jour d'ici la fin du mois"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(tr("Dépensé aujourd'hui : \(TF.money(spent, currency))"))
                .font(perDayLeft == nil ? .headline : .caption.weight(.semibold))
                .foregroundStyle(perDayLeft == nil ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("daily-budget")
    }
}

private struct WeatherDayTile: View {
    let weather: WeatherSnapshot
    @Environment(AppModel.self) private var model

    var body: some View {
        DayCard(title: weather.locationName, symbol: "location.fill", colorHex: "3A8DDE", route: .app(.weather)) {
            HStack(spacing: 8) {
                WeatherGlyph(code: weather.code, isDay: weather.isDay)
                    .font(.title2)
                Text(Fmt.temperature(weather.temperature, unit: model.settings.temperatureUnit))
                    .font(.title.weight(.semibold))
            }
            Text(WeatherCode.description(weather.code))
                .font(.caption.weight(.semibold))
            Text(tr("Max \(Fmt.temperature(weather.high, unit: model.settings.temperatureUnit)) · Min \(Fmt.temperature(weather.low, unit: model.settings.temperatureUnit))"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let rain = rainHint {
                Text(rain)
                    .font(.caption)
                    .foregroundStyle(Color(hex: "3A8DDE"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("daily-weather")
    }

    /// The first hour today with a good chance of rain.
    private var rainHint: String? {
        let now = Date()
        guard let hour = weather.hourly.first(where: { $0.date > now && DateMath.isSameDay($0.date, now) && ($0.precipitationProbability ?? 0) >= 50 }) else { return nil }
        return tr("Pluie probable vers \(Fmt.time(hour.date, uses24Hour: true))")
    }
}

private struct RemindersDayTile: View {
    let items: [DailyBrief.Reminder]

    var body: some View {
        DayCard(title: tr("À ne pas oublier"), symbol: "bell.fill", colorHex: "4B5563") {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(items) { item in
                    if let route = item.route {
                        NavigationLink(value: route) { row(item) }
                            .buttonStyle(.plain)
                    } else {
                        row(item)
                    }
                }
            }
        }
        .accessibilityIdentifier("daily-reminders")
    }

    private func row(_ item: DailyBrief.Reminder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: item.colorHex))
                .frame(width: 20)
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(item.when)
                .font(.caption)
                .foregroundStyle(item.when == tr("En retard") ? Color.red : .secondary)
                .lineLimit(1)
            if item.route != nil {
                Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct PrioritiesDayTile: View {
    let items: [DailyBrief.Check]
    @Environment(AppModel.self) private var model

    var body: some View {
        DayCard(title: tr("Top 3"), symbol: "3.circle.fill", colorHex: "6B7280", route: .space(.productivity)) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    Button {
                        if let id = UUID(uuidString: item.id) {
                            model.update(\.productivity) { $0.togglePriority(id) }
                            Haptics.tap()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? Color.accentColor : .secondary)
                            Text(item.title)
                                .font(.subheadline)
                                .strikethrough(item.isDone)
                                .foregroundStyle(item.isDone ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("daily-priorities")
    }
}

/// An interest with nothing entered yet: an invitation, never a made-up figure.
private struct InviteDayTile: View {
    let area: InfoArea

    var body: some View {
        NavigationLink(value: HomeRoute.infoArea(area)) {
            HStack(spacing: 12) {
                Image(systemName: area.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: area.colorHex))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: area.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(area.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(invitation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Text(tr("Ajouter"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily-invite-\(area.rawValue)")
    }

    private var invitation: String {
        switch area {
        case .nutrition: tr("Donne ton objectif calorique ou scanne un repas : tes calories du jour apparaîtront ici.")
        case .fitness: tr("Crée ton programme : ta séance du jour apparaîtra ici.")
        case .student: tr("Ajoute tes cours : ton horaire du jour apparaîtra ici.")
        case .budget: tr("Donne ton budget du mois pour voir ce qu'il te reste chaque jour.")
        case .habits: tr("Ajoute une habitude à suivre chaque jour.")
        case .productivity: tr("Ajoute tes tâches ou ton top 3 du jour.")
        default: area.items.first?.purpose ?? ""
        }
    }
}

// MARK: - Other views of the cards (swiped left or right)

private struct NutritionMealsTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.nutrition
        DayCard(title: tr("Repas du jour"), symbol: "fork.knife", colorHex: "F08A24", route: .app(.nutrition)) {
            VStack(spacing: 6) {
                ForEach(MealType.allCases) { meal in
                    let kcal = NutritionMath.totals(of: meal, state, on: Date()).kcal
                    HStack(alignment: .firstTextBaseline) {
                        Text(meal.title)
                            .font(.subheadline.weight(kcal > 0 ? .semibold : .regular))
                        Spacer()
                        Text(kcal > 0 ? tr("\(TF.int(kcal)) kcal") : "—")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(kcal > 0 ? .primary : .secondary)
                    }
                }
                Divider()
                HStack {
                    Text(tr("Total")).font(.subheadline.weight(.bold))
                    Spacer()
                    Text(nutrition.knowsKcal ? tr("\(TF.int(nutrition.eaten.kcal)) / \(TF.int(nutrition.goals.kcal)) kcal") : tr("\(TF.int(nutrition.eaten.kcal)) kcal"))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
            }
        }
        .accessibilityIdentifier("daily-nutrition-meals")
    }
}

private struct NutritionWeekTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(AppModel.self) private var model

    var body: some View {
        let days = NutritionMath.dailyCalories(model.nutrition, days: 7, until: Date())
        let logged = days.filter { $0 > 0 }
        DayCard(title: tr("Calories · 7 jours"), symbol: "chart.bar.fill", colorHex: "F08A24", route: .page(.nutritionHistory)) {
            DailyWeekBars(values: days, goal: nutrition.knowsKcal ? nutrition.goals.kcal : nil, colorHex: "F08A24")
            Text(logged.isEmpty ? tr("Rien noté cette semaine") : tr("Moyenne : \(TF.int(logged.reduce(0, +) / Double(logged.count))) kcal par jour noté"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("daily-nutrition-week")
    }
}

private struct WorkoutWeekTile: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let state = model.fitness
        let now = Date()
        let week = DateMath.calendar.dateInterval(of: .weekOfYear, for: now)
        let done = FitnessMath.sessions(state).filter { session in
            session.isFinished && (week?.contains(session.start) ?? false)
        }
        let goal = state.weeklyGoal
        DayCard(title: tr("Cette semaine"), symbol: "calendar", colorHex: "E5484D", isDark: true, route: .space(.fitness)) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(done.count)")
                    .font(.title.weight(.bold))
                Text(tr("/\(goal) séances"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = week.flatMap { DateMath.calendar.date(byAdding: .day, value: offset, to: $0.start) } ?? now
                    let trained = done.contains { DateMath.isSameDay($0.start, day) }
                    Circle()
                        .fill(trained ? Color(hex: "FF8A8D") : Color.white.opacity(DateMath.isSameDay(day, now) ? 0.45 : 0.18))
                        .frame(width: 12, height: 12)
                        .frame(maxWidth: .infinity)
                }
            }
            Text(done.count >= goal ? tr("Objectif de la semaine atteint") : tr("Encore \(Fmt.plural(goal - done.count, tr("séance"), tr("séances")))"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .accessibilityIdentifier("daily-workout-week")
    }
}

private struct WaterWeekTile: View {
    let goal: Int?
    @Environment(AppModel.self) private var model

    var body: some View {
        let hydration = model.content.hydration
        let values = (0..<7).reversed().map { offset in
            Double(hydration.glasses(on: DateMath.calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()))
        }
        DayCard(title: tr("Eau · 7 jours"), symbol: "drop.fill", colorHex: "3A8DDE") {
            DailyWeekBars(values: values, goal: goal.map(Double.init), colorHex: "3A8DDE", height: 44)
            if let goal {
                let reached = values.filter { $0 >= Double(goal) }.count
                Text(tr("Objectif atteint \(Fmt.plural(reached, tr("jour"), tr("jours"))) sur 7"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("daily-water-week")
    }
}

private struct StepsWeekTile: View {
    let goal: Int?
    private var counter: StepCounter { .shared }

    var body: some View {
        let days = counter.week.suffix(7)
        let values = days.map { Double($0.steps) }
        DayCard(title: tr("Pas · 7 jours"), symbol: "figure.walk", colorHex: "12A4B5", route: .page(.fitnessActivity)) {
            if values.isEmpty {
                Text(tr("La semaine apparaîtra ici."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                DailyWeekBars(values: Array(values), goal: goal.map(Double.init), colorHex: "12A4B5", height: 44)
                Text(tr("Moyenne : \(Fmt.number(Int(values.reduce(0, +) / Double(values.count)))) pas"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task { await counter.refreshWeek() }
        .accessibilityIdentifier("daily-steps-week")
    }
}

private struct WeatherHoursTile: View {
    let weather: WeatherSnapshot
    @Environment(AppModel.self) private var model

    var body: some View {
        let now = Date()
        let hours = weather.hourly.filter { $0.date > now }.prefix(5)
        DayCard(title: tr("Prochaines heures"), symbol: "clock", colorHex: "3A8DDE", route: .app(.weather)) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(hours), id: \.date) { hour in
                    VStack(spacing: 4) {
                        Text(Fmt.time(hour.date, uses24Hour: model.settings.uses24HourClock))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        WeatherGlyph(code: hour.code, isDay: hour.isDay)
                            .font(.callout)
                        Text(Fmt.temperature(hour.temperature, unit: model.settings.temperatureUnit))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityIdentifier("daily-weather-hours")
    }
}
