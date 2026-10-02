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
    /// Budget for the whole trip, in the home currency.
    var budget: Double?

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

enum TripExpenseKind: String, Codable, CaseIterable, Identifiable {
    case transport, lodging, food, activities, shopping, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .transport: tr("Transport")
        case .lodging: tr("Hébergement")
        case .food: tr("Repas")
        case .activities: tr("Activités")
        case .shopping: tr("Achats")
        case .other: tr("Autre")
        }
    }

    var symbol: String {
        switch self {
        case .transport: "tram.fill"
        case .lodging: "bed.double.fill"
        case .food: "fork.knife"
        case .activities: "ticket.fill"
        case .shopping: "bag.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .transport: "3366FF"
        case .lodging: "8C6CFF"
        case .food: "F08A24"
        case .activities: "12A4B5"
        case .shopping: "D6409F"
        case .other: "64748B"
        }
    }
}

/// Money spent on a trip, in whichever currency it was paid.
struct TripExpense: Codable, Hashable, Identifiable {
    var id = UUID()
    var tripID: UUID
    var amount: Double
    var currencyCode: String
    var kind: TripExpenseKind = .other
    var label: String = ""
    var date = Date()
}

/// Something not to forget for a trip.
struct ChecklistItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var tripID: UUID
    var title: String
    var isDone = false
}

struct TravelState: Codable, Hashable {
    var trips: [Trip] = []
    var flights: [Flight] = []
    var stays: [Stay] = []
    var activities: [TripActivity] = []
    /// Amount converted by the currency widget (in the home currency).
    var sampleAmount: Double = 100
    var expenses: [TripExpense] = []
    var checklist: [ChecklistItem] = []

    enum CodingKeys: String, CodingKey { case trips, flights, stays, activities, sampleAmount, expenses, checklist }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trips = c.value(.trips, [])
        flights = c.value(.flights, [])
        stays = c.value(.stays, [])
        activities = c.value(.activities, [])
        sampleAmount = c.value(.sampleAmount, 100)
        expenses = c.value(.expenses, [])
        checklist = c.value(.checklist, [])
    }

    mutating func toggleChecklist(_ id: UUID) {
        guard let index = checklist.firstIndex(where: { $0.id == id }) else { return }
        checklist[index].isDone.toggle()
    }

    /// Adds the usual things to pack, skipping the ones already on the list.
    mutating func addEssentials(to trip: UUID, abroad: Bool) {
        var titles = [tr("Chargeur de téléphone"), tr("Médicaments"), tr("Carte bancaire"), tr("Vêtements"), tr("Trousse de toilette"), tr("Confirmations de réservation")]
        if abroad { titles = [tr("Passeport"), tr("Assurance voyage"), tr("Adaptateur de prise")] + titles }
        let existing = Set(checklist.filter { $0.tripID == trip }.map { $0.title.lowercased() })
        for title in titles where !existing.contains(title.lowercased()) {
            checklist.append(ChecklistItem(tripID: trip, title: title))
        }
    }

    /// Removes a trip with what belongs only to it (its expenses and checklist).
    mutating func deleteTrip(_ id: UUID) {
        trips.removeAll { $0.id == id }
        expenses.removeAll { $0.tripID == id }
        checklist.removeAll { $0.tripID == id }
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

    /// The window a trip covers (a day on each side, for the flight out and back).
    static func window(_ trip: Trip) -> DateInterval {
        let start = DateMath.startOfDay(trip.start).addingTimeInterval(-86_400)
        let end = DateMath.startOfDay(trip.end).addingTimeInterval(2 * 86_400)
        return DateInterval(start: start, end: max(start, end))
    }

    static func flights(_ state: TravelState, for trip: Trip) -> [Flight] {
        state.flights.filter { window(trip).contains($0.departure) }.sorted { $0.departure < $1.departure }
    }

    static func stays(_ state: TravelState, for trip: Trip) -> [Stay] {
        let span = window(trip)
        return state.stays.filter { $0.checkIn < span.end && $0.checkOut > span.start }.sorted { $0.checkIn < $1.checkIn }
    }

    static func activities(_ state: TravelState, for trip: Trip) -> [TripActivity] {
        state.activities.filter { window(trip).contains($0.date) }.sorted { $0.date < $1.date }
    }

    /// One line of the trip's program: a flight, a check-in or check-out, an activity.
    struct ProgramItem: Hashable, Identifiable {
        enum Kind: Hashable { case flight, checkIn, checkOut, activity }
        let id: String
        let kind: Kind
        let date: Date
        let title: String
        let detail: String?

        var symbol: String {
            switch kind {
            case .flight: "airplane"
            case .checkIn: "bed.double.fill"
            case .checkOut: "figure.walk.departure"
            case .activity: "mappin.and.ellipse"
            }
        }
    }

    struct ProgramDay: Hashable, Identifiable {
        let day: Date
        let items: [ProgramItem]
        var id: Date { day }
    }

    static func flightDetail(_ flight: Flight) -> String? {
        var parts: [String] = []
        if !flight.from.isEmpty && !flight.to.isEmpty { parts.append("\(flight.from) → \(flight.to)") }
        if !flight.gate.isEmpty { parts.append(tr("porte \(flight.gate)")) }
        if !flight.seat.isEmpty { parts.append(tr("siège \(flight.seat)")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The trip day by day, from the day before departure to the return.
    static func program(_ state: TravelState, for trip: Trip) -> [ProgramDay] {
        var items: [ProgramItem] = []
        for flight in flights(state, for: trip) {
            items.append(ProgramItem(id: "flight-\(flight.id)", kind: .flight, date: flight.departure, title: tr("Vol \(flight.number)"), detail: flightDetail(flight)))
        }
        for stay in stays(state, for: trip) {
            items.append(ProgramItem(id: "in-\(stay.id)", kind: .checkIn, date: stay.checkIn, title: tr("Arrivée · \(stay.name)"), detail: stay.address.isEmpty ? nil : stay.address))
            items.append(ProgramItem(id: "out-\(stay.id)", kind: .checkOut, date: stay.checkOut, title: tr("Départ · \(stay.name)"), detail: nil))
        }
        for activity in activities(state, for: trip) {
            items.append(ProgramItem(id: "activity-\(activity.id)", kind: .activity, date: activity.date, title: activity.title, detail: activity.place.isEmpty ? nil : activity.place))
        }
        let days = Dictionary(grouping: items) { DateMath.startOfDay($0.date) }
        return days.keys.sorted().map { day in ProgramDay(day: day, items: (days[day] ?? []).sorted { $0.date < $1.date }) }
    }

    /// A trip's spending in the home currency, with what could not be converted (no rate known).
    struct Spending: Hashable {
        var total: Double = 0
        var byKind: [TripExpenseKind: Double] = [:]
        var unconverted: [String: Double] = [:]
    }

    static func spending(_ state: TravelState, for trip: Trip, home: String, rates: FXRates?) -> Spending {
        var result = Spending()
        for expense in state.expenses where expense.tripID == trip.id {
            guard let value = convert(expense.amount, from: expense.currencyCode, to: home, rates: rates) else {
                result.unconverted[expense.currencyCode, default: 0] += expense.amount
                continue
            }
            result.total += value
            result.byKind[expense.kind, default: 0] += value
        }
        return result
    }

    /// Converts with the reference rates of the home currency (1 home = rate × other).
    static func convert(_ amount: Double, from currency: String, to home: String, rates: FXRates?) -> Double? {
        if currency == home { return amount }
        guard let rates, rates.base == home, let rate = rates.rates[currency], rate > 0 else { return nil }
        return amount / rate
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
