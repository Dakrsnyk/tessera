import SwiftUI
import WidgetKit

/// A complete, ready-made screen: a wallpaper, Tessera widgets placed as on a real iPhone,
/// app icons in the same mood and a matching Lock Screen. Shown in the Store, installed in one tap.
struct HomeSetup: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let tags: [SetupTag]
    let wallpaper: SetupWallpaper
    let icons: SetupIconStyle
    /// Home Screen rows, top to bottom.
    let rows: [SetupRow]
    let dock: [SetupApp]
    let lock: SetupLock

    /// Every widget of the setup, Home Screen first, one per kind.
    var widgets: [SetupWidget] {
        var seen: Set<WidgetKind> = []
        var result: [SetupWidget] = []
        for widget in rows.flatMap(\.widgets) + lock.allWidgets where !seen.contains(widget.kind) {
            seen.insert(widget.kind)
            result.append(widget)
        }
        return result
    }

    var homeWidgets: [SetupWidget] { widgets.filter { !$0.family.isAccessory } }
    var lockOnlyWidgets: [SetupWidget] { widgets.filter(\.family.isAccessory) }

    func designs() -> [WidgetDesign] { widgets.map { $0.makeDesign() } }

    var isPremium: Bool { designs().contains(where: \.usesPremiumFeatures) }

    /// Colors of the text drawn on the wallpaper (icon labels, clock, status bar).
    var ink: Color { wallpaper.isLight ? Color(hex: wallpaper.darkInk) : .white }
}

enum SetupTag: String, CaseIterable, Identifiable {
    case minimal, dark, light, colorful, pastel, productivity, fitness, study, travel, money, wellbeing
    var id: String { rawValue }

    var title: String {
        switch self {
        case .minimal: "minimal"
        case .dark: "sombre"
        case .light: "clair"
        case .colorful: "coloré"
        case .pastel: "pastel"
        case .productivity: "productivité"
        case .fitness: "sport"
        case .study: "études"
        case .travel: "voyage"
        case .money: "finances"
        case .wellbeing: "bien-être"
        }
    }
}

/// One widget placed in a setup, at the size it is shown.
struct SetupWidget {
    let kind: WidgetKind
    let family: WidgetFamily
    let theme: ThemeID
    let accent: String
    var template: String?

    func makeDesign() -> WidgetDesign {
        var design = template.flatMap { TemplateCatalog.template($0) }.map { $0.makeDesign() }
            ?? TemplateCatalog.template(for: kind)?.makeDesign()
            ?? WidgetDesign.starter(for: kind)
        design.kind = kind
        design.name = kind.title
        design.themeID = theme
        design.accentHex = accent
        design.background = .theme
        design.font = .theme
        return design
    }
}

enum SetupRow {
    /// Two small widgets, one medium or one large.
    case widgets([SetupWidget])
    /// A small widget and four app icons in a square, on either side.
    case widgetAndApps(SetupWidget, [SetupApp], widgetFirst: Bool)
    /// A row of four app icons.
    case apps([SetupApp])

    var widgets: [SetupWidget] {
        switch self {
        case let .widgets(widgets): widgets
        case let .widgetAndApps(widget, _, _): [widget]
        case .apps: []
        }
    }
}

struct SetupLock {
    /// Next to the date, above the clock.
    var inline: SetupWidget?
    /// Below the clock: up to four circular widgets, or rectangular ones (each counts for two).
    var widgets: [SetupWidget]
    var clockDesign: Font.Design = .default
    var clockWeight: Font.Weight = .semibold

    var allWidgets: [SetupWidget] { widgets + [inline].compactMap { $0 } }
}

/// A generic app for the icons around the widgets (no brand, no real app icon).
struct SetupApp: Hashable {
    let name: String
    let symbol: String

    static let phone = SetupApp(name: "Téléphone", symbol: "phone.fill")
    static let messages = SetupApp(name: "Messages", symbol: "message.fill")
    static let mail = SetupApp(name: "Mail", symbol: "envelope.fill")
    static let music = SetupApp(name: "Musique", symbol: "music.note")
    static let photos = SetupApp(name: "Photos", symbol: "photo.on.rectangle.angled")
    static let camera = SetupApp(name: "Caméra", symbol: "camera.fill")
    static let maps = SetupApp(name: "Plans", symbol: "map.fill")
    static let notes = SetupApp(name: "Notes", symbol: "note.text")
    static let settings = SetupApp(name: "Réglages", symbol: "gearshape.fill")
    static let clock = SetupApp(name: "Horloge", symbol: "clock.fill")
    static let calendar = SetupApp(name: "Calendrier", symbol: "calendar")
    static let books = SetupApp(name: "Livres", symbol: "book.fill")
    static let weather = SetupApp(name: "Météo", symbol: "cloud.sun.fill")
    static let reminders = SetupApp(name: "Rappels", symbol: "checklist")
    static let health = SetupApp(name: "Santé", symbol: "heart.fill")
    static let fitness = SetupApp(name: "Forme", symbol: "figure.run")
    static let wallet = SetupApp(name: "Cartes", symbol: "creditcard.fill")
    static let web = SetupApp(name: "Web", symbol: "globe")
    static let podcasts = SetupApp(name: "Podcasts", symbol: "mic.fill")
    static let files = SetupApp(name: "Fichiers", symbol: "folder.fill")
    static let tessera = SetupApp(name: "Tessera", symbol: "")
}

enum SetupIconStyle {
    /// Translucent white tiles, white symbols.
    case glass
    /// Near-black tiles, colored symbols.
    case tinted(String)
    case solid(background: String, symbol: String)
    case gradient([String], symbol: String)
}

enum SetupWallpaper: String, CaseIterable {
    case midnight, cream, aurora, topography, synthwave, dunes, jade, pastel, graphite, paper, bureau, bauhaus

    var isLight: Bool {
        switch self {
        case .cream, .topography, .dunes, .pastel, .paper, .bauhaus: true
        default: false
        }
    }

    /// Ink for text drawn on a light wallpaper.
    var darkInk: String {
        switch self {
        case .cream: "3B2F22"
        case .topography: "2E3A26"
        case .dunes: "4A2616"
        case .pastel: "4A2E40"
        case .paper: "1E2A44"
        case .bauhaus: "3A1F1A"
        default: "1C1C1E"
        }
    }

    var title: String {
        switch self {
        case .midnight: "Nuit étoilée"
        case .cream: "Soleil crème"
        case .aurora: "Aurore boréale"
        case .topography: "Courbes de niveau"
        case .synthwave: "Rétro néon"
        case .dunes: "Dunes"
        case .jade: "Mosaïque jade"
        case .pastel: "Brume pastel"
        case .graphite: "Graphite"
        case .paper: "Papier pointillé"
        case .bureau: "Art déco"
        case .bauhaus: "Formes"
        }
    }
}

// MARK: - Catalog

enum HomeSetupCatalog {
    private static func small(_ kind: WidgetKind, _ theme: ThemeID, _ accent: String, _ template: String? = nil) -> SetupWidget {
        SetupWidget(kind: kind, family: .systemSmall, theme: theme, accent: accent, template: template)
    }

    private static func medium(_ kind: WidgetKind, _ theme: ThemeID, _ accent: String, _ template: String? = nil) -> SetupWidget {
        SetupWidget(kind: kind, family: .systemMedium, theme: theme, accent: accent, template: template)
    }

    private static func circular(_ kind: WidgetKind, _ template: String? = nil) -> SetupWidget {
        SetupWidget(kind: kind, family: .accessoryCircular, theme: .minimal, accent: Palette.defaultAccent, template: template)
    }

    private static func rectangular(_ kind: WidgetKind, _ template: String? = nil) -> SetupWidget {
        SetupWidget(kind: kind, family: .accessoryRectangular, theme: .minimal, accent: Palette.defaultAccent, template: template)
    }

    private static func inline(_ kind: WidgetKind) -> SetupWidget {
        SetupWidget(kind: kind, family: .accessoryInline, theme: .minimal, accent: Palette.defaultAccent)
    }

    static let all: [HomeSetup] = [
        HomeSetup(
            id: "creme", name: "Crème", tagline: "Des tons chauds et l'essentiel de la journée, sans bruit.",
            tags: [.light, .minimal], wallpaper: .cream,
            icons: .solid(background: "FBF7EF", symbol: "8A6F55"),
            rows: [
                .widgets([medium(.progress, .light, "F2A33A", "progress-year")]),
                .widgets([small(.weekView, .light, "F2A33A"), small(.note, .light, "F2A33A", "note-quote")]),
                .widgetAndApps(small(.countdown, .light, "F2A33A", "countdown-holidays"), [.photos, .camera, .maps, .weather], widgetFirst: true),
            ],
            dock: [.phone, .messages, .web, .music],
            lock: SetupLock(widgets: [rectangular(.progress, "progress-year"), circular(.countdown, "countdown-holidays"), circular(.weather)])
        ),
        HomeSetup(
            id: "aurore", name: "Aurore", tagline: "Des dégradés boréals pour l'eau, les habitudes et la météo.",
            tags: [.colorful, .dark, .wellbeing], wallpaper: .aurora, icons: .glass,
            rows: [
                .widgets([medium(.now, .aurora, "3366FF")]),
                .widgets([small(.weather, .glass, "8C6CFF"), small(.hydration, .aurora, "3366FF")]),
                .widgetAndApps(small(.habitStreak, .aurora, "3366FF"), [.health, .fitness, .music, .podcasts], widgetFirst: false),
            ],
            dock: [.phone, .messages, .web, .camera],
            lock: SetupLock(widgets: [circular(.hydration), circular(.habitStreak), circular(.weather), circular(.progress, "progress-day")])
        ),
        HomeSetup(
            id: "graphite", name: "Graphite", tagline: "Noir, blanc et rien d'autre. L'heure, la journée, la semaine.",
            tags: [.dark, .minimal], wallpaper: .graphite,
            icons: .solid(background: "1C1C1E", symbol: "FFFFFF"),
            rows: [
                .widgets([small(.clock, .monochrome, "6B7280"), small(.progress, .monochrome, "6B7280", "progress-day")]),
                .widgets([medium(.weekView, .monochrome, "6B7280")]),
                .widgetAndApps(small(.counter, .monochrome, "6B7280"), [.phone, .clock, .notes, .settings], widgetFirst: false),
            ],
            dock: [.messages, .mail, .web, .music],
            lock: SetupLock(widgets: [circular(.progress, "progress-day"), circular(.counter), circular(.weather), circular(.countdown)], clockWeight: .light)
        ),
        HomeSetup(
            id: "neon", name: "Néon", tagline: "Focus, échéances et fuseaux, en cyan électrique.",
            tags: [.dark, .colorful, .productivity], wallpaper: .synthwave, icons: .tinted("22E6FF"),
            rows: [
                .widgets([small(.focus, .futuristic, "3366FF", "focus-futuristic"), small(.deadline, .futuristic, "3366FF")]),
                .widgets([medium(.worldClock, .futuristic, "3366FF", "world-futuristic")]),
                .widgetAndApps(small(.crypto, .digital, "3366FF"), [.web, .settings, .calendar, .clock], widgetFirst: false),
            ],
            dock: [.phone, .messages, .music, .camera],
            lock: SetupLock(widgets: [circular(.focus), circular(.deadline), circular(.progress, "progress-day"), circular(.counter)],
                            clockDesign: .monospaced, clockWeight: .light)
        ),
        HomeSetup(
            id: "topographie", name: "Topographie", tagline: "Soleil, lune et météo sur des courbes de niveau.",
            tags: [.light, .minimal, .wellbeing], wallpaper: .topography,
            icons: .solid(background: "F4F6EF", symbol: "5E7A3A"),
            rows: [
                .widgets([small(.sunCycle, .light, "7FA33A"), small(.moonPhase, .light, "7FA33A")]),
                .widgets([medium(.weather, .light, "7FA33A")]),
                .widgetAndApps(small(.habits, .light, "7FA33A"), [.maps, .weather, .camera, .notes], widgetFirst: true),
            ],
            dock: [.phone, .messages, .web, .photos],
            lock: SetupLock(widgets: [rectangular(.sunCycle), circular(.moonPhase), circular(.weather)])
        ),
        HomeSetup(
            id: "minuit", name: "Minuit", tagline: "Or et bleu nuit, serif et étoiles : ton agenda en élégance.",
            tags: [.dark], wallpaper: .midnight,
            icons: .solid(background: "13203A", symbol: "C8A15A"),
            rows: [
                .widgets([small(.clock, .elegant, "F2A33A"), small(.calendar, .elegant, "F2A33A")]),
                .widgets([medium(.upNext, .elegant, "F2A33A", "upnext-elegant")]),
                .widgetAndApps(small(.moonPhase, .elegant, "F2A33A"), [.notes, .books, .podcasts, .settings], widgetFirst: false),
            ],
            dock: [.phone, .messages, .web, .music],
            lock: SetupLock(widgets: [circular(.moonPhase), circular(.weather), circular(.progress, "progress-day"), circular(.countdown)],
                            clockDesign: .serif, clockWeight: .regular)
        ),
        HomeSetup(
            id: "etudes", name: "Études", tagline: "Cours, examens et priorités sur papier pointillé.",
            tags: [.light, .study, .productivity], wallpaper: .paper,
            icons: .solid(background: "FFFFFF", symbol: "3366FF"),
            rows: [
                .widgets([small(.nextClass, .light, "3366FF"), small(.nextExam, .light, "3366FF")]),
                .widgets([medium(.priorities, .light, "3366FF")]),
                .widgetAndApps(small(.semesterProgress, .light, "3366FF"), [.books, .notes, .calendar, .reminders], widgetFirst: true),
            ],
            dock: [.phone, .messages, .web, .files],
            lock: SetupLock(inline: inline(.nextClass), widgets: [rectangular(.priorities), circular(.nextExam), circular(.semesterProgress)])
        ),
        HomeSetup(
            id: "jade", name: "Jade", tagline: "Calories, séance et régularité, aux couleurs de Tessera.",
            tags: [.colorful, .fitness], wallpaper: .jade,
            icons: .gradient(["3FB39A", "1F6B5A"], symbol: "FFFFFF"),
            rows: [
                .widgets([small(.caloriesLeft, .colorful, "2F8F7A"), small(.macros, .dark, "2F8F7A")]),
                .widgets([medium(.todaysWorkout, .dark, "2F8F7A")]),
                .widgetAndApps(small(.trainingStreak, .colorful, "2F8F7A"), [.health, .fitness, .music, .tessera], widgetFirst: false),
            ],
            dock: [.phone, .messages, .web, .camera],
            lock: SetupLock(widgets: [circular(.caloriesLeft), circular(.trainingStreak), rectangular(.nextSet)], clockWeight: .bold)
        ),
        HomeSetup(
            id: "dune", name: "Dune", tagline: "Le départ, le vol et l'heure sur place, au soleil couchant.",
            tags: [.light, .travel, .colorful], wallpaper: .dunes,
            icons: .solid(background: "F9E6D2", symbol: "B5532C"),
            rows: [
                .widgets([small(.tripCountdown, .retro, "F2A33A", "trip-aurora"), small(.localTime, .retro, "F2A33A")]),
                .widgets([medium(.weather, .retro, "F2A33A")]),
                .widgetAndApps(small(.currency, .retro, "F2A33A"), [.maps, .camera, .photos, .wallet], widgetFirst: true),
            ],
            dock: [.phone, .messages, .web, .music],
            lock: SetupLock(inline: inline(.localTime), widgets: [circular(.tripCountdown, "trip-aurora"), rectangular(.flight), circular(.weather)],
                            clockDesign: .rounded, clockWeight: .bold)
        ),
        HomeSetup(
            id: "pastel", name: "Pastel", tagline: "Une brume rose et lilas pour les dates qui comptent.",
            tags: [.pastel, .light], wallpaper: .pastel,
            icons: .gradient(["FFE1E8", "E6DDFF"], symbol: "A0567A"),
            rows: [
                .widgets([small(.countdown, .typography, "F2588F", "countdown-birthday"), small(.birthday, .glass, "F2588F")]),
                .widgets([medium(.note, .typography, "F2588F", "note-reminder")]),
                .widgetAndApps(small(.hydration, .glass, "F2588F"), [.photos, .messages, .music, .calendar], widgetFirst: true),
            ],
            dock: [.phone, .mail, .web, .camera],
            lock: SetupLock(widgets: [circular(.birthday), circular(.hydration), circular(.countdown, "countdown-birthday"), circular(.moonPhase)],
                            clockDesign: .serif, clockWeight: .medium)
        ),
        HomeSetup(
            id: "bureau", name: "Bureau", tagline: "Ventes, MRR et portefeuille, façon art déco.",
            tags: [.dark, .money], wallpaper: .bureau, icons: .tinted("C8A15A"),
            rows: [
                .widgets([small(.revenueToday, .elegant, "F2A33A"), small(.mrr, .elegant, "F2A33A")]),
                .widgets([medium(.businessDashboard, .elegant, "F2A33A")]),
                .widgetAndApps(small(.portfolio, .elegant, "F2A33A"), [.mail, .calendar, .wallet, .files], widgetFirst: false),
            ],
            dock: [.phone, .messages, .web, .notes],
            lock: SetupLock(widgets: [rectangular(.revenueToday), rectangular(.portfolio)], clockDesign: .serif, clockWeight: .regular)
        ),
        HomeSetup(
            id: "corail", name: "Corail", tagline: "Ton budget en grandes formes colorées.",
            tags: [.colorful, .light, .money], wallpaper: .bauhaus,
            icons: .solid(background: "FFFFFF", symbol: "FF6B57"),
            rows: [
                .widgets([small(.budgetLeft, .colorful, "FF6B57"), small(.savingsGoal, .light, "FF6B57")]),
                .widgets([medium(.spendingByCategory, .light, "FF6B57")]),
                .widgetAndApps(small(.quickExpense, .colorful, "FF6B57"), [.wallet, .maps, .messages, .photos], widgetFirst: true),
            ],
            dock: [.phone, .mail, .web, .camera],
            lock: SetupLock(widgets: [rectangular(.budgetLeft), rectangular(.billsUpcoming)], clockDesign: .rounded, clockWeight: .bold)
        ),
    ]

    static func setup(_ id: String) -> HomeSetup? {
        all.first { $0.id == id }
    }
}
