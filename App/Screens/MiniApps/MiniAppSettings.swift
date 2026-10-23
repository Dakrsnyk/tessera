import SwiftUI

/// « Mes infos » inside each mini-app: the personal information it uses, shown and changed right where
/// the person looks at it. There is no second copy: every answer reads and writes the same data as
/// « Mes informations » on Home, so a change here is a change everywhere (widgets, « Mon Quotidien »,
/// the other mini-apps), and what depends on it is recalculated (the nutrition needs follow the weight,
/// for instance). What the page of the mini-app already lets the person change (a routine, a task, a
/// bill) is not repeated here.
extension MiniApp {
    /// The questions of « Mes informations » this mini-app uses.
    var infoTopics: [ProfileTopic] {
        switch self {
        case .nutrition: [.nutrition]
        case .fitness: [.sport]
        case .planning: [.productivity, .studies]
        // Finances: no « Chaque mois » nor « Tes principales dépenses » here (2026-10-17): the budget is set on
        // the page, the fixed expenses have their own row; they stay in « Mes informations ».
        case .finances: []
        case .business: [.business]
        case .travel: []
        case .car: [.car]
        case .weather: [.weather]
        case .photos: []
        }
    }

    var settingsTopic: ProfileTopic? { infoTopics.first }

    /// Other personal data it uses that none of its questions asks and its page doesn't show.
    var settingsItems: [DataItem] {
        switch self {
        case .fitness: [.stepGoal]
        case .finances: [.moneyFlow]
        default: []
        }
    }

    /// Settings shared by every mini-app that this one depends on.
    var commonSettings: [CommonSetting] {
        switch self {
        case .finances, .business: [.currency]
        case .travel: [.currency, .temperature]
        case .weather: [.temperature]
        case .planning: [.clock]
        default: []
        }
    }

    /// Whether « Mes infos » has something to show.
    var hasInfo: Bool { !infoTopics.isEmpty || !settingsItems.isEmpty || !commonSettings.isEmpty }
}

/// A setting of the whole app shown in the « Mes infos » of the mini-apps that use it.
enum CommonSetting: Hashable {
    case currency, temperature, clock
}

/// The end of a mini-app screen: one button, « Mes paramètres », that opens what the mini-app uses (the same
/// answers as « Mes informations », the settings it depends on, its smart reminder) in a sheet.
struct MiniAppInfoSection: View {
    let app: MiniApp
    @State private var isShowing = false

    var body: some View {
        if app.hasInfo {
            Button {
                isShowing = true
            } label: {
                Label(tr("Mes paramètres"), systemImage: "gearshape")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(app.color)
            .accessibilityIdentifier("miniapp-settings-edit")
            .sheet(isPresented: $isShowing) {
                MiniAppInfoSheet(app: app)
            }
        }
    }
}

/// The smart reminder that goes with a mini-app, and when it comes: a row that opens its settings.
private struct MiniAppReminderRow: View {
    let app: MiniApp
    @Environment(AppModel.self) private var model

    var body: some View {
        if let reminder {
            NavigationLink {
                SmartRemindersView()
            } label: {
                HStack(spacing: 8) {
                    Label(reminder.title, systemImage: "bell.badge")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(reminder.value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .contentShape(Rectangle())
                .miniCard()
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("miniapp-reminder")
        }
    }

    private var reminder: (title: String, value: String)? {
        let settings = model.settings
        func hour(_ value: Int) -> String {
            let date = DateMath.calendar.date(bySettingHour: value, minute: 0, second: 0, of: Date()) ?? Date()
            return Fmt.time(date, uses24Hour: settings.uses24HourClock)
        }
        switch app {
        case .fitness: return (tr("Rappel de séance"), settings.remindsWorkout ? hour(settings.workoutReminderHour) : tr("Désactivé"))
        case .nutrition: return (tr("Rappel des repas"), settings.remindsMeals ? hour(settings.mealReminderHour) : tr("Désactivé"))
        case .finances: return (tr("Rappel des factures"), settings.remindsBills ? tr("La veille") : tr("Désactivé"))
        default: return nil
        }
    }
}

/// What « Mes infos » lets the person change: the questions of « Mes informations » (the same
/// components), the shared settings the mini-app depends on, and the few data its page doesn't show.
struct MiniAppInfoEditors: View {
    let app: MiniApp
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(app.infoTopics) { topic in
                if app.infoTopics.count > 1 {
                    Text(topic.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
                TopicForm(topic: topic, inMiniApp: true)
            }
            if !app.commonSettings.isEmpty {
                QuestionCard(title: tr("Réglages communs"), detail: tr("Pour toute l'app.")) {
                    VStack(spacing: 10) {
                        ForEach(app.commonSettings, id: \.self) { setting in
                            commonSetting(setting)
                        }
                    }
                }
            }
            if !app.settingsItems.isEmpty {
                WidgetDataSection(items: app.settingsItems, title: tr("Tes données"))
            }
        }
    }

    @ViewBuilder private func commonSetting(_ setting: CommonSetting) -> some View {
        switch setting {
        case .currency:
            Picker(tr("Devise"), selection: Binding(
                get: { model.settings.currencyCode },
                set: { code in model.updateSettings { $0.currencyCode = code } }
            )) {
                ForEach(AppSettings.currencies, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("info-currency")
        case .temperature:
            Picker(tr("Unité de température"), selection: Binding(
                get: { model.settings.temperatureUnit },
                set: { unit in model.updateSettings { $0.temperatureUnit = unit } }
            )) {
                ForEach(TemperatureUnit.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("weather-unit")
        case .clock:
            Toggle(tr("Heure sur 24 h"), isOn: Binding(
                get: { model.settings.uses24HourClock },
                set: { on in model.updateSettings { $0.uses24HourClock = on } }
            ))
            .font(.subheadline)
        }
    }
}

/// « Mes paramètres » of a mini-app in a sheet, opened by its last button or from one of its screens (« Définis ton objectif du jour »…).
struct MiniAppInfoSheet: View {
    let app: MiniApp
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MiniAppReminderRow(app: app)
                    MiniAppInfoEditors(app: app)
                    MiniFootnote(text: tr("Les mêmes infos partout : modifiées ici, elles le sont dans « Mes informations », tes autres mini-apps et tes widgets."))
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.screenGradient)
            .navigationTitle(tr("Mes paramètres"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
        }
    }
}
