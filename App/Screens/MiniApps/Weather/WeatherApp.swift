import Charts
import SwiftUI

/// The detailed weather: now, the next hours, the coming days and the details (wind, humidity,
/// pressure, UV, sun), plus the destination of a trip under way or coming.
struct WeatherAppView: View {
    @Environment(AppModel.self) private var model
    @State private var choosingCity = false
    /// The day the screen tells about: today is the weather now, another day of the forecast is its forecast.
    @State private var day = Date()

    private var accentHex: String { MiniApp.weather.colorHex }
    private var unit: TemperatureUnit { model.settings.temperatureUnit }

    var body: some View {
        MiniAppScaffold(colorHex: accentHex) {
            // The band: the week selector and the weather of the day picked (nothing without a forecast to tell).
            switch model.weather {
            case let .ready(snapshot):
                bandContent(snapshot)
            case let .unavailable(snapshot):
                if let snapshot {
                    bandContent(snapshot)
                }
            case .needsLocation:
                EmptyView()
            }
        } sheet: {
            MiniAppToFillSection(app: .weather)
            switch model.weather {
            case let .ready(snapshot):
                content(snapshot)
            case let .unavailable(snapshot):
                if let snapshot {
                    content(snapshot)
                } else {
                    EmptyStateView(symbol: "cloud.sun", title: tr("Météo indisponible"), message: tr("Le service météo ne répond pas pour l'instant. Réessaie dans un moment."), actionTitle: tr("Réessayer")) {
                        Task { await model.refreshWeather(force: true) }
                    }
                    .card()
                }
            case .needsLocation:
                EmptyStateView(symbol: "location.circle", title: tr("Ta ville"), message: tr("Choisis ta ville (ou ta position) pour voir la météo ici, sur l'accueil et dans les widgets."), actionTitle: tr("Choisir ma ville")) {
                    choosingCity = true
                }
                .card()
            }
            trip
            updateNote
            MiniFootnote(text: tr("Données météo : Open-Meteo.com (CC BY 4.0)."))
            MiniAppInfoSection(app: .weather)
        }
        .navigationTitle(tr("Météo"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { choosingCity = true } label: { Image(systemName: "mappin.and.ellipse") }
                    .accessibilityLabel(Text(tr("Changer de ville")))
            }
        }
        .refreshable { await model.refreshWeather(force: true) }
        .task { await model.refreshWeather() }
        .sheet(isPresented: $choosingCity) {
            NavigationStack {
                WeatherLocationView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(tr("Fermer")) { choosingCity = false }
                        }
                    }
            }
        }
    }

    /// The band: the week selector, then the weather of the day picked (now, or its forecast).
    @ViewBuilder
    private func bandContent(_ weather: WeatherSnapshot) -> some View {
        let now = Date()
        let isToday = DateMath.isSameDay(day, now)
        let forecast = weather.daily.first { DateMath.isSameDay($0.date, day) }
        WeekSelector(day: $day, colorHex: accentHex, allowsFuture: true, mark: { date in
            WeekDayMark(isPlanned: weather.daily.contains { DateMath.isSameDay($0.date, date) })
        })
        if isToday {
            hero(weather, now: now)
        } else if let forecast {
            dayHero(weather, forecast)
        } else {
            noForecast
        }
    }

    /// The sheet: the hours, the days to come and the details.
    @ViewBuilder
    private func content(_ weather: WeatherSnapshot) -> some View {
        let now = Date()
        let isToday = DateMath.isSameDay(day, now)
        let forecast = weather.daily.first { DateMath.isSameDay($0.date, day) }
        hours(weather, now: now)
        days(weather, now: now)
        if isToday {
            details(weather, now: now)
        } else if let forecast {
            forecastDetails(forecast)
        }
    }

    /// The offline note when the forecast shown is the last one received, otherwise when it was updated:
    /// one of the two, never both.
    @ViewBuilder
    private var updateNote: some View {
        switch model.weather {
        case let .ready(snapshot):
            MiniFootnote(text: tr("Mis à jour \(updatedText(snapshot.fetchedAt))."))
        case let .unavailable(snapshot):
            if let snapshot {
                Label(tr("Pas de connexion : dernière météo reçue \(updatedText(snapshot.fetchedAt))."), systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .needsLocation:
            EmptyView()
        }
    }

    // MARK: Now

    /// The weather now, on the band: the city and the day, the big temperature, then the sky, the feels-like,
    /// the high and the low and, when it is coming, the rain.
    private func hero(_ weather: WeatherSnapshot, now: Date) -> some View {
        var lines = [
            WeatherCode.description(weather.code),
            tr("Ressenti \(Fmt.temperature(weather.apparentTemperature, unit: unit)) · Max \(Fmt.temperature(weather.high, unit: unit)) · Min \(Fmt.temperature(weather.low, unit: unit))"),
        ]
        if let rain = weather.hourly.first(where: { $0.date > now && $0.date < now.addingTimeInterval(12 * 3_600) && ($0.precipitationProbability ?? 0) >= 50 }) {
            lines.append(tr("Pluie probable vers \(Fmt.time(rain.date, uses24Hour: true)) (\(rain.precipitationProbability ?? 0) %)"))
        }
        return HStack(alignment: .center, spacing: 10) {
            MiniHero(label: "\(weather.locationName) · \(tr("Aujourd'hui"))", value: Fmt.temperature(weather.temperature, unit: unit),
                     caption: lines.joined(separator: "\n"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weather-hero")
    }

    /// Another day of the forecast: its high, then its sky, its low and the chance of rain.
    private func dayHero(_ weather: WeatherSnapshot, _ forecast: DayForecast) -> some View {
        var parts = [WeatherCode.description(forecast.code), Fmt.temperature(forecast.low, unit: unit)]
        if let rain = forecast.precipitationProbability, rain >= 20 {
            parts.append("\(rain) %")
        }
        return HStack(alignment: .center, spacing: 10) {
            MiniHero(label: "\(weather.locationName) · \(Fmt.shortDay(day))", value: Fmt.temperature(forecast.high, unit: unit),
                     caption: parts.joined(separator: " · "))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weather-hero")
    }

    /// A day the forecast does not cover: nothing is made up.
    private var noForecast: some View {
        MiniHero(label: Fmt.longDay(day), value: tr("Météo indisponible"), valueSize: 30)
            .accessibilityIdentifier("weather-hero")
    }

    // MARK: Hours

    /// The next 24 hours for today, the hours of the day picked for another day of the forecast.
    @ViewBuilder
    private func hours(_ weather: WeatherSnapshot, now: Date) -> some View {
        let isToday = DateMath.isSameDay(day, now)
        let hours = isToday ? weather.upcomingHours(from: now, count: 24) : weather.hourly.filter { DateMath.isSameDay($0.date, day) }
        if !hours.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: isToday ? tr("Prochaines heures") : Fmt.longDay(day))
                VStack(spacing: 12) {
                    // Five columns fill the card (hour, temperature, chance of rain); the other hours are a swipe away.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(hours, id: \.date) { hour in
                                VStack(spacing: 4) {
                                    Text(DateMath.calendar.isDate(hour.date, equalTo: now, toGranularity: .hour) ? "Maint." : "\(Fmt.format(hour.date, template: "HH")) h")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(Fmt.temperature(hour.temperature, unit: unit)).font(.subheadline.weight(.bold)).monospacedDigit()
                                    Text((hour.precipitationProbability ?? 0) >= 20 ? "\(hour.precipitationProbability ?? 0) %" : " ")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color(hex: accentHex))
                                }
                                .containerRelativeFrame(.horizontal, count: 5, spacing: 0)
                            }
                        }
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
        // The day picked is told above (the hero), so the list is the other days.
        let days = weather.daily.filter { DateMath.startOfDay($0.date) >= DateMath.startOfDay(now) && !DateMath.isSameDay($0.date, day) }
        if !days.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("\(days.count) prochains jours"))
                MiniRowsCard {
                    ForEach(Array(days.enumerated()), id: \.element.date) { index, forecast in
                        if index > 0 { MiniDivider() }
                        MiniRow(symbol: WeatherCode.symbol(forecast.code), colorHex: "3A8DDE",
                                title: DateMath.isSameDay(forecast.date, now) ? tr("Aujourd'hui") : Fmt.format(forecast.date, template: "EEEE").capitalizedFirst,
                                detail: dayDetail(forecast),
                                value: "\(Fmt.temperature(forecast.high, unit: unit)) / \(Fmt.temperature(forecast.low, unit: unit))",
                                showsChevron: false)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weather-days")
            }
        }
    }

    /// The sky of a day, with the chance of rain when it is worth knowing.
    private func dayDetail(_ forecast: DayForecast) -> String {
        let sky = WeatherCode.description(forecast.code)
        if let rain = forecast.precipitationProbability, rain >= 20 { return "\(sky) · \(rain) %" }
        return sky
    }

    // MARK: Details

    private func details(_ weather: WeatherSnapshot, now: Date) -> some View {
        let today = weather.day(for: now)
        return VStack(alignment: .leading, spacing: 10) {
            MiniSectionTitle(title: tr("Détails"))
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    MiniStat(title: tr("Vent"), value: tr("\(TF.int(weather.windSpeed)) km/h"), detail: windDetail(weather))
                    MiniStat(title: tr("Humidité"), value: weather.humidity.map { "\(TF.int($0)) %" } ?? "–")
                }
                HStack(spacing: 10) {
                    MiniStat(title: tr("Indice UV"), value: weather.uvIndex(at: now).map { TF.int($0) } ?? "–", detail: uvDetail(weather, today: today, now: now))
                    MiniStat(title: tr("Pression"), value: weather.pressure.map { tr("\(TF.int($0)) hPa") } ?? "–")
                }
                if let sunrise = today?.sunrise, let sunset = today?.sunset {
                    HStack(spacing: 10) {
                        MiniStat(title: tr("Lever du soleil"), value: Fmt.time(sunrise, uses24Hour: true))
                        MiniStat(title: tr("Coucher du soleil"), value: Fmt.time(sunset, uses24Hour: true),
                                 detail: tr("\(Fmt.hours(sunset.timeIntervalSince(sunrise) / 3_600)) de jour"))
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("weather-details")
        }
    }

    /// Another day of the forecast: only what the forecast holds (UV at its peak, sunrise and sunset).
    @ViewBuilder
    private func forecastDetails(_ forecast: DayForecast) -> some View {
        let sunrise = forecast.sunrise
        let sunset = forecast.sunset
        if forecast.uvMax != nil || (sunrise != nil && sunset != nil) {
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: tr("Détails"))
                VStack(spacing: 10) {
                    if let uv = forecast.uvMax {
                        MiniStat(title: tr("Indice UV"), value: TF.int(uv), detail: TF.uvLevel(uv))
                    }
                    if let sunrise, let sunset {
                        HStack(spacing: 10) {
                            MiniStat(title: tr("Lever du soleil"), value: Fmt.time(sunrise, uses24Hour: true))
                            MiniStat(title: tr("Coucher du soleil"), value: Fmt.time(sunset, uses24Hour: true),
                                     detail: tr("\(Fmt.hours(sunset.timeIntervalSince(sunrise) / 3_600)) de jour"))
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weather-details")
            }
        }
    }

    private func updatedText(_ date: Date) -> String {
        DateMath.isSameDay(date, Date()) ? "à \(Fmt.time(date, uses24Hour: true))" : tr("le \(Fmt.shortDay(date))")
    }

    private func windDetail(_ weather: WeatherSnapshot) -> String? {
        var parts: [String] = []
        if let direction = weather.windDirection { parts.append(tr("du \(TF.compass(direction))")) }
        if let gusts = weather.windGusts { parts.append(tr("rafales \(TF.int(gusts)) km/h")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func uvDetail(_ weather: WeatherSnapshot, today: DayForecast?, now: Date) -> String? {
        guard let uv = weather.uvIndex(at: now) else { return nil }
        guard let highest = today?.uvMax else { return TF.uvLevel(uv) }
        return tr("\(TF.uvLevel(uv)) · max \(TF.int(highest))")
    }

    // MARK: Trip

    @ViewBuilder
    private var trip: some View {
        if let trip = TravelMath.currentTrip(model.travel, at: Date()), let weather = model.tripWeather {
            let now = Date()
            let days = weather.daily.filter { DateMath.startOfDay($0.date) >= DateMath.startOfDay(now) }.prefix(7)
            VStack(alignment: .leading, spacing: 10) {
                MiniSectionTitle(title: "À \(trip.destination)", detail: tr("\(Fmt.temperature(weather.temperature, unit: unit)) maintenant"))
                NavigationLink(value: HomeRoute.app(.travel)) {
                    VStack(spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.element.date) { index, day in
                            if index > 0 { Divider() }
                            DayRow(day: day, isToday: DateMath.isSameDay(day.date, now), lowest: days.map(\.low).min() ?? 0, highest: days.map(\.high).max() ?? 1, unit: unit)
                        }
                    }
                    .padding(.horizontal, 14)
                    .miniCard()
                }
                .buttonStyle(.pressable)
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
            Text(isToday ? tr("Aujourd'hui") : Fmt.format(day.date, template: "EEEd").capitalizedFirst)
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
