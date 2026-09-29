import SwiftUI
import WidgetKit

/// The mini-apps: each space is where the data behind a family of widgets is entered.
struct SpacesView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    /// The space whose widget creator is open.
    @State private var creating: Space?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.spacePath) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Touche un espace pour créer ton propre widget. Ce que tu notes dans « Mes données » s'affiche tout de suite dessus.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .padding(.bottom, 2)
                    ForEach(Space.allCases) { space in
                        // A space opens its widget creator; its data stays in « Mes données » there.
                        Button {
                            creating = space
                        } label: {
                            SpaceSection(space: space, summary: summary(for: space))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(.screenFill)
            .screenshotScroll()
            .navigationTitle("Espaces")
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
        }
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
            return model.nutrition.entries.isEmpty ? "Note ton premier repas" : "\(TF.int(model.nutrition.goals.kcal - eaten)) kcal restantes"
        case .fitness:
            return model.fitness.routines.isEmpty ? "Crée ta séance" : "\(FitnessMath.workouts(inWeekOf: now, model.fitness))/\(model.fitness.weeklyGoal) séances"
        case .budget:
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

/// A space in the list: its title, a live summary and a few of its widgets, full width.
struct SpaceSection: View {
    let space: Space
    let summary: String
    @Environment(AppModel.self) private var model

    var body: some View {
        let examples = SpaceCatalog.examples(for: space)
        let usesOwnData = model.hasData(in: space)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: space.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color(hex: space.colorHex), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(space.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            EqualHeightRow(ratios: examples.map { $0.family.aspectRatio }, spacing: 10) {
                ForEach(Array(examples.enumerated()), id: \.offset) { pair in
                    let design = pair.element.design
                    WidgetPreview(
                        design: design, family: pair.element.family,
                        payload: usesOwnData ? model.payload(for: design) : SamplePayload.make(for: design)
                    )
                }
            }
            HStack(spacing: 6) {
                Text(space.subtitle)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(Fmt.plural(SpaceCatalog.kinds(in: space).count, "widget", "widgets"))
                    .fontWeight(.semibold)
                if !usesOwnData {
                    Text("· exemple")
                }
            }
            .font(.caption)
            .foregroundStyle(Color.secondary)
        }
        .card(padding: 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(space.title), \(summary)"))
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
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        List {
            // The strip lives in the header, which isn't clipped like a list row,
            // so the widgets scroll all the way to the screen edges.
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
            content
                .listRowBackground(Rectangle().fill(.cardFill))
        }
        .styledList()
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
