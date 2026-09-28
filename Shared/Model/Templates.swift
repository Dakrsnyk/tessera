import Foundation

/// A ready-made starting point shown in Explore. Picking one opens the editor with a copy.
struct WidgetTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let kind: WidgetKind
    let themeID: ThemeID
    let accentHex: String
    var background: BackgroundStyle = .theme
    var font: FontChoice = .theme
    var alignment: ContentAlignment = .leading
    var isFeatured = false
    var configure: Configure = .none

    /// Kind-specific tweaks, kept as data so templates stay Hashable.
    enum Configure: Hashable {
        case none
        case progress(ProgressUnit)
        case countdown(String, days: Int, mode: CountdownMode)
        case note(title: String, text: String)
        case money(MoneyMode)
        case coin(String)
        case cities([String])
    }

    var theme: WidgetTheme { ThemeCatalog.theme(themeID) }

    var isPremium: Bool {
        kind.isPremium || theme.isPremium || background.isPremium || font.isPremium
            || !Palette.freeAccents.contains { $0.hex == accentHex }
    }

    func makeDesign(now: Date = Date()) -> WidgetDesign {
        var options = DesignOptions()
        switch configure {
        case .none: break
        case let .progress(unit): options.progressUnit = unit
        case let .countdown(title, days, mode):
            options.countdownTitle = title
            options.countdownMode = mode
            options.countdownDate = DateMath.calendar.date(byAdding: .day, value: days, to: DateMath.startOfDay(now)) ?? now
        case let .note(title, text):
            options.noteTitle = title
            options.noteText = text
        case let .money(mode): options.moneyMode = mode
        case let .coin(id): options.coinID = id
        case let .cities(ids): options.cities = ids
        }
        return WidgetDesign(
            name: name, kind: kind, themeID: themeID, accentHex: accentHex,
            background: background, font: font, alignment: alignment, options: options
        )
    }
}

enum TemplateCatalog {
    static let all: [WidgetTemplate] = [
        // Temps
        WidgetTemplate(id: "clock-minimal", name: "Heure", kind: .clock, themeID: .minimal, accentHex: "2F8F7A", isFeatured: true),
        WidgetTemplate(id: "clock-typo", name: "Heure typo", kind: .clock, themeID: .typography, accentHex: "FF6B57", alignment: .center),
        WidgetTemplate(id: "clock-digital", name: "Réveil digital", kind: .clock, themeID: .digital, accentHex: "2F8F7A"),
        WidgetTemplate(id: "calendar-light", name: "Ce mois-ci", kind: .calendar, themeID: .light, accentHex: "FF6B57", isFeatured: true),
        WidgetTemplate(id: "calendar-elegant", name: "Calendrier élégant", kind: .calendar, themeID: .elegant, accentHex: "2F8F7A"),
        WidgetTemplate(id: "world-futuristic", name: "Tour du monde", kind: .worldClock, themeID: .futuristic, accentHex: "3366FF",
                       configure: .cities(["America/Toronto", "Europe/Paris", "Asia/Tokyo"])),
        WidgetTemplate(id: "world-minimal", name: "Mes villes", kind: .worldClock, themeID: .minimal, accentHex: "3366FF",
                       configure: .cities(["America/Montreal", "Europe/Paris", "America/Los_Angeles", "Asia/Dubai"])),
        WidgetTemplate(id: "progress-year", name: "L'année avance", kind: .progress, themeID: .dark, accentHex: "F2A33A", isFeatured: true,
                       configure: .progress(.year)),
        WidgetTemplate(id: "progress-day", name: "Ma journée", kind: .progress, themeID: .minimal, accentHex: "3366FF",
                       configure: .progress(.day)),
        WidgetTemplate(id: "progress-month-retro", name: "Mois rétro", kind: .progress, themeID: .retro, accentHex: "F2A33A",
                       configure: .progress(.month)),
        WidgetTemplate(id: "countdown-holidays", name: "Vacances", kind: .countdown, themeID: .aurora, accentHex: "2F8F7A", isFeatured: true,
                       configure: .countdown("Vacances", days: 42, mode: .until)),
        WidgetTemplate(id: "countdown-birthday", name: "Anniversaire", kind: .countdown, themeID: .minimal, accentHex: "F2588F",
                       configure: .countdown("Mon anniversaire", days: 120, mode: .until)),
        WidgetTemplate(id: "countdown-since", name: "Jours depuis", kind: .countdown, themeID: .monochrome, accentHex: "6B7280",
                       configure: .countdown("Sans cigarette", days: -30, mode: .since)),
        WidgetTemplate(id: "dots-year", name: "365 points", kind: .yearDots, themeID: .dark, accentHex: "FF6B57", isFeatured: true),
        WidgetTemplate(id: "dots-glass", name: "Année de verre", kind: .yearDots, themeID: .glass, accentHex: "8C6CFF"),

        // Productivité
        WidgetTemplate(id: "tasks-minimal", name: "Aujourd'hui", kind: .tasks, themeID: .minimal, accentHex: "2F8F7A", isFeatured: true),
        WidgetTemplate(id: "tasks-light", name: "Liste claire", kind: .tasks, themeID: .light, accentHex: "3366FF"),
        WidgetTemplate(id: "habits-dark", name: "Mes habitudes", kind: .habits, themeID: .dark, accentHex: "7FA33A", isFeatured: true),
        WidgetTemplate(id: "habits-retro", name: "Routine rétro", kind: .habits, themeID: .retro, accentHex: "F2A33A"),
        WidgetTemplate(id: "focus-minimal", name: "Pomodoro", kind: .focus, themeID: .minimal, accentHex: "FF6B57", isFeatured: true),
        WidgetTemplate(id: "focus-futuristic", name: "Deep work", kind: .focus, themeID: .futuristic, accentHex: "3366FF"),
        WidgetTemplate(id: "upnext-minimal", name: "Prochain rendez-vous", kind: .upNext, themeID: .minimal, accentHex: "3366FF"),
        WidgetTemplate(id: "upnext-elegant", name: "Agenda élégant", kind: .upNext, themeID: .elegant, accentHex: "2F8F7A"),
        WidgetTemplate(id: "note-quote", name: "Citation", kind: .note, themeID: .typography, accentHex: "FF6B57", font: .serif,
                       configure: .note(title: "", text: "Ce qui se mesure s'améliore.")),
        WidgetTemplate(id: "note-reminder", name: "Pense-bête", kind: .note, themeID: .minimal, accentHex: "F2A33A",
                       configure: .note(title: "À ne pas oublier", text: "Rappeler maman dimanche.")),

        // Météo
        WidgetTemplate(id: "weather-minimal", name: "Météo", kind: .weather, themeID: .minimal, accentHex: "3366FF", isFeatured: true),
        WidgetTemplate(id: "weather-aurora", name: "Ciel aurore", kind: .weather, themeID: .aurora, accentHex: "3366FF"),
        WidgetTemplate(id: "weather-glass", name: "Météo verre", kind: .weather, themeID: .glass, accentHex: "8C6CFF"),

        // Finances
        WidgetTemplate(id: "crypto-dark", name: "Bitcoin", kind: .crypto, themeID: .dark, accentHex: "F2A33A", isFeatured: true,
                       configure: .coin("bitcoin")),
        WidgetTemplate(id: "crypto-eth", name: "Ethereum", kind: .crypto, themeID: .minimal, accentHex: "8C6CFF",
                       configure: .coin("ethereum")),
        WidgetTemplate(id: "money-net", name: "Solde net", kind: .moneyFlow, themeID: .dark, accentHex: "2F8F7A", isFeatured: true,
                       configure: .money(.net)),
        WidgetTemplate(id: "money-income", name: "Ce que je gagne", kind: .moneyFlow, themeID: .light, accentHex: "2F8F7A",
                       configure: .money(.income)),
        WidgetTemplate(id: "money-expense", name: "Ce que je dépense", kind: .moneyFlow, themeID: .minimal, accentHex: "FF6B57",
                       configure: .money(.expense)),

        // Bien-être
        WidgetTemplate(id: "water-minimal", name: "Verres d'eau", kind: .hydration, themeID: .minimal, accentHex: "3366FF", isFeatured: true),
        WidgetTemplate(id: "water-colorful", name: "Hydratation couleur", kind: .hydration, themeID: .colorful, accentHex: "3366FF"),
    ]

    static var featured: [WidgetTemplate] { all.filter(\.isFeatured) }

    static func template(_ id: String) -> WidgetTemplate? {
        all.first { $0.id == id }
    }

    /// A design from a known template, used by illustrations.
    static func design(_ id: String, theme: ThemeID? = nil) -> WidgetDesign {
        var design = template(id)?.makeDesign() ?? WidgetDesign.starter(for: .clock)
        if let theme { design.themeID = theme }
        return design
    }

    static var newest: [WidgetTemplate] { all.filter { $0.kind.isNew } }

    static func templates(for kind: WidgetKind) -> [WidgetTemplate] {
        all.filter { $0.kind == kind }
    }

    static func search(_ query: String) -> [WidgetTemplate] {
        let q = query.trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
        guard !q.isEmpty else { return all }
        return all.filter { template in
            let haystack = ([template.name, template.kind.title, template.kind.category.title, template.theme.name] + template.kind.keywords)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Fmt.locale)
            return haystack.contains(q)
        }
    }
}
