import StoreKit
import SwiftUI
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
                    LabeledContent("Prénom") {
                        TextField("Facultatif", text: settingBinding(\.profileName))
                            .multilineTextAlignment(.trailing)
                            .textContentType(.givenName)
                            .submitLabel(.done)
                    }
                    LabeledContent("Nom") {
                        TextField("Facultatif", text: Binding(
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
                        .background(.screenFill)
                        .navigationTitle("Centres d'intérêt")
                    } label: {
                        LabeledContent("Centres d'intérêt", value: model.profile.interests.isEmpty ? "Aucun" : Fmt.plural(model.profile.interests.count, "choisi", "choisis"))
                    }
                    Picker("Jours fériés", selection: Binding(
                        get: { model.life.holidayRegion },
                        set: { value in model.update(\.life) { $0.holidayRegion = value } }
                    )) {
                        ForEach(HolidayRegion.allCases) { Text($0.title).tag($0) }
                    }
                    NavigationLink {
                        WeatherLocationView()
                    } label: {
                        LabeledContent("Ville (météo)", value: model.settings.weatherLocation?.name ?? "Aucune")
                    }
                } header: {
                    Text("Mon profil")
                } footer: {
                    Text("Ton nom, ton anniversaire et tes centres d'intérêt restent sur ton iPhone. Tes autres informations (poids, objectifs, budget…) se modifient dans « Mes informations », sur l'accueil.")
                }

                premiumSection

                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        AppStyleGrid(swatchSize: 48)
                        AppearancePicker()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Apparence")
                } footer: {
                    let style = AppStyle.style(model.settings.appStyle)
                    Text("\(style.name) — \(style.tagline). Tes widgets gardent chacun leur propre style.")
                }

                Section("Préférences") {
                    Picker("Température", selection: settingBinding(\.temperatureUnit)) {
                        ForEach(TemperatureUnit.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Heure sur 24 h", isOn: settingBinding(\.uses24HourClock))
                    Picker("Devise (flux d'argent)", selection: settingBinding(\.currencyCode)) {
                        ForEach(AppSettings.currencies, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Devise (crypto)", selection: settingBinding(\.cryptoCurrency)) {
                        ForEach(AppSettings.cryptoCurrencies, id: \.self) { Text($0.uppercased()).tag($0) }
                    }
                }

                Section {
                    LabeledContent("Autorisation", value: notificationStatus)
                    NavigationLink { HydrationView() } label: { Text("Rappels d'hydratation") }
                    NavigationLink { HabitsView() } label: { Text("Rappels d'habitudes") }
                    if notificationStatus == "Refusée" {
                        Button("Ouvrir les réglages de l'iPhone") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Tessera ne demande l'autorisation qu'au moment où tu actives un rappel. Les comptes à rebours ont leur propre rappel dans l'éditeur.")
                }

                Section("Tes données") {
                    NavigationLink { TasksView() } label: { Label("Tâches", systemImage: "checklist") }
                    NavigationLink { HabitsView() } label: { Label("Habitudes", systemImage: "repeat") }
                    NavigationLink { HydrationView() } label: { Label("Hydratation", systemImage: "drop") }
                    NavigationLink { MoneyView() } label: { Label("Revenus et dépenses", systemImage: "dollarsign.circle") }
                    NavigationLink { CalendarAccessView() } label: { Label("Calendrier", systemImage: "calendar") }
                }

                Section("Aide") {
                    Button {
                        showsAddGuide = true
                    } label: {
                        Label("Ajouter un widget à l'écran d'accueil", systemImage: "plus.square.on.square")
                    }
                    Button {
                        // The tutorial covers the whole app: close the profile first.
                        dismiss()
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            router.startTutorial()
                        }
                    } label: {
                        Label("Revoir le tutoriel", systemImage: "graduationcap")
                    }
                    .accessibilityIdentifier("settings-tutorial")
                    Button {
                        rate()
                    } label: {
                        Label("Noter Tessera", systemImage: "star")
                    }
                    .accessibilityIdentifier("settings-rate")
                    Button {
                        UIPasteboard.general.string = PremiumConfiguration.supportEmail
                        copiedEmail = true
                    } label: {
                        LabeledContent {
                            Text(copiedEmail ? "Copiée" : PremiumConfiguration.supportEmail)
                        } label: {
                            Label("Contacter le support", systemImage: "envelope")
                        }
                    }
                }

                Section {
                    Link(destination: PremiumConfiguration.privacyURL) {
                        Label("Confidentialité", systemImage: "hand.raised")
                    }
                    Link(destination: PremiumConfiguration.termsURL) {
                        Label("Conditions d'utilisation", systemImage: "doc.text")
                    }
                } header: {
                    Text("À propos")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tessera \(appVersion)")
                        Text("Météo : Open-Meteo.com (CC BY 4.0). Cours crypto : CoinGecko.")
                        Text("Tes données restent sur ton iPhone. Aucun compte, aucun suivi publicitaire.")
                    }
                    .padding(.top, 6)
                }

                Section {
                    Button("Effacer toutes mes données", role: .destructive) { confirmReset = true }
                }

                #if DEBUG
                Section {
                    Toggle("Premium débloqué (mode test)", isOn: Binding(
                        get: { model.isDebugPremiumOn },
                        set: { model.setDebugPremium($0) }
                    ))
                    Button("Recharger les widgets") { WidgetCenter.shared.reloadAllTimelines() }
                    LabeledContent("Version", value: WidgetDiagnostics.appVersion)
                    LabeledContent("Module des widgets", value: WidgetDiagnostics.isExtensionInstalled ? "Installé" : "Absent")
                    LabeledContent("Espace partagé", value: WidgetDiagnostics.sharedSpaceText)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Groupes accordés")
                        Text(WidgetDiagnostics.groupsText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    LabeledContent("Widgets lancés par iOS", value: WidgetDiagnostics.lastLaunchText)
                } header: {
                    Text("Développeur")
                } footer: {
                    Text("Visible uniquement dans les versions de test : tout est débloqué par défaut pour essayer chaque widget. Cet interrupteur n'existe pas dans la version App Store, où seul un achat débloque Premium.")
                }
                #endif
                }
                .listRowBackground(Rectangle().fill(.cardFill))
            }
            .styledList()
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .sheet(isPresented: $showsAddGuide) { AddToHomeScreenGuide(designName: nil) }
            .task(id: scenePhase) { await refreshNotificationStatus() }
            .manageSubscriptionsSheet(isPresented: $showsManageSubscriptions)
            .alert("Restauration", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
            .confirmationDialog("Effacer toutes tes données ?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Tout effacer", role: .destructive) { model.resetAllData() }
            } message: {
                Text("Tes widgets, tâches, habitudes et montants seront supprimés. Ton abonnement n'est pas touché.")
            }
        }
    }

    private var header: some View {
        let name = model.settings.profileName.trimmed
        return VStack(spacing: 14) {
            ProfileAvatar(name: name, size: 78)
            VStack(spacing: 3) {
                Text(name.isEmpty ? "Ton profil" : name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Label(model.isPremium ? "Tessera Premium" : "Version gratuite", systemImage: model.isPremium ? "sparkles" : "person")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(model.isPremium ? Color.premiumInk : Color.secondary)
            }
            HStack(spacing: 10) {
                stat(model.designs.count, model.designs.count > 1 ? "widgets" : "widget")
                stat(model.content.habits.count, model.content.habits.count > 1 ? "habitudes" : "habitude")
                stat(Space.allCases.filter { model.hasData(in: $0) }.count, "espaces actifs")
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
            DatePicker("Anniversaire", selection: Binding(
                get: { birthday },
                set: { value in model.update(\.life) { $0.birthday = value } }
            ), in: ...Date(), displayedComponents: .date)
        } else {
            Button {
                model.update(\.life) { $0.birthday = Calendar.current.date(byAdding: .year, value: -25, to: Date()) }
            } label: {
                Label("Ajouter mon anniversaire", systemImage: "gift")
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
                        Text("Premium actif").font(.headline)
                        Text(premiumDetail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if model.premium.productID != PremiumConfiguration.lifetimeID && model.premium.isActive {
                    Button("Gérer l'abonnement") { showsManageSubscriptions = true }
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
                            Text("Passer à Premium").font(.headline).foregroundStyle(.primary)
                            Text("Tous les widgets et tous les styles").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
            Button {
                Task {
                    let found = await premium.restore()
                    restoreMessage = found ? "Ton accès Premium est rétabli." : "Aucun achat Premium trouvé pour ce compte Apple."
                }
            } label: {
                HStack {
                    Text("Restaurer les achats")
                    Spacer()
                    if premium.isRestoring { ProgressView() }
                }
            }
            .disabled(premium.isRestoring)
        }
    }

    private var premiumDetail: String {
        #if DEBUG
        if model.isDebugPremiumOn && !model.premium.hasPurchase() { return "Débloqué en mode test" }
        #endif
        switch model.premium.productID ?? "" {
        case PremiumConfiguration.lifetimeID: return "Accès à vie"
        case PremiumConfiguration.yearlyID, PremiumConfiguration.monthlyID:
            if let date = model.premium.expirationDate {
                return "Renouvellement le \(Fmt.format(date, template: "dMMMMyyyy"))"
            }
            return "Abonnement actif"
        default: return "Merci pour ton soutien"
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: notificationStatus = "Autorisée"
        case .denied: notificationStatus = "Refusée"
        case .notDetermined: notificationStatus = "Pas encore demandée"
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
