import SwiftUI

/// One line of « Mes informations »: a value the user gave, or data they entered.
struct InfoFact: Identifiable, Hashable {
    let id: String
    let symbol: String
    let title: String
    let value: String
}

extension AppModel {
    /// What « Mes informations » shows for a topic: only what the user gave, never a default.
    func facts(for topic: ProfileTopic) -> [InfoFact] {
        let currency = settings.currencyCode
        var facts: [InfoFact] = []
        func add(_ id: String, _ symbol: String, _ title: String, _ value: String?) {
            guard let value, !value.trimmed.isEmpty else { return }
            facts.append(InfoFact(id: id, symbol: symbol, title: title, value: value))
        }
        func money(_ value: Double?) -> String? { value.map { TF.money($0, currency) } }
        switch topic {
        case .sport:
            add("goal", "target", "Objectif", profile.fitnessGoal?.title)
            add("weight", "scalemass", "Poids", profile.weightKg.map { "\(ProfileNumberField.format($0)) kg" })
            add("height", "ruler", "Taille", profile.heightCm.map(Self.heightText))
            add("age", "person", "Âge", age.map { "\($0) ans" })
            add("workouts", "calendar", "Séances", profile.knows(.weeklyWorkouts) ? "\(fitness.weeklyGoal) par semaine" : nil)
            add("level", "chart.bar.fill", "Niveau", profile.fitnessLevel?.title)
        case .nutrition:
            add("aim", "target", "Objectif", profile.nutritionAim?.title)
            add("kcal", "flame", "Calories", profile.knows(.kcalTarget) ? "\(TF.int(nutrition.goals.kcal)) kcal" : nil)
            add("protein", "bolt.heart", "Protéines", profile.knows(.proteinTarget) ? "\(TF.int(nutrition.goals.protein)) g" : nil)
            add("carbs", "leaf", "Glucides", profile.knows(.carbsTarget) ? "\(TF.int(nutrition.goals.carbs)) g" : nil)
            add("fat", "drop", "Lipides", profile.knows(.fatTarget) ? "\(TF.int(nutrition.goals.fat)) g" : nil)
        case .money:
            add("income", "arrow.down.circle", "Revenu mensuel", money(profile.monthlyIncome))
            add("budget", "creditcard", "Budget", profile.knows(.monthlyBudget) ? TF.money(budget.monthlyBudget, currency) : nil)
            add("savings", "banknote", "Épargne visée", money(profile.monthlySavingsGoal))
            add("expenses", "cart", "Dépenses", profile.mainExpenses.isEmpty ? nil : profile.mainExpenses.prefix(2).joined(separator: ", "))
        case .business:
            add("name", "briefcase", "Activité", profile.knows(.businessName) ? business.name : nil)
            add("goal", "target", "Objectif", profile.knows(.businessGoal) ? "\(TF.money(business.monthlyGoal, currency)) / mois" : nil)
            add("clients", "person.2", "Clients", profile.businessClients.map { Fmt.number($0) })
            add("revenue", "chart.line.uptrend.xyaxis", "Ce mois-ci", business.sales.isEmpty ? nil : TF.money(BusinessMath.revenue(business, .month, at: Date()), currency))
        case .productivity:
            add("goal", "target", "Objectif", profile.mainGoal.trimmed.nonEmpty)
            let open = content.tasks.filter { !$0.isDone }.count
            add("tasks", "checklist", "Tâches du jour", content.tasks.isEmpty ? nil : Fmt.number(open))
            add("work", "clock", "Travail", profile.dailyWorkHours.map { "\(ProfileNumberField.format($0)) h par jour" })
            add("focus", "brain.head.profile", "Concentration", profile.knows(.focusGoal) ? "\(Fmt.hours(productivity.weeklyFocusGoalHours)) / sem." : nil)
        case .studies:
            add("field", "graduationcap", "Études", profile.studyField.trimmed.nonEmpty)
            add("hours", "clock", "Étude perso", profile.weeklyStudyHours.map { "\(ProfileNumberField.format($0)) h / sem." })
            add("courses", "book", "Cours", student.courses.isEmpty ? nil : Fmt.number(student.courses.count))
        case .car:
            add("name", "car", "Voiture", profile.knows(.carName) ? car.name : nil)
            add("km", "gauge.with.dots.needle.33percent", "Compteur", CarMath.odometer(car).map { "\(TF.int($0)) km" })
        case .weather:
            add("city", "location", "Ville", settings.weatherLocation?.name)
        case .wellbeing:
            add("water", "drop.fill", "Eau", profile.knows(.hydrationGoal) ? "\(content.hydration.goal) verres / jour" : nil)
            add("habits", "repeat", "Habitudes", content.habits.isEmpty ? nil : Fmt.number(content.habits.count))
        }
        return facts
    }

    /// How many of a topic's main questions are still unanswered.
    func missingCount(for topic: ProfileTopic) -> Int {
        let answered: [Bool]
        switch topic {
        case .sport:
            answered = [profile.fitnessGoal != nil, profile.weightKg != nil, profile.heightCm != nil, age != nil, profile.knows(.weeklyWorkouts)]
        case .nutrition:
            answered = [profile.knows(.kcalTarget), profile.knows(.proteinTarget), profile.knows(.carbsTarget), profile.knows(.fatTarget)]
        case .money:
            answered = [profile.monthlyIncome != nil, profile.knows(.monthlyBudget), profile.monthlySavingsGoal != nil]
        case .business:
            answered = [profile.knows(.businessName), profile.knows(.businessGoal)]
        case .productivity:
            answered = [!profile.mainGoal.trimmed.isEmpty, profile.dailyWorkHours != nil, profile.knows(.focusGoal)]
        case .studies:
            answered = [!profile.studyField.trimmed.isEmpty, profile.weeklyStudyHours != nil]
        case .car:
            answered = [profile.knows(.carName), CarMath.odometer(car) != nil]
        case .weather:
            answered = [settings.weatherLocation != nil]
        case .wellbeing:
            answered = [profile.knows(.hydrationGoal)]
        }
        return answered.filter { !$0 }.count
    }

    /// The topics « Mes informations » shows: the user's interests first, then any topic they gave values for.
    var infoTopics: [ProfileTopic] {
        let chosen = profile.topics
        let others = ProfileTopic.allCases.filter { !chosen.contains($0) && !facts(for: $0).isEmpty && $0 != .weather }
        return chosen + others
    }

    static func heightText(_ centimetres: Double) -> String {
        let metres = centimetres / 100
        return String(format: "%.2f m", metres).replacingOccurrences(of: ".", with: ",")
    }
}

/// « Mes informations » on the Home tab: one card per topic, each opening its questions.
struct MyInfoSection: View {
    @Environment(AppModel.self) private var model
    @State private var editing: ProfileTopic?
    @State private var editsInterests = false

    var body: some View {
        let topics = model.infoTopics
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mes informations", actionTitle: topics.isEmpty ? nil : "Centres d'intérêt") {
                editsInterests = true
            }
            if topics.isEmpty {
                prompt
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(topics) { topic in
                            Button {
                                editing = topic
                            } label: {
                                InfoCard(topic: topic, facts: model.facts(for: topic), missing: model.missingCount(for: topic))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("info-\(topic.rawValue)")
                        }
                        addCard
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
        .sheet(item: $editing) { topic in
            TopicEditorSheet(topic: topic)
        }
        .sheet(isPresented: $editsInterests) {
            InterestsEditorSheet()
        }
    }

    /// Nothing chosen or given yet: an invitation, never empty cards.
    private var prompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Personnalise Tessera", systemImage: "sparkles")
                .font(.headline)
            Text("Dis ce qui t'intéresse : tes widgets reprendront tes objectifs, ton poids, ton budget… sans que tu aies à les répéter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                editsInterests = true
            } label: {
                Text("Choisir mes centres d'intérêt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
        }
        .card()
    }

    private var addCard: some View {
        Button {
            editsInterests = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
                Text("Ajouter un thème")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
            .frame(width: 120, height: InfoCard.height)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A topic of « Mes informations »: its values, or an invitation to give them.
struct InfoCard: View {
    let topic: ProfileTopic
    let facts: [InfoFact]
    let missing: Int

    static let height: CGFloat = 178

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: topic.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color(hex: topic.colorHex), in: Circle())
                Text(topic.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if !facts.isEmpty && missing > 0 {
                    Text("À compléter")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(light: "8A4B00", dark: "F5B25A"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(light: "FCE8CC", dark: "4A3314"), in: Capsule())
                }
            }
            if facts.isEmpty {
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Ajouter mes informations", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(topic.purpose)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(facts.prefix(4)) { fact in
                        HStack(spacing: 8) {
                            Image(systemName: fact.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(hex: topic.colorHex))
                                .frame(width: 18)
                            Text(fact.title)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(fact.value)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                Spacer(minLength: 0)
                Text(facts.count > 4 ? "et \(facts.count - 4) de plus · Modifier" : "Modifier")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(14)
        .frame(width: 250, height: Self.height, alignment: .topLeading)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Modifier"))
    }
}
