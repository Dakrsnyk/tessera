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

    /// The widgets shown as small ones in the Store (a few exist only in medium or large).
    func smallDesigns() -> [WidgetDesign] {
        designs().filter { $0.kind.families.contains(.systemSmall) }
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
        WidgetPack(id: "essentials", name: "L'essentiel", tagline: "Heure, météo, tâches, habitudes et dates, gratuitement.", symbol: "star.fill",
                   themeID: .minimal, accentHex: "2F8F7A", kinds: [.clock, .weather, .tasks, .habits, .calendar, .countdown]),
        WidgetPack(id: "nutrition", name: "Nutrition complète", tagline: "Calories, macros, protéines, repas et semaine.", symbol: "fork.knife",
                   themeID: .glass, accentHex: "2F8F7A", kinds: [.caloriesLeft, .macros, .proteinLeft, .mealsToday, .nutritionWeek, .nextMeal]),
        WidgetPack(id: "habits", name: "Bonnes habitudes", tagline: "Routine, eau, séries, taux de réussite et rythme du jour.", symbol: "leaf.fill",
                   themeID: .minimal, accentHex: "8C6CFF", kinds: [.habits, .hydration, .habitStreak, .habitRate, .sunCycle, .moonPhase]),
        WidgetPack(id: "focus", name: "Concentration", tagline: "Focus, travail profond, priorités et échéances.", symbol: "scope",
                   themeID: .futuristic, accentHex: "3366FF", kinds: [.focus, .deepWork, .priorities, .deadline, .project, .tasks]),
        WidgetPack(id: "weather", name: "Tout le ciel", tagline: "Météo, détails, pluie, vent, soleil et lune.", symbol: "cloud.sun.fill",
                   themeID: .aurora, accentHex: "3366FF", kinds: [.weather, .weatherDetails, .rainNext, .windUV, .sunCycle, .moonPhase]),
        WidgetPack(id: "dates", name: "Dates importantes", tagline: "Anniversaires, comptes à rebours et jours fériés.", symbol: "gift.fill",
                   themeID: .typography, accentHex: "F2588F", kinds: [.birthday, .countdown, .holiday, .calendar, .ageProgress, .note]),
        WidgetPack(id: "car", name: "Ma voiture", tagline: "Coût, entretien, kilométrage et carburant.", symbol: "car.fill",
                   themeID: .dark, accentHex: "6B7280", kinds: [.carCost, .nextService, .mileage, .fuelStats, .carDeadlines, .weather]),
        WidgetPack(id: "gym", name: "Salle de sport", tagline: "Séance, volume, records et mois d'entraînement.", symbol: "dumbbell.fill",
                   themeID: .futuristic, accentHex: "FF6B57", kinds: [.todaysWorkout, .weeklyVolume, .personalRecords, .workoutMonth, .caloriesBurned, .nextSet]),
        WidgetPack(id: "elegant", name: "Élégance", tagline: "Serif et reflets dorés pour l'agenda et la journée.", symbol: "crown.fill",
                   themeID: .elegant, accentHex: "F2A33A", kinds: [.clock, .calendar, .upNext, .weather, .note, .moonPhase]),
        WidgetPack(id: "neon", name: "Néon", tagline: "Heure, fuseaux, focus et crypto en cyan électrique.", symbol: "bolt.fill",
                   themeID: .futuristic, accentHex: "3366FF", kinds: [.clock, .worldClock, .focus, .crypto, .progress, .weather]),
        WidgetPack(id: "retro", name: "Rétro", tagline: "Papier chaud et typo ronde, pour tous les jours.", symbol: "camera.macro",
                   themeID: .retro, accentHex: "F2A33A", kinds: [.calendar, .progress, .countdown, .habits, .note, .weather]),
        WidgetPack(id: "vivid", name: "Couleurs vives", tagline: "Ta couleur en plein fond, sur six widgets.", symbol: "paintpalette.fill",
                   themeID: .colorful, accentHex: "F2588F", kinds: [.now, .weather, .hydration, .habitStreak, .budgetLeft, .trainingStreak]),
        WidgetPack(id: "evening", name: "Bonne soirée", tagline: "La lune, la journée qui s'achève et tes habitudes.", symbol: "moon.stars.fill",
                   themeID: .glass, accentHex: "8C6CFF", kinds: [.moonPhase, .habitStreak, .progress, .weather, .note, .countdown]),
        WidgetPack(id: "crypto", name: "Crypto", tagline: "Bitcoin, marché, portefeuille et plus forte variation.", symbol: "bitcoinsign.circle.fill",
                   themeID: .digital, accentHex: "2F8F7A", kinds: [.crypto, .marketOverview, .portfolio, .topMover, .watchlist, .allocation]),
    ]

    static func pack(_ id: String) -> WidgetPack? {
        all.first { $0.id == id }
    }
}
