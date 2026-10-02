import Foundation

enum WeatherTiles {
    static func make(_ context: RenderContext) -> Tile {
        let kind = context.design.kind
        guard let weather = TF.weather(context.payload) else {
            return .empty(kind.title, symbol: kind.symbol, message: tr("Choisis ta ville dans Tessera pour voir la météo."), emptySymbol: "location.slash")
        }
        let now = context.date
        let unit = context.settings.temperatureUnit
        switch kind {
        case .sunCycle: return sun(weather, context: context)
        case .rainNext: return rain(weather, context: context)
        case .windUV: return windUV(weather, now: now)
        case .weatherDetails: return details(weather, now: now, unit: unit)
        case .weeklyForecast: return weekly(weather, now: now, unit: unit)
        default: return TileFactory.placeholder(kind)
        }
    }

    static func sun(_ weather: WeatherSnapshot, context: RenderContext) -> Tile {
        let now = context.date
        guard let today = weather.day(for: now), let sunrise = today.sunrise, let sunset = today.sunset else {
            return .empty(tr("Soleil"), symbol: "sunrise.fill", message: tr("Les heures du soleil arrivent avec la prochaine mise à jour météo."))
        }
        let tomorrow = weather.daily.first { $0.date > today.date }
        let isDay = now >= sunrise && now < sunset
        var tile = Tile(title: tr("Soleil"), symbol: isDay ? "sunset.fill" : "sunrise.fill")
        let nextEvent: Date
        if now < sunrise {
            nextEvent = sunrise
            tile.caption = tr("Lever du soleil · \(TF.relativeTime(sunrise, from: now))")
        } else if isDay {
            nextEvent = sunset
            tile.caption = tr("Coucher du soleil · \(TF.relativeTime(sunset, from: now))")
        } else {
            nextEvent = tomorrow?.sunrise ?? sunrise.addingTimeInterval(86_400)
            tile.caption = tr("Lever demain")
        }
        tile.value = TF.time(nextEvent, context)
        let length = sunset.timeIntervalSince(sunrise) / 3600
        tile.detail = tr("Durée du jour : \(Fmt.hours(length)) · \(weather.locationName)")
        let progress: Double? = isDay ? now.timeIntervalSince(sunrise) / max(1, sunset.timeIntervalSince(sunrise)) : nil
        tile.visual = .sun(progress: progress, sunrise: TF.time(sunrise, context), sunset: TF.time(sunset, context))
        tile.inline = "\(isDay ? tr("Coucher") : tr("Lever")) \(TF.time(nextEvent, context))"
        tile.shortValue = TF.time(nextEvent, context)
        tile.footnote = "Open-Meteo.com"
        return tile
    }

    static func rain(_ weather: WeatherSnapshot, context: RenderContext) -> Tile {
        let now = context.date
        let hours = weather.upcomingHours(from: now, count: 12)
        let chances = hours.map { Double($0.precipitationProbability ?? 0) }
        var tile = Tile(title: tr("Pluie"), symbol: "cloud.rain.fill")
        guard !hours.isEmpty, hours.contains(where: { $0.precipitationProbability != nil }) else {
            return .empty(tr("Pluie"), symbol: "cloud.rain.fill", message: tr("Le risque de pluie arrive avec la prochaine mise à jour météo."))
        }
        let top = chances.max() ?? 0
        tile.value = "\(Int(top))"
        tile.unit = "%"
        if let first = hours.first(where: { ($0.precipitationProbability ?? 0) >= 40 }) {
            tile.caption = tr("Pluie probable vers \(TF.time(first.date, context))")
            tile.symbol = "umbrella.fill"
        } else if top >= 20 {
            tile.caption = tr("Quelques averses possibles d'ici 12 h")
        } else {
            tile.caption = tr("Pas de pluie prévue d'ici 12 h")
            tile.symbol = "sun.max.fill"
        }
        let labels = hours.enumerated().map { pair -> String in
            pair.offset % 3 == 0 ? Fmt.format(pair.element.date, template: context.settings.uses24HourClock ? "H" : "ha") : ""
        }
        let highlight = hours.firstIndex { ($0.precipitationProbability ?? 0) >= 40 }
        tile.visual = .bars(chances.map { max($0, 2) }, labels: labels, highlight: highlight)
        tile.detail = weather.locationName
        tile.inline = tile.caption
        tile.gauge = top / 100
        tile.shortValue = Fmt.percent(top / 100)
        tile.footnote = tr("Probabilité de précipitations · Open-Meteo.com")
        return tile
    }

    static func windUV(_ weather: WeatherSnapshot, now: Date) -> Tile {
        var tile = Tile(title: tr("Vent et UV"), symbol: "wind")
        tile.value = "\(Int(weather.windSpeed.rounded()))"
        tile.unit = "km/h"
        var parts: [String] = []
        if let direction = weather.windDirection { parts.append(tr("vent \(TF.compass(direction))")) }
        if let gusts = weather.windGusts { parts.append(tr("rafales \(Int(gusts.rounded()))")) }
        tile.caption = parts.isEmpty ? weather.locationName : parts.joined(separator: " · ").capitalizedFirst
        let uv = weather.uvIndex(at: now) ?? weather.day(for: now)?.uvMax
        if let uv {
            tile.detail = tr("UV \(Int(uv.rounded())) · \(TF.uvLevel(uv))")
            tile.rows = [
                TileRow(id: "uv", title: tr("Indice UV"), value: "\(Int(uv.rounded())) · \(TF.uvLevel(uv))", symbol: "sun.max.fill", progress: min(1, uv / 11)),
            ]
            if let peak = weather.day(for: now)?.uvMax {
                tile.rows.append(TileRow(id: "uvmax", title: tr("Maximum du jour"), value: "\(Int(peak.rounded()))", symbol: "sun.max"))
            }
        }
        tile.visual = .bar(min(1, weather.windSpeed / 80))
        tile.inline = tr("Vent \(Int(weather.windSpeed.rounded())) km/h")
        tile.footnote = "Open-Meteo.com"
        return tile
    }

    static func details(_ weather: WeatherSnapshot, now: Date, unit: TemperatureUnit) -> Tile {
        var tile = Tile(title: weather.locationName, symbol: WeatherCode.symbol(weather.code, isDay: weather.isDay))
        tile.value = Fmt.temperature(weather.temperature, unit: unit)
        tile.caption = WeatherCode.description(weather.code)
        var rows = [TileRow(id: "feels", title: tr("Ressenti"), value: Fmt.temperature(weather.apparentTemperature, unit: unit), symbol: "thermometer.medium")]
        if let humidity = weather.humidity {
            rows.append(TileRow(id: "humidity", title: tr("Humidité"), value: "\(Int(humidity.rounded())) %", symbol: "humidity.fill"))
        }
        var wind = tr("\(Int(weather.windSpeed.rounded())) km/h")
        if let direction = weather.windDirection { wind += " \(TF.compass(direction))" }
        rows.append(TileRow(id: "wind", title: tr("Vent"), value: wind, symbol: "wind"))
        if let uv = weather.uvIndex(at: now) {
            rows.append(TileRow(id: "uv", title: tr("UV"), value: "\(Int(uv.rounded())) · \(TF.uvLevel(uv))", symbol: "sun.max.fill"))
        }
        if let rain = weather.day(for: now)?.precipitationProbability {
            rows.append(TileRow(id: "rain", title: tr("Pluie aujourd'hui"), value: "\(rain) %", symbol: "cloud.rain.fill"))
        }
        if let pressure = weather.pressure {
            rows.append(TileRow(id: "pressure", title: tr("Pression"), value: tr("\(Int(pressure.rounded())) hPa"), symbol: "gauge.medium"))
        }
        tile.rows = rows
        tile.detail = tr("Ressenti \(Fmt.temperature(weather.apparentTemperature, unit: unit)) · ↑\(Fmt.temperature(weather.high, unit: unit)) ↓\(Fmt.temperature(weather.low, unit: unit))")
        tile.inline = "\(Fmt.temperature(weather.temperature, unit: unit)) \(WeatherCode.description(weather.code))"
        tile.footnote = "Open-Meteo.com"
        return tile
    }

    static func weekly(_ weather: WeatherSnapshot, now: Date, unit: TemperatureUnit) -> Tile {
        var tile = Tile(title: tr("Semaine météo"), symbol: "calendar.badge.clock")
        tile.value = Fmt.temperature(weather.temperature, unit: unit)
        tile.caption = "\(weather.locationName) · \(WeatherCode.description(weather.code).lowercased())"
        tile.rows = weather.daily.prefix(7).map { day -> TileRow in
            let name = DateMath.isSameDay(day.date, now) ? tr("Aujourd'hui") : Fmt.format(day.date, template: "EEEEd").capitalizedFirst
            let rain = day.precipitationProbability.map { tr("\($0) % de pluie") }
            return TileRow(
                id: DateMath.dayKey(day.date),
                title: name,
                value: "\(Fmt.temperature(day.high, unit: unit)) / \(Fmt.temperature(day.low, unit: unit))",
                detail: rain,
                symbol: WeatherCode.symbol(day.code),
                isHighlighted: DateMath.isSameDay(day.date, now)
            )
        }
        tile.footnote = "Open-Meteo.com"
        return tile
    }
}
