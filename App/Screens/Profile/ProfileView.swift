import StoreKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import WidgetKit

/// The profile: who the user is, their numbers, and every setting of the app.
/// Opened from the avatar at the top right of the Home tab.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(PremiumStore.self) private var premium
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var showsPaywall = false
    @State private var showsAddGuide = false
    @State private var restoreMessage: String?
    @State private var showsManageSubscriptions = false
    @State private var confirmReset = false
    @State private var backup: BackupDocument?
    @State private var exportsBackup = false
    @State private var importsBackup = false
    @State private var pendingRestore: DataBackup.Archive?
    @State private var backupMessage: String?
    @State private var copiedEmail = false
    @State private var notificationStatus = "—"
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                Group {
                Section {
                    LabeledContent(tr("Prénom")) {
                        TextField(tr("Facultatif"), text: settingBinding(\.profileName))
                            .multilineTextAlignment(.trailing)
                            .textContentType(.givenName)
                            .submitLabel(.done)
                    }
                    LabeledContent(tr("Nom", context: "lastname")) {
                        TextField(tr("Facultatif"), text: Binding(
                            get: { model.profile.lastName },
                            set: { name in model.update(\.profile) { $0.lastName = name } }
                        ))
                        .multilineTextAlignment(.trailing)
                        .textContentType(.familyName)
                        .submitLabel(.done)
                    }
                    birthdayRow
                    NavigationLink {
                        ScrollView {
                            InterestGrid(selection: Binding(
                                get: { model.profile.interests },
                                set: { interests in model.update(\.profile) { $0.interests = interests } }
                            ))
                            .padding(20)
                        }
                        .background(.screenGradient)
                        .navigationTitle(tr("Centres d'intérêt"))
                    } label: {
                        LabeledContent(tr("Centres d'intérêt"), value: model.profile.interests.isEmpty ? tr("Aucun") : Fmt.plural(model.profile.interests.count, tr("choisi"), tr("choisis")))
                    }
                    Picker(tr("Jours fériés"), selection: Binding(
                        get: { model.life.holidayRegion },
                        set: { value in model.update(\.life) { $0.holidayRegion = value } }
                    )) {
                        ForEach(HolidayRegion.allCases) { Text($0.title).tag($0) }
                    }
                    NavigationLink {
                        WeatherLocationView()
                    } label: {
                        LabeledContent(tr("Ville (météo)"), value: model.settings.weatherLocation?.name ?? tr("Aucune"))
                    }
                } header: {
                    Text(tr("Mon profil"))
                } footer: {
                    Text(tr("Ton nom, ton anniversaire et tes centres d'intérêt restent sur ton iPhone. Tes autres informations (poids, objectifs, budget…) se modifient dans « Mes informations », sur l'accueil."))
                }

                premiumSection

                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        AppStyleGrid(swatchSize: 48)
                        AppearancePicker()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text(tr("Apparence"))
                } footer: {
                    let style = AppStyle.style(model.settings.appStyle)
                    Text(tr("\(style.name) — \(style.tagline). Tes widgets gardent chacun leur propre style."))
                }

                Section(tr("Préférences")) {
                    NavigationLink {
                        AppIconPicker()
                    } label: {
                        Label(tr("Icône de l'app"), systemImage: "app.badge")
                    }
                    .accessibilityIdentifier("settings-app-icon")
                    Picker(tr("Température"), selection: settingBinding(\.temperatureUnit)) {
                        ForEach(TemperatureUnit.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle(tr("Heure sur 24 h"), isOn: settingBinding(\.uses24HourClock))
                    Picker(tr("Devise (flux d'argent)"), selection: settingBinding(\.currencyCode)) {
                        ForEach(AppSettings.currencies, id: \.self) { Text($0).tag($0) }
                    }
                    Picker(tr("Devise (crypto)"), selection: settingBinding(\.cryptoCurrency)) {
                        ForEach(AppSettings.cryptoCurrencies, id: \.self) { Text($0.uppercased()).tag($0) }
                    }
                }

                Section {
                    LabeledContent(tr("Autorisation"), value: notificationStatus)
                    NavigationLink { SmartRemindersView() } label: { Text(tr("Rappels intelligents")) }
                        .accessibilityIdentifier("settings-smart-reminders")
                    NavigationLink { HydrationView() } label: { Text(tr("Rappels d'hydratation")) }
                    NavigationLink { HabitsView() } label: { Text(tr("Rappels d'habitudes")) }
                    if notificationStatus == tr("Refusée") {
                        Button(tr("Ouvrir les réglages de l'iPhone")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text(tr("Notifications"))
                } footer: {
                    Text(tr("Ardane ne demande l'autorisation qu'au moment où tu actives un rappel. Les comptes à rebours ont leur propre rappel dans l'éditeur."))
                }

                Section(tr("Tes données")) {
                    NavigationLink { TasksView() } label: { Label(tr("Tâches"), systemImage: "checklist") }
                    NavigationLink { HabitsView() } label: { Label(tr("Habitudes"), systemImage: "repeat") }
                    NavigationLink { HydrationView() } label: { Label(tr("Hydratation"), systemImage: "drop") }
                    NavigationLink { MoneyView() } label: { Label(tr("Revenus et dépenses"), systemImage: "dollarsign.circle") }
                    NavigationLink { CalendarAccessView() } label: { Label(tr("Calendrier"), systemImage: "calendar") }
                }

                Section(tr("Aide")) {
                    Button {
                        showsAddGuide = true
                    } label: {
                        Label(tr("Ajouter un widget à l'écran d'accueil"), systemImage: "plus.square.on.square")
                    }
                    Button {
                        // The tutorial covers the whole app: close the profile first.
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            router.startTutorial()
                        }
                    } label: {
                        Label(tr("Revoir le tutoriel"), systemImage: "graduationcap")
                    }
                    .accessibilityIdentifier("settings-tutorial")
                    Button {
                        rate()
                    } label: {
                        Label(tr("Noter Ardane"), systemImage: "star")
                    }
                    .accessibilityIdentifier("settings-rate")
                    Button {
                        UIPasteboard.general.string = PremiumConfiguration.supportEmail
                        copiedEmail = true
                    } label: {
                        LabeledContent {
                            Text(copiedEmail ? tr("Copiée") : PremiumConfiguration.supportEmail)
                        } label: {
                            Label(tr("Contacter le support"), systemImage: "envelope")
                        }
                    }
                }

                Section {
                    Link(destination: PremiumConfiguration.privacyURL) {
                        Label(tr("Confidentialité"), systemImage: "hand.raised")
                    }
                    Link(destination: PremiumConfiguration.termsURL) {
                        Label(tr("Conditions d'utilisation"), systemImage: "doc.text")
                    }
                } header: {
                    Text(tr("À propos"))
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Ardane \(appVersion)"))
                        Text(tr("Météo : Open-Meteo.com (CC BY 4.0). Cours crypto : CoinGecko."))
                        Text(tr("Tes données restent sur ton iPhone. Aucun compte, aucun suivi publicitaire."))
                    }
                    .padding(.top, 6)
                }

                Section {
                    Button {
                        exportBackup()
                    } label: {
                        Label(tr("Exporter mes données"), systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("backup-export")
                    .fileExporter(isPresented: $exportsBackup, document: backup, contentType: .json,
                                  defaultFilename: DataBackup.fileName(Date())) { result in
                        if case .success = result { backupMessage = tr("Sauvegarde enregistrée. Garde-la dans Fichiers ou iCloud Drive.") }
                        backup = nil
                    }
                    Button {
                        importsBackup = true
                    } label: {
                        Label(tr("Restaurer une sauvegarde"), systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("backup-import")
                    .fileImporter(isPresented: $importsBackup, allowedContentTypes: [.json]) { result in
                        guard case let .success(url) = result else { return }
                        readBackup(at: url)
                    }
                } header: {
                    Text(tr("Sauvegarde"))
                } footer: {
                    Text(tr("Un fichier avec tes widgets, les données de tes mini-apps et tes réglages, à garder dans Fichiers ou iCloud Drive. Il remet tout en place sur cet iPhone ou un autre."))
                }

                Section {
                    Button(tr("Effacer toutes mes données"), role: .destructive) { confirmReset = true }
                }

                #if DEBUG
                Section {
                    Toggle(tr("Premium débloqué (mode test)"), isOn: Binding(
                        get: { model.isDebugPremiumOn },
                        set: { model.setDebugPremium($0) }
                    ))
                    Button(tr("Recharger les widgets")) { WidgetCenter.shared.reloadAllTimelines() }
                    LabeledContent(tr("Version"), value: WidgetDiagnostics.appVersion)
                    LabeledContent(tr("Module des widgets"), value: WidgetDiagnostics.isExtensionInstalled ? tr("Installé") : tr("Absent"))
                    LabeledContent(tr("Espace partagé"), value: WidgetDiagnostics.sharedSpaceText)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Groupes accordés"))
                        Text(WidgetDiagnostics.groupsText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    LabeledContent(tr("Widgets lancés par iOS"), value: WidgetDiagnostics.lastLaunchText)
                } header: {
                    Text(tr("Développeur"))
                } footer: {
                    Text(tr("Visible uniquement dans les versions de test : tout est débloqué par défaut pour essayer chaque widget. Cet interrupteur n'existe pas dans la version App Store, où seul un achat débloque Premium."))
                }
                #endif
                }
                .listRowBackground(Rectangle().fill(.cardFill))
            }
            .styledList()
            .navigationTitle(tr("Profil"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK")) { dismiss() }
                }
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .sheet(isPresented: $showsAddGuide) { AddToHomeScreenGuide(designName: nil) }
            .task(id: scenePhase) { await refreshNotificationStatus() }
            .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
            .alert(tr("Restauration"), isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
            .confirmationDialog(tr("Remplacer tes données par cette sauvegarde ?"), isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }), titleVisibility: .visible) {
                Button(tr("Restaurer"), role: .destructive) {
                    if let archive = pendingRestore {
                        model.restore(archive)
                        backupMessage = tr("Tes données sont de retour.")
                    }
                    pendingRestore = nil
                }
            } message: {
                Text(tr("Les données actuelles de l'app seront remplacées par celles de la sauvegarde du \(Fmt.longDay(pendingRestore?.date ?? Date())). Ton abonnement n'est pas touché."))
            }
            .alert(tr("Sauvegarde"), isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
            .confirmationDialog(tr("Effacer toutes tes données ?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(tr("Tout effacer"), role: .destructive) { model.resetAllData() }
            } message: {
                Text(tr("Tes widgets, tâches, habitudes et montants seront supprimés. Ton abonnement n'est pas touché."))
            }
        }
    }

    private func exportBackup() {
        do {
            backup = BackupDocument(data: try DataBackup.make())
            exportsBackup = true
        } catch {
            backupMessage = tr("La sauvegarde n'a pas pu être créée.")
        }
    }

    /// Reads the file chosen and asks before replacing anything; a file that isn't a backup changes nothing.
    private func readBackup(at url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            pendingRestore = try DataBackup.read(Data(contentsOf: url))
        } catch DataBackup.Failure.newerVersion {
            backupMessage = tr("Cette sauvegarde vient d'une version plus récente d'Ardane. Mets l'app à jour, puis réessaie.")
        } catch {
            backupMessage = tr("Ce fichier n'est pas une sauvegarde d'Ardane, ou il est abîmé. Rien n'a été changé.")
        }
    }

    private var header: some View {
        let name = model.settings.profileName.trimmed
        return VStack(spacing: 14) {
            ProfileAvatar(name: name, size: 78)
            VStack(spacing: 3) {
                Text(name.isEmpty ? tr("Ton profil") : name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Label(model.isPremium ? tr("Ardane Premium") : tr("Version gratuite"), systemImage: model.isPremium ? "sparkles" : "person")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(model.isPremium ? Color.premiumInk : Color.secondary)
            }
            HStack(spacing: 10) {
                stat(model.designs.count, model.designs.count > 1 ? tr("widgets") : tr("widget"))
                stat(model.content.habits.count, model.content.habits.count > 1 ? tr("habitudes") : tr("habitude"))
                stat(Space.allCases.filter { model.hasData(in: $0) }.count, tr("espaces actifs"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder private var birthdayRow: some View {
        if let birthday = model.life.birthday {
            DatePicker(tr("Anniversaire"), selection: Binding(
                get: { birthday },
                set: { value in model.update(\.life) { $0.birthday = value } }
            ), in: ...Date(), displayedComponents: .date)
        } else {
            Button {
                model.update(\.life) { $0.birthday = Calendar.current.date(byAdding: .year, value: -25, to: Date()) }
            } label: {
                Label(tr("Ajouter mon anniversaire"), systemImage: "gift")
            }
        }
    }

    /// The App Store's review page when the app is published, else Apple's rating prompt.
    private func rate() {
        if let id = PremiumConfiguration.appStoreID, let url = URL(string: "https://apps.apple.com/app/id\(id)?action=write-review") {
            openURL(url)
        } else {
            requestReview()
        }
        model.updateSettings { ReviewPrompt.markAsked(&$0) }
    }

    @ViewBuilder private var premiumSection: some View {
        Section {
            if model.isPremium {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.premiumInk)
                        .frame(width: 36, height: 36)
                        .background(Color.premiumFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Premium actif")).font(.headline)
                        Text(premiumDetail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if model.premium.productID != PremiumConfiguration.lifetimeID && model.premium.isActive {
                    Button(tr("Gérer l'abonnement")) { showsManageSubscriptions = true }
                }
            } else {
                Button {
                    showsPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.premiumInk)
                            .frame(width: 36, height: 36)
                            .background(Color.premiumFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Passer à Premium")).font(.headline).foregroundStyle(.primary)
                            Text(tr("Tous les widgets et tous les styles")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            Button {
                Task {
                    let found = await premium.restore()
                    restoreMessage = found ? tr("Ton accès Premium est rétabli.") : tr("Aucun achat Premium trouvé pour ce compte Apple.")
                }
            } label: {
                HStack {
                    Text(tr("Restaurer les achats"))
                    Spacer()
                    if premium.isRestoring { ProgressView() }
                }
            }
            .disabled(premium.isRestoring)
        }
    }

    private var premiumDetail: String {
        #if DEBUG
        if model.isDebugPremiumOn && !model.premium.hasPurchase() { return tr("Débloqué en mode test") }
        #endif
        switch model.premium.productID ?? "" {
        case PremiumConfiguration.lifetimeID: return tr("Accès à vie")
        case PremiumConfiguration.yearlyID, PremiumConfiguration.monthlyID:
            if let date = model.premium.expirationDate {
                return tr("Renouvellement le \(Fmt.format(date, template: "dMMMMyyyy"))")
            }
            return tr("Abonnement actif")
        default: return tr("Merci pour ton soutien")
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationStatus = tr("Autorisée")
        case .denied: notificationStatus = tr("Refusée")
        case .notDetermined: notificationStatus = tr("Pas encore demandée")
        @unknown default: notificationStatus = "—"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func settingBinding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}

/// Initials on the accent color, or a person symbol before a name is set.
struct ProfileAvatar: View {
    let name: String
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.46, weight: .semibold))
            } else {
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(.onAccent)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
