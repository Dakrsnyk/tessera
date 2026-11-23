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

/// An answer already given, shown in place of its question with « Modifier » (the first-launch pages never
/// ask twice what the person already said).
struct KnownSummary: View {
    let text: String
    let identifier: String
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button(tr("Modifier"), action: onEdit)
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier(identifier)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    // The number keeps room for itself in a narrow field: the unit shrinks instead of overlapping it.
                    .frame(minWidth: 30)
                    .layoutPriority(1)
                    .accessibilityLabel(Text(title))
                    .accessibilityIdentifier(identifier ?? title)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
    /// The first-launch pages: what the person already gave (on an earlier page, or in another space) is
    /// shown as a summary with « Modifier », not asked again. « Mes informations » always shows the answers
    /// selected, ready to change.
    var compactKnown = false
    @Environment(AppModel.self) private var model
    @State private var newTask = ""
    @State private var newHabit = ""
    /// Planning, first launch: « Importer mon emploi du temps » opened, or the tasks typed by hand shown.
    @State private var importsSchedule = false
    @State private var addsTasksByHand = false
    // Whether the page opened without the answer (nil until it appeared): the page keeps asking while the
    // person fills it in, and only shows a summary when the answer was already there.
    @State private var asksBody: Bool?
    @State private var asksGoal: Bool?
    @State private var asksActivity: Bool?
    @State private var editsBody = false
    @State private var editsGoal = false
    @State private var editsActivity = false
    @State private var paywall: PaywallContext?

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
            case .wellbeing: wellbeing
            }
        }
        .onAppear {
            if asksBody == nil { asksBody = !bodyKnown }
            if asksGoal == nil { asksGoal = profile.goal == nil }
            if asksActivity == nil { asksActivity = !activityKnown }
        }
        .sheet(item: $paywall) { PaywallView(context: $0) }
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

    /// In cm and kg as saved: `ProfileMeasureField` shows both units itself.
    private var heightBinding: Binding<Double?> {
        Binding(get: { model.profile.heightCm }, set: { value in model.update(\.profile) { $0.heightCm = value } })
    }

    private var weightBinding: Binding<Double?> {
        Binding<Double?>(get: { model.profile.weightKg }, set: { model.setWeight($0) })
    }

    /// The order of the three body fields (PDG, 2026-11-22): Nutrition asks the weight first (weight, age, height),
    /// Fitness the age, the weight, then the height; elsewhere age, height, weight as before.
    enum BodyOrder {
        case ageHeightWeight, weightAgeHeight, ageWeightHeight
    }

    /// Age, height and weight side by side (also used by the nutrition calculation), in the order of the page.
    private func bodyFields(order: BodyOrder = .ageHeightWeight) -> some View {
        HStack(spacing: 8) {
            switch order {
            case .ageHeightWeight:
                ageField
                heightFields
                weightField
            case .weightAgeHeight:
                weightField
                ageField
                heightFields
            case .ageWeightHeight:
                ageField
                weightField
                heightFields
            }
        }
    }

    private var ageField: some View {
        ProfileNumberField(title: tr("Âge"), unit: tr("ans"), value: ageBinding, decimals: false, identifier: "profile-age")
            .disabled(model.life.birthday != nil)
    }

    /// One field, whatever the units: the list offers lb or ft/in on the left and kg or cm on the right (PDG, 2026-11-22).
    private var heightFields: some View {
        ProfileMeasureField(measure: .height, value: heightBinding, identifier: "profile-height")
    }

    private var weightField: some View {
        ProfileMeasureField(measure: .weight, value: weightBinding, identifier: "profile-weight")
    }

    // MARK: Shared questions (asked once, whichever page comes first)

    /// Age, height, weight and gender: all there (the calculation needs the four).
    private var bodyKnown: Bool {
        model.age != nil && profile.heightCm != nil && profile.weightKg != nil && profile.sex != nil
    }

    private var showsBodyFields: Bool { !compactKnown || editsBody || (asksBody ?? !bodyKnown) }

    /// « Toi » (age, height, weight, gender), the same card in Sport and in Nutrition: when everything is
    /// already known on a first-launch page, a summary with « Modifier » instead of the fields.
    private func bodyCard(detail: String, identifier: String, order: BodyOrder = .ageHeightWeight) -> some View {
        QuestionCard(title: tr("Toi"), detail: showsBodyFields ? detail : tr("Déjà renseigné : tu peux le modifier.")) {
            if showsBodyFields {
                VStack(alignment: .leading, spacing: 10) {
                    bodyFields(order: order)
                    GenderPicker()
                }
            } else {
                KnownSummary(text: bodySummary, identifier: identifier) { editsBody = true }
            }
        }
    }

    /// « 27 ans · 175 cm · 78 kg · Homme ».
    private var bodySummary: String {
        let system = model.settings.unitSystem
        var parts: [String] = []
        if let age = model.age { parts.append(tr("\(age) ans")) }
        if let height = profile.heightCm { parts.append(Units.heightText(centimetres: height, in: system)) }
        if let weight = profile.weightKg { parts.append(Units.weightText(kilograms: weight, in: system)) }
        if let sex = profile.sex { parts.append(sex.title) }
        return parts.joined(separator: " · ")
    }

    private var showsGoalChips: Bool { !compactKnown || editsGoal || (asksGoal ?? (profile.goal == nil)) }

    /// « Ton objectif »: one question, one answer for Sport and Nutrition (`UserProfile.goal`), the same list
    /// on both pages. Already chosen on an earlier first-launch page: shown, with « Modifier ».
    private func goalCard(identifierPrefix: String, goals: [FitnessGoal] = FitnessGoal.displayOrder, detail: String? = nil) -> some View {
        QuestionCard(title: tr("Ton objectif"), detail: showsGoalChips ? (detail ?? tr("Le même pour Sport et Nutrition.")) : tr("Déjà choisi : tu peux le changer.")) {
            if showsGoalChips {
                FlowLayout {
                    ForEach(goals) { goal in
                        ChoiceChip(title: goal.title, isSelected: profile.goal == goal) {
                            model.setGoal(profile.goal == goal ? nil : goal)
                        }
                        .accessibilityIdentifier("\(identifierPrefix)-\(goal.rawValue)")
                    }
                }
            } else {
                KnownSummary(text: profile.goal?.title ?? "", identifier: "\(identifierPrefix)-edit") { editsGoal = true }
            }
        }
    }

    /// « Ton objectif » of Nutrition: the weight and the training side in one answer (« Perte de poids et
    /// force »). The same shared goal as Sport (the calculation reads it); its training side is `goalFocus`.
    private var nutritionGoalCard: some View {
        let current = NutritionGoalChoice.current(profile)
        return QuestionCard(title: tr("Ton objectif"), detail: showsGoalChips ? tr("Le même pour Sport et Nutrition.") : tr("Déjà choisi : tu peux le changer.")) {
            if showsGoalChips {
                FlowLayout {
                    ForEach(NutritionGoalChoice.all) { choice in
                        ChoiceChip(title: choice.title, isSelected: current == choice) {
                            if current == choice {
                                model.setGoal(nil)
                            } else {
                                model.setGoal(choice.goal)
                                model.update(\.profile) { $0.goalFocus = choice.focus }
                            }
                        }
                        .accessibilityIdentifier("nutrition-aim-\(choice.id)")
                    }
                }
            } else {
                KnownSummary(text: current?.title ?? profile.goal?.title ?? "", identifier: "nutrition-aim-edit") { editsGoal = true }
            }
        }
    }

    // MARK: Sport

    /// Fitness (PDG, 2026-11-22): the person first (age, weight, height), then questions that follow the answers
    /// (`FitnessAdvice`): the goals that fit the body first and none unsafe for a minor, a level hint, the sessions
    /// a week that fit the level, the goal and the age. No pregnancy question here: it is asked only where a weight
    /// plan needs it (Nutrition, `WeightPlanQuestions`).
    @ViewBuilder private var sport: some View {
        let minor = profile.isMinor(birthday: model.life.birthday)
        let bmi = FitnessAdvice.bmi(weightKg: profile.weightKg, heightCm: profile.heightCm)
        let suggested = FitnessAdvice.suggestedFirst(bmi: bmi)
        bodyCard(
            detail: model.life.birthday != nil ? tr("L'âge vient de ton anniversaire (Ma vie).") : tr("Pour adapter les questions suivantes. Le poids sert aussi à estimer les calories brûlées."),
            identifier: "sport-body-edit",
            order: .ageWeightHeight
        )
        goalCard(
            identifierPrefix: "sport-goal",
            goals: FitnessAdvice.goals(bmi: bmi, isMinor: minor),
            detail: suggested.isEmpty ? nil : tr("Les plus adaptés à ton profil sont en premier. Le même objectif pour Sport et Nutrition.")
        )
        QuestionCard(title: tr("Ton niveau"), detail: levelDetail) {
            FlowLayout {
                ForEach(FitnessLevel.allCases) { level in
                    ChoiceChip(title: level.title, isSelected: profile.fitnessLevel == level) { toggle(\.fitnessLevel, level) }
                        .accessibilityIdentifier("sport-level-\(level.rawValue)")
                }
            }
        }
        let advised = FitnessAdvice.sessions(level: profile.fitnessLevel, goal: profile.goal, age: model.age, isMinor: minor)
        QuestionCard(title: tr("Séances par semaine"), detail: sessionsDetail(advised)) {
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { count in
                    let isOn = profile.knows(.weeklyWorkouts) && model.fitness.weeklyGoal == count
                    let isAdvised = advised?.contains(count) == true
                    Button {
                        if isOn { model.forget(.weeklyWorkouts) } else { model.setWeeklyWorkouts(count) }
                    } label: {
                        Text("\(count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOn ? AnyShapeStyle(.onAccent) : AnyShapeStyle(Color.primary))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(AppFill.screenFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                // The advised counts, outlined in the accent (never chosen for the person).
                                if isAdvised && !isOn {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                                }
                            }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(Text(Fmt.plural(count, tr("séance"), tr("séances"))))
                    .accessibilityHint(Text(isAdvised ? tr("Conseillé pour toi") : ""))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    /// Under « Ton niveau »: a word of prudence for a beginner from 60 years old or under 18, else nothing.
    private var levelDetail: String? {
        let minor = profile.isMinor(birthday: model.life.birthday)
        if minor { return tr("Avant 18 ans, privilégie la technique et des charges légères.") }
        if let age = model.age, age >= 60 { return tr("Commence doucement : tu pourras changer de niveau plus tard.") }
        return nil
    }

    /// « Conseillé pour toi : 3 à 4 séances » once the level is known, else what the number is for.
    private func sessionsDetail(_ advised: ClosedRange<Int>?) -> String {
        guard let advised else { return tr("Choisis ton niveau pour un conseil. Le widget Régularité suit cet objectif.") }
        if advised.lowerBound == advised.upperBound {
            return tr("Conseillé pour toi : \(Fmt.plural(advised.lowerBound, tr("séance"), tr("séances"))). Le widget Régularité suit cet objectif.")
        }
        return tr("Conseillé pour toi : \(advised.lowerBound) à \(advised.upperBound) séances. Le widget Régularité suit cet objectif.")
    }

    // MARK: Nutrition

    private var activityKnown: Bool { profile.calculatedActivity != nil || model.activityFromWorkouts != nil }

    private var showsActivityChips: Bool { !compactKnown || editsActivity || (asksActivity ?? !activityKnown) }

    /// What the activity card says about where the level comes from.
    private var activityDetail: String {
        if !showsActivityChips { return tr("Déjà connu : tu peux le modifier.") }
        let fromWorkouts = model.activityFromWorkouts
        if let chosen = profile.calculatedActivity {
            if let fromWorkouts, fromWorkouts != chosen {
                return tr("Choisi par toi. Tes séances donneraient : \(fromWorkouts.title). Touche ton choix pour revenir aux séances.")
            }
            return tr("Choisi par toi. Touche-le de nouveau pour revenir à tes séances.")
        }
        if fromWorkouts != nil {
            return tr("D'après tes séances : \(String(model.fitness.weeklyGoal)) par semaine. Choisis un autre niveau si tu préfères.")
        }
        return tr("Ton activité physique habituelle, sport compris.")
    }

    /// The aim, the body and the activity: the daily needs are calculated from them (no number to type
    /// first), then each one can be changed by hand in the card below.
    @ViewBuilder private var nutrition: some View {
        // Weight, age and height first, then the goal (PDG, 2026-11-22).
        bodyCard(
            detail: model.life.birthday != nil ? tr("L'âge vient de ton anniversaire (Ma vie).") : tr("Pour calculer tes besoins. Le poids sert aussi à Fitness."),
            identifier: "nutrition-body-edit",
            order: .weightAgeHeight
        )
        nutritionGoalCard
        WeightPlanQuestions(compactKnown: compactKnown)
        QuestionCard(title: tr("Ton niveau d'activité"), detail: activityDetail) {
            if showsActivityChips {
                FlowLayout {
                    ForEach(NutritionCalculator.Activity.allCases) { level in
                        let isOn = (profile.calculatedActivity ?? model.activityFromWorkouts) == level
                        ChoiceChip(title: level.title, isSelected: isOn) {
                            model.tapNutritionActivity(level)
                        }
                        .accessibilityIdentifier("nutrition-activity-\(Int(level.rawValue * 1_000))")
                    }
                }
            } else if let level = profile.calculatedActivity ?? model.activityFromWorkouts {
                KnownSummary(text: profile.calculatedActivity == nil ? tr("\(level.title), d'après tes séances") : level.title,
                             identifier: "nutrition-activity-edit") { editsActivity = true }
            }
        }
        WeightPlanRecap()
        NutritionTargetsCard()
    }

    // MARK: Money

    private static let expenseChoices = [tr("Logement"), tr("Épicerie"), tr("Transport"), tr("Restaurants"), tr("Loisirs"), tr("Abonnements"), tr("Santé"), tr("Shopping"), tr("Voyages")]

    /// The first launch asks only the income, the main expenses and the savings goal (PDG, 2026-11-22): the
    /// monthly budget is set later, in « Mes informations » or the Finances mini-app.
    @ViewBuilder private var money: some View {
        QuestionCard(title: tr("Chaque mois")) {
            if compactKnown {
                ProfileNumberField(title: tr("Revenu"), unit: currencySymbol, value: profileBinding(\.monthlyIncome), decimals: false, identifier: "money-income")
            } else {
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
        if compactKnown {
            QuestionCard(title: tr("Ton objectif d'épargne"), detail: tr("Ce que tu veux mettre de côté chaque mois.")) {
                ProfileNumberField(title: tr("Épargne visée"), unit: currencySymbol, value: profileBinding(\.monthlySavingsGoal), decimals: false, identifier: "money-savings")
            }
        }
    }

    private var currencySymbol: String { UnitText.display(model.settings.currencyCode) }

    // MARK: Business

    @ViewBuilder private var business: some View {
        // « Ton activité » of the business, not the physical activity of Nutrition (two translations).
        QuestionCard(title: tr("Ton activité", context: "business")) {
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
        if !inMiniApp { planningStart }
        QuestionCard(title: tr("Ton objectif du moment")) {
            ProfileTextField(placeholder: tr("Finir mon projet, lire plus…"), text: profileBinding(\.mainGoal), identifier: "productivity-goal")
        }
        // The weekly concentration goal is asked once, in Études (`ProfileTopic.studies`), where Concentration lives.
        QuestionCard(title: tr("Ton rythme")) {
            ProfileNumberField(title: tr("Travail / étude"), unit: tr("h par jour"), value: profileBinding(\.dailyWorkHours), identifier: "work-hours")
        }
    }

    /// « Pour commencer » of Planning (PDG, 2026-11-22): import the timetable (a photo or a PDF, read on the
    /// iPhone) or type the tasks by hand, whichever suits the person.
    private var planningStart: some View {
        let openTasks = model.content.tasks.filter { !$0.isDone }.count
        let slots = model.student.slots.count
        return QuestionCard(title: tr("Pour commencer"), detail: tr("Choisis comment remplir ton planning.")) {
            VStack(spacing: 8) {
                startChoice(
                    symbol: "doc.viewfinder", title: tr("Importer mon emploi du temps"),
                    detail: slots > 0 ? Fmt.plural(slots, tr("créneau dans ton horaire"), tr("créneaux dans ton horaire")) : tr("À partir d'une photo ou d'un PDF"),
                    isPremiumOnly: !model.isPremium, identifier: "first-import-schedule"
                ) { importsSchedule = true }
                startChoice(
                    symbol: "square.and.pencil", title: tr("Ajouter mes tâches à la main"),
                    detail: openTasks > 0 ? Fmt.plural(openTasks, tr("tâche à faire"), tr("tâches à faire")) : tr("Une par une, en quelques mots"),
                    isPremiumOnly: false, identifier: "first-tasks-by-hand"
                ) { withAnimation(.snappy) { addsTasksByHand = true } }
                if addsTasksByHand || openTasks > 0 {
                    quickAdd(placeholder: tr("Ex. : appeler le garage"), text: $newTask, identifier: "first-task") {
                        model.updateContent { $0.tasks.append(TaskItem(title: newTask.trimmed)) }
                        newTask = ""
                    }
                }
            }
        }
        .sheet(isPresented: $importsSchedule) { ScheduleImportView() }
    }

    private func startChoice(symbol: String, title: String, detail: String, isPremiumOnly: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isPremiumOnly { PremiumBadge(compact: true) }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier(identifier)
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
            HStack(spacing: 8) {
                // The goal of Études itself (card, widget, notifications), not a second number.
                ProfileNumberField(
                    title: tr("Étude personnelle"), unit: tr("h par semaine"),
                    value: Binding(
                        get: { model.profile.knows(.studyGoal) ? model.student.weeklyStudyGoalHours : nil },
                        set: { value in
                            if let value {
                                model.setStudyGoal(value)
                            } else {
                                // Cleared for good: the old field must not bring the value back.
                                model.update(\.profile) { $0.provided.remove(.studyGoal); $0.weeklyStudyHours = nil }
                            }
                        }
                    ),
                    identifier: "study-hours"
                )
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

    // MARK: Well-being

    /// Habits to start with in one tap (PDG, 2026-11-22: Bien-être proposes the habits), each with its icon.
    @ViewBuilder private var wellbeing: some View {
        if !inMiniApp {
            QuestionCard(title: tr("Des habitudes à suivre"), detail: tr("Touche celles qui te parlent : elles arrivent dans Habitudes.")) {
                FlowLayout {
                    ForEach(HabitSuggestions.all, id: \.self) { suggestion in
                        let existing = model.content.habits.first { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }
                        ChoiceChip(title: suggestion.name, symbol: suggestion.symbol, isSelected: existing != nil) {
                            if let existing {
                                // Only the habit this chip added, never checked, is taken back: a followed one, or one
                                // made by hand with the same name, stays.
                                if existing.completedDays.isEmpty, existing.symbol == suggestion.symbol,
                                   existing.colorHex == suggestion.colorHex, existing.reminderHour == nil {
                                    model.updateContent { $0.habits.removeAll { $0.id == existing.id } }
                                }
                            } else if !model.addHabit(Habit(name: suggestion.name, symbol: suggestion.symbol, colorHex: suggestion.colorHex)) {
                                paywall = .habitLimit
                            }
                        }
                        .accessibilityIdentifier("habit-suggestion-\(suggestion.symbol)")
                    }
                }
            }
        }
        QuestionCard(title: inMiniApp ? tr("Une habitude à suivre") : tr("Une autre habitude"), detail: model.content.habits.isEmpty ? nil : Fmt.plural(model.content.habits.count, tr("habitude suivie"), tr("habitudes suivies"))) {
            quickAdd(placeholder: tr("Ex. : méditer, lire, marcher"), text: $newHabit, identifier: "first-habit") {
                // At the free limit: the paywall opens and the text typed stays.
                guard model.addHabit(Habit(name: newHabit.trimmed, symbol: "checkmark.circle", colorHex: "7FA33A")) else {
                    paywall = .habitLimit
                    return
                }
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
            ForEach(Interest.offered(keeping: selection)) { interest in
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
                        // The title only (PDG, 2026-11-22: no words under Études and Planning).
                        Text(interest.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .cristalPanel(radius: 18)
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
            .cristalScreen()
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
            .cristalScreen()
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

// MARK: - Weight goal (chantier 15)

/// « Es-tu enceinte ou allaitante ? », asked for any goal of loss or gain (`UserProfile.aim`), whether it
/// was chosen in Sport or in Nutrition, and not of a man. Already answered on an earlier first-launch page:
/// a summary with « Modifier ».
struct LifeStageQuestion: View {
    var compactKnown = false
    @Environment(AppModel.self) private var model
    @State private var asksStage: Bool?
    @State private var edits = false

    private var profile: UserProfile { model.profile }

    var body: some View {
        if profile.asksLifeStage {
            let asks = !compactKnown || edits || (asksStage ?? (profile.lifeStage == nil))
            QuestionCard(title: tr("Es-tu enceinte ou allaitante ?"),
                         detail: asks ? tr("Pendant la grossesse ou l'allaitement, Ardane ne calcule pas d'objectif de poids.") : tr("Déjà répondu : tu peux le modifier.")) {
                if asks {
                    FlowLayout {
                        ForEach([LifeStage.adult, .pregnant, .breastfeeding, .preferNotToSay]) { stage in
                            // None is preselected: an unanswered question gives no weight plan.
                            ChoiceChip(title: stage.title, isSelected: profile.lifeStage == stage) {
                                model.update(\.profile) { $0.lifeStage = $0.lifeStage == stage ? nil : stage }
                            }
                            .accessibilityIdentifier("lifestage-\(stage.rawValue)")
                        }
                    }
                } else if let stage = profile.lifeStage {
                    KnownSummary(text: stage.title, identifier: "lifestage-edit") { edits = true }
                }
            }
            .onAppear { if asksStage == nil { asksStage = profile.lifeStage == nil } }
        }
    }
}

/// The weight to reach and when, and the situation that makes the calculation more careful. Shown under
/// « Ton objectif » when the aim is to lose or to gain; the answers already asked above are not asked again.
struct WeightPlanQuestions: View {
    /// First-launch page: the pregnancy question already answered is shown as a summary (see `LifeStageQuestion`).
    var compactKnown = false
    @Environment(AppModel.self) private var model
    @State private var mode: DurationMode = .weeks

    enum DurationMode: String, CaseIterable, Identifiable {
        case weeks, months, date
        var id: String { rawValue }

        var title: String {
            switch self {
            case .weeks: tr("Semaines")
            case .months: tr("Mois")
            case .date: tr("Date")
            }
        }
    }

    private var system: UnitSystem { model.settings.unitSystem }
    private var profile: UserProfile { model.profile }

    var body: some View {
        if profile.aim == .lose || profile.aim == .gain {
            VStack(spacing: 12) {
                QuestionCard(title: tr("Ton poids cible"), detail: tr("Facultatif. Ardane calcule des calories d'après ce poids et la durée choisie, et te les montre avant de les appliquer.")) {
                    VStack(alignment: .leading, spacing: 10) {
                        ProfileNumberField(title: tr("Poids cible"), unit: system.weightUnit, value: targetBinding, identifier: "weightplan-target")
                        if let plan = profile.weightPlan {
                            duration(plan)
                        }
                    }
                }
                // The pregnancy question is no longer asked here (PDG, 2026-11-22): the recap of the plan asks it, only
                // when a target weight needs it (`WeightPlanSummaryView`).
            }
        }
    }

    /// The target in kilograms, typed and shown in the chosen unit. Clearing the field keeps the goal.
    private var targetBinding: Binding<Double?> {
        Binding<Double?>(
            get: { model.profile.weightPlan?.targetKg },
            set: { model.setWeightPlan(targetKg: $0) }
        ).weight(in: system)
    }

    private func duration(_ plan: WeightPlan) -> some View {
        let days = WeightPlanCalculator.days(until: plan.targetDate)
        let weeks = min(max(Int((Double(days) / 7).rounded()), 1), 104)
        let months = min(max(Int((Double(days) / 30.44).rounded()), 1), 24)
        let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: DateMath.startOfDay(Date())) ?? Date()
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr("Durée"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(tr("Durée"), selection: $mode) {
                ForEach(DurationMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("weightplan-duration-mode")
            switch mode {
            case .weeks:
                Stepper(value: Binding(get: { weeks }, set: { setDate(daysFromToday: $0 * 7) }), in: 1...104) {
                    Text(tr("En \(Fmt.plural(weeks, tr("semaine"), tr("semaines")))"))
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("weightplan-weeks")
            case .months:
                Stepper(value: Binding(get: { months }, set: { setDate(monthsFromToday: $0) }), in: 1...24) {
                    Text(tr("En \(String(months)) mois"))
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("weightplan-months")
            case .date:
                DatePicker(tr("Date cible"), selection: Binding(get: { max(plan.targetDate, tomorrow) }, set: { model.setWeightPlanDate($0) }),
                           in: tomorrow..., displayedComponents: .date)
                    .accessibilityIdentifier("weightplan-date")
            }
        }
    }

    private func setDate(daysFromToday days: Int) {
        let date = DateMath.calendar.date(byAdding: .day, value: days, to: DateMath.startOfDay(Date())) ?? Date()
        model.setWeightPlanDate(date)
    }

    private func setDate(monthsFromToday months: Int) {
        let date = DateMath.calendar.date(byAdding: .month, value: months, to: DateMath.startOfDay(Date())) ?? Date()
        model.setWeightPlanDate(date)
    }
}

/// The recap of the weight goal (before the calories are applied) and the way to take the goal away.
struct WeightPlanRecap: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.activeWeightPlan != nil {
            VStack(spacing: 8) {
                WeightPlanSummaryView()
                Button(tr("Retirer cet objectif de poids"), role: .destructive) {
                    model.removeWeightPlan()
                }
                .font(.footnote.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("weightplan-remove")
            }
        }
    }
}
