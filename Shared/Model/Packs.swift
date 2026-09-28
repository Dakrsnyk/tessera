import Foundation

/// A themed set of widgets installed in one tap from the Store, with a shared look.
struct WidgetPack: Identifiable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let symbol: String
    let themeID: ThemeID
    let accentHex: String
    let kinds: [WidgetKind]

    var isPremium: Bool {
        ThemeCatalog.theme(themeID).isPremium || kinds.contains(where: \.isPremium)
            || !Palette.freeAccents.contains { $0.hex == accentHex }
    }

    func designs() -> [WidgetDesign] {
        kinds.map { kind in
            var design = TemplateCatalog.template(for: kind)?.makeDesign() ?? WidgetDesign.starter(for: kind)
            design.name = kind.title
            design.themeID = themeID
            design.accentHex = accentHex
            design.background = .theme
            return design
        }
    }
}

enum PackCatalog {
    static let all: [WidgetPack] = [
        WidgetPack(id: "morning", name: "Bien démarrer", tagline: "Météo, agenda, priorités et eau, dès le réveil.", symbol: "sunrise.fill",
                   themeID: .glass, accentHex: "8C6CFF", kinds: [.now, .morning, .weather, .upNext, .priorities, .hydration]),
        WidgetPack(id: "student", name: "Étudiant", tagline: "Cours, examens, devoirs et fiches de révision.", symbol: "graduationcap.fill",
                   themeID: .minimal, accentHex: "F2588F", kinds: [.nextClass, .nextExam, .assignments, .timetable, .flashcard, .semesterProgress]),
        WidgetPack(id: "athlete", name: "Sportif", tagline: "Séance, séries, repos, calories et protéines.", symbol: "figure.strengthtraining.traditional",
                   themeID: .dark, accentHex: "FF6B57", kinds: [.todaysWorkout, .nextSet, .restTimer, .trainingStreak, .caloriesLeft, .proteinLeft]),
        WidgetPack(id: "founder", name: "Entrepreneur", tagline: "Chiffre d'affaires, objectif, bénéfice et MRR.", symbol: "briefcase.fill",
                   themeID: .elegant, accentHex: "F2A33A", kinds: [.revenueGoal, .revenueToday, .profit, .businessKPIs, .mrr, .businessDashboard]),
        WidgetPack(id: "budget", name: "Budget serré", tagline: "Reste du mois, dépenses rapides, factures et épargne.", symbol: "creditcard.fill",
                   themeID: .light, accentHex: "2F8F7A", kinds: [.budgetLeft, .quickExpense, .billsUpcoming, .savingsGoal, .subscriptions, .moneyDashboard]),
        WidgetPack(id: "traveler", name: "Voyageur", tagline: "Départ, vol, hôtel, météo, heure et devise sur place.", symbol: "airplane",
                   themeID: .aurora, accentHex: "3366FF", kinds: [.tripCountdown, .flight, .hotel, .destinationWeather, .localTime, .currency]),
        WidgetPack(id: "investor", name: "Investisseur", tagline: "Portefeuille, répartition, cours et chiffres officiels.", symbol: "chart.line.uptrend.xyaxis",
                   themeID: .futuristic, accentHex: "3366FF", kinds: [.portfolio, .allocation, .watchlist, .marketOverview, .companySnapshot, .companyCompare]),
        WidgetPack(id: "calm", name: "Minimal", tagline: "L'essentiel en noir et blanc, sans rien de plus.", symbol: "circle.lefthalf.filled",
                   themeID: .monochrome, accentHex: "6B7280", kinds: [.clock, .calendar, .progress, .weekView, .moonPhase, .note]),
    ]

    static func pack(_ id: String) -> WidgetPack? {
        all.first { $0.id == id }
    }
}
