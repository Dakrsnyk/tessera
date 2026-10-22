import SwiftUI

// The questions of « Mes informations », one page per topic. The same page is used by the first-launch
// onboarding and by « Mes informations » on the Home tab, and every answer is saved as it is given,
// in the one place that value lives (see `UserProfile`). Nothing is required: an empty field stays unknown.

// MARK: - Building blocks

/// Lays out chips left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let rows = arrange(subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Item {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat = 0
        var items: [Item] = []
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row(y: 0)
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
                x = 0
            }
            current.items.append(Item(index: index, x: x, size: size))
            current.height = max(current.height, size.height)
            x += size.width + spacing
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

/// A capsule that can be selected.
struct ChoiceChip: View {
    let title: String
    var symbol: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.caption.weight(.semibold))
                }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.primary))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(AppFill.screenFill), in: Capsule())
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

/// One question of a page: its label above, the answer below, on a card.
struct QuestionCard<Content: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .card(padding: 14)
    }
}

/// A number the user may leave empty (unknown), saved as it is typed.
struct ProfileNumberField: View {
    let title: String
    let unit: String
    @Binding var value: Double?
    var decimals = true
    var placeholder = "—"
    var identifier: String?
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField(placeholder, text: $text)
                    .keyboardType(decimals ? .decimalPad : .numberPad)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityLabel(Text(title))
                    .accessibilityIdentifier(identifier ?? title)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { text = Self.format(value) }
        .onChange(of: text) { _, newText in
            let parsed = Self.parse(newText)
            if parsed != value { value = parsed }
        }
        .onChange(of: value) { _, newValue in
            // Updated from elsewhere (a calculation): show it, without fighting the typing.
            if Self.parse(text) != newValue { text = Self.format(newValue) }
        }
    }

    static func parse(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\u{202F}", with: "")
        guard let number = Double(cleaned), number.isFinite, number > 0 else { return nil }
        return number
    }

    static func format(_ value: Double?) -> String {
        guard let value else { return "" }
        if value.rounded() == value { return String(Int(safely: value)) }
        return String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}

/// A short text the user may leave empty, saved as it is typed.
struct ProfileTextField: View {
    let placeholder: String
    @Binding var text: String
    var identifier: String?

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.body.weight(.medium))
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .padding(12)
            .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier(identifier ?? placeholder)
    }
}

// MARK: - Gender

/// The gender, always visible with the current choice highlighted, so a wrong tap can be fixed.
/// Tapping the chosen answer again clears it. Non-binary answers pick the reference used by the
/// calorie formula (the average by default).
struct GenderPicker: View {
    @Environment(AppModel.self) private var model

    private var profile: UserProfile { model.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Genre"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout {
                ForEach(BodySex.allCases) { sex in
                    ChoiceChip(title: sex.title, isSelected: profile.sex == sex) {
                        model.update(\.profile) { $0.sex = $0.sex == sex ? nil : sex }
                    }
                    .accessibilityIdentifier("gender-\(sex.rawValue)")
                }
            }
            if profile.sex == .other {
                ProfileTextField(placeholder: tr("Précise si tu veux (facultatif)"), text: Binding(
                    get: { model.profile.genderDetail },
                    set: { value in model.update(\.profile) { $0.genderDetail = value } }
                ), identifier: "gender-detail")
            }
            if let sex = profile.sex, !sex.isBinary {
                Text(tr("Pour estimer tes calories, Ardane utilise :"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                FlowLayout {
                    ForEach([NutritionCalculator.Sex.neutral, .female, .male]) { reference in
                        ChoiceChip(title: reference.title, isSelected: (profile.calculationSex ?? .neutral) == reference) {
                            model.update(\.profile) { $0.calculationSex = reference == .neutral ? nil : reference }
                        }
                        .accessibilityIdentifier("gender-reference-\(reference.rawValue)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - A topic's questions

struct TopicForm: View {
    let topic: ProfileTopic
    /// Inside a mini-app (« Mes infos »): the questions only, without the « first task / first habit » the
    /// mini-app already lets the person add on its page.
    var inMiniApp = false
    @Environment(AppModel.self) private var model
    @State private var newTask = ""
    @State private var newHabit = ""
    @State private var showsCityPicker = false
    @State private var asksBody = false

    var body: some View {
        VStack(spacing: 12) {
            switch topic {
            case .sport: sport
            case .nutrition: nutrition
            case .money: money
            case .business: business
            case .productivity: productivity
            case .studies: studies
            case .car: car
            case .weather: weather
            case .wellbeing: wellbeing
            }
        }
        .onAppear {
            if model.age == nil || profile.heightCm == nil || profile.weightKg == nil { asksBody = true }
        }
    }

    // MARK: Shared answers

    private var profile: UserProfile { model.profile }

    private func profileBinding<Value>(_ keyPath: WritableKeyPath<UserProfile, Value>) -> Binding<Value> {
        Binding(get: { model.profile[keyPath: keyPath] }, set: { value in model.update(\.profile) { $0[keyPath: keyPath] = value } })
    }

    /// A choice that can be taken back by tapping it again.
    private func toggle<Value: Equatable>(_ keyPath: WritableKeyPath<UserProfile, Value?>, _ value: Value) {
        model.update(\.profile) { $0[keyPath: keyPath] = $0[keyPath: keyPath] == value ? nil : value }
    }

    private var ageBinding: Binding<Double?> {
        Binding(get: { model.age.map { Double($0) } }, set: { model.setAge($0.map { Int(safely: $0) }) })
    }

    private var heightBinding: Binding<Double?> {
        Binding(get: { model.profile.heightCm }, set: { value in model.update(\.profile) { $0.heightCm = value } })
    }

    private var weightBinding: Binding<Double?> {
        Binding(get: { model.profile.weightKg }, set: { model.setWeight($0) })
    }

    /// Age, height and weight side by side (also used by the nutrition calculation).
    private func bodyFields() -> some View {
        HStack(spacing: 8) {
            ProfileNumberField(title: tr("Âge"), unit: tr("ans"), value: ageBinding, decimals: false, identifier: "profile-age")
                .disabled(model.life.birthday != nil)
            ProfileNumberField(title: tr("Taille", context: "height"), unit: tr("cm"), value: heightBinding, decimals: false, identifier: "profile-height")
            ProfileNumberField(title: tr("Poids"), unit: tr("kg"), value: weightBinding, identifier: "profile-weight")
        }
    }

    // MARK: Sport

    @ViewBuilder private var sport: some View {
        QuestionCard(title: tr("Ton objectif")) {
            FlowLayout {
                ForEach(FitnessGoal.allCases) { goal in
                    ChoiceChip(title: goal.title, isSelected: profile.fitnessGoal == goal) { toggle(\.fitnessGoal, goal) }
                }
            }
        }
        QuestionCard(title: tr("Ton niveau")) {
            FlowLayout {
                ForEach(FitnessLevel.allCases) { level in
                    ChoiceChip(title: level.title, isSelected: profile.fitnessLevel == level) { toggle(\.fitnessLevel, level) }
                }
            }
        }
        QuestionCard(title: tr("Séances par semaine"), detail: tr("Le widget Régularité suit cet objectif.")) {
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { count in
                    let isOn = profile.knows(.weeklyWorkouts) && model.fitness.weeklyGoal == count
                    Button {
                        if isOn { model.forget(.weeklyWorkouts) } else { model.setWeeklyWorkouts(count) }
                    } label: {
                        Text("\(count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOn ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.primary))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(AppFill.screenFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(Fmt.plural(count, tr("séance"), tr("séances"))))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        QuestionCard(title: tr("Toi"), detail: model.life.birthday != nil ? tr("L'âge vient de ton anniversaire (Ma vie).") : tr("Le poids sert aussi à estimer les calories brûlées.")) {
            VStack(alignment: .leading, spacing: 10) {
                bodyFields()
                GenderPicker()
            }
        }
    }

    // MARK: Nutrition

    /// The aim, the body and the activity: the daily needs are calculated from them (no number to type
    /// first), then each one can be changed by hand in the card below.
    @ViewBuilder private var nutrition: some View {
        QuestionCard(title: tr("Ton objectif")) {
            FlowLayout {
                ForEach(NutritionAim.allCases) { aim in
                    ChoiceChip(title: aim.title, isSelected: profile.nutritionAim == aim) { toggle(\.nutritionAim, aim) }
                        .accessibilityIdentifier("nutrition-aim-\(aim.rawValue)")
                }
            }
        }
        QuestionCard(title: tr("Toi"), detail: model.life.birthday != nil ? tr("L'âge vient de ton anniversaire (Ma vie).") : tr("Pour calculer tes besoins. Le poids sert aussi à Fitness.")) {
            VStack(alignment: .leading, spacing: 10) {
                bodyFields()
                GenderPicker()
            }
        }
        QuestionCard(title: tr("Ton activité"), detail: model.activityFromWorkouts != nil && profile.calculatedActivity == nil
                     ? tr("D'après tes séances par semaine. Choisis-en une autre si elle te ressemble plus.")
                     : tr("Ton activité physique habituelle, sport compris.")) {
            FlowLayout {
                ForEach(NutritionCalculator.Activity.allCases) { level in
                    let isOn = (profile.calculatedActivity ?? model.activityFromWorkouts) == level
                    ChoiceChip(title: level.title, isSelected: isOn) {
                        model.setNutritionActivity(profile.calculatedActivity == level ? nil : level)
                    }
                    .accessibilityIdentifier("nutrition-activity-\(Int(level.rawValue * 1_000))")
                }
            }
        }
        NutritionTargetsCard()
    }

    // MARK: Money

    private static let expenseChoices = [tr("Logement"), tr("Épicerie"), tr("Transport"), tr("Restaurants"), tr("Loisirs"), tr("Abonnements"), tr("Santé"), tr("Shopping"), tr("Voyages")]

    @ViewBuilder private var money: some View {
        QuestionCard(title: tr("Chaque mois")) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProfileNumberField(title: tr("Revenu"), unit: currencySymbol, value: profileBinding(\.monthlyIncome), decimals: false, identifier: "money-income")
                    ProfileNumberField(
                        title: tr("Budget"), unit: currencySymbol,
                        value: Binding(
                            get: { model.profile.knows(.monthlyBudget) ? model.budget.monthlyBudget : nil },
                            set: { value in if let value { model.setMonthlyBudget(value) } else { model.forget(.monthlyBudget) } }
                        ),
                        decimals: false, identifier: "money-budget"
                    )
                }
                ProfileNumberField(title: tr("Épargne visée"), unit: currencySymbol, value: profileBinding(\.monthlySavingsGoal), decimals: false, identifier: "money-savings")
            }
        }
        QuestionCard(title: tr("Tes principales dépenses")) {
            FlowLayout {
                ForEach(Self.expenseChoices, id: \.self) { expense in
                    let isOn = profile.mainExpenses.contains(expense)
                    ChoiceChip(title: expense, isSelected: isOn) {
                        model.update(\.profile) { profile in
                            if isOn { profile.mainExpenses.removeAll { $0 == expense } } else { profile.mainExpenses.append(expense) }
                        }
                    }
                }
            }
        }
    }

    private var currencySymbol: String { UnitText.display(model.settings.currencyCode) }

    // MARK: Business

    @ViewBuilder private var business: some View {
        QuestionCard(title: tr("Ton activité")) {
            ProfileTextField(
                placeholder: tr("Nom ou activité"),
                text: Binding(
                    get: { model.profile.knows(.businessName) ? model.business.name : "" },
                    set: { name in
                        if name.trimmed.isEmpty { model.forget(.businessName) } else { model.setBusinessName(name) }
                    }
                ),
                identifier: "business-name"
            )
        }
        QuestionCard(title: tr("Chaque mois"), detail: tr("Le chiffre d'affaires, les dépenses et le bénéfice viennent des ventes que tu notes.")) {
            HStack(spacing: 8) {
                ProfileNumberField(
                    title: tr("Objectif de CA"), unit: currencySymbol,
                    value: Binding(
                        get: { model.profile.knows(.businessGoal) ? model.business.monthlyGoal : nil },
                        set: { value in if let value { model.setBusinessGoal(value) } else { model.forget(.businessGoal) } }
                    ),
                    decimals: false, identifier: "business-goal"
                )
                ProfileNumberField(
                    title: tr("Clients"), unit: "",
                    value: Binding(get: { model.profile.businessClients.map { Double($0) } }, set: { value in model.update(\.profile) { $0.businessClients = value.map { Int(safely: $0) } } }),
                    decimals: false, identifier: "business-clients"
                )
            }
        }
    }

    // MARK: Productivity

    @ViewBuilder private var productivity: some View {
        QuestionCard(title: tr("Ton objectif du moment")) {
            ProfileTextField(placeholder: tr("Finir mon projet, lire plus…"), text: profileBinding(\.mainGoal), identifier: "productivity-goal")
        }
        QuestionCard(title: tr("Ton rythme")) {
            HStack(spacing: 8) {
                ProfileNumberField(title: tr("Travail / étude"), unit: tr("h par jour"), value: profileBinding(\.dailyWorkHours), identifier: "work-hours")
                ProfileNumberField(
                    title: tr("Concentration"), unit: tr("h / sem."),
                    value: Binding(
                        get: { model.profile.knows(.focusGoal) ? model.productivity.weeklyFocusGoalHours : nil },
                        set: { value in if let value { model.setFocusGoal(value) } else { model.forget(.focusGoal) } }
                    ),
                    identifier: "focus-goal"
                )
            }
        }
        if !inMiniApp {
            QuestionCard(title: tr("Une tâche pour commencer"), detail: model.content.tasks.isEmpty ? nil : Fmt.plural(model.content.tasks.filter { !$0.isDone }.count, tr("tâche à faire"), tr("tâches à faire"))) {
                quickAdd(placeholder: tr("Ex. : appeler le garage"), text: $newTask, identifier: "first-task") {
                    model.updateContent { $0.tasks.append(TaskItem(title: newTask.trimmed)) }
                    newTask = ""
                }
            }
        }
    }

    private func quickAdd(placeholder: String, text: Binding<String>, identifier: String, add: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            ProfileTextField(placeholder: placeholder, text: text, identifier: identifier)
                .onSubmit { if !text.wrappedValue.trimmed.isEmpty { add() } }
            Button {
                add()
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(text.wrappedValue.trimmed.isEmpty)
            .accessibilityLabel(Text(tr("Ajouter")))
        }
    }

    // MARK: Studies

    @ViewBuilder private var studies: some View {
        QuestionCard(title: tr("Ce que tu étudies")) {
            ProfileTextField(placeholder: tr("Filière, niveau…"), text: profileBinding(\.studyField), identifier: "study-field")
        }
        QuestionCard(title: tr("Ton rythme"), detail: tr("Tes cours, examens et notes s'ajoutent dans Créer › Études.")) {
            ProfileNumberField(title: tr("Étude personnelle"), unit: tr("h par semaine"), value: profileBinding(\.weeklyStudyHours), identifier: "study-hours")
        }
    }

    // MARK: Car

    @ViewBuilder private var car: some View {
        QuestionCard(title: tr("Ta voiture")) {
            ProfileTextField(
                placeholder: tr("Marque et modèle"),
                text: Binding(
                    get: { model.profile.knows(.carName) ? model.car.name : "" },
                    set: { name in
                        if name.trimmed.isEmpty { model.forget(.carName) } else { model.setCarName(name) }
                    }
                ),
                identifier: "car-name"
            )
        }
        QuestionCard(title: tr("Kilométrage actuel"), detail: tr("Les pleins et les entretiens le mettent ensuite à jour.")) {
            ProfileNumberField(
                title: tr("Compteur"), unit: tr("km"),
                value: Binding(get: { model.odometer }, set: { model.setOdometer($0) }),
                decimals: false, identifier: "car-km"
            )
        }
        if inMiniApp {
            QuestionCard(title: tr("Réservoir"), detail: tr("Dans le manuel ou sur le site du constructeur : il sert à estimer l'autonomie après un plein complet.")) {
                ProfileNumberField(
                    title: tr("Capacité"), unit: "L",
                    value: Binding(get: { model.car.tankLiters }, set: { liters in model.update(\.car) { $0.tankLiters = liters } }),
                    identifier: "car-tank"
                )
            }
        }
    }

    // MARK: Weather

    private var weather: some View {
        QuestionCard(title: tr("Ta ville"), detail: tr("Pour la météo de tes widgets. Tu peux la changer quand tu veux.")) {
            Button {
                showsCityPicker = true
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text(model.settings.weatherLocation?.name ?? tr("Choisir ma ville"))
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(12)
                .frame(minHeight: 44)
                .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.pressable)
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
    }

    // MARK: Well-being

    @ViewBuilder private var wellbeing: some View {
        QuestionCard(title: tr("Une habitude à suivre"), detail: model.content.habits.isEmpty ? nil : Fmt.plural(model.content.habits.count, tr("habitude suivie"), tr("habitudes suivies"))) {
            quickAdd(placeholder: tr("Ex. : méditer, lire, marcher"), text: $newHabit, identifier: "first-habit") {
                guard model.canAddHabit else { return }
                model.updateContent { $0.habits.append(Habit(name: newHabit.trimmed, symbol: "checkmark.circle", colorHex: "7FA33A")) }
                newHabit = ""
            }
        }
    }
}

// MARK: - Interests

/// Every interest as a tile to tick.
struct InterestGrid: View {
    @Binding var selection: [Interest]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Interest.allCases) { interest in
                let isOn = selection.contains(interest)
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        if isOn { selection.removeAll { $0 == interest } } else { selection.append(interest) }
                    }
                    Haptics.tap()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: interest.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isOn ? .white : Color(hex: interest.colorHex))
                            .frame(width: 44, height: 44)
                            .background(isOn ? Color(hex: interest.colorHex) : Color(hex: interest.colorHex).opacity(0.14), in: Circle())
                        Text(interest.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isOn ? Color(hex: interest.colorHex) : .clear, lineWidth: 2)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(Color(hex: interest.colorHex))
                                .padding(7)
                        }
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(Text(interest.title))
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("interest-\(interest.rawValue)")
            }
        }
    }
}

/// « Mes informations » › a topic: the same questions as at the first launch.
struct TopicEditorSheet: View {
    let topic: ProfileTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(topic.purpose)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TopicForm(topic: topic)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.screenGradient)
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
    }
}

/// « Mes informations » › centres d'intérêt.
struct InterestsEditorSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tr("Ardane met ces thèmes en avant, sans jamais cacher les autres."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    InterestGrid(selection: Binding(
                        get: { model.profile.interests },
                        set: { interests in model.update(\.profile) { $0.interests = interests } }
                    ))
                }
                .padding(20)
            }
            .background(.screenGradient)
            .navigationTitle(tr("Centres d'intérêt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
    }
}
