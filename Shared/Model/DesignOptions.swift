import Foundation

enum ProgressUnit: String, Codable, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: tr("Journée")
        case .week: tr("Semaine")
        case .month: tr("Mois")
        case .year: tr("Année")
        }
    }
}

enum CountdownMode: String, Codable, CaseIterable, Identifiable {
    case until, since
    var id: String { rawValue }

    var title: String {
        switch self {
        case .until: tr("Jours avant")
        case .since: tr("Jours depuis")
        }
    }
}

enum MoneyMode: String, Codable, CaseIterable, Identifiable {
    case net, income, expense
    var id: String { rawValue }

    var title: String {
        switch self {
        case .net: tr("Solde net")
        case .income: tr("Revenus")
        case .expense: tr("Dépenses")
        }
    }
}

/// Settings that only apply to some widget kinds. Every field has a default so older
/// saved designs keep decoding when new options are added.
struct DesignOptions: Codable, Hashable {
    var progressUnit: ProgressUnit = .year
    var countdownTitle: String = tr("Vacances")
    var countdownDate: Date = Calendar.current.date(byAdding: .day, value: 42, to: Date()) ?? Date()
    var countdownMode: CountdownMode = .until
    var countdownReminder: Bool = false
    /// The « Décompte » widget (kind `birthday`): its name and date, nil while the person kept the defaults
    /// (« Anniversaire », and the birthday of « Ma vie »). See `DayCountdown`.
    var dayTitle: String?
    var dayDate: Date?
    /// Counts to the next anniversary of the date each year. True when absent, so widgets made when this
    /// was only the birthday widget draw exactly as before.
    var dayRepeatsYearly: Bool = true
    var cities: [String] = ["America/Toronto", "Europe/Paris", "Asia/Tokyo"]
    var noteTitle: String = ""
    var noteText: String = tr("Fais une chose aujourd'hui dont tu seras fier demain.")
    var coinID: String = "bitcoin"
    var moneyMode: MoneyMode = .net
    var showsCompletedTasks: Bool = true
    var clockShowsDate: Bool = true
    /// The item a mini-app widget follows (a habit, a counter, a project, a goal, a company…), nil for the default one.
    var targetID: String?
    /// A combined widget: the widgets drawn inside it, in order. Empty for every other widget.
    var parts: [ComboPart] = []
    /// A photo widget: its photos, in order, each with its framing.
    var photos: [PhotoSlot] = []
    /// A quote widget: its text, author, typography and colors.
    var quote: QuoteContent?

    init() {}

    enum CodingKeys: String, CodingKey {
        case progressUnit, countdownTitle, countdownDate, countdownMode, countdownReminder, dayTitle, dayDate, dayRepeatsYearly
        case cities, noteTitle, noteText, coinID, moneyMode, showsCompletedTasks, clockShowsDate, targetID, parts, photos, quote
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DesignOptions()
        progressUnit = (try? c.decodeIfPresent(ProgressUnit.self, forKey: .progressUnit)) ?? d.progressUnit
        countdownTitle = (try? c.decodeIfPresent(String.self, forKey: .countdownTitle)) ?? d.countdownTitle
        countdownDate = (try? c.decodeIfPresent(Date.self, forKey: .countdownDate)) ?? d.countdownDate
        countdownMode = (try? c.decodeIfPresent(CountdownMode.self, forKey: .countdownMode)) ?? d.countdownMode
        countdownReminder = (try? c.decodeIfPresent(Bool.self, forKey: .countdownReminder)) ?? d.countdownReminder
        dayTitle = (try? c.decodeIfPresent(String.self, forKey: .dayTitle)) ?? nil
        dayDate = (try? c.decodeIfPresent(Date.self, forKey: .dayDate)) ?? nil
        dayRepeatsYearly = (try? c.decodeIfPresent(Bool.self, forKey: .dayRepeatsYearly)) ?? d.dayRepeatsYearly
        cities = (try? c.decodeIfPresent([String].self, forKey: .cities)) ?? d.cities
        noteTitle = (try? c.decodeIfPresent(String.self, forKey: .noteTitle)) ?? d.noteTitle
        noteText = (try? c.decodeIfPresent(String.self, forKey: .noteText)) ?? d.noteText
        coinID = (try? c.decodeIfPresent(String.self, forKey: .coinID)) ?? d.coinID
        moneyMode = (try? c.decodeIfPresent(MoneyMode.self, forKey: .moneyMode)) ?? d.moneyMode
        showsCompletedTasks = (try? c.decodeIfPresent(Bool.self, forKey: .showsCompletedTasks)) ?? d.showsCompletedTasks
        clockShowsDate = (try? c.decodeIfPresent(Bool.self, forKey: .clockShowsDate)) ?? d.clockShowsDate
        targetID = (try? c.decodeIfPresent(String.self, forKey: .targetID)) ?? nil
        // A widget of a removed kind is left out of the combination, the others stay.
        parts = (try? c.decodeIfPresent(LossyList<ComboPart>.self, forKey: .parts))?.elements ?? []
        photos = (try? c.decodeIfPresent([PhotoSlot].self, forKey: .photos)) ?? []
        quote = (try? c.decodeIfPresent(QuoteContent.self, forKey: .quote)) ?? nil
    }
}
