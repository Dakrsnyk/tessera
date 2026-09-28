import StoreKit
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(PremiumStore.self) private var premium
    @State private var restoreMessage: String?
    @State private var showsManageSubscriptions = false
    @State private var confirmReset = false
    @State private var copiedEmail = false

    var body: some View {
        NavigationStack {
            Form {
                premiumSection

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
                    NavigationLink {
                        WeatherLocationView()
                    } label: {
                        LabeledContent("Ville (météo)", value: model.settings.weatherLocation?.name ?? "Aucune")
                    }
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
                        router.lastSavedName = nil
                        router.isAddGuidePresented = true
                    } label: {
                        Label("Ajouter un widget à l'écran d'accueil", systemImage: "plus.square.on.square")
                    }
                    Button {
                        model.updateSettings { $0.hasCompletedOnboarding = false }
                    } label: {
                        Label("Revoir la présentation", systemImage: "play.rectangle")
                    }
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
                    Toggle("Premium (mode test)", isOn: Binding(
                        get: { model.premium.testerOverride },
                        set: { value in
                            var state = model.premium
                            state.testerOverride = value
                            model.updatePremium(state)
                        }
                    ))
                    Button("Recharger les widgets") { WidgetCenter.shared.reloadAllTimelines() }
                } header: {
                    Text("Développeur")
                } footer: {
                    Text("Visible uniquement dans les versions de test. Permet de vérifier l'app en mode Premium sans achat.")
                }
                #endif
            }
            .navigationTitle("Réglages")
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
                    router.isPaywallPresented = true
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
        if model.premium.testerOverride && !model.premium.isActive { return "Mode test" }
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
