import SwiftUI

/// Where a tap on Home leads, inside the Home tab.
enum HomeRoute: Hashable {
    case space(Space)
    case info
    /// Kept for old links only (screenshot mode, saved paths): there is no page per category any more,
    /// it opens the mini-app of the area (see `InfoArea.homeRoute`). New code uses `homeRoute`.
    case infoArea(InfoArea)
    /// A mini-app (Nutrition, Fitness…), and one of its detailed pages.
    case app(MiniApp)
    case page(MiniAppPage)
}

extension InfoArea {
    /// The mini-app where this area's information is filled in (Studies and Habits live in Planning).
    /// Nil for the areas without a mini-app: investments, listed companies, « Ma vie » and the general settings.
    var miniApp: MiniApp? {
        switch self {
        case .nutrition: .nutrition
        case .fitness: .fitness
        case .habits, .productivity, .student: .planning
        case .budget: .finances
        case .business: .business
        case .travel: .travel
        case .car: .car
        case .investing, .markets, .life, .general: nil
        }
    }

    /// Where a tap on this area leads: its mini-app, else the data of its space, else « Mes informations »
    /// (the general settings: city, calendar).
    var homeRoute: HomeRoute {
        if let miniApp { return .app(miniApp) }
        if let space { return .space(space) }
        return .info
    }
}

extension AppModel {
    /// Where « Complète tes informations » leads: the mini-app of the first area that still misses something
    /// its « À remplir » block asks for (the person's interests come first), else « Mes informations » for
    /// the general ones. A missing item no block shows (tasks, bills…) never picks a mini-app.
    var firstMissingInfoRoute: HomeRoute {
        let app = completion.missing.lazy.compactMap { item -> MiniApp? in
            guard let app = item.area.miniApp, app.toFillItems.contains(item) else { return nil }
            return app
        }.first
        return app.map { HomeRoute.app($0) } ?? .info
    }
}

/// « Mon Quotidien »: the figures of the day as a dashboard of tiles, only for what the person
/// entered, ordered by what matters now (see `DailyBrief`).
struct DailySection: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @State private var editingLayout = false
    private var steps: StepCounter { .shared }

    var body: some View {
        let now = Date()
        let settings = model.settings
        // Complete from the first launch: every category shows, as a dotted « Ajouter » card while it is empty.
        let automatic = DailyCategories.home(model: model, now: now, steps: steps.status == .allowed ? steps.stepsToday : nil)
        let tiles = DailyBrief.arranged(automatic, order: settings.dailyOrder, hidden: settings.dailyHidden)
        // Real figures entered by the person (invitations to fill in a category don't count).
        let hasData = automatic.contains { tile in
            switch tile {
            case .invite, .empty, .weather, .miniApp(_, caption: nil): false
            case let .priorities(items) where items.isEmpty: false
            default: true
            }
        }
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
                // A small « + »: add, order and size the cards, right here on Home (« Mes informations »
                // is at the bottom of the page). Always there: categories can be added before any data.
                Button {
                    editingLayout = true
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(.cardFill, in: Circle())
                }
                .accessibilityLabel(Text(tr("Modifier la disposition")))
                .accessibilityIdentifier("daily-layout")
            }
            // Nothing entered yet: Mon Quotidien asks for the information, the invitations follow.
            if !hasData {
                emptyState
            }
            if !tiles.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(DailyBrief.rows(tiles, wide: settings.dailyWide).enumerated()), id: \.offset) { pair in
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(pair.element) { tile in
                                // Two cards side by side: each lays itself out for half the width.
                                DailyTileView(tile: tile)
                                    .frame(maxWidth: .infinity)
                                    .environment(\.dailyCompact, pair.element.count > 1)
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
        .sheet(isPresented: $editingLayout) {
            DailyLayoutEditor(available: automatic)
        }
    }

    /// Nothing entered yet: « Mon Quotidien » asks for the person's information. No fake figure.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("Complète tes informations pour personnaliser ton Mon Quotidien."), systemImage: "sun.max")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(tr("Tes repas, ta séance, tes cours, tes habitudes… Renseigne ce qui te concerne : Ardane réunit chaque jour ce qui compte."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // The mini-app with something left to fill in (its « À remplir » block), else « Mes informations ».
            NavigationLink(value: model.firstMissingInfoRoute) {
                Text(tr("Ajouter mes informations"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("daily-empty-add")
        }
        .card()
    }
}

// MARK: - Tiles

private struct DailyCompactKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// A card of « Mon Quotidien » at half width, next to another one: only what matters, laid out
    /// for the narrow space (not the wide card made smaller).
    var dailyCompact: Bool {
        get { self[DailyCompactKey.self] }
        set { self[DailyCompactKey.self] = newValue }
    }
}

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
        case let .planning(items): PlanningDayTile(items: items)
        case let .habits(done, items): HabitsDayTile(done: done, items: items)
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
        case let .empty(category):
            InviteCard(title: category.title, symbol: category.symbol, colorHex: category.colorHex, text: category.invitation,
                       route: category.route, identifier: "daily-empty-\(category.rawValue)")
        case let .miniApp(raw, caption):
            if let app = MiniApp(rawValue: raw) {
                DayCard(title: app.title, symbol: app.symbol, colorHex: app.colorHex, route: .app(app)) {
                    Text(caption ?? tr("Rien pour l'instant : touche pour ajouter tes données."))
                        .font(caption == nil ? .caption : .headline)
                        .foregroundStyle(caption == nil ? Color.secondary : Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityIdentifier("daily-app-\(raw)")
            }
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
    /// A small tag next to the title (« Maintenant »), and a slightly firmer outline for the card to do right now.
    var badge: String? = nil
    var glows = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        let tint = Color(hex: colorHex)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
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
                if let badge {
                    HStack(spacing: 5) {
                        Circle().fill(tint).frame(width: 6, height: 6)
                        Text(badge.uppercased())
                            .font(.caption2.weight(.heavy))
                            .tracking(0.6)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(tint.opacity(0.2), in: Capsule())
                } else if route != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .opacity(0.5)
                }
            }
            .foregroundStyle(isDark ? Color(hex: "FF8A8D") : tint)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isDark ? AnyShapeStyle(Color(hex: "141416")) : AnyShapeStyle(.cardFill), in: shape)
        .categoryTint(colorHex, emphasized: glows)

        if let route {
            NavigationLink(value: route) { themed(card) }
                .buttonStyle(.pressable)
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

/// The light gradient of a category's color over a card, from the top left, and its thin outline: the
/// same on every card of Mon Quotidien (no image behind). `emphasized`: a slightly firmer outline.
private struct CategoryTint: ViewModifier {
    let colorHex: String
    var emphasized = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let tint = Color(hex: colorHex)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let dark = scheme == .dark
        content
            .overlay {
                shape
                    .fill(LinearGradient(colors: [tint.opacity(dark ? 0.24 : 0.15), tint.opacity(dark ? 0.08 : 0.05), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .overlay { shape.strokeBorder(tint.opacity(emphasized ? 0.4 : 0.2), lineWidth: 1).allowsHitTesting(false) }
    }
}

private extension View {
    func categoryTint(_ colorHex: String, emphasized: Bool = false) -> some View {
        modifier(CategoryTint(colorHex: colorHex, emphasized: emphasized))
    }
}

private struct NutritionDayTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(Router.self) private var router
    @Environment(\.dailyCompact) private var compact

    var body: some View {
        if compact { compactBody } else { wideBody }
    }

    /// Half width: the ring with what is left beside it, the three macros on one line each, then
    /// the scanner and the meals.
    private var compactBody: some View {
        let accent = Color(hex: "F08A24")
        return VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: HomeRoute.app(.nutrition)) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(tr("Nutrition"), systemImage: "fork.knife")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    HStack(spacing: 10) {
                        RingView(progress: nutrition.knowsKcal ? nutrition.eaten.kcal / max(1, nutrition.goals.kcal) : 0, lineWidth: 7, color: accent, track: accent.opacity(0.16))
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(TF.int(abs(nutrition.kcalLeft ?? nutrition.eaten.kcal)))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(nutrition.kcalLeft.map { $0 >= 0 ? tr("kcal restantes") : tr("kcal en trop") } ?? tr("kcal mangées"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    VStack(spacing: 6) {
                        compactMacro(tr("Protéines"), nutrition.eaten.protein, nutrition.knowsProtein ? nutrition.goals.protein : nil, "E5484D")
                        compactMacro(tr("Glucides"), nutrition.eaten.carbs, nutrition.knowsCarbs ? nutrition.goals.carbs : nil, "F2A33A")
                        compactMacro(tr("Lipides"), nutrition.eaten.fat, nutrition.knowsFat ? nutrition.goals.fat : nil, "3366FF")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("daily-nutrition-open")
            HStack(spacing: 6) {
                Button {
                    router.isFoodScanPresented = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 34)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(tr("Scanner")))
                .accessibilityIdentifier("daily-scan")
                NavigationLink(value: HomeRoute.app(.nutrition)) {
                    Text(mealsText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "CF6414"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(accent.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .categoryTint("F08A24")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-nutrition")
    }

    /// A macro on one line: its colour, its name, eaten over the target; a thin bar under it.
    private func compactMacro(_ name: String, _ eaten: Double, _ goal: Double?, _ hex: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(Color(hex: hex)).frame(width: 6, height: 6)
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Text(goal.map { "\(TF.int(eaten))/\(TF.int($0))" } ?? "\(TF.int(eaten)) g")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            if let goal {
                BarView(progress: eaten / max(1, goal), color: Color(hex: hex), track: Color(hex: hex).opacity(0.15), height: 4)
            }
        }
    }

    private var wideBody: some View {
        let accent = Color(hex: "F08A24")
        return VStack(alignment: .leading, spacing: 12) {
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
            .buttonStyle(.pressable)
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
                .buttonStyle(.pressable)
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
                .buttonStyle(.pressable)
            }
            if let meal = nutrition.nextMeal, let kcal = nutrition.nextMealKcal, kcal > 0 {
                Text(tr("Prochain repas : \(meal.lowercased()), environ \(TF.int(kcal)) kcal"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .categoryTint("F08A24")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("daily-nutrition")
    }

    private var mealsText: String {
        nutrition.foods == 0 ? tr("Rien noté") : Fmt.plural(nutrition.meals, tr("repas", context: "one"), tr("repas"))
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
    /// Today's session recorded by mistake, to delete once confirmed (it can then be done again).
    @State private var deleting: UUID?

    /// Today's finished session (the « Faite » card), the one « Supprimer la séance » removes.
    private var doneTodayID: UUID? {
        guard case .done = workout.stage else { return nil }
        let now = Date()
        return FitnessMath.sessions(model.fitness).last { DateMath.isSameDay($0.start, now) && $0.isFinished }?.id
    }

    var body: some View {
        DayCard(title: title, symbol: "figure.strengthtraining.traditional", colorHex: "E5484D", route: .space(.fitness), badge: nowBadge, glows: isNow) {
            switch workout.stage {
            case .planned:
                Text(workout.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(Fmt.plural(workout.exercises.count, tr("exercice"), tr("exercices"))) · \(Fmt.plural(workout.totalSets, tr("série"), tr("séries")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
                // The rest: counting down with a pause button, or paused with a button to start again.
                if let paused = model.fitness.active?.restPausedRemaining {
                    restControl(Text(tr("Pause · \(Duration.seconds(paused).formatted(.time(pattern: .minuteSecond)))")), symbol: "play.fill",
                                label: tr("Reprendre le repos")) { $0.resumeRest(at: Date()) }
                } else if let restEndsAt, restEndsAt > Date() {
                    restControl(Text(timerInterval: Date()...restEndsAt, countsDown: true), symbol: "pause.fill",
                                label: tr("Mettre le repos en pause")) { $0.pauseRest(at: Date()) }
                }
                Spacer(minLength: 4)
                actionButton(tr("Série faite")) {
                    var accepted = false
                    model.update(\.fitness) { accepted = $0.completeNextSet(at: Date()) }
                    if accepted { Haptics.tap() }
                }
            case let .done(sets, volume):
                Text(workout.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                Label(tr("Faite · \(Fmt.plural(sets, tr("série"), tr("séries")))"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: "2B9A66"))
                if volume > 0 {
                    Text(tr("\(TF.int(volume)) kg soulevés"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case let .rest(nextName, nextDay):
                Text(tr("Repos aujourd'hui"))
                    .font(.headline)
                if let nextName, let nextDay {
                    Text("\(nextDay) : \(nextName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .contextMenu {
            if let id = doneTodayID {
                Button(role: .destructive) {
                    deleting = id
                } label: {
                    Label(tr("Supprimer la séance"), systemImage: "trash")
                }
            }
        }
        .confirmsWorkoutDeletion($deleting)
        .accessibilityIdentifier("daily-workout")
    }

    /// The session to do right now: in progress, or still planned from the afternoon on (the moment
    /// where Mon Quotidien puts it first).
    private var isNow: Bool {
        switch workout.stage {
        case .inProgress: true
        case .planned: DailyBrief.Moment(Date()) != .morning
        default: false
        }
    }

    private var nowBadge: String? {
        if case .planned = workout.stage, isNow { return tr("Maintenant") }
        return nil
    }

    private var title: String {
        switch workout.stage {
        case .inProgress: tr("Séance en cours")
        case .done: tr("Séance du jour")
        case .rest: tr("Sport")
        case .planned: tr("Séance du jour")
        }
    }

    private func restControl(_ time: Text, symbol: String, label: String, change: @escaping (inout FitnessState) -> Void) -> some View {
        HStack(spacing: 8) {
            time
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color(hex: "E5484D"))
            Button {
                Haptics.tap()
                model.update(\.fitness, change)
            } label: {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: "E5484D"))
                    .frame(width: 28, height: 24)
                    .background(Color(hex: "E5484D").opacity(0.14), in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(label))
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
        .buttonStyle(.pressable)
    }
}

/// The week as a table: classes, work, appointments, tasks, workouts and the events of the Apple
/// calendar, a column a day. A touch anywhere on the card opens Planning, where a touch on a free time of
/// the calendar creates an event. Half width: the same table, its blocks without text. While the Apple
/// calendar isn't linked, its button stays apart: the table opens Planning, the button links the calendar.
private struct PlanningDayTile: View {
    let items: [DailyBrief.TimedItem]
    @Environment(AppModel.self) private var model
    @Environment(\.dailyCompact) private var compact
    @State private var events: [EventSnapshot] = []
    @State private var askingCalendar = false

    private let colorHex = "3366FF"

    var body: some View {
        let week = Agenda.week(containing: Date(), model: model, events: events)
        let isEmpty = week.allSatisfy { $0.items.isEmpty }
        Group {
            if model.events == .needsAccess {
                DayCard(title: tr("Planning"), symbol: "calendar.day.timeline.left", colorHex: colorHex) {
                    NavigationLink(value: HomeRoute.app(.planning)) {
                        table(week, isEmpty: isEmpty)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(tr("Planning")))
                    .accessibilityValue(Text(isEmpty ? tr("Rien de prévu cette semaine.") : ""))
                    .accessibilityIdentifier("daily-planning-week")
                    calendarButton
                }
            } else {
                DayCard(title: tr("Planning"), symbol: "calendar.day.timeline.left", colorHex: colorHex, route: .app(.planning)) {
                    table(week, isEmpty: isEmpty)
                        .accessibilityIdentifier("daily-planning-week")
                }
                // VoiceOver: the card reads as Planning, not as every block of the table.
                .accessibilityLabel(Text(tr("Planning")))
                .accessibilityValue(Text(isEmpty ? tr("Rien de prévu cette semaine.") : ""))
            }
        }
        .accessibilityIdentifier("daily-planning")
        .onAppear(perform: loadEvents)
        .onChange(of: model.events) { _, _ in loadEvents() }
        .permissionSheet(.calendar, isPresented: $askingCalendar, request: requestCalendar) { _ in
            model.refreshEvents()
            loadEvents()
        }
    }

    private func requestCalendar() async {
        _ = await CalendarService.requestAccess()
    }

    private func table(_ week: [(day: Date, items: [AgendaItem])], isEmpty: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if compact {
                if isEmpty {
                    emptyText
                } else {
                    WeekTimetable(days: week, compact: true, hourHeight: 12)
                }
            } else {
                // Empty, the table stays: Planning is where its free times are filled.
                if isEmpty { emptyText }
                WeekTimetable(days: week, hourHeight: 22)
            }
            weekLabel
                .frame(minHeight: compact ? nil : 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The Apple calendar, one tap away when it isn't linked yet.
    private var calendarButton: some View {
        Button {
            Task {
                // Explanation first (once); refused, the sheet offers the settings and the card keeps working.
                if let state = await AppPermission.calendar.requestOrExplain(isPresented: $askingCalendar, request: requestCalendar), state == .granted {
                    model.refreshEvents()
                    loadEvents()
                }
            }
        } label: {
            Label(tr("Relier le calendrier Apple"), systemImage: "calendar.badge.plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(hex: colorHex))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("daily-planning-calendar")
    }

    private var emptyText: some View {
        Text(tr("Rien de prévu cette semaine."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var weekLabel: some View {
        HStack(spacing: 3) {
            Text(tr("Toute la semaine"))
            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(hex: colorHex))
    }

    /// The calendar events of the whole week, the days already gone included.
    private func loadEvents() {
        guard CalendarService.hasAccess, let first = DateMath.week(containing: Date()).first else { return }
        events = CalendarService.events(from: first, to: first.addingTimeInterval(7 * 86_400))
    }
}

private struct HabitsDayTile: View {
    let done: Int
    let items: [DailyBrief.Check]
    @Environment(AppModel.self) private var model

    /// The longest run of days in a row among the habits (nothing shown without one).
    private var streak: Int { items.map(\.streak).max() ?? 0 }

    private var names: String { items.map { $0.isDone ? "\($0.title) ✓" : $0.title }.joined(separator: ", ") }

    var body: some View {
        DayCard(title: tr("Habitudes"), symbol: "repeat", colorHex: "5C8424", route: .page(.planningHabits)) {
            // One ring a habit, in its own color: full with a check when done today.
            HStack(spacing: 6) {
                ForEach(items.prefix(5)) { item in
                    let color = Color(hex: item.colorHex ?? "7FA33A")
                    ZStack {
                        Circle().strokeBorder(color, lineWidth: 2.5)
                        if item.isDone {
                            Circle().fill(color)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                if items.count > 5 {
                    Text("+\(items.count - 5)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(names))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(done)")
                    .font(.title.weight(.bold))
                Text("/\(items.count)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            if streak > 0 {
                Text(tr("Série de \(Fmt.plural(streak, tr("jour"), tr("jours")))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text(names)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .accessibilityIdentifier("daily-habits")
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
            // What was really spent the last seven days: no curve while nothing was spent.
            let week = lastSevenDays
            if week.contains(where: { $0 > 0 }) {
                SparklineShape(values: week)
                    .stroke(Color(hex: "2F8F7A"), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .frame(height: 26)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("daily-budget")
    }

    /// The spending of each of the last seven days, today last.
    private var lastSevenDays: [Double] {
        let now = Date()
        return (0..<7).reversed().map { back in
            DateMath.calendar.date(byAdding: .day, value: -back, to: now).map { BudgetMath.spentToday(model.budget, at: $0) } ?? 0
        }
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
                            .buttonStyle(.pressable)
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
    @State private var draft = ""

    /// Added from « + » as Productivité: the card gets its quick add (and no longer is one big link).
    private var hasQuickAdd: Bool { model.settings.dailyAdded.contains(DailyCategories.productivityKey) }
    private var canAdd: Bool { model.productivity.priorities.count < ProductivityState.maxPriorities }

    var body: some View {
        DayCard(title: tr("Top 3"), symbol: "3.circle.fill", colorHex: "6B7280", route: hasQuickAdd ? nil : .space(.productivity)) {
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
                    .buttonStyle(.pressable)
                }
                if hasQuickAdd {
                    quickAdd
                }
            }
        }
        .accessibilityIdentifier("daily-priorities")
    }

    /// The field to add a task in one gesture, and the way to the whole Top 3.
    private var quickAdd: some View {
        HStack(spacing: 8) {
            if canAdd {
                TextField(tr("Ajouter une tâche"), text: $draft)
                    .font(.subheadline)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("daily-quick-task-field")
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(draft.trimmed.isEmpty ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.pressable)
                .disabled(draft.trimmed.isEmpty)
                .accessibilityLabel(Text(tr("Ajouter une tâche")))
                .accessibilityIdentifier("daily-quick-task-add")
            } else {
                Spacer(minLength: 0)
            }
            NavigationLink(value: HomeRoute.space(.productivity)) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(Text(tr("Top 3")))
        }
        .padding(.top, items.isEmpty ? 0 : 2)
    }

    /// Adds the task for today; the haptic only when it was accepted (not empty, not a double tap, room left).
    private func add() {
        var accepted = false
        model.update(\.productivity) { accepted = $0.addQuickTask(draft, on: Date()) }
        if accepted {
            Haptics.tap()
            draft = ""
        }
    }
}

/// An interest with nothing entered yet: an invitation, never a made-up figure.
private struct InviteDayTile: View {
    let area: InfoArea

    var body: some View {
        InviteCard(title: area.title, symbol: area.symbol, colorHex: area.colorHex, text: invitation,
                   route: area.homeRoute, identifier: "daily-invite-\(area.rawValue)")
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

/// The dotted card of a category with nothing entered yet: its icon, name and what will show here,
/// « Ajouter » on the right; a tap opens the mini-app, where the missing information is filled in.
private struct InviteCard: View {
    let title: String
    let symbol: String
    let colorHex: String
    let text: String
    let route: HomeRoute
    let identifier: String

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: colorHex))
                    .frame(width: 34, height: 34)
                    .background(Color(hex: colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(text)
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
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - Other views of the cards (swiped left or right)

private struct NutritionMealsTile: View {
    let nutrition: DailyBrief.Nutrition
    @Environment(AppModel.self) private var model
    @Environment(\.dailyCompact) private var compact

    var body: some View {
        let state = model.nutrition
        DayCard(title: tr("Repas du jour"), symbol: "fork.knife", colorHex: "F08A24", route: .app(.nutrition)) {
            VStack(spacing: compact ? 5 : 6) {
                ForEach(MealType.allCases) { meal in
                    let kcal = NutritionMath.totals(of: meal, state, on: Date()).kcal
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(meal.title)
                            .font((compact ? Font.caption : .subheadline).weight(kcal > 0 ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Text(kcal > 0 ? (compact ? TF.int(kcal) : tr("\(TF.int(kcal)) kcal")) : "—")
                            .font(compact ? .caption : .subheadline)
                            .monospacedDigit()
                            .foregroundStyle(kcal > 0 ? .primary : .secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }
                }
                Divider()
                if compact {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Total")).font(.caption.weight(.bold))
                        Text(nutrition.knowsKcal ? tr("\(TF.int(nutrition.eaten.kcal)) / \(TF.int(nutrition.goals.kcal)) kcal") : tr("\(TF.int(nutrition.eaten.kcal)) kcal"))
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        Text(tr("Total")).font(.subheadline.weight(.bold))
                        Spacer()
                        Text(nutrition.knowsKcal ? tr("\(TF.int(nutrition.eaten.kcal)) / \(TF.int(nutrition.goals.kcal)) kcal") : tr("\(TF.int(nutrition.eaten.kcal)) kcal"))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }
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
        DayCard(title: tr("Cette semaine"), symbol: "calendar", colorHex: "E5484D", route: .space(.fitness)) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(done.count)")
                    .font(.title.weight(.bold))
                Text(tr("/\(goal) séances"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = week.flatMap { DateMath.calendar.date(byAdding: .day, value: offset, to: $0.start) } ?? now
                    let trained = done.contains { DateMath.isSameDay($0.start, day) }
                    Circle()
                        .fill(trained ? Color(hex: "E5484D") : Color.secondary.opacity(DateMath.isSameDay(day, now) ? 0.45 : 0.18))
                        .frame(width: 12, height: 12)
                        .frame(maxWidth: .infinity)
                }
            }
            Text(done.count >= goal ? tr("Objectif de la semaine atteint") : tr("Encore \(Fmt.plural(goal - done.count, tr("séance"), tr("séances")))"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("daily-workout-week")
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
    @Environment(\.dailyCompact) private var compact

    var body: some View {
        let now = Date()
        let hours = weather.hourly.filter { $0.date > now }.prefix(compact ? 3 : 5)
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
