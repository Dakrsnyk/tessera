import AVFoundation
import CoreMotion
import SwiftUI
import UIKit

/// The last page of the first setup, and the same cards in Profil › Autorisations. Each permission shows what
/// it is for BEFORE any request; « Autoriser » then shows the real iOS prompt (never an imitation). A refusal
/// is respected: « Ouvrir Réglages », never a new prompt, and the app stays usable without.
enum PermissionsSetup {
    static let seenKey = "permissionsSetupSeen"

    /// The order of the cards: the most useful first.
    static let order: [AppPermission] = [.notifications, .motion, .camera, .calendar]

    /// Written when the page is shown (nothing reads it yet: kept for a later « already seen » decision).
    static func markSeen(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: seenKey)
    }

    /// What the person gets, concretely (the privacy line comes from `AppPermission.privacy`).
    static func benefit(_ permission: AppPermission) -> String {
        switch permission {
        case .notifications: tr("Rappels de repas, d'habitudes, de séances et de planning, et quelques encouragements, à l'heure que tu choisis.")
        case .motion: tr("Tes pas, ta distance et tes étages dans Mon Quotidien et Fitness.")
        case .camera: tr("Scanner un code-barres ou photographier un plat pour l'ajouter à ton journal.")
        case .calendar: tr("Tes prochains rendez-vous dans Planning et dans le widget À venir.")
        }
    }

    /// What the card offers for a state, from the shared policy (nothing is asked when it would not appear).
    static func action(state: PermissionState, explained: Bool) -> PermissionStep {
        PermissionPolicy.step(state: state, explained: explained)
    }

    /// Whether the device can ever grant it (a step sensor is needed for the steps).
    @MainActor
    static func isAvailable(_ permission: AppPermission) -> Bool {
        permission == .motion ? CMPedometer.isStepCountingAvailable() : true
    }

    /// The real system request. Only called from the person's tap, only while the answer is still open.
    @MainActor
    static func request(_ permission: AppPermission) async {
        switch permission {
        case .notifications: _ = await NotificationScheduler.requestAuthorization()
        case .calendar: _ = await CalendarService.requestAccess()
        case .motion: await StepCounter.shared.refresh(asking: true)
        case .camera: _ = await AVCaptureDevice.requestAccess(for: .video)
        }
    }
}

/// One permission: icon, benefit, privacy line, its state and the one button that fits.
struct PermissionRowCard: View {
    let permission: AppPermission
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: PermissionState?
    @State private var isAsking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: permission.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
                    .accessibilityHidden(true)
                Text(permission.title)
                    .font(.headline)
                Spacer(minLength: 8)
                statusLabel
            }
            Text(PermissionsSetup.benefit(permission))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Label(permission.privacy, systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            actionView
        }
        .card(padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("permission-card-\(permission.rawValue)")
        .task(id: scenePhase) { await refresh() }
    }

    private var available: Bool { PermissionsSetup.isAvailable(permission) }

    private var step: PermissionStep? {
        guard let state else { return nil }
        return PermissionsSetup.action(state: state, explained: PermissionMemory.hasExplained(permission))
    }

    @ViewBuilder private var statusLabel: some View {
        if !available {
            Text(tr("Indisponible"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            switch state {
            case .granted:
                Label(tr("Accordée"), systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            case .denied:
                Label(tr("Refusée"), systemImage: "xmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            case .notDetermined:
                Text(tr("Pas encore demandée"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            case nil:
                EmptyView()
            }
        }
    }

    @ViewBuilder private var actionView: some View {
        if !available {
            Text(tr("Cet iPhone n'a pas le capteur nécessaire."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            switch step {
            case .explain, .requestDirectly:
                Button {
                    ask()
                } label: {
                    HStack {
                        if isAsking { ProgressView() }
                        Text(tr("Autoriser"))
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAsking)
                .accessibilityIdentifier("permission-allow-\(permission.rawValue)")
            case .openSettings:
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("L'accès est refusé. Tu peux l'activer dans Réglages › Ardane, ou continuer sans."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Text(tr("Ouvrir Réglages"))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("permission-settings-\(permission.rawValue)")
                }
            case .some(.none), nil:
                EmptyView()
            }
        }
    }

    private func ask() {
        guard !isAsking else { return }
        isAsking = true
        Task { @MainActor in
            // The benefit above is the explanation: from now on the system prompt can come directly.
            PermissionMemory.markExplained(permission)
            if await permission.currentState() == .notDetermined {
                await PermissionsSetup.request(permission)
            }
            state = await permission.currentState()
            isAsking = false
            // Notifications just allowed: the reminders are planned now, not at the next change of data.
            if permission == .notifications, state == .granted { model.syncReminders() }
        }
    }

    /// Read again when the person comes back from the settings.
    private func refresh() async {
        guard !isAsking else { return }
        state = await permission.currentState()
    }
}

/// The page itself, inside the onboarding's scroll view: the notifications only (PDG, 2026-11-22). The camera, the
/// calendar and the motion are asked when they are first used (the first scan of a meal, the calendar in Planning,
/// the steps in Fitness), each behind its own explanation; all of them stay in Profil › Autorisations.
struct PermissionsStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(
                symbol: "bell.badge.fill", colorHex: "34C759",
                title: tr("Notifications"),
                message: tr("Les autres accès (caméra, calendrier, mouvement) te seront demandés au moment où tu en auras besoin.")
            )
            // Every notification in one go: one card, one iOS prompt, instead of a request per mini-app.
            AllNotificationsCard()
            Text(tr("Tu retrouveras tout dans Profil › Autorisations."))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// The last page of the first setup: all the notifications in one go. The person picks the families they want
/// (the same switches as Profil › Rappels), then one button shows the real iOS prompt once. Nothing counts as
/// allowed before iOS says so: the state is read back from the system, and a refusal leads to Réglages, never to a
/// second prompt. The switches are only the person's wishes; nothing is sent until iOS allows it.
struct AllNotificationsCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: PermissionState?
    @State private var isAsking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: AppPermission.notifications.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Toutes tes notifications en une fois"))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    statusText
                }
                Spacer(minLength: 0)
            }
            Text(tr("Choisis ce qui t'intéresse, puis autorise une seule fois : chaque mini-app en profite."))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(SmartCategory.allCases) { category in
                    Toggle(isOn: Self.binding(category, model: model)) {
                        Label(category.title, systemImage: category.symbol)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("all-notifications-\(category.rawValue)")
                }
            }
            Label(AppPermission.notifications.privacy, systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            action
        }
        .card(padding: 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("all-notifications-card")
        .task(id: scenePhase) { await refresh() }
    }

    @ViewBuilder private var statusText: some View {
        switch state {
        case .granted:
            Label(tr("Accordée"), systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
        case .denied:
            Label(tr("Refusée"), systemImage: "xmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.orange)
        case .notDetermined, nil:
            Text(tr("Pas encore demandée"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var action: some View {
        let anyChosen = SmartCategory.allCases.contains { $0.isEnabled(in: model.settings) }
        switch state {
        case .notDetermined:
            Button(action: ask) {
                HStack {
                    if isAsking { ProgressView() }
                    Text(tr("Activer les notifications"))
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAsking || !anyChosen)
            .accessibilityIdentifier("all-notifications-allow")
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("L'accès est refusé. Tu peux l'activer dans Réglages › Ardane, ou continuer sans."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text(tr("Ouvrir Réglages"))
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("all-notifications-settings")
            }
        case .granted:
            Text(tr("C'est fait : tu peux changer chaque famille dans Profil › Rappels."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case nil:
            EmptyView()
        }
    }

    /// The switch of a family, written in the settings at once (the same values as Profil › Rappels).
    static func binding(_ category: SmartCategory, model: AppModel) -> Binding<Bool> {
        let path = keyPath(category)
        return Binding(get: { model.settings[keyPath: path] }, set: { isOn in model.updateSettings { $0[keyPath: path] = isOn } })
    }

    static func keyPath(_ category: SmartCategory) -> WritableKeyPath<AppSettings, Bool> {
        switch category {
        case .nutrition: return \.remindsNutrition
        case .habits: return \.remindsHabits
        case .fitness: return \.remindsFitness
        case .planning: return \.remindsPlanning
        case .goals: return \.remindsGoals
        case .general: return \.remindsGeneral
        }
    }

    /// The one real iOS prompt, from the person's tap, only while the answer is still open.
    private func ask() {
        guard !isAsking else { return }
        isAsking = true
        Task { @MainActor in
            PermissionMemory.markExplained(.notifications)
            if await AppPermission.notifications.currentState() == .notDetermined {
                await PermissionsSetup.request(.notifications)
            }
            state = await AppPermission.notifications.currentState()
            isAsking = false
            // Allowed: the reminders of the families chosen are planned now.
            if state == .granted { model.syncReminders() }
        }
    }

    private func refresh() async {
        guard !isAsking else { return }
        state = await AppPermission.notifications.currentState()
    }
}
