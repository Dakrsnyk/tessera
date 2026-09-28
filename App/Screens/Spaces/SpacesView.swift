import SwiftUI
import WidgetKit

/// The mini-apps: each space is where the data behind a family of widgets is entered.
struct SpacesView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.spacePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Chaque espace alimente ses widgets. Ce que tu notes ici s'affiche tout de suite sur ton écran d'accueil.")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(Space.allCases) { space in
                            NavigationLink(value: space) {
                                SpaceCard(space: space, summary: summary(for: space), widgetCount: SpaceCatalog.kinds(in: space).count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color.screenFill)
            .screenshotScroll()
            .navigationTitle("Espaces")
            .navigationDestination(for: Space.self) { space in
                SpaceView(space: space)
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
                    .background(Color.screenFill, in: Capsule())
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

enum SpaceCatalog {
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
            Section {
                widgetStrip
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
            } header: {
                Text("Widgets de l'espace")
            } footer: {
                Text("Touche un widget pour le personnaliser, puis ajoute-le à ton écran d'accueil ou verrouillé.")
            }
            content
        }
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
