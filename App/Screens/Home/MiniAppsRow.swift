import SwiftUI

/// How often each mini-app is opened on this iPhone, to put the most used first on Home.
enum MiniAppUsage {
    private static let key = "miniAppOpens"

    static func record(_ app: MiniApp) {
        var counts = load()
        counts[app.rawValue, default: 0] += 1
        UserDefaults.standard.set(counts, forKey: key)
    }

    static func load() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    private static let hiddenKey = "miniAppsHidden"

    /// The mini-apps the person took off Home (still in « Toutes »).
    static var hidden: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
    }

    static func setHidden(_ app: MiniApp, _ isHidden: Bool) {
        var set = hidden
        if isHidden { set.insert(app.rawValue) } else { set.remove(app.rawValue) }
        UserDefaults.standard.set(Array(set).sorted(), forKey: hiddenKey)
    }
}

/// What a mini-app shows on its chip: whether the person has data there, and one live figure.
@MainActor
enum MiniAppSummary {
    static func hasData(_ app: MiniApp, _ model: AppModel) -> Bool {
        switch app {
        case .nutrition: !model.nutrition.entries.isEmpty
        case .fitness: !model.fitness.routines.isEmpty || !model.fitness.history.isEmpty
        case .planning: !model.content.tasks.isEmpty || !model.content.habits.isEmpty || !model.productivity.projects.isEmpty
        case .studies: !model.student.courses.isEmpty
        case .finances: !model.budget.expenses.isEmpty || !model.budget.bills.isEmpty || !model.budget.goals.isEmpty
        case .business: !model.business.sales.isEmpty
        case .travel: !model.travel.trips.isEmpty
        case .car: !model.car.fills.isEmpty || !model.car.readings.isEmpty
        case .weather: model.settings.weatherLocation != nil
        }
    }

    static func interest(_ app: MiniApp) -> [Interest] {
        switch app {
        case .nutrition: [.nutrition, .wellbeing]
        case .fitness: [.sport, .wellbeing]
        case .planning: [.productivity]
        case .studies: [.studies]
        case .finances: [.budget, .finance]
        case .business: [.business]
        case .travel: [.travel]
        case .car: [.car]
        case .weather: [.weather]
        }
    }

    /// One figure from the person's own data, nil when there is none to show.
    static func caption(_ app: MiniApp, _ model: AppModel, now: Date) -> String? {
        let currency = model.settings.currencyCode
        switch app {
        case .nutrition:
            let totals = NutritionMath.totals(model.nutrition, on: now)
            return totals.kcal > 0 ? "\(TF.int(totals.kcal)) kcal aujourd'hui" : nil
        case .fitness:
            if model.fitness.active.map({ !$0.isFinished }) == true { return "Séance en cours" }
            let days = FitnessMath.trainedDays(inWeekOf: now, model.fitness).filter { $0 }.count
            return model.fitness.routines.isEmpty && days == 0 ? nil : "\(days) séance\(days > 1 ? "s" : "") cette semaine"
        case .planning:
            let open = model.content.tasks.filter { !$0.isDone && ($0.isDue(on: now) || $0.isOverdue(at: now)) }.count
            return open > 0 ? "\(open) tâche\(open > 1 ? "s" : "") aujourd'hui" : nil
        case .studies:
            if let next = StudentMath.nextClass(model.student, at: now), DateMath.isSameDay(next.start, now) {
                return "\(model.student.course(next.slot.courseID)?.name ?? "Cours") à \(Fmt.time(next.start, uses24Hour: true))"
            }
            let open = StudentMath.openAssignments(model.student).count
            return open > 0 ? "\(open) devoir\(open > 1 ? "s" : "") à rendre" : nil
        case .finances:
            guard !model.budget.expenses.isEmpty else { return nil }
            let remaining = BudgetMath.remaining(model.budget, at: now)
            return remaining >= 0 ? "\(TF.money(remaining, currency)) restants" : "Budget dépassé"
        case .business:
            guard !model.business.sales.isEmpty else { return nil }
            return "\(TF.money(BusinessMath.revenue(model.business, .month, at: now), currency)) ce mois"
        case .travel:
            guard let trip = TravelMath.currentTrip(model.travel, at: now) else { return nil }
            if TravelMath.isOngoing(trip, at: now) { return "\(trip.destination) · jour \(TravelMath.tripDay(trip, at: now).day)" }
            return "\(trip.destination) · J-\(DateMath.daysBetween(now, trip.start))"
        case .car:
            if let range = CarMath.range(model.car) { return "≈ \(Fmt.number(Int(range.km))) km d'autonomie" }
            return CarMath.odometer(model.car).map { "\(Fmt.number(Int($0))) km" }
        case .weather:
            guard case let .ready(weather) = model.weather else { return nil }
            return "\(Fmt.temperature(weather.temperature, unit: model.settings.temperatureUnit)) · \(WeatherCode.description(weather.code))"
        }
    }

    /// The mini-apps for this person: those with data or matching an interest, the most opened
    /// first; the others stay one tap away.
    static func ordered(_ model: AppModel) -> (shown: [MiniApp], others: [MiniApp]) {
        let usage = MiniAppUsage.load()
        let interests = Set(model.profile.interests)
        let hidden = MiniAppUsage.hidden
        let relevant = MiniApp.allCases.filter { app in
            !hidden.contains(app.rawValue) && (hasData(app, model) || !Set(interest(app)).isDisjoint(with: interests))
        }
        let shown = relevant.sorted { lhs, rhs in
            let left = usage[lhs.rawValue] ?? 0
            let right = usage[rhs.rawValue] ?? 0
            if left != right { return left > right }
            let leftData = hasData(lhs, model)
            let rightData = hasData(rhs, model)
            if leftData != rightData { return leftData }
            return (MiniApp.allCases.firstIndex(of: lhs) ?? 0) < (MiniApp.allCases.firstIndex(of: rhs) ?? 0)
        }
        return (shown, MiniApp.allCases.filter { !shown.contains($0) })
    }
}

/// « Mes mini-apps » on Home: one chip per mini-app the person uses, with a live figure; the
/// others behind « Toutes ».
struct MiniAppsRow: View {
    @Environment(AppModel.self) private var model
    @State private var showingAll = false
    /// Bumped when the person hides or shows a mini-app, to redraw the row.
    @State private var revision = 0

    var body: some View {
        let now = Date()
        let order = MiniAppSummary.ordered(model)
        let _ = revision
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mes mini-apps")
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Toutes") { showingAll = true }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("mini-apps-all")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(order.shown.isEmpty ? [MiniApp.planning, .weather] : order.shown) { app in
                        NavigationLink(value: HomeRoute.app(app)) {
                            chip(app, caption: MiniAppSummary.caption(app, model, now: now))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("mini-app-\(app.rawValue)")
                        .contextMenu {
                            Button {
                                MiniAppUsage.setHidden(app, true)
                                revision += 1
                            } label: {
                                Label("Masquer de l'accueil", systemImage: "eye.slash")
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
        .sheet(isPresented: $showingAll, onDismiss: { revision += 1 }) {
            AllMiniAppsSheet(order: order)
        }
    }

    private func chip(_ app: MiniApp, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: app.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(app.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(app.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text(caption ?? "Ouvrir")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 128, height: 118, alignment: .topLeading)
        .padding(12)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Every mini-app, the ones in use first.
struct AllMiniAppsSheet: View {
    let order: (shown: [MiniApp], others: [MiniApp])
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !order.shown.isEmpty {
                    Section("Mes mini-apps") {
                        ForEach(order.shown) { row($0) }
                    }
                }
                if !order.others.isEmpty {
                    Section {
                        ForEach(order.others) { app in
                            row(app)
                                .swipeActions {
                                    if MiniAppUsage.hidden.contains(app.rawValue) {
                                        Button("Afficher") { MiniAppUsage.setHidden(app, false) }
                                            .tint(app.color)
                                    }
                                }
                        }
                    } header: {
                        Text("À découvrir")
                    } footer: {
                        Text("Chaque mini-app utilise tes données de Tessera et de « Mes informations » : rien n'est inventé, elles se remplissent à mesure que tu notes. Une mini-app masquée de l'accueil (appui long) revient en glissant sa ligne.")
                    }
                }
            }
            .styledList()
            .navigationTitle("Mini-apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func row(_ app: MiniApp) -> some View {
        Button {
            dismiss()
            router.openApp(app)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: app.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(app.color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(app.title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .accessibilityIdentifier("all-apps-\(app.rawValue)")
    }
}
