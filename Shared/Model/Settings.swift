import Foundation

/// The look of the app itself (not of the widgets): an accent and matching backgrounds.
enum AppStyleID: String, Codable, CaseIterable, Identifiable {
    case cobalt, sapphire, iceBlue, aqua, jade, pistachio, olive, amber, ruby, rose, orchid, amethyst
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cobalt: tr("Cobalt")
        case .sapphire: tr("Saphir")
        case .iceBlue: tr("Bleu glacier")
        case .aqua: tr("Aqua")
        case .jade: tr("Jade")
        case .pistachio: tr("Pistache")
        case .olive: tr("Olive")
        case .amber: tr("Ambre")
        case .ruby: tr("Rubis")
        case .rose: tr("Rose")
        case .orchid: tr("Orchidée")
        case .amethyst: tr("Améthyste")
        }
    }

    /// The styles saved before the palette of 2026-10-27, each with its closest color today.
    private static let formerNames: [String: AppStyleID] = [
        "tessera": .jade, "ocean": .cobalt, "coral": .ruby, "lavender": .orchid, "sand": .amber,
        "graphite": .sapphire, "forest": .pistachio, "midnight": .amethyst, "neon": .aqua,
    ]

    /// A style by its current or former name (also used by the screenshot arguments).
    init?(named name: String) {
        guard let style = AppStyleID(rawValue: name) ?? Self.formerNames[name] else { return nil }
        self = style
    }

    /// A saved choice from before the new palette still decodes (to its closest color), never fails the settings.
    init(from decoder: Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        self = AppStyleID(named: name) ?? .sapphire
    }

    /// The only color of the free plan, and the default one. The eleven others are Premium.
    static let free: AppStyleID = .sapphire

    var isPremium: Bool { self != Self.free }

    /// The color actually drawn: a free plan shows Saphir whatever is saved (the saved choice is kept,
    /// so it comes back with Premium), Premium shows its choice.
    func effective(isPremium premium: Bool) -> AppStyleID {
        (premium || !isPremium) ? self : Self.free
    }
}

/// Light, dark, or whatever the iPhone is set to.
enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: tr("Auto", context: "mode")
        case .light: tr("Clair")
        case .dark: tr("Sombre")
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
    var uses24HourClock = true
    var currencyCode = "CAD"
    var cryptoCurrency = "usd"
    var hasCompletedOnboarding = false
    var hydrationReminders = false
    var appStyle: AppStyleID = .sapphire
    var appearance: AppearanceMode = .system
    /// Set once the style has been picked (at the first launch, or once after an update).
    var hasChosenStyle = false
    /// First name shown on the profile and in the greeting. Optional, stays on the device.
    var profileName = ""
    /// The questions about the user (interests, then a page per topic) have been answered or skipped.
    var hasCompletedProfileSetup = false
    /// The step-by-step tutorial shown after the first questions has been seen (or skipped).
    var hasSeenTutorial = false
    /// Opens of the app (at most one every few hours), for the rating request.
    var openCount = 0
    var lastCountedOpen: Date?
    /// The major version for which Ardane already asked for a rating (asked once per major version).
    var reviewRequestedVersion: String?
    /// The view chosen on each « Mon Quotidien » card (swiped left or right), by card.
    var dailyCardPages: [String: Int] = [:]
    /// « Mon Quotidien » arranged by hand (the layout button under « Mes données »): the cards in
    /// this order, any other after them. Empty: the automatic order, by what matters now.
    var dailyOrder: [String] = []
    /// Cards hidden from « Mon Quotidien ».
    var dailyHidden: [String] = []
    /// The size chosen for a card: true full width, false half; absent, the card's own size.
    var dailyWide: [String: Bool] = [:]
    /// Mini-apps added to « Mon Quotidien » by the person (MiniApp raw values), shown even without data.
    var dailyAdded: [String] = []
    /// « Rappels intelligents » (`SmartReminders`): the workout of the day not begun at its hour, no meal
    /// noted in the evening, a bill due tomorrow. On, but sent only once notifications are allowed.
    var remindsWorkout = true
    var remindsMeals = true
    var remindsBills = true
    var workoutReminderHour = 18
    var mealReminderHour = 20
    /// « Encouragements » (`Encouragements`): a word after a workout, a meal, a study session or a goal
    /// reached. Two a day at most, never at night; sent only once notifications are allowed.
    var encourages = true
    /// Units shown for the body weight and height. What is saved stays in kg and cm.
    var unitSystem: UnitSystem = .metric
    /// « Notifications intelligentes » (`NotificationEngine`): one switch per category, quiet hours,
    /// a daily ceiling, a least spacing and the hour of the evening summaries. Installs from before
    /// them get these defaults; `remindsWorkout`, `remindsMeals` and `remindsBills` keep their meaning.
    var remindsNutrition = true
    var remindsHabits = true
    var remindsFitness = true
    var remindsPlanning = true
    var remindsGoals = true
    var remindsGeneral = true
    /// Nothing is sent from this hour (included) to the end hour (excluded); equal hours: no quiet time.
    var quietStartHour = 22
    var quietEndHour = 8
    /// The most notifications of a day, all kinds together (encouragements included).
    var dailyNotificationCap = 4
    /// The least time between two notifications, in minutes.
    var minNotificationSpacingMinutes = 90
    /// The hour of the evening summaries (habits left, calories, tomorrow's agenda…).
    var summaryReminderHour = 19

    /// Everything that changes what the engine plans, to plan again when one of them changes.
    var smartPreferences: [Int] {
        [remindsNutrition, remindsHabits, remindsFitness, remindsPlanning, remindsGoals, remindsGeneral, encourages].map { $0 ? 1 : 0 }
            + [quietStartHour, quietEndHour, dailyNotificationCap, minNotificationSpacingMinutes, summaryReminderHour]
    }

    enum CodingKeys: String, CodingKey {
        case uses24HourClock, currencyCode, cryptoCurrency
        case hasCompletedOnboarding, hydrationReminders
        case appStyle, appearance, hasChosenStyle, profileName, hasCompletedProfileSetup, hasSeenTutorial
        case openCount, lastCountedOpen, reviewRequestedVersion, dailyCardPages
        case dailyOrder, dailyHidden, dailyWide, dailyAdded
        case remindsWorkout, remindsMeals, remindsBills, workoutReminderHour, mealReminderHour
        case encourages, unitSystem
        case remindsNutrition, remindsHabits, remindsFitness, remindsPlanning, remindsGoals, remindsGeneral
        case quietStartHour, quietEndHour, dailyNotificationCap, minNotificationSpacingMinutes, summaryReminderHour
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uses24HourClock = (try? c.decodeIfPresent(Bool.self, forKey: .uses24HourClock)) ?? true
        currencyCode = (try? c.decodeIfPresent(String.self, forKey: .currencyCode)) ?? "CAD"
        cryptoCurrency = (try? c.decodeIfPresent(String.self, forKey: .cryptoCurrency)) ?? "usd"
        hasCompletedOnboarding = (try? c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        hydrationReminders = (try? c.decodeIfPresent(Bool.self, forKey: .hydrationReminders)) ?? false
        appStyle = (try? c.decodeIfPresent(AppStyleID.self, forKey: .appStyle)) ?? .sapphire
        appearance = (try? c.decodeIfPresent(AppearanceMode.self, forKey: .appearance)) ?? .system
        hasChosenStyle = (try? c.decodeIfPresent(Bool.self, forKey: .hasChosenStyle)) ?? false
        profileName = (try? c.decodeIfPresent(String.self, forKey: .profileName)) ?? ""
        hasCompletedProfileSetup = (try? c.decodeIfPresent(Bool.self, forKey: .hasCompletedProfileSetup)) ?? false
        // Installs from before the tutorial: those who already know the app aren't shown it (Réglages has it).
        hasSeenTutorial = (try? c.decodeIfPresent(Bool.self, forKey: .hasSeenTutorial)) ?? hasCompletedOnboarding
        openCount = (try? c.decodeIfPresent(Int.self, forKey: .openCount)) ?? 0
        lastCountedOpen = try? c.decodeIfPresent(Date.self, forKey: .lastCountedOpen)
        reviewRequestedVersion = try? c.decodeIfPresent(String.self, forKey: .reviewRequestedVersion)
        dailyCardPages = (try? c.decodeIfPresent([String: Int].self, forKey: .dailyCardPages)) ?? [:]
        dailyOrder = (try? c.decodeIfPresent([String].self, forKey: .dailyOrder)) ?? []
        dailyHidden = (try? c.decodeIfPresent([String].self, forKey: .dailyHidden)) ?? []
        dailyWide = (try? c.decodeIfPresent([String: Bool].self, forKey: .dailyWide)) ?? [:]
        dailyAdded = (try? c.decodeIfPresent([String].self, forKey: .dailyAdded)) ?? []
        remindsWorkout = (try? c.decodeIfPresent(Bool.self, forKey: .remindsWorkout)) ?? true
        remindsMeals = (try? c.decodeIfPresent(Bool.self, forKey: .remindsMeals)) ?? true
        remindsBills = (try? c.decodeIfPresent(Bool.self, forKey: .remindsBills)) ?? true
        workoutReminderHour = (try? c.decodeIfPresent(Int.self, forKey: .workoutReminderHour)) ?? 18
        mealReminderHour = (try? c.decodeIfPresent(Int.self, forKey: .mealReminderHour)) ?? 20
        encourages = (try? c.decodeIfPresent(Bool.self, forKey: .encourages)) ?? true
        unitSystem = (try? c.decodeIfPresent(UnitSystem.self, forKey: .unitSystem)) ?? .metric
        remindsNutrition = c.value(.remindsNutrition, true)
        remindsHabits = c.value(.remindsHabits, true)
        remindsFitness = c.value(.remindsFitness, true)
        remindsPlanning = c.value(.remindsPlanning, true)
        remindsGoals = c.value(.remindsGoals, true)
        remindsGeneral = c.value(.remindsGeneral, true)
        quietStartHour = min(23, max(0, c.value(.quietStartHour, 22)))
        quietEndHour = min(23, max(0, c.value(.quietEndHour, 8)))
        dailyNotificationCap = min(10, max(1, c.value(.dailyNotificationCap, 4)))
        minNotificationSpacingMinutes = min(360, max(0, c.value(.minNotificationSpacingMinutes, 90)))
        summaryReminderHour = min(23, max(0, c.value(.summaryReminderHour, 19)))
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
        #if INTERNAL_PREMIUM
        // Internal TestFlight build only (CI tag [interne], uploaded « TestFlight Internal Only »: Apple keeps
        // it from the App Store and from external testers). Never set in the project.
        return true
        #else
        return hasPurchase(at: date)
        #endif
    }
}
