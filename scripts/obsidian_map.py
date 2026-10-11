"""Builds the Obsidian map of the project in docs/obsidian/ (JSON Canvas 1.0 + Markdown notes), then checks it.

    python3 scripts/obsidian_map.py          # writes the canvases, the module notes and the guide, then checks
    python3 scripts/obsidian_map.py --check  # checks only: valid JSON Canvas, links and source paths that exist

Everything shown here was read in the code (paths, types, relations). When the architecture or an important
feature changes, update MODULES / the canvas builders below, run the script, and commit docs/obsidian/.
The vault to open in Obsidian is the repository root (paths stay the real ones).
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "obsidian")
NOTES = os.path.join(OUT, "modules")

# ----------------------------------------------------------------------------------------------- modules
# zone: interface · metier · donnees · ios · services · outils
MODULES = [
    {"file": "Noyau-AppModel", "title": "Noyau : AppModel et Router", "zone": "metier",
     "role": "Source unique des données de l'app et navigation. `AppModel` (@Observable, @MainActor) garde l'état de chaque domaine, l'écrit dans le stockage partagé, recharge les widgets et tient les caches réseau ; `Router` décide de l'onglet, des feuilles et des liens profonds.",
     "features": [
         "État : designs (widgets), contenu (tâches, habitudes, eau, argent), réglages, Premium, 11 domaines métier, profil, « Mes styles ».",
         "Caches réseau : météo, crypto, marchés, entreprises, taux de change, météo de voyage, analyses.",
         "Limites gratuites : `freeDesignLimit = 8` widgets, `freeHabitLimit = 5` habitudes.",
         "Rappels intelligents (SmartReminders), activité en direct de la séance, « bons moments » pour la demande de note.",
         "Router : onglets `home`, `spaces` (Créer), `explore` (Store), `mine` (Mes widgets) ; `openEditor`, `openApp`, `showPaywall`, `handle(DeepLink)`.",
     ],
     "sources": ["App/Core/AppModel.swift", "App/Core/Router.swift", "App/TesseraApp.swift", "App/Core/AppModel+Debug.swift"],
     "links": [("Donnees-et-stockage", "écrit chaque domaine en JSON"), ("Domaines-metier", "tient les états"), ("Widgets-extension", "recharge les widgets (WidgetCenter)"),
               ("Services-externes", "remplit les caches réseau"), ("Intents-et-activite-en-direct", "démarre l'activité en direct"), ("Premium-et-abonnements", "état Premium")]},
    {"file": "Donnees-et-stockage", "title": "Données et stockage", "zone": "donnees",
     "role": "Tout est stocké sur l'appareil, dans le conteneur App Group partagé par l'app et l'extension widgets : un fichier JSON par domaine pour qu'un widget qui écrit un domaine ne touche jamais les autres.",
     "features": [
         "App Group `group.com.dakrsnyk.tessera`, dossier `Tessera/` (nom conservé après le renommage en Ardane).",
         "`StoreFile` : designs, content, settings, premium, weather, crypto, nutrition, fitness, budget, business, portfolio, following, student, travel, car, productivity, life, profile, styles, markets, companies, fx, tripWeather, insights.",
         "Sauvegarde : un fichier qui contient tout, à garder où on veut ; les sauvegardes « Tessera » s'importent toujours.",
         "Données d'un widget : `PayloadLoader` charge seulement ce que le type de widget utilise (`DataNeeds`, `DomainData`).",
         "Données de démonstration (galerie système, aperçus du Store, builds de test) : `SampleData`.",
         "Ressources embarquées : base alimentaire CNF (`cnf-foods.json`, ~5 600 aliments) et démos d'exercices (`ExerciseDemos.json`).",
     ],
     "sources": ["Shared/Support/SharedStore.swift", "App/Core/DataBackup.swift", "App/Core/DataItems.swift", "Shared/Data/PayloadLoader.swift",
                 "Shared/Data/DomainData.swift", "Shared/Data/SampleData.swift", "Shared/Data/Insights.swift", "App/Core/NutrientFile.swift",
                 "App/Resources/cnf-foods.json", "App/Resources/ExerciseDemos.json", "Config/Tessera.entitlements", "Config/TesseraWidgets.entitlements"],
     "links": [("Noyau-AppModel", "écrit par AppModel"), ("Widgets-extension", "lu par l'extension"), ("Intents-et-activite-en-direct", "écrit par les boutons des widgets"),
               ("Profil-et-reglages", "sauvegarde et import")]},
    {"file": "Domaines-metier", "title": "Domaines métier (Shared/Domains)", "zone": "metier",
     "role": "Les règles et les états de chaque partie de la vie gérée par Ardane, partagés par l'app et l'extension (calculs, objectifs, historiques).",
     "features": [
         "Nutrition (`NutritionState`, base d'aliments `FoodDatabase`), Fitness (`FitnessState`, bibliothèque `ExerciseLibrary`, `ExerciseTechniques`).",
         "Budget (`BudgetState`), Business (`BusinessState`), Placements (`PortfolioState`), Marchés et sociétés (`MarketsState`).",
         "Études (`StudentState`), Voyage (`TravelState`), Auto (`CarState`), Productivité (`ProductivityState`), Ma vie (`LifeState`).",
         "Profil (`UserProfile`) : centres d'intérêt et informations de la personne.",
     ],
     "sources": ["Shared/Domains/Nutrition.swift", "Shared/Domains/FoodDatabase.swift", "Shared/Domains/Fitness.swift", "Shared/Domains/ExerciseLibrary.swift",
                 "Shared/Domains/ExerciseTechniques.swift", "Shared/Domains/Budget.swift", "Shared/Domains/Business.swift", "Shared/Domains/Portfolio.swift",
                 "Shared/Domains/Companies.swift", "Shared/Domains/Student.swift", "Shared/Domains/Travel.swift", "Shared/Domains/Car.swift",
                 "Shared/Domains/Productivity.swift", "Shared/Domains/Life.swift", "Shared/Domains/Profile.swift", "Shared/Domains/StoredStates.swift"],
     "links": [("Noyau-AppModel", "états tenus par AppModel"), ("Donnees-et-stockage", "un fichier par domaine"), ("Services-externes", "Open Food Facts, CoinGecko, Finnhub, SEC, Frankfurter"),
               ("Mini-apps", "affichés et modifiés par les mini-apps")]},
    {"file": "Accueil-Mon-Quotidien", "title": "Accueil : Mon Quotidien", "zone": "interface",
     "role": "L'onglet Accueil : « Mon Quotidien » rassemble ce qui compte aujourd'hui, construit seulement à partir de ce que la personne a saisi, puis « Mes informations ».",
     "features": [
         "Cartes du jour (nutrition, séance, habitudes, À ne pas oublier, planning, eau, budget, Top 3…), classées selon le moment de la journée.",
         "Cartes à plusieurs vues (balayage), disposition à la main (ordre, demi ou large, masquer).",
         "« Mes informations » : complétude du profil et chaque domaine suivi d'un coup d'œil.",
         "`MiniAppsRow.swift` est présent mais le type `MiniAppsRow` n'est instancié nulle part.",
     ],
     "sources": ["App/Screens/Home/HomeView.swift", "App/Screens/Home/DailySection.swift", "App/Screens/Home/DailyPager.swift", "App/Screens/Home/DailyLayoutEditor.swift",
                 "App/Screens/Home/MyInfoCenter.swift", "App/Screens/Home/MyInfoSection.swift", "App/Screens/Home/MiniAppsRow.swift", "App/Core/DailyBrief.swift",
                 "App/Core/DailyCategories.swift", "App/Core/Agenda.swift"],
     "links": [("Mini-apps", "chaque carte ouvre sa mini-app"), ("Noyau-AppModel", "lit l'état"), ("Nutrition", "carte et bouton Scanner"), ("Fitness", "carte séance en cours")]},
    {"file": "Mini-apps", "title": "Mini-apps", "zone": "interface",
     "role": "Chaque mini-app est une partie entière d'Ardane : un tableau de bord, puis ses pages. Elles sont atteintes depuis l'Accueil.",
     "features": [
         "`MiniApp` : nutrition, fitness, planning, finances, business, travel, car, weather.",
         "`MiniAppPage` : les pages de chaque mini-app (repas, séance, bibliothèque, historique…).",
         "« Mes paramètres » de chaque mini-app (`MiniAppSettings`), vues de semaine partagées (`WeekViews`).",
     ],
     "sources": ["App/Screens/MiniApps/MiniApp.swift", "App/Screens/MiniApps/MiniAppSettings.swift", "App/Screens/MiniApps/WeekViews.swift"],
     "links": [("Nutrition", ""), ("Fitness", ""), ("Planning-et-habitudes", ""), ("Finances", ""), ("Autres-mini-apps", "Business, Voyage, Auto, Météo, Études"),
               ("Domaines-metier", "données de chaque mini-app")]},
    {"file": "Nutrition", "title": "Nutrition", "zone": "interface",
     "role": "Calories et macros du jour, repas, recherche d'aliments, scanner de code-barres, idées, historique.",
     "features": [
         "Anneau des calories restantes, protéines, glucides, lipides, repas du jour, idée, semaine.",
         "Ajout d'un aliment : recherche (aliments intégrés, base CNF, Open Food Facts si peu de résultats) puis feuille de quantité.",
         "Scanner de code-barres (VisionKit, EAN/UPC) avec carré de visée ; produit inconnu → créer l'aliment.",
         "Widgets nutrition ; le bouton « Scanner » des tailles moyenne et grande ouvre l'app sur le scanner (`tessera://scan-food`).",
         "Ajout rapide depuis un widget (`LogFoodIntent`).",
     ],
     "sources": ["App/Screens/MiniApps/Nutrition/NutritionApp.swift", "App/Screens/MiniApps/Nutrition/NutritionPages.swift", "App/Screens/Spaces/NutritionSpace.swift",
                 "Shared/Domains/Nutrition.swift", "Shared/Domains/FoodDatabase.swift", "App/Core/NutrientFile.swift", "Shared/Render/Tiles/NutritionTiles.swift"],
     "links": [("Services-externes", "Open Food Facts"), ("Domaines-metier", "NutritionState"), ("Intents-et-activite-en-direct", "LogFoodIntent, lien scan-food")]},
    {"file": "Fitness", "title": "Fitness", "zone": "interface",
     "role": "Programme de la semaine, séance en direct, repos, bibliothèque d'exercices avec démonstrations animées, progression.",
     "features": [
         "Séance en direct : série en cours, répétitions et charge, repos minuté (pause, passer), « Série faite ».",
         "Activité en direct sur l'écran verrouillé et dans la Dynamic Island, boutons actifs sans ouvrir l'app.",
         "Bibliothèque d'exercices (163) avec démonstration animée (`DemoRenderer`, `ExerciseDemos.json`) et technique.",
         "Semaine en ronds, records, progression, historique, séances rattrapées, calories estimées.",
         "Pas du jour via le capteur de mouvement (`StepCounter`, CoreMotion).",
     ],
     "sources": ["App/Screens/MiniApps/Fitness/FitnessApp.swift", "App/Screens/MiniApps/Fitness/FitnessSession.swift", "App/Screens/MiniApps/Fitness/FitnessPages.swift",
                 "App/Screens/MiniApps/Fitness/ExerciseLibraryViews.swift", "App/Screens/MiniApps/Fitness/ExerciseDemo.swift", "App/Screens/Spaces/FitnessSpace.swift",
                 "Shared/Domains/Fitness.swift", "Shared/Domains/ExerciseLibrary.swift", "App/Core/StepCounter.swift", "Shared/Render/Tiles/FitnessTiles.swift"],
     "links": [("Intents-et-activite-en-direct", "Série faite, pause, passer"), ("Domaines-metier", "FitnessState"), ("Donnees-et-stockage", "ExerciseDemos.json")]},
    {"file": "Planning-et-habitudes", "title": "Planning, tâches et habitudes", "zone": "interface",
     "role": "La semaine en tableau et le jour choisi, les tâches, le Top 3, les projets, la concentration, les études, les habitudes et l'eau.",
     "features": [
         "Semaine en tableau (blocs, ligne « maintenant », balayage de semaine), agenda du jour.",
         "Tâches avec répétition, Top 3 du jour, mois, projets, minuteur de concentration.",
         "Études (cours, examens, devoirs, notes) dans le Planning.",
         "Habitudes quotidiennes (série, rappel), eau en verres.",
         "Calendrier lu seulement (EventKit), sur autorisation.",
     ],
     "sources": ["App/Screens/MiniApps/Planning/PlanningApp.swift", "App/Screens/MiniApps/Planning/PlanningPages.swift", "App/Screens/MiniApps/Studies/StudiesApp.swift",
                 "App/Screens/MiniApps/Studies/StudiesPages.swift", "App/Screens/Content/HabitsView.swift", "App/Screens/Content/HydrationView.swift",
                 "App/Screens/Content/TasksView.swift", "Shared/Domains/Productivity.swift", "Shared/Domains/Student.swift", "Shared/Model/Content.swift",
                 "Shared/Data/CalendarService.swift"],
     "links": [("Services-externes", "EventKit (calendrier)"), ("Intents-et-activite-en-direct", "cocher une habitude ou une tâche depuis un widget"), ("Domaines-metier", "")]},
    {"file": "Finances", "title": "Finances", "zone": "interface",
     "role": "Saisie manuelle des revenus et dépenses : solde, reste du mois, catégories, factures, épargne. Aucune connexion bancaire.",
     "features": [
         "Graphique du solde (mois, 3 mois, année), solde de départ facultatif.",
         "Reste ce mois-ci, revenus / dépenses / solde, catégories avec limites, factures à venir, objectifs d'épargne, valeur nette.",
         "Évolution (Premium), dépense rapide depuis un widget (`QuickExpenseIntent`).",
     ],
     "sources": ["App/Screens/MiniApps/Finances/FinancesApp.swift", "App/Screens/MiniApps/Finances/FinancesPages.swift", "App/Screens/Spaces/BudgetSpace.swift",
                 "App/Screens/Content/MoneyView.swift", "Shared/Domains/Budget.swift", "Shared/Data/MoneyMath.swift", "Shared/Render/Tiles/MoneyTiles.swift"],
     "links": [("Domaines-metier", "BudgetState"), ("Premium-et-abonnements", "historique et évolution"), ("Intents-et-activite-en-direct", "QuickExpenseIntent")]},
    {"file": "Autres-mini-apps", "title": "Autres mini-apps", "zone": "interface",
     "role": "Business, Voyage, Auto et Météo, plus les espaces Placements, Marchés et Ma vie.",
     "features": [
         "Business : ventes, résultats, récurrent, indicateurs.",
         "Voyage : programme, budget en devise (taux Frankfurter), météo du voyage, liste.",
         "Auto : pleins, kilométrage, entretien, échéances, coûts.",
         "Météo : prévisions Open-Meteo pour la ville choisie.",
         "Placements et marchés : cours CoinGecko et Finnhub, données SEC des sociétés.",
     ],
     "sources": ["App/Screens/MiniApps/Business/BusinessApp.swift", "App/Screens/MiniApps/Business/BusinessPages.swift", "App/Screens/MiniApps/Travel/TravelApp.swift",
                 "App/Screens/MiniApps/Travel/TravelPages.swift", "App/Screens/MiniApps/Car/CarApp.swift", "App/Screens/MiniApps/Car/CarPages.swift",
                 "App/Screens/MiniApps/Weather/WeatherApp.swift", "App/Screens/Spaces/MoneySpaces.swift", "App/Screens/Spaces/TravelCarLifeSpaces.swift"],
     "links": [("Services-externes", "Open-Meteo, Frankfurter, CoinGecko, Finnhub, SEC"), ("Domaines-metier", "")]},
    {"file": "Creer-espaces", "title": "Créer : les espaces", "zone": "interface",
     "role": "L'onglet Créer : chaque espace est l'endroit où l'on saisit les données d'une famille de widgets, puis où l'on crée ses widgets.",
     "features": [
         "`Space` : productivity, habits, nutrition, fitness, budget, investing, business, markets, student, travel, car, life.",
         "Création de widgets depuis un espace (taille, un ou plusieurs widgets), envol vers « Mes widgets ».",
         "« Écran verrouillé » : les widgets prévus pour l'écran verrouillé, par univers.",
         "Formulaires des espaces (aliment, séance, dépense, plein…).",
     ],
     "sources": ["App/Screens/Spaces/SpacesView.swift", "App/Screens/Spaces/SpaceBuilderView.swift", "App/Screens/Spaces/LockScreenCreator.swift",
                 "App/Screens/Spaces/SpaceForms.swift", "App/Screens/Spaces/SpaceSheets.swift", "App/Screens/Spaces/ProductivitySpace.swift",
                 "App/Screens/Spaces/StudentSpace.swift", "App/Components/SaveFlight.swift", "Shared/Model/KindCatalog.swift"],
     "links": [("Studio-editeur", "ouvre le Studio (openEditor)"), ("Domaines-metier", "saisie des données"), ("Mes-widgets", "les widgets créés y arrivent")]},
    {"file": "Store", "title": "Store", "zone": "interface",
     "role": "L'onglet Store (Explore) : la sélection de la semaine, des écrans d'accueil complets, des widgets seuls, des packs et des combinés.",
     "features": [
         "23 écrans d'accueil prêts (fond, widgets, icônes et écran verrouillé assortis), 18 fonds d'écran dessinés en code.",
         "34 packs, saisons du Store (Halloween en octobre, Noël en décembre), widgets combinés, modèles.",
         "Un modèle ouvre le Studio sur une copie (`router.openEditor`).",
     ],
     "sources": ["App/Screens/Explore/ExploreView.swift", "App/Screens/Explore/HomeSetups.swift", "App/Screens/Explore/HomeSetupViews.swift",
                 "App/Screens/Explore/SetupWallpapers.swift", "App/Screens/Explore/StoreCombos.swift", "App/Screens/Explore/StoreMagazine.swift",
                 "App/Screens/Explore/StoreShowcase.swift", "Shared/Model/Packs.swift", "Shared/Model/Templates.swift", "Shared/Model/Combo.swift"],
     "links": [("Studio-editeur", "ouvre un modèle"), ("Premium-et-abonnements", "packs et styles Premium"), ("Mes-widgets", "installe des widgets")]},
    {"file": "Studio-editeur", "title": "Studio (éditeur de widgets)", "zone": "interface",
     "role": "Le Studio : contenu, taille, style, couleurs, fond, bordure et réglages propres au type de widget, avec un aperçu réel.",
     "features": [
         "57 styles (`ThemeID`), 16 thèmes complets (`StylePreset`), 14 palettes, couleur principale, fonds et textures, bordures.",
         "« Mes styles » : looks enregistrés pour plusieurs widgets.",
         "Réglages du type de widget et de l'élément suivi, guide d'ajout à l'écran d'accueil.",
     ],
     "sources": ["App/Screens/Editor/EditorView.swift", "App/Screens/Editor/StudioComponents.swift", "App/Screens/Editor/StudioPanels.swift",
                 "App/Screens/Editor/KindOptionsSection.swift", "App/Screens/Editor/SpaceOptionsSection.swift", "App/Screens/Editor/AddToHomeScreenGuide.swift",
                 "App/Components/StylePicker.swift", "Shared/Model/WidgetDesign.swift", "Shared/Model/WidgetStyle.swift", "Shared/Model/StyleColors.swift",
                 "Shared/Model/DesignOptions.swift", "Shared/Theme/Theme.swift"],
     "links": [("Widgets-extension", "le design est rendu par WidgetCanvas"), ("Noyau-AppModel", "enregistre le design"), ("Premium-et-abonnements", "styles et couleurs Premium")]},
    {"file": "Mes-widgets", "title": "Mes widgets", "zone": "interface",
     "role": "L'onglet Mes widgets : tous les widgets créés, en carrousel, favoris ou par catégorie, et la fusion de plusieurs widgets en un combiné.",
     "features": ["Carrousel et filtres, modification dans le Studio, fusion (`FusionViews`)."],
     "sources": ["App/Screens/MyWidgets/MyWidgetsView.swift", "App/Screens/MyWidgets/WidgetCarousel.swift", "App/Screens/MyWidgets/FusionViews.swift"],
     "links": [("Studio-editeur", "modifier un widget"), ("Widgets-extension", "les widgets posés sur l'iPhone")]},
    {"file": "Widgets-extension", "title": "Widgets : extension et rendu", "zone": "ios",
     "role": "L'extension WidgetKit (cible TesseraWidgets) et le rendu partagé : un même code dessine les vrais widgets et tous les aperçus de l'app.",
     "features": [
         "103 types de widgets (`WidgetKind`), tailles petite, moyenne, grande et écran verrouillé (circulaire, rectangulaire, en ligne).",
         "Un fournisseur pour tous les types (`DesignProvider`), configuration « Modifier le widget » (`DesignWidgetIntent`).",
         "Rendu : `WidgetCanvas`, tuiles par domaine (`Tile`, `TileFactory`, `TileView`), widgets d'écran verrouillé (`AccessoryViews`).",
         "QuickWidget : le dernier design enregistré, sans configuration.",
     ],
     "sources": ["Widgets/TesseraWidgetsBundle.swift", "Widgets/DesignProvider.swift", "Widgets/DesignWidgets.swift", "Widgets/QuickWidget.swift",
                 "Widgets/WorkoutLiveActivityWidget.swift", "Shared/Render/WidgetCanvas.swift", "Shared/Render/Tiles/TileView.swift", "Shared/Render/Tiles/TileFactory.swift",
                 "Shared/Render/Tiles/Tile.swift", "Shared/Render/AccessoryViews.swift", "Shared/Render/StyleRendering.swift", "Shared/Model/WidgetKind.swift",
                 "Shared/Model/WidgetGroup.swift", "Shared/Model/KindCatalog.swift", "Shared/Intents/DesignIntent.swift", "Config/Widgets-Info.plist"],
     "links": [("Donnees-et-stockage", "lit le SharedStore"), ("Intents-et-activite-en-direct", "boutons interactifs"), ("Services-externes", "météo, crypto, taux de change au rafraîchissement"),
               ("Studio-editeur", "les designs")]},
    {"file": "Intents-et-activite-en-direct", "title": "Boutons des widgets, activité en direct et liens", "zone": "ios",
     "role": "Les actions qui changent les données sans ouvrir l'app (App Intents des widgets iOS 17), l'activité en direct de la séance et les liens profonds `tessera://`.",
     "features": [
         "Widgets interactifs : `AddWaterIntent`, `ToggleHabitIntent`, `ToggleTaskIntent`, `StartFocusIntent`, `StopFocusIntent` (InteractiveIntents).",
         "Espaces : `LogFoodIntent`, `QuickExpenseIntent`, `TogglePriorityIntent`, `ToggleProjectTaskIntent`, `ToggleAssignmentIntent`, `CounterStepIntent`, `GradeCardIntent`, `RevealCardIntent` (SpaceIntents).",
         "Activité en direct (ActivityKit) : `CompleteSetIntent` (Série faite), `PauseRestIntent`, `ResumeRestIntent`, `SkipRestIntent`.",
         "Liens profonds `tessera://` : design, premium, tâches, habitudes, eau, argent, météo, calendrier, Store, espace, scan-food ; reçus par `onOpenURL` puis `router.handle`.",
     ],
     "sources": ["Shared/Intents/InteractiveIntents.swift", "Shared/Intents/SpaceIntents.swift", "Shared/Intents/DesignIntent.swift", "Shared/Live/WorkoutLiveActivity.swift",
                 "Widgets/WorkoutLiveActivityWidget.swift", "Shared/Support/DeepLink.swift"],
     "links": [("Donnees-et-stockage", "écrivent dans le SharedStore"), ("Fitness", "séance en cours"), ("Noyau-AppModel", "liens reçus par le Router")]},
    {"file": "Premium-et-abonnements", "title": "Premium et abonnements", "zone": "metier",
     "role": "Achats StoreKit 2 : l'App Store fait foi, le résultat est mis en cache pour l'extension. Le paywall s'ouvre sur ce que la personne a touché.",
     "features": [
         "Produits (`Config/Tessera.storekit`) : `com.dakrsnyk.tessera.premium.lifetime` (achat unique), `.monthly` et `.yearly` (abonnements).",
         "Paywall contextuel (`PaywallContext`) : widget, limite de widgets ou d'habitudes, historique, écran d'accueil, pack.",
         "Limites gratuites (8 widgets, 5 habitudes), accents gratuits (`Palette`), cadenas Premium (`PremiumLock`).",
         "Builds DEBUG : déverrouillage de test (`DebugPremium`), jamais en Release (vérifié par `scripts/check_swift.py` et la CI).",
     ],
     "sources": ["App/Premium/PremiumStore.swift", "App/Premium/PaywallView.swift", "App/Premium/PaywallContext.swift", "App/Premium/PremiumLock.swift",
                 "App/Premium/PremiumConfiguration.swift", "Shared/Theme/Palette.swift", "Shared/Support/DebugPremium.swift", "Config/Tessera.storekit"],
     "links": [("Services-externes", "StoreKit / App Store"), ("Noyau-AppModel", "état Premium, limites"), ("Store", "packs Premium"), ("Studio-editeur", "styles Premium")]},
    {"file": "Profil-et-reglages", "title": "Profil et réglages", "zone": "interface",
     "role": "Le profil (qui est la personne, ses chiffres) et tous les réglages de l'app.",
     "features": [
         "Informations de la personne et données demandées là où un widget les utilise.",
         "Rappels intelligents (séance, repas, factures), notifications locales.",
         "Icône de l'app (19 icônes), style de l'app (10 styles `AppStyleID`, clair/sombre).",
         "Sauvegarde et import, aide (tutoriel), note de l'app.",
     ],
     "sources": ["App/Screens/Profile/ProfileView.swift", "App/Screens/Profile/ProfileTopics.swift", "App/Screens/Profile/DataItemViews.swift",
                 "App/Screens/Profile/SmartRemindersView.swift", "App/Screens/Profile/AppIconPicker.swift", "App/Core/AppIcons.swift", "Shared/Model/Settings.swift",
                 "Shared/Theme/AppStyle.swift", "Shared/Support/SmartReminders.swift", "App/Services/NotificationScheduler.swift", "Shared/Model/ReviewPrompt.swift"],
     "links": [("Donnees-et-stockage", "sauvegarde"), ("Services-externes", "UserNotifications"), ("Onboarding-et-tutoriel", "aide")]},
    {"file": "Onboarding-et-tutoriel", "title": "Lancement, premier lancement et tutoriel", "zone": "interface",
     "role": "L'écran de lancement (le logo), les questions du premier lancement et la visite guidée.",
     "features": ["Écran de lancement : les deux moitiés du A.", "Premier lancement : style de l'app, profil, centres d'intérêt.", "Tutoriel par étapes au-dessus de l'app."],
     "sources": ["App/Screens/Launch/LaunchView.swift", "App/Screens/Onboarding/OnboardingView.swift", "App/Screens/Tutorial/Tutorial.swift", "App/Screens/Tutorial/TutorialOverlay.swift"],
     "links": [("Profil-et-reglages", "le tutoriel se relance depuis l'aide"), ("Noyau-AppModel", "")]},
    {"file": "Services-externes", "title": "Services externes et frameworks Apple", "zone": "services",
     "role": "Ce qui sort de l'appareil (API web, sans compte) et les frameworks système utilisés.",
     "features": [
         "Open Food Facts (`world.openfoodfacts.org`) : recherche et code-barres — `FoodDatabase`, appelé par `NutritionSpace`.",
         "Open-Meteo (`api.open-meteo.com`) : météo — `WeatherService` (AppModel, PayloadLoader, DesignProvider, Voyage).",
         "CoinGecko (`api.coingecko.com`) : crypto — `CryptoService`, `MarketService`.",
         "Finnhub (`finnhub.io`) : cours des actions — `MarketService`.",
         "SEC (`data.sec.gov`, `www.sec.gov`) : données des sociétés cotées — `CompanyService`.",
         "Frankfurter (`api.frankfurter.dev`) : taux de change — `FXService`.",
         "Frameworks : StoreKit, WidgetKit, ActivityKit, AppIntents, VisionKit et Vision (scanner), EventKit (calendrier), CoreLocation (ville), CoreMotion (pas), UserNotifications, Charts, PhotosUI, FoundationModels (`AIPhraser`, iOS 26).",
     ],
     "sources": ["Shared/Domains/FoodDatabase.swift", "Shared/Data/WeatherService.swift", "Shared/Data/CryptoService.swift", "Shared/Domains/Portfolio.swift",
                 "Shared/Domains/Companies.swift", "Shared/Domains/Travel.swift", "Shared/Data/CalendarService.swift", "App/Services/LocationService.swift",
                 "App/Core/StepCounter.swift", "App/Services/AIPhraser.swift", "App/Services/NotificationScheduler.swift", "App/Premium/PremiumStore.swift"],
     "links": [("Noyau-AppModel", "caches réseau"), ("Widgets-extension", "rafraîchissement des widgets"), ("Nutrition", "Open Food Facts"), ("Premium-et-abonnements", "StoreKit")]},
    {"file": "Outils-partages", "title": "Outils partagés (Shared/Support)", "zone": "outils",
     "role": "Petits outils communs à l'app et à l'extension : couleurs, dates, formats, décodage tolérant, diagnostic des widgets.",
     "features": ["Couleurs hexadécimales, calculs de dates, formats de nombres et de dates selon la langue.", "Diagnostic des widgets manquants (builds de test), droits signés de l'App Group."],
     "sources": ["Shared/Support/ColorHex.swift", "Shared/Support/DateMath.swift", "Shared/Support/Formatting.swift", "Shared/Support/Helpers.swift",
                 "Shared/Support/WidgetDiagnostics.swift", "Shared/Support/SignedEntitlements.swift"],
     "links": [("Donnees-et-stockage", "App Group"), ("Localisation", "formats selon la langue")]},
    {"file": "Localisation", "title": "Localisation", "zone": "outils",
     "role": "Le code est écrit en français ; `tr(\"texte\")` cherche ce texte comme clé dans le catalogue. Langues : fr (source), en, es, de, it, pt-BR, ja.",
     "features": ["Catalogue `Shared/Localizable.xcstrings`, textes d'Info.plist `App/InfoPlist.xcstrings`.", "Traductions en lots dans `l10n/`, glossaire, scripts `l10n_*`."],
     "sources": ["Shared/Support/Localization.swift", "Shared/Support/Formatting.swift", "Shared/Localizable.xcstrings", "App/InfoPlist.xcstrings", "l10n/GLOSSARY.md",
                 "scripts/l10n_catalog.py", "scripts/l10n_scan.py"],
     "links": [("Tests-CI-et-outils", "vérifié par la CI (l10n sync)")]},
    {"file": "Tests-CI-et-outils", "title": "Tests, CI et outils", "zone": "outils",
     "role": "Pas de Mac : tout se compile et se teste sur GitHub Actions, piloté par des tags dans le message de commit. Outils DEBUG de captures.",
     "features": [
         "Cibles : Tessera (app), TesseraWidgets (extension), TesseraTests (21 fichiers), TesseraUITests (7 fichiers).",
         "Workflow `.github/workflows/build.yml` : `[check]`, `[unit]`, `[daily]`, `[studio]`, `[apps]`, `[shots]`, `[langs]`, `[store]`, `[marketing]`, `[video]`, `[adkit]`…",
         "`scripts/check_swift.py` : ordre des labels d'init, catalogue de kinds, sécurité Release, manifeste de confidentialité.",
         "Outils DEBUG : `ScreenshotMode` (-screenshotScreen), `MarketingShots`, `StudioGallery`, `DemoGallery`, `AdExport` ; pubs dans `scripts/ads/`.",
     ],
     "sources": [".github/workflows/build.yml", "scripts/check_swift.py", "scripts/ci_report.sh", "App/Core/ScreenshotMode.swift", "App/Core/MarketingShots.swift",
                 "App/Core/StudioGallery.swift", "App/Core/DemoGallery.swift", "App/Core/AdExport.swift", "Tessera.xcodeproj/project.pbxproj", "HANDOFF.md"],
     "links": [("Localisation", ""), ("Premium-et-abonnements", "sécurité Release du déverrouillage DEBUG")]},
]
BY_FILE = {m["file"]: m for m in MODULES}

ZONES = {
    "interface": ("Interface (App/Screens)", "5"),
    "metier": ("Logique métier et état", "4"),
    "donnees": ("Données et stockage", "3"),
    "ios": ("Widgets et système iOS", "6"),
    "services": ("Services externes", "2"),
    "outils": ("Qualité et outillage", None),
}


# ----------------------------------------------------------------------------------------------- notes
def rel_from(folder, path):
    return os.path.relpath(os.path.join(ROOT, path), folder).replace(os.sep, "/")


def write_note(m, files=(), deps=None, services=None):
    zone_label = ZONES[m["zone"]][0]
    lines = ["---", f"tags: [ardane, module, zone/{m['zone']}]", "---", "", f"# {m['title']}", "", f"Zone : **{zone_label}** · Cartes : [[Vue-Globale.canvas|Vue globale]] · "
             "[[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]", "", m["role"], "", "## Ce qui existe (vérifié dans le code)", ""]
    lines += [f"- {f}" for f in m["features"]]
    lines += ["", "## Fichiers sources", ""]
    lines += [f"- [{p}]({rel_from(NOTES, p)})" for p in m["sources"]]
    lines += ["", "## Relations", ""]
    for target, text in m["links"]:
        lines.append(f"- [[{target}]]" + (f" : {text}" if text else ""))
    if files:
        lines += ["", f"## Fichiers du module ({len(files)})", ""] + [f"- [[{code_note_name(p)}]]" for p in files]
    if deps:
        # Measured in the code: how many of the other module's files this module's files use.
        lines += ["", "## Dépend de (mesuré dans le code)", ""]
        # The three strongest are links (the graph stays readable), the others plain text.
        ranked = sorted(deps.items(), key=lambda kv: (-len(kv[1]), kv[0]))
        lines += [(f"- [[{other}]]" if i < 3 else f"- {BY_FILE[other]['title']}") + f" : {len(used)} fichier(s)" for i, (other, used) in enumerate(ranked)]
    if services:
        lines += ["", "## Services et frameworks", ""]
        lines += [f"- [[{name}]] : {len(users)} fichier(s)" for name, users in sorted(services.items(), key=lambda kv: (-len(kv[1]), kv[0]))]
    lines += ["", "Partie de [[Ardane]]."]
    lines += ["", "> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).", ""]
    open(os.path.join(NOTES, m["file"] + ".md"), "w").write("\n".join(lines))


# ----------------------------------------------------------------------------------------------- canvas
class Canvas:
    def __init__(self):
        self.nodes, self.edges, self._ids = [], [], set()

    def _id(self, base):
        base = re.sub(r"[^a-z0-9]+", "-", base.lower()).strip("-")[:40] or "n"
        i, cand = 1, base
        while cand in self._ids:
            i += 1
            cand = f"{base}-{i}"
        self._ids.add(cand)
        return cand

    def text(self, key, x, y, w, h, text, color=None):
        node = {"id": self._id(key), "type": "text", "x": int(x), "y": int(y), "width": int(w), "height": int(h), "text": text}
        if color:
            node["color"] = color
        self.nodes.append(node)
        return node["id"]

    def group(self, key, x, y, w, h, label, color=None):
        node = {"id": self._id("g-" + key), "type": "group", "x": int(x), "y": int(y), "width": int(w), "height": int(h), "label": label}
        if color:
            node["color"] = color
        # Groups first: Obsidian draws nodes in order, groups must sit under their content.
        self.nodes.insert(0, node)
        return node["id"]

    def box(self, node_id):
        return next(n for n in self.nodes if n["id"] == node_id)

    def edge(self, a, b, label=None, color=None):
        na, nb = self.box(a), self.box(b)
        ax, ay = na["x"] + na["width"] / 2, na["y"] + na["height"] / 2
        bx, by = nb["x"] + nb["width"] / 2, nb["y"] + nb["height"] / 2
        dx, dy = bx - ax, by - ay
        if abs(dx) * na["height"] > abs(dy) * na["width"]:
            fs, ts = ("right", "left") if dx > 0 else ("left", "right")
        else:
            fs, ts = ("bottom", "top") if dy > 0 else ("top", "bottom")
        e = {"id": self._id(f"e-{a}-{b}"), "fromNode": a, "fromSide": fs, "toNode": b, "toSide": ts, "toEnd": "arrow"}
        if label:
            e["label"] = label
        if color:
            e["color"] = color
        self.edges.append(e)

    def save(self, name):
        # Obsidian's own layout (one node or edge per line, tabs): opening a map in Obsidian no longer
        # rewrites the whole file and leaves changes to discard before pulling.
        row = lambda item: json.dumps(item, ensure_ascii=False, separators=(",", ":"))
        with open(os.path.join(OUT, name), "w") as f:
            f.write('{\n\t"nodes":[\n' + ",\n".join("\t\t" + row(n) for n in self.nodes) + '\n\t],\n\t"edges":[\n'
                    + ",\n".join("\t\t" + row(e) for e in self.edges) + "\n\t]\n}")


def src_links(paths, limit=None, base=OUT):
    shown = paths if limit is None else paths[:limit]
    return "\n".join(f"- [{os.path.basename(p)}]({rel_from(base, p)})" for p in shown)


def grid(cv, items, x0, y0, cols, w, h, gx=40, gy=40):
    """items: list of (key, text, color); returns the ids and the box (x, y, w, h) around them."""
    ids = []
    for i, (key, text, color) in enumerate(items):
        r, c = divmod(i, cols)
        ids.append(cv.text(key, x0 + c * (w + gx), y0 + r * (h + gy), w, h, text, color))
    rows = (len(items) + cols - 1) // cols
    return ids, (x0, y0, cols * w + (cols - 1) * gx, rows * h + (rows - 1) * gy)


def framed(cv, key, label, color, items, x0, y0, cols, w, h, pad=50):
    ids, (x, y, bw, bh) = grid(cv, items, x0 + pad, y0 + pad + 30, cols, w, h)
    gid = cv.group(key, x0, y0, bw + 2 * pad, bh + 2 * pad + 30, label, color)
    return gid, ids


def module_card(key, extra_sources=2):
    m = BY_FILE[key]
    head = f"## {m['title']}\n[[{m['file']}|Ouvrir la note]]\n\n"
    body = "\n".join(f"- {f}" for f in m["features"][:3])
    return head + body + "\n\n**Sources**\n" + src_links(m["sources"], extra_sources)


# --- 1. Vue globale ---------------------------------------------------------------------------------
def vue_globale():
    cv = Canvas()
    center = cv.text("ardane", -330, -170, 660, 340,
                     "# Ardane\n*(anciennement Tessera : projet, cibles, module et identifiants gardent « Tessera »)*\n\n"
                     "App iOS 17 en SwiftUI de widgets et de mini-apps pour les essentiels du quotidien : nutrition, sport, argent, planning, habitudes…\n\n"
                     "[[docs/obsidian/README|Guide]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]", "6")
    W, H = 420, 330
    zones = {}
    # Interface, above the center.
    ui = ["Accueil-Mon-Quotidien", "Mini-apps", "Creer-espaces", "Store", "Studio-editeur", "Mes-widgets", "Profil-et-reglages", "Onboarding-et-tutoriel"]
    gid, ids = framed(cv, "interface", ZONES["interface"][0], ZONES["interface"][1], [(k, module_card(k), None) for k in ui], -(4 * W + 3 * 40 + 100) // 2, -1250, 4, W, H)
    zones["interface"] = gid
    ui_ids = dict(zip(ui, ids))
    # Business logic, left.
    gid, ids = framed(cv, "metier", ZONES["metier"][0], ZONES["metier"][1],
                      [(k, module_card(k), None) for k in ["Noyau-AppModel", "Domaines-metier", "Premium-et-abonnements"]], -1900, -140, 1, W + 60, H + 40)
    zones["metier"] = gid
    met = dict(zip(["Noyau-AppModel", "Domaines-metier", "Premium-et-abonnements"], ids))
    # Data, below.
    data_items = [
        ("Donnees-et-stockage", module_card("Donnees-et-stockage", 3), None),
        ("ressources", "## Ressources embarquées\n- Base alimentaire CNF (~5 600 aliments)\n- Démos d'exercices (163)\n- Catalogue de traductions\n\n**Sources**\n"
         + src_links(["App/Resources/cnf-foods.json", "App/Resources/ExerciseDemos.json", "Shared/Localizable.xcstrings"]), None),
    ]
    gid, ids = framed(cv, "donnees", ZONES["donnees"][0], ZONES["donnees"][1], data_items, -500, 1350, 2, W + 60, H + 40)
    zones["donnees"] = gid
    store_id, res_id = ids
    # iOS, right.
    gid, ids = framed(cv, "ios", ZONES["ios"][0], ZONES["ios"][1],
                      [(k, module_card(k), None) for k in ["Widgets-extension", "Intents-et-activite-en-direct"]], 900, -140, 1, W + 60, H + 40)
    zones["ios"] = gid
    ios = dict(zip(["Widgets-extension", "Intents-et-activite-en-direct"], ids))
    # Services, bottom right.
    svc_items = [
        ("api", "## API web (sans compte)\n- Open Food Facts : aliments, codes-barres\n- Open-Meteo : météo\n- CoinGecko : crypto\n- Finnhub : actions\n- SEC : sociétés cotées\n- Frankfurter : taux de change\n\n[[Services-externes|Ouvrir la note]]", None),
        ("apple", "## Frameworks Apple\n- StoreKit 2 (Premium)\n- WidgetKit, ActivityKit, AppIntents\n- VisionKit (scanner)\n- EventKit, CoreLocation, CoreMotion\n- UserNotifications, Charts\n- FoundationModels (iOS 26)\n\n[[Services-externes|Ouvrir la note]]", None),
    ]
    gid, ids = framed(cv, "services", ZONES["services"][0], ZONES["services"][1], svc_items, 900, 1350, 2, W, H + 40)
    zones["services"] = gid
    api_id, apple_id = ids
    # Tooling, bottom left.
    gid, ids = framed(cv, "outils", ZONES["outils"][0], None,
                      [(k, module_card(k), None) for k in ["Tests-CI-et-outils", "Localisation"]], -1900, 1350, 1, W + 60, H + 40)
    zones["outils"] = gid
    tools = dict(zip(["Tests-CI-et-outils", "Localisation"], ids))
    # Sub-features, in their own groups above the interface.
    subs = [
        ("Nutrition", "Nutrition", ["Anneau et macros du jour", "Recherche + base CNF", "Scanner de code-barres", "Widget « Scanner »"]),
        ("Fitness", "Fitness", ["Séance en direct, Série faite", "Repos minuté", "Activité en direct", "163 exercices animés"]),
        ("Planning-et-habitudes", "Planning et habitudes", ["Semaine en tableau", "Tâches et Top 3", "Études", "Habitudes et eau"]),
        ("Finances", "Finances", ["Graphique du solde", "Reste du mois", "Catégories, factures", "Épargne, valeur nette"]),
        ("Autres-mini-apps", "Autres mini-apps", ["Business", "Voyage (devises)", "Auto", "Météo, placements"]),
    ]
    x = -(len(subs) * 740 + (len(subs) - 1) * 60) // 2
    sub_groups = {}
    for key, label, items in subs:
        gid, ids = framed(cv, "sub-" + key, label, None, [(f"{key}-{i}", f"**{t}**", None) for i, t in enumerate(items)], x, -2330, 2, 300, 110)
        note = cv.text("note-" + key, x + 50, -2330 + 50 + 30 + 2 * (110 + 40), 640, 90, f"[[{key}|Ouvrir la note {label}]]\n" + src_links(BY_FILE[key]["sources"], 1))
        box = cv.box(gid)
        box["height"] += 130
        sub_groups[key] = gid
        x += box["width"] + 60
    # Edges: center to the zones.
    for z, label in [("interface", "écrans"), ("metier", "état et règles"), ("donnees", "stockage"), ("ios", "widgets et système"), ("services", "réseau et frameworks"), ("outils", "qualité")]:
        cv.edge(center, zones[z], label)
    # Module relations (verified in the code).
    cv.edge(zones["interface"], met["Noyau-AppModel"], "lit et écrit l'état", "5")
    cv.edge(ui_ids["Store"], ui_ids["Studio-editeur"], "ouvre un modèle")
    cv.edge(ui_ids["Mes-widgets"], ui_ids["Studio-editeur"], "modifier")
    cv.edge(ui_ids["Creer-espaces"], ui_ids["Studio-editeur"], "créer")
    cv.edge(ui_ids["Accueil-Mon-Quotidien"], ui_ids["Mini-apps"], "ouvre")
    for key in sub_groups:
        cv.edge(sub_groups[key], zones["interface"], None, "5")
    cv.edge(met["Noyau-AppModel"], met["Domaines-metier"], "états")
    cv.edge(met["Noyau-AppModel"], store_id, "écrit en JSON", "3")
    cv.edge(store_id, ios["Widgets-extension"], "lu par l'extension", "6")
    cv.edge(met["Noyau-AppModel"], ios["Widgets-extension"], "recharge (WidgetCenter)", "6")
    cv.edge(ios["Intents-et-activite-en-direct"], store_id, "écrit sans ouvrir l'app", "3")
    cv.edge(met["Premium-et-abonnements"], apple_id, "StoreKit 2", "2")
    cv.edge(met["Domaines-metier"], api_id, "requêtes réseau", "2")
    cv.edge(ios["Widgets-extension"], api_id, "rafraîchit météo, crypto, taux", "2")
    cv.edge(res_id, met["Domaines-metier"], "aliments, démos")
    cv.edge(tools["Tests-CI-et-outils"], zones["interface"], "captures et tests")
    cv.save("Vue-Globale.canvas")


# --- 2. Architecture -------------------------------------------------------------------------------
def architecture():
    cv = Canvas()
    title = cv.text("titre", -400, -1450, 800, 160,
                    "# Architecture technique\nCouches de l'app, cibles Xcode et dépendances (vérifiées dans le code).\n[[Vue-Globale.canvas|← Vue globale]] · [[docs/obsidian/README|Guide]]", "6")
    W = 460
    layers = []
    # Layer 1: UI.
    ui = [("app-entry", "### Point d'entrée\n`TesseraApp` → `RootView` (lancement, onglets, feuilles, `onOpenURL`)\n" + src_links(["App/TesseraApp.swift"]), None),
          ("tabs", "### Onglets\nAccueil · Créer · Store · Mes widgets\n[[Accueil-Mon-Quotidien]] · [[Creer-espaces]] · [[Store]] · [[Mes-widgets]]", None),
          ("screens", "### Écrans\nMini-apps, Studio, Profil, Premium, tutoriel\n[[Mini-apps]] · [[Studio-editeur]] · [[Profil-et-reglages]] · [[Premium-et-abonnements]]", None),
          ("components", "### Composants\nAperçus de widgets à taille réelle, sélecteur de style\n" + src_links(["App/Components/UIComponents.swift", "App/Components/StylePicker.swift"]), None)]
    g, ui_ids = framed(cv, "l-ui", "1. Interface — SwiftUI (cible Tessera)", "5", ui, -1100, -1180, 4, W, 230)
    # Layer 2: state & navigation.
    st = [("appmodel", "### AppModel\n@Observable, @MainActor : source unique, écrit tout, recharge les widgets, caches réseau\n[[Noyau-AppModel]]\n" + src_links(["App/Core/AppModel.swift"]), None),
          ("router", "### Router\nOnglet, feuilles, Studio, paywall, liens `tessera://`\n" + src_links(["App/Core/Router.swift", "Shared/Support/DeepLink.swift"]), None),
          ("premiumstore", "### PremiumStore\nStoreKit 2, droits en cache pour l'extension\n[[Premium-et-abonnements]]\n" + src_links(["App/Premium/PremiumStore.swift"]), None),
          ("daily", "### Mon Quotidien et analyses\nBrief du jour, agenda, analyses écrites depuis les données\n" + src_links(["App/Core/DailyBrief.swift", "Shared/Data/Insights.swift"]), None)]
    g, st_ids = framed(cv, "l-state", "2. État, navigation, achats (App/Core, App/Premium)", "4", st, -1100, -760, 4, W, 260)
    # Layer 3: domains & models (Shared).
    dm = [("domains", "### Domaines\n11 états métier + profil\n[[Domaines-metier]]\n" + src_links(["Shared/Domains/Nutrition.swift", "Shared/Domains/Fitness.swift", "Shared/Domains/Budget.swift"]), None),
          ("models", "### Modèle de widget\n`WidgetDesign`, `WidgetKind` (103), styles (57), palettes, packs, modèles\n" + src_links(["Shared/Model/WidgetDesign.swift", "Shared/Model/WidgetKind.swift", "Shared/Model/WidgetStyle.swift"]), None),
          ("render", "### Rendu partagé\n`WidgetCanvas`, tuiles, écran verrouillé, thèmes\n[[Widgets-extension]]\n" + src_links(["Shared/Render/WidgetCanvas.swift", "Shared/Theme/Theme.swift"]), None),
          ("support", "### Support\nFormats, dates, couleurs, `tr()`, rappels\n[[Localisation]]\n" + src_links(["Shared/Support/Localization.swift", "Shared/Support/SmartReminders.swift"]), None)]
    g, dm_ids = framed(cv, "l-shared", "3. Code partagé app + extension (Shared/)", "4", dm, -1100, -320, 4, W, 270)
    # Layer 4: persistence.
    ps = [("sharedstore", "### SharedStore\nJSON par domaine dans l'App Group `group.com.dakrsnyk.tessera`, dossier `Tessera/`\n[[Donnees-et-stockage]]\n" + src_links(["Shared/Support/SharedStore.swift"]), None),
          ("payload", "### Données des widgets\n`PayloadLoader`, `DataNeeds`, `DomainData`, `SampleData`\n" + src_links(["Shared/Data/PayloadLoader.swift", "Shared/Data/DomainData.swift"]), None),
          ("backup", "### Sauvegarde\nUn fichier qui contient tout ; import des sauvegardes Tessera\n" + src_links(["App/Core/DataBackup.swift"]), None),
          ("resources", "### Ressources\nCNF, démos d'exercices, StoreKit, entitlements\n" + src_links(["App/Resources/cnf-foods.json", "App/Resources/ExerciseDemos.json", "Config/Tessera.storekit", "Config/Tessera.entitlements"]), None)]
    g, ps_ids = framed(cv, "l-data", "4. Persistance et ressources", "3", ps, -1100, 140, 4, W, 270)
    # Extension, right.
    ex = [("bundle", "### TesseraWidgetsBundle\nLes widgets de l'extension (groupes par domaine, horloge, calendrier, tâches…) et l'activité en direct\n" + src_links(["Widgets/TesseraWidgetsBundle.swift", "Widgets/DesignWidgets.swift"]), None),
          ("provider", "### DesignProvider\nUn fournisseur pour tous les types ; lit le SharedStore, rafraîchit météo, crypto, taux\n" + src_links(["Widgets/DesignProvider.swift"]), None),
          ("intents", "### App Intents\nBoutons des widgets, activité en direct, configuration\n[[Intents-et-activite-en-direct]]\n" + src_links(["Shared/Intents/SpaceIntents.swift", "Shared/Intents/InteractiveIntents.swift"]), None),
          ("live", "### Activité en direct\nActivityKit : séance sur l'écran verrouillé et la Dynamic Island\n" + src_links(["Shared/Live/WorkoutLiveActivity.swift", "Widgets/WorkoutLiveActivityWidget.swift"]), None)]
    g, ex_ids = framed(cv, "l-ext", "Extension WidgetKit (cible TesseraWidgets)", "6", ex, 1100, -760, 1, W, 230)
    # Services, far right.
    sv = [("net", "### Réseau\nOpen Food Facts · Open-Meteo · CoinGecko · Finnhub · SEC · Frankfurter\n[[Services-externes]]", None),
          ("fw", "### Frameworks\nStoreKit · WidgetKit · ActivityKit · AppIntents · VisionKit · EventKit · CoreLocation · CoreMotion · UserNotifications · Charts · FoundationModels", None)]
    g, sv_ids = framed(cv, "l-svc", "Services externes", "2", sv, 1100, 520, 1, W, 210)
    # Build & CI, bottom.
    ci = [("targets", "### Cibles Xcode\nTessera · TesseraWidgets · TesseraTests (21) · TesseraUITests (7)\nDossiers synchronisés : un nouveau fichier rejoint sa cible\n" + src_links(["Tessera.xcodeproj/project.pbxproj"]), None),
          ("ci", "### CI GitHub Actions\nTags dans le message de commit\n[[Tests-CI-et-outils]]\n" + src_links([".github/workflows/build.yml", "scripts/check_swift.py"]), None),
          ("debug", "### Outils DEBUG\nCaptures, galeries, export pub (jamais en Release)\n" + src_links(["App/Core/ScreenshotMode.swift", "App/Core/AdExport.swift"]), None)]
    g, ci_ids = framed(cv, "l-ci", "Construction, tests, qualité", None, ci, -1100, 600, 3, W + 120, 230)
    a = dict(zip(["entry", "tabs", "screens", "components"], ui_ids))
    s = dict(zip(["appmodel", "router", "premiumstore", "daily"], st_ids))
    d = dict(zip(["domains", "models", "render", "support"], dm_ids))
    p = dict(zip(["sharedstore", "payload", "backup", "resources"], ps_ids))
    e = dict(zip(["bundle", "provider", "intents", "live"], ex_ids))
    n = dict(zip(["net", "fw"], sv_ids))
    cv.edge(a["entry"], s["appmodel"], "crée et injecte", "5")
    cv.edge(a["tabs"], s["router"], "navigation", "5")
    cv.edge(a["screens"], s["appmodel"], "lit / écrit", "5")
    cv.edge(s["appmodel"], d["domains"], "états métier", "4")
    cv.edge(s["appmodel"], p["sharedstore"], "écrit chaque domaine", "3")
    cv.edge(s["appmodel"], e["bundle"], "WidgetCenter.reload", "6")
    cv.edge(s["premiumstore"], n["fw"], "StoreKit 2", "2")
    cv.edge(p["sharedstore"], e["provider"], "lit", "6")
    cv.edge(e["provider"], d["render"], "WidgetCanvas", "6")
    cv.edge(e["provider"], n["net"], "rafraîchit les caches", "2")
    cv.edge(e["intents"], p["sharedstore"], "écrit", "3")
    cv.edge(e["live"], e["intents"], "Série faite, pause, passer", "6")
    cv.edge(d["domains"], n["net"], "requêtes", "2")
    cv.edge(p["payload"], d["render"], "données des widgets")
    cv.edge(p["resources"], d["domains"], "aliments, démos")
    cv.edge(a["components"], d["render"], "aperçus réels")
    cv.edge(ci_ids[1], ci_ids[0], "compile et teste")
    cv.save("Architecture.canvas")


# --- 3. Fonctionnalités -----------------------------------------------------------------------------
def fonctionnalites():
    cv = Canvas()
    cv.text("titre", -400, -1250, 800, 150,
            "# Fonctionnalités\nChaque zone : une partie d'Ardane et ses sous-fonctionnalités, avec les fichiers sources.\n[[Vue-Globale.canvas|← Vue globale]] · [[docs/obsidian/README|Guide]]", "6")
    areas = [
        ("Accueil-Mon-Quotidien", "Accueil — Mon Quotidien", "5", [
            ("Cartes du jour", ["App/Screens/Home/DailySection.swift", "App/Core/DailyBrief.swift"]),
            ("Cartes à plusieurs vues", ["App/Screens/Home/DailyPager.swift"]),
            ("Disposition à la main", ["App/Screens/Home/DailyLayoutEditor.swift"]),
            ("Mes informations", ["App/Screens/Home/MyInfoCenter.swift"])]),
        ("Widgets-extension", "Widgets", "6", [
            ("103 types, 3 tailles + écran verrouillé", ["Shared/Model/WidgetKind.swift"]),
            ("Rendu des tuiles", ["Shared/Render/Tiles/TileView.swift"]),
            ("Boutons interactifs", ["Shared/Intents/SpaceIntents.swift"]),
            ("Combinés et fusion", ["Shared/Model/Combo.swift", "App/Screens/MyWidgets/FusionViews.swift"])]),
        ("Studio-editeur", "Studio", "5", [
            ("57 styles, 16 thèmes", ["Shared/Model/WidgetStyle.swift"]),
            ("14 palettes, couleurs", ["Shared/Model/StyleColors.swift"]),
            ("Fond, texture, bordure", ["App/Screens/Editor/StudioPanels.swift"]),
            ("Réglages du type", ["App/Screens/Editor/KindOptionsSection.swift"])]),
        ("Store", "Store", "5", [
            ("23 écrans d'accueil prêts", ["App/Screens/Explore/HomeSetups.swift"]),
            ("18 fonds dessinés", ["App/Screens/Explore/SetupWallpapers.swift"]),
            ("34 packs et saisons", ["Shared/Model/Packs.swift"]),
            ("Combinés, modèles", ["App/Screens/Explore/StoreCombos.swift", "Shared/Model/Templates.swift"])]),
        ("Nutrition", "Nutrition", "4", [
            ("Calories et macros", ["App/Screens/MiniApps/Nutrition/NutritionApp.swift"]),
            ("Recherche et base CNF", ["App/Screens/Spaces/NutritionSpace.swift", "App/Core/NutrientFile.swift"]),
            ("Scanner de code-barres", ["App/Screens/Spaces/NutritionSpace.swift", "Shared/Domains/FoodDatabase.swift"]),
            ("Repas, idées, historique", ["App/Screens/MiniApps/Nutrition/NutritionPages.swift"])]),
        ("Fitness", "Fitness", "4", [
            ("Séance en direct, Série faite", ["App/Screens/MiniApps/Fitness/FitnessSession.swift"]),
            ("Activité en direct", ["Shared/Live/WorkoutLiveActivity.swift"]),
            ("Bibliothèque et démos", ["App/Screens/MiniApps/Fitness/ExerciseLibraryViews.swift", "App/Screens/MiniApps/Fitness/ExerciseDemo.swift"]),
            ("Programme, progression", ["App/Screens/MiniApps/Fitness/FitnessPages.swift"])]),
        ("Planning-et-habitudes", "Planning et habitudes", "4", [
            ("Semaine en tableau", ["App/Screens/MiniApps/Planning/PlanningApp.swift", "App/Screens/MiniApps/WeekViews.swift"]),
            ("Tâches, Top 3, projets", ["App/Screens/MiniApps/Planning/PlanningPages.swift"]),
            ("Études", ["App/Screens/MiniApps/Studies/StudiesPages.swift"]),
            ("Habitudes et eau", ["App/Screens/Content/HabitsView.swift", "App/Screens/Content/HydrationView.swift"])]),
        ("Finances", "Finances", "4", [
            ("Graphique du solde", ["App/Screens/MiniApps/Finances/FinancesApp.swift"]),
            ("Catégories, factures", ["App/Screens/MiniApps/Finances/FinancesPages.swift"]),
            ("Saisie des dépenses", ["App/Screens/Spaces/BudgetSpace.swift"]),
            ("Règles de budget", ["Shared/Domains/Budget.swift"])]),
        ("Premium-et-abonnements", "Abonnements Premium", "2", [
            ("Achats StoreKit 2", ["App/Premium/PremiumStore.swift", "Config/Tessera.storekit"]),
            ("Paywall contextuel", ["App/Premium/PaywallContext.swift", "App/Premium/PaywallView.swift"]),
            ("Cadenas et limites", ["App/Premium/PremiumLock.swift", "App/Core/AppModel.swift"]),
            ("Configuration App Store", ["App/Premium/PremiumConfiguration.swift"])]),
        ("Profil-et-reglages", "Profil et réglages", "3", [
            ("Profil et données", ["App/Screens/Profile/ProfileView.swift", "App/Screens/Profile/DataItemViews.swift"]),
            ("Rappels intelligents", ["App/Screens/Profile/SmartRemindersView.swift", "Shared/Support/SmartReminders.swift"]),
            ("Icône et style de l'app", ["App/Screens/Profile/AppIconPicker.swift", "Shared/Model/Settings.swift"]),
            ("Sauvegarde", ["App/Core/DataBackup.swift"])]),
        ("Autres-mini-apps", "Autres mini-apps", None, [
            ("Business", ["App/Screens/MiniApps/Business/BusinessApp.swift"]),
            ("Voyage", ["App/Screens/MiniApps/Travel/TravelApp.swift"]),
            ("Auto", ["App/Screens/MiniApps/Car/CarApp.swift"]),
            ("Météo", ["App/Screens/MiniApps/Weather/WeatherApp.swift"])]),
        ("Onboarding-et-tutoriel", "Premier lancement", None, [
            ("Écran de lancement", ["App/Screens/Launch/LaunchView.swift"]),
            ("Questions du premier lancement", ["App/Screens/Onboarding/OnboardingView.swift"]),
            ("Tutoriel", ["App/Screens/Tutorial/Tutorial.swift"]),
            ("Icônes de l'app", ["App/Core/AppIcons.swift"])]),
    ]
    W, H = 330, 150
    cols_per_area = 2
    area_w = 50 * 2 + cols_per_area * W + 40
    gids = {}
    for i, (key, label, color, items) in enumerate(areas):
        r, c = divmod(i, 4)
        x0, y0 = -1600 + c * (area_w + 80), -1000 + r * 760
        texts = [(f"{key}-{j}", f"**{t}**\n" + src_links(paths), None) for j, (t, paths) in enumerate(items)]
        gid, ids = framed(cv, key, label, color, texts, x0, y0, cols_per_area, W, H)
        cv.text("note-" + key, x0 + 50, y0 + 50 + 30 + 2 * (H + 40), area_w - 100, 70, f"[[{key}|Ouvrir la note]]")
        cv.box(gid)["height"] += 110
        gids[key] = gid
    # Verified relations between areas.
    for a, b, label in [("Store", "Studio-editeur", "ouvre un modèle"), ("Studio-editeur", "Widgets-extension", "rendu du design"),
                        ("Accueil-Mon-Quotidien", "Nutrition", "carte et Scanner"), ("Fitness", "Widgets-extension", "activité en direct, boutons"),
                        ("Premium-et-abonnements", "Studio-editeur", "styles Premium"), ("Finances", "Premium-et-abonnements", "Évolution Premium"),
                        ("Profil-et-reglages", "Planning-et-habitudes", "rappels d'habitudes"), ("Accueil-Mon-Quotidien", "Planning-et-habitudes", "planning et habitudes")]:
        cv.edge(gids[a], gids[b], label)
    cv.save("Fonctionnalites.canvas")



# ----------------------------------------------------------------------------------------------- graph
# One note per Swift file, per external service and framework, and the hub « Ardane »: the links come from
# the code itself (a file uses a type declared in another file, imports a framework, calls a web API), so
# Obsidian's graph view draws the real dependency network of the project.
CODE = os.path.join(OUT, "code")
SERVICES_DIR = os.path.join(OUT, "services")
SWIFT_DIRS = ["App", "Shared", "Widgets", "Tests", "UITests"]
FALLBACK = [  # first matching prefix wins, after the modules' own source lists
    ("App/Screens/Home/", "Accueil-Mon-Quotidien"), ("App/Screens/MiniApps/Nutrition/", "Nutrition"), ("App/Screens/MiniApps/Fitness/", "Fitness"),
    ("App/Screens/MiniApps/Planning/", "Planning-et-habitudes"), ("App/Screens/MiniApps/Studies/", "Planning-et-habitudes"),
    ("App/Screens/MiniApps/Finances/", "Finances"), ("App/Screens/MiniApps/", "Autres-mini-apps"), ("App/Screens/Spaces/", "Creer-espaces"),
    ("App/Screens/Explore/", "Store"), ("App/Screens/Editor/", "Studio-editeur"), ("App/Screens/MyWidgets/", "Mes-widgets"),
    ("App/Screens/Profile/", "Profil-et-reglages"), ("App/Screens/Content/", "Planning-et-habitudes"), ("App/Screens/", "Onboarding-et-tutoriel"),
    ("App/Premium/", "Premium-et-abonnements"), ("App/Services/", "Services-externes"), ("App/Components/", "Widgets-extension"),
    ("App/Core/", "Noyau-AppModel"), ("App/", "Noyau-AppModel"), ("Shared/Domains/", "Domaines-metier"), ("Shared/Data/", "Donnees-et-stockage"),
    ("Shared/Render/", "Widgets-extension"), ("Shared/Model/", "Widgets-extension"), ("Shared/Theme/", "Studio-editeur"),
    ("Shared/Intents/", "Intents-et-activite-en-direct"), ("Shared/Live/", "Intents-et-activite-en-direct"), ("Shared/Support/", "Outils-partages"),
    ("Widgets/", "Widgets-extension"), ("Tests/", "Tests-CI-et-outils"), ("UITests/", "Tests-CI-et-outils"),
]
EXTERNAL = [  # name, kind, what it is, how a file shows it uses it (regex on its code)
    ("Open Food Facts", "api", "Base alimentaire ouverte : recherche d'aliments et codes-barres (world.openfoodfacts.org).", r"openfoodfacts\.org"),
    ("Open-Meteo", "api", "Prévisions météo (api.open-meteo.com).", r"open-meteo\.com"),
    ("CoinGecko", "api", "Cours des cryptomonnaies (api.coingecko.com).", r"coingecko\.com"),
    ("Finnhub", "api", "Cours des actions (finnhub.io).", r"finnhub\.io"),
    ("SEC EDGAR", "api", "Données financières des sociétés cotées américaines (data.sec.gov).", r"sec\.gov"),
    ("Frankfurter", "api", "Taux de change (api.frankfurter.dev).", r"frankfurter\.dev"),
    ("StoreKit", "framework", "Achats intégrés et abonnements (StoreKit 2).", r"^import StoreKit"),
    ("WidgetKit", "framework", "Widgets de l'écran d'accueil et de l'écran verrouillé.", r"^import WidgetKit"),
    ("ActivityKit", "framework", "Activités en direct (écran verrouillé, Dynamic Island).", r"^import ActivityKit"),
    ("AppIntents", "framework", "Actions des boutons de widgets et de l'activité en direct.", r"^import AppIntents"),
    ("VisionKit", "framework", "Scanner de codes-barres par la caméra.", r"^import VisionKit"),
    ("EventKit", "framework", "Lecture du calendrier.", r"^import EventKit"),
    ("CoreLocation", "framework", "Ville et position.", r"^import CoreLocation"),
    ("CoreMotion", "framework", "Nombre de pas.", r"^import CoreMotion"),
    ("UserNotifications", "framework", "Rappels et notifications locales.", r"^import UserNotifications"),
    ("Swift Charts", "framework", "Graphiques des mini-apps.", r"^import Charts"),
    ("FoundationModels", "framework", "Modèle d'Apple sur l'appareil (iOS 26).", r"^import FoundationModels"),
    ("PhotosUI", "framework", "Choix d'une photo.", r"^import PhotosUI"),
    ("App Group", "data", "Conteneur partagé `group.com.dakrsnyk.tessera` : un fichier JSON par domaine, lu par l'app et l'extension.", r"\bSharedStore\b"),
    ("Base alimentaire CNF", "data", "Fichier canadien sur les éléments nutritifs embarqué, ~5 600 aliments (App/Resources/cnf-foods.json).", r"cnf-foods"),
    ("Demos des exercices", "data", "Démonstrations animées des 163 exercices (App/Resources/ExerciseDemos.json).", r"\"ExerciseDemos\""),
]


def swift_files():
    found = []
    for d in SWIFT_DIRS:
        for base, _, files in os.walk(os.path.join(ROOT, d)):
            found += [os.path.relpath(os.path.join(base, f), ROOT).replace(os.sep, "/") for f in files if f.endswith(".swift")]
    return sorted(found)


def code_note_name(path):
    return os.path.basename(path)[:-6] + " (swift)"


def module_of(path):
    for m in MODULES:
        if path in m["sources"]:
            return m["file"]
    return next(mod for prefix, mod in FALLBACK if path.startswith(prefix))


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r'"""(.*?)"""', '""', text, flags=re.S)
    # String contents are text shown to people, not code: « Store » in a label is not the type Store.
    text = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', text)
    return "\n".join(line.split("//")[0] for line in text.splitlines())


def code_graph():
    files = swift_files()
    raw = {p: open(os.path.join(ROOT, p), encoding="utf-8").read() for p in files}
    code = {p: strip_comments(t) for p, t in raw.items()}
    declared = {}
    for p, text in code.items():
        for match in re.finditer(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |final |nonisolated )*(struct|class|enum|protocol|actor|typealias)\s+([A-Z]\w*)", text, re.M):
            declared.setdefault(match.group(2), p)
    uses, used_by, external = {}, {}, {}
    for p, text in code.items():
        names = set(re.findall(r"\b([A-Z]\w+)\b", text))
        targets = sorted({declared[n] for n in names if n in declared and declared[n] != p})
        uses[p] = targets
        for t in targets:
            used_by.setdefault(t, []).append(p)
        external[p] = [name for name, _, _, pattern in EXTERNAL if re.search(pattern, raw[p], re.M)]
    modules = {p: module_of(p) for p in files}
    # Graph shape: each module is a star (its files link to it and to each other); a dependency on another
    # module's file stays in the note as text, and the modules link to each other and to their services.
    # Linking every file to every file it uses (~1 600 links, half of them to tr(), Fmt, Color(hex:)…)
    # drew one tangle instead of clusters.
    service_users = {name: [p for p in files if name in external[p]] for name, _, _, _ in EXTERNAL}
    os.makedirs(CODE, exist_ok=True)
    os.makedirs(SERVICES_DIR, exist_ok=True)
    for old in os.listdir(CODE):
        os.remove(os.path.join(CODE, old))
    by_module, module_deps, module_services, link_count = {}, {}, {}, 0
    for p in files:
        mod = modules[p]
        by_module.setdefault(mod, []).append(p)
        zone = BY_FILE[mod]["zone"]
        doc = next((re.sub(r"^\s*///\s?", "", l) for l in raw[p].splitlines() if l.strip().startswith("///")), "")
        types = sorted(n for n, f in declared.items() if f == p)
        inside = [t for t in uses[p] if modules[t] == mod]
        outside = [t for t in uses[p] if modules[t] != mod]
        for t in outside:
            module_deps.setdefault(mod, {}).setdefault(modules[t], set()).add(t)
        for e in external[p]:
            module_services.setdefault(mod, {}).setdefault(e, []).append(p)
        lines = ["---", f"tags: [ardane, code, zone/{zone}]", f"source: {p}", "---", "",
                 f"# {os.path.basename(p)}", "", f"Module : [[{mod}]] · Fichier : [{p}]({rel_from(CODE, p)}) · {raw[p].count(chr(10))} lignes", ""]
        if doc:
            lines += [f"> {doc}", ""]
        if types:
            lines += ["**Déclare :** " + ", ".join(f"`{t}`" for t in types), ""]
        if inside:
            lines += ["## Utilise (même module)", ""] + [f"- [[{code_note_name(t)}]]" for t in inside] + [""]
            link_count += len(inside)
        if outside:
            lines += ["## Utilise (autres modules)", ""]
            for other in sorted({modules[t] for t in outside}):
                lines.append(f"- {BY_FILE[other]['title']} : " + ", ".join(f"`{os.path.basename(t)}`" for t in outside if modules[t] == other))
            lines.append("")
        if external[p]:
            # A service few files use links from them; WidgetKit, the App Group… link from the modules.
            lines += ["## Services et frameworks", ""] + [f"- [[{e}]]" if len(service_users[e]) <= 3 else f"- {e}" for e in external[p]] + [""]
        if used_by.get(p):
            lines += [f"Utilisé par {len(used_by[p])} fichier(s) : " + ", ".join(f"`{os.path.basename(u)}`" for u in used_by[p][:12]) + (" …" if len(used_by[p]) > 12 else ""), ""]
        open(os.path.join(CODE, code_note_name(p) + ".md"), "w").write("\n".join(lines))
    for name, kind, what, _ in EXTERNAL:
        users = service_users[name]
        label = {"api": "API web", "framework": "Framework Apple", "data": "Données"}[kind]
        lines = ["---", f"tags: [ardane, service, service/{kind}]", "---", "", f"# {name}", "", f"{label} · [[Services-externes]] · [[Ardane]]", "", what, "",
                 f"Utilisé par {len(users)} fichier(s) : voir les rétroliens."]
        open(os.path.join(SERVICES_DIR, name + ".md"), "w").write("\n".join(lines) + "\n")
    hub = ["---", "tags: [ardane, hub]", "---", "", "# Ardane", "", "Le centre de la carte : chaque module, puis ses fichiers, ses services et ses données.", "",
           "[[docs/obsidian/README|Guide]] · [[Memoire|Mémoire du projet]] · [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]", ""]
    for z, (label, _) in ZONES.items():
        mods = [m for m in MODULES if m["zone"] == z]
        if mods:
            hub += [f"## {label}", ""] + [f"- [[{m['file']}]]" for m in mods] + [""]
    open(os.path.join(OUT, "Ardane.md"), "w").write("\n".join(hub))
    return by_module, module_deps, module_services, link_count


# --- README ----------------------------------------------------------------------------------------
def readme():
    zones = {}
    for m in MODULES:
        zones.setdefault(m["zone"], []).append(m)
    lines = ["# Carte du projet Ardane (Obsidian)", "",
             "Cartes et notes générées à partir du code par `scripts/obsidian_map.py` : rien n'y est inventé, chaque élément renvoie à ses fichiers sources.", "",
             "## Ouvrir dans Obsidian", "",
             "1. Obsidian → **Open folder as vault** → choisir la **racine du dépôt** (le dossier qui contient `App/`, `Shared/`, `docs/`). Les liens vers les fichiers sources n'existent qu'avec ce choix.",
             "2. Ouvrir `docs/obsidian/Vue-Globale.canvas` (la carte principale), puis `Architecture.canvas` et `Fonctionnalites.canvas`.",
             "3. Pour ouvrir les fichiers `.swift` depuis Obsidian : Settings → Files & links → activer **Detect all file extensions** (sinon ils s'ouvrent seulement depuis GitHub ou Xcode).",
             "4. Dans une carte : molette ou pincement pour zoomer, clic sur un lien de note pour ouvrir la note du module.", "",
             "## Les cartes", "",
             "- [[Vue-Globale.canvas|Vue globale]] : le projet au centre, les grands modules autour (interface, logique métier, données, widgets et iOS, services externes, outillage), les sous-fonctionnalités en groupes et les liens entre modules.",
             "- [[Architecture.canvas|Architecture]] : les couches (interface → état → code partagé → persistance), l'extension WidgetKit, les services, les cibles Xcode et la CI.",
             "- [[Fonctionnalites.canvas|Fonctionnalités]] : chaque partie d'Ardane avec ses sous-fonctionnalités et les fichiers qui les portent.", "",
             "## Les notes de modules", ""]
    for z, (label, _) in ZONES.items():
        if z not in zones:
            continue
        lines.append(f"**{label}**")
        lines += [f"- [[{m['file']}|{m['title']}]] ([fichier](modules/{m['file']}.md))" for m in zones[z]]
        lines.append("")
    lines += ["## Vue graphique (le réseau d'étoiles)", "",
              "Chaque fichier du code a sa note dans `code/` (ce qu'il déclare, ce qu'il utilise, ses services), chaque service ou framework dans `services/`, et [[Ardane]] est le centre. Chaque module est une étoile : ses fichiers sont reliés à lui et entre eux ; les modules sont reliés à leurs trois plus fortes dépendances (mesurées dans le code) et à leurs services. Les dépendances vers les fichiers d'autres modules restent écrites dans chaque note, sans lien, pour garder des grappes lisibles.", "",
              "1. Ouvrir la vue graphique : icône « Vue graphique » dans la barre de gauche (ou Ctrl+G).",
              "2. Roue dentée en haut à droite du graphe → **Filtres** → dans la recherche, taper `tag:#ardane` (seulement les notes de la carte, sans le guide ni les canvas).",
              "3. **Groupes** → « Nouveau groupe » six fois, avec ces requêtes et une couleur chacune :",
              "   - `tag:#zone/interface` (cyan) · `tag:#zone/metier` (vert) · `tag:#zone/donnees` (jaune)",
              "   - `tag:#zone/ios` (violet) · `tag:#zone/outils` (gris) · `tag:#service` (orange)",
              "   - facultatif : `tag:#memoire` (blanc) pour la [[Memoire|mémoire du projet]] (demandes, chantiers, décisions, pièges).",
              "4. **Forces** : force centrale ≈ 0,3 · répulsion ≈ 15 · force des liens ≈ 0,6 · distance des liens ≈ 120. **Affichage** : « Flèches » activé, taille des nœuds ≈ 1,5, seuil d'estompage du texte vers la gauche pour voir les noms des modules.",
              "5. Clic sur un point : ouvre la note ; survol : allume ses liens. Les gros points (AppModel, SharedStore, WidgetDesign…) sont les fichiers dont tout dépend.", "",
              "## Couleurs", "",
              "Cyan : interface · Vert : logique métier · Jaune : données · Violet : widgets et iOS · Orange : services externes · Gris : outillage.", "",
              "## Mettre à jour", "",
              "Modifier `MODULES` ou les cartes dans `scripts/obsidian_map.py`, puis lancer `python3 scripts/obsidian_map.py` : il réécrit `docs/obsidian/` et vérifie le JSON des cartes, les liens entre notes et l'existence de chaque fichier source cité. `python3 scripts/obsidian_map.py --check` vérifie sans rien écrire.", ""]
    open(os.path.join(OUT, "README.md"), "w").write("\n".join(lines))


# ----------------------------------------------------------------------------------------------- check
def check():
    errors = []
    notes = {os.path.splitext(f)[0] for f in os.listdir(NOTES) if f.endswith(".md")}
    every = {}
    for base, _, fs in os.walk(OUT):
        for f in fs:
            if f.endswith(".md"):
                every[os.path.join(base, f)] = os.path.splitext(f)[0]
    targets = set(every.values()) | {"docs/obsidian/README", "Vue-Globale.canvas", "Architecture.canvas", "Fonctionnalites.canvas"}

    def links_in(text, base, where):
        for target in re.findall(r"\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]", text):
            if target not in targets:
                errors.append(f"{where}: lien [[{target}]] sans cible")
        for path in re.findall(r"\]\(([^)\s]+)\)", text):
            if re.match(r"[a-z]+://", path) or path.startswith("/"):  # web link, or the voice script's IPA markup [Ardane](/ɑɹdˈɑn/)
                continue
            if not os.path.exists(os.path.normpath(os.path.join(base, path))):
                errors.append(f"{where}: lien {path} vers un fichier absent")

    for name in ["Vue-Globale.canvas", "Architecture.canvas", "Fonctionnalites.canvas"]:
        path = os.path.join(OUT, name)
        try:
            data = json.load(open(path))
        except Exception as error:
            errors.append(f"{name}: JSON invalide ({error})")
            continue
        ids = [n["id"] for n in data.get("nodes", [])]
        if len(ids) != len(set(ids)):
            errors.append(f"{name}: identifiants de nœuds en double")
        for n in data["nodes"]:
            for key in ("id", "type", "x", "y", "width", "height"):
                if key not in n:
                    errors.append(f"{name}: nœud sans {key}")
            if n["type"] not in ("text", "file", "link", "group"):
                errors.append(f"{name}: type {n['type']} inconnu")
            if n["type"] == "text":
                links_in(n["text"], OUT, name)
            if n["type"] == "file" and not os.path.exists(os.path.join(ROOT, n["file"])):
                errors.append(f"{name}: fichier {n['file']} absent")
        for e in data.get("edges", []):
            if e["fromNode"] not in ids or e["toNode"] not in ids:
                errors.append(f"{name}: flèche {e['id']} vers un nœud absent")
            if e.get("fromSide") not in (None, "top", "right", "bottom", "left") or e.get("toSide") not in (None, "top", "right", "bottom", "left"):
                errors.append(f"{name}: côté de flèche invalide")
        print(f"{name}: {len(data['nodes'])} nœuds, {len(data['edges'])} flèches")
    for path in sorted(every):
        links_in(open(path).read(), os.path.dirname(path), os.path.relpath(path, OUT))
    for m in MODULES:
        for p in m["sources"]:
            if not os.path.exists(os.path.join(ROOT, p)):
                errors.append(f"{m['file']}: source {p} absente")
    print(f"{len(notes)} notes de modules, {len(every)} notes en tout")
    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print("OK : cartes JSON valides, liens et fichiers sources vérifiés")


if __name__ == "__main__":
    if "--check" not in sys.argv:
        os.makedirs(NOTES, exist_ok=True)
        by_module, module_deps, module_services, link_count = code_graph()
        for m in MODULES:
            write_note(m, by_module.get(m["file"], []), module_deps.get(m["file"]), module_services.get(m["file"]))
        print(f"vue graphique : {sum(len(v) for v in by_module.values())} notes de code, {link_count} liens dans les modules")
        vue_globale()
        architecture()
        fonctionnalites()
        readme()
    check()
