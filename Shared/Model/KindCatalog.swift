import Foundation
import WidgetKit

struct KindInfo {
    let kind: WidgetKind
    let title: String
    let summary: String
    let category: WidgetCategory
    let symbol: String
    let isPremium: Bool
    let families: [WidgetFamily]
    let keywords: [String]
    var space: Space?
    var isNew = false
    var isInteractive = false
}

private let sml: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
private let sm: [WidgetFamily] = [.systemSmall, .systemMedium]
private let ml: [WidgetFamily] = [.systemMedium, .systemLarge]
private let circle: WidgetFamily = .accessoryCircular
private let rect: WidgetFamily = .accessoryRectangular
private let inline: WidgetFamily = .accessoryInline

/// Metadata for every widget kind, grouped by category.
enum KindCatalog {
    static func info(_ kind: WidgetKind) -> KindInfo {
        table[kind] ?? KindInfo(kind: kind, title: kind.rawValue, summary: "", category: .time, symbol: "square", isPremium: true, families: sml, keywords: [])
    }

    private static let table: [WidgetKind: KindInfo] = {
        var map: [WidgetKind: KindInfo] = [:]
        for info in time + weather + productivity + wellbeing + nutrition + fitness + finance + investing + business + markets + student + travel + car + dashboards {
            map[info.kind] = info
        }
        return map
    }()

    private static let time: [KindInfo] = [
        KindInfo(kind: .clock, title: "Horloge", summary: "L'heure et la date, sans rien de plus.", category: .time, symbol: "clock", isPremium: false, families: sm, keywords: ["heure", "time", "minimal", "date"]),
        KindInfo(kind: .calendar, title: "Calendrier", summary: "Le mois en un coup d'œil, aujourd'hui mis en avant.", category: .time, symbol: "calendar", isPremium: false, families: sml, keywords: ["mois", "date", "jour", "agenda"]),
        KindInfo(kind: .worldClock, title: "Fuseaux horaires", summary: "L'heure de tes villes, avec le décalage horaire.", category: .time, symbol: "globe", isPremium: true, families: sm, keywords: ["monde", "fuseau", "voyage", "ville"]),
        KindInfo(kind: .progress, title: "Progression", summary: "Où en est ta journée, ta semaine, ton mois ou ton année.", category: .time, symbol: "chart.bar.fill", isPremium: false, families: sm + [circle, rect, inline], keywords: ["année", "mois", "semaine", "journée", "pourcentage", "year progress"]),
        KindInfo(kind: .countdown, title: "Compte à rebours", summary: "Les jours avant un événement, ou depuis un moment important.", category: .time, symbol: "hourglass", isPremium: false, families: sm + [circle, rect, inline], keywords: ["jours", "days until", "days since", "événement", "depuis"]),
        KindInfo(kind: .yearDots, title: "L'année en points", summary: "Chaque jour de l'année est un point. Regarde-la avancer.", category: .time, symbol: "circle.grid.3x3.fill", isPremium: true, families: sml, keywords: ["année", "points", "jours"]),
        KindInfo(kind: .ageProgress, title: "Mon âge", summary: "Ton âge au jour près et la route vers ton prochain anniversaire.", category: .time, symbol: "person.crop.circle.badge.clock", isPremium: true, families: sm + [circle], keywords: ["âge", "anniversaire", "vie", "age progress"], space: .life, isNew: true),
        KindInfo(kind: .birthday, title: "Mon anniversaire", summary: "Le compte à rebours jusqu'à ton prochain anniversaire.", category: .time, symbol: "gift", isPremium: false, families: sm + [circle, inline], keywords: ["anniversaire", "fête", "birthday"], space: .life, isNew: true),
        KindInfo(kind: .weekView, title: "Ma semaine", summary: "Les 7 jours de la semaine, le numéro de semaine et sa progression.", category: .time, symbol: "calendar.day.timeline.left", isPremium: false, families: sm, keywords: ["semaine", "week", "jours"], isNew: true),
        KindInfo(kind: .holiday, title: "Prochain jour férié", summary: "Le prochain congé férié au Québec, au Canada ou en France.", category: .time, symbol: "party.popper", isPremium: false, families: sm + [inline], keywords: ["férié", "congé", "vacances", "holiday"], space: .life, isNew: true),
        KindInfo(kind: .moonPhase, title: "Phase de la lune", summary: "La lune de ce soir, son éclairage et la prochaine pleine lune.", category: .time, symbol: "moon.stars", isPremium: false, families: sm + [circle], keywords: ["lune", "moon", "pleine lune", "astronomie"], isNew: true),
    ]

    private static let weather: [KindInfo] = [
        KindInfo(kind: .weather, title: "Météo", summary: "La température et les prévisions de ta ville.", category: .weather, symbol: "cloud.sun.fill", isPremium: false, families: sml + [circle, rect, inline], keywords: ["température", "pluie", "prévisions", "soleil"]),
        KindInfo(kind: .sunCycle, title: "Soleil", summary: "Lever, coucher, durée du jour et position du soleil en ce moment.", category: .weather, symbol: "sunrise", isPremium: false, families: sm, keywords: ["lever", "coucher", "sunrise", "sunset", "jour"], isNew: true),
        KindInfo(kind: .rainNext, title: "Pluie", summary: "Les risques de pluie heure par heure pour les 12 prochaines heures.", category: .weather, symbol: "cloud.rain", isPremium: true, families: sm + [rect], keywords: ["pluie", "parapluie", "précipitations"], isNew: true),
        KindInfo(kind: .windUV, title: "Vent et UV", summary: "La vitesse et la direction du vent, et l'indice UV.", category: .weather, symbol: "wind", isPremium: true, families: sm, keywords: ["vent", "uv", "soleil", "rafales"], isNew: true),
        KindInfo(kind: .weatherDetails, title: "Météo détaillée", summary: "Ressenti, humidité, vent, UV et pluie réunis.", category: .weather, symbol: "thermometer.medium", isPremium: true, families: sml, keywords: ["ressenti", "humidité", "détails"], isNew: true),
        KindInfo(kind: .weeklyForecast, title: "Prévisions 7 jours", summary: "La semaine à venir, avec minimales et maximales.", category: .weather, symbol: "calendar.badge.clock", isPremium: true, families: ml, keywords: ["semaine", "prévisions", "7 jours"], isNew: true),
    ]

    private static let productivity: [KindInfo] = [
        KindInfo(kind: .tasks, title: "Tâches", summary: "Ta liste du jour, que tu coches directement sur l'écran d'accueil.", category: .productivity, symbol: "checklist", isPremium: false, families: sml + [rect], keywords: ["todo", "to-do", "liste", "à faire"], space: .today, isInteractive: true),
        KindInfo(kind: .habits, title: "Habitudes", summary: "Tes habitudes de la semaine, validées d'une touche.", category: .productivity, symbol: "repeat", isPremium: false, families: sml, keywords: ["routine", "streak", "objectif", "série"], space: .habits, isInteractive: true),
        KindInfo(kind: .focus, title: "Focus", summary: "Un minuteur de concentration qui défile en direct.", category: .productivity, symbol: "timer", isPremium: true, families: sm + [circle, rect], keywords: ["pomodoro", "minuteur", "timer", "concentration"], isInteractive: true),
        KindInfo(kind: .upNext, title: "À venir", summary: "Tes prochains rendez-vous, tirés de ton calendrier.", category: .productivity, symbol: "calendar.badge.clock", isPremium: true, families: sml + [rect], keywords: ["événements", "agenda", "rendez-vous", "réunion"]),
        KindInfo(kind: .note, title: "Note", summary: "Un mot, un rappel ou une citation, toujours sous les yeux.", category: .productivity, symbol: "note.text", isPremium: false, families: sml, keywords: ["citation", "mémo", "texte", "rappel"]),
        KindInfo(kind: .priorities, title: "Mes 3 priorités", summary: "Les trois choses qui comptent aujourd'hui, cochées depuis l'écran d'accueil.", category: .productivity, symbol: "3.circle", isPremium: false, families: sm, keywords: ["priorité", "top 3", "important", "aujourd'hui"], space: .today, isNew: true, isInteractive: true),
        KindInfo(kind: .project, title: "Projet", summary: "L'avancement d'un projet, ses tâches restantes et son échéance.", category: .productivity, symbol: "folder", isPremium: true, families: sml, keywords: ["projet", "avancement", "tâches", "deadline"], space: .projects, isNew: true, isInteractive: true),
        KindInfo(kind: .deadline, title: "Échéance", summary: "Le temps restant avant une échéance, qui défile en direct.", category: .productivity, symbol: "flag.checkered", isPremium: true, families: sm + [rect, inline], keywords: ["deadline", "échéance", "rendu", "heures"], space: .projects, isNew: true),
        KindInfo(kind: .deepWork, title: "Deep work", summary: "Ton temps de concentration du jour et de la semaine, face à ton objectif.", category: .productivity, symbol: "brain.head.profile", isPremium: true, families: sm, keywords: ["concentration", "deep work", "focus", "heures"], space: .projects, isNew: true),
        KindInfo(kind: .counter, title: "Compteur", summary: "Compte n'importe quoi d'une touche : cafés, pompes, pages…", category: .productivity, symbol: "plus.forwardslash.minus", isPremium: false, families: sm + [circle], keywords: ["compteur", "tally", "compter", "clic"], space: .today, isNew: true, isInteractive: true),
    ]

    private static let wellbeing: [KindInfo] = [
        KindInfo(kind: .hydration, title: "Hydratation", summary: "Tes verres d'eau de la journée, ajoutés d'une touche.", category: .wellbeing, symbol: "drop.fill", isPremium: false, families: sm + [circle], keywords: ["eau", "boire", "verres"], space: .today, isInteractive: true),
        KindInfo(kind: .habitStreak, title: "Série d'habitude", summary: "La série en cours d'une habitude et ses 30 derniers jours.", category: .wellbeing, symbol: "flame", isPremium: false, families: sm + [circle], keywords: ["streak", "série", "habitude"], space: .habits, isNew: true),
        KindInfo(kind: .habitWeek, title: "Semaine d'habitudes", summary: "Toutes tes habitudes sur 7 jours, en grille.", category: .wellbeing, symbol: "square.grid.3x3", isPremium: true, families: ml, keywords: ["grille", "semaine", "habitudes"], space: .habits, isNew: true),
        KindInfo(kind: .habitRate, title: "Taux de réussite", summary: "Le pourcentage d'habitudes tenues ce mois-ci.", category: .wellbeing, symbol: "percent", isPremium: true, families: sm, keywords: ["taux", "réussite", "mois", "habitudes"], space: .habits, isNew: true),
    ]

    private static let nutrition: [KindInfo] = [
        KindInfo(kind: .caloriesLeft, title: "Calories restantes", summary: "Ce qu'il te reste à manger aujourd'hui, avec une jauge.", category: .nutrition, symbol: "flame.fill", isPremium: false, families: sm + [circle, rect], keywords: ["calories", "kcal", "restantes", "régime"], space: .nutrition, isNew: true),
        KindInfo(kind: .macros, title: "Macros", summary: "Protéines, glucides et lipides face à tes objectifs.", category: .nutrition, symbol: "chart.bar.xaxis", isPremium: true, families: sm, keywords: ["macros", "protéines", "glucides", "lipides"], space: .nutrition, isNew: true),
        KindInfo(kind: .proteinLeft, title: "Protéines", summary: "Les grammes de protéines qu'il te reste pour la journée.", category: .nutrition, symbol: "bolt.heart", isPremium: true, families: sm + [circle], keywords: ["protéines", "muscle", "grammes"], space: .nutrition, isNew: true),
        KindInfo(kind: .mealsToday, title: "Repas du jour", summary: "Petit-déjeuner, dîner, souper et collations, avec leurs calories.", category: .nutrition, symbol: "fork.knife", isPremium: true, families: ml, keywords: ["repas", "journal", "aliments"], space: .nutrition, isNew: true),
        KindInfo(kind: .nutritionWeek, title: "Semaine nutrition", summary: "Tes calories des 7 derniers jours et ta moyenne.", category: .nutrition, symbol: "chart.bar", isPremium: true, families: ml, keywords: ["semaine", "moyenne", "calories"], space: .nutrition, isNew: true),
        KindInfo(kind: .nutritionStreak, title: "Série de suivi", summary: "Les jours d'affilée où tu as noté tes repas.", category: .nutrition, symbol: "flame", isPremium: true, families: sm, keywords: ["streak", "série", "suivi"], space: .nutrition, isNew: true),
        KindInfo(kind: .quickFood, title: "Ajout rapide", summary: "Tes aliments favoris, ajoutés à ton journal d'une touche.", category: .nutrition, symbol: "plus.circle", isPremium: true, families: sm, keywords: ["rapide", "favoris", "ajouter"], space: .nutrition, isNew: true, isInteractive: true),
        KindInfo(kind: .nextMeal, title: "Prochain repas", summary: "Ce qu'il te reste pour ton prochain repas, selon l'heure.", category: .nutrition, symbol: "clock", isPremium: true, families: sm, keywords: ["repas", "souper", "dîner", "suivant"], space: .nutrition, isNew: true),
    ]

    private static let fitness: [KindInfo] = [
        KindInfo(kind: .todaysWorkout, title: "Séance du jour", summary: "Ta séance prévue aujourd'hui et ses exercices.", category: .fitness, symbol: "figure.strengthtraining.traditional", isPremium: false, families: sml, keywords: ["séance", "entraînement", "workout", "programme"], space: .fitness, isNew: true, isInteractive: true),
        KindInfo(kind: .nextSet, title: "Prochaine série", summary: "Ta série suivante : touche « Série faite » et le repos démarre.", category: .fitness, symbol: "arrow.forward.circle", isPremium: true, families: sm, keywords: ["série", "set", "répétitions", "poids"], space: .fitness, isNew: true, isInteractive: true),
        KindInfo(kind: .restTimer, title: "Repos", summary: "Le minuteur de repos entre deux séries, en direct.", category: .fitness, symbol: "stopwatch", isPremium: true, families: sm + [circle, rect], keywords: ["repos", "rest timer", "minuteur"], space: .fitness, isNew: true, isInteractive: true),
        KindInfo(kind: .weeklyVolume, title: "Volume de la semaine", summary: "Le poids total soulevé chaque jour de la semaine.", category: .fitness, symbol: "chart.bar.fill", isPremium: true, families: ml, keywords: ["volume", "tonnage", "semaine"], space: .fitness, isNew: true),
        KindInfo(kind: .personalRecords, title: "Records", summary: "Tes meilleures charges par exercice.", category: .fitness, symbol: "trophy", isPremium: true, families: sml, keywords: ["record", "pr", "max"], space: .fitness, isNew: true),
        KindInfo(kind: .trainingStreak, title: "Régularité", summary: "Tes séances de la semaine face à ton objectif, et ta série.", category: .fitness, symbol: "flame.fill", isPremium: false, families: sm + [circle], keywords: ["streak", "séances", "semaine", "objectif"], space: .fitness, isNew: true),
        KindInfo(kind: .caloriesBurned, title: "Calories brûlées", summary: "Une estimation des calories dépensées pendant tes séances.", category: .fitness, symbol: "bolt.fill", isPremium: true, families: sm, keywords: ["calories", "dépense", "brûlées"], space: .fitness, isNew: true),
        KindInfo(kind: .workoutMonth, title: "Mois d'entraînement", summary: "Tes jours d'entraînement du mois, en calendrier.", category: .fitness, symbol: "calendar", isPremium: true, families: sm, keywords: ["mois", "calendrier", "séances"], space: .fitness, isNew: true),
    ]

    private static let finance: [KindInfo] = [
        KindInfo(kind: .moneyFlow, title: "Flux d'argent", summary: "Ce que tu gagnes et dépenses, calculé au fil du jour.", category: .finance, symbol: "dollarsign.arrow.circlepath", isPremium: true, families: sml, keywords: ["argent", "revenus", "dépenses", "salaire"], space: .budget),
        KindInfo(kind: .budgetLeft, title: "Reste à dépenser", summary: "L'argent qu'il te reste ce mois-ci, et par jour.", category: .finance, symbol: "creditcard", isPremium: false, families: sm + [rect, inline], keywords: ["budget", "restant", "mois", "remaining"], space: .budget, isNew: true),
        KindInfo(kind: .spendingByCategory, title: "Dépenses par catégorie", summary: "Où part ton argent ce mois-ci.", category: .finance, symbol: "chart.bar.doc.horizontal", isPremium: true, families: ml, keywords: ["catégories", "dépenses", "mois"], space: .budget, isNew: true),
        KindInfo(kind: .billsUpcoming, title: "Factures à venir", summary: "Tes prochains prélèvements et le nombre de jours avant chacun.", category: .finance, symbol: "doc.text", isPremium: true, families: sml, keywords: ["factures", "prélèvements", "loyer"], space: .budget, isNew: true),
        KindInfo(kind: .savingsGoal, title: "Objectif d'épargne", summary: "Où tu en es sur ton objectif d'épargne.", category: .finance, symbol: "banknote", isPremium: false, families: sm + [circle], keywords: ["épargne", "objectif", "économies"], space: .budget, isNew: true),
        KindInfo(kind: .netWorth, title: "Valeur nette", summary: "Tes avoirs moins tes dettes, et leur évolution.", category: .finance, symbol: "chart.line.uptrend.xyaxis", isPremium: true, families: sm, keywords: ["patrimoine", "net worth", "valeur"], space: .budget, isNew: true),
        KindInfo(kind: .subscriptions, title: "Abonnements", summary: "Le total mensuel de tes abonnements, et lesquels coûtent le plus.", category: .finance, symbol: "repeat.circle", isPremium: true, families: sml, keywords: ["abonnements", "netflix", "spotify", "mensuel"], space: .budget, isNew: true),
        KindInfo(kind: .quickExpense, title: "Dépense rapide", summary: "Tes dépenses habituelles ajoutées d'une touche, et le total du jour.", category: .finance, symbol: "cart.badge.plus", isPremium: true, families: sm, keywords: ["dépense", "rapide", "café"], space: .budget, isNew: true, isInteractive: true),
    ]

    private static let investing: [KindInfo] = [
        KindInfo(kind: .crypto, title: "Crypto", summary: "Le cours d'une crypto et sa courbe sur 7 jours.", category: .investing, symbol: "bitcoinsign.circle", isPremium: true, families: sm + [rect], keywords: ["bitcoin", "ethereum", "btc", "cours"]),
        KindInfo(kind: .portfolio, title: "Portefeuille", summary: "La valeur de ton portefeuille et son gain ou sa perte.", category: .investing, symbol: "chart.pie.fill", isPremium: true, families: sml, keywords: ["portefeuille", "actions", "etf", "investissement"], space: .investing, isNew: true),
        KindInfo(kind: .allocation, title: "Répartition", summary: "Actions, ETF, crypto et cash, en anneau.", category: .investing, symbol: "chart.pie", isPremium: true, families: sm, keywords: ["allocation", "répartition", "diversification"], space: .investing, isNew: true),
        KindInfo(kind: .topMover, title: "Plus forte variation", summary: "L'actif de ton portefeuille qui bouge le plus aujourd'hui.", category: .investing, symbol: "arrow.up.arrow.down", isPremium: true, families: sm, keywords: ["variation", "hausse", "baisse", "top mover"], space: .investing, isNew: true),
        KindInfo(kind: .watchlist, title: "Liste de suivi", summary: "Plusieurs cryptos et leur variation sur 24 h.", category: .investing, symbol: "list.bullet.rectangle", isPremium: false, families: sml, keywords: ["watchlist", "suivi", "crypto", "cours"], space: .investing, isNew: true),
        KindInfo(kind: .marketOverview, title: "Marché crypto", summary: "La capitalisation totale du marché et la domination du bitcoin.", category: .investing, symbol: "globe.americas", isPremium: true, families: sm, keywords: ["marché", "capitalisation", "domination"], isNew: true),
    ]

    private static let business: [KindInfo] = [
        KindInfo(kind: .revenueGoal, title: "Objectif de CA", summary: "Le chiffre d'affaires du mois face à ton objectif.", category: .business, symbol: "target", isPremium: false, families: sm + [circle, rect], keywords: ["chiffre d'affaires", "ca", "objectif", "ventes"], space: .business, isNew: true),
        KindInfo(kind: .revenueTrend, title: "Tendance du CA", summary: "Tes ventes des 30 derniers jours et l'évolution par rapport au mois dernier.", category: .business, symbol: "chart.xyaxis.line", isPremium: true, families: ml, keywords: ["tendance", "ventes", "croissance"], space: .business, isNew: true),
        KindInfo(kind: .profit, title: "Bénéfice", summary: "Le bénéfice et la marge du mois.", category: .business, symbol: "dollarsign.circle", isPremium: true, families: sm, keywords: ["bénéfice", "marge", "profit"], space: .business, isNew: true),
        KindInfo(kind: .businessKPIs, title: "Indicateurs", summary: "Commandes, panier moyen, nouveaux clients et conversion.", category: .business, symbol: "square.grid.2x2", isPremium: true, families: sm, keywords: ["kpi", "commandes", "panier moyen", "conversion"], space: .business, isNew: true),
        KindInfo(kind: .mrr, title: "MRR", summary: "Revenu récurrent mensuel, annuel et croissance des abonnés.", category: .business, symbol: "arrow.triangle.2.circlepath", isPremium: true, families: sm, keywords: ["mrr", "arr", "saas", "abonnés"], space: .business, isNew: true),
        KindInfo(kind: .revenueToday, title: "Ventes du jour", summary: "Le CA du jour comparé au même jour la semaine dernière.", category: .business, symbol: "cart", isPremium: true, families: sm + [rect], keywords: ["aujourd'hui", "ventes", "jour"], space: .business, isNew: true),
        KindInfo(kind: .businessDashboard, title: "Tableau business", summary: "CA, bénéfice, commandes et tendance réunis.", category: .business, symbol: "briefcase.fill", isPremium: true, families: ml, keywords: ["dashboard", "entreprise", "résumé"], space: .business, isNew: true),
    ]

    private static let markets: [KindInfo] = [
        KindInfo(kind: .companySnapshot, title: "Fiche entreprise", summary: "Chiffre d'affaires, bénéfice, marge et croissance d'une société cotée.", category: .markets, symbol: "building.2", isPremium: true, families: sm, keywords: ["apple", "tesla", "nvidia", "entreprise", "résultats"], space: .markets, isNew: true),
        KindInfo(kind: .companyRevenue, title: "Revenus d'entreprise", summary: "Le chiffre d'affaires trimestriel d'une société, en barres.", category: .markets, symbol: "chart.bar.fill", isPremium: true, families: ml, keywords: ["revenus", "trimestre", "croissance"], space: .markets, isNew: true),
        KindInfo(kind: .companyStock, title: "Action", summary: "Le cours de l'action et la capitalisation (clé de données requise).", category: .markets, symbol: "chart.line.uptrend.xyaxis", isPremium: true, families: sm, keywords: ["action", "bourse", "cours", "capitalisation"], space: .markets, isNew: true),
        KindInfo(kind: .companyCompare, title: "Comparer", summary: "Le chiffre d'affaires annuel de plusieurs sociétés côte à côte.", category: .markets, symbol: "square.split.2x1", isPremium: true, families: ml, keywords: ["comparer", "concurrents"], space: .markets, isNew: true),
    ]

    private static let student: [KindInfo] = [
        KindInfo(kind: .nextClass, title: "Prochain cours", summary: "Ton prochain cours, l'heure et la salle.", category: .student, symbol: "book", isPremium: false, families: sm + [rect, inline], keywords: ["cours", "classe", "salle", "horaire"], space: .student, isNew: true),
        KindInfo(kind: .nextExam, title: "Prochain examen", summary: "Le compte à rebours jusqu'à ton prochain examen.", category: .student, symbol: "pencil.and.list.clipboard", isPremium: false, families: sm + [circle, rect], keywords: ["examen", "partiel", "exam"], space: .student, isNew: true),
        KindInfo(kind: .assignments, title: "Devoirs", summary: "Tes devoirs à rendre, par date.", category: .student, symbol: "tray.full", isPremium: true, families: sml, keywords: ["devoirs", "travaux", "rendre"], space: .student, isNew: true, isInteractive: true),
        KindInfo(kind: .gradeAverage, title: "Moyenne", summary: "Ta moyenne pondérée et celle de chaque cours.", category: .student, symbol: "graduationcap", isPremium: true, families: sm, keywords: ["notes", "moyenne", "bulletin"], space: .student, isNew: true),
        KindInfo(kind: .semesterProgress, title: "Session", summary: "L'avancement de ta session, en semaines.", category: .student, symbol: "calendar.badge.checkmark", isPremium: false, families: sm + [circle], keywords: ["session", "semestre", "trimestre"], space: .student, isNew: true),
        KindInfo(kind: .flashcard, title: "Flashcard", summary: "Révise sur l'écran d'accueil : retourne la carte, puis dis si tu savais.", category: .student, symbol: "rectangle.on.rectangle.angled", isPremium: true, families: sm, keywords: ["flashcards", "réviser", "mémoriser"], space: .student, isNew: true, isInteractive: true),
        KindInfo(kind: .studyHours, title: "Heures d'étude", summary: "Tes heures d'étude de la semaine face à ton objectif.", category: .student, symbol: "clock.arrow.circlepath", isPremium: true, families: sm, keywords: ["étude", "heures", "révision"], space: .student, isNew: true),
        KindInfo(kind: .timetable, title: "Horaire du jour", summary: "Tous tes cours de la journée.", category: .student, symbol: "list.bullet.below.rectangle", isPremium: true, families: ml, keywords: ["horaire", "emploi du temps", "cours"], space: .student, isNew: true),
    ]

    private static let travel: [KindInfo] = [
        KindInfo(kind: .tripCountdown, title: "Départ en voyage", summary: "Les jours avant ton prochain voyage.", category: .travel, symbol: "airplane.departure", isPremium: false, families: sm + [circle, inline], keywords: ["voyage", "vacances", "départ"], space: .travel, isNew: true),
        KindInfo(kind: .flight, title: "Vol", summary: "Ton vol : numéro, heure, terminal et temps avant le départ.", category: .travel, symbol: "airplane", isPremium: true, families: sm + [rect], keywords: ["vol", "avion", "porte", "terminal"], space: .travel, isNew: true),
        KindInfo(kind: .hotel, title: "Hôtel", summary: "Ton hôtel, l'adresse et les dates d'arrivée et de départ.", category: .travel, symbol: "bed.double", isPremium: true, families: sm, keywords: ["hôtel", "logement", "check-in"], space: .travel, isNew: true),
        KindInfo(kind: .destinationWeather, title: "Météo à destination", summary: "Le temps qu'il fait là où tu vas.", category: .travel, symbol: "cloud.sun", isPremium: true, families: sm, keywords: ["météo", "destination"], space: .travel, isNew: true),
        KindInfo(kind: .localTime, title: "Heure à destination", summary: "L'heure là-bas et le décalage avec chez toi.", category: .travel, symbol: "clock.badge.questionmark", isPremium: false, families: sm + [inline], keywords: ["heure", "décalage", "fuseau"], space: .travel, isNew: true),
        KindInfo(kind: .currency, title: "Taux de change", summary: "Le taux de change vers la devise de ta destination, avec des conversions toutes faites.", category: .travel, symbol: "arrow.left.arrow.right.circle", isPremium: true, families: sm, keywords: ["devise", "change", "euro", "dollar"], space: .travel, isNew: true),
        KindInfo(kind: .tripProgress, title: "Voyage en cours", summary: "Le jour de ton voyage et les jours restants.", category: .travel, symbol: "map", isPremium: true, families: sm + [circle], keywords: ["voyage", "jours restants"], space: .travel, isNew: true),
        KindInfo(kind: .nextActivity, title: "Prochaine activité", summary: "La prochaine activité prévue pendant ton voyage.", category: .travel, symbol: "mappin.and.ellipse", isPremium: true, families: sm, keywords: ["activité", "visite", "programme"], space: .travel, isNew: true),
    ]

    private static let car: [KindInfo] = [
        KindInfo(kind: .carCost, title: "Coût de la voiture", summary: "Ce que ta voiture te coûte vraiment par mois, et par kilomètre.", category: .car, symbol: "car.fill", isPremium: true, families: sm, keywords: ["voiture", "coût", "assurance", "essence"], space: .car, isNew: true),
        KindInfo(kind: .nextService, title: "Prochain entretien", summary: "Le prochain entretien et les kilomètres ou jours restants.", category: .car, symbol: "wrench.and.screwdriver", isPremium: false, families: sm + [rect], keywords: ["entretien", "vidange", "huile", "garage"], space: .car, isNew: true),
        KindInfo(kind: .mileage, title: "Kilométrage", summary: "Ton compteur et les kilomètres parcourus ce mois-ci.", category: .car, symbol: "gauge.with.dots.needle.67percent", isPremium: true, families: sm, keywords: ["kilométrage", "km", "odomètre"], space: .car, isNew: true),
        KindInfo(kind: .fuelStats, title: "Carburant", summary: "Consommation moyenne, prix du litre et coût au kilomètre.", category: .car, symbol: "fuelpump", isPremium: true, families: sm, keywords: ["essence", "carburant", "consommation", "plein"], space: .car, isNew: true),
        KindInfo(kind: .carDeadlines, title: "Échéances auto", summary: "Assurance, immatriculation et autres dates à ne pas manquer.", category: .car, symbol: "calendar.badge.exclamationmark", isPremium: true, families: sm, keywords: ["assurance", "immatriculation", "échéance"], space: .car, isNew: true),
    ]

    private static let dashboards: [KindInfo] = [
        KindInfo(kind: .myDay, title: "Ma journée", summary: "Heure, météo, agenda, tâche, calories et compte à rebours dans un seul widget.", category: .dashboards, symbol: "sun.horizon", isPremium: true, families: ml, keywords: ["journée", "résumé", "dashboard", "my day"], isNew: true),
        KindInfo(kind: .now, title: "Maintenant", summary: "Change tout seul selon le moment : météo le matin, tâches la journée, bilan le soir.", category: .dashboards, symbol: "clock.arrow.2.circlepath", isPremium: true, families: sml, keywords: ["contextuel", "matin", "soir", "intelligent"], isNew: true),
        KindInfo(kind: .morning, title: "Bon matin", summary: "Météo, premier rendez-vous, priorités et objectif du jour.", category: .dashboards, symbol: "sunrise.fill", isPremium: true, families: ml, keywords: ["matin", "morning", "réveil"], isNew: true),
        KindInfo(kind: .fitnessDashboard, title: "Tableau fitness", summary: "Séance, régularité, calories et protéines réunies.", category: .dashboards, symbol: "figure.run", isPremium: true, families: ml, keywords: ["fitness", "sport", "dashboard"], space: .fitness, isNew: true),
        KindInfo(kind: .moneyDashboard, title: "Tableau finances", summary: "Budget restant, dépenses, factures et épargne réunis.", category: .dashboards, symbol: "creditcard.and.123", isPremium: true, families: ml, keywords: ["argent", "budget", "dashboard"], space: .budget, isNew: true),
        KindInfo(kind: .studentDashboard, title: "Tableau études", summary: "Cours, examen, devoirs et heures d'étude réunis.", category: .dashboards, symbol: "graduationcap.fill", isPremium: true, families: ml, keywords: ["études", "école", "dashboard"], space: .student, isNew: true),
        KindInfo(kind: .aiSummary, title: "Résumé du jour", summary: "Un résumé écrit de ta journée, tiré uniquement de tes données.", category: .dashboards, symbol: "sparkles", isPremium: true, families: sml, keywords: ["ia", "ai", "résumé", "intelligent"], isNew: true),
        KindInfo(kind: .aiNutrition, title: "Conseil nutrition", summary: "Ce qu'il te reste en calories et en protéines, dit simplement.", category: .dashboards, symbol: "sparkles.rectangle.stack", isPremium: true, families: sm, keywords: ["ia", "nutrition", "analyse"], space: .nutrition, isNew: true),
        KindInfo(kind: .aiFinance, title: "Analyse dépenses", summary: "Tes dépenses comparées à la semaine dernière, par catégorie.", category: .dashboards, symbol: "sparkle.magnifyingglass", isPremium: true, families: sm, keywords: ["ia", "dépenses", "analyse"], space: .budget, isNew: true),
        KindInfo(kind: .aiProductivity, title: "Analyse productivité", summary: "Tes tâches, ta concentration et tes habitudes, analysées.", category: .dashboards, symbol: "wand.and.stars", isPremium: true, families: sm, keywords: ["ia", "productivité", "analyse"], isNew: true),
    ]
}
