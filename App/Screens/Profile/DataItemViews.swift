import SwiftUI

extension AppModel {
    func setStepGoal(_ steps: Int?) {
        update(\.profile) { $0.stepGoal = steps }
    }
}

/// The data a widget (or a pack, or a space) needs, asked right where it's made. Everything typed
/// here goes to the one place Tessera keeps it: every widget, « Mon Quotidien » and « Mes informations »
/// read it from there.
struct WidgetDataSection: View {
    let items: [DataItem]
    var title = tr("Tes données")
    @Environment(AppModel.self) private var model

    var body: some View {
        let missing = model.missingItems(items).count
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(missing == 0 ? tr("Tout est renseigné") : Fmt.plural(missing, tr("à renseigner"), tr("à renseigner")))
                    .font(.footnote.weight(missing == 0 ? .regular : .semibold))
                    .foregroundStyle(missing == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color(light: "8A4B00", dark: "F5B25A")))
            }
            Text(tr("Renseignées une fois, elles servent à tous tes widgets et à « Mon Quotidien »."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                ForEach(items) { item in
                    DataItemRow(item: item)
                }
            }
        }
        .hostsSpaceSheets()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("widget-data")
    }
}

/// One piece of data: what it is, whether it's given, and the way to give it.
struct DataItemRow: View {
    let item: DataItem
    @Environment(AppModel.self) private var model
    @Environment(SpaceSheets.self) private var sheets: SpaceSheets?
    @State private var newText = ""
    @State private var showsCityPicker = false
    private var stepCounter: StepCounter { .shared }

    var body: some View {
        let isFilled = model.isFilled(item)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: item.area.colorHex), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    Text(model.summary(item) ?? item.purpose)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if isFilled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel(Text(tr("Renseigné")))
                } else if item.countsAsMissing {
                    Text(tr("À renseigner"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(light: "8A4B00", dark: "F5B25A"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(light: "FCE8CC", dark: "4A3314"), in: Capsule())
                }
            }
            editor
        }
        .padding(14)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("data-\(item.rawValue)")
        .sheet(isPresented: $showsCityPicker) {
            NavigationStack {
                WeatherLocationView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(tr("OK")) { showsCityPicker = false }
                        }
                    }
            }
        }
    }

    // MARK: Editors

    @ViewBuilder private var editor: some View {
        let now = Date()
        switch item {
        case .kcalTarget:
            VStack(alignment: .leading, spacing: 8) {
                ProfileNumberField(title: tr("Calories par jour"), unit: "kcal", value: target(.kcalTarget, \.kcal), decimals: false, identifier: "data-kcal")
                action(tr("Calculer pour moi"), symbol: "wand.and.stars") { sheets?.open { TopicEditorSheet(topic: .nutrition) } }
            }
        case .macroTargets:
            HStack(spacing: 8) {
                ProfileNumberField(title: tr("Protéines"), unit: "g", value: target(.proteinTarget, \.protein), decimals: false, identifier: "data-protein")
                ProfileNumberField(title: tr("Glucides"), unit: "g", value: target(.carbsTarget, \.carbs), decimals: false, identifier: "data-carbs")
                ProfileNumberField(title: tr("Lipides"), unit: "g", value: target(.fatTarget, \.fat), decimals: false, identifier: "data-fat")
            }
        case .meals:
            HStack(spacing: 8) {
                action(tr("Scanner"), symbol: "barcode.viewfinder", prominent: true) { sheets?.open { FoodSearchView(startsWithScanner: true) } }
                action(tr("Chercher"), symbol: "magnifyingglass") { sheets?.open { FoodSearchView() } }
            }
        case .routines:
            buttons(add: tr("Créer une séance"), space: model.isFilled(.routines) ? .fitness : nil) {
                sheets?.open { RoutineEditor(routine: Routine(name: "", exercises: [ExerciseTemplate(name: "", sets: 3, reps: 10, weight: 0)])) }
            }
        case .weeklyWorkouts:
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { count in
                    let isOn = model.profile.knows(.weeklyWorkouts) && model.fitness.weeklyGoal == count
                    chip("\(count)", isOn: isOn) {
                        if isOn { model.forget(.weeklyWorkouts) } else { model.setWeeklyWorkouts(count) }
                    }
                    .accessibilityLabel(Text(Fmt.plural(count, tr("séance"), tr("séances"))))
                }
            }
        case .weight:
            ProfileNumberField(title: tr("Poids"), unit: tr("kg"), value: Binding(get: { model.profile.weightKg }, set: { model.setWeight($0) }), identifier: "data-weight")
        case .stepGoal:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach([6_000, 8_000, 10_000, 12_000], id: \.self) { steps in
                        let isOn = model.profile.stepGoal == steps
                        chip(Fmt.number(steps), isOn: isOn) { model.setStepGoal(isOn ? nil : steps) }
                    }
                }
                stepsAccess
            }
        case .habits:
            VStack(spacing: 8) {
                quickAdd(tr("Ex. : méditer, lire, marcher"), identifier: "data-new-habit") {
                    guard model.canAddHabit else { return }
                    model.updateContent { $0.habits.append(Habit(name: newText.trimmed, symbol: "checkmark.circle", colorHex: "7FA33A")) }
                }
                if model.isFilled(.habits) { link(tr("Gérer mes habitudes")) { HabitsView() } }
            }
        case .hydrationGoal:
            HStack(spacing: 6) {
                ForEach([4, 6, 8, 10, 12], id: \.self) { glasses in
                    let isOn = model.profile.knows(.hydrationGoal) && model.content.hydration.goal == glasses
                    chip("\(glasses)", isOn: isOn) {
                        if isOn { model.forget(.hydrationGoal) } else { model.setHydrationGoal(glasses) }
                    }
                }
            }
        case .tasks:
            VStack(spacing: 8) {
                quickAdd(tr("Ex. : appeler le garage"), identifier: "data-new-task") {
                    model.updateContent { $0.tasks.append(TaskItem(title: newText.trimmed)) }
                }
                if model.isFilled(.tasks) { link(tr("Gérer mes tâches")) { TasksView() } }
            }
        case .priorities:
            link(model.isFilled(.priorities) ? tr("Voir mon top 3") : tr("Choisir mon top 3 du jour")) { SpaceView(space: .productivity, isEmbedded: true) }
        case .projects:
            buttons(add: tr("Nouveau projet"), space: model.isFilled(.projects) ? .productivity : nil) {
                sheets?.open { ProjectEditor(project: Project(name: "")) }
            }
        case .deadlines:
            buttons(add: tr("Nouvelle échéance"), space: model.isFilled(.deadlines) ? .productivity : nil) {
                sheets?.open { DeadlineEditor(deadline: Deadline(title: "", date: now.addingTimeInterval(3 * 86_400))) }
            }
        case .counters:
            buttons(add: tr("Nouveau compteur"), space: model.isFilled(.counters) ? .productivity : nil) {
                sheets?.open { CounterEditor(counter: CounterItem(name: "")) }
            }
        case .focusGoal:
            ProfileNumberField(
                title: tr("Concentration"), unit: tr("h par semaine"),
                value: Binding(
                    get: { model.profile.knows(.focusGoal) ? model.productivity.weeklyFocusGoalHours : nil },
                    set: { value in if let value { model.setFocusGoal(value) } else { model.forget(.focusGoal) } }
                ),
                identifier: "data-focus"
            )
        case .timetable:
            HStack(spacing: 8) {
                action(tr("Nouveau cours"), symbol: "plus") { sheets?.open { CourseEditor(course: Course(name: "")) } }
                if !model.student.courses.isEmpty {
                    action(tr("Ajouter un horaire"), symbol: "clock") {
                        let courseID = model.student.courses.first?.id
                        sheets?.open { SlotEditor(slot: ClassSlot(courseID: courseID, weekday: FitnessMath.isoWeekday(now), startMinute: 8 * 60 + 30, endMinute: 10 * 60 + 20)) }
                    }
                }
            }
        case .exams:
            buttons(add: tr("Nouvel examen"), space: model.isFilled(.exams) ? .student : nil) {
                let courseID = model.student.courses.first?.id
                sheets?.open { ExamEditor(exam: Exam(courseID: courseID, title: "", date: now.addingTimeInterval(7 * 86_400))) }
            }
        case .assignments:
            buttons(add: tr("Nouveau devoir"), space: model.isFilled(.assignments) ? .student : nil) {
                let courseID = model.student.courses.first?.id
                sheets?.open { AssignmentEditor(assignment: Assignment(courseID: courseID, title: "", due: now.addingTimeInterval(3 * 86_400))) }
            }
        case .grades:
            buttons(add: tr("Nouvelle note"), space: model.isFilled(.grades) ? .student : nil) {
                let courseID = model.student.courses.first?.id
                sheets?.open { GradeEditor(grade: Grade(courseID: courseID, title: "", score: 0)) }
            }
        case .flashcards:
            buttons(add: tr("Nouvelle fiche"), space: model.isFilled(.flashcards) ? .student : nil) {
                sheets?.open { CardEditor(card: Flashcard(front: "", back: "")) }
            }
        case .monthlyBudget:
            ProfileNumberField(
                title: tr("Budget"), unit: UnitText.display(model.settings.currencyCode),
                value: Binding(
                    get: { model.profile.knows(.monthlyBudget) ? model.budget.monthlyBudget : nil },
                    set: { value in if let value { model.setMonthlyBudget(value) } else { model.forget(.monthlyBudget) } }
                ),
                decimals: false, identifier: "data-budget"
            )
        case .expenses:
            action(tr("Ajouter une dépense"), symbol: "plus", prominent: true) { sheets?.open { ExpenseEditor() } }
        case .bills:
            buttons(add: tr("Nouvelle facture"), space: model.isFilled(.bills) ? .budget : nil) {
                sheets?.open { BillEditor(bill: Bill(name: "", amount: 0, anchorDate: now)) }
            }
        case .savingsGoals:
            buttons(add: tr("Nouvel objectif"), space: model.isFilled(.savingsGoals) ? .budget : nil) {
                sheets?.open { GoalEditor(goal: SavingsGoal(name: "", target: 1_000, saved: 0, deadline: nil)) }
            }
        case .accounts:
            buttons(add: tr("Nouveau compte"), space: model.isFilled(.accounts) ? .budget : nil) {
                sheets?.open { AccountEditor(account: Account(name: "", balance: 0)) }
            }
        case .moneyFlow:
            link(model.isFilled(.moneyFlow) ? tr("Gérer mes revenus et dépenses") : tr("Ajouter mon salaire et mes dépenses fixes")) { MoneyView() }
        case .businessGoal:
            ProfileNumberField(
                title: tr("Chaque mois"), unit: UnitText.display(model.settings.currencyCode),
                value: Binding(
                    get: { model.profile.knows(.businessGoal) ? model.business.monthlyGoal : nil },
                    set: { value in if let value { model.setBusinessGoal(value) } else { model.forget(.businessGoal) } }
                ),
                decimals: false, identifier: "data-business-goal"
            )
        case .sales:
            action(tr("Noter une vente"), symbol: "plus", prominent: true) { sheets?.open { SaleEditor() } }
        case .holdings:
            buttons(add: tr("Nouveau placement"), space: model.isFilled(.holdings) ? .investing : nil) {
                sheets?.open { HoldingEditor(holding: Holding(kind: .etf, name: "", symbol: "", quantity: 0, costBasis: 0)) }
            }
        case .companies:
            link(tr("Choisir les entreprises suivies")) { SpaceView(space: .markets, isEmbedded: true) }
        case .trip:
            buttons(add: tr("Nouveau voyage"), space: model.isFilled(.trip) ? .travel : nil) {
                sheets?.open { TripEditor(trip: Trip(destination: "", start: now.addingTimeInterval(30 * 86_400), end: now.addingTimeInterval(37 * 86_400))) }
            }
        case .carName:
            VStack(spacing: 8) {
                ProfileTextField(
                    placeholder: tr("Marque et modèle"),
                    text: Binding(
                        get: { model.profile.knows(.carName) ? model.car.name : "" },
                        set: { name in if name.trimmed.isEmpty { model.forget(.carName) } else { model.setCarName(name) } }
                    ),
                    identifier: "data-car-name"
                )
                ProfileNumberField(title: tr("Compteur"), unit: tr("km"), value: Binding(get: { model.odometer }, set: { model.setOdometer($0) }), decimals: false, identifier: "data-car-km")
            }
        case .carFills:
            action(tr("Noter un plein"), symbol: "fuelpump", prominent: true) { sheets?.open { FuelEditor() } }
        case .carDeadlines:
            buttons(add: tr("Nouvelle échéance"), space: model.isFilled(.carDeadlines) ? .car : nil) {
                sheets?.open { CarDeadlineEditor(deadline: CarDeadline(title: "", date: now.addingTimeInterval(60 * 86_400))) }
            }
        case .birthday:
            if let birthday = model.life.birthday {
                DatePicker(tr("Date de naissance"), selection: Binding(get: { birthday }, set: { date in model.update(\.life) { $0.birthday = date } }), in: ...now, displayedComponents: .date)
                    .font(.subheadline)
                    .environment(\.locale, Fmt.locale)
            } else {
                action(tr("Ajouter ma date de naissance"), symbol: "plus") {
                    model.update(\.life) { $0.birthday = Holidays.make(2000, 1, 1) }
                }
            }
        case .city:
            action(model.settings.weatherLocation?.name ?? tr("Choisir ma ville"), symbol: "location.fill", prominent: !model.isFilled(.city)) {
                showsCityPicker = true
            }
        case .calendar:
            CalendarAccessRow()
        }
    }

    private func target(_ fact: ProvidedFact, _ keyPath: WritableKeyPath<NutritionGoals, Double>) -> Binding<Double?> {
        Binding(
            get: { model.profile.knows(fact) ? model.nutrition.goals[keyPath: keyPath] : nil },
            set: { value in
                guard let value else {
                    model.forget(fact)
                    return
                }
                switch fact {
                case .kcalTarget: model.setNutritionTargets(kcal: value)
                case .proteinTarget: model.setNutritionTargets(protein: value)
                case .carbsTarget: model.setNutritionTargets(carbs: value)
                default: model.setNutritionTargets(fat: value)
                }
            }
        )
    }

    @ViewBuilder private var stepsAccess: some View {
        switch stepCounter.status {
        case .allowed:
            Label(stepCounter.stepsToday.map { tr("\(Fmt.number($0)) pas aujourd'hui") } ?? tr("Accès autorisé"), systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .notAsked:
            action(tr("Afficher mes pas"), symbol: "figure.walk") {
                Task { await stepCounter.refresh(asking: true) }
            }
        case .denied:
            Text(tr("L'accès aux mouvements est désactivé : Réglages › Tessera › Mouvements et forme."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .unavailable:
            Text(tr("Cet appareil ne compte pas les pas."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Pieces

    private func action(_ title: String, symbol: String, prominent: Bool = false, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(prominent ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.accentColor))
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(prominent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.accentColor.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Add one more, and see everything in the space once there is something.
    private func buttons(add title: String, space: Space?, run: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            action(title, symbol: "plus", prominent: space == nil, run: run)
            if let space {
                NavigationLink {
                    SpaceView(space: space, isEmbedded: true)
                } label: {
                    Text(tr("Tout voir"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func link<Destination: View>(_ title: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isOn ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.primary))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(AppFill.screenFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func quickAdd(_ placeholder: String, identifier: String, add: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            ProfileTextField(placeholder: placeholder, text: $newText, identifier: identifier)
                .onSubmit {
                    guard !newText.trimmed.isEmpty else { return }
                    add()
                    newText = ""
                }
            Button {
                guard !newText.trimmed.isEmpty else { return }
                add()
                newText = ""
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(newText.trimmed.isEmpty)
            .accessibilityLabel(Text(tr("Ajouter")))
        }
    }
}

/// Marks a preview that shows example data, not the person's own.
struct ExampleBadge: View {
    var body: some View {
        Label(tr("Exemple"), systemImage: "sparkles")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.45), in: Capsule())
            .accessibilityLabel(Text(tr("Aperçu avec des données d'exemple")))
    }
}
