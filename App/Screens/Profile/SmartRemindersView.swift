import SwiftUI
import UserNotifications

/// « Rappels intelligents »: each one on or off, at its hour. They come only when the thing isn't done
/// yet (`SmartReminders`). Turning one on asks for notifications when Tessera may not send any yet.
/// Reached from Profil › Notifications, and from « Mes paramètres » in Fitness, Nutrition and Finances.
struct SmartRemindersView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        let settings = model.settings
        List {
            if status == .notDetermined {
                Section {
                    Button {
                        Task { await allow() }
                    } label: {
                        Label(tr("Autoriser les notifications"), systemImage: "bell.badge")
                    }
                    .accessibilityIdentifier("reminders-allow")
                } footer: {
                    Text(tr("Les rappels ci-dessous partent une fois les notifications autorisées."))
                }
            } else if status == .denied {
                Section {
                    Button(tr("Ouvrir les réglages de l'iPhone")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } footer: {
                    Text(tr("Les notifications de Tessera sont refusées dans les réglages de l'iPhone."))
                }
            }
            if let next = SmartReminders.plan(fitness: model.fitness, nutrition: model.nutrition, budget: model.budget, settings: settings).first {
                Section(tr("Prochain rappel")) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(next.title).font(.subheadline.weight(.semibold))
                        Text(next.body).font(.footnote).foregroundStyle(.secondary)
                        Text(when(next.date)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            Section {
                Toggle(isOn: binding(\.remindsWorkout)) {
                    Label(tr("Séance du jour"), systemImage: "figure.strengthtraining.traditional")
                }
                .accessibilityIdentifier("reminders-workout")
                if settings.remindsWorkout {
                    hourPicker(binding(\.workoutReminderHour))
                }
            } footer: {
                Text(tr("Un jour où ton programme prévoit une séance, si elle n'est pas commencée à cette heure."))
            }
            Section {
                Toggle(isOn: binding(\.remindsMeals)) {
                    Label(tr("Repas"), systemImage: "fork.knife")
                }
                .accessibilityIdentifier("reminders-meals")
                if settings.remindsMeals {
                    hourPicker(binding(\.mealReminderHour))
                }
            } footer: {
                Text(tr("Si aucun repas n'est noté ce jour-là. Seulement si tu as noté des repas cette semaine."))
            }
            Section {
                Toggle(isOn: binding(\.remindsBills)) {
                    Label(tr("Factures"), systemImage: "doc.text")
                }
                .accessibilityIdentifier("reminders-bills")
            } footer: {
                Text(tr("La veille de chaque facture et abonnement de Finances, à 9 h."))
            }
        }
        .styledList()
        .navigationTitle(tr("Rappels intelligents"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scenePhase) { await refreshStatus() }
    }

    private func hourPicker(_ hour: Binding<Int>) -> some View {
        Picker(tr("Heure"), selection: hour) {
            ForEach(5...23, id: \.self) { value in
                Text(hourText(value)).tag(value)
            }
        }
    }

    private func hourText(_ hour: Int) -> String {
        let date = DateMath.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return Fmt.time(date, uses24Hour: model.settings.uses24HourClock)
    }

    /// « Aujourd'hui à 18:00 », « Demain à 20:00 », « Samedi 11 octobre à 09:00 ».
    private func when(_ date: Date) -> String {
        let time = Fmt.time(date, uses24Hour: model.settings.uses24HourClock)
        if DateMath.isSameDay(date, Date()) { return tr("Aujourd'hui à \(time)") }
        if let tomorrow = DateMath.calendar.date(byAdding: .day, value: 1, to: Date()), DateMath.isSameDay(date, tomorrow) {
            return tr("Demain à \(time)")
        }
        return tr("\(Fmt.longDay(date)) à \(time)")
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in
                model.updateSettings { $0[keyPath: keyPath] = value }
                // A reminder turned on: the permission is asked now, while it means something.
                if let isOn = value as? Bool, isOn, status == .notDetermined {
                    Task { await allow() }
                }
            }
        )
    }

    private func allow() async {
        _ = await NotificationScheduler.requestAuthorization()
        await refreshStatus()
        model.syncReminders()
    }

    private func refreshStatus() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
