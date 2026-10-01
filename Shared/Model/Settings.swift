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

/// The look of the app itself (not of the widgets): an accent and matching backgrounds.
enum AppStyleID: String, Codable, CaseIterable, Identifiable {
    case tessera, ocean, coral, lavender, sand, graphite, forest, rose, midnight, neon
    var id: String { rawValue }

    var title: String {
        switch self {
        case .tessera: "Tessera"
        case .ocean: "Océan"
        case .coral: "Corail"
        case .lavender: "Lavande"
        case .sand: "Sable"
        case .graphite: "Graphite"
        case .forest: "Forêt"
        case .rose: "Rose"
        case .midnight: "Minuit"
        case .neon: "Néon"
        }
    }
}

/// Light, dark, or whatever the iPhone is set to.
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

struct AppSettings: Codable, Hashable {
    var temperatureUnit: TemperatureUnit = .celsius
    var uses24HourClock = true
    var currencyCode = "CAD"
    var cryptoCurrency = "usd"
    var weatherLocation: WeatherLocation?
    var hasCompletedOnboarding = false
    var hydrationReminders = false
    var appStyle: AppStyleID = .tessera
    var appearance: AppearanceMode = .system
    /// Set once the style has been picked (at the first launch, or once after an update).
    var hasChosenStyle = false
    /// First name shown on the profile and in the greeting. Optional, stays on the device.
    var profileName = ""
    /// The questions about the user (interests, then a page per topic) have been answered or skipped.
    var hasCompletedProfileSetup = false
    /// The step-by-step tutorial shown after the first questions has been seen (or skipped).
    var hasSeenTutorial = false

    enum CodingKeys: String, CodingKey {
        case temperatureUnit, uses24HourClock, currencyCode, cryptoCurrency, weatherLocation
        case hasCompletedOnboarding, hydrationReminders
        case appStyle, appearance, hasChosenStyle, profileName, hasCompletedProfileSetup, hasSeenTutorial
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
        appStyle = (try? c.decodeIfPresent(AppStyleID.self, forKey: .appStyle)) ?? .tessera
        appearance = (try? c.decodeIfPresent(AppearanceMode.self, forKey: .appearance)) ?? .system
        hasChosenStyle = (try? c.decodeIfPresent(Bool.self, forKey: .hasChosenStyle)) ?? false
        profileName = (try? c.decodeIfPresent(String.self, forKey: .profileName)) ?? ""
        hasCompletedProfileSetup = (try? c.decodeIfPresent(Bool.self, forKey: .hasCompletedProfileSetup)) ?? false
        // Installs from before the tutorial: those who already know the app aren't shown it (Réglages has it).
        hasSeenTutorial = (try? c.decodeIfPresent(Bool.self, forKey: .hasSeenTutorial)) ?? hasCompletedOnboarding
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

    /// Offline tolerance after an expiration date, so a renewal that hasn't synced yet doesn't lock the user out.
    static let gracePeriod: TimeInterval = 3 * 86_400

    /// Whether a real purchase is active (StoreKit), whatever the build.
    func hasPurchase(at date: Date = Date()) -> Bool {
        guard isActive else { return false }
        guard let expirationDate else { return true }
        return expirationDate.addingTimeInterval(Self.gracePeriod) > date
    }

    func isPremium(at date: Date = Date()) -> Bool {
        #if DEBUG
        if DebugPremium.isUnlocked { return true }
        #endif
        return hasPurchase(at: date)
    }
}
