import Foundation

/// A part of Ardane where the person keeps their data: one per space, plus the general settings
/// (city, calendar) the widgets share.
enum InfoArea: String, CaseIterable, Identifiable {
    case nutrition, fitness, habits, productivity, student, budget, business, investing, markets, travel, car, life, general

    var id: String { rawValue }
    var space: Space? { Space(rawValue: rawValue) }
    var title: String { space?.title ?? tr("Général") }
    var symbol: String { space?.symbol ?? "gearshape.fill" }
    var colorHex: String { space?.colorHex ?? "6B7280" }

    var items: [DataItem] { DataItem.allCases.filter { $0.area == self } }

    /// The areas of the person's interests first, then the others in catalog order.
    static func ordered(preferring spaces: [Space]) -> [InfoArea] {
        let preferred = spaces.compactMap { InfoArea(rawValue: $0.rawValue) }
        var seen = Set<InfoArea>()
        return (preferred + allCases).filter { seen.insert($0).inserted }
    }
}

/// Something widgets need from the person. It is asked once, kept in one place, and every widget,
/// « Mon Quotidien » and « Mes informations » read that same place.
enum DataItem: String, CaseIterable, Identifiable {
    case kcalTarget, macroTargets, meals
    case routines, weeklyWorkouts, weight, stepGoal
    case habits, hydrationGoal
    case tasks, priorities, projects, deadlines, counters, focusGoal
    case timetable, exams, assignments, grades, flashcards
    case monthlyBudget, expenses, bills, savingsGoals, accounts, moneyFlow
    case businessGoal, sales
    case holdings
    case companies
    case trip
    case carName, carFills, carDeadlines
    case birthday
    case city, calendar

    var id: String { rawValue }

    /// How the item is given: a value typed once, a list built once, a log kept day after day,
    /// or an access the iPhone grants.
    enum Style {
        case value, list, log, access
    }

    var style: Style {
        switch self {
        case .kcalTarget, .macroTargets, .weeklyWorkouts, .weight, .stepGoal, .hydrationGoal, .focusGoal,
             .monthlyBudget, .businessGoal, .carName, .birthday, .city:
            .value
        case .meals, .expenses, .sales, .carFills:
            .log
        case .calendar:
            .access
        default:
            .list
        }
    }

    var area: InfoArea {
        switch self {
        case .kcalTarget, .macroTargets, .meals: .nutrition
        case .routines, .weeklyWorkouts, .weight, .stepGoal: .fitness
        case .habits, .hydrationGoal: .habits
        case .tasks, .priorities, .projects, .deadlines, .counters, .focusGoal: .productivity
        case .timetable, .exams, .assignments, .grades, .flashcards: .student
        case .monthlyBudget, .expenses, .bills, .savingsGoals, .accounts, .moneyFlow: .budget
        case .businessGoal, .sales: .business
        case .holdings: .investing
        case .companies: .markets
        case .trip: .travel
        case .carName, .carFills, .carDeadlines: .car
        case .birthday: .life
        case .city, .calendar: .general
        }
    }

    var title: String {
        switch self {
        case .kcalTarget: tr("Objectif calorique")
        case .macroTargets: tr("Objectifs de macros")
        case .meals: tr("Repas")
        case .routines: tr("Programme d'entraînement")
        case .weeklyWorkouts: tr("Séances par semaine")
        case .weight: tr("Poids")
        case .stepGoal: tr("Objectif de pas")
        case .habits: tr("Habitudes")
        case .hydrationGoal: tr("Objectif d'eau")
        case .tasks: tr("Tâches")
        case .priorities: tr("Top 3 du jour")
        case .projects: tr("Projets")
        case .deadlines: tr("Échéances")
        case .counters: tr("Compteurs")
        case .focusGoal: tr("Objectif de concentration")
        case .timetable: tr("Cours et horaire")
        case .exams: tr("Examens")
        case .assignments: tr("Devoirs")
        case .grades: tr("Notes")
        case .flashcards: tr("Fiches de révision")
        case .monthlyBudget: tr("Budget du mois")
        case .expenses: tr("Dépenses")
        case .bills: tr("Factures et abonnements")
        case .savingsGoals: tr("Objectifs d'épargne")
        case .accounts: tr("Comptes")
        case .moneyFlow: tr("Revenus et dépenses fixes")
        case .businessGoal: tr("Objectif de chiffre d'affaires")
        case .sales: tr("Ventes")
        case .holdings: tr("Placements")
        case .companies: tr("Entreprises suivies")
        case .trip: tr("Voyage")
        case .carName: tr("Ta voiture")
        case .carFills: tr("Pleins")
        case .carDeadlines: tr("Échéances auto")
        case .birthday: tr("Anniversaire")
        case .city: tr("Ville")
        case .calendar: tr("Calendrier")
        }
    }

    var symbol: String {
        switch self {
        case .kcalTarget: "flame"
        case .macroTargets: "chart.pie"
        case .meals: "fork.knife"
        case .routines: "list.bullet.rectangle"
        case .weeklyWorkouts: "calendar"
        case .weight: "scalemass"
        case .stepGoal: "figure.walk"
        case .habits: "repeat"
        case .hydrationGoal: "drop.fill"
        case .tasks: "checklist"
        case .priorities: "3.circle"
        case .projects: "folder"
        case .deadlines: "flag"
        case .counters: "plus.circle"
        case .focusGoal: "brain.head.profile"
        case .timetable: "calendar.day.timeline.left"
        case .exams: "pencil.and.list.clipboard"
        case .assignments: "doc.text"
        case .grades: "chart.bar"
        case .flashcards: "rectangle.on.rectangle"
        case .monthlyBudget: "creditcard"
        case .expenses: "cart"
        case .bills: "doc.text"
        case .savingsGoals: "banknote"
        case .accounts: "building.columns"
        case .moneyFlow: "arrow.left.arrow.right"
        case .businessGoal: "target"
        case .sales: "chart.line.uptrend.xyaxis"
        case .holdings: "chart.pie"
        case .companies: "building.2"
        case .trip: "airplane"
        case .carName: "car"
        case .carFills: "fuelpump"
        case .carDeadlines: "calendar.badge.exclamationmark"
        case .birthday: "gift"
        case .city: "location"
        case .calendar: "calendar"
        }
    }

    /// Why it is asked, in the words of the widgets that use it.
    var purpose: String {
        switch self {
        case .kcalTarget: tr("Pour savoir ce qu'il te reste à manger aujourd'hui.")
        case .macroTargets: tr("Pour suivre tes protéines, glucides et lipides.")
        case .meals: tr("Scanne ou cherche un aliment : tes widgets se mettent à jour.")
        case .routines: tr("Tes séances et les jours où tu les fais.")
        case .weeklyWorkouts: tr("Pour suivre ta régularité semaine après semaine.")
        case .weight: tr("Pour estimer les calories brûlées.")
        case .stepGoal: tr("Pour suivre tes pas dans « Mon Quotidien ».")
        case .habits: tr("Ce que tu veux faire chaque jour.")
        case .hydrationGoal: tr("Le nombre de verres d'eau à boire par jour.")
        case .tasks: tr("Ce qu'il te reste à faire.")
        case .priorities: tr("Les trois choses les plus importantes du jour.")
        case .projects: tr("Tes projets et leurs étapes.")
        case .deadlines: tr("Les dates à ne pas manquer.")
        case .counters: tr("Ce que tu comptes d'une touche.")
        case .focusGoal: tr("Les heures de concentration visées par semaine.")
        case .timetable: tr("Tes cours et leurs horaires de la semaine.")
        case .exams: tr("Tes prochains examens.")
        case .assignments: tr("Tes devoirs et leur date de remise.")
        case .grades: tr("Tes notes, pour ta moyenne.")
        case .flashcards: tr("Des fiches à réviser.")
        case .monthlyBudget: tr("Pour savoir ce qu'il te reste chaque jour.")
        case .expenses: tr("Note une dépense en quelques secondes.")
        case .bills: tr("Pour voir ce qui arrive bientôt.")
        case .savingsGoals: tr("Ce que tu mets de côté, et pour quoi.")
        case .accounts: tr("Pour ta valeur nette.")
        case .moneyFlow: tr("Ton salaire et tes dépenses fixes.")
        case .businessGoal: tr("Ce que tu vises chaque mois.")
        case .sales: tr("Note tes ventes pour suivre ton activité.")
        case .holdings: tr("Tes actions, ETF et cryptos.")
        case .companies: tr("Les sociétés cotées que tu suis.")
        case .trip: tr("Ton prochain voyage : destination et dates.")
        case .carName: tr("Le nom de ta voiture et son kilométrage.")
        case .carFills: tr("Tes pleins, pour le coût et la consommation.")
        case .carDeadlines: tr("Contrôle technique, assurance, pneus…")
        case .birthday: tr("Pour ton âge et le compte à rebours.")
        case .city: tr("Pour la météo de tes widgets.")
        case .calendar: tr("Pour afficher tes événements.")
        }
    }

    /// A list or a log with nothing yet is not « missing »: it is simply empty. Only values,
    /// lists a widget can't work without, and accesses count as missing.
    var countsAsMissing: Bool { style != .log }

    /// The few items that make an area « complete » in « Mes informations » (the others are extras).
    var isKey: Bool {
        switch self {
        case .kcalTarget, .macroTargets, .routines, .weeklyWorkouts, .weight, .stepGoal, .habits, .hydrationGoal,
             .tasks, .timetable, .exams, .monthlyBudget, .bills, .businessGoal, .holdings, .trip, .carName, .birthday, .city:
            true
        default:
            false
        }
    }
}

extension InfoArea {
    var keyItems: [DataItem] { items.filter(\.isKey) }

    /// The questions of the first launch that go with this area (goal, level, height…), if any.
    var topic: ProfileTopic? {
        switch self {
        case .nutrition: .nutrition
        case .fitness: .sport
        case .budget: .money
        case .business: .business
        case .productivity: .productivity
        case .student: .studies
        case .car: .car
        case .habits: .wellbeing
        default: nil
        }
    }
}

extension AppModel {
    /// The areas « Mes informations » follows: the person's interests, plus any area they entered data in.
    var followedAreas: [InfoArea] {
        let preferred = profile.preferredSpaces.compactMap { InfoArea(rawValue: $0.rawValue) }
        // The followed companies come filled by default: that area joins only through an interest.
        let withData = InfoArea.allCases.filter { area in area != .general && area != .markets && area.items.contains(where: isFilled) && !preferred.contains(area) }
        var seen = Set<InfoArea>()
        return (preferred + withData).filter { seen.insert($0).inserted }
    }

    /// Key items given, over the key items of the followed areas and the general ones.
    var completion: (filled: Int, total: Int, missing: [DataItem]) {
        let items = (followedAreas + [.general]).flatMap(\.keyItems).filter { $0 != .city || !followedAreas.isEmpty }
        let missing = items.filter { !isFilled($0) }
        return (items.count - missing.count, items.count, missing)
    }
}

// MARK: - What each widget needs

extension WidgetKind {
    /// The data this widget shows from the person, in the order to ask for it.
    var dataItems: [DataItem] {
        switch self {
        case .clock, .calendar, .worldClock, .progress, .countdown, .yearDots, .weekView, .moonPhase, .note, .holiday, .focus, .crypto, .marketOverview, .studyHours, .semesterProgress:
            []
        case .ageProgress, .birthday: [.birthday]
        case .weather, .sunCycle, .rainNext, .windUV, .weatherDetails, .weeklyForecast: [.city]
        case .upNext: [.calendar]
        case .tasks: [.tasks]
        case .habits, .habitStreak, .habitWeek, .habitRate: [.habits]
        case .hydration: [.hydrationGoal]
        case .deepWork: [.focusGoal]
        case .priorities: [.priorities]
        case .project: [.projects]
        case .deadline: [.deadlines]
        case .counter: [.counters]
        case .caloriesLeft, .nextMeal: [.kcalTarget, .meals]
        case .macros, .proteinLeft: [.macroTargets, .meals]
        case .mealsToday, .nutritionWeek, .nutritionStreak, .quickFood: [.meals]
        case .todaysWorkout, .nextSet, .restTimer, .weeklyVolume, .personalRecords, .workoutMonth: [.routines]
        case .trainingStreak: [.routines, .weeklyWorkouts]
        case .caloriesBurned: [.routines, .weight]
        case .moneyFlow: [.moneyFlow]
        case .budgetLeft: [.monthlyBudget, .expenses]
        case .spendingByCategory, .quickExpense: [.expenses]
        case .billsUpcoming, .subscriptions: [.bills]
        case .savingsGoal: [.savingsGoals]
        case .netWorth: [.accounts]
        case .portfolio, .allocation, .topMover, .watchlist: [.holdings]
        case .revenueGoal: [.businessGoal, .sales]
        case .revenueTrend, .profit, .businessKPIs, .mrr, .revenueToday, .businessDashboard: [.sales]
        case .companySnapshot, .companyRevenue, .companyStock, .companyCompare: [.companies]
        case .nextClass, .timetable: [.timetable]
        case .nextExam: [.exams]
        case .assignments: [.assignments]
        case .gradeAverage: [.grades]
        case .flashcard: [.flashcards]
        case .tripCountdown, .flight, .hotel, .destinationWeather, .localTime, .currency, .tripProgress, .nextActivity: [.trip]
        case .carCost, .mileage, .fuelStats, .nextService: [.carName, .carFills]
        case .carDeadlines: [.carDeadlines]
        case .myDay: [.city, .calendar, .tasks, .kcalTarget]
        case .now: [.city, .tasks, .kcalTarget, .routines, .monthlyBudget]
        case .morning: [.city, .calendar, .priorities]
        case .fitnessDashboard: [.routines, .kcalTarget]
        case .moneyDashboard: [.monthlyBudget, .expenses]
        case .studentDashboard: [.timetable, .exams]
        case .aiSummary: [.kcalTarget, .tasks, .monthlyBudget]
        case .aiNutrition: [.kcalTarget, .meals]
        case .aiFinance: [.monthlyBudget, .expenses]
        case .aiProductivity: [.tasks, .priorities]
        }
    }

    /// A dashboard is useful as soon as one of its parts has data; any other widget needs all of them.
    var showsOwnDataWithAnyItem: Bool { category == .dashboards }
}

extension WidgetDesign {
    /// Everything this widget (or each widget inside a combined one) needs, each item once.
    var dataItems: [DataItem] {
        let kinds = isCombo ? options.parts.map(\.kind) : [kind]
        var seen = Set<DataItem>()
        return kinds.flatMap(\.dataItems).filter { seen.insert($0).inserted }
    }
}

extension Array where Element == WidgetDesign {
    /// The data a set of widgets needs (a pack, a Home Screen), each item once, in the widgets' order.
    var dataItems: [DataItem] {
        var seen = Set<DataItem>()
        return flatMap(\.dataItems).filter { seen.insert($0).inserted }
    }
}

// MARK: - What the person gave

extension AppModel {
    /// Whether the person gave this: a value set, a list with something in it, a log with at least
    /// one entry, an access granted. Defaults never count.
    func isFilled(_ item: DataItem) -> Bool {
        switch item {
        case .kcalTarget: profile.knows(.kcalTarget)
        case .macroTargets: profile.knows(.proteinTarget) || profile.knows(.carbsTarget) || profile.knows(.fatTarget)
        case .meals: !nutrition.entries.isEmpty
        case .routines: !fitness.routines.isEmpty
        case .weeklyWorkouts: profile.knows(.weeklyWorkouts)
        case .weight: profile.weightKg != nil
        case .stepGoal: profile.stepGoal != nil
        case .habits: !content.habits.isEmpty
        case .hydrationGoal: profile.knows(.hydrationGoal)
        case .tasks: !content.tasks.isEmpty
        case .priorities: !productivity.priorities.isEmpty
        case .projects: !productivity.projects.isEmpty
        case .deadlines: !productivity.deadlines.isEmpty
        case .counters: !productivity.counters.isEmpty
        case .focusGoal: profile.knows(.focusGoal)
        case .timetable: !student.courses.isEmpty && !student.slots.isEmpty
        case .exams: !student.exams.isEmpty
        case .assignments: !student.assignments.isEmpty
        case .grades: !student.grades.isEmpty
        case .flashcards: !student.cards.isEmpty
        case .monthlyBudget: profile.knows(.monthlyBudget)
        case .expenses: !budget.expenses.isEmpty
        case .bills: !budget.bills.isEmpty
        case .savingsGoals: !budget.goals.isEmpty
        case .accounts: !budget.accounts.isEmpty
        case .moneyFlow: !content.money.items.isEmpty
        case .businessGoal: profile.knows(.businessGoal)
        case .sales: !business.sales.isEmpty
        case .holdings: !portfolio.holdings.isEmpty
        case .companies: !following.followed.isEmpty
        case .trip: !travel.trips.isEmpty
        case .carName: profile.knows(.carName)
        case .carFills: !car.fills.isEmpty
        case .carDeadlines: !car.deadlines.isEmpty
        case .birthday: life.birthday != nil
        case .city: settings.weatherLocation != nil
        case .calendar: CalendarService.hasAccess
        }
    }

    /// What is known, in a few words (« 2 500 kcal », « 3 séances »), or nil when nothing is.
    func summary(_ item: DataItem, now: Date = Date()) -> String? {
        guard isFilled(item) else { return nil }
        let currency = settings.currencyCode
        switch item {
        case .kcalTarget: return tr("\(TF.int(nutrition.goals.kcal)) kcal par jour")
        case .macroTargets:
            var parts: [String] = []
            if profile.knows(.proteinTarget) { parts.append("P \(TF.int(nutrition.goals.protein)) g") }
            if profile.knows(.carbsTarget) { parts.append("G \(TF.int(nutrition.goals.carbs)) g") }
            if profile.knows(.fatTarget) { parts.append("L \(TF.int(nutrition.goals.fat)) g") }
            return parts.joined(separator: " · ")
        case .meals:
            let today = NutritionMath.entries(nutrition, on: now).count
            return today == 0 ? tr("Rien noté aujourd'hui") : Fmt.plural(today, tr("aliment noté aujourd'hui"), tr("aliments notés aujourd'hui"))
        case .routines: return Fmt.plural(fitness.routines.count, tr("séance"), tr("séances"))
        case .weeklyWorkouts: return tr("\(fitness.weeklyGoal) par semaine")
        case .weight: return profile.weightKg.map { tr("\(ProfileNumberField.format($0)) kg") }
        case .stepGoal: return profile.stepGoal.map { tr("\(Fmt.number($0)) pas") }
        case .habits: return Fmt.plural(content.habits.count, tr("habitude"), tr("habitudes"))
        case .hydrationGoal: return Fmt.plural(content.hydration.goal, tr("verre par jour"), tr("verres par jour"))
        case .tasks:
            let open = content.tasks.filter { !$0.isDone }.count
            return Fmt.plural(open, tr("tâche à faire"), tr("tâches à faire"))
        case .priorities: return Fmt.plural(productivity.priorities.count, tr("priorité"), tr("priorités"))
        case .projects: return Fmt.plural(productivity.projects.count, tr("projet"), tr("projets"))
        case .deadlines: return Fmt.plural(productivity.deadlines.count, tr("échéance"), tr("échéances"))
        case .counters: return Fmt.plural(productivity.counters.count, tr("compteur"), tr("compteurs"))
        case .focusGoal: return tr("\(Fmt.hours(productivity.weeklyFocusGoalHours)) par semaine")
        case .timetable: return Fmt.plural(student.courses.count, tr("cours", context: "one"), tr("cours"))
        case .exams:
            let next = student.exams.filter { $0.date > now }.count
            return next == 0 ? tr("Aucun à venir") : Fmt.plural(next, tr("examen à venir"), tr("examens à venir"))
        case .assignments:
            let open = student.assignments.filter { !$0.isDone }.count
            return Fmt.plural(open, tr("devoir à rendre"), tr("devoirs à rendre"))
        case .grades: return Fmt.plural(student.grades.count, tr("note"), tr("notes"))
        case .flashcards: return Fmt.plural(student.cards.count, tr("fiche"), tr("fiches"))
        case .monthlyBudget: return tr("\(TF.money(budget.monthlyBudget, currency)) par mois")
        case .expenses: return tr("\(TF.money(BudgetMath.spentToday(budget, at: now), currency)) aujourd'hui")
        case .bills: return Fmt.plural(budget.bills.count, tr("facture"), tr("factures"))
        case .savingsGoals: return Fmt.plural(budget.goals.count, tr("objectif"), tr("objectifs"))
        case .accounts: return Fmt.plural(budget.accounts.count, tr("compte"), tr("comptes"))
        case .moneyFlow: return Fmt.plural(content.money.items.count, tr("ligne"), tr("lignes"))
        case .businessGoal: return tr("\(TF.money(business.monthlyGoal, currency)) par mois")
        case .sales: return Fmt.plural(business.sales.count, tr("vente notée"), tr("ventes notées"))
        case .holdings: return Fmt.plural(portfolio.holdings.count, tr("placement"), tr("placements"))
        case .companies: return Fmt.plural(following.followed.count, tr("entreprise"), tr("entreprises"))
        case .trip:
            let next = travel.trips.filter { $0.end >= now }.min { $0.start < $1.start }
            return next.map { "\($0.destination), \(Fmt.shortDay($0.start))" } ?? Fmt.plural(travel.trips.count, tr("voyage"), tr("voyages"))
        case .carName: return odometer.map { tr("\(car.name) · \(TF.int($0)) km") } ?? car.name
        case .carFills: return Fmt.plural(car.fills.count, tr("plein"), tr("pleins"))
        case .carDeadlines: return Fmt.plural(car.deadlines.count, tr("échéance"), tr("échéances"))
        case .birthday: return life.birthday.map { Fmt.format($0, template: "dMMMM") }
        case .city: return settings.weatherLocation?.name
        case .calendar: return tr("Accès autorisé")
        }
    }

    /// Whether a widget can show the person's own data: every item it needs is given (for a
    /// dashboard, one is enough). A widget that needs nothing always shows its own content.
    func hasOwnData(for design: WidgetDesign) -> Bool {
        let items = design.dataItems
        guard !items.isEmpty else { return true }
        // Daily logs (meals, expenses…) don't hold a widget back once its settings are given:
        // « 2 500 kcal restantes » with nothing eaten yet is the person's own data.
        let settings = items.filter(\.countsAsMissing)
        guard !settings.isEmpty else { return items.contains(where: isFilled) }
        let anyIsEnough = design.isCombo ? false : design.kind.showsOwnDataWithAnyItem
        return anyIsEnough ? settings.contains(where: isFilled) : settings.allSatisfy(isFilled)
    }

    /// What a preview shows: the person's data once they gave it, clearly marked example data before.
    func previewPayload(for design: WidgetDesign) -> WidgetPayload {
        hasOwnData(for: design) ? payload(for: design) : SamplePayload.make(for: design)
    }

    /// How many items still to give, among those that count (not the daily logs).
    func missingItems(_ items: [DataItem]) -> [DataItem] {
        items.filter { $0.countsAsMissing && !isFilled($0) }
    }
}
