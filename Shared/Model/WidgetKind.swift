import Foundation
import WidgetKit

enum WidgetCategory: String, CaseIterable, Codable, Identifiable {
    case time
    case productivity
    case weather
    case finance
    case wellbeing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .time: "Temps"
        case .productivity: "Productivité"
        case .weather: "Météo"
        case .finance: "Finances"
        case .wellbeing: "Bien-être"
        }
    }

    var symbol: String {
        switch self {
        case .time: "clock"
        case .productivity: "checklist"
        case .weather: "cloud.sun"
        case .finance: "chart.line.uptrend.xyaxis"
        case .wellbeing: "leaf"
        }
    }
}

/// Every widget type the app can render. The raw value is persisted, never rename it.
enum WidgetKind: String, CaseIterable, Codable, Identifiable {
    case clock
    case calendar
    case worldClock
    case progress
    case countdown
    case yearDots
    case tasks
    case habits
    case focus
    case upNext
    case note
    case weather
    case crypto
    case moneyFlow
    case hydration

    var id: String { rawValue }

    /// The identifier registered with WidgetKit.
    var widgetKindID: String { "tessera.\(rawValue)" }

    var title: String {
        switch self {
        case .clock: "Horloge"
        case .calendar: "Calendrier"
        case .worldClock: "Fuseaux horaires"
        case .progress: "Progression"
        case .countdown: "Compte à rebours"
        case .yearDots: "L'année en points"
        case .tasks: "Tâches"
        case .habits: "Habitudes"
        case .focus: "Focus"
        case .upNext: "À venir"
        case .note: "Note"
        case .weather: "Météo"
        case .crypto: "Crypto"
        case .moneyFlow: "Flux d'argent"
        case .hydration: "Hydratation"
        }
    }

    var summary: String {
        switch self {
        case .clock: "L'heure et la date, sans rien de plus."
        case .calendar: "Le mois en un coup d'œil, aujourd'hui mis en avant."
        case .worldClock: "L'heure de tes villes, avec le décalage horaire."
        case .progress: "Où en est ta journée, ta semaine, ton mois ou ton année."
        case .countdown: "Les jours avant un événement, ou depuis un moment important."
        case .yearDots: "Chaque jour de l'année est un point. Regarde-la avancer."
        case .tasks: "Ta liste du jour, que tu coches directement sur l'écran d'accueil."
        case .habits: "Tes habitudes de la semaine, validées d'une touche."
        case .focus: "Un minuteur de concentration qui défile en direct."
        case .upNext: "Tes prochains rendez-vous, tirés de ton calendrier."
        case .note: "Un mot, un rappel ou une citation, toujours sous les yeux."
        case .weather: "La température et les prévisions de ta ville."
        case .crypto: "Le cours d'une crypto et sa courbe sur 7 jours."
        case .moneyFlow: "Ce que tu gagnes et dépenses, calculé au fil du jour."
        case .hydration: "Tes verres d'eau de la journée, ajoutés d'une touche."
        }
    }

    var category: WidgetCategory {
        switch self {
        case .clock, .calendar, .worldClock, .progress, .countdown, .yearDots: .time
        case .tasks, .habits, .focus, .upNext, .note: .productivity
        case .weather: .weather
        case .crypto, .moneyFlow: .finance
        case .hydration: .wellbeing
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
        case .calendar: "calendar"
        case .worldClock: "globe"
        case .progress: "chart.bar.fill"
        case .countdown: "hourglass"
        case .yearDots: "circle.grid.3x3.fill"
        case .tasks: "checklist"
        case .habits: "repeat"
        case .focus: "timer"
        case .upNext: "calendar.badge.clock"
        case .note: "note.text"
        case .weather: "cloud.sun.fill"
        case .crypto: "bitcoinsign.circle"
        case .moneyFlow: "dollarsign.arrow.circlepath"
        case .hydration: "drop.fill"
        }
    }

    var isPremium: Bool {
        switch self {
        case .worldClock, .yearDots, .focus, .upNext, .crypto, .moneyFlow: true
        default: false
        }
    }

    /// Shown in the "Nouveautés" shelf.
    var isNew: Bool {
        switch self {
        case .moneyFlow, .yearDots, .focus: true
        default: false
        }
    }

    var families: [WidgetFamily] {
        switch self {
        case .clock: [.systemSmall, .systemMedium]
        case .calendar: [.systemSmall, .systemMedium, .systemLarge]
        case .worldClock: [.systemSmall, .systemMedium]
        case .progress: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        case .countdown: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        case .yearDots: [.systemSmall, .systemMedium, .systemLarge]
        case .tasks: [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]
        case .habits: [.systemSmall, .systemMedium, .systemLarge]
        case .focus: [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular]
        case .upNext: [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular]
        case .note: [.systemSmall, .systemMedium, .systemLarge]
        case .weather: [.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        case .crypto: [.systemSmall, .systemMedium, .accessoryRectangular]
        case .moneyFlow: [.systemSmall, .systemMedium, .systemLarge]
        case .hydration: [.systemSmall, .systemMedium, .accessoryCircular]
        }
    }

    var homeFamilies: [WidgetFamily] {
        families.filter { $0 == .systemSmall || $0 == .systemMedium || $0 == .systemLarge }
    }

    var supportsLockScreen: Bool {
        families.contains { $0 == .accessoryCircular || $0 == .accessoryRectangular || $0 == .accessoryInline }
    }

    /// Words that should match this widget in search, beyond its title.
    var keywords: [String] {
        switch self {
        case .clock: ["heure", "time", "minimal", "date"]
        case .calendar: ["mois", "date", "jour", "agenda"]
        case .worldClock: ["monde", "fuseau", "voyage", "ville", "heure"]
        case .progress: ["année", "mois", "semaine", "journée", "pourcentage"]
        case .countdown: ["jours", "days until", "days since", "événement", "anniversaire", "depuis"]
        case .yearDots: ["année", "points", "jours", "calendrier"]
        case .tasks: ["todo", "to-do", "liste", "à faire"]
        case .habits: ["routine", "streak", "objectif", "série"]
        case .focus: ["pomodoro", "minuteur", "timer", "concentration", "travail"]
        case .upNext: ["événements", "agenda", "rendez-vous", "réunion"]
        case .note: ["citation", "mémo", "texte", "rappel"]
        case .weather: ["température", "pluie", "prévisions", "soleil"]
        case .crypto: ["bitcoin", "ethereum", "btc", "marché", "cours"]
        case .moneyFlow: ["argent", "revenus", "dépenses", "budget", "salaire", "loyer"]
        case .hydration: ["eau", "boire", "verres", "santé"]
        }
    }

    static func kinds(in category: WidgetCategory) -> [WidgetKind] {
        allCases.filter { $0.category == category }
    }
}

extension WidgetFamily {
    var shortTitle: String {
        switch self {
        case .systemSmall: "Petit"
        case .systemMedium: "Moyen"
        case .systemLarge: "Grand"
        case .systemExtraLarge: "Très grand"
        case .accessoryCircular: "Rond"
        case .accessoryRectangular: "Rectangle"
        case .accessoryInline: "En ligne"
        @unknown default: "Widget"
        }
    }

    var isAccessory: Bool {
        self == .accessoryCircular || self == .accessoryRectangular || self == .accessoryInline
    }
}
