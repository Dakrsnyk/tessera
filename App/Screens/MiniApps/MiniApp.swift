import SwiftUI

/// The mini-apps reached from Home: each one is a whole part of Tessera (a dashboard, then its
/// sections), built on the same data as the widgets, « Mes informations » and the spaces of Créer.
enum MiniApp: String, CaseIterable, Identifiable, Hashable {
    case nutrition, fitness, planning, finances, business, travel, car, weather
    var id: String { rawValue }

    var title: String {
        switch self {
        case .nutrition: tr("Nutrition")
        case .fitness: tr("Fitness")
        case .planning: tr("Planning")
        case .finances: tr("Finances")
        case .business: tr("Business")
        case .travel: tr("Voyage")
        case .car: tr("Auto")
        case .weather: tr("Météo")
        }
    }

    var symbol: String {
        switch self {
        case .nutrition: "fork.knife"
        case .fitness: "dumbbell.fill"
        case .planning: "calendar"
        case .finances: "creditcard.fill"
        case .business: "briefcase.fill"
        case .travel: "airplane"
        case .car: "car.fill"
        case .weather: "cloud.sun.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .nutrition: "F08A24"
        case .fitness: "E5484D"
        case .planning: "3366FF"
        case .finances: "2F8F7A"
        case .business: "8C6CFF"
        case .travel: "12A4B5"
        case .car: "6B7280"
        case .weather: "3A8DDE"
        }
    }

    var color: Color { Color(hex: colorHex) }

    /// The space of Créer holding the same data (its widgets are made there).
    var space: Space? {
        switch self {
        case .nutrition: .nutrition
        case .fitness: .fitness
        case .planning: .productivity
        case .finances: .budget
        case .business: .business
        case .travel: .travel
        case .car: .car
        case .weather: nil
        }
    }

    /// Every mini-app is built; kept so a new one can open its space's data until it is.
    var isBuilt: Bool { true }

    init?(space: Space) {
        // Studies live in Planning now (schedule, classes, exams, homework, grades, cards).
        if space == .student {
            self = .planning
            return
        }
        guard let app = MiniApp.allCases.first(where: { $0.space == space }) else { return nil }
        self = app
    }
}

/// The detailed pages of the mini-apps (level 4), pushed on the Home stack so « back » always
/// returns where the person was.
enum MiniAppPage: Hashable {
    case nutritionDay(Date)
    case nutritionMeal(MealType, Date)
    case nutritionNutrients(Date)
    case nutritionIdeas
    case nutritionHistory
    case nutritionSavedMeals
    case fitnessSession
    case fitnessProgram
    case fitnessLibrary
    case fitnessExercise(String)
    case fitnessHistory
    case fitnessSessionDetail(UUID)
    case fitnessProgress
    case fitnessActivity
    case planningTasks
    case planningWeek
    case planningMonth
    case planningProjects
    case planningHabits
    case planningFocus
    /// Studies inside Planning: the next class, homework, exams, the average and the cards.
    case studiesHome
    case studiesTimetable
    case studiesCourses
    case studiesCourse(UUID)
    case studiesExams
    case studiesAssignments
    case studiesGrades
    case studiesRevision
    case financesTransactions
    case financesCategories
    case financesBills
    case financesSavings
    case financesTrends
    case businessSales
    case businessResults
    case businessRecurring
    case businessMetrics
    case travelProgram(UUID)
    case travelBudget(UUID)
    case travelChecklist(UUID)
    case carFuel
    case carMileage
    case carMaintenance
    case carDeadlines
    case carCosts
}

/// A mini-app, or its space's data while it isn't built yet.
struct MiniAppView: View {
    let app: MiniApp

    var body: some View {
        content
            .onAppear { MiniAppUsage.record(app) }
    }

    @ViewBuilder
    private var content: some View {
        switch app {
        case .nutrition:
            NutritionAppView()
        case .fitness:
            FitnessAppView()
        case .planning:
            PlanningAppView()
        case .finances:
            FinancesAppView()
        case .business:
            BusinessAppView()
        case .travel:
            TravelAppView()
        case .car:
            CarAppView()
        case .weather:
            WeatherAppView()
        }
    }
}

struct MiniAppPageView: View {
    let page: MiniAppPage

    var body: some View {
        switch page {
        case let .nutritionDay(day): NutritionAppView(day: day)
        case let .nutritionMeal(meal, day): NutritionMealPage(meal: meal, day: day)
        case let .nutritionNutrients(day): NutritionNutrientsPage(day: day)
        case .nutritionIdeas: NutritionIdeasPage()
        case .nutritionHistory: NutritionHistoryPage()
        case .nutritionSavedMeals: NutritionSavedMealsPage()
        case .fitnessSession: FitnessSessionPage()
        case .fitnessProgram: FitnessProgramPage()
        case .fitnessLibrary: ExerciseLibraryPage()
        case let .fitnessExercise(id):
            if let exercise = ExerciseLibrary.info(id) {
                ExerciseDetailView(exercise: exercise)
            } else {
                ContentUnavailableView(tr("Exercice introuvable"), systemImage: "dumbbell")
            }
        case .fitnessHistory: FitnessHistoryPage()
        case let .fitnessSessionDetail(id): FitnessSessionDetailPage(sessionID: id)
        case .fitnessProgress: FitnessProgressPage()
        case .fitnessActivity: FitnessActivityPage()
        case .planningTasks: PlanningTasksPage()
        case .planningWeek: PlanningWeekPage()
        case .planningMonth: PlanningMonthPage()
        case .planningProjects: PlanningProjectsPage()
        case .planningHabits: PlanningHabitsPage()
        case .planningFocus: PlanningFocusPage()
        case .studiesHome: StudiesAppView()
        case .studiesTimetable: StudiesTimetablePage()
        case .studiesCourses: StudiesCoursesPage()
        case let .studiesCourse(id): StudiesCoursePage(courseID: id)
        case .studiesExams: StudiesExamsPage()
        case .studiesAssignments: StudiesAssignmentsPage()
        case .studiesGrades: StudiesGradesPage()
        case .studiesRevision: StudiesRevisionPage()
        case .financesTransactions: FinancesTransactionsPage()
        case .financesCategories: FinancesCategoriesPage()
        case .financesBills: FinancesBillsPage()
        case .financesSavings: FinancesSavingsPage()
        case .financesTrends: FinancesTrendsPage()
        case .businessSales: BusinessSalesPage()
        case .businessResults: BusinessResultsPage()
        case .businessRecurring: BusinessRecurringPage()
        case .businessMetrics: BusinessMetricsPage()
        case let .travelProgram(id): TravelProgramPage(tripID: id)
        case let .travelBudget(id): TravelBudgetPage(tripID: id)
        case let .travelChecklist(id): TravelChecklistPage(tripID: id)
        case .carFuel: CarFuelPage()
        case .carMileage: CarMileagePage()
        case .carMaintenance: CarMaintenancePage()
        case .carDeadlines: CarDeadlinesPage()
        case .carCosts: CarCostsPage()
        }
    }
}

// MARK: - Shared pieces

/// The frame every mini-app screen shares: its background, spacing and margins.
struct MiniAppScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .background(.screenGradient)
        .screenshotScroll()
    }
}

/// A section title inside a mini-app, with an optional link on the right.
struct MiniSectionTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A tappable row inside a card: an icon in a tinted circle, a title, a detail and a value.
struct MiniRow: View {
    let symbol: String
    let colorHex: String
    let title: String
    var detail: String?
    var value: String?
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: colorHex))
                .frame(width: 34, height: 34)
                .background(Color(hex: colorHex).opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Rows stacked in one card with hairlines between them.
struct MiniRowsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// A big colored action, or a softer one beside it.
struct MiniActionButton: View {
    let title: String
    let symbol: String
    let colorHex: String
    var isProminent = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(isProminent ? Color.white : Color(hex: colorHex))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(isProminent ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A figure with its label, for the stat grids of the mini-apps.
struct MiniStat: View {
    let title: String
    let value: String
    var unit: String?
    var detail: String?
    var colorHex: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(colorHex.map { Color(hex: $0) } ?? Color.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A hairline between the rows of a card.
struct MiniDivider: View {
    var body: some View {
        Divider().padding(.leading, 46)
    }
}

/// Moves between days without leaving the screen: the day before, the day after, any date from the
/// calendar (a touch on the date), and back to today. Logs (meals, habits) stop at today; plans
/// (agenda, tasks, program) look ahead too.
struct DaySwitcher: View {
    @Binding var day: Date
    var colorHex = "F08A24"
    var allowsFuture = false
    @State private var picking = false

    private var isToday: Bool { DateMath.isSameDay(day, Date()) }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                move(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 40, height: 36)
            }
            .accessibilityLabel(Text(tr("Jour précédent")))
            Button {
                picking = true
            } label: {
                HStack(spacing: 4) {
                    Text(title)
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .opacity(0.6)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .accessibilityLabel(Text(tr("Choisir une date")))
            .accessibilityValue(Text(title))
            if !isToday {
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { day = Date() }
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption.weight(.bold))
                        .frame(width: 32, height: 36)
                }
                .accessibilityLabel(Text(tr("Revenir à aujourd'hui")))
                .transition(.scale.combined(with: .opacity))
            }
            Button {
                move(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 40, height: 36)
            }
            .disabled(isToday && !allowsFuture)
            .accessibilityLabel(Text(tr("Jour suivant")))
        }
        .foregroundStyle(Color(hex: colorHex))
        .background(.cardFill, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-switcher")
        .sheet(isPresented: $picking) {
            NavigationStack {
                DatePicker(tr("Date"), selection: Binding(get: { day }, set: { day = $0; picking = false }),
                           in: allowsFuture ? Date.distantPast...Date.distantFuture : Date.distantPast...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Color(hex: colorHex))
                    .environment(\.locale, Fmt.locale)
                    .padding(.horizontal)
                    .navigationTitle(tr("Choisir une date"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(tr("Aujourd'hui")) {
                                day = Date()
                                picking = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(tr("OK")) { picking = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var title: String {
        if isToday { return tr("Aujourd'hui") }
        let calendar = DateMath.calendar
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()), DateMath.isSameDay(day, yesterday) { return tr("Hier") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()), DateMath.isSameDay(day, tomorrow) { return tr("Demain") }
        return Fmt.longDay(day)
    }

    private func move(_ days: Int) {
        guard let next = DateMath.calendar.date(byAdding: .day, value: days, to: day) else { return }
        Haptics.tap()
        withAnimation(.snappy) { day = allowsFuture ? next : min(next, Date()) }
    }
}
