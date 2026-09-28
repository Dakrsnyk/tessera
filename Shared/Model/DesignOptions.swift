import Foundation

enum ProgressUnit: String, Codable, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "Journée"
        case .week: "Semaine"
        case .month: "Mois"
        case .year: "Année"
        }
    }
}

enum CountdownMode: String, Codable, CaseIterable, Identifiable {
    case until, since
    var id: String { rawValue }

    var title: String {
        switch self {
        case .until: "Jours avant"
        case .since: "Jours depuis"
        }
    }
}

enum MoneyMode: String, Codable, CaseIterable, Identifiable {
    case net, income, expense
    var id: String { rawValue }

    var title: String {
        switch self {
        case .net: "Solde net"
        case .income: "Revenus"
        case .expense: "Dépenses"
        }
    }
}

/// Settings that only apply to some widget kinds. Every field has a default so older
/// saved designs keep decoding when new options are added.
struct DesignOptions: Codable, Hashable {
    var progressUnit: ProgressUnit = .year
    var countdownTitle: String = "Vacances"
    var countdownDate: Date = Calendar.current.date(byAdding: .day, value: 42, to: Date()) ?? Date()
    var countdownMode: CountdownMode = .until
    var countdownReminder: Bool = false
    var cities: [String] = ["America/Toronto", "Europe/Paris", "Asia/Tokyo"]
    var noteTitle: String = ""
    var noteText: String = "Fais une chose aujourd'hui dont tu seras fier demain."
    var coinID: String = "bitcoin"
    var moneyMode: MoneyMode = .net
    var showsCompletedTasks: Bool = true
    var clockShowsDate: Bool = true
    /// The item a mini-app widget follows (a habit, a counter, a project, a goal, a company…), nil for the default one.
    var targetID: String?

    init() {}

    enum CodingKeys: String, CodingKey {
        case progressUnit, countdownTitle, countdownDate, countdownMode, countdownReminder
        case cities, noteTitle, noteText, coinID, moneyMode, showsCompletedTasks, clockShowsDate, targetID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DesignOptions()
        progressUnit = (try? c.decodeIfPresent(ProgressUnit.self, forKey: .progressUnit)) ?? d.progressUnit
        countdownTitle = (try? c.decodeIfPresent(String.self, forKey: .countdownTitle)) ?? d.countdownTitle
        countdownDate = (try? c.decodeIfPresent(Date.self, forKey: .countdownDate)) ?? d.countdownDate
        countdownMode = (try? c.decodeIfPresent(CountdownMode.self, forKey: .countdownMode)) ?? d.countdownMode
        countdownReminder = (try? c.decodeIfPresent(Bool.self, forKey: .countdownReminder)) ?? d.countdownReminder
        cities = (try? c.decodeIfPresent([String].self, forKey: .cities)) ?? d.cities
        noteTitle = (try? c.decodeIfPresent(String.self, forKey: .noteTitle)) ?? d.noteTitle
        noteText = (try? c.decodeIfPresent(String.self, forKey: .noteText)) ?? d.noteText
        coinID = (try? c.decodeIfPresent(String.self, forKey: .coinID)) ?? d.coinID
        moneyMode = (try? c.decodeIfPresent(MoneyMode.self, forKey: .moneyMode)) ?? d.moneyMode
        showsCompletedTasks = (try? c.decodeIfPresent(Bool.self, forKey: .showsCompletedTasks)) ?? d.showsCompletedTasks
        clockShowsDate = (try? c.decodeIfPresent(Bool.self, forKey: .clockShowsDate)) ?? d.clockShowsDate
        targetID = (try? c.decodeIfPresent(String.self, forKey: .targetID)) ?? nil
    }
}
