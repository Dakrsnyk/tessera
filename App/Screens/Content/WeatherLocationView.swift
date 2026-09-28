import SwiftUI

struct WeatherLocationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [WeatherLocation] = []
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var errorMessage: String?
    @State private var locationService = LocationService()

    var body: some View {
        List {
            if let current = model.settings.weatherLocation {
                Section("Ville actuelle") {
                    HStack {
                        Label(current.name, systemImage: "mappin.circle.fill")
                        Spacer()
                        if case let .ready(weather) = model.weather {
                            Text(Fmt.temperature(weather.temperature, unit: model.settings.temperatureUnit))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                Button {
                    locate()
                } label: {
                    HStack {
                        Label("Utiliser ma position", systemImage: "location.fill")
                        Spacer()
                        if isLocating { ProgressView() }
                    }
                }
                .disabled(isLocating)
            } footer: {
                Text("Ta position sert uniquement à trouver la météo. Elle n'est pas enregistrée ailleurs que sur ton iPhone.")
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !results.isEmpty {
                Section("Résultats") {
                    ForEach(results, id: \.self) { location in
                        Button {
                            select(location)
                        } label: {
                            Text(location.name)
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .styledList()
        .navigationTitle("Ville pour la météo")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Chercher une ville")
        .onSubmit(of: .search) { search() }
        .overlay {
            if isSearching { ProgressView() }
        }
    }

    private func search() {
        errorMessage = nil
        isSearching = true
        Task {
            defer { isSearching = false }
            do {
                results = try await LocationService.search(query)
            } catch {
                results = []
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "La recherche a échoué. Vérifie ta connexion."
            }
        }
    }

    private func locate() {
        errorMessage = nil
        isLocating = true
        Task {
            defer { isLocating = false }
            do {
                let location = try await locationService.currentLocation()
                select(location)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? LocationError.unavailable.errorDescription
            }
        }
    }

    private func select(_ location: WeatherLocation) {
        model.updateSettings { $0.weatherLocation = location }
        Haptics.success()
        results = []
        query = ""
    }
}

struct CalendarAccessView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.accentColor)
                    Text("Le widget À venir")
                        .font(.headline)
                    Text("Il affiche tes événements des 48 prochaines heures, directement depuis le calendrier de ton iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            Section {
                CalendarAccessRow()
            }
        }
        .styledList()
        .navigationTitle("Calendrier")
    }
}
