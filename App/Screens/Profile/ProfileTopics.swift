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
        .buttonStyle(.plain)
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
            Text("Genre")
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
                ProfileTextField(placeholder: "Précise si tu veux (facultatif)", text: Binding(
                    get: { model.profile.genderDetail },
                    set: { value in model.update(\.profile) { $0.genderDetail = value } }
                ), identifier: "gender-detail")
            }
            if let sex = profile.sex, !sex.isBinary {
                Text("Pour estimer tes calories, Tessera utilise :")
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
    @Environment(AppModel.self) private var model
    @State private var calculationActivity: NutritionCalculator.Activity?
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
            ProfileNumberField(title: "Âge", unit: "ans", value: ageBinding, decimals: false, identifier: "profile-age")
                .disabled(model.life.birthday != nil)
            ProfileNumberField(title: "Taille", unit: "cm", value: heightBinding, decimals: false, identifier: "profile-height")
            ProfileNumberField(title: "Poids", unit: "kg", value: weightBinding, identifier: "profile-weight")
        }
    }

    // MARK: Sport

    @ViewBuilder private var sport: some View {
        QuestionCard(title: "Ton objectif") {
            FlowLayout {
                ForEach(FitnessGoal.allCases) { goal in
                    ChoiceChip(title: goal.title, isSelected: profile.fitnessGoal == goal) { toggle(\.fitnessGoal, goal) }
                }
            }
        }
        QuestionCard(title: "Ton niveau") {
            FlowLayout {
                ForEach(FitnessLevel.allCases) { level in
                    ChoiceChip(title: level.title, isSelected: profile.fitnessLevel == level) { toggle(\.fitnessLevel, level) }
                }
            }
        }
        QuestionCard(title: "Séances par semaine", detail: "Le widget Régularité suit cet objectif.") {
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
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(Fmt.plural(count, "séance", "séances")))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        QuestionCard(title: "Toi", detail: model.life.birthday != nil ? "L'âge vient de ton anniversaire (Ma vie)." : "Le poids sert aussi à estimer les calories brûlées.") {
            VStack(alignment: .leading, spacing: 10) {
                bodyFields()
                GenderPicker()
            }
        }
    }

    // MARK: Nutrition

    private func targetBinding(_ fact: ProvidedFact, _ keyPath: WritableKeyPath<NutritionGoals, Double>) -> Binding<Double?> {
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

    @ViewBuilder private var nutrition: some View {
        QuestionCard(title: "Ton objectif") {
            FlowLayout {
                ForEach(NutritionAim.allCases) { aim in
                    ChoiceChip(title: aim.title, isSelected: profile.nutritionAim == aim) { toggle(\.nutritionAim, aim) }
                }
            }
        }
        QuestionCard(title: "Par jour", detail: "Laisse vide ce que tu ne sais pas : Tessera peut le calculer.") {
            VStack(spacing: 8) {
                ProfileNumberField(title: "Calories", unit: "kcal", value: targetBinding(.kcalTarget, \.kcal), decimals: false, identifier: "target-kcal")
                HStack(spacing: 8) {
                    ProfileNumberField(title: "Protéines", unit: "g", value: targetBinding(.proteinTarget, \.protein), decimals: false, identifier: "target-protein")
                    ProfileNumberField(title: "Glucides", unit: "g", value: targetBinding(.carbsTarget, \.carbs), decimals: false, identifier: "target-carbs")
                    ProfileNumberField(title: "Lipides", unit: "g", value: targetBinding(.fatTarget, \.fat), decimals: false, identifier: "target-fat")
                }
            }
        }
        calculation
    }

    /// Mifflin-St Jeor from the profile: asks only for what is missing.
    private var calculation: some View {
        let activity = model.activityFromWorkouts ?? calculationActivity
        let result = activity.flatMap { model.calculatedNutritionGoals(activity: $0) }
        return QuestionCard(title: "Calculer pour moi", detail: "Estimation à partir de ton âge, ta taille, ton poids et ton activité. Ce n'est pas un avis médical.") {
            VStack(alignment: .leading, spacing: 10) {
                // Shown when something was missing as the card appeared, and kept while the user types
                // (a field never disappears under their fingers).
                if asksBody {
                    bodyFields()
                }
                GenderPicker()
                if model.activityFromWorkouts == nil {
                    FlowLayout {
                        ForEach(NutritionCalculator.Activity.allCases) { level in
                            ChoiceChip(title: level.title, isSelected: calculationActivity == level) {
                                calculationActivity = calculationActivity == level ? nil : level
                            }
                        }
                    }
                }
                Button {
                    if let result, let activity { model.setNutritionGoals(result, calculatedWith: activity) }
                } label: {
                    Label("Calculer mes objectifs", systemImage: "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .disabled(result == nil)
                .accessibilityIdentifier("calculate-targets")
            }
        }
    }

    // MARK: Money

    private static let expenseChoices = ["Logement", "Épicerie", "Transport", "Restaurants", "Loisirs", "Abonnements", "Santé", "Shopping", "Voyages"]

    @ViewBuilder private var money: some View {
        QuestionCard(title: "Chaque mois") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ProfileNumberField(title: "Revenu", unit: currencySymbol, value: profileBinding(\.monthlyIncome), decimals: false, identifier: "money-income")
                    ProfileNumberField(
                        title: "Budget", unit: currencySymbol,
                        value: Binding(
                            get: { model.profile.knows(.monthlyBudget) ? model.budget.monthlyBudget : nil },
                            set: { value in if let value { model.setMonthlyBudget(value) } else { model.forget(.monthlyBudget) } }
                        ),
                        decimals: false, identifier: "money-budget"
                    )
                }
                ProfileNumberField(title: "Épargne visée", unit: currencySymbol, value: profileBinding(\.monthlySavingsGoal), decimals: false, identifier: "money-savings")
            }
        }
        QuestionCard(title: "Tes principales dépenses") {
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
        QuestionCard(title: "Ton activité") {
            ProfileTextField(
                placeholder: "Nom ou activité",
                text: Binding(
                    get: { model.profile.knows(.businessName) ? model.business.name : "" },
                    set: { name in
                        if name.trimmed.isEmpty { model.forget(.businessName) } else { model.setBusinessName(name) }
                    }
                ),
                identifier: "business-name"
            )
        }
        QuestionCard(title: "Chaque mois", detail: "Le chiffre d'affaires, les dépenses et le bénéfice viennent des ventes que tu notes.") {
            HStack(spacing: 8) {
                ProfileNumberField(
                    title: "Objectif de CA", unit: currencySymbol,
                    value: Binding(
                        get: { model.profile.knows(.businessGoal) ? model.business.monthlyGoal : nil },
                        set: { value in if let value { model.setBusinessGoal(value) } else { model.forget(.businessGoal) } }
                    ),
                    decimals: false, identifier: "business-goal"
                )
                ProfileNumberField(
                    title: "Clients", unit: "",
                    value: Binding(get: { model.profile.businessClients.map { Double($0) } }, set: { value in model.update(\.profile) { $0.businessClients = value.map { Int(safely: $0) } } }),
                    decimals: false, identifier: "business-clients"
                )
            }
        }
    }

    // MARK: Productivity

    @ViewBuilder private var productivity: some View {
        QuestionCard(title: "Ton objectif du moment") {
            ProfileTextField(placeholder: "Finir mon projet, lire plus…", text: profileBinding(\.mainGoal), identifier: "productivity-goal")
        }
        QuestionCard(title: "Ton rythme") {
            HStack(spacing: 8) {
                ProfileNumberField(title: "Travail / étude", unit: "h par jour", value: profileBinding(\.dailyWorkHours), identifier: "work-hours")
                ProfileNumberField(
                    title: "Concentration", unit: "h / sem.",
                    value: Binding(
                        get: { model.profile.knows(.focusGoal) ? model.productivity.weeklyFocusGoalHours : nil },
                        set: { value in if let value { model.setFocusGoal(value) } else { model.forget(.focusGoal) } }
                    ),
                    identifier: "focus-goal"
                )
            }
        }
        QuestionCard(title: "Une tâche pour commencer", detail: model.content.tasks.isEmpty ? nil : Fmt.plural(model.content.tasks.filter { !$0.isDone }.count, "tâche à faire", "tâches à faire")) {
            quickAdd(placeholder: "Ex. : appeler le garage", text: $newTask, identifier: "first-task") {
                model.updateContent { $0.tasks.append(TaskItem(title: newTask.trimmed)) }
                newTask = ""
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
            .buttonStyle(.plain)
            .disabled(text.wrappedValue.trimmed.isEmpty)
            .accessibilityLabel(Text("Ajouter"))
        }
    }

    // MARK: Studies

    @ViewBuilder private var studies: some View {
        QuestionCard(title: "Ce que tu étudies") {
            ProfileTextField(placeholder: "Filière, niveau…", text: profileBinding(\.studyField), identifier: "study-field")
        }
        QuestionCard(title: "Ton rythme", detail: "Tes cours, examens et notes s'ajoutent dans Créer › Études.") {
            ProfileNumberField(title: "Étude personnelle", unit: "h par semaine", value: profileBinding(\.weeklyStudyHours), identifier: "study-hours")
        }
    }

    // MARK: Car

    @ViewBuilder private var car: some View {
        QuestionCard(title: "Ta voiture") {
            ProfileTextField(
                placeholder: "Marque et modèle",
                text: Binding(
                    get: { model.profile.knows(.carName) ? model.car.name : "" },
                    set: { name in
                        if name.trimmed.isEmpty { model.forget(.carName) } else { model.setCarName(name) }
                    }
                ),
                identifier: "car-name"
            )
        }
        QuestionCard(title: "Kilométrage actuel", detail: "Les pleins et les entretiens le mettent ensuite à jour.") {
            ProfileNumberField(
                title: "Compteur", unit: "km",
                value: Binding(get: { model.odometer }, set: { model.setOdometer($0) }),
                decimals: false, identifier: "car-km"
            )
        }
    }

    // MARK: Weather

    private var weather: some View {
        QuestionCard(title: "Ta ville", detail: "Pour la météo de tes widgets. Tu peux la changer quand tu veux.") {
            Button {
                showsCityPicker = true
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text(model.settings.weatherLocation?.name ?? "Choisir ma ville")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(12)
                .frame(minHeight: 44)
                .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showsCityPicker) {
                NavigationStack {
                    WeatherLocationView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("OK") { showsCityPicker = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: Well-being

    @ViewBuilder private var wellbeing: some View {
        QuestionCard(title: "Verres d'eau par jour", detail: "Le widget Hydratation suit cet objectif.") {
            FlowLayout {
                ForEach([4, 6, 8, 10, 12], id: \.self) { glasses in
                    let isOn = profile.knows(.hydrationGoal) && model.content.hydration.goal == glasses
                    ChoiceChip(title: "\(glasses)", isSelected: isOn) {
                        if isOn { model.forget(.hydrationGoal) } else { model.setHydrationGoal(glasses) }
                    }
                }
            }
        }
        QuestionCard(title: "Une habitude à suivre", detail: model.content.habits.isEmpty ? nil : Fmt.plural(model.content.habits.count, "habitude suivie", "habitudes suivies")) {
            quickAdd(placeholder: "Ex. : méditer, lire, marcher", text: $newHabit, identifier: "first-habit") {
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
                .buttonStyle(.plain)
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
            .background(.screenFill)
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
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
                    Text("Tessera met ces thèmes en avant, sans jamais cacher les autres.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    InterestGrid(selection: Binding(
                        get: { model.profile.interests },
                        set: { interests in model.update(\.profile) { $0.interests = interests } }
                    ))
                }
                .padding(20)
            }
            .background(.screenFill)
            .navigationTitle("Centres d'intérêt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}
