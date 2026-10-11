import SwiftUI
import WidgetKit

/// Settings specific to the widget kind being edited.
struct KindOptionsSection: View {
    @Binding var design: WidgetDesign
    @Environment(AppModel.self) private var model

    var body: some View {
        switch design.kind {
        case .clock:
            EditorSection(title: tr("Contenu")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(tr("Afficher la date"), isOn: $design.options.clockShowsDate)
                    Text(tr("Le format 12 h / 24 h se règle dans Réglages."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        case .worldClock:
            EditorSection(title: tr("Villes"), detail: tr("\(design.options.cities.count) sur 4")) {
                VStack(spacing: 0) {
                    ForEach(design.options.cities, id: \.self) { id in
                        HStack {
                            Text(WorldCities.name(for: id))
                            Spacer()
                            if let zone = TimeZone(identifier: id) {
                                Text(WorldCities.offsetText(for: zone, at: Date()))
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                design.options.cities.removeAll { $0 == id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(tr("Retirer \(WorldCities.name(for: id))")))
                        }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        Divider()
                    }
                    if design.options.cities.count < 4 {
                        NavigationLink {
                            CityPickerView(selected: $design.options.cities)
                        } label: {
                            Label(tr("Ajouter une ville"), systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                }
            }
        case .progress:
            EditorSection(title: tr("Période")) {
                Picker(tr("Période"), selection: $design.options.progressUnit) {
                    ForEach(ProgressUnit.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        case .countdown:
            EditorSection(title: tr("Événement")) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(tr("Nom de l'événement"), text: $design.options.countdownTitle)
                        .padding(12)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Picker(tr("Mode"), selection: $design.options.countdownMode) {
                        ForEach(CountdownMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker(tr("Date"), selection: $design.options.countdownDate, displayedComponents: .date)
                        .environment(\.locale, Fmt.locale)
                    if design.options.countdownMode == .until {
                        Toggle(tr("Me rappeler le jour J"), isOn: Binding(
                            get: { design.options.countdownReminder },
                            set: { newValue in
                                design.options.countdownReminder = newValue
                                if newValue { Task { _ = await NotificationScheduler.requestAuthorization() } }
                            }
                        ))
                    }
                }
                .font(.subheadline)
            }
        case .tasks:
            EditorSection(title: tr("Contenu")) {
                VStack(spacing: 0) {
                    Toggle(tr("Garder les tâches cochées aujourd'hui"), isOn: $design.options.showsCompletedTasks)
                        .frame(minHeight: 44)
                    Divider()
                    contentLink(tr("Gérer mes tâches"), detail: tr("\(model.content.tasks.filter { !$0.isDone }.count) à faire")) { TasksView() }
                }
                .font(.subheadline)
            }
        case .habits:
            EditorSection(title: tr("Contenu")) {
                contentLink(tr("Gérer mes habitudes"), detail: "\(model.content.habits.count)") { HabitsView() }
            }
        case .hydration:
            EditorSection(title: tr("Contenu")) {
                VStack(spacing: 0) {
                    Stepper(value: Binding(
                        get: { model.content.hydration.goal },
                        set: { goal in model.setHydrationGoal(goal) }
                    ), in: 1...20) {
                        Text(tr("Objectif : \(model.content.hydration.goal) verres"))
                    }
                    .frame(minHeight: 44)
                    Divider()
                    contentLink(tr("Suivi et rappels"), detail: nil) { HydrationView() }
                }
                .font(.subheadline)
            }
        case .focus:
            EditorSection(title: tr("Contenu")) {
                Text(tr("Lance une session de 15, 25 ou 50 minutes directement depuis le widget. Le minuteur défile en direct sur ton écran d'accueil."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .upNext:
            EditorSection(title: tr("Calendrier")) {
                CalendarAccessRow()
            }
        case .note:
            EditorSection(title: tr("Texte")) {
                VStack(spacing: 12) {
                    TextField(tr("Titre (facultatif)"), text: $design.options.noteTitle)
                        .padding(12)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    TextField(tr("Ta note"), text: $design.options.noteText, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(12)
                        .background(.screenFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: design.options.noteText) { _, text in
                            if text.count > 180 { design.options.noteText = String(text.prefix(180)) }
                        }
                    HStack {
                        Spacer()
                        Text("\(design.options.noteText.count)/180")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .weather:
            EditorSection(title: tr("Lieu")) {
                VStack(spacing: 0) {
                    contentLink(model.settings.weatherLocation?.name ?? tr("Choisir une ville"), detail: nil) { WeatherLocationView() }
                    Divider()
                    HStack {
                        Text(tr("Unité"))
                        Spacer()
                        Picker(tr("Unité"), selection: Binding(
                            get: { model.settings.temperatureUnit },
                            set: { unit in model.updateSettings { $0.temperatureUnit = unit } }
                        )) {
                            Text("°C").tag(TemperatureUnit.celsius)
                            Text("°F").tag(TemperatureUnit.fahrenheit)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    .frame(minHeight: 44)
                }
                .font(.subheadline)
            }
        case .crypto:
            EditorSection(title: tr("Actif")) {
                VStack(spacing: 0) {
                    Picker(tr("Crypto"), selection: $design.options.coinID) {
                        ForEach(CryptoService.coins) { coin in
                            Text("\(coin.name) (\(coin.symbol))").tag(coin.id)
                        }
                    }
                    .frame(minHeight: 44)
                    Divider()
                    Picker(tr("Devise"), selection: Binding(
                        get: { model.settings.cryptoCurrency },
                        set: { value in model.updateSettings { $0.cryptoCurrency = value } }
                    )) {
                        ForEach(AppSettings.cryptoCurrencies, id: \.self) { Text($0.uppercased()).tag($0) }
                    }
                    .frame(minHeight: 44)
                    Divider()
                    Text(tr("Cours fournis par CoinGecko, mis à jour toutes les 15 minutes environ. À titre informatif, pas un conseil financier."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }
                .font(.subheadline)
            }
        case .moneyFlow:
            EditorSection(title: tr("Contenu")) {
                VStack(spacing: 12) {
                    Picker(tr("Afficher"), selection: $design.options.moneyMode) {
                        ForEach(MoneyMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    contentLink(tr("Mes revenus et dépenses"), detail: "\(model.content.money.items.count)") { MoneyView() }
                }
                .font(.subheadline)
            }
        case .calendar, .yearDots:
            EmptyView()
        default:
            SpaceOptionsSection(design: $design)
        }
    }

    private func contentLink<Destination: View>(_ title: String, detail: String?, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                if let detail {
                    Text(detail).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Explains and requests calendar access for the "À venir" widget.
struct CalendarAccessRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var isRequesting = false

    var body: some View {
        if CalendarService.hasAccess {
            Label(tr("Accès autorisé. Tes 48 prochaines heures s'affichent dans le widget."), systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if CalendarService.accessDenied {
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("L'accès au calendrier est désactivé. Active-le dans Réglages > Ardane > Calendriers."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(tr("Ouvrir Réglages")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.bordered)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("Ardane lit tes événements pour les afficher. Rien ne quitte ton iPhone."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    isRequesting = true
                    Task {
                        _ = await CalendarService.requestAccess()
                        model.refreshEvents()
                        model.scheduleWidgetReload()
                        isRequesting = false
                    }
                } label: {
                    HStack {
                        if isRequesting { ProgressView() }
                        Text(tr("Autoriser l'accès au calendrier"))
                    }
                    .foregroundStyle(.onAccent)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequesting)
            }
        }
    }
}

struct CityPickerView: View {
    @Binding var selected: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var cities: [WorldCity] {
        let q = query.trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
        let available = WorldCities.all.filter { !selected.contains($0.id) }
        guard !q.isEmpty else { return available }
        return available.filter {
            "\($0.name) \($0.country)".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale).contains(q)
        }
    }

    var body: some View {
        List(cities) { city in
            Button {
                selected.append(city.id)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(city.name).foregroundStyle(.primary)
                        Text(city.country).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let zone = TimeZone(identifier: city.id) {
                        Text(Fmt.time(Date(), uses24Hour: true, timeZone: zone))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.primary)
        }
        .styledList()
        .searchable(text: $query, prompt: tr("Chercher une ville"))
        .navigationTitle(tr("Ajouter une ville"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
