import Foundation

enum TemperatureUnit: String, Codable, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }

    var title: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }

    func convert(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }
}

struct WeatherLocation: Codable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double
}

struct AppSettings: Codable, Hashable {
    var temperatureUnit: TemperatureUnit = .celsius
    var uses24HourClock = true
    var currencyCode = "CAD"
    var cryptoCurrency = "usd"
    var weatherLocation: WeatherLocation?
    var hasCompletedOnboarding = false
    var hydrationReminders = false

    enum CodingKeys: String, CodingKey {
        case temperatureUnit, uses24HourClock, currencyCode, cryptoCurrency, weatherLocation
        case hasCompletedOnboarding, hydrationReminders
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        temperatureUnit = (try? c.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit)) ?? .celsius
        uses24HourClock = (try? c.decodeIfPresent(Bool.self, forKey: .uses24HourClock)) ?? true
        currencyCode = (try? c.decodeIfPresent(String.self, forKey: .currencyCode)) ?? "CAD"
        cryptoCurrency = (try? c.decodeIfPresent(String.self, forKey: .cryptoCurrency)) ?? "usd"
        weatherLocation = try? c.decodeIfPresent(WeatherLocation.self, forKey: .weatherLocation)
        hasCompletedOnboarding = (try? c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        hydrationReminders = (try? c.decodeIfPresent(Bool.self, forKey: .hydrationReminders)) ?? false
    }

    static let currencies = ["CAD", "USD", "EUR", "GBP", "CHF"]
    static let cryptoCurrencies = ["usd", "cad", "eur", "gbp"]
}

/// Cached entitlement so widgets and offline launches know the Premium status.
/// The app refreshes it from StoreKit on every launch and transaction update.
struct PremiumState: Codable, Hashable {
    var isActive = false
    var productID: String?
    var expirationDate: Date?
    var verifiedAt: Date?
    /// Debug builds only: lets a tester switch Premium on without a purchase.
    var testerOverride = false

    /// Offline tolerance after an expiration date, so a renewal that hasn't synced yet doesn't lock the user out.
    static let gracePeriod: TimeInterval = 3 * 86_400

    func isPremium(at date: Date = Date()) -> Bool {
        if testerOverride { return true }
        guard isActive else { return false }
        guard let expirationDate else { return true }
        return expirationDate.addingTimeInterval(Self.gracePeriod) > date
    }
}
