"""Builds the interactive map of the project: one node per file (code, memory notes, external services),
linked by what really calls or uses what, coloured by a few large categories.

    python3 scripts/graph_map.py                 # refreshes the code graph with graphify, then writes the map
    python3 scripts/graph_map.py --no-graphify   # reuses graphify-out/graph.json as it is
    python3 scripts/graph_map.py --install-hook  # rebuilds the map after every commit (git post-commit hook)
    python3 scripts/graph_map.py --artifact      # also writes graphify-out/artifact/carte-ardane.html (claude.ai page)

The code graph comes from graphify (https://graphify.com, `pip install graphifyy`), run locally on the code
only (no API, no cost). The map is written to graphify-out/ (not committed): index.html (the viewer, from
scripts/graph/viewer.html), graph-data.js and graph-data.json. Open graphify-out/index.html, or the
« graphe » server of .claude/launch.json, which also reloads the map by itself when it changes.
When a module, a screen or a service appears or changes role, update MODULES / FALLBACK / EXTERNAL below.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "graphify-out")
VIEWER = os.path.join(ROOT, "scripts", "graph", "viewer.html")
MEMORY = os.path.join(ROOT, "docs", "memoire")
FORCE_GRAPH = "https://cdn.jsdelivr.net/npm/force-graph@1.51.4/dist/force-graph.min.js"

# ------------------------------------------------------------------------------------------- modules
# What each part of Ardane does (checked in the code), shown when a file of that part is selected.
MODULES = [
    {"file": "Noyau-AppModel", "title": "Noyau : AppModel et Router", "zone": "metier",
     "role": "Source unique des données de l'app et navigation. `AppModel` (@Observable, @MainActor) garde l'état de chaque domaine, l'écrit dans le stockage partagé, recharge les widgets et tient les caches réseau ; `Router` décide de l'onglet, des feuilles et des liens profonds.",
     "features": [
         "État : designs (widgets), contenu (tâches, habitudes, argent ; l'eau est retirée depuis le 2026-10-15, `removeRetiredFeatures`), réglages, Premium, 11 domaines métier, profil, « Mes styles ».",
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
         "Profil (`UserProfile`) : centres d'intérêt et informations de la personne ; besoins nutritionnels calculés (`NutritionCalculator`, `nutritionAuto`, `customTargets`).",
         "Business : sources externes (`SalesEntry.source/externalID`, `BusinessConnections`), import CSV (`BusinessImport.swift`, `BusinessCSV`, `StripeTransactions`), fusion sans doublon (`merge`).",
     ],
     "sources": ["Shared/Domains/Nutrition.swift", "Shared/Domains/FoodDatabase.swift", "Shared/Domains/Fitness.swift", "Shared/Domains/ExerciseLibrary.swift",
                 "Shared/Domains/ExerciseTechniques.swift", "Shared/Domains/Budget.swift", "Shared/Domains/Business.swift", "Shared/Domains/BusinessImport.swift", "Shared/Domains/Portfolio.swift",
                 "Shared/Domains/Companies.swift", "Shared/Domains/Student.swift", "Shared/Domains/Travel.swift", "Shared/Domains/Car.swift",
                 "Shared/Domains/Productivity.swift", "Shared/Domains/Life.swift", "Shared/Domains/Profile.swift", "Shared/Domains/StoredStates.swift"],
     "links": [("Noyau-AppModel", "états tenus par AppModel"), ("Donnees-et-stockage", "un fichier par domaine"), ("Services-externes", "Open Food Facts, CoinGecko, Finnhub, SEC, Frankfurter"),
               ("Mini-apps", "affichés et modifiés par les mini-apps")]},
    {"file": "Accueil-Mon-Quotidien", "title": "Accueil : Mon Quotidien", "zone": "interface",
     "role": "L'onglet Accueil : « Mon Quotidien » rassemble ce qui compte aujourd'hui, construit seulement à partir de ce que la personne a saisi, puis « Mes informations ».",
     "features": [
         "Cartes du jour (nutrition, séance, habitudes, À ne pas oublier, planning, budget, Top 3…), classées selon le moment de la journée.",
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
         "`MiniApp` : nutrition, fitness, planning, finances, business, travel, car, weather, photos.",
         "`MiniAppPage` : les pages de chaque mini-app (repas, séance, bibliothèque, historique…).",
         "« Mes infos » en tête de chaque mini-app (`MiniAppInfoSection`, `MiniAppSettings.swift`) : les infos de la personne, les mêmes que « Mes informations » ; plus de « Mes paramètres » ni de doublons.",
         "Vues de semaine partagées (`WeekViews`) : toucher une heure libre crée, toucher un bloc ouvre.",
     ],
     "sources": ["App/Screens/MiniApps/MiniApp.swift", "App/Screens/MiniApps/MiniAppSettings.swift", "App/Screens/MiniApps/WeekViews.swift"],
     "links": [("Nutrition", ""), ("Fitness", ""), ("Planning-et-habitudes", ""), ("Finances", ""), ("Autres-mini-apps", "Business, Voyage, Auto, Météo, Photos et citations"),
               ("Domaines-metier", "données de chaque mini-app")]},
    {"file": "Nutrition", "title": "Nutrition", "zone": "interface",
     "role": "Calories et macros du jour, repas, recherche d'aliments, scanner de code-barres, idées, historique.",
     "features": [
         "Besoins calculés (Mifflin-St Jeor × activité, objectif, protéines en g/kg, fibres, sucres, gras saturés, sodium, minéraux et vitamines DRI) ; chaque valeur « Calculé » ou « Personnalisé » (`NutritionTargetsCard`), jamais écrasée.",
         "Nutriments détaillés (`Micronutrients`) quand l'aliment les donne (CNF, Open Food Facts) ; historique et analyses détaillées en Premium.",
         "Anneau des calories restantes, protéines, glucides, lipides, repas du jour, idée, semaine.",
         "Ajout d'un aliment : recherche (aliments intégrés, base CNF, Open Food Facts si peu de résultats) puis feuille de quantité.",
         "Scanner de code-barres (VisionKit, EAN/UPC) avec carré de visée ; produit inconnu → créer l'aliment.",
         "Widgets nutrition ; le bouton « Scanner » des tailles moyenne et grande ouvre l'app sur le scanner (`tessera://scan-food`).",
         "Ajout rapide depuis un widget (`LogFoodIntent`).",
     ],
     "sources": ["App/Screens/MiniApps/Nutrition/NutritionApp.swift", "App/Screens/MiniApps/Nutrition/NutritionPages.swift", "App/Screens/Spaces/NutritionSpace.swift",
                 "Shared/Domains/Nutrition.swift", "Shared/Domains/FoodDatabase.swift", "App/Core/NutrientFile.swift", "Shared/Render/Tiles/NutritionTiles.swift", "App/Screens/Profile/NutritionTargetsCard.swift", "App/Screens/MiniApps/Nutrition/NutrientViews.swift"],
     "links": [("Services-externes", "Open Food Facts"), ("Domaines-metier", "NutritionState"), ("Intents-et-activite-en-direct", "LogFoodIntent, lien scan-food")]},
    {"file": "Fitness", "title": "Fitness", "zone": "interface",
     "role": "Programme de la semaine, séance en direct, repos, bibliothèque d'exercices avec démonstrations animées, progression.",
     "features": [
         "Séance en direct : série en cours, répétitions et charge, repos minuté (pause, passer), « Série faite ».",
         "Activité en direct sur l'écran verrouillé et dans la Dynamic Island, boutons actifs sans ouvrir l'app.",
         "Page dans l'ordre : aperçu, semaine, programme et séances, exercices, progression et statistiques, records en bas.",
         "Bibliothèque d'exercices (163) avec démonstration animée (`DemoRenderer`, `ExerciseDemos.json`) et technique ; entièrement Premium avec les données de chaque exercice ; en gratuit : séances, exercices tapés à la main (« Mes exercices »), séries notées.",
         "Ajouter un exercice pendant une séance l'ajoute directement à la séance en cours (`exercisePick`).",
         "Exercices récents plus affichés (page Fitness, bibliothèque) : favoris seulement ; « Récents » reste dans le sélecteur d'une séance (2026-10-15).",
         "Semaine en ronds, records, progression, historique, séances rattrapées, calories estimées.",
         "Pas du jour via le capteur de mouvement (`StepCounter`, CoreMotion).",
     ],
     "sources": ["App/Screens/MiniApps/Fitness/FitnessApp.swift", "App/Screens/MiniApps/Fitness/FitnessSession.swift", "App/Screens/MiniApps/Fitness/FitnessPages.swift",
                 "App/Screens/MiniApps/Fitness/ExerciseLibraryViews.swift", "App/Screens/MiniApps/Fitness/ExerciseDemo.swift", "App/Screens/Spaces/FitnessSpace.swift",
                 "Shared/Domains/Fitness.swift", "Shared/Domains/ExerciseLibrary.swift", "App/Core/StepCounter.swift", "Shared/Render/Tiles/FitnessTiles.swift"],
     "links": [("Intents-et-activite-en-direct", "Série faite, pause, passer"), ("Domaines-metier", "FitnessState"), ("Donnees-et-stockage", "ExerciseDemos.json")]},
    {"file": "Planning-et-habitudes", "title": "Planning, tâches et habitudes", "zone": "interface",
     "role": "Le calendrier (jour, semaine, mois, année), les tâches, le Top 3, les projets, la concentration, les études et les habitudes.",
     "features": [
         "Calendrier `PlanningCalendar` : échelles jour, semaine, mois, année par pincement (et sélecteur), toucher une heure libre crée un événement prérempli, chevauchements signalés.",
         "Éditeurs partagés `PlanningEditors` + `planningEditors(_:)` : le Planning et sa page Semaine créent et ouvrent les événements de la même façon ; la carte Planning de Mon Quotidien ouvre la mini-app Planning.",
         "Tâches avec répétition, Top 3 du jour, mois, projets, minuteur de concentration.",
         "Études (cours, examens, devoirs, notes) dans le Planning.",
         "Habitudes quotidiennes (série, rappel) ; régularité sur 30 et 90 jours en Premium.",
         "Calendrier lu seulement (EventKit), sur autorisation.",
     ],
     "sources": ["App/Screens/MiniApps/Planning/PlanningApp.swift", "App/Screens/MiniApps/Planning/PlanningPages.swift", "App/Screens/MiniApps/Planning/PlanningCalendar.swift", "App/Screens/MiniApps/Studies/StudiesApp.swift",
                 "App/Screens/MiniApps/Studies/StudiesPages.swift", "App/Screens/Content/HabitsView.swift",
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
     "role": "Business, Voyage, Auto, Météo et Photos et citations, plus les espaces Placements, Marchés et Ma vie.",
     "features": [
         "Business : ventes, résultats, récurrent, indicateurs ; « Ventes automatiques » : Stripe en lecture seule (clé restreinte dans le trousseau, `StripeSync`) et import CSV (`BusinessSources`). Audit : `docs/integrations-business.md`.",
         "Photos et citations : taille d'abord, puis 1 à 12 photos (sélecteur système, mises en page 1 à 4, recadrage) ou une citation (typographie, couleurs) ; widgets `photos` et `quote`.",
         "Voyage : programme, budget en devise (taux Frankfurter), météo du voyage, liste.",
         "Auto : pleins, kilométrage, entretien, échéances, coûts.",
         "Météo : prévisions Open-Meteo pour la ville choisie.",
         "Placements et marchés : cours CoinGecko et Finnhub, données SEC des sociétés.",
     ],
     "sources": ["App/Screens/MiniApps/Business/BusinessApp.swift", "App/Screens/MiniApps/Business/BusinessPages.swift", "App/Screens/MiniApps/Business/BusinessSources.swift",
                 "App/Services/StripeSync.swift", "App/Screens/MiniApps/Photos/PhotoQuotesApp.swift", "Shared/Model/PhotoQuote.swift", "Shared/Render/Kinds/PhotoQuoteWidgets.swift", "App/Screens/MiniApps/Travel/TravelApp.swift",
                 "App/Screens/MiniApps/Travel/TravelPages.swift", "App/Screens/MiniApps/Car/CarApp.swift", "App/Screens/MiniApps/Car/CarPages.swift",
                 "App/Screens/MiniApps/Weather/WeatherApp.swift", "App/Screens/Spaces/MoneySpaces.swift", "App/Screens/Spaces/TravelCarLifeSpaces.swift"],
     "links": [("Services-externes", "Open-Meteo, Frankfurter, CoinGecko, Finnhub, SEC, Stripe"), ("Domaines-metier", "")]},
    {"file": "Creer-espaces", "title": "Créer : les espaces", "zone": "interface",
     "role": "L'onglet Créer : chaque espace est l'endroit où l'on saisit les données d'une famille de widgets, puis où l'on crée ses widgets.",
     "features": [
         "`Space` : productivity, habits, nutrition, fitness, budget, investing, business, markets, student, travel, car, life.",
         "Création de widgets depuis un espace (taille, un ou plusieurs widgets), envol vers « Mes widgets ».",
         "« Écran verrouillé » : les widgets prévus pour l'écran verrouillé, par univers.",
         "Carte « Photos et citations » (`PhotoQuotesCard`, hors enum `Space`) : en dernier dans « Tout » et « Vie » ; Photos ou Citation puis `PhotoQuoteEditor` ; citation sur photo de fond (`quoteBackground` = 1re photo de `options.photos`, voile réglable).",
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
         "Galerie de l'écran d'accueil : un seul widget « Mes widgets » (`QuickWidget.swift`, `MyWidgetsProvider`) qui ne propose que les widgets créés par la personne ; écran verrouillé : l'essentiel de chaque mini-app (`DesignWidgets.swift`).",
         "Un widget ajouté garde son widget (défaut `defaultResult()` enregistré à l'ajout, `MyWidgetsChoice`) ; la galerie ne peut montrer qu'une entrée par taille (limite d'iOS).",
         "Écran verrouillé : « Scanner un aliment » (`ScanFoodWidgets.swift`, `tessera.lock.scan-food`) et Control iOS 18 (`FoodScannerIntent.swift`, `AppOpenRequests`).",
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
         "Widgets interactifs : `ToggleHabitIntent`, `ToggleTaskIntent`, `StartFocusIntent`, `StopFocusIntent` (InteractiveIntents).",
         "Espaces : `LogFoodIntent`, `QuickExpenseIntent`, `TogglePriorityIntent`, `ToggleProjectTaskIntent`, `ToggleAssignmentIntent`, `CounterStepIntent`, `GradeCardIntent`, `RevealCardIntent` (SpaceIntents).",
         "Activité en direct (ActivityKit) : `CompleteSetIntent` (Série faite), `PauseRestIntent`, `ResumeRestIntent`, `SkipRestIntent`, utilisables iPhone verrouillé (`authenticationPolicy = .alwaysAllowed`, fichiers en protection « jusqu'au premier déverrouillage »).",
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
         "Premium depuis le 2026-10-15 : statistiques détaillées de chaque mini-app, toute la bibliothèque d'exercices et leurs données, tous les nutriments sauf calories, protéines, glucides et lipides, l'icône de l'app (l'icône en place est gardée) ; les données ne sont jamais effacées.",
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
         "Icône de l'app (19 icônes, Premium ; Corail et l'icône en place restent), style de l'app (10 styles `AppStyleID`, clair/sombre).",
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
         "Stripe (`api.stripe.com`) : ventes, remboursements et frais de Business, en lecture seule, directement depuis l'iPhone avec la clé restreinte de la personne (trousseau) — `StripeSync`.",
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

# Where a file belongs when no module lists it (first matching prefix wins).
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
    ("Stripe", "api", "Ventes, remboursements et frais en lecture seule, par une clé restreinte de la personne (api.stripe.com).", r"api\.stripe\.com"),
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
    ("PhotosUI", "framework", "Choix de photos par le sélecteur système, sans accès à la photothèque.", r"^import PhotosUI"),
    ("App Group", "data", "Conteneur partagé `group.com.dakrsnyk.tessera` : un fichier JSON par domaine, lu par l'app et l'extension.", r"\bSharedStore\b"),
    ("Base alimentaire CNF", "data", "Fichier canadien sur les éléments nutritifs embarqué, ~5 600 aliments (App/Resources/cnf-foods.json).", r"cnf-foods"),
    ("Demos des exercices", "data", "Démonstrations animées des 163 exercices (App/Resources/ExerciseDemos.json).", r"\"ExerciseDemos\""),
]

# Parts outside the app's Swift code.
MODULES += [
    {"file": "Publicite", "title": "Publicité : campagne et films", "zone": "pub",
     "role": "Production des pubs d'Ardane : captures de l'app, voix off (Kokoro), musique de synthèse, mixage, montage Remotion des films et contrôle qualité.",
     "features": [
         "`scripts/ad2/film` : projet Remotion des films (scènes, téléphone 3D, coupes dans `cuts.json`).",
         "`vo.py` (voix), `score.py` (musique), `mix.py` (mixage −14 LUFS), `qc.py` (contrôle qualité), `stitch.py`.",
         "Brief et concept : `docs/memoire/campagne-v2/`.",
     ],
     "sources": [], "links": []},
    {"file": "Demos-exercices", "title": "Démonstrations des exercices", "zone": "outils",
     "role": "Génère les démonstrations animées des exercices de Fitness (`App/Resources/ExerciseDemos.json`).",
     "features": ["Moteur et figures par groupe d'exercices dans `scripts/demos/`."],
     "sources": [], "links": []},
    {"file": "Memoire", "title": "Mémoire du projet", "zone": "memoire",
     "role": "Notes tenues à chaque tâche : demandes de l'utilisateur, chantiers en cours, décisions, pièges connus, campagne publicitaire.",
     "features": ["`docs/memoire/` : `Demandes.md`, `Chantiers.md`, `Decisions.md`, `Pieges-connus.md`, `campagne-v2/`."],
     "sources": [], "links": []},
    {"file": "Services-tiers", "title": "Services et frameworks utilisés", "zone": "services",
     "role": "API web, frameworks d'Apple et données embarquées dont dépend Ardane.",
     "features": [], "sources": [], "links": []},
]
BY_FILE = {m["file"]: m for m in MODULES}

ZONE_STYLE = [  # id, label, colour (few large families, distinct on a dark ground)
    ("interface", "Interface (écrans)", "#F2709C"),
    ("metier", "Logique et état", "#FF9F5A"),
    ("donnees", "Données et stockage", "#F5CF66"),
    ("ios", "Widgets et iOS", "#6FCF97"),
    ("services", "Services externes", "#5CC8E0"),
    ("outils", "Tests et outils", "#7E9CF5"),
    ("pub", "Publicité", "#B48CF2"),
    ("memoire", "Mémoire", "#D5D9E2"),
]
SCRIPT_FALLBACK = [
    ("scripts/ad2/", "Publicite"), ("scripts/ads/", "Publicite"), ("scripts/ad_", "Publicite"), ("scripts/demos/", "Demos-exercices"),
    ("scripts/l10n", "Localisation"), ("l10n/", "Localisation"), ("scripts/", "Tests-CI-et-outils"),
]


def module_of(path):
    for m in MODULES:
        if path in m["sources"]:
            return m["file"]
    for prefix, mod in FALLBACK + SCRIPT_FALLBACK:
        if path.startswith(prefix):
            return mod
    return "Tests-CI-et-outils"


def slug(path):
    return re.sub(r"[^a-z0-9]+", "_", path.rsplit(".", 1)[0].lower()).strip("_")


def short_name(path):
    base = os.path.basename(path)
    return base[:-6] if base.endswith(".swift") else base


def find_graphify():
    for candidate in (os.environ.get("GRAPHIFY_BIN"), shutil.which("graphify"),
                      os.path.expanduser("~/ardane-tools/graphify-venv/Scripts/graphify.exe"),
                      os.path.expanduser("~/ardane-tools/graphify-venv/bin/graphify")):
        if candidate and os.path.exists(candidate):
            return candidate
    return None


def refresh_code_graph(quiet):
    tool = find_graphify()
    if not tool:
        print("graphify introuvable (pip install graphifyy) : graphe de code réutilisé tel quel.", file=sys.stderr)
        return
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    run = subprocess.run([tool, "update", ".", "--no-cluster", "--force"], cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if run.returncode != 0:
        print(run.stdout[-2000:] + run.stderr[-2000:], file=sys.stderr)
        raise SystemExit("graphify update a échoué")
    if not quiet:
        print(next((l for l in run.stdout.splitlines() if "Rebuilt" in l), "graphify : graphe de code à jour"))


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def birth_dates():
    """First commit where each path appears (for the « Animer » timelapse)."""
    born, stamp = {}, None
    for line in git("log", "--reverse", "--format=@%ct", "--name-only").splitlines():
        if line.startswith("@"):
            stamp = int(line[1:])
        elif line and stamp and line not in born:
            born[line] = stamp
    return born


def code_graph():
    path = os.path.join(OUT, "graph.json")
    if not os.path.exists(path):
        raise SystemExit("graphify-out/graph.json introuvable : installer graphify (pip install graphifyy) puis relancer sans --no-graphify.")
    data = json.load(open(path, encoding="utf-8"))
    owner = {}
    for n in data["nodes"]:
        path = n.get("source_file") or ""
        if path and not path.endswith(".md") and n["id"].startswith(slug(path)):
            owner[n["id"]] = path
    files = set(owner.values())
    weights, forward = Counter(), Counter()
    for link in data["links"]:
        a, b = owner.get(link["source"]), owner.get(link["target"])
        if a and b and a != b:
            weights[tuple(sorted((a, b)))] += 1
            forward[(a, b)] += 1
    return files, weights, forward


def memory_notes(files):
    notes, links = [], Counter()
    if not os.path.isdir(MEMORY):
        return notes, links
    by_stem = defaultdict(list)
    for path in files:
        by_stem[os.path.splitext(os.path.basename(path))[0]].append(path)
    paths = []
    for base, _, names in os.walk(MEMORY):
        paths += [os.path.relpath(os.path.join(base, f), ROOT).replace(os.sep, "/") for f in names if f.endswith(".md")]
    titles = {os.path.splitext(os.path.basename(p))[0]: p for p in paths}
    for path in sorted(paths):
        text = open(os.path.join(ROOT, path), encoding="utf-8").read()
        heading = next((l.lstrip("# ").strip() for l in text.splitlines() if l.startswith("# ")), os.path.basename(path)[:-3])
        notes.append({"path": path, "desc": heading})
        mentioned = set()
        for token in re.findall(r"([A-Za-z0-9_+\-/]+\.(?:swift|py|tsx|ts|js|sh))", text):
            mentioned.update(f for f in files if f == token or f.endswith("/" + token.split("/")[-1]))
        for token in re.findall(r"`([A-Za-z][A-Za-z0-9_+]{4,})(?:\.[A-Za-z_]+)*`", text):
            mentioned.update(by_stem.get(token, []))
        for target in mentioned:
            links[(path, target)] += 1
        for name in re.findall(r"\[\[([^\]|#]+)", text):
            other = titles.get(os.path.splitext(os.path.basename(name.strip()))[0])
            if other and other != path:
                links[(path, other)] += 1
    return notes, links


def external_uses(files):
    uses = Counter()
    for path in files:
        try:
            text = open(os.path.join(ROOT, path), encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        for name, _, _, pattern in EXTERNAL:
            if re.search(pattern, text, flags=re.M):
                uses[(path, "ext:" + name)] += 1
    return uses


def build():
    files, weights, forward = code_graph()
    born = birth_dates()
    now = int(time.time())
    nodes = {}
    for path in sorted(files):
        module = module_of(path)
        nodes[path] = {"id": path, "name": short_name(path), "path": path, "kind": "code", "module": module,
                       "zone": BY_FILE[module]["zone"], "born": born.get(path, now)}
    links = {}

    def link(a, b, w, directed=None):
        key = tuple(sorted((a, b)))
        entry = links.setdefault(key, {"source": a, "target": b, "w": 0})
        entry["w"] += w
        if directed:
            entry["source"], entry["target"] = directed

    for (a, b), w in weights.items():
        link(a, b, w, (a, b) if forward[(a, b)] >= forward[(b, a)] else (b, a))
    for (path, ext), w in external_uses(files).items():
        name = ext[4:]
        kind, desc = next((k, d) for n, k, d, _ in EXTERNAL if n == name)
        nodes.setdefault(ext, {"id": ext, "name": name, "path": "", "kind": "ext", "module": "Services-tiers", "zone": "services",
                               "desc": desc, "born": 0})
        link(path, ext, 1, (path, ext))
    notes, note_links = memory_notes(files)
    for note in notes:
        nodes[note["path"]] = {"id": note["path"], "name": os.path.basename(note["path"])[:-3], "path": note["path"], "kind": "note",
                               "module": "Memoire", "zone": "memoire", "desc": note["desc"], "born": born.get(note["path"], now)}
    for (a, b), w in note_links.items():
        link(a, b, w, (a, b))
    for n in nodes.values():
        if n["kind"] == "ext":
            n["born"] = min((nodes[l["source"]]["born"] for l in links.values() if l["target"] == n["id"]), default=now)
    degree = Counter()
    for l in links.values():
        degree[l["source"]] += 1
        degree[l["target"]] += 1
    for n in nodes.values():
        n["deg"] = degree[n["id"]]
    commit = git("rev-parse", "--short", "HEAD").strip()
    used = {n["module"] for n in nodes.values()}
    return {
        "version": f"{commit}-{len(nodes)}-{len(links)}-{sum(l['w'] for l in links.values())}",
        "commit": commit,
        "generated": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "root": ROOT.replace(os.sep, "/"),
        "zones": [{"id": z, "label": label, "color": color} for z, label, color in ZONE_STYLE],
        "modules": {m["file"]: {"title": m["title"], "zone": m["zone"], "role": m["role"], "features": m["features"]}
                    for m in MODULES if m["file"] in used},
        "nodes": sorted(nodes.values(), key=lambda n: n["id"]),
        "links": sorted(links.values(), key=lambda l: (l["source"], l["target"])),
    }


def write_artifact(graph):
    """The same map as one page for claude.ai (readable on a phone): no document wrapper (the host adds it),
    the library from the CDN, the data inline, without the local path."""
    html = open(VIEWER, encoding="utf-8").read()
    html = re.sub(r'<!doctype html>\s*|</?html[^>]*>\s*|</?head>\s*|</?body>\s*|<meta charset[^>]*>\s*|<meta name="viewport"[^>]*>\s*', "", html, flags=re.I)
    html = re.sub(r'<script src="vendor/force-graph\.min\.js"></script>\s*<script>window\.ForceGraph[^\n]*\n', f'<script src="{FORCE_GRAPH}"></script>\n', html)
    payload = json.dumps(dict(graph, root=""), ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    html = html.replace('<script src="graph-data.js"></script>', "<script>window.ARDANE_GRAPH = " + payload + ";</script>")
    html = re.sub(r"<!--.*?-->\s*", "", html, flags=re.S)
    assert 'src="vendor/' not in html and 'src="graph-data.js"' not in html
    path = os.path.join(OUT, "artifact", "carte-ardane.html")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    print("Page à publier :", os.path.relpath(path, ROOT))


def write(graph, quiet):
    os.makedirs(os.path.join(OUT, "vendor"), exist_ok=True)
    lib = os.path.join(OUT, "vendor", "force-graph.min.js")
    if not os.path.exists(lib):
        try:
            urllib.request.urlretrieve(FORCE_GRAPH, lib)
        except OSError:
            pass  # the viewer falls back to the CDN
    payload = json.dumps(graph, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(OUT, "graph-data.json"), "w", encoding="utf-8") as f:
        f.write(payload)
    with open(os.path.join(OUT, "graph-data.js"), "w", encoding="utf-8") as f:
        f.write("window.ARDANE_GRAPH = " + payload + ";\n")
    shutil.copyfile(VIEWER, os.path.join(OUT, "index.html"))
    if not quiet:
        zones = Counter(n["zone"] for n in graph["nodes"])
        print(f"Graphe : {len(graph['nodes'])} nœuds, {len(graph['links'])} liens ({', '.join(f'{z} {c}' for z, c in zones.most_common())})")
        print("Ouvrir : graphify-out/index.html")


HOOK = """#!/bin/sh
# Ardane : la carte du projet se met à jour après chaque commit (installé par scripts/graph_map.py --install-hook).
# Detached (no output kept open): the commit returns at once, the map follows about 40 s later.
( python3 scripts/graph_map.py --quiet || python scripts/graph_map.py --quiet ) </dev/null >/dev/null 2>&1 &
"""


def install_hook():
    hooks = git("rev-parse", "--git-path", "hooks").strip()
    path = os.path.join(ROOT, hooks, "post-commit")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(HOOK)
    os.chmod(path, 0o755)
    print("Hook installé :", os.path.relpath(path, ROOT))


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = set(sys.argv[1:])
    if "--install-hook" in args:
        install_hook()
        return
    quiet = "--quiet" in args
    if "--no-graphify" not in args:
        refresh_code_graph(quiet)
    graph = build()
    write(graph, quiet)
    if "--artifact" in args:
        write_artifact(graph)


if __name__ == "__main__":
    main()
