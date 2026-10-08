import SwiftUI

/// What a mini-app lets the person change about themselves, right where they look at it. There is
/// no second copy: every row reads and writes the same data as « Mes informations », so a change
/// here is a change everywhere (widgets, « Mon Quotidien », the other mini-apps), and what depends on
/// it is recalculated (calculated calorie targets follow the weight, for instance).
extension MiniApp {
    /// The questions of « Mes informations » that belong to this mini-app.
    var settingsTopic: ProfileTopic? {
        switch self {
        case .nutrition: .nutrition
        case .fitness: .sport
        case .planning: .productivity
        case .studies: .studies
        case .finances: .money
        case .business: .business
        case .travel: nil
        case .car: .car
        case .weather: .weather
        }
    }

    /// The pieces of data this mini-app uses, editable in place.
    var settingsItems: [DataItem] {
        switch self {
        case .nutrition: [.kcalTarget, .macroTargets, .weight]
        case .fitness: [.routines, .weeklyWorkouts, .weight, .stepGoal]
        case .planning: [.focusGoal, .habits, .hydrationGoal, .priorities]
        case .studies: [.timetable, .exams, .assignments]
        case .finances: [.monthlyBudget, .moneyFlow, .savingsGoals, .bills]
        case .business: [.businessGoal]
        case .travel: [.trip]
        case .car: [.carName, .carDeadlines]
        case .weather: [.city]
        }
    }
}

struct MiniAppSettingsSection: View {
    let app: MiniApp
    @Environment(AppModel.self) private var model
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(tr("Mes paramètres"), systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            summary
            Button {
                withAnimation(.snappy) { isEditing.toggle() }
            } label: {
                Label(isEditing ? tr("Terminé") : tr("Modifier mes paramètres"), systemImage: isEditing ? "checkmark" : "pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(app.color)
            .accessibilityIdentifier("miniapp-settings-edit")
            if isEditing {
                editors
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text(tr("Modifié ici, c'est modifié partout : « Mes informations », tes widgets et « Mon Quotidien »."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("miniapp-settings")
    }

    // MARK: Current values

    private var rows: [(String, String)] {
        var rows: [(String, String)] = []
        let profile = model.profile
        switch app {
        case .nutrition:
            if let height = profile.heightCm { rows.append((tr("Taille", context: "height"), tr("\(TF.int(height)) cm"))) }
            if let aim = profile.nutritionAim { rows.append((tr("Objectif"), aim.title)) }
            if profile.calculatedActivity != nil { rows.append((tr("Calcul"), tr("Suit ton poids et ton activité"))) }
        case .fitness:
            if let goal = profile.fitnessGoal { rows.append((tr("Objectif"), goal.title)) }
            if let level = profile.fitnessLevel { rows.append((tr("Niveau"), level.title)) }
            let days = model.fitness.routines.flatMap(\.weekdays)
            if !days.isEmpty { rows.append((tr("Jours"), Self.weekdays(Set(days)))) }
        case .weather:
            rows.append((tr("Unité"), model.settings.temperatureUnit.title))
        default:
            break
        }
        for item in app.settingsItems where !rows.contains(where: { $0.0 == item.title }) {
            if let value = model.summary(item) { rows.append((item.title, value)) }
        }
        return rows
    }

    @ViewBuilder private var summary: some View {
        let rows = rows
        if rows.isEmpty {
            Text(tr("Rien de renseigné pour l'instant."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.0)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(row.1)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                    if index < rows.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: Editors (the same components as « Mes informations »)

    @ViewBuilder private var editors: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let topic = app.settingsTopic {
                TopicForm(topic: topic)
            }
            if app == .weather {
                Picker(tr("Unité de température"), selection: Binding(
                    get: { model.settings.temperatureUnit },
                    set: { unit in model.updateSettings { $0.temperatureUnit = unit } }
                )) {
                    ForEach(TemperatureUnit.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("weather-unit")
            }
            WidgetDataSection(items: app.settingsItems, title: tr("Tes données"))
        }
    }

    /// ISO weekdays (1 = lundi … 7 = dimanche), Monday first.
    private static func weekdays(_ days: Set<Int>) -> String {
        let symbols = DateMath.calendar.shortWeekdaySymbols    // Sunday first
        return (1...7).filter(days.contains).map { symbols[$0 % 7].capitalized }.joined(separator: " · ")
    }
}
