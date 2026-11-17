# Audit : Nutrition

Audit du 2026-11-17, fait en lecture seule sur le code de la branche `main` (dernier commit lu : `19f6eb1`). Rien n'a été modifié dans l'app.

Où sont les fichiers cités (le nom court suffit ensuite, suivi du numéro de ligne) :

| Nom court | Dossier |
|---|---|
| `NutritionApp.swift`, `NutritionPages.swift`, `FoodScanView.swift`, `ScanRecapView.swift`, `CustomFoodsView.swift`, `WeightPlanSummaryView.swift`, `CameraAccessGate.swift`, `ScanTorch.swift`, `NutrientViews.swift`, `MealPhotoAnalysis.swift`, `FoodModelRecognizer.swift` | `App/Screens/MiniApps/Nutrition/` |
| `NutritionSpace.swift`, `SpaceView.swift` | `App/Screens/Spaces/` |
| `MiniApp.swift`, `MiniAppScaffold.swift`, `MiniAppSettings.swift`, `MiniAppToFill.swift`, `WeekSelector.swift` | `App/Screens/MiniApps/` |
| `NutritionTargetsCard.swift`, `ProfileTopics.swift`, `DataItemViews.swift`, `SmartRemindersView.swift` | `App/Screens/Profile/` |
| `DailySection.swift`, `MiniAppsRow.swift` | `App/Screens/Home/` |
| `DailyBrief.swift`, `DailyDefaults.swift`, `Router.swift`, `AppModel.swift`, `NutrientFile.swift` | `App/Core/` |
| `Nutrition.swift`, `NutritionSafety.swift`, `WeightPlan.swift`, `ScanRecap.swift`, `ScanQuota.swift`, `FoodDatabase.swift`, `Profile.swift` | `Shared/Domains/` |
| `NutritionTiles.swift` | `Shared/Render/Tiles/` |
| `KindCatalog.swift` | `Shared/Model/` |
| `SmartReminders.swift`, `NotificationEngine.swift`, `Encouragements.swift`, `DeepLink.swift` | `Shared/Support/` |
| `SpaceIntents.swift`, `FoodScannerIntent.swift` | `Shared/Intents/` |
| `ScanFoodWidgets.swift` | `Widgets/` |
| `NutritionColors.swift`, `CristalPalette.swift` | `Shared/Theme/` |
| `PaywallContext.swift`, `PremiumLock.swift` | `App/Premium/` |

## 1. En bref

- Nutrition sert à noter ce qu'on mange et à voir ce qu'il reste : calories, protéines, glucides, lipides. C'est un vrai cas de `MiniApp` (`MiniApp.swift:6`).
- Pour qui : toute personne qui suit son alimentation, avec ou sans objectif de poids. Les besoins sont calculés à partir du corps, de l'objectif et de l'activité.
- Fréquence : plusieurs fois par jour (un ajout par repas), plus un coup d'œil à la semaine.
- État : complet et en service. 24 écrans et feuilles, 64 fonctions. Le scanner (code-barres et photo de plat) est la partie la plus riche.
- Deux manques face à la mission : pas d'hydratation (retirée le 2026-10-15) et pas d'historique des objectifs.

## 2. Écrans et navigation

| n° | Écran ou feuille | Vue SwiftUI, fichier:ligne | Comment on y arrive | Ce qu'on y fait |
|---|---|---|---|---|
| E1 | « Nutrition » (écran principal) | `NutritionAppView`, `NutritionApp.swift:24` (ouverte par `MiniAppView`, `MiniApp.swift:146`) | Carte Nutrition de Mon quotidien (`DailySection.swift:590`). Rangée des mini-apps de l'Accueil (`MiniAppsRow.swift:160`). Widget Nutrition (lien `tessera://space/nutrition`, `Router.swift:168`). Historique › « Jour par jour » ouvre la même vue sur un autre jour (route `nutritionDay`, `MiniApp.swift:172`). | Voir le jour choisi, ajouter un aliment, ouvrir tout le reste. |
| E2 | Page d'un repas (« Déjeuner », « Dîner », « Souper », « Collation ») | `NutritionMealPage`, `NutritionPages.swift:8` | Toucher une ligne de « Repas » (`NutritionApp.swift:113`). | Voir, ajouter, modifier, supprimer les aliments du repas (glisser : « Supprimer » et « Favori »). Reprendre un repas passé. Enregistrer le repas. |
| E3 | « Nutriments » | `NutritionNutrientsPage`, `NutritionPages.swift:260` | Ligne « Tous les nutriments » (`NutritionApp.swift:151`). | Lire chaque nutriment du jour face à sa cible ou à sa limite. |
| E4 | « Idées » | `NutritionIdeasPage`, `NutritionPages.swift:381` | Carte « Des idées pour la suite de ta journée » seulement (`NutritionApp.swift:184`). | Choisir un aliment ou un plat qui tient dans ce qu'il reste, puis l'ajouter. |
| E5 | « Historique » | `NutritionHistoryPage`, `NutritionPages.swift:474` | Ligne « Historique » (`NutritionApp.swift:284`). Vue « 7 jours » de la carte de Mon quotidien (`DailySection.swift:1720`). | Choisir une période, lire moyennes, graphiques, poids, jours. |
| E6 | « Mes repas » | `NutritionSavedMealsPage`, `NutritionPages.swift:732` | Ligne « Mes repas » (`NutritionApp.swift:290`). | Voir les repas enregistrés, en ajouter un à la journée, en supprimer un. |
| E7 | « Ajouter un aliment » (recherche) | `FoodSearchView`, `NutritionSpace.swift:139` | « Rechercher » ou « Ajouter un aliment » (`NutritionApp.swift:96`). « + » d'un repas (`NutritionApp.swift:123`). « Ajouter un aliment » de la page repas (`NutritionPages.swift:159`). Depuis le récapitulatif d'un scan, en mode choix (`ScanRecapView.swift:186`). C'est aussi l'écran qui reste quand on ferme le scanner. | Chercher, filtrer par famille, ouvrir le scanner, créer un aliment perso, reprendre un repas enregistré. Bouton « Fermer » en haut. 80 lignes au plus par liste (`NutritionSpace.swift:262`). Mode « choix » (ouvert par « Remplacer » ou « Ajouter un aliment » du récapitulatif, `ScanRecapView.swift:186`) : un aliment touché est rendu au récapitulatif au lieu d'être noté ; ni « Scanner » ni « Mes repas » n'y sont proposés (`NutritionSpace.swift:145-147`, `:205`, `:239`). |
| E8 | Feuille de quantité (le titre est le nom de l'aliment) | `FoodLogSheet`, `NutritionSpace.swift:451` | Toucher un aliment dans la recherche (`NutritionSpace.swift:331`). Toucher une idée (`NutritionPages.swift:432`). | Régler la quantité et le repas, lire l'apport, « Enregistrer ». |
| E9 | Feuille d'un repas enregistré (le titre est le nom du repas) | `SavedMealLogSheet`, `NutritionSpace.swift:555` | Recherche › « Mes repas » (`NutritionSpace.swift:334`). Page repas › « Mes repas » (`NutritionPages.swift:162`). Page « Mes repas » › « Ajouter à ma journée » (`NutritionPages.swift:776`). | Choisir le repas d'arrivée, lire les aliments et l'apport, « Enregistrer ». |
| E10 | « Aliment perso » (création) | `CustomFoodEditor`, `NutritionSpace.swift:608` | Recherche › « Aliment perso » (`NutritionSpace.swift:212`). Scanner › « Créer cet aliment » (`FoodScanView.swift:165`, suite `NutritionSpace.swift:427`). | Saisir nom, portion et valeurs pour 100 g. |
| E11 | Scanner « Code-barres ou aliments » (caméra) | `FoodScanView`, `FoodScanView.swift:27` ; caméra `ScanCameraView`, `FoodScanView.swift:528` ; cadre `ScanFrame`, `NutritionSpace.swift:721` | « Scanner » de l'écran principal (`NutritionApp.swift:91`) : la recherche s'ouvre, puis le scanner par-dessus (`NutritionSpace.swift:339`). « Scanner » dans la recherche (`NutritionSpace.swift:205`). Bouton « Scanner » de Mon quotidien (`DailySection.swift:621` et `:726`). Widgets et écran verrouillé (`tessera://scan-food`, `ArdaneApp.swift:123`). | Viser un code-barres (lu tout seul) ou photographier un plat. Choisir une photo. Régler le flash. Aller à la recherche. |
| E12 | Accès à la caméra : « Utiliser la caméra » ou « Caméra désactivée » | `CameraAccessGate`, `CameraAccessGate.swift:14` | Avant la caméra tant que l'accès n'est pas donné, ou s'il est refusé (`FoodScanView.swift:142`). | « Continuer », « Plus tard », « Ouvrir Réglages », « Chercher ou créer l'aliment ». |
| E13 | Scanner : attente et messages | attente `FoodScanView.swift:441` ; `ScanMessageView`, `FoodScanView.swift:470` | Après la lecture d'un code ou d'une photo (`FoodScanView.swift:150-216`). | Attendre, ou choisir une sortie : réessayer, créer l'aliment, chercher dans la liste, scanner à nouveau. |
| E14 | « Récapitulatif » (du scan) | `ScanRecapView`, `ScanRecapView.swift:14` | Produit trouvé ou plat analysé (`FoodScanView.swift:154`). | Corriger les aliments et les quantités, confirmer les aliments peu sûrs, choisir le repas, « Ajouter au journal ». |
| E15 | Modifier un aliment noté (le titre est le nom de l'aliment) | `EntryEditor`, `NutritionPages.swift:189` | Toucher un aliment dans la page d'un repas (`NutritionPages.swift:156`). | Changer la quantité, déplacer vers un autre repas, « Retirer de ce repas ». |
| E16 | « Mes aliments » | `CustomFoodsView`, `CustomFoodsView.swift:5` | Ligne « Mes aliments » (`NutritionApp.swift:297`). Elle n'existe que s'il y a au moins un aliment perso (`NutritionApp.swift:295`). | Corriger ou supprimer un aliment perso (glisser : « Supprimer », avec confirmation). Bouton « OK » en haut (`CustomFoodsView.swift:54-58`). |
| E17 | « Aliment perso » (correction) | `CustomFoodEditForm`, `CustomFoodsView.swift:81` | Toucher un aliment de « Mes aliments » (`CustomFoodsView.swift:60`). | Changer nom, portion, calories, protéines, glucides, lipides. |
| E18 | « Mes paramètres » | `MiniAppInfoSheet`, `MiniAppSettings.swift:184` ; contenu : `TopicForm`, cas nutrition, `ProfileTopics.swift:461` | Bouton « Mes paramètres » tout en bas (`MiniAppSettings.swift:63`). Carte « Calcule tes besoins du jour » (`NutritionApp.swift:174`). | Rappel des repas, objectif, poids cible, corps, activité, plan de poids, besoins par jour. |
| E19 | « Nutrition » (fiche de « Mes informations ») | `TopicEditorSheet`, `ProfileTopics.swift:749` | Cartes « À remplir » › « Calculer mes besoins » ou « Voir mes besoins » (`DataItemViews.swift:106`). Espace Nutrition › « Objectifs du jour » (`NutritionSpace.swift:110`). | Le même formulaire que E18, sans la ligne du rappel. |
| E20 | Éditeur d'une cible (le titre est le nom du nutriment) | `NutritionTargetEditor`, `NutritionTargetsCard.swift:298` | Toucher une valeur de « Tes besoins par jour » (`NutritionTargetsCard.swift:141`). | Taper une valeur, « Enregistrer », ou « Revenir au calcul ». |
| E21 | « Ton objectif de poids » (récapitulatif en feuille) | feuille `NutritionTargetsCard.swift:107` avec `WeightPlanSummaryView`, `WeightPlanSummaryView.swift:9` | « Calculé d'après ton plan » › « Voir le récapitulatif » (`NutritionTargetsCard.swift:36`). Le même récapitulatif est aussi posé dans E18 (`WeightPlanRecap`, `ProfileTopics.swift:940`). | Lire le plan, « Appliquer ce plan », « Utiliser cette durée », « Modifier l'objectif ». |
| E22 | « Rappels » | `SmartRemindersView`, section Nutrition `SmartRemindersView.swift:73` | Ligne « Rappel des repas » de E18 (`MiniAppSettings.swift:95`). | Activer « Repas », choisir l'heure. |
| E23 | Offre Premium | `PaywallView` ; contextes `nutrients` (`NutrientViews.swift:5`) et `photoScanLimit` (`PaywallContext.swift:65`) ; carte `PremiumLockCard` (`PremiumLock.swift:5`) | Ligne verrouillée « Tous les nutriments ». Analyses de plat gratuites épuisées. « Découvrir Premium » de l'Historique. | Lire l'offre, s'abonner. Le même verrou « Nutriments » (`NutrientLockRow`, `NutrientViews.swift:17`) apparaît aussi dans la feuille de quantité, la modification d'un aliment noté, la création d'un aliment perso, « Idées » (fibres) et, par ligne verrouillée ou « Acides gras, minéraux et vitamines », dans « Tes besoins par jour » (`NutritionTargetsCard.swift:79`, `:141`). |
| E24 | Espace Nutrition (données, côté Créer) | `NutritionSpaceSections`, `NutritionSpace.swift:5`, dans `SpaceView` (`SpaceView.swift:78`) | Studio › « Données de l'espace Nutrition » (`App/Screens/Editor/SpaceOptionsSection.swift:58`). Créateur d'espace › « Mes données » (`App/Screens/Spaces/SpaceBuilderView.swift:127`). Onglet Créer (`App/Screens/Spaces/CreateView.swift:35`, chemin exact à vérifier). | Un second tableau de bord : calories du jour, repas, « Favoris », « Objectifs ». |

Variantes sans écran à part : le scanner existe aussi sous forme de feuille de capture de test (`ScanFrameScreenshot`, `NutritionSpace.swift:780-830`, réservée aux captures, non comptée). Dans le récapitulatif du scan, une ligne se glisse aussi : « Supprimer » et « Remplacer » (`ScanRecapView.swift:67-78`).

Petites fenêtres non comptées comme écrans : alerte « Enregistrer ce repas » avec le champ « Nom » (`NutritionPages.swift:165`) ; alerte « Enregistrer quand même ? » (`NutritionSpace.swift:684`, `CustomFoodsView.swift:134`) ; dialogue « Supprimer cet aliment ? » (`CustomFoodsView.swift:63`) ; alerte « Déjà ajouté à l'instant » (`ScanRecapView.swift:174`) ; menu « … » d'une ligne du récapitulatif (`ScanRecapView.swift:495`) ; sélecteur de photos du système (`FoodScanView.swift:244`).

Profondeur la plus longue constatée : Accueil › Nutrition › Historique › Nutrition d'un autre jour › page d'un repas › feuille de recherche › feuille du scanner › récapitulatif.

## 3. Écran principal : sections dans l'ordre actuel

Ordre lu dans `NutritionApp.swift:47-67`. Le cadre commun est `MiniAppScaffold` (`MiniAppScaffold.swift:30`) : un bandeau en haut, puis le reste. Il n'y a pas de bouton flottant sur cet écran.

1. **Sélecteur de semaine** (bandeau). Sept jours, flèches « Semaine précédente » et « Semaine suivante », bouton « Aujourd'hui » si un autre jour est choisi. Un point sous chaque jour noté. Les jours à venir sont bloqués (`NutritionApp.swift:50`, `WeekSelector.swift:23`).
2. **Anneau des calories et trois macros** (bandeau, carte de verre). Au centre : le reste, avec « kcal restantes », « kcal en trop » ou « kcal mangées ». À droite : « Protéines », « Glucides », « Lipides » en « mangé / objectif g » avec une jauge (`NutritionApp.swift:52`, `CalorieHero` `:314`).
3. **« À remplir »** (seulement s'il manque l'objectif calorique ou les macros). Deux cartes : « Objectif calorique » et « Objectifs de macros », chacune avec « Calculer mes besoins ». Compteur « 0 / 2 » (`NutritionApp.swift:58`, `MiniAppToFill.swift:41`).
4. **Deux boutons d'action** : « Scanner » et « Rechercher ». Sans caméra, un seul bouton plein : « Ajouter un aliment » (`NutritionApp.swift:88-101`).
5. **« Repas »** : quatre lignes, « Déjeuner », « Dîner », « Souper », « Collation ». Chaque ligne montre « N aliments » ou « Rien noté », les kcal, un chevron, et un « + » (`NutritionApp.swift:105-138`).
6. **Ligne « Tous les nutriments »** (sans titre de section). Avec Premium : « Fibres 12 g · sucres 41 g · sodium 384 mg ». Sans Premium : un badge Premium (`NutritionApp.swift:143-167`).
7. **Carte conseil** (seulement si le jour choisi est aujourd'hui). Selon l'état : « Calcule tes besoins du jour », « Des idées pour la suite de ta journée », « Objectif dépassé », « Objectif atteint » (`NutritionApp.swift:171-200`).
8. **« Calories de la semaine »** : sept barres (le jour choisi en couleur pleine), la ligne de l'objectif, puis « Moyenne 1 612 kcal · 0 jour sur 2 dans l'objectif » (`NutritionApp.swift:245-278`).
9. **Carte de liens** (sans titre) : « Historique » (« Moyennes, tendances et poids »), « Mes repas » (avec le nombre), « Mes aliments » (seulement s'il y en a) (`NutritionApp.swift:282-306`).
10. **Note** : « Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL). » (`NutritionApp.swift:65`).
11. **Bouton « Mes paramètres »** (`NutritionApp.swift:66`, `MiniAppSettings.swift:63`).

Sur la capture `tests/mini-app-nutrition.png` (Build 454), le premier écran montre les sections 1, 2, 4 et 5. Les sections 6 à 11 demandent de défiler.

## 4. Fonctions existantes

Liste de référence. Colonne « Accès » : G = gratuit, P = Premium, G+P = gratuit avec une partie Premium. 17 fonctions ont une partie Premium (F11, F13, F16, F17, F29, F37, F38, F40, F42 à F47, F58, F60, F61).

| n° | Fonction | Où elle est | Accès | Données affichées | Actions possibles |
|---|---|---|---|---|---|
| F1 | Choisir le jour affiché | Sélecteur de semaine, `NutritionApp.swift:50`, `WeekSelector.swift:23` | G | Semaine, date, point sous un jour noté | Toucher un jour, changer de semaine (flèches ou balayage), « Aujourd'hui ». Pas de jour futur. |
| F2 | Retour automatique à aujourd'hui | `NutritionApp.swift:69-73` | G | — | Aucune : si l'app se rouvre un autre jour et que l'écran montrait « aujourd'hui », il suit. |
| F3 | Calories du jour (anneau) | `CalorieHero`, `NutritionApp.swift:314` | G | Reste, trop, ou mangé si pas d'objectif. Anneau rouge si dépassé. | Lecture seule |
| F4 | Protéines, glucides, lipides du jour | `MacroGauge`, `NutritionApp.swift:354` | G | « mangé / objectif g », jauge, « ≥ » si une valeur manque | Lecture seule |
| F5 | « À remplir » | `MiniAppToFill.swift:10` et `:41`, `DataItemViews.swift:106` | G | Cartes « Objectif calorique », « Objectifs de macros », compteur | « Calculer mes besoins » ouvre E19 |
| F6 | Bouton « Scanner » | `NutritionApp.swift:91` | G | — | Ouvre le scanner pour le jour choisi. Absent sans caméra. |
| F7 | Bouton « Rechercher » ou « Ajouter un aliment » | `NutritionApp.swift:96` | G | — | Ouvre la recherche pour le jour choisi |
| F8 | Recherche d'aliments hors ligne | `FoodSearchView`, `NutritionSpace.swift:175-188` et `:261-271` | G | « Suggestions » (favoris, récents, aliments perso, table intégrée) ou « Résultats » (table intégrée, puis environ 8 900 aliments génériques) ; ligne « kcal / 100 g · P · G · L » | Taper, toucher un aliment |
| F9 | Filtres par famille | `NutritionSpace.swift:222-238`, `FoodDatabase.swift:4` | G | « Pour toi », « Fruits », « Légumes », « Féculents », « Protéines », « Produits laitiers », « Noix et graines », « Plats », « Collations », « Boissons », « Sauces et sucres » | Toucher une pastille |
| F10 | Recherche de produits emballés (Open Food Facts) | `NutritionSpace.swift:272-300` et `:384-423` | G | Section « Produits emballés », attente, erreur, « Aucun produit trouvé » | « Chercher « … » dans les produits emballés », touche Rechercher du clavier, « Réessayer ». Jamais pendant la frappe. |
| F11 | Feuille de quantité | `FoodLogSheet`, `NutritionSpace.swift:451-552` | G+P | Marque, valeurs pour 100 g, « Après ajout, il te restera … kcal », « Apport ». Fibres et autres nutriments : Premium. | Quantité en g, portions rapides (« ½ portion », portion habituelle, « 2 portions », « 100 g »), repas, « Enregistrer » |
| F12 | Ajout direct à un repas | « + » d'une ligne (`NutritionApp.swift:123`), « Ajouter un aliment » de la page repas (`NutritionPages.swift:81`) | G | — | Ouvre la recherche avec le repas déjà choisi |
| F13 | Créer un aliment perso | `CustomFoodEditor`, `NutritionSpace.swift:608-712` ; contrôles `Nutrition.swift:820` | G+P | Nom, portion, calories, protéines, glucides, lipides. Premium : fibres, sucres, gras saturés, gras trans, cholestérol, sodium, potassium, calcium, fer. | Saisir, « Enregistrer ». Valeur impossible : refus. Valeur douteuse : « Enregistrer quand même ? ». |
| F14 | Reprendre un repas enregistré depuis la recherche | `NutritionSpace.swift:239-260` | G | Section « Mes repas » : nom, aliments, kcal | Toucher : ouvre E9 |
| F15 | Scanner un code-barres | `ScanCameraView`, `FoodScanView.swift:528` ; recherche du produit `:334-354` | G, sans limite | Caméra, cadre, « Vise un code-barres ou ton assiette » | Viser : lecture automatique (EAN-13, EAN-8, UPC-E). Cherche d'abord dans les aliments de la personne, puis sur Open Food Facts. |
| F16 | Scanner un plat par photo | Déclencheur, `FoodScanView.swift:254` ; analyse `:406-430` | G+P : 10 analyses gratuites au total, puis Premium (`ScanQuota.swift:7`) | « Photographier le plat », « Analyse du plat sur ton iPhone… » | Photographier. L'analyse se fait sur l'iPhone. La photo n'est ni gardée ni envoyée. |
| F17 | Analyser une photo déjà prise | `FoodScanView.swift:243-252` et `:392-401` | G+P : même quota | Sélecteur de photos du système | Choisir une photo |
| F18 | Flash du scanner | `ScanTorch.swift:7` et `:262` | G | « Flash automatique », « Flash activé », « Flash désactivé » | Toucher l'éclair. Le choix est gardé. En automatique, le flash s'allume seul s'il fait sombre. |
| F19 | Explication avant la caméra | `CameraAccessGate.swift:49` et `:122` | G | « Pourquoi la caméra », « Ce qui reste sur ton iPhone », ou « Caméra désactivée » | « Continuer », « Plus tard », « Ouvrir Réglages » |
| F20 | Sorties d'un code-barres | `FoodScanView.swift:158-204` et `:93-100` | G | « Produit introuvable », pas de connexion, « Service occupé », produit sans valeurs | « Créer cet aliment », « Chercher dans la liste », « Scanner à nouveau », « Réessayer », « Voir la fiche Open Food Facts » |
| F21 | Récapitulatif modifiable du scan | `ScanRecapView.swift:14` | G | Chaque aliment avec une étiquette (« Vérifié », « Estimation », « Open Food Facts », « Aliment perso »), « Ton habitude », « peu sûr » ou « assez sûr », calories et macros, total (fourchette « ≈ 420–560 kcal »), « Objectifs » après ajout | Quantité (champ et boutons + −), « Remplacer », « Supprimer » (menu « … » ou geste de glisser), remplaçants en une touche, « Ajouter un aliment », repas, « Ajouter au journal » |
| F22 | « À confirmer » | `ScanRecapView.swift:93-121`, `ScanRecap.swift:429` | G | Aliments « peu sûr » ou « Peut-être sur la photo ». Ajouts possibles : « Huile de cuisson ? », « Beurre ? », « Sauce ? » | Toucher le bon aliment, « Ajouter », « Ignorer ». Rien n'est ajouté sans accord. |
| F23 | Apprentissage local du scanner | `ScanRecap.swift:364`, `ScanRecapView.swift:242` | G | « Ton habitude », « Comme ton repas du 12 octobre » | Aucune : les corrections restent sur l'iPhone et améliorent les scans suivants |
| F24 | Compteur d'analyses gratuites | `FoodScanView.swift:127-131` et `:281` | G (montré sans Premium) | « Encore 3 analyses de plat gratuites », « Analyses de plat gratuites utilisées » | À zéro, le déclencheur et la galerie ouvrent l'offre Premium |
| F25 | « Scanner à nouveau » depuis le récapitulatif | `FoodScanView.swift:84-92` | G | Icône d'appareil photo | Revenir à la caméra |
| F26 | Pas de doublon | `ScanRecapView.swift:353-373`, `Nutrition.swift:744` | G | « Déjà ajouté à l'instant » | Le même aliment ajouté deux fois en moins de 2 s ne compte qu'une fois |
| F27 | Liste des quatre repas du jour | `NutritionApp.swift:105-138` | G | Nom du repas, « N aliments » ou « Rien noté », kcal | Toucher la ligne (E2) ou le « + » |
| F28 | Page d'un repas | `NutritionPages.swift:30-66` | G | Totaux calories, protéines, glucides, lipides. Chaque aliment : g, « P · G · L », kcal. | Toucher un aliment |
| F29 | Modifier un aliment noté | `EntryEditor`, `NutritionPages.swift:189-253` | G+P | « Apport ». Fibres et autres nutriments : Premium. | « Quantité », « Ajuster de 10 g », « Repas », « Retirer de ce repas » |
| F30 | Glisser pour supprimer un aliment noté | `NutritionPages.swift:67-72` | G | — | « Supprimer » |
| F31 | Mettre un aliment en favori | `NutritionPages.swift:73-78`, `Nutrition.swift:808` | G | — | Glisser, « Favori ». Les favoris passent en tête des suggestions, servent au widget « Ajout rapide » et au scan de code-barres. |
| F32 | Reprendre un repas précédent | `NutritionPages.swift:96-119`, `Nutrition.swift:937` | G | Section « Reprendre un déjeuner précédent » : 3 derniers repas du même type, date, aliments, kcal | Toucher : tout le repas est ajouté |
| F33 | Reprendre un repas enregistré depuis la page repas | `NutritionPages.swift:121-136` | G | Section « Mes repas » | Toucher : ouvre E9 |
| F34 | « Enregistrer ce repas » | `NutritionPages.swift:138-175`, `Nutrition.swift:800` | G | — | Donner un nom, « Enregistrer » |
| F35 | Page « Mes repas » | `NutritionPages.swift:732-780` | G | Nom, « kcal · P g », aliments et grammes | « Ajouter à ma journée », « Supprimer ce repas » |
| F36 | « Mes aliments » | `CustomFoodsView.swift:5` et `:81` | G | Nom, « pour 100 g · P · G · L », kcal | Corriger, supprimer (menu de glisser, avec confirmation) |
| F37 | Ligne « Tous les nutriments » | `NutritionApp.swift:143-167` | G+P : le résumé est Premium | « Fibres … g · sucres … g · sodium … mg » | Ouvre E3 |
| F38 | Page « Nutriments » | `NutritionPages.swift:260-374` | G+P : 4 gratuits, 34 Premium | « Objectifs » (calories, protéines, glucides, lipides, fibres), « À limiter » (7), « Acides gras » (4), « Minéraux » (9), « Vitamines » (13). Barre, rouge si une limite est dépassée, « partiel », « Non disponible ». | Lecture seule |
| F39 | Carte conseil du jour | `NutritionApp.swift:171-200` | G | Un des quatre messages (voir section 3, point 7) | « Calculer » (E18) ou « Voir des idées » (E4) |
| F40 | Page « Idées » | `NutritionPages.swift:381-469`, `Nutrition.swift:1025-1042` | G+P : « Riches en fibres » est Premium | « Il te reste environ … kcal », « Un repas qui tient dans ce qu'il reste », « Riches en protéines », « Riches en fibres » | Toucher une idée : feuille de quantité, repas suivant déjà choisi. « Un repas qui tient dans ce qu'il reste » seulement si 250 kcal ou plus restent ; « Riches en protéines » si plus de 10 g restent ou si la cible est inconnue ; « Riches en fibres » si plus de 5 g restent (`NutritionPages.swift:405-424`). |
| F41 | « Calories de la semaine » | `NutritionApp.swift:245-278` | G | 7 barres, ligne d'objectif, moyenne, jours dans l'objectif | Lecture seule |
| F42 | Historique : choix de la période | `NutritionPages.swift:475-531` | G+P : « Aujourd'hui » et « Hier » gratuits ; « 7 jours », « 30 jours », « Période » Premium | Sélecteur à 5 segments, deux dates « Du » et « Au » pour « Période » | Changer de période |
| F43 | Historique : « Bilan » ou « Moyennes » | `NutritionPages.swift:558-573` | G+P : bilan d'un jour gratuit, moyennes Premium | Calories (avec « objectif … »), protéines, glucides, lipides, « N jours sur M à moins de 10 % de ton objectif » | Lecture seule |
| F44 | Historique : « Calories par jour » | `NutritionPages.swift:575-597` | P (il faut plus d'un jour) | Barres par jour, ligne « Objectif » | Lecture seule |
| F45 | Historique : « Répartition des calories » | `NutritionPages.swift:599-634` | G+P : sur un jour gratuit, sur une période Premium | Barre en 3 parts et pourcentages | Lecture seule |
| F46 | Historique : courbe « Poids » | `NutritionPages.swift:636-693` | P en pratique : il faut 2 pesées dans la période et au moins un jour noté (sinon l'état vide remplace tout, `NutritionPages.swift:537-546`) | Courbe, variation, courbe lissée sur 7 jours et ligne « Cible » s'il y a un objectif de poids | Lecture seule |
| F47 | Historique : « Jour par jour » | `NutritionPages.swift:695-709` | P (il faut plus d'un jour) | Jusqu'à 31 jours, kcal ou « Rien de noté » | Toucher un jour : ouvre la Nutrition de ce jour |
| F48 | Bouton « Mes paramètres » | `MiniAppSettings.swift:63` | G | — | Ouvre E18 |
| F49 | « Rappel des repas » | `MiniAppSettings.swift:88-131`, `SmartRemindersView.swift:73` | G | Heure ou « Désactivé » | Ouvre « Rappels » : interrupteur « Repas », heure |
| F50 | « Ton objectif » (partagé avec Fitness) | `ProfileTopics.swift:382`, `Profile.swift:205` | G | 9 choix, dont « Recomposition corporelle », « Prise de muscle », « Prise de masse », « Force », « Performance », « Endurance » | Choisir. Texte : « Le même pour Sport et Nutrition. » |
| F51 | « Ton poids cible » et durée | `WeightPlanQuestions`, `ProfileTopics.swift:847` | G | Champ « Poids cible », « Durée » en « Semaines », « Mois » ou « Date » | Saisir. Montré seulement pour une perte ou une prise. |
| F52 | « Es-tu enceinte ou allaitante ? » | `LifeStageQuestion`, `ProfileTopics.swift:813` | G | « Adulte », « Enceinte », « Allaitante », « Je préfère ne pas répondre » | Choisir |
| F53 | « Toi » : âge, taille, poids, genre | `ProfileTopics.swift:329-365` | G | Les quatre valeurs. Référence de calcul si le genre n'est ni femme ni homme. | Saisir. Le poids saisi ici alimente la courbe de poids. |
| F54 | « Ton niveau d'activité » | `ProfileTopics.swift:468-483` | G | « Sédentaire (0–1 séance) », « Légère (2–3 séances) », « Modérée (4–5 séances) », « Élevée (6 séances ou plus) » | Choisir, ou laisser suivre les séances de Fitness |
| F55 | Récapitulatif « Ton objectif de poids » | `WeightPlanSummaryView.swift:9`, `ProfileTopics.swift:940` | G | « Poids actuel », « Poids cible », « Durée », « Rythme », « Calories par jour », « Date estimée », protéines, glucides, lipides. Cas refusés : « Objectif impossible à atteindre de manière sûre », « Parle à un professionnel de santé ». | « Appliquer ce plan », « Utiliser cette durée », « Modifier l'objectif », « Retirer cet objectif de poids » |
| F56 | « Ajustement proposé » | `WeightPlanSummaryView.swift:232-273`, `WeightPlan.swift:501` | G | Raison, « 2 100 → 2 000 kcal par jour » | « Accepter », « Plus tard » |
| F57 | « Nouveau calcul proposé » après un changement d'objectif | `NutritionTargetsCard.swift:253-280` | G | Calories et protéines recommandées | « Utiliser ce calcul », « Garder mes valeurs » |
| F58 | « Tes besoins par jour » | `NutritionTargetsCard.swift:8` | G+P : 4 cibles gratuites, 30 Premium | Chaque cible avec « Calculé » ou « Personnalisé », « Recommandé : … », « Soit … g de sel », « À LIMITER », « Acides gras, minéraux et vitamines », « Comment c'est calculé » | « Calcul automatique » (interrupteur), toucher une valeur pour la changer, « Revenir au calcul », « Voir le récapitulatif » du plan |
| F59 | Carte Nutrition de Mon quotidien | `DailySection.swift:423-430`, `:575`, `:1662`, `:1713` | G | Trois vues à balayer : « Aujourd'hui », « Repas », « 7 jours » | Ouvrir la mini-app, « Scanner », ouvrir l'Historique |
| F60 | Widgets Nutrition | `KindCatalog.swift:155-162`, `NutritionTiles.swift`, `ScanFoodWidgets.swift` | G+P : « Calories restantes » et « Macros » gratuits ; 6 autres Premium | Voir section 6 | Bouton « Scanner » sur les tailles moyenne et grande |
| F61 | Ajout rapide depuis un widget | `SpaceIntents.swift:228-265`, `NutritionTiles.swift:226` | P | 3 favoris (ou récents) | Une touche ajoute une portion au repas de l'heure |
| F62 | Rappels et notifications | `SmartReminders.swift:46-56`, `NotificationEngine.swift:372-430`, `Encouragements.swift:148` | G | « Rien de noté aujourd'hui », « Un dîner à noter ? », « Ta journée en calories », « Protéines du jour », « Bilan nutrition de la semaine » | Réglés dans « Rappels » |
| F63 | Espace Nutrition (côté Créer) | `NutritionSpace.swift:94-123` | G | « Favoris » (liste), « Moyenne sur 7 jours », « Série de suivi », « Objectifs du jour » | Retirer un favori, ouvrir les objectifs |
| F64 | Mentions des sources | `NutritionApp.swift:65`, `NutritionSpace.swift:267-298`, `ScanRecapView.swift:306-330`, `NutrientFile.swift:22` | G | Open Food Facts (ODbL), Fichier canadien sur les éléments nutritifs, USDA, « pas un avis médical » | Liens « openfoodfacts.org » et « ODbL » |

Hors version publique : l'interrupteur « Contribuer à l'amélioration » du récapitulatif n'existe qu'en version de test (`ScanRecapView.swift:157`).

## 5. Données et calculs

**Ce qui est saisi par la personne**

- Les aliments notés : `FoodEntry` = date, repas, copie de l'aliment, grammes, origine (`Nutrition.swift:407`).
- Les aliments perso, les favoris, les repas enregistrés (`NutritionState`, `Nutrition.swift:692`).
- Le corps et les choix : âge, taille, poids (avec le journal des pesées `weightLog`), genre, objectif, niveau d'activité, situation (grossesse, allaitement), poids cible et date (`WeightPlan`, `WeightPlan.swift:10`).
- Les cibles changées à la main (`customTargets`, « Personnalisé »).

**Ce qui est gardé** (`NutritionState`, `Nutrition.swift:692-721`, dans l'App Group)

- `goals` (34 cibles), `entries`, `favorites`, `customFoods`, `recentFoods` (20 au plus), `savedMeals`, `scanLearning`, `mealMemory`, `photoScansUsed`.
- Les entrées de plus de 400 jours sont effacées à chaque ajout (`Nutrition.swift:739`).
- Un aliment (`FoodItem`, `Nutrition.swift:9`) porte ses valeurs pour 100 g. Une valeur inconnue reste inconnue : elle n'est jamais montrée comme un zéro.
- Quatre repas fixes : « Déjeuner », « Dîner », « Souper », « Collation » (usage du Québec, `Nutrition.swift:361-373`).
- 38 nutriments suivis (`Nutrient`, `Nutrition.swift:147`) : 4 gratuits, 34 Premium. 34 cibles (`NutritionTarget`, `Nutrition.swift:577`).

**Calculs existants, à ne pas modifier**

| Calcul | Règle | Preuve |
|---|---|---|
| Apport d'un aliment | valeur pour 100 g × grammes ÷ 100 | `Nutrition.swift:55` |
| Total du jour | somme des entrées du même jour | `Nutrition.swift:870-876` |
| Reste | objectif − mangé | `NutritionApp.swift:323` |
| Quantité | entre 1 g et 5 000 g | `Nutrition.swift:724-731` |
| Heure d'une entrée | maintenant pour aujourd'hui ; sinon 8 h, 12 h, 19 h ou 16 h selon le repas | `Nutrition.swift:859-868` |
| Repas proposé | 4 h–11 h déjeuner, 11 h–15 h dîner, 17 h–22 h souper, sinon collation | `Nutrition.swift:385-393` |
| Moyennes d'une période | sur les jours notés seulement | `Nutrition.swift:979-997` |
| Jour « dans l'objectif » | à ± 10 % de l'objectif calorique | `Nutrition.swift:995`, `NutritionApp.swift:240` |
| Série de suivi | jours de suite avec au moins un aliment | `Nutrition.swift:897` |
| Prochain repas | reste partagé entre les repas principaux à venir | `Nutrition.swift:911` |
| Idées | protéines ou fibres par calorie ; plats entre 45 % et 100 % du reste (le commentaire du code dit 60 % : à vérifier) | `Nutrition.swift:1025-1042` |
| Répartition | protéines × 4, glucides × 4, lipides × 9 | `NutritionPages.swift:600` |
| Besoins | Mifflin-St Jeor × activité (1,2 / 1,375 / 1,55 / 1,725) × objectif (−15 %, −20 %, 0, +10 %, +15 % plafonné à 500 kcal), 1 400 kcal au moins | `Nutrition.swift:1175-1197` |
| Macros | protéines en g par kg (1,2 à 2,2), plafonnées à 35 % des calories ; lipides 28 % ; glucides : le reste | `Nutrition.swift:1165`, `:1198-1200` |
| Autres cibles | fibres 14 g par 1 000 kcal ; sucres et gras saturés 10 % ; sodium 2 300 mg ; minéraux et vitamines selon l'âge et le genre | `Nutrition.swift:1201-1230` |
| Bornes de sécurité | maintien seulement pour un mineur, une grossesse, un allaitement, un IMC trop bas (perte) ou trop haut (prise) ; plancher de calories | `NutritionSafety.swift:23-62` |
| Objectif de poids | 7 700 kcal par kg ; perte de 1 % du poids par semaine au plus ; prise de 0,5 % au plus ; planchers 1 200 / 1 500 kcal et 80 % du métabolisme ; plafond : dépense + 500 | `WeightPlan.swift:75-113`, `:235` |
| Suivi du poids | moyenne sur 7 jours ; rythme réel sur 28 jours avec 6 pesées au moins ; ajustement si l'écart dépasse 25 % | `WeightPlan.swift:375-553` |
| Scan photo | ajout seul à partir d'une confiance de 0,80 ; « peu sûr » sous 0,50 ; fourchette de calories pour une estimation | `ScanRecap.swift:125-128` |
| Quota photo | 10 analyses gratuites au total ; une analyse ratée ne compte pas | `ScanQuota.swift:7`, `FoodScanView.swift:420-422` |
| Aliment perso | 900 kcal et 100 g au plus pour 100 g ; avertissement si 0 kcal ou calories incohérentes | `Nutrition.swift:820-854` |

Règles d'affichage qui viennent des données : « ≥ » devant un total incomplet (`Nutrition.swift:439`) ; « ≈ » et fourchette pour une estimation ; « ? » pour une macro inconnue ; « partiel » ; « Non disponible » ; « — » pour une cible inconnue. Une cible que la personne n'a pas donnée n'est jamais montrée comme la sienne (`NutritionTiles.swift:10`, `NutritionTargetsCard.swift:286`).

Poids : gardé en kg, montré en kg ou en lb selon le réglage (`NutritionPages.swift:638`).

## 6. Liens

**Carte de Mon quotidien**

- Première dans l'ordre par défaut, présente pour tous, en pleine largeur (`DailyDefaults.swift:11-21`). Le code n'a que deux largeurs : demie et pleine (`DailyLayoutRules.swift:8`). « Moyen » et « grand » ont la même largeur (`DailyDefaults.swift:19`).
- Trois vues à balayer (`DailySection.swift:424`) :
  1. « Aujourd'hui » : anneau du reste, trois macros, bouton « Scanner », nombre de repas, « Prochain repas : souper, environ 1 569 kcal » (`DailySection.swift:675-760`). Une version demi-largeur existe (`:588-650`).
  2. « Repas » (« Repas du jour ») : kcal par repas et « Total 1 181 / 2 750 kcal » (`DailySection.swift:1662`).
  3. « 7 jours » (« Calories · 7 jours ») : barres et moyenne ; ouvre l'Historique (`DailySection.swift:1713`).
- Sans objectif et sans aliment noté : carte vide avec « Donne ton objectif calorique ou scanne un repas : tes calories du jour apparaîtront ici. » (`DailyBrief.swift:228`, `:452-459`).

**Widgets** (`KindCatalog.swift:155-162`, `NutritionTiles.swift`)

- Gratuits : « Calories restantes », « Macros ».
- Premium : « Protéines restantes », « Repas du jour », « Semaine nutrition », « Série de suivi », « Ajout rapide », « Prochain repas ».
- Autres widgets Premium qui lisent la nutrition : « Conseil nutrition », « Ma journée », « Tableau fitness » (`KindCatalog.swift:261-268`).
- Écran verrouillé : « Scanner un aliment », et un contrôle iOS 18 (`ScanFoodWidgets.swift:8` et `:107`). Pas de verrou Premium dans ce fichier.

**Autres mini-apps**

- Fitness : un seul objectif pour les deux (« Le même pour Sport et Nutrition. », `ProfileTopics.swift:383`). Le niveau d'activité peut venir des séances par semaine (`AppModel.swift:1336`). Le poids sert aux deux.
- « Mes informations » : mêmes données, mêmes formulaires (`MiniAppSettings.swift:3-8`).

**Notifications et rappels**

- Rappel « Rien de noté aujourd'hui », à l'heure choisie (20 h par défaut), seulement si la personne a noté un repas dans la semaine (`SmartReminders.swift:46-56`).
- « Un dîner à noter ? », « Objectif calorique en vue », « Ta journée en calories », « Protéines du jour », « Bilan nutrition de la semaine » le dimanche (`NotificationEngine.swift:372-430`).
- Encouragements après un repas (`Encouragements.swift:148`).
- Demande de note de l'app après 3 jours de suivi (`Shared/Model/ReviewPrompt.swift:36`).

**Liens profonds**

- `tessera://scan-food` : ouvre la recherche puis le scanner (`DeepLink.swift:17`, `Router.swift:167`, `ArdaneApp.swift:123`).
- `tessera://space/nutrition` : ouvre la mini-app (`Router.swift:168`).

## 7. États vides, première utilisation, erreurs, permissions, limites du mode gratuit

**Première utilisation**

- Page « Nutrition » du premier lancement : même formulaire que « Mes paramètres », avec les réponses déjà connues en résumé (`App/Screens/Onboarding/OnboardingView.swift:283`).
- Sans objectif : l'anneau montre « kcal mangées », les macros n'ont pas de jauge, le bloc « À remplir » et la carte « Calcule tes besoins du jour » apparaissent.
- Il manque une donnée pour le calcul : « Ajoute ton âge, ta taille et ton poids : Ardane calcule tes besoins. » (`NutritionTargetsCard.swift:57`).

**États vides**

- Repas sans aliment : « Rien noté » sur l'écran principal, « Rien de noté pour ce repas. » dans la page (`NutritionPages.swift:44`).
- Semaine vide : « Rien de noté cette semaine. » (`NutritionApp.swift:255`).
- Historique vide : « Rien de noté », « Aucun repas noté sur cette période. » (`NutritionPages.swift:537`).
- « Mes repas » vide : un texte explique comment enregistrer un repas (`NutritionPages.swift:743`).
- « Mes aliments » vide : « Aucun aliment personnel. » (`CustomFoodsView.swift:16`).
- Favoris vides (dans l'espace) : « Glisse un aliment vers la gauche pour l'ajouter aux favoris. Le widget Ajout rapide les propose d'une touche. » (`NutritionSpace.swift:102`).

**Erreurs**

- Recherche en ligne : « Open Food Facts ne répond pas. Réessaie dans un instant. », « Open Food Facts reçoit trop de demandes en ce moment. », « Aucun produit trouvé pour « … ». » (`NutritionSpace.swift:413-421`).
- Code-barres : « Produit introuvable », pas de connexion, « Service occupé », produit connu sans valeurs (`FoodScanView.swift:158-204`).
- Photo : « Plat non reconnu » (`FoodScanView.swift:205`).
- Caméra : « Caméra indisponible » (`FoodScanView.swift:229`).
- Saisie : quantité bornée ; valeurs d'un aliment perso refusées avec un message rouge (`CustomFoodsView.swift:142`).
- Objectif de poids refusé : aucun chiffre de calories n'est montré (`WeightPlanSummaryView.swift:163-206`).

**Permissions**

- Caméra seulement. L'explication passe avant la demande d'iOS. Un refus est respecté : la demande n'est jamais répétée (`CameraAccessGate.swift:4-13`).
- La galerie passe par le sélecteur du système : aucun accès aux photos n'est demandé (`FoodScanView.swift:390`).
- Notifications : réglées dans « Rappels ».

**Limites du mode gratuit**

- Nutriments : calories, protéines, glucides, lipides seulement. Les 34 autres sont Premium. Ce qui est noté reste gardé (`NutrientViews.swift:10`).
- Historique : « Aujourd'hui » et « Hier ». Le reste montre « L'historique détaillé est dans Premium » (`NutritionPages.swift:532`). La semaine de l'écran principal reste gratuite.
- Photo de plat : 10 analyses au total. Codes-barres et recherche : jamais limités (`ScanQuota.swift:3`).
- Cibles : 4 gratuites, 30 Premium (`NutritionTargetsCard.swift:139`).
- Idées : « Riches en fibres » est Premium (`NutritionPages.swift:416`).
- Widgets : 2 gratuits sur 8.

## 8. Problèmes d'UX constatés aujourd'hui

1. **Les calories mangées et l'objectif ne sont pas sur l'écran principal.** L'anneau ne montre que le reste (`NutritionApp.swift:323-336`). Le chiffre « mangé / objectif » se lit dans « Nutriments » (`NutritionPages.swift:276`) ou dans la vue « Repas » de Mon quotidien (`DailySection.swift:1691`).
2. **Le scan par photo n'a ni entrée ni libellé à lui.** Le bouton s'appelle « Scanner » avec une icône de code-barres (`NutritionApp.swift:91`). L'écran s'appelle « Code-barres ou aliments » (`FoodScanView.swift:135`). Ailleurs on lit « Scanner un code-barres » (`NutritionSpace.swift:50`, `ScanFoodWidgets.swift:17`).
3. **Annuler un scan demande deux fermetures.** Le scanner est une feuille posée sur la recherche. La croix renvoie à la recherche, qu'il faut fermer à son tour (`FoodScanView.swift:78`, `NutritionSpace.swift:339-348`).
4. **Un compte neuf voit quatre accès au même réglage.** Deux cartes « À remplir », la carte « Calcule tes besoins du jour » et « Mes paramètres » (`NutritionApp.swift:58`, `:62`, `:66`). Ils ouvrent deux feuilles différentes pour le même formulaire : « Nutrition » (`ProfileTopics.swift:749`) et « Mes paramètres » (`MiniAppSettings.swift:184`).
5. **Deux blocs n'ont pas de titre.** La ligne « Tous les nutriments » (`NutritionApp.swift:150`) et la carte « Historique » / « Mes repas » / « Mes aliments » (`NutritionApp.swift:283`). « Repas » et « Calories de la semaine » en ont un.
6. **L'historique, les repas enregistrés et les réglages sont sous le premier écran** (capture `tests/mini-app-nutrition.png`). La page « Idées » n'a qu'une entrée, et elle est conditionnelle : aujourd'hui, objectif connu, au moins un aliment noté, plus de 150 kcal restantes (`NutritionApp.swift:180-193`).
7. **La semaine est montrée trois fois, avec deux définitions.** Écran principal : la semaine civile du jour choisi (`NutritionApp.swift:246`). Historique « 7 jours » et Mon quotidien « 7 jours » : les 7 derniers jours (`NutritionPages.swift:507`, `DailySection.swift:1718`). Les moyennes peuvent différer.
8. **Deux règles pour « objectif atteint » sur le même écran.** La carte conseil : entre 50 kcal de trop et 150 kcal de reste (`NutritionApp.swift:183-197`). La semaine et l'historique : à ± 10 % (`NutritionApp.swift:240`, `Nutrition.swift:995`).
9. **Le sélecteur calcule « jour dans l'objectif » mais ne le montre pas.** Un jour réussi et un jour simplement noté ont le même point plein (`NutritionApp.swift:235-241`, `WeekSelector.swift:133-141`).
10. **Les favoris sont cachés.** On met en favori seulement en glissant un aliment déjà noté (`NutritionPages.swift:73-78`). Le libellé « Favori » ne change pas selon l'état. La mini-app n'a pas de liste des favoris : elle n'existe que dans l'espace (`NutritionSpace.swift:94-106`). Dans la recherche, rien ne distingue un favori (`NutritionSpace.swift:358-380`).
11. **Des calculs existent mais la mini-app ne les montre pas.** La série de suivi (`Nutrition.swift:897`) et le prochain repas (`Nutrition.swift:911`) sont dans les widgets, Mon quotidien ou l'espace (`NutritionSpace.swift:118`, `DailySection.swift:751`), pas dans la mini-app.
12. **Le poids est coupé en deux.** La courbe est dans l'Historique (`NutritionPages.swift:636`). La pesée se saisit dans « Mes paramètres » › « Toi » (`ProfileTopics.swift:341`). L'« Ajustement proposé » n'apparaît que dans « Mes paramètres » (`NutritionTargetsCard.swift:25`). L'écran principal ne dit rien de l'objectif de poids.
13. **« Mes paramètres » est une très longue feuille.** Jusqu'à 8 blocs à la suite : rappel, objectif, poids cible, grossesse, corps, activité, plan, besoins avec 34 cibles (`MiniAppSettings.swift:192-196`, `ProfileTopics.swift:461-486`).
14. **Les suppressions ne suivent pas la même règle.** Un aliment perso demande une confirmation (`CustomFoodsView.swift:63`). Un repas enregistré et un aliment noté sont supprimés tout de suite, sans retour possible (`NutritionPages.swift:757`, `:68`, `:222`).
15. **Un repas enregistré ne peut être ni renommé ni modifié.** Seulement ajouté ou supprimé (`NutritionPages.swift:747-769`).
16. **Corriger un aliment perso offre moins que le créer.** 4 valeurs à la correction (`CustomFoodsView.swift:111-116`), jusqu'à 13 à la création en Premium (`NutritionSpace.swift:656-669`).
17. **Des libellés sont coupés** (captures du Build 454). Le titre de la feuille de quantité : « Yogourt grec n… » (`tests/mini-app-nutrition-quantity.png`, `NutritionSpace.swift:466`). Le segment « Aujourd'… » de l'Historique (`tests/mini-app-nutrition-history.png`, 5 segments, `NutritionPages.swift:520`). Le détail de « Mes repas » : « Des repas enregistrés, à reprendre d'… » (`app-nutrition-settings-light.jpg`, `NutritionApp.swift:291`).
18. **Sans Premium, trois segments de l'Historique sur cinq mènent à une carte verrouillée**, sans signe avant de toucher (`NutritionPages.swift:520-535`). La page s'ouvre d'elle-même sur « Aujourd'hui » (`NutritionPages.swift:555`).
19. **L'anneau des calories part de trois couleurs dans le code.** Mini-app : `FF9500` (`NutritionColors.swift:6`, `NutritionApp.swift:326`). Mon quotidien : `F08A24` (`DailySection.swift:588`). Espace : `FF6B57` (`NutritionSpace.swift:34`). L'écart réel à l'écran est à vérifier sur capture.
20. **Un aliment noté ne peut pas changer de jour.** La feuille ne propose que la quantité et le repas (`NutritionPages.swift:200-205`).
21. **L'objectif n'est pas daté.** L'Historique compare tous les jours passés à l'objectif d'aujourd'hui (`Nutrition.swift:994-995`).
22. **L'Historique ouvre une deuxième copie de l'écran principal.** « Jour par jour » empile la même vue sur un autre jour, avec son propre sélecteur de semaine (`NutritionPages.swift:701`, `MiniApp.swift:172`).
23. **Un second tableau de bord Nutrition existe côté Créer**, avec d'autres libellés (« Scanner un code-barres », « Objectifs du jour ») et la seule liste des favoris (`NutritionSpace.swift:5-124`).

## 9. Ce que la mission du PDG cite et qui n'existe pas

1. **Hydratation.** La mini-app Eau a été retirée le 2026-10-15 (`docs/memoire/Decisions.md:13`, `AppModel.swift:810`). Aucun écran ne permet de noter l'eau. Les anciennes données restent dans le fichier (`Shared/Model/Content.swift:234`). Un ancien widget Eau ouvre l'Accueil (`Router.swift:163`).
2. **Évolution des objectifs.** L'objectif calorique n'a pas d'historique : une seule valeur, celle d'aujourd'hui (`Nutrition.swift:693`, `:994`). Ce qui existe et s'en approche : la courbe de poids avec la ligne « Cible » (F46), l'« Ajustement proposé » (F56), le récapitulatif du plan (F55).
3. **Une taille « Medium » distincte dans Mon quotidien.** Le code n'a que la demi-largeur et la pleine largeur (`DailyLayoutRules.swift:8`). Nutrition est en pleine largeur par défaut. À trancher avant de dessiner la carte.

Tout le reste de la liste de la mission existe : calories et objectif du jour, macros, suivi des repas, ajout d'aliments, scan par photo, scan de code-barres, recherche, historique.

Hors mission, pour mémoire : « Faire mes repas » (Premium) est une demande ouverte, pas développée (`docs/memoire/Demandes.md:397`). Ne pas la dessiner comme si elle existait.

## 10. Captures CI disponibles

**Dans `origin/ci-report` tel qu'il est aujourd'hui** (commit `170618c`, « Build 455 ») : aucune image. La branche ne contient que des fichiers texte (918 fichiers). Elle est réécrite à chaque run, et le dernier run n'a pas pris de capture.

**Dans la version précédente de la branche, encore dans le dépôt local** (commit `9261911`, « Build 454 », run `[daily]`) : 13 captures de Nutrition. Lecture seule possible avec `git show 9261911:<chemin>`. Ce commit n'est plus qu'un ancien état de la branche : il peut disparaître. Un nouveau run avec captures (`[daily]` ou `[apps]`) les remettrait dans `origin/ci-report`.

| Fichier | Ce qu'on y voit |
|---|---|
| `tests/mini-app-nutrition.png` | Écran principal, haut : sélecteur, anneau, « Ajouter un aliment », « Repas » |
| `tests/mini-app-daily-opens-nutrition.png` | Le même écran (fichier identique) |
| `app-nutrition-settings-light.jpg` | Écran principal, bas (clair) : nutriments, idée, semaine, liens, « Mes paramètres » |
| `app-nutrition-settings-dark.jpg` | Le même en sombre |
| `tests/mini-app-nutrition-meal.png` | Page « Déjeuner » |
| `tests/mini-app-nutrition-quantity.png` | Feuille de quantité |
| `tests/mini-app-nutrition-nutrients.png` | Page « Nutriments » |
| `tests/mini-app-nutrition-history.png` | Page « Historique », 7 jours |
| `tests/mini-app-nutrition-saved.png` | Page « Mes repas » |
| `tests/mini-app-nutrition-settings.png` | Feuille « Mes paramètres » |
| `tests/profile-scan-fallback.png` | Recherche « Ajouter un aliment » (repli du scanner sans caméra) |
| `tests/profile-nutrition-needs.png` | Premier lancement : corps et niveau d'activité |
| `tests/profile-nutrition-goal-known.png` | Premier lancement : page « Nutrition » |

Captures voisines du même commit : `home-light.jpg`, `home-dark.jpg`, `home-pages-light.jpg`, `home-pages-dark.jpg`, `tests/mini-app-daily-swiped.png`, `tests/profile-home-daily.png` (carte de Mon quotidien) ; `paywall-history-light.jpg` ; `reminders-light.jpg`.

Plus ancien (commit `71cc0ee`, « Build 447 ») : `tests/data-entry-food-quantity.png`, `tests/data-entry-creator-after-food.png`, `tests/data-entry-editor-after-food.png`.

**Aucune capture nulle part** pour : le scanner (caméra, flash, messages), le récapitulatif d'un scan, « Idées », « Mes aliments », l'éditeur d'une cible, le récapitulatif de l'objectif de poids, l'état sans Premium, un compte neuf dans la mini-app. Le simulateur n'a pas de caméra. Des écrans de test existent pour en produire (`-screenshotScreen scan-frame`, `scan-recap`, `scan-recap-photo`, `nutrition-plan`, `nutrition-ideas` : `App/Core/ScreenshotMode.swift:112`, `:183`, `:459`).

## 11. Contraintes pour la conception

**Ne rien perdre**

1. Les 64 fonctions de la section 4 doivent toutes rester joignables. Les plus faciles à oublier : F2, F14, F20, F22, F23, F25, F31, F32, F36, F56, F57, F63, F64.
2. Aucune fonction inventée : pas d'hydratation, pas d'historique des objectifs, pas de « Faire mes repas ». Si une planche en propose une, elle doit être marquée « nouvelle idée ».

**Données et calculs**

3. Aucun calcul de la section 5 ne change. Les chiffres des planches doivent être possibles avec ces règles (exemple : une prise de masse ne dépasse pas 500 kcal de surplus).
4. Une valeur inconnue ne devient jamais un zéro. Les marques « ≥ », « ≈ », « ? », « partiel », « Non disponible », « — » doivent garder une place.
5. Une estimation de photo se montre comme une estimation : étiquette « Estimation », fourchette, « peu sûr ». Jamais comme une mesure.
6. Rien n'est ajouté ni appliqué sans un geste de la personne : aliments « À confirmer », plan de poids, ajustement, nouveau calcul.
7. Quatre repas fixes. Pas de repas libre.
8. Le jour choisi pilote tout l'écran. Les jours futurs sont interdits (c'est un journal).

**Structure commune des mini-apps**

9. Un seul sélecteur de dates par écran, en tête, puis l'essentiel, puis le complémentaire, puis les réglages en dernier (décision du 2026-10-22, `docs/memoire/Chantiers.md:118`).
10. Le cadre `MiniAppScaffold` est partagé par toutes les mini-apps : bandeau avec lavis de couleur, cartes en dessous, action flottante possible (`MiniAppScaffold.swift:25-30`).
11. « Mes paramètres » montre les mêmes données que « Mes informations » : pas de copie à part (`MiniAppSettings.swift:3-8`).
12. L'objectif est commun à Fitness et Nutrition (décision du 2026-11-17, `docs/memoire/Decisions.md:134`).

**Couleurs**

13. Anneau des calories orange, protéines rouge, glucides jaune, lipides bleu. Une seule source : `NutritionColors.swift` (demande du 2026-10-30, `docs/memoire/Demandes.md:235`). La couleur de la mini-app est `F08A24` (`MiniApp.swift:40`).
14. Toute couleur passe par la palette Cristal (`CristalPalette.swift:133`). Le dépassement d'une limite est en rouge d'alerte.

**Premium**

15. Garder les frontières de la section 7. Ce que la personne a noté n'est jamais effacé ni caché pour de bon : Premium ajoute l'affichage.
16. Codes-barres et recherche restent toujours gratuits et sans limite (`docs/memoire/Demandes.md:253`).

**Confidentialité et droit**

17. L'analyse d'une photo se fait sur l'iPhone. Aucune photo n'est gardée ni envoyée (décision du 2026-10-26, `docs/memoire/Decisions.md:32`). Le texte qui le dit doit rester avant la demande de caméra.
18. Les mentions des sources restent visibles là où leurs données s'affichent : Open Food Facts (ODbL) avec ses liens, Fichier canadien sur les éléments nutritifs, USDA, et « pas un avis médical ».
19. Open Food Facts n'est jamais interrogé pendant la frappe : seulement sur demande (`NutritionSpace.swift:304-306`).
20. Sécurité de l'objectif de poids : dans un cas refusé, aucun chiffre de calories et aucun bouton pour en appliquer (`WeightPlanSummaryView.swift:3-5`).

**Technique et tests**

21. Sans caméra (simulateur, certains appareils), le bouton « Scanner » disparaît et « Ajouter un aliment » devient le bouton principal (`NutritionApp.swift:86-100`). Les planches doivent prévoir ce cas.
22. Le flash reste réglable à côté du déclencheur, avec ses trois états (décision du 2026-11-17, `docs/memoire/Decisions.md:140`).
23. Les tests d'interface cherchent des identifiants : `nutrition-hero`, `nutrition-scan`, `nutrition-search`, `meal-breakfast`, `meal-add`, `food-row`, `entry-row`, `entry-delete`, `nutrition-nutrients`, `nutrition-saved`, `nutrition-history`, `miniapp-settings-edit`, `daily-nutrition-open`, `daily-scan` (`UITests/MiniAppUITests.swift:116-160`, `:499`). Une intégration future devra les garder ou mettre les tests à jour.
24. Les textes sont traduits en 6 langues. Un libellé nouveau ou plus long doit tenir aussi en allemand et en japonais (voir le problème 17).
25. Mon quotidien : la carte Nutrition a trois vues et un bouton « Scanner ». La mini-app et la carte doivent montrer les mêmes chiffres avec les mêmes mots (« kcal restantes », « kcal en trop », « kcal mangées »).

## Relecture

- Ajouté : les gestes de glisser de « Mes aliments » et du récapitulatif (« Supprimer », « Remplacer ») ; le mode « choix » de la recherche (sans « Scanner » ni « Mes repas ») et sa limite de 80 lignes ; les conditions d'affichage des trois blocs de « Idées » ; les autres endroits où le verrou « Nutriments » apparaît ; la feuille de capture de test, non comptée.
- Corrigé : F46 (la courbe de poids disparaît aussi quand aucun jour n'est noté). Les autres affirmations vérifiées (dix-sept : lignes des sections 3, 4, 5 et 9, familles de filtres, 38 nutriments et 34 cibles, quota de 10, seuil 0,80, nettoyage à 400 jours, plafond 20 récents, 45 %, ± 10 %, champs Premium de la création) sont exactes. Les décomptes 24 écrans, 64 fonctions, 17 fonctions avec une partie Premium restent exacts.
- Incertain : le chiffre « environ 8 900 aliments génériques » (source `scripts/graph_map.py`, base non recomptée) ; la présence de « Nutrition » dans Créer (`CreateView.swift:35`, déjà marquée à vérifier) ; les couleurs réelles de l'anneau sur capture (problème 19).
