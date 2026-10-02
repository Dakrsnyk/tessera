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
        WidgetPack(id: "morning", name: tr("Bien démarrer"), tagline: tr("Météo, agenda, priorités et eau, dès le réveil."), symbol: "sunrise.fill",
                   themeID: .glass, accentHex: "8C6CFF", kinds: [.now, .morning, .weather, .upNext, .priorities, .hydration]),
        WidgetPack(id: "student", name: tr("Étudiant"), tagline: tr("Cours, examens, devoirs et fiches de révision."), symbol: "graduationcap.fill",
                   themeID: .minimal, accentHex: "F2588F", kinds: [.nextClass, .nextExam, .assignments, .timetable, .flashcard, .semesterProgress]),
        WidgetPack(id: "athlete", name: tr("Sportif"), tagline: tr("Séance, séries, repos, calories et protéines."), symbol: "figure.strengthtraining.traditional",
                   themeID: .dark, accentHex: "FF6B57", kinds: [.todaysWorkout, .nextSet, .restTimer, .trainingStreak, .caloriesLeft, .proteinLeft]),
        WidgetPack(id: "founder", name: tr("Entrepreneur"), tagline: tr("Chiffre d'affaires, objectif, bénéfice et MRR."), symbol: "briefcase.fill",
                   themeID: .elegant, accentHex: "F2A33A", kinds: [.revenueGoal, .revenueToday, .profit, .businessKPIs, .mrr, .businessDashboard]),
        WidgetPack(id: "budget", name: tr("Budget serré"), tagline: tr("Reste du mois, dépenses rapides, factures et épargne."), symbol: "creditcard.fill",
                   themeID: .light, accentHex: "2F8F7A", kinds: [.budgetLeft, .quickExpense, .billsUpcoming, .savingsGoal, .subscriptions, .moneyDashboard]),
        WidgetPack(id: "traveler", name: tr("Voyageur"), tagline: tr("Départ, vol, hôtel, météo, heure et devise sur place."), symbol: "airplane",
                   themeID: .aurora, accentHex: "3366FF", kinds: [.tripCountdown, .flight, .hotel, .destinationWeather, .localTime, .currency]),
        WidgetPack(id: "investor", name: tr("Investisseur"), tagline: tr("Portefeuille, répartition, cours et chiffres officiels."), symbol: "chart.line.uptrend.xyaxis",
                   themeID: .futuristic, accentHex: "3366FF", kinds: [.portfolio, .allocation, .watchlist, .marketOverview, .companySnapshot, .companyCompare]),
        WidgetPack(id: "calm", name: tr("Minimal"), tagline: tr("L'essentiel en noir et blanc, sans rien de plus."), symbol: "circle.lefthalf.filled",
                   themeID: .monochrome, accentHex: "6B7280", kinds: [.clock, .calendar, .progress, .weekView, .moonPhase, .note]),
        WidgetPack(id: "essentials", name: tr("L'essentiel"), tagline: tr("Heure, météo, tâches, habitudes et dates, gratuitement."), symbol: "star.fill",
                   themeID: .minimal, accentHex: "2F8F7A", kinds: [.clock, .weather, .tasks, .habits, .calendar, .countdown]),
        WidgetPack(id: "nutrition", name: tr("Nutrition complète"), tagline: tr("Calories, macros, protéines, repas et semaine."), symbol: "fork.knife",
                   themeID: .glass, accentHex: "2F8F7A", kinds: [.caloriesLeft, .macros, .proteinLeft, .mealsToday, .nutritionWeek, .nextMeal]),
        WidgetPack(id: "habits", name: tr("Bonnes habitudes"), tagline: tr("Routine, eau, séries, taux de réussite et rythme du jour."), symbol: "leaf.fill",
                   themeID: .minimal, accentHex: "8C6CFF", kinds: [.habits, .hydration, .habitStreak, .habitRate, .sunCycle, .moonPhase]),
        WidgetPack(id: "focus", name: tr("Concentration"), tagline: tr("Focus, travail profond, priorités et échéances."), symbol: "scope",
                   themeID: .futuristic, accentHex: "3366FF", kinds: [.focus, .deepWork, .priorities, .deadline, .project, .tasks]),
        WidgetPack(id: "weather", name: tr("Tout le ciel"), tagline: tr("Météo, détails, pluie, vent, soleil et lune."), symbol: "cloud.sun.fill",
                   themeID: .aurora, accentHex: "3366FF", kinds: [.weather, .weatherDetails, .rainNext, .windUV, .sunCycle, .moonPhase]),
        WidgetPack(id: "dates", name: tr("Dates importantes"), tagline: tr("Anniversaires, comptes à rebours et jours fériés."), symbol: "gift.fill",
                   themeID: .typography, accentHex: "F2588F", kinds: [.birthday, .countdown, .holiday, .calendar, .ageProgress, .note]),
        WidgetPack(id: "car", name: tr("Ma voiture"), tagline: tr("Coût, entretien, kilométrage et carburant."), symbol: "car.fill",
                   themeID: .dark, accentHex: "6B7280", kinds: [.carCost, .nextService, .mileage, .fuelStats, .carDeadlines, .weather]),
        WidgetPack(id: "gym", name: tr("Salle de sport"), tagline: tr("Séance, volume, records et mois d'entraînement."), symbol: "dumbbell.fill",
                   themeID: .futuristic, accentHex: "FF6B57", kinds: [.todaysWorkout, .weeklyVolume, .personalRecords, .workoutMonth, .caloriesBurned, .nextSet]),
        WidgetPack(id: "elegant", name: tr("Élégance"), tagline: tr("Serif et reflets dorés pour l'agenda et la journée."), symbol: "crown.fill",
                   themeID: .elegant, accentHex: "F2A33A", kinds: [.clock, .calendar, .upNext, .weather, .note, .moonPhase]),
        WidgetPack(id: "neon", name: tr("Néon"), tagline: tr("Heure, fuseaux, focus et crypto en cyan électrique."), symbol: "bolt.fill",
                   themeID: .futuristic, accentHex: "3366FF", kinds: [.clock, .worldClock, .focus, .crypto, .progress, .weather]),
        WidgetPack(id: "retro", name: tr("Rétro"), tagline: tr("Papier chaud et typo ronde, pour tous les jours."), symbol: "camera.macro",
                   themeID: .retro, accentHex: "F2A33A", kinds: [.calendar, .progress, .countdown, .habits, .note, .weather]),
        WidgetPack(id: "vivid", name: tr("Couleurs vives"), tagline: tr("Ta couleur en plein fond, sur six widgets."), symbol: "paintpalette.fill",
                   themeID: .colorful, accentHex: "F2588F", kinds: [.now, .weather, .hydration, .habitStreak, .budgetLeft, .trainingStreak]),
        WidgetPack(id: "evening", name: tr("Bonne soirée"), tagline: tr("La lune, la journée qui s'achève et tes habitudes."), symbol: "moon.stars.fill",
                   themeID: .glass, accentHex: "8C6CFF", kinds: [.moonPhase, .habitStreak, .progress, .weather, .note, .countdown]),
        WidgetPack(id: "crypto", name: tr("Crypto"), tagline: tr("Bitcoin, marché, portefeuille et plus forte variation."), symbol: "bitcoinsign.circle.fill",
                   themeID: .digital, accentHex: "2F8F7A", kinds: [.crypto, .marketOverview, .portfolio, .topMover, .watchlist, .allocation]),
    ]

    static func pack(_ id: String) -> WidgetPack? {
        all.first { $0.id == id }
    }
}
