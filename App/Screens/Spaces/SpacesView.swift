import SwiftUI
import WidgetKit

/// The mini-apps: each space is where the data behind a family of widgets is entered.
struct SpacesView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    /// The space whose widget creator is open.
    @State private var creating: Space?
    /// Nil shows every space.
    @State private var universe: SpaceUniverse?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.spacePath) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choisis un univers, puis la taille de ton widget.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 20)
                        .id("spaces-top")
                    universeFilter
                    LazyVStack(spacing: 14) {
                        // The user's interests first, every other space below.
                        ForEach(shownSpaces) { space in
                            // A space opens its widget creator; its data stays in « Mes données » there.
                            Button {
                                creating = space
                            } label: {
                                ImmersiveSpaceCard(space: space, summary: summary(for: space))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("space-card-\(space.rawValue)")
                            .tutorialTarget(.createSpace, when: space == shownSpaces.first)
                        }
                    }
                    .padding(.horizontal, 20)
                    .animation(.spring(response: 0.38, dampingFraction: 0.86), value: universe)
                }
                .padding(.bottom, 32)
            }
            .onChange(of: router.tutorialStep) { _, step in
                if step == .create { withAnimation { proxy.scrollTo("spaces-top", anchor: .top) } }
            }
            }
            .background(.screenFill)
            .screenshotScroll()
            .navigationTitle("Créer")
            .navigationDestination(for: Space.self) { space in
                SpaceView(space: space)
            }
            .sheet(item: $creating) { space in
                SpaceBuilderView(space: space)
            }
            .onAppear {
                if let space = router.requestedCreator {
                    router.requestedCreator = nil
                    creating = space
                }
            }
            // A category tapped on the Home tab while this tab was already loaded.
            .onChange(of: router.requestedCreator) { _, space in
                if let space {
                    router.requestedCreator = nil
                    creating = space
                }
            }
        }
    }

    private var shownSpaces: [Space] {
        orderedSpaces.filter { universe == nil || $0.universe == universe }
    }

    private var universeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("Tout", isOn: universe == nil) { universe = nil }
                ForEach(SpaceUniverse.allCases) { item in
                    filterChip(item.title, isOn: universe == item) { universe = item }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterChip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .foregroundStyle(isOn ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(Color.primary))
                .background(isOn ? AnyShapeStyle(Color.primary) : AnyShapeStyle(AppFill.cardFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var orderedSpaces: [Space] {
        let preferred = model.profile.preferredSpaces
        return preferred + Space.allCases.filter { !preferred.contains($0) }
    }

    /// One live figure per space, so the grid doubles as a dashboard.
    private func summary(for space: Space) -> String {
        let now = Date()
        let currency = model.settings.currencyCode
        switch space {
        case .productivity:
            let open = model.content.tasks.filter { !$0.isDone }.count
            return open == 0 ? "Aucune tâche en attente" : Fmt.plural(open, "tâche à faire", "tâches à faire")
        case .habits:
            let habits = model.content.habits
            return habits.isEmpty ? "Crée une habitude" : "\(habits.filter { $0.isDone(on: now) }.count)/\(habits.count) aujourd'hui"
        case .nutrition:
            let eaten = NutritionMath.totals(model.nutrition, on: now).kcal
            if model.nutrition.entries.isEmpty { return "Note ton premier repas" }
            return model.profile.knows(.kcalTarget) ? "\(TF.int(model.nutrition.goals.kcal - eaten)) kcal restantes" : "\(TF.int(eaten)) kcal aujourd'hui"
        case .fitness:
            if model.fitness.routines.isEmpty { return "Crée ta séance" }
            let done = FitnessMath.workouts(inWeekOf: now, model.fitness)
            return model.profile.knows(.weeklyWorkouts) ? "\(done)/\(model.fitness.weeklyGoal) séances" : Fmt.plural(done, "séance cette semaine", "séances cette semaine")
        case .budget:
            guard model.profile.knows(.monthlyBudget) else {
                return "Dépensé \(TF.money(BudgetMath.spentThisMonth(model.budget, at: now), currency)) ce mois-ci"
            }
            return "Reste \(TF.money(BudgetMath.remaining(model.budget, at: now), currency))"
        case .investing:
            return model.portfolio.holdings.isEmpty ? "Ajoute tes placements" : Fmt.plural(model.portfolio.holdings.count, "placement", "placements")
        case .business:
            return model.business.sales.isEmpty ? "Note ta première vente" : "\(TF.money(BusinessMath.revenue(model.business, .month, at: now), currency)) ce mois-ci"
        case .markets:
            return Fmt.plural(model.following.followed.count, "entreprise suivie", "entreprises suivies")
        case .student:
            if let exam = StudentMath.nextExam(model.student, at: now) { return "Examen dans \(DateMath.daysBetween(now, exam.date)) j" }
            return model.student.courses.isEmpty ? "Ajoute tes cours" : Fmt.plural(model.student.courses.count, "cours", "cours")
        case .travel:
            if let trip = TravelMath.currentTrip(model.travel, at: now) {
                return TravelMath.isOngoing(trip, at: now) ? "En voyage à \(trip.destination)" : "\(trip.destination) dans \(DateMath.daysBetween(now, trip.start)) j"
            }
            return "Prépare ton prochain voyage"
        case .car:
            if let status = CarMath.serviceStatus(model.car, at: now).first, let km = status.kmLeft {
                return "\(status.item.name) dans \(TF.int(km)) km"
            }
            return model.car.fills.isEmpty ? "Note ton premier plein" : model.car.name
        case .life:
            if let birthday = model.life.birthday {
                return "Anniversaire dans \(DateMath.daysBetween(now, LifeMath.nextBirthday(birthday: birthday, after: now).date)) j"
            }
            return "Anniversaire et jours fériés"
        }
    }
}

/// The families of spaces the Créer tab filters by.
enum SpaceUniverse: String, CaseIterable, Identifiable {
    case health, money, organisation, life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "Santé"
        case .money: "Argent"
        case .organisation: "Organisation"
        case .life: "Vie"
        }
    }
}

extension Space {
    var universe: SpaceUniverse {
        switch self {
        case .fitness, .nutrition, .habits: .health
        case .budget, .investing, .business, .markets: .money
        case .productivity, .student: .organisation
        case .travel, .car, .life: .life
        }
    }
}

/// A space in the Créer tab: its colour as a deep backdrop, its live figure, and a few of its widgets
/// sitting on it as on a wallpaper.
struct ImmersiveSpaceCard: View {
    let space: Space
    let summary: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let examples = Array(SpaceCatalog.examples(for: space).prefix(2))
        let usesOwnData = model.hasData(in: space)
        let color = Color(hex: space.colorHex)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: space.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(Fmt.plural(SpaceCatalog.kinds(in: space).count, "widget", "widgets"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                if !usesOwnData {
                    Text("· exemple")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.2), in: Circle())
            }
            Text(space.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 12)
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            EqualHeightRow(ratios: examples.map { $0.family.aspectRatio }, spacing: 10) {
                ForEach(Array(examples.enumerated()), id: \.offset) { pair in
                    let design = pair.element.design
                    WidgetPreview(
                        design: design, family: pair.element.family,
                        payload: usesOwnData ? model.payload(for: design) : SamplePayload.make(for: design)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                }
            }
            .padding(.top, 16)
        }
        .padding(18)
        .background {
            // The space's colour, bright at the top right and deepening towards the widgets.
            ZStack {
                color
                RadialGradient(colors: [.white.opacity(0.22), .clear], center: .topTrailing, startRadius: 0, endRadius: 280)
                LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.62)], startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(space.title), \(summary)"))
        .accessibilityHint(Text("Crée un widget de cet espace"))
    }
}

extension AppModel {
    /// Whether the user has entered anything in a space yet (otherwise its widgets show example data).
    func hasData(in space: Space) -> Bool {
        switch space {
        case .productivity: !content.tasks.isEmpty || !productivity.priorities.isEmpty || !productivity.projects.isEmpty
        case .habits: !content.habits.isEmpty
        case .nutrition: !nutrition.entries.isEmpty
        case .fitness: !fitness.routines.isEmpty
        case .budget: !budget.expenses.isEmpty
        case .investing: !portfolio.holdings.isEmpty
        case .business: !business.sales.isEmpty
        case .markets: !companies.isEmpty
        case .student: !student.courses.isEmpty
        case .travel: !travel.trips.isEmpty
        case .car: !car.fills.isEmpty
        case .life: life.birthday != nil
        }
    }
}

struct SpaceCard: View {
    let space: Space
    let summary: String
    let widgetCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: space.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color(hex: space.colorHex), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                Spacer()
                Text("\(widgetCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.screenFill, in: Capsule())
                    .accessibilityLabel(Text("\(widgetCount) widgets"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(space.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .card(padding: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct SpaceExample {
    let design: WidgetDesign
    let family: WidgetFamily
}

enum SpaceCatalog {
    /// What the space creator selects first for each size: the key widget in small, two widgets that
    /// complete each other in medium, a dashboard of the space in large (one of them takes a whole row).
    static func preset(for space: Space, format: WidgetFormat) -> [WidgetKind] {
        let pair: (medium: [WidgetKind], large: [WidgetKind])
        switch space {
        case .productivity: pair = ([.priorities, .deadline], [.priorities, .deadline, .tasks])
        case .habits: pair = ([.habitStreak, .hydration], [.habitStreak, .hydration, .habits])
        case .nutrition: pair = ([.caloriesLeft, .macros], [.caloriesLeft, .macros, .mealsToday])
        case .fitness: pair = ([.nextSet, .trainingStreak], [.nextSet, .trainingStreak, .todaysWorkout])
        case .budget: pair = ([.budgetLeft, .savingsGoal], [.budgetLeft, .savingsGoal, .spendingByCategory])
        case .investing: pair = ([.portfolio, .allocation], [.allocation, .topMover, .portfolio])
        case .business: pair = ([.revenueToday, .revenueGoal], [.revenueToday, .revenueGoal, .revenueTrend])
        case .markets: pair = ([.companySnapshot, .companyStock], [.companySnapshot, .companyStock, .companyRevenue])
        case .student: pair = ([.nextClass, .nextExam], [.nextClass, .nextExam, .timetable])
        case .travel: pair = ([.tripCountdown, .localTime], [.tripCountdown, .localTime, .flight])
        case .car: pair = ([.nextService, .mileage], [.nextService, .mileage, .carCost])
        case .life: pair = ([.birthday, .holiday], [.birthday, .holiday, .ageProgress])
        }
        let available = kinds(in: space)
        switch format {
        case .small:
            let small = available.filter { $0.families.contains(.systemSmall) }
            return [small.first(where: { !$0.isPremium }) ?? small.first ?? available.first ?? .note]
        case .medium: return pair.medium.filter { available.contains($0) }
        case .large: return pair.large.filter { available.contains($0) }
        }
    }

    /// A few widgets of a space, small and medium, shown in the list of spaces.
    static func examples(for space: Space) -> [SpaceExample] {
        let picks: [(WidgetKind, WidgetFamily)]
        switch space {
        case .productivity: picks = [(.priorities, .systemSmall), (.tasks, .systemMedium)]
        case .habits: picks = [(.habits, .systemMedium), (.hydration, .systemSmall)]
        case .nutrition: picks = [(.caloriesLeft, .systemSmall), (.macros, .systemSmall), (.nextMeal, .systemSmall)]
        case .fitness: picks = [(.todaysWorkout, .systemMedium), (.trainingStreak, .systemSmall)]
        case .budget: picks = [(.budgetLeft, .systemSmall), (.spendingByCategory, .systemMedium)]
        case .investing: picks = [(.portfolio, .systemMedium), (.allocation, .systemSmall)]
        case .business: picks = [(.revenueToday, .systemSmall), (.revenueGoal, .systemSmall), (.mrr, .systemSmall)]
        case .markets: picks = [(.companySnapshot, .systemSmall), (.companyCompare, .systemMedium)]
        case .student: picks = [(.nextClass, .systemSmall), (.timetable, .systemMedium)]
        case .travel: picks = [(.flight, .systemMedium), (.tripCountdown, .systemSmall)]
        case .car: picks = [(.nextService, .systemSmall), (.carCost, .systemMedium)]
        case .life: picks = [(.birthday, .systemSmall), (.ageProgress, .systemSmall), (.holiday, .systemSmall)]
        }
        return picks.map { kind, family in
            SpaceExample(design: TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind), family: family)
        }
    }


    /// The widgets fed by a space.
    static func kinds(in space: Space) -> [WidgetKind] {
        var kinds = WidgetKind.allCases.filter { $0.space == space }
        switch space {
        case .life: kinds += [.birthday, .ageProgress, .holiday].filter { !kinds.contains($0) }
        case .productivity: kinds += [.aiProductivity].filter { !kinds.contains($0) }
        default: break
        }
        return kinds
    }
}

/// A space: its widgets at the top, then everything needed to feed them.
struct SpaceView: View {
    let space: Space
    /// Opened from the widget editor or the space creator: only the data, so going back returns to the
    /// widget being made exactly as it was (the widget strip would open another editor over it).
    var isEmbedded = false
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        List {
            // The strip lives in the header, which isn't clipped like a list row,
            // so the widgets scroll all the way to the screen edges.
            if !isEmbedded {
                Section {
                } header: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Widgets de l'espace")
                        widgetStrip
                            .padding(.horizontal, -20)
                            .foregroundStyle(Color.primary)
                            .textCase(nil)
                    }
                } footer: {
                    Text("Touche un widget pour le personnaliser, puis ajoute-le à ton écran d'accueil ou verrouillé.")
                }
            }
            content
                .listRowBackground(Rectangle().fill(.cardFill))
        }
        .styledList()
        .hostsSpaceSheets()
        .navigationTitle(space.title)
        .navigationBarTitleDisplayMode(.large)
        .screenshotScroll()
    }

    private var widgetStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(SpaceCatalog.kinds(in: space)) { kind in
                    let design = TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind)
                    Button {
                        router.openEditor(design, isNew: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            WidgetPreview(design: design, family: .systemSmall, payload: model.payload(for: design), width: 128)
                            HStack(spacing: 4) {
                                Text(kind.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                if kind.isPremium && !model.isPremium {
                                    PremiumBadge(compact: true)
                                }
                            }
                            .frame(width: 128, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        // Widgets scroll to the screen edge instead of being cut at the row's inset.
        .scrollClipDisabled()
    }

    @ViewBuilder private var content: some View {
        switch space {
        case .productivity: ProductivitySpaceSections()
        case .habits: HabitsSpaceSections()
        case .nutrition: NutritionSpaceSections()
        case .fitness: FitnessSpaceSections()
        case .budget: BudgetSpaceSections()
        case .investing: PortfolioSpaceSections()
        case .business: BusinessSpaceSections()
        case .markets: MarketsSpaceSections()
        case .student: StudentSpaceSections()
        case .travel: TravelSpaceSections()
        case .car: CarSpaceSections()
        case .life: LifeSpaceSections()
        }
    }
}
