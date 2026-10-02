import Foundation
import WidgetKit

/// The mini-apps inside Tessera. Each one feeds a family of widgets.
enum Space: String, CaseIterable, Identifiable, Codable {
    case productivity, habits, nutrition, fitness, budget, investing, business, markets, student, travel, car, life

    var id: String { rawValue }

    var title: String {
        switch self {
        case .productivity: tr("Productivité")
        case .habits: tr("Habitudes")
        case .nutrition: tr("Nutrition")
        case .fitness: tr("Fitness")
        case .budget: tr("Budget")
        case .investing: tr("Placements")
        case .business: tr("Mon entreprise")
        case .markets: tr("Sociétés cotées")
        case .student: tr("Études")
        case .travel: tr("Voyage")
        case .car: tr("Auto")
        case .life: tr("Ma vie")
        }
    }

    var subtitle: String {
        switch self {
        case .productivity: tr("Tâches, priorités, projets, compteurs")
        case .habits: tr("Habitudes et hydratation")
        case .nutrition: tr("Repas, calories et macros")
        case .fitness: tr("Séances, séries et records")
        case .budget: tr("Dépenses, factures et épargne")
        case .investing: tr("Actions, ETF, crypto et cash")
        case .business: tr("Chiffre d'affaires et indicateurs")
        case .markets: tr("Chiffres officiels des sociétés cotées")
        case .student: tr("Cours, examens, notes et fiches")
        case .travel: tr("Vols, hôtels et activités")
        case .car: tr("Pleins, entretiens et coûts")
        case .life: tr("Anniversaire, jours fériés, profil")
        }
    }

    var symbol: String {
        switch self {
        case .productivity: "checklist"
        case .habits: "repeat"
        case .nutrition: "fork.knife"
        case .fitness: "dumbbell.fill"
        case .budget: "creditcard.fill"
        case .investing: "chart.pie.fill"
        case .business: "briefcase.fill"
        case .markets: "building.columns.fill"
        case .student: "graduationcap.fill"
        case .travel: "airplane"
        case .car: "car.fill"
        case .life: "person.crop.circle"
        }
    }

    var colorHex: String {
        switch self {
        case .productivity: "6B7280"
        case .habits: "7FA33A"
        case .nutrition: "F08A24"
        case .fitness: "E5484D"
        case .budget: "2F8F7A"
        case .investing: "8C6CFF"
        case .business: "C28A12"
        case .markets: "3366FF"
        case .student: "D6409F"
        case .travel: "12A4B5"
        case .car: "4B5563"
        case .life: "5B6CFF"
        }
    }
}

struct KindInfo {
    let kind: WidgetKind
    let title: String
    let summary: String
    let category: WidgetCategory
    let symbol: String
    let isPremium: Bool
    let families: [WidgetFamily]
    var keywords: [String] = []
    var space: Space?
    var isNew = false
    var isInteractive = false
}

private let SM: [WidgetFamily] = [.systemSmall, .systemMedium]
private let SML: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
private let ML: [WidgetFamily] = [.systemMedium, .systemLarge]
private let circ: WidgetFamily = .accessoryCircular
private let rect: WidgetFamily = .accessoryRectangular
private let inline: WidgetFamily = .accessoryInline

enum KindCatalog {
    static let all: [KindInfo] = [
        time, weather, productivity, wellbeing, nutrition, fitness, finance,
        investing, business, markets, student, travel, car, dashboards,
    ].flatMap { $0 }

    private static let index: [WidgetKind: KindInfo] = Dictionary(uniqueKeysWithValues: all.map { ($0.kind, $0) })

    static func info(_ kind: WidgetKind) -> KindInfo {
        index[kind] ?? KindInfo(kind: kind, title: kind.rawValue, summary: "", category: .time, symbol: "square", isPremium: true, families: SML)
    }

    // MARK: Temps

    static let time: [KindInfo] = [
        KindInfo(kind: .clock, title: tr("Horloge"), summary: tr("L'heure et la date, sans rien de plus."), category: .time, symbol: "clock", isPremium: false, families: SM, keywords: ["heure", "time", "minimal", "date"]),
        KindInfo(kind: .calendar, title: tr("Calendrier"), summary: tr("Le mois en un coup d'œil, aujourd'hui mis en avant."), category: .time, symbol: "calendar", isPremium: false, families: SML, keywords: ["mois", "date", "jour", "agenda"]),
        KindInfo(kind: .worldClock, title: tr("Fuseaux horaires"), summary: tr("L'heure de tes villes, avec le décalage horaire."), category: .time, symbol: "globe", isPremium: true, families: SM, keywords: ["monde", "fuseau", "voyage", "ville", "heure"]),
        KindInfo(kind: .progress, title: tr("Progression"), summary: tr("Où en est ta journée, ta semaine, ton mois ou ton année."), category: .time, symbol: "chart.bar.fill", isPremium: false, families: SM + [circ, rect, inline], keywords: ["année", "mois", "semaine", "journée", "pourcentage", "year progress"]),
        KindInfo(kind: .countdown, title: tr("Compte à rebours"), summary: tr("Les jours avant un événement, ou depuis un moment important."), category: .time, symbol: "hourglass", isPremium: false, families: SM + [circ, rect, inline], keywords: ["jours", "days until", "days since", "événement", "anniversaire", "depuis"]),
        KindInfo(kind: .yearDots, title: tr("L'année en points"), summary: tr("Chaque jour de l'année est un point. Regarde-la avancer."), category: .time, symbol: "circle.grid.3x3.fill", isPremium: true, families: SML, keywords: ["année", "points", "jours", "calendrier"]),
        KindInfo(kind: .ageProgress, title: tr("Mon âge"), summary: tr("Ton âge à la décimale près et le chemin vers ton prochain anniversaire."), category: .time, symbol: "person.crop.circle.badge.clock", isPremium: true, families: SM, keywords: ["âge", "anniversaire", "vie", "age progress"], space: .life, isNew: true),
        KindInfo(kind: .birthday, title: tr("Anniversaire"), summary: tr("Les jours avant ton prochain anniversaire, chaque année."), category: .time, symbol: "gift", isPremium: false, families: SM + [circ, inline], keywords: ["anniversaire", "fête", "birthday"], space: .life, isNew: true),
        KindInfo(kind: .weekView, title: tr("Ma semaine"), summary: tr("Les sept jours de la semaine, aujourd'hui en avant, avec ta progression."), category: .time, symbol: "calendar.day.timeline.left", isPremium: false, families: SM, keywords: ["semaine", "jours", "numéro de semaine"], isNew: true),
        KindInfo(kind: .holiday, title: tr("Prochain jour férié"), summary: tr("Le prochain jour férié au Québec, au Canada ou en France."), category: .time, symbol: "sun.max", isPremium: false, families: SM + [rect, inline], keywords: ["férié", "congé", "vacances", "holiday"], space: .life, isNew: true),
        KindInfo(kind: .moonPhase, title: tr("Phase de lune"), summary: tr("La lune ce soir, son éclairage et la prochaine pleine lune."), category: .time, symbol: "moon.stars", isPremium: false, families: SM + [circ], keywords: ["lune", "pleine lune", "nouvelle lune", "moon"], isNew: true),
    ]

    // MARK: Météo

    static let weather: [KindInfo] = [
        KindInfo(kind: .weather, title: tr("Météo"), summary: tr("La température et les prévisions de ta ville."), category: .weather, symbol: "cloud.sun.fill", isPremium: false, families: SML + [circ, rect, inline], keywords: ["température", "pluie", "prévisions", "soleil"]),
        KindInfo(kind: .sunCycle, title: tr("Soleil"), summary: tr("Lever, coucher et durée du jour, avec la course du soleil."), category: .weather, symbol: "sunrise.fill", isPremium: false, families: SM + [rect], keywords: ["lever", "coucher", "sunrise", "sunset", "jour"], isNew: true),
        KindInfo(kind: .rainNext, title: tr("Pluie"), summary: tr("Le risque de pluie heure par heure pour les 12 prochaines heures."), category: .weather, symbol: "cloud.rain.fill", isPremium: true, families: SM + [rect], keywords: ["pluie", "parapluie", "précipitations"], isNew: true),
        KindInfo(kind: .windUV, title: tr("Vent et UV"), summary: tr("La force du vent, sa direction et l'indice UV."), category: .weather, symbol: "wind", isPremium: true, families: SM, keywords: ["vent", "uv", "soleil", "rafales"], isNew: true),
        KindInfo(kind: .weatherDetails, title: tr("Météo détaillée"), summary: tr("Ressenti, humidité, vent, UV et pression, réunis."), category: .weather, symbol: "thermometer.medium", isPremium: true, families: SML, keywords: ["ressenti", "humidité", "pression"], isNew: true),
        KindInfo(kind: .weeklyForecast, title: tr("Semaine météo"), summary: tr("Les prévisions des sept prochains jours."), category: .weather, symbol: "calendar.badge.clock", isPremium: true, families: ML, keywords: ["semaine", "prévisions", "7 jours"], isNew: true),
    ]

    // MARK: Productivité

    static let productivity: [KindInfo] = [
        KindInfo(kind: .tasks, title: tr("Tâches"), summary: tr("Ta liste du jour, que tu coches directement sur l'écran d'accueil."), category: .productivity, symbol: "checklist", isPremium: false, families: SML + [rect], keywords: ["todo", "to-do", "liste", "à faire"], space: .productivity, isInteractive: true),
        KindInfo(kind: .habits, title: tr("Habitudes"), summary: tr("Tes habitudes de la semaine, validées d'une touche."), category: .wellbeing, symbol: "repeat", isPremium: false, families: SML, keywords: ["routine", "streak", "objectif", "série"], space: .habits, isInteractive: true),
        KindInfo(kind: .focus, title: tr("Focus"), summary: tr("Un minuteur de concentration qui défile en direct."), category: .productivity, symbol: "timer", isPremium: true, families: SM + [circ, rect], keywords: ["pomodoro", "minuteur", "timer", "concentration", "travail"], space: .productivity, isInteractive: true),
        KindInfo(kind: .upNext, title: tr("À venir"), summary: tr("Tes prochains rendez-vous, tirés de ton calendrier."), category: .productivity, symbol: "calendar.badge.clock", isPremium: true, families: SML + [rect], keywords: ["événements", "agenda", "rendez-vous", "réunion"]),
        KindInfo(kind: .note, title: tr("Note"), summary: tr("Un mot, un rappel ou une citation, toujours sous les yeux."), category: .productivity, symbol: "note.text", isPremium: false, families: SML, keywords: ["citation", "mémo", "texte", "rappel"]),
        KindInfo(kind: .priorities, title: tr("Top 3 du jour"), summary: tr("Tes trois priorités du jour, cochées depuis l'écran d'accueil."), category: .productivity, symbol: "3.circle", isPremium: false, families: SM + [rect], keywords: ["priorités", "important", "objectifs", "today"], space: .productivity, isNew: true, isInteractive: true),
        KindInfo(kind: .project, title: tr("Projet"), summary: tr("L'avancement d'un projet, ses tâches restantes et son échéance."), category: .productivity, symbol: "folder.fill", isPremium: true, families: SML, keywords: ["projet", "avancement", "deadline"], space: .productivity, isNew: true, isInteractive: true),
        KindInfo(kind: .deadline, title: tr("Échéance"), summary: tr("Le temps qu'il reste avant une échéance, à la seconde près."), category: .productivity, symbol: "flag.checkered", isPremium: true, families: SM + [circ, rect], keywords: ["deadline", "rendu", "date limite"], space: .productivity, isNew: true),
        KindInfo(kind: .deepWork, title: tr("Travail profond"), summary: tr("Tes heures de concentration de la semaine, par rapport à ton objectif."), category: .productivity, symbol: "brain.head.profile", isPremium: true, families: SML, keywords: ["concentration", "focus", "heures", "travail profond"], space: .productivity, isNew: true),
        KindInfo(kind: .counter, title: tr("Compteur"), summary: tr("Compte n'importe quoi d'une touche : cafés, pompes, pages…"), category: .productivity, symbol: "plusminus.circle", isPremium: false, families: SM + [circ], keywords: ["compteur", "tally", "comptage", "clic"], space: .productivity, isNew: true, isInteractive: true),
    ]

    // MARK: Habitudes

    static let wellbeing: [KindInfo] = [
        KindInfo(kind: .hydration, title: tr("Hydratation"), summary: tr("Tes verres d'eau de la journée, ajoutés d'une touche."), category: .wellbeing, symbol: "drop.fill", isPremium: false, families: SM + [circ], keywords: ["eau", "boire", "verres", "santé"], space: .habits, isInteractive: true),
        KindInfo(kind: .habitStreak, title: tr("Série"), summary: tr("La série en cours d'une habitude et ses 30 derniers jours."), category: .wellbeing, symbol: "flame.fill", isPremium: false, families: SM + [circ], keywords: ["streak", "série", "habitude"], space: .habits, isNew: true),
        KindInfo(kind: .habitWeek, title: tr("Semaine d'habitudes"), summary: tr("Toutes tes habitudes sur sept jours, en grille."), category: .wellbeing, symbol: "square.grid.3x3.fill", isPremium: true, families: ML, keywords: ["semaine", "grille", "habitudes"], space: .habits, isNew: true),
        KindInfo(kind: .habitRate, title: tr("Taux de réussite"), summary: tr("Le pourcentage d'habitudes tenues ce mois-ci."), category: .wellbeing, symbol: "percent", isPremium: true, families: SM, keywords: ["réussite", "pourcentage", "mois"], space: .habits, isNew: true),
    ]

    // MARK: Nutrition

    static let nutrition: [KindInfo] = [
        KindInfo(kind: .caloriesLeft, title: tr("Calories restantes"), summary: tr("Ce qu'il te reste à manger aujourd'hui par rapport à ton objectif."), category: .nutrition, symbol: "flame", isPremium: false, families: SM + [circ, rect, inline], keywords: ["calories", "kcal", "restantes", "régime"], space: .nutrition, isNew: true),
        KindInfo(kind: .macros, title: tr("Macros"), summary: tr("Protéines, glucides et lipides de la journée face à tes objectifs."), category: .nutrition, symbol: "chart.bar.xaxis", isPremium: true, families: SM + [rect], keywords: ["protéines", "glucides", "lipides", "macros"], space: .nutrition, isNew: true),
        KindInfo(kind: .proteinLeft, title: tr("Protéines restantes"), summary: tr("Les grammes de protéines qu'il te reste pour atteindre ton objectif."), category: .nutrition, symbol: "bolt.heart", isPremium: true, families: SM + [circ], keywords: ["protéines", "muscle", "grammes"], space: .nutrition, isNew: true),
        KindInfo(kind: .mealsToday, title: tr("Repas du jour"), summary: tr("Ce que tu as mangé aujourd'hui, repas par repas."), category: .nutrition, symbol: "list.bullet.rectangle", isPremium: true, families: SML, keywords: ["repas", "journal", "déjeuner", "dîner"], space: .nutrition, isNew: true),
        KindInfo(kind: .nutritionWeek, title: tr("Semaine nutrition"), summary: tr("Tes calories des sept derniers jours et ta moyenne."), category: .nutrition, symbol: "chart.bar", isPremium: true, families: SML, keywords: ["semaine", "moyenne", "calories"], space: .nutrition, isNew: true),
        KindInfo(kind: .nutritionStreak, title: tr("Série de suivi"), summary: tr("Les jours d'affilée où tu as noté ce que tu manges."), category: .nutrition, symbol: "flame.fill", isPremium: true, families: SM, keywords: ["streak", "série", "suivi"], space: .nutrition, isNew: true),
        KindInfo(kind: .quickFood, title: tr("Ajout rapide"), summary: tr("Tes aliments favoris, ajoutés au journal d'une touche."), category: .nutrition, symbol: "plus.app", isPremium: true, families: SM, keywords: ["favoris", "rapide", "ajouter", "repas"], space: .nutrition, isNew: true, isInteractive: true),
        KindInfo(kind: .nextMeal, title: tr("Prochain repas"), summary: tr("Ce qu'il reste pour ton prochain repas en calories et en protéines."), category: .nutrition, symbol: "clock.badge.checkmark", isPremium: true, families: SM, keywords: ["repas", "suivant", "dîner", "souper"], space: .nutrition, isNew: true),
    ]

    // MARK: Fitness

    static let fitness: [KindInfo] = [
        KindInfo(kind: .todaysWorkout, title: tr("Séance du jour"), summary: tr("La séance prévue aujourd'hui et ses exercices."), category: .fitness, symbol: "figure.strengthtraining.traditional", isPremium: false, families: SML, keywords: ["entraînement", "séance", "workout", "musculation"], space: .fitness, isNew: true),
        KindInfo(kind: .nextSet, title: tr("Prochaine série"), summary: tr("Ta prochaine série, validée depuis l'écran d'accueil, avec le repos qui démarre."), category: .fitness, symbol: "arrow.forward.circle.fill", isPremium: true, families: SM + [rect], keywords: ["série", "répétitions", "set", "next set"], space: .fitness, isNew: true, isInteractive: true),
        KindInfo(kind: .restTimer, title: tr("Repos"), summary: tr("Le temps de repos entre deux séries, qui défile en direct."), category: .fitness, symbol: "timer", isPremium: true, families: SM + [circ, rect], keywords: ["repos", "rest timer", "minuteur"], space: .fitness, isNew: true, isInteractive: true),
        KindInfo(kind: .weeklyVolume, title: tr("Volume de la semaine"), summary: tr("Le tonnage soulevé chaque jour de la semaine."), category: .fitness, symbol: "scalemass", isPremium: true, families: SML, keywords: ["volume", "tonnage", "kg", "semaine"], space: .fitness, isNew: true),
        KindInfo(kind: .personalRecords, title: tr("Records"), summary: tr("Tes meilleures charges par exercice."), category: .fitness, symbol: "trophy.fill", isPremium: true, families: SML, keywords: ["record", "pr", "max", "1rm"], space: .fitness, isNew: true),
        KindInfo(kind: .trainingStreak, title: tr("Régularité"), summary: tr("Tes séances de la semaine face à ton objectif, et ta série de semaines."), category: .fitness, symbol: "flame.fill", isPremium: false, families: SM + [circ], keywords: ["série", "régularité", "semaine", "streak"], space: .fitness, isNew: true),
        KindInfo(kind: .caloriesBurned, title: tr("Calories brûlées"), summary: tr("Une estimation des calories dépensées pendant tes séances."), category: .fitness, symbol: "flame", isPremium: true, families: SM, keywords: ["calories", "dépense", "brûlées"], space: .fitness, isNew: true),
        KindInfo(kind: .workoutMonth, title: tr("Mois d'entraînement"), summary: tr("Tes jours d'entraînement du mois, en calendrier."), category: .fitness, symbol: "calendar", isPremium: true, families: SML, keywords: ["mois", "calendrier", "entraînement"], space: .fitness, isNew: true),
    ]

    // MARK: Budget

    static let finance: [KindInfo] = [
        KindInfo(kind: .moneyFlow, title: tr("Flux d'argent"), summary: tr("Ce que tu gagnes et dépenses, calculé au fil du jour."), category: .finance, symbol: "dollarsign.arrow.circlepath", isPremium: true, families: SML, keywords: ["argent", "revenus", "dépenses", "salaire", "loyer"], space: .budget),
        KindInfo(kind: .budgetLeft, title: tr("Reste du mois"), summary: tr("L'argent qu'il te reste à dépenser ce mois-ci, et par jour."), category: .finance, symbol: "creditcard", isPremium: false, families: SM + [rect, inline], keywords: ["budget", "reste", "remaining", "mois"], space: .budget, isNew: true),
        KindInfo(kind: .spendingByCategory, title: tr("Dépenses par catégorie"), summary: tr("Où part ton argent ce mois-ci, catégorie par catégorie."), category: .finance, symbol: "chart.bar.doc.horizontal", isPremium: true, families: SML, keywords: ["dépenses", "catégories", "courses", "restaurants"], space: .budget, isNew: true),
        KindInfo(kind: .billsUpcoming, title: tr("Factures à venir"), summary: tr("Tes prochaines factures et leurs échéances."), category: .finance, symbol: "doc.text", isPremium: true, families: SML + [rect], keywords: ["factures", "loyer", "échéances", "bills"], space: .budget, isNew: true),
        KindInfo(kind: .savingsGoal, title: tr("Objectif d'épargne"), summary: tr("Où tu en es de ton objectif d'épargne."), category: .finance, symbol: "banknote", isPremium: false, families: SM + [circ], keywords: ["épargne", "objectif", "économies", "savings"], space: .budget, isNew: true),
        KindInfo(kind: .netWorth, title: tr("Valeur nette"), summary: tr("Ce que tu possèdes moins ce que tu dois, et son évolution."), category: .finance, symbol: "building.columns", isPremium: true, families: SM, keywords: ["patrimoine", "net worth", "actifs", "dettes"], space: .budget, isNew: true),
        KindInfo(kind: .subscriptions, title: tr("Abonnements"), summary: tr("Le coût mensuel de tous tes abonnements."), category: .finance, symbol: "repeat.circle", isPremium: true, families: SML, keywords: ["abonnements", "netflix", "spotify", "mensuel"], space: .budget, isNew: true),
        KindInfo(kind: .quickExpense, title: tr("Dépense rapide"), summary: tr("Tes dépenses habituelles, notées d'une touche."), category: .finance, symbol: "cart.badge.plus", isPremium: true, families: SM, keywords: ["dépense", "café", "rapide", "ajouter"], space: .budget, isNew: true, isInteractive: true),
    ]

    // MARK: Investissement

    static let investing: [KindInfo] = [
        KindInfo(kind: .crypto, title: tr("Crypto"), summary: tr("Le cours d'une crypto et sa courbe sur 7 jours."), category: .investing, symbol: "bitcoinsign.circle", isPremium: true, families: SM + [rect], keywords: ["bitcoin", "ethereum", "btc", "marché", "cours"]),
        KindInfo(kind: .portfolio, title: tr("Portefeuille"), summary: tr("La valeur de ton portefeuille et sa performance."), category: .investing, symbol: "chart.line.uptrend.xyaxis", isPremium: true, families: SML + [rect], keywords: ["portefeuille", "actions", "etf", "performance"], space: .investing, isNew: true),
        KindInfo(kind: .allocation, title: tr("Répartition"), summary: tr("La part de chaque type de placement dans ton portefeuille."), category: .investing, symbol: "chart.pie", isPremium: true, families: SM, keywords: ["allocation", "répartition", "diversification"], space: .investing, isNew: true),
        KindInfo(kind: .topMover, title: tr("Plus forte variation"), summary: tr("Le placement qui a le plus bougé en 24 h."), category: .investing, symbol: "arrow.up.arrow.down", isPremium: true, families: SM, keywords: ["variation", "top mover", "hausse", "baisse"], space: .investing, isNew: true),
        KindInfo(kind: .watchlist, title: tr("Liste de suivi"), summary: tr("Plusieurs cryptos suivies en direct, en une liste."), category: .investing, symbol: "list.star", isPremium: false, families: SML, keywords: ["watchlist", "suivi", "crypto", "cours"], space: .investing, isNew: true),
        KindInfo(kind: .marketOverview, title: tr("Marché crypto"), summary: tr("La capitalisation totale du marché et ses principaux actifs."), category: .investing, symbol: "globe.americas", isPremium: true, families: SM, keywords: ["marché", "capitalisation", "dominance"], isNew: true),
    ]

    // MARK: Business

    static let business: [KindInfo] = [
        KindInfo(kind: .revenueGoal, title: tr("Objectif du mois"), summary: tr("Ton chiffre d'affaires du mois face à ton objectif."), category: .business, symbol: "target", isPremium: false, families: SM + [circ, rect], keywords: ["chiffre d'affaires", "ca", "objectif", "ventes"], space: .business, isNew: true),
        KindInfo(kind: .revenueTrend, title: tr("Ventes sur 30 jours"), summary: tr("Ton chiffre d'affaires jour par jour, avec la semaine et le mois."), category: .business, symbol: "chart.xyaxis.line", isPremium: true, families: SML, keywords: ["ventes", "courbe", "tendance", "revenus"], space: .business, isNew: true),
        KindInfo(kind: .profit, title: tr("Bénéfice"), summary: tr("Le bénéfice du mois et ta marge."), category: .business, symbol: "banknote.fill", isPremium: true, families: SM, keywords: ["bénéfice", "marge", "profit", "dépenses"], space: .business, isNew: true),
        KindInfo(kind: .businessKPIs, title: tr("Indicateurs"), summary: tr("Commandes, panier moyen, nouveaux clients et conversion."), category: .business, symbol: "square.grid.2x2", isPremium: true, families: SML, keywords: ["kpi", "commandes", "panier moyen", "clients", "conversion"], space: .business, isNew: true),
        KindInfo(kind: .mrr, title: tr("MRR et ARR"), summary: tr("Ton revenu récurrent, tes abonnés et ta croissance mensuelle."), category: .business, symbol: "arrow.triangle.2.circlepath", isPremium: true, families: SM + [rect], keywords: ["mrr", "arr", "abonnés", "saas", "croissance"], space: .business, isNew: true),
        KindInfo(kind: .revenueToday, title: tr("Ventes du jour"), summary: tr("Le chiffre d'affaires du jour comparé au même jour la semaine dernière."), category: .business, symbol: "cart", isPremium: true, families: SM + [rect, inline], keywords: ["aujourd'hui", "ventes", "jour"], space: .business, isNew: true),
        KindInfo(kind: .businessDashboard, title: tr("Tableau de bord business"), summary: tr("Les chiffres clés de ton entreprise sur un seul widget."), category: .business, symbol: "rectangle.3.group", isPremium: true, families: ML, keywords: ["dashboard", "entreprise", "business"], space: .business, isNew: true),
    ]

    // MARK: Entreprises

    static let markets: [KindInfo] = [
        KindInfo(kind: .companySnapshot, title: tr("Fiche entreprise"), summary: tr("Revenus, bénéfice, marge et croissance d'une société cotée."), category: .markets, symbol: "building.2", isPremium: true, families: SM, keywords: ["apple", "tesla", "nvidia", "entreprise", "revenus", "sec"], space: .markets, isNew: true),
        KindInfo(kind: .companyRevenue, title: tr("Revenus trimestriels"), summary: tr("Les revenus trimestriels d'une société, en barres."), category: .markets, symbol: "chart.bar.fill", isPremium: true, families: SML, keywords: ["revenus", "trimestre", "croissance"], space: .markets, isNew: true),
        KindInfo(kind: .companyStock, title: tr("Action"), summary: tr("Le cours de l'action d'une société et sa capitalisation."), category: .markets, symbol: "chart.line.uptrend.xyaxis.circle", isPremium: true, families: SM + [rect], keywords: ["action", "bourse", "cours", "capitalisation"], space: .markets, isNew: true),
        KindInfo(kind: .companyCompare, title: tr("Comparateur"), summary: tr("Plusieurs sociétés comparées par revenus annuels."), category: .markets, symbol: "chart.bar.doc.horizontal", isPremium: true, families: ML, keywords: ["comparer", "revenus", "concurrents"], space: .markets, isNew: true),
    ]

    // MARK: Études

    static let student: [KindInfo] = [
        KindInfo(kind: .nextClass, title: tr("Prochain cours"), summary: tr("Ton prochain cours, l'heure et la salle."), category: .student, symbol: "book.closed", isPremium: false, families: SM + [rect, inline], keywords: ["cours", "horaire", "salle", "école", "université"], space: .student, isNew: true),
        KindInfo(kind: .nextExam, title: tr("Prochain examen"), summary: tr("Les jours avant ton prochain examen."), category: .student, symbol: "pencil.and.list.clipboard", isPremium: false, families: SM + [circ, rect, inline], keywords: ["examen", "partiel", "contrôle", "révisions"], space: .student, isNew: true),
        KindInfo(kind: .assignments, title: tr("Devoirs"), summary: tr("Tes devoirs à rendre, par échéance."), category: .student, symbol: "doc.text", isPremium: true, families: SML + [rect], keywords: ["devoirs", "travaux", "rendu"], space: .student, isNew: true, isInteractive: true),
        KindInfo(kind: .gradeAverage, title: tr("Moyenne"), summary: tr("Ta moyenne générale pondérée et celle de chaque cours."), category: .student, symbol: "graduationcap", isPremium: true, families: SML, keywords: ["moyenne", "notes", "gpa", "bulletin"], space: .student, isNew: true),
        KindInfo(kind: .semesterProgress, title: tr("Session"), summary: tr("L'avancement de ta session ou de ton semestre."), category: .student, symbol: "calendar.badge.clock", isPremium: false, families: SM + [circ, inline], keywords: ["semestre", "session", "progression"], space: .student, isNew: true),
        KindInfo(kind: .flashcard, title: tr("Fiche de révision"), summary: tr("Une fiche à retourner depuis l'écran d'accueil, avec répétition espacée."), category: .student, symbol: "rectangle.on.rectangle.angled", isPremium: true, families: SM, keywords: ["flashcards", "fiches", "révision", "mémoriser"], space: .student, isNew: true, isInteractive: true),
        KindInfo(kind: .studyHours, title: tr("Heures d'étude"), summary: tr("Tes heures d'étude de la semaine face à ton objectif."), category: .student, symbol: "clock.badge.checkmark", isPremium: true, families: SML, keywords: ["étude", "heures", "révisions"], space: .student, isNew: true),
        KindInfo(kind: .timetable, title: tr("Horaire du jour"), summary: tr("Tous tes cours de la journée."), category: .student, symbol: "list.bullet.rectangle.portrait", isPremium: true, families: SML, keywords: ["horaire", "emploi du temps", "cours"], space: .student, isNew: true),
    ]

    // MARK: Voyage

    static let travel: [KindInfo] = [
        KindInfo(kind: .tripCountdown, title: tr("Départ en voyage"), summary: tr("Les jours avant ton prochain voyage."), category: .travel, symbol: "airplane.departure", isPremium: false, families: SM + [circ, rect, inline], keywords: ["voyage", "vacances", "départ", "trip"], space: .travel, isNew: true),
        KindInfo(kind: .flight, title: tr("Vol"), summary: tr("Ton vol : heure de départ, terminal, porte et compte à rebours."), category: .travel, symbol: "airplane", isPremium: true, families: SM + [rect], keywords: ["vol", "avion", "porte", "terminal", "flight"], space: .travel, isNew: true),
        KindInfo(kind: .hotel, title: tr("Hôtel"), summary: tr("Ton hôtel, son adresse et les dates d'arrivée et de départ."), category: .travel, symbol: "bed.double.fill", isPremium: true, families: SM, keywords: ["hôtel", "logement", "airbnb"], space: .travel, isNew: true),
        KindInfo(kind: .destinationWeather, title: tr("Météo à destination"), summary: tr("La météo de ta destination pendant ton voyage."), category: .travel, symbol: "cloud.sun.rain", isPremium: true, families: SM, keywords: ["météo", "destination"], space: .travel, isNew: true),
        KindInfo(kind: .localTime, title: tr("Heure sur place"), summary: tr("L'heure à destination et le décalage avec chez toi."), category: .travel, symbol: "clock.arrow.2.circlepath", isPremium: false, families: SM + [inline], keywords: ["heure", "décalage", "fuseau"], space: .travel, isNew: true),
        KindInfo(kind: .currency, title: tr("Devise"), summary: tr("Le taux de change et une conversion rapide."), category: .travel, symbol: "coloncurrencysign.circle", isPremium: true, families: SM, keywords: ["devise", "taux de change", "euro", "dollar"], space: .travel, isNew: true),
        KindInfo(kind: .tripProgress, title: tr("Avancement du voyage"), summary: tr("Le jour du voyage où tu es et les jours restants."), category: .travel, symbol: "map", isPremium: true, families: SM + [circ], keywords: ["jour", "voyage", "restants"], space: .travel, isNew: true),
        KindInfo(kind: .nextActivity, title: tr("Prochaine activité"), summary: tr("La prochaine activité prévue pendant ton voyage."), category: .travel, symbol: "mappin.and.ellipse", isPremium: true, families: SM + [rect], keywords: ["activité", "visite", "réservation"], space: .travel, isNew: true),
    ]

    // MARK: Auto

    static let car: [KindInfo] = [
        KindInfo(kind: .carCost, title: tr("Coût de la voiture"), summary: tr("Le coût mensuel estimé de ta voiture, tout compris."), category: .car, symbol: "car.side", isPremium: true, families: SML, keywords: ["coût", "voiture", "mensuel", "assurance"], space: .car, isNew: true),
        KindInfo(kind: .nextService, title: tr("Prochain entretien"), summary: tr("Le prochain entretien et les kilomètres ou jours qu'il reste."), category: .car, symbol: "wrench.and.screwdriver", isPremium: false, families: SM + [rect], keywords: ["entretien", "vidange", "huile", "pneus"], space: .car, isNew: true),
        KindInfo(kind: .mileage, title: tr("Kilométrage"), summary: tr("Ton compteur et les kilomètres parcourus ce mois-ci."), category: .car, symbol: "gauge.with.dots.needle.33percent", isPremium: true, families: SM, keywords: ["kilométrage", "odomètre", "km"], space: .car, isNew: true),
        KindInfo(kind: .fuelStats, title: tr("Carburant"), summary: tr("Ta consommation moyenne, ton dernier prix au litre et le coût au kilomètre."), category: .car, symbol: "fuelpump", isPremium: true, families: SM, keywords: ["essence", "carburant", "consommation", "plein"], space: .car, isNew: true),
        KindInfo(kind: .carDeadlines, title: tr("Échéances auto"), summary: tr("Assurance, immatriculation, pneus : les prochaines dates à retenir."), category: .car, symbol: "calendar.badge.exclamationmark", isPremium: true, families: SML, keywords: ["assurance", "immatriculation", "pneus", "échéances"], space: .car, isNew: true),
    ]

    // MARK: Tableaux de bord

    static let dashboards: [KindInfo] = [
        KindInfo(kind: .myDay, title: tr("Ma journée"), summary: tr("L'heure, la météo, ton prochain rendez-vous, tes tâches et tes calories en un seul widget."), category: .dashboards, symbol: "sun.horizon", isPremium: true, families: ML, keywords: ["journée", "dashboard", "résumé", "my day"], isNew: true),
        KindInfo(kind: .now, title: tr("Maintenant"), summary: tr("Un widget qui change selon le moment : météo et agenda le matin, tâches et focus la journée, bilan le soir."), category: .dashboards, symbol: "wand.and.stars", isPremium: true, families: SML, keywords: ["contextuel", "intelligent", "matin", "soir"], isNew: true),
        KindInfo(kind: .morning, title: tr("Ce matin"), summary: tr("Météo, premier rendez-vous, priorités et objectif du jour pour bien démarrer."), category: .dashboards, symbol: "sunrise", isPremium: true, families: ML, keywords: ["matin", "morning", "réveil"], isNew: true),
        KindInfo(kind: .fitnessDashboard, title: tr("Tableau fitness"), summary: tr("Séance, régularité, calories et protéines réunies."), category: .dashboards, symbol: "figure.run", isPremium: true, families: ML, keywords: ["fitness", "sport", "dashboard"], isNew: true),
        KindInfo(kind: .moneyDashboard, title: tr("Tableau argent"), summary: tr("Reste du mois, dépenses, épargne et factures réunies."), category: .dashboards, symbol: "dollarsign.circle", isPremium: true, families: ML, keywords: ["argent", "budget", "dashboard"], isNew: true),
        KindInfo(kind: .studentDashboard, title: tr("Tableau études"), summary: tr("Prochain cours, examen, devoirs et heures d'étude réunis."), category: .dashboards, symbol: "graduationcap.circle", isPremium: true, families: ML, keywords: ["études", "étudiant", "dashboard"], isNew: true),
        KindInfo(kind: .aiSummary, title: tr("Résumé intelligent"), summary: tr("Ta journée résumée en deux phrases, à partir de tes vraies données."), category: .dashboards, symbol: "sparkles", isPremium: true, families: SML + [rect], keywords: ["ia", "ai", "résumé", "intelligent"], isNew: true),
        KindInfo(kind: .aiNutrition, title: tr("Conseil nutrition"), summary: tr("Ce qu'il te reste pour la journée, expliqué simplement."), category: .dashboards, symbol: "sparkles.rectangle.stack", isPremium: true, families: SM, keywords: ["ia", "nutrition", "analyse"], space: .nutrition, isNew: true),
        KindInfo(kind: .aiFinance, title: tr("Analyse des dépenses"), summary: tr("Tes dépenses comparées à la semaine dernière."), category: .dashboards, symbol: "sparkle.magnifyingglass", isPremium: true, families: SM, keywords: ["ia", "dépenses", "analyse"], space: .budget, isNew: true),
        KindInfo(kind: .aiProductivity, title: tr("Analyse productivité"), summary: tr("Tes tendances de concentration, d'habitudes et de tâches."), category: .dashboards, symbol: "chart.line.text.clipboard", isPremium: true, families: SM, keywords: ["ia", "productivité", "analyse"], space: .productivity, isNew: true),
    ]
}
