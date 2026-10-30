import SwiftUI
import UserNotifications

/// « Rappels intelligents »: each one on or off, at its hour. They come only when the thing isn't done
/// yet (`SmartReminders`). Turning one on asks for notifications when Ardane may not send any yet.
/// Reached from Profil › Notifications, and from « Mes paramètres » in Fitness, Nutrition and Finances.
struct SmartRemindersView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: UNAuthorizationStatus?
    @State private var showsExplainer = false
    /// The next reminder, computed when the screen or the settings change (not at each render).
    @State private var next: NotificationEngine.Candidate?

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
                    Label(tr("Notifications refusées"), systemImage: "bell.slash")
                        .foregroundStyle(.orange)
                    Button(tr("Ouvrir les réglages de l'iPhone")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .accessibilityIdentifier("reminders-open-settings")
                } footer: {
                    Text(tr("Les notifications d'Ardane sont refusées dans les réglages de l'iPhone. Tes préférences ci-dessous sont gardées : les rappels partiront dès que tu les autoriseras."))
                }
            } else if status == .authorized || status == .provisional || status == .ephemeral {
                Section {
                    Label(tr("Notifications autorisées"), systemImage: "bell.badge.fill")
                        .foregroundStyle(.green)
                } footer: {
                    Text(tr("Ardane n'envoie que ce qui est utile : rien quand c'est déjà fait, jamais deux fois la même chose."))
                }
            }
            if let next {
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
                categoryToggle(.fitness, binding(\.remindsFitness))
                if settings.remindsFitness {
                    Toggle(isOn: binding(\.remindsWorkout)) {
                        Label(tr("Séance du jour"), systemImage: "figure.strengthtraining.traditional")
                    }
                    .accessibilityIdentifier("reminders-workout")
                    if settings.remindsWorkout {
                        hourPicker(binding(\.workoutReminderHour))
                    }
                }
            } footer: {
                Text(tr("La séance du jour si elle n'est pas commencée à l'heure choisie, les séances restantes de la semaine, tes pas (si le mouvement est autorisé), la séance de demain et le bilan du dimanche. Rien un jour de repos."))
            }
            Section {
                categoryToggle(.nutrition, binding(\.remindsNutrition))
                if settings.remindsNutrition {
                    Toggle(isOn: binding(\.remindsMeals)) {
                        Label(tr("Repas"), systemImage: "fork.knife")
                    }
                    .accessibilityIdentifier("reminders-meals")
                    if settings.remindsMeals {
                        hourPicker(binding(\.mealReminderHour))
                    }
                }
            } footer: {
                Text(tr("Le dîner pas encore noté à ton heure habituelle, ta journée en calories et en protéines, et le bilan de la semaine. Seulement si tu notes tes repas."))
            }
            Section {
                categoryToggle(.habits, binding(\.remindsHabits))
            } footer: {
                Text(tr("Les habitudes qu'il te reste à faire, ta série, un record battu et le bilan de la semaine."))
            }
            Section {
                categoryToggle(.planning, binding(\.remindsPlanning))
            } footer: {
                Text(tr("Un cours 30 minutes avant, les rendez-vous et examens de demain, les tâches importantes du jour. Rien pour un événement supprimé ou annulé."))
            }
            Section {
                categoryToggle(.goals, binding(\.remindsGoals))
                Toggle(isOn: binding(\.encourages)) {
                    Label(tr("Encouragements"), systemImage: "hands.clap")
                }
                .accessibilityIdentifier("reminders-encourage")
            } footer: {
                Text(tr("Ta progression vers tes objectifs, le début de semaine, et un mot après une séance, un record, une longue période d'étude ou un objectif atteint."))
            }
            Section {
                categoryToggle(.general, binding(\.remindsGeneral))
                if settings.remindsGeneral {
                    Toggle(isOn: binding(\.remindsBills)) {
                        Label(tr("Factures"), systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("reminders-bills")
                }
            } footer: {
                Text(tr("La veille de chaque facture et abonnement de Finances, à 9 h."))
            }
            Section {
                hourPicker(binding(\.summaryReminderHour), title: tr("Résumé du soir"))
                Picker(tr("Maximum par jour"), selection: binding(\.dailyNotificationCap)) {
                    ForEach(Array(Set(Array(1...8) + [settings.dailyNotificationCap])).sorted(), id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .accessibilityIdentifier("reminders-cap")
                Picker(tr("Espacement minimal"), selection: binding(\.minNotificationSpacingMinutes)) {
                    ForEach(spacingChoices(settings.minNotificationSpacingMinutes), id: \.self) { value in
                        Text(value == 0 ? tr("Aucun") : Fmt.minutes(Double(value))).tag(value)
                    }
                }
                Picker(tr("Silence à partir de"), selection: binding(\.quietStartHour)) {
                    ForEach(0...23, id: \.self) { value in Text(hourText(value)).tag(value) }
                }
                .accessibilityIdentifier("reminders-quiet-start")
                Picker(tr("Silence jusqu'à"), selection: binding(\.quietEndHour)) {
                    ForEach(0...23, id: \.self) { value in Text(hourText(value)).tag(value) }
                }
            } header: {
                Text(tr("Horaires et fréquence"))
            } footer: {
                Text(tr("Rien n'est envoyé pendant les heures de silence, et jamais plus que le maximum par jour, encouragements compris."))
            }
        }
        .styledList()
        .navigationTitle(tr("Rappels intelligents"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scenePhase) { await refreshStatus() }
        .onChange(of: model.settings) { refreshNext() }
        .permissionSheet(.notifications, isPresented: $showsExplainer, request: requestNotifications) { _ in
            Task {
                await refreshStatus()
                model.syncReminders()
            }
        }
    }

    private func categoryToggle(_ category: SmartCategory, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(category.title, systemImage: category.symbol)
        }
        .accessibilityIdentifier("reminders-category-" + category.rawValue)
    }

    /// The usual spacings, and the saved one when it is another.
    private func spacingChoices(_ current: Int) -> [Int] {
        Array(Set([0, 30, 60, 90, 120, 180, current])).sorted()
    }

    private func hourPicker(_ hour: Binding<Int>, title: String = tr("Heure")) -> some View {
        Picker(title, selection: hour) {
            // The saved hour is always offered, even outside the usual range.
            ForEach(Array(Set(Array(5...23) + [hour.wrappedValue])).sorted(), id: \.self) { value in
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

    /// Explains first (once), then the system prompt. When the sheet is shown, the outcome is handled when it closes.
    private func allow() async {
        if await AppPermission.notifications.requestOrExplain(isPresented: $showsExplainer, request: requestNotifications) != nil {
            await refreshStatus()
            model.syncReminders()
        }
    }

    private func requestNotifications() async {
        _ = await NotificationScheduler.requestAuthorization()
    }

    private func refreshStatus() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        refreshNext()
    }

    /// Only shown when notifications are allowed: otherwise nothing would be sent.
    private func refreshNext() {
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            next = nil
            return
        }
        next = NotificationEngine.plan(model.smartInputs(), log: NotificationLog.load(), encouragements: EncouragementLog.load()).first
    }
}
