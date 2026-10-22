import CoreLocation
import CoreMotion
import EventKit
import SwiftUI
import UIKit
import UserNotifications

// Permissions iOS: only what a feature needs, an explanation before the system prompt, a refusal respected.
// The rules, kept in one place:
// - a system prompt only follows an action of the person tied to the feature (turn a reminder on, link the
//   calendar, use the position, show the steps), never the launch;
// - the first time, a short explanation comes first (once per permission, remembered); afterwards the
//   system prompt is asked directly, and iOS itself never shows it twice;
// - refused: a clear message and « Ouvrir Réglages », never a new prompt, never a block: the feature
//   stays usable without.

/// What the system says about a permission, read without ever asking.
enum PermissionState: Equatable {
    case notDetermined, granted, denied
}

/// What to do before using a feature that needs a permission.
enum PermissionStep: Equatable {
    /// Already granted: go ahead.
    case none
    /// Never asked and never explained: show the explanation first.
    case explain
    /// Never asked but already explained: the system prompt can come directly.
    case requestDirectly
    /// Refused: no prompt would appear, offer the iPhone's settings.
    case openSettings
}

/// The decision, pure so that it can be tested without touching any real service.
enum PermissionPolicy {
    static func step(state: PermissionState, explained: Bool) -> PermissionStep {
        switch state {
        case .granted: .none
        case .denied: .openSettings
        case .notDetermined: explained ? .requestDirectly : .explain
        }
    }
}

/// Which permissions already had their explanation (one entry per permission, in UserDefaults).
enum PermissionMemory {
    static let key = "permissionsExplained"

    static func hasExplained(_ permission: AppPermission, defaults: UserDefaults = .standard) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(permission.rawValue)
    }

    static func markExplained(_ permission: AppPermission, defaults: UserDefaults = .standard) {
        var list = defaults.stringArray(forKey: key) ?? []
        guard !list.contains(permission.rawValue) else { return }
        list.append(permission.rawValue)
        defaults.set(list, forKey: key)
    }
}

/// The permissions Ardane may ask for. The camera (food scanner) and Photos (wallpapers) have their own flows.
enum AppPermission: String, CaseIterable, Identifiable {
    case notifications, calendar, location, motion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notifications: tr("Notifications")
        case .calendar: tr("Calendrier")
        case .location: tr("Position")
        case .motion: tr("Mouvement et pas")
        }
    }

    var symbol: String {
        switch self {
        case .notifications: "bell.badge.fill"
        case .calendar: "calendar"
        case .location: "location.fill"
        case .motion: "figure.walk"
        }
    }

    /// Why the app asks, in one sentence.
    var why: String {
        switch self {
        case .notifications: tr("Pour t'envoyer les rappels que tu actives, à l'heure choisie.")
        case .calendar: tr("Pour afficher tes prochains rendez-vous dans Ardane et ses widgets.")
        case .location: tr("Pour trouver la météo là où tu es.")
        case .motion: tr("Pour compter tes pas, ta distance et tes étages avec le capteur de ton iPhone.")
        }
    }

    /// What the app does not do with it.
    var privacy: String {
        switch self {
        case .notifications: tr("Les rappels sont créés sur ton iPhone, sans compte ni serveur.")
        case .calendar: tr("Tes événements restent sur ton iPhone.")
        case .location: tr("Ardane ne s'en sert que pour la météo, une seule fois.")
        case .motion: tr("Tes pas restent sur ton iPhone, sans Santé ni compte.")
        }
    }

    /// The current state, read without showing any system prompt.
    @MainActor
    func currentState() async -> PermissionState {
        switch self {
        case .notifications:
            switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
            case .authorized, .provisional, .ephemeral: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .calendar:
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess: return .granted
            case .notDetermined: return .notDetermined
            // Write-only access cannot read events: the settings are the way to widen it.
            default: return .denied
            }
        case .location:
            switch CLLocationManager().authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .motion:
            // Without a step sensor there is nothing to ask for: the screens show their own message.
            guard CMPedometer.isStepCountingAvailable() else { return .denied }
            switch CMPedometer.authorizationStatus() {
            case .authorized: return .granted
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        }
    }

    /// Call on the person's action. Returns the final state when no sheet is needed (already granted, or the
    /// system prompt came directly after an earlier explanation); returns nil when the explanation sheet was
    /// opened (`isPresented`): the outcome then comes from the `onDismiss` of `permissionSheet`.
    @MainActor
    func requestOrExplain(isPresented: Binding<Bool>, request: () async -> Void) async -> PermissionState? {
        let state = await currentState()
        switch PermissionPolicy.step(state: state, explained: PermissionMemory.hasExplained(self)) {
        case .none:
            return state
        case .explain, .openSettings:
            isPresented.wrappedValue = true
            return nil
        case .requestDirectly:
            await request()
            return await currentState()
        }
    }
}

/// The sheet: icon, why, what the app does not do, « Continuer » / « Plus tard ». Refused: a message and
/// « Ouvrir Réglages ». `request` shows the system prompt (it runs once the person taps « Continuer »).
struct PermissionExplainerView: View {
    let permission: AppPermission
    let request: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var state: PermissionState?
    @State private var isWorking = false

    var body: some View {
        let isDenied = state == .denied
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: permission.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
                    .accessibilityHidden(true)
                Text(permission.title)
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                if isDenied {
                    Text(tr("L'accès est refusé dans Réglages. Tu peux l'activer, ou continuer sans."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(permission.why)
                        .font(.body)
                    Label(permission.privacy, systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                }
                VStack(spacing: 8) {
                    if isDenied {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } label: {
                            Text(tr("Ouvrir Réglages"))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.onAccent)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("permission-settings")
                    } else {
                        Button {
                            isWorking = true
                            Task {
                                PermissionMemory.markExplained(permission)
                                await request()
                                isWorking = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if isWorking { ProgressView() }
                                Text(tr("Continuer"))
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.onAccent)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isWorking)
                        .accessibilityIdentifier("permission-continue")
                    }
                    Button(tr("Plus tard")) { dismiss() }
                        .buttonStyle(.bordered)
                        .disabled(isWorking)
                        .accessibilityIdentifier("permission-later")
                }
                .controlSize(.large)
                .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .padding(24)
        }
        .opacity(state == nil ? 0 : 1)
        // Not while the system's question is up: closing the sheet then would report « not decided yet ».
        .interactiveDismissDisabled(isWorking)
        .task(id: scenePhase) { await refreshState() }
    }

    /// Read again when the person comes back from the settings: granted there closes the sheet.
    private func refreshState() async {
        guard !isWorking else { return }
        let current = await permission.currentState()
        state = current
        if current == .granted { dismiss() }
    }
}

private struct PermissionSheetModifier: ViewModifier {
    let permission: AppPermission
    @Binding var isPresented: Bool
    let request: () async -> Void
    let onDismiss: (PermissionState) -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: {
            Task { @MainActor in onDismiss(await permission.currentState()) }
        }) {
            PermissionExplainerView(permission: permission, request: request)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

extension View {
    /// The explanation sheet of a permission. `onDismiss` receives the state once it closes (granted, still
    /// not asked, or refused) so the screen can switch its feature on or back off.
    func permissionSheet(
        _ permission: AppPermission,
        isPresented: Binding<Bool>,
        request: @escaping () async -> Void,
        onDismiss: @escaping (PermissionState) -> Void = { _ in }
    ) -> some View {
        modifier(PermissionSheetModifier(permission: permission, isPresented: isPresented, request: request, onDismiss: onDismiss))
    }
}
