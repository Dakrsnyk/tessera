import Foundation

struct HourForecast: Codable, Hashable {
    var date: Date
    var temperature: Double
    var code: Int
    var isDay: Bool
    var precipitationProbability: Int? = nil
    var uvIndex: Double? = nil
}

struct DayForecast: Codable, Hashable {
    var date: Date
    var code: Int
    var high: Double
    var low: Double
    var sunrise: Date? = nil
    var sunset: Date? = nil
    var precipitationProbability: Int? = nil
    var uvMax: Double? = nil
}

struct WeatherSnapshot: Codable, Hashable {
    var locationName: String
    var latitude: Double
    var longitude: Double
    var fetchedAt: Date
    var temperature: Double
    var apparentTemperature: Double
    var code: Int
    var isDay: Bool
    var windSpeed: Double
    var high: Double
    var low: Double
    var hourly: [HourForecast]
    var daily: [DayForecast]
    var humidity: Double? = nil
    var pressure: Double? = nil
    var windDirection: Double? = nil
    var windGusts: Double? = nil

    /// Today's forecast (the first day whose date is today), falling back to the first day.
    func day(for date: Date) -> DayForecast? {
        daily.first { DateMath.isSameDay($0.date, date) } ?? daily.first
    }

    /// UV index right now, from the hourly forecast.
    func uvIndex(at date: Date) -> Double? {
        hourly.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }?.uvIndex
    }

    func matches(_ location: WeatherLocation) -> Bool {
        abs(latitude - location.latitude) < 0.01 && abs(longitude - location.longitude) < 0.01
    }

    /// Hours from now on, so a cached snapshot still shows a sensible forecast later.
    func upcomingHours(from date: Date, count: Int) -> [HourForecast] {
        Array(hourly.filter { $0.date > date.addingTimeInterval(-3600) }.prefix(count))
    }
}

enum WeatherResult: Hashable {
    case ready(WeatherSnapshot)
    case needsLocation
    case unavailable(WeatherSnapshot?)
}

enum WeatherError: LocalizedError {
    case badResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .badResponse: "Le service météo n'a pas répondu."
        case .decoding: "Les données météo sont illisibles."
        }
    }
}

/// Weather from Open-Meteo. No key is needed for non-commercial use; set OPEN_METEO_API_KEY
/// (see README) to use the commercial endpoint once the app is sold.
enum WeatherService {
    static let refreshInterval: TimeInterval = 30 * 60

    static var cached: WeatherSnapshot? {
        SharedStore.shared.read(WeatherSnapshot.self, from: .weather)
    }

    /// Returns cached weather when fresh, otherwise fetches (if allowed) and falls back to the cache on failure.
    static func load(allowNetwork: Bool, now: Date = Date()) async -> WeatherResult {
        guard let location = SharedStore.shared.settings.weatherLocation else { return .needsLocation }
        let cache = cached.flatMap { $0.matches(location) ? $0 : nil }
        if let cache, now.timeIntervalSince(cache.fetchedAt) < refreshInterval {
            return .ready(cache)
        }
        guard allowNetwork else {
            if let cache { return .ready(cache) }
            return .unavailable(nil)
        }
        do {
            let snapshot = try await fetch(location)
            SharedStore.shared.write(snapshot, to: .weather)
            return .ready(snapshot)
        } catch {
            if let cache { return .unavailable(cache) }
            return .unavailable(nil)
        }
    }

    static func fetch(_ location: WeatherLocation) async throws -> WeatherSnapshot {
        let key = (Bundle.main.object(forInfoDictionaryKey: "OpenMeteoAPIKey") as? String)?.trimmed.nonEmpty
        var components = URLComponents(string: key == nil
            ? "https://api.open-meteo.com/v1/forecast"
            : "https://customer-api.open-meteo.com/v1/forecast")!
        var items = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", location.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,relative_humidity_2m,pressure_msl"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day,precipitation_probability,uv_index"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max,uv_index_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "7"),
        ]
        if let key { items.append(URLQueryItem(name: "apikey", value: key)) }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherError.badResponse
        }
        guard let payload = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
            throw WeatherError.decoding
        }
        return try payload.snapshot(for: location)
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let apparent_temperature: Double
        let is_day: Int
        let weather_code: Int
        let wind_speed_10m: Double
        let wind_direction_10m: Double?
        let wind_gusts_10m: Double?
        let relative_humidity_2m: Double?
        let pressure_msl: Double?
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double?]
        let weather_code: [Int?]
        let is_day: [Int?]
        let precipitation_probability: [Int?]?
        let uv_index: [Double?]?
    }

    struct Daily: Decodable {
        let time: [String]
        let weather_code: [Int?]
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
        let sunrise: [String?]?
        let sunset: [String?]?
        let precipitation_probability_max: [Int?]?
        let uv_index_max: [Double?]?
    }

    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily

    func snapshot(for location: WeatherLocation) throws -> WeatherSnapshot {
        let zone = TimeZone(secondsFromGMT: utc_offset_seconds) ?? .current
        let hourFormatter = DateFormatter()
        hourFormatter.locale = Locale(identifier: "en_US_POSIX")
        hourFormatter.timeZone = zone
        hourFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = zone
        dayFormatter.dateFormat = "yyyy-MM-dd"

        var hours: [HourForecast] = []
        for (index, stamp) in hourly.time.enumerated() {
            guard let date = hourFormatter.date(from: stamp),
                  index < hourly.temperature_2m.count, let temperature = hourly.temperature_2m[index],
                  index < hourly.weather_code.count, let code = hourly.weather_code[index] else { continue }
            let isDay = index < hourly.is_day.count ? (hourly.is_day[index] ?? 1) == 1 : true
            var hour = HourForecast(date: date, temperature: temperature, code: code, isDay: isDay)
            hour.precipitationProbability = hourly.precipitation_probability?[safe: index] ?? nil
            hour.uvIndex = hourly.uv_index?[safe: index] ?? nil
            hours.append(hour)
        }

        var days: [DayForecast] = []
        for (index, stamp) in daily.time.enumerated() {
            guard let date = dayFormatter.date(from: stamp),
                  index < daily.weather_code.count, let code = daily.weather_code[index],
                  index < daily.temperature_2m_max.count, let high = daily.temperature_2m_max[index],
                  index < daily.temperature_2m_min.count, let low = daily.temperature_2m_min[index] else { continue }
            var day = DayForecast(date: date, code: code, high: high, low: low)
            if let stamp = daily.sunrise?[safe: index] ?? nil { day.sunrise = hourFormatter.date(from: stamp) }
            if let stamp = daily.sunset?[safe: index] ?? nil { day.sunset = hourFormatter.date(from: stamp) }
            day.precipitationProbability = daily.precipitation_probability_max?[safe: index] ?? nil
            day.uvMax = daily.uv_index_max?[safe: index] ?? nil
            days.append(day)
        }
        guard let today = days.first else { throw WeatherError.decoding }

        var snapshot = WeatherSnapshot(
            locationName: location.name,
            latitude: location.latitude,
            longitude: location.longitude,
            fetchedAt: Date(),
            temperature: current.temperature_2m,
            apparentTemperature: current.apparent_temperature,
            code: current.weather_code,
            isDay: current.is_day == 1,
            windSpeed: current.wind_speed_10m,
            high: today.high,
            low: today.low,
            hourly: hours,
            daily: days
        )
        snapshot.humidity = current.relative_humidity_2m
        snapshot.pressure = current.pressure_msl
        snapshot.windDirection = current.wind_direction_10m
        snapshot.windGusts = current.wind_gusts_10m
        return snapshot
    }
}

/// WMO weather interpretation codes → text and SF Symbols.
enum WeatherCode {
    static func description(_ code: Int) -> String {
        switch code {
        case 0: "Ciel dégagé"
        case 1: "Plutôt dégagé"
        case 2: "Partiellement nuageux"
        case 3: "Couvert"
        case 45, 48: "Brouillard"
        case 51, 53, 55: "Bruine"
        case 56, 57: "Bruine verglaçante"
        case 61, 63: "Pluie"
        case 65: "Forte pluie"
        case 66, 67: "Pluie verglaçante"
        case 71, 73: "Neige"
        case 75: "Forte neige"
        case 77: "Grains de neige"
        case 80, 81: "Averses"
        case 82: "Violentes averses"
        case 85, 86: "Averses de neige"
        case 95: "Orage"
        case 96, 99: "Orage et grêle"
        default: "—"
        }
    }

    static func symbol(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51, 53, 55, 56, 57: "cloud.drizzle.fill"
        case 61, 63, 66, 67, 80, 81: "cloud.rain.fill"
        case 65, 82: "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: "cloud.snow.fill"
        case 95, 96, 99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}
