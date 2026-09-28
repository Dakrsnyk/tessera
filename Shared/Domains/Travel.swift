import Foundation

struct Trip: Codable, Hashable, Identifiable {
    var id = UUID()
    var destination: String
    var start: Date
    var end: Date
    var timeZoneID: String = TimeZone.current.identifier
    var currencyCode: String = "EUR"
    var latitude: Double?
    var longitude: Double?

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    var location: WeatherLocation? {
        guard let latitude, let longitude else { return nil }
        return WeatherLocation(name: destination, latitude: latitude, longitude: longitude)
    }
}

struct Flight: Codable, Hashable, Identifiable {
    var id = UUID()
    var number: String
    var from: String
    var to: String
    var departure: Date
    var arrival: Date?
    var terminal: String = ""
    var gate: String = ""
    var seat: String = ""
}

struct Stay: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var address: String = ""
    var checkIn: Date
    var checkOut: Date
    var confirmation: String = ""
}

struct TripActivity: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var date: Date
    var place: String = ""
}

struct TravelState: Codable, Hashable {
    var trips: [Trip] = []
    var flights: [Flight] = []
    var stays: [Stay] = []
    var activities: [TripActivity] = []
    /// Amount converted by the currency widget (in the home currency).
    var sampleAmount: Double = 100

    enum CodingKeys: String, CodingKey { case trips, flights, stays, activities, sampleAmount }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trips = c.value(.trips, [])
        flights = c.value(.flights, [])
        stays = c.value(.stays, [])
        activities = c.value(.activities, [])
        sampleAmount = c.value(.sampleAmount, 100)
    }
}

enum TravelMath {
    /// The trip in progress, otherwise the next one.
    static func currentTrip(_ state: TravelState, at date: Date) -> Trip? {
        let today = DateMath.startOfDay(date)
        if let ongoing = state.trips.first(where: { DateMath.startOfDay($0.start) <= today && DateMath.startOfDay($0.end) >= today }) {
            return ongoing
        }
        return state.trips.filter { $0.start > date }.min { $0.start < $1.start }
    }

    static func isOngoing(_ trip: Trip, at date: Date) -> Bool {
        let today = DateMath.startOfDay(date)
        return DateMath.startOfDay(trip.start) <= today && DateMath.startOfDay(trip.end) >= today
    }

    /// Day number within the trip (1-based) and the trip length in days.
    static func tripDay(_ trip: Trip, at date: Date) -> (day: Int, total: Int) {
        let total = max(1, DateMath.daysBetween(trip.start, trip.end) + 1)
        let day = min(total, max(1, DateMath.daysBetween(trip.start, date) + 1))
        return (day, total)
    }

    static func nextFlight(_ state: TravelState, at date: Date) -> Flight? {
        // A flight stays on screen until an hour after take-off.
        state.flights.filter { $0.departure.addingTimeInterval(3600) > date }.min { $0.departure < $1.departure }
    }

    static func currentStay(_ state: TravelState, at date: Date) -> Stay? {
        if let now = state.stays.first(where: { $0.checkIn <= date && $0.checkOut > date }) { return now }
        return state.stays.filter { $0.checkIn > date }.min { $0.checkIn < $1.checkIn }
    }

    static func nextActivity(_ state: TravelState, at date: Date) -> TripActivity? {
        state.activities.filter { $0.date.addingTimeInterval(1800) > date }.min { $0.date < $1.date }
    }

    /// Hours between the destination and the phone's time zone (positive when the destination is ahead).
    static func offsetHours(_ zone: TimeZone, at date: Date) -> Double {
        Double(zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)) / 3600
    }
}

// MARK: Exchange rates (Frankfurter, European Central Bank reference rates, no key)

struct FXRates: Codable, Hashable {
    var base: String
    var rates: [String: Double]
    /// Publication date of the ECB rates (yyyy-MM-dd).
    var day: String
    var fetchedAt: Date
}

struct FXCache: Codable {
    var tables: [String: FXRates] = [:]
}

enum FXService {
    static let refreshInterval: TimeInterval = 6 * 3600
    /// Currencies published by the European Central Bank.
    static let currencies = ["CAD", "USD", "EUR", "GBP", "CHF", "JPY", "MXN", "AUD", "NZD", "CNY", "HKD", "SGD", "KRW", "THB", "INR", "IDR", "MYR", "PHP", "BRL", "ZAR", "TRY", "ILS", "SEK", "NOK", "DKK", "ISK", "PLN", "CZK", "HUF", "RON"]

    static func cached(base: String) -> FXRates? {
        SharedStore.shared.read(FXCache.self, from: .fx)?.tables[base]
    }

    static func rates(base: String, allowNetwork: Bool, now: Date = Date()) async -> FXRates? {
        let cache = cached(base: base)
        if let cache, now.timeIntervalSince(cache.fetchedAt) < refreshInterval { return cache }
        guard allowNetwork, let fresh = try? await fetch(base: base, now: now) else { return cache }
        var store = SharedStore.shared.read(FXCache.self, from: .fx) ?? FXCache()
        store.tables[base] = fresh
        SharedStore.shared.write(store, to: .fx)
        return fresh
    }

    static func fetch(base: String, now: Date) async throws -> FXRates {
        guard let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=\(base)") else { throw WeatherError.badResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WeatherError.badResponse }
        struct Payload: Decodable {
            let base: String
            let date: String
            let rates: [String: Double]
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return FXRates(base: payload.base, rates: payload.rates, day: payload.date, fetchedAt: now)
    }
}

/// Weather at the trip's destination, cached apart from the home weather.
enum TripWeatherService {
    static let refreshInterval: TimeInterval = 60 * 60

    static func load(for trip: Trip, allowNetwork: Bool, now: Date = Date()) async -> WeatherSnapshot? {
        guard let location = trip.location else { return nil }
        let stored = SharedStore.shared.read(WeatherSnapshot.self, from: .tripWeather)
        let cache = (stored?.matches(location) ?? false) ? stored : nil
        if let cache, now.timeIntervalSince(cache.fetchedAt) < refreshInterval { return cache }
        guard allowNetwork, let fresh = try? await WeatherService.fetch(location) else { return cache }
        SharedStore.shared.write(fresh, to: .tripWeather)
        return fresh
    }
}
