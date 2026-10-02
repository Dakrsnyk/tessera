import Charts
import SwiftUI

/// The detailed weather: now, the next hours, the coming days and the details (wind, humidity,
/// pressure, UV, sun), plus the destination of a trip under way or coming.
struct WeatherAppView: View {
    @Environment(AppModel.self) private var model
    @State private var choosingCity = false

    private var accentHex: String { MiniApp.weather.colorHex }
    private var unit: TemperatureUnit { model.settings.temperatureUnit }

    var body: some View {
        MiniAppScroll {
            switch model.weather {
            case let .ready(snapshot):
                content(snapshot)
            case let .unavailable(snapshot):
                if let snapshot {
                    Label("Pas de connexion : dernière météo reçue \(updatedText(snapshot.fetchedAt)).", systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    content(snapshot)
                } else {
                    EmptyStateView(symbol: "cloud.sun", title: "Météo indisponible", message: "Le service météo ne répond pas pour l'instant. Réessaie dans un moment.", actionTitle: "Réessayer") {
                        Task { await model.refreshWeather(force: true) }
                    }
                    .card()
                }
            case .needsLocation:
                EmptyStateView(symbol: "location.circle", title: "Ta ville", message: "Choisis ta ville (ou ta position) pour voir la météo ici, sur l'accueil et dans les widgets.", actionTitle: "Choisir ma ville") {
                    choosingCity = true
                }
                .card()
            }
            trip
            Text("Données météo : Open-Meteo.com (CC BY 4.0).")
                .font(.footnote)
                .foregroundStyle(.secondary)
            MiniAppSettingsSection(app: .weather)
        }
        .navigationTitle("Météo")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { choosingCity = true } label: { Image(systemName: "mappin.and.ellipse") }
                    .accessibilityLabel(Text("Changer de ville"))
            }
        }
        .refreshable { await model.refreshWeather(force: true) }
        .task { await model.refreshWeather() }
        .sheet(isPresented: $choosingCity) {
            NavigationStack {
                WeatherLocationView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { choosingCity = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func content(_ weather: WeatherSnapshot) -> some View {
        let now = Date()
        hero(weather, now: now)
        hours(weather, now: now)
        days(weather, now: now)
        details(weather, now: now)
    }

    // MARK: Now

    private func hero(_ weather: WeatherSnapshot, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(weather.locationName, systemImage: "location.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: accentHex))
            HStack(alignment: .center, spacing: 14) {
                Text(Fmt.temperature(weather.temperature, unit: unit))
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                WeatherGlyph(code: weather.code, isDay: weather.isDay)
                    .font(.system(size: 44))
            }
            Text(WeatherCode.description(weather.code)).font(.title3.weight(.semibold))
            Text("Ressenti \(Fmt.temperature(weather.apparentTemperature, unit: unit)) · Max \(Fmt.temperature(weather.high, unit: unit)) · Min \(Fmt.temperature(weather.low, unit: unit))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let rain = weather.hourly.first(where: { $0.date > now && $0.date < now.addingTimeInterval(12 * 3_600) && ($0.precipitationProbability ?? 0) >= 50 }) {
                Label("Pluie probable vers \(Fmt.time(rain.date, uses24Hour: true)) (\(rain.precipitationProbability ?? 0) %)", systemImage: "umbrella.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(hex: accentHex))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weather-hero")
    }

    // MARK: Hours

    @ViewBuilder
    private func hours(_ weather: WeatherSnapshot, now: Date) -> some View {
        let hours = weather.upcomingHours(from: now, count: 24)
        if !hours.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: "Prochaines heures")
                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(hours, id: \.date) { hour in
                                VStack(spacing: 6) {
                                    Text(DateMath.calendar.isDate(hour.date, equalTo: now, toGranularity: .hour) ? "Maint." : Fmt.format(hour.date, template: "HH"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    WeatherGlyph(code: hour.code, isDay: hour.isDay)
                                        .font(.title3)
                                        .frame(height: 24)
                                    Text(Fmt.temperature(hour.temperature, unit: unit)).font(.subheadline.weight(.semibold)).monospacedDigit()
                                    Text((hour.precipitationProbability ?? 0) >= 20 ? "\(hour.precipitationProbability ?? 0) %" : " ")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color(hex: accentHex))
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    Chart {
                        ForEach(hours, id: \.date) { hour in
                            BarMark(x: .value("Heure", hour.date, unit: .hour), y: .value("Pluie", Double(hour.precipitationProbability ?? 0) / 100 * rainScale(hours)))
                                .foregroundStyle(Color(hex: accentHex).opacity(0.25))
                            LineMark(x: .value("Heure", hour.date, unit: .hour), y: .value("Température", displayed(hour.temperature)))
                                .foregroundStyle(Color(hex: "F2A33A"))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text("\(Fmt.format(date, template: "HH")) h")
                                }
                            }
                        }
                    }
                    .frame(height: 110)
                }
                .card(padding: 14)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weather-hours")
            }
        }
    }

    /// Temperatures in the unit chosen, for the chart.
    private func displayed(_ celsius: Double) -> Double {
        unit == .fahrenheit ? celsius * 9 / 5 + 32 : celsius
    }

    /// The rain bars reach the top of the temperature range at 100 %.
    private func rainScale(_ hours: [HourForecast]) -> Double {
        let temperatures = hours.map { displayed($0.temperature) }
        return max(1, (temperatures.max() ?? 1))
    }

    // MARK: Days

    @ViewBuilder
    private func days(_ weather: WeatherSnapshot, now: Date) -> some View {
        let days = weather.daily.filter { DateMath.startOfDay($0.date) >= DateMath.startOfDay(now) }
        if !days.isEmpty {
            let lowest = days.map(\.low).min() ?? 0
            let highest = days.map(\.high).max() ?? 1
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: "\(days.count) prochains jours")
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                        if index > 0 { Divider() }
                        DayRow(day: day, isToday: DateMath.isSameDay(day.date, now), lowest: lowest, highest: highest, unit: unit)
                    }
                }
                .padding(.horizontal, 14)
                .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weather-days")
            }
        }
    }

    // MARK: Details

    private func details(_ weather: WeatherSnapshot, now: Date) -> some View {
        let today = weather.day(for: now)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: "Détails")
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    MiniStat(title: "Vent", value: "\(TF.int(weather.windSpeed)) km/h", detail: windDetail(weather))
                    MiniStat(title: "Humidité", value: weather.humidity.map { "\(TF.int($0)) %" } ?? "–")
                }
                HStack(spacing: 10) {
                    MiniStat(title: "Indice UV", value: weather.uvIndex(at: now).map { TF.int($0) } ?? "–", detail: uvDetail(weather, today: today, now: now))
                    MiniStat(title: "Pression", value: weather.pressure.map { "\(TF.int($0)) hPa" } ?? "–")
                }
                if let sunrise = today?.sunrise, let sunset = today?.sunset {
                    HStack(spacing: 10) {
                        MiniStat(title: "Lever du soleil", value: Fmt.time(sunrise, uses24Hour: true))
                        MiniStat(title: "Coucher du soleil", value: Fmt.time(sunset, uses24Hour: true),
                                 detail: "\(Fmt.hours(sunset.timeIntervalSince(sunrise) / 3_600)) de jour")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weather-details")
            Text("Mis à jour \(updatedText(weather.fetchedAt)).").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func updatedText(_ date: Date) -> String {
        DateMath.isSameDay(date, Date()) ? "à \(Fmt.time(date, uses24Hour: true))" : "le \(Fmt.shortDay(date))"
    }

    private func windDetail(_ weather: WeatherSnapshot) -> String? {
        var parts: [String] = []
        if let direction = weather.windDirection { parts.append("du \(TF.compass(direction))") }
        if let gusts = weather.windGusts { parts.append("rafales \(TF.int(gusts)) km/h") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func uvDetail(_ weather: WeatherSnapshot, today: DayForecast?, now: Date) -> String? {
        guard let uv = weather.uvIndex(at: now) else { return nil }
        guard let highest = today?.uvMax else { return TF.uvLevel(uv) }
        return "\(TF.uvLevel(uv)) · max \(TF.int(highest))"
    }

    // MARK: Trip

    @ViewBuilder
    private var trip: some View {
        if let trip = TravelMath.currentTrip(model.travel, at: Date()), let weather = model.tripWeather {
            let now = Date()
            let days = weather.daily.filter { DateMath.startOfDay($0.date) >= DateMath.startOfDay(now) }.prefix(7)
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: "À \(trip.destination)", detail: "\(Fmt.temperature(weather.temperature, unit: unit)) maintenant")
                NavigationLink(value: HomeRoute.app(.travel)) {
                    VStack(spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                            if index > 0 { Divider() }
                            DayRow(day: day, isToday: DateMath.isSameDay(day.date, now), lowest: days.map(\.low).min() ?? 0, highest: days.map(\.high).max() ?? 1, unit: unit)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A day of forecast: its name, the sky, the chance of rain and the range of temperatures.
struct DayRow: View {
    let day: DayForecast
    let isToday: Bool
    let lowest: Double
    let highest: Double
    let unit: TemperatureUnit

    var body: some View {
        HStack(spacing: 10) {
            Text(isToday ? "Aujourd'hui" : Fmt.format(day.date, template: "EEEd").capitalizedFirst)
                .font(.subheadline.weight(isToday ? .semibold : .regular))
                .frame(width: 92, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            WeatherGlyph(code: day.code)
                .frame(width: 26)
            Text((day.precipitationProbability ?? 0) >= 20 ? "\(day.precipitationProbability ?? 0) %" : "")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(hex: "3A8DDE"))
                .frame(width: 34, alignment: .leading)
            Text(Fmt.temperature(day.low, unit: unit)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit().frame(width: 38, alignment: .trailing)
            GeometryReader { proxy in
                let span = max(1, highest - lowest)
                let start = (day.low - lowest) / span * proxy.size.width
                let width = max(6, (day.high - day.low) / span * proxy.size.width)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [Color(hex: "3A8DDE"), Color(hex: "F2A33A")], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width)
                        .offset(x: start)
                }
            }
            .frame(height: 5)
            Text(Fmt.temperature(day.high, unit: unit)).font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 38, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

/// A weather symbol readable on light cards too (the multicolor clouds are white): grey clouds, a
/// yellow sun or moon, blue rain and snow.
struct WeatherGlyph: View {
    let code: Int
    var isDay = true

    private static let cloud = Color(hex: "8A9BB0")
    private static let sun = Color(hex: "F2B233")
    private static let water = Color(hex: "3A8DDE")

    var body: some View {
        let name = WeatherCode.symbol(code, isDay: isDay)
        let image = Image(systemName: name)
        if name.hasPrefix("sun") || name.hasPrefix("moon") {
            image.symbolRenderingMode(.monochrome).foregroundStyle(Self.sun)
        } else if name.contains("sun") || name.contains("moon") {
            image.symbolRenderingMode(.palette).foregroundStyle(Self.cloud, Self.sun)
        } else if name.contains("rain") || name.contains("drizzle") || name.contains("snow") || name.contains("bolt") {
            image.symbolRenderingMode(.palette).foregroundStyle(Self.cloud, Self.water)
        } else {
            image.symbolRenderingMode(.monochrome).foregroundStyle(Self.cloud)
        }
    }
}
