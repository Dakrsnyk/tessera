# Inventaire : mini-apps Nutrition et Fitness (état du code au 2026-11-15)

Source : code Swift (fait foi), captures du 2026-10-31 pour contrôle. Chemins relatifs à `App/Screens/MiniApps/`. Textes français exacts (`tr`).

## Structure commune (`MiniAppScaffold.swift`, `MiniApp.swift`, `WeekSelector.swift`)
- Barre du haut : barre de navigation système, titre inline (« Nutrition » / « Fitness »), fond de barre masqué (`toolbarBackground(.hidden)`). Bouton retour = chevron système (rond en capture). Aucun bouton de réglages dans la barre : les réglages sont un bouton en bas de page.
- Accent : Nutrition `F08A24` (orange), Fitness `E5484D` (rouge). Autres teintes : alerte `E5484D`, bon `1E9E75`, pas `12A4B5`.
- Fond : `.screenGradient` (fond d'app). Bande de la couleur d'accent derrière l'en-tête (haut 34 % clair / 55 % sombre, fondu vers transparent, remonte au bord haut de l'écran).
- Feuille calme dessous : coins hauts 30 pt, remplissage blanc 65 % (clair) / blanc 4,5 % (sombre), ombre vers le haut, poignée capsule 38×4. Marges 20 pt, espace entre blocs 22 pt, min 520 pt de haut.
- En-tête (sur la bande, texte couleur d'écran) : `WeekSelector` puis la « figure essentielle » du jour.
- `WeekSelector` : flèches `<` `>` autour d'un titre de semaine (« Cette semaine » ou « Semaine du … »), bouton de retour à aujourd'hui quand un autre jour est choisi, 7 jours (initiale, numéro, point ou repère). Jour choisi = pilule (blanche en sombre, accent en clair), aujourd'hui cerclé, passés neutres, futurs atténués. Balayage = semaine suivante/précédente. Nutrition : futur interdit, marque = anneau de progression kcal ou coche si à ±10 % de l'objectif. Fitness : futur permis, marque = fait / prévu / rattrapé.
- Action flottante (Fitness seulement) : capsule 50 pt de haut dans l'accent, au-dessus de la barre d'onglets (`MiniFloatingAction`). Nutrition n'en a pas (boutons dans la feuille).
- Blocs communs de la feuille : `MiniAppToFillSection` (« À remplir  n / m », cartes de données manquantes, disparaît seule), `MiniSectionTitle` (petite barre d'accent + titre + détail à droite), `MiniRowsCard` + `MiniRow` (icône carrée teintée, titre, détail, valeur, chevron), `MiniStat` (tuile titre/valeur/unité), `MiniFootnote`, `MiniAppInfoSection` (bouton bordered « Mes paramètres », icône engrenage, ouvre `MiniAppInfoSheet`).
- `MiniAppInfoSheet` (feuille « Mes paramètres », bouton « OK ») : ligne de rappel intelligent (Nutrition « Rappel des repas », Fitness « Rappel de séance » ; valeur = heure ou « Désactivé »), puis les questions de « Mes informations » (`TopicForm` : Nutrition = `.nutrition`, Fitness = `.sport` + « Tes données » = objectif de pas), note « Les mêmes infos partout : modifiées ici, elles le sont dans « Mes informations », tes autres mini-apps et tes widgets. ».
- « À remplir » : Nutrition = « Objectif calorique », « Objectifs de macros ». Fitness = « Programme d'entraînement », « Séances par semaine », « Poids », « Objectif de pas ».
- Pages secondaires : `MiniAppScroll` (fond d'app, sans bande) ou `List` `.styledList()`, titre large ou inline.

---
# NUTRITION

## 2. Page principale, de haut en bas (`Nutrition/NutritionApp.swift`, `NutritionAppView`)
Bande (en-tête) :
1. `WeekSelector` (voir plus haut).
2. `CalorieHero` : anneau 112 pt (progression kcal/objectif ; orange `FF9500`, rouge `E5484D` si dépassé) avec au centre le nombre (26 pt gras arrondi) et « kcal restantes » / « kcal en trop » / « kcal mangées » (objectif inconnu : total mangé). À droite 3 `MacroGauge` : « Protéines » (rouge `FF3B30`), « Glucides » (jaune `FFCC00`), « Lipides » (bleu `0A84FF`), valeur « mangé / objectif g » (sans objectif : « mangé g » ; marque minimum `≥` si un aliment n'a pas la valeur), jauge fine 4 pt.

Feuille :
3. `MiniAppToFillSection(.nutrition)` (si données manquantes).
4. `actions` : si scanner supporté (`DataScannerViewController.isSupported`) deux `MiniActionButton` côte à côte « Scanner » (`barcode.viewfinder`, id `nutrition-scan`) + « Rechercher » (`magnifyingglass`, id `nutrition-search`) ; sinon un seul « Ajouter un aliment » (`plus`, proéminent). Les captures sont sans scanner (simulateur).
5. « Repas » (`meals`) : carte de 4 lignes `MealRow` : Déjeuner (`sunrise`), Dîner (`sun.max`), Souper (`moon.stars`), Collation (`carrot`). Détail : « Rien noté » ou « n aliment(s) » ; valeur « n kcal » ; chevron ; à droite un « + » rond (`plus.circle.fill`, étiquette « Ajouter au <repas> ») qui ouvre la recherche pour ce repas. La ligne ouvre la page du repas.
6. « Tous les nutriments » (`nutrientsRow`, icône `leaf.fill`) : détail Premium « Fibres n g · sucres n g · sodium n mg » ; sans Premium : badge Premium compact, pas de détail. Ouvre la page Nutriments.
7. Carte d'idée (`insight`, aujourd'hui seulement), 4 variantes : objectifs inconnus → « Calcule tes besoins du jour » / « Ton âge, ta taille, ton poids et ton objectif suffisent : Ardane calcule tes calories et tes nutriments, puis te dit ce qu'il te reste. » / « Calculer » (ouvre « Mes paramètres ») ; reste > 150 kcal et repas notés → « Des idées pour la suite de ta journée » / « Voir des idées » (page Idées) ; < −50 → « Objectif dépassé » / « Rien de grave : c'est la moyenne sur plusieurs jours qui compte. L'historique te la montre. » ; sinon → « Objectif atteint » / « Tu es dans ta cible de calories aujourd'hui. ». Rien si aucun repas noté et objectifs connus.
8. « Calories de la semaine » (`weekTrend`, `WeekBars`) : 7 barres (initiales L M M J V S D, jour choisi en accent plein, autres 45 %), trait d'objectif ; phrase « Moyenne n kcal · x jour(s) sur y dans l'objectif » ; sans objectif « Moyenne n kcal sur y jour(s) noté(s). » ; vide : « Rien de noté cette semaine. ».
9. Carte de lignes (`more`) : « Historique » / « Moyennes, tendances et poids » ; « Mes repas » / « Des repas enregistrés, à reprendre d'une touche » (valeur = nombre) ; « Mes aliments » / « Corriger ou supprimer tes aliments personnels » (valeur = nombre ; seulement s'il existe des aliments perso ; ouvre une feuille).
10. `MiniFootnote` : « Valeurs indicatives, pas un avis médical. Aliments emballés : Open Food Facts (licence ODbL). »
11. Bouton « Mes paramètres ».

## 3. Segments et sous-pages
Pas d'onglets sur la page principale. Un seul sélecteur segmenté : page Historique.
- **Page repas** `NutritionMealPage` (`NutritionPages.swift`, `List`, titre large = nom du repas) : en-tête de section « Aujourd'hui » (ou date longue) avec 4 stats Calories kcal / Protéines g / Glucides g / Lipides g ; « Aliments » : lignes nom + « n g · P x · G x · L x » + « n kcal », glisser = « Supprimer » / « Favori » (étoile) ; bouton « Ajouter un aliment » ; pied « Touche un aliment pour changer sa quantité ou le déplacer. Glisse-le pour le supprimer. » ; « Reprendre un <repas> précédent » (3 derniers : date, résumé, kcal, +) ; « Mes repas » (repas enregistrés, kcal, +) ; « Enregistrer ce repas » (alerte avec champ « Nom », message « Donne-lui un nom : « Déjeuner du dimanche », « Bol protéiné »… ») ; pied « Il ira dans « Mes repas » pour le reprendre d'une touche. ».
- **Nutriments** `NutritionNutrientsPage` (`List`, titre inline « Nutriments ») : « Objectifs » = Calories, Protéines, Glucides, Lipides (gratuits, barre 6 pt) + Fibres (Premium) ; Premium : « À limiter » (sucres, sodium, graisses saturées…), puis groupes graisses / minéraux / vitamines (barre verte `7FA33A`, grise ou rouge si limite dépassée, pastille « partiel », « Non disponible ») ; sans Premium : `NutrientLockRow` « Tous les nutriments » / « Fibres, sucres, gras, minéraux, vitamines, caféine… » + badge.
- **Idées** `NutritionIdeasPage` (titre inline « Idées ») : carte « Il te reste environ n kcal » + « Encore x g de protéines [et y g de fibres] pour tes objectifs du jour. » ; sections « Un repas qui tient dans ce qu'il reste » (≥ 250 kcal), « Riches en protéines », « Riches en fibres » (Premium) ; chaque ligne : aliment, portion · P · fibres, kcal, + (ouvre `FoodLogSheet`) ; pied « Idées générales tirées de la table d'aliments d'Ardane, à adapter à tes goûts. Ce n'est pas un avis médical. »
- **Historique** `NutritionHistoryPage` (`MiniAppScroll`, titre large) : segments « Aujourd'hui », « Hier », « 7 jours », « 30 jours », « Période » (deux sélecteurs « Du » / « Au », Premium). Gratuit : un jour seulement ; 7 j / 30 j / Période → `PremiumLockCard` « L'historique détaillé est dans Premium ». Contenu : « Bilan » ou « Moyennes » (tuiles Calories (détail « objectif n »), Protéines, Glucides, Lipides ; « x jour(s) sur y à moins de 10 % de ton objectif »), « Calories par jour » (barres + ligne « Objectif »), « Répartition des calories » (barre empilée P/G/L + %), « Poids » (courbe, ± variation, ligne « Cible » et moyenne lissée si plan de poids ; note « Le poids vient de « Mes informations » : chaque nouvelle valeur s'ajoute ici. »), « Jour par jour » (31 jours max, ouvre `NutritionAppView(day:)`).
- **Mes repas** `NutritionSavedMealsPage` (titre large « Mes repas ») : un bloc par repas enregistré (en-tête nom + « n kcal · P n g », lignes aliment/grammes, « Ajouter à ma journée », « Supprimer ce repas »).
- Feuilles : `FoodSearchView`, `FoodScanView`, `ScanRecapView`, `CustomFoodEditor`, `CustomFoodsView` (« Mes aliments »), `WeightPlanSummaryView` (côté « Mes paramètres », à vérifier).

## 4. Actions principales et feuilles
- Ajouter un aliment `FoodSearchView` (`Spaces/NutritionSpace.swift`, titre inline « Ajouter un aliment », « Fermer ») : recherche « Pomme, poulet, yogourt… », boutons bordered « Scanner » et « Aliment perso » ; puces « Pour toi » + catégories ; « Mes repas » (un tap = ajoute le repas) ; « Suggestions » / « Résultats » (base interne + Fichier canadien sur les nutriments) ; « Produits emballés » = recherche Open Food Facts seulement sur demande (« Chercher « … » dans les produits emballés », « Recherche sur Open Food Facts… », « Réessayer »).
- `FoodLogSheet` : « Pour 100 g : n kcal · protéines … », « Quantité » (g) + portions « ½ portion / 1 portion / 2 portions », « Repas » (sélecteur), « Après ajout, il te restera n kcal. » / « Après ajout, tu dépasseras ton objectif de n kcal. », « Apport » (Calories, Protéines, Glucides, Lipides, Fibres Premium).
- Scanner `FoodScanView` (`Nutrition/FoodScanView.swift`) : caméra plein cadre, « Vise un code-barres ou ton assiette », titre « Code-barres ou aliments », boutons « Photographier le plat », « Choisir une photo », « Chercher dans la liste » ; états : « Recherche du produit n… », « Produit introuvable » + « Créer cet aliment », « Service occupé », « Caméra indisponible », « Plat non reconnu », « Analyse du plat sur ton iPhone… » ; porte `CameraAccessGate` (« Pourquoi la caméra », « Utiliser la caméra », « Caméra désactivée », « Ouvrir Réglages »). Quota : « Encore n analyses de plat gratuites » puis « Analyses de plat gratuites utilisées » (Premium).
- Récap de scan `ScanRecapView` : « Récapitulatif », « Estimation » (« ≈ a–b kcal »), lignes aliment (badges « Vérifié », « À confirmer », « peu sûr », « Ton habitude »), « Peut-être sur la photo », « Ajouter au journal », « Ignorer », « Remplacer », « Contribuer à l'amélioration ».
- Aliment perso `CustomFoodEditor` : « Nom », « Portion » g, « Pour 100 g » Calories/Protéines/Glucides/Lipides/Fibres.
- Éditer une ligne `EntryEditor` : « Quantité » g, « Ajuster de 10 g », « Repas », « Apport », « Retirer de ce repas ».

## 5. États vides (textes exacts)
- Repas sans aliment : ligne « Rien noté » ; page repas « Rien de noté pour ce repas. ».
- Profil non rempli : carte « Calcule tes besoins du jour » ; anneau sans objectif = « kcal mangées ».
- Semaine vide : « Rien de noté cette semaine. ».
- Historique : `EmptyStateView` « Rien de noté » / « Aucun repas noté sur cette période. ».
- Mes repas : « Aucun repas enregistré. Ouvre un repas de ta journée et touche « Enregistrer ce repas » : il sera ici, prêt à reprendre d'une touche. ».
- Mes aliments : « Aucun aliment personnel. ».
- Recherche en ligne vide : « Aucun produit trouvé pour « … ». ».

## 6. Premium (cadenas / offre)
- `PremiumBadge` : ligne « Tous les nutriments » (page principale), `NutrientLockRow` (Nutriments, Idées « Riches en fibres », `EntryEditor`, `FoodLogSheet`) → `PaywallContext.nutrients`.
- Historique : 7 jours, 30 jours, Période → `PremiumLockCard`.
- Scanner : analyse de plat par photo au-delà du quota gratuit. À vérifier : écran exact du blocage dans `FoodScanView`.
- Gratuits : calories + 3 macros, repas, recherche, code-barres, repas enregistrés, un jour d'historique, idées protéines.

## 7. Existe / n'existe pas
- Hydratation : N'EXISTE PAS. Mini-app Eau supprimée le 2026-10-15 (`AppModel.swift`, « Removed features »).
- Objectifs nutritionnels : existent (kcal, P/G/L en bande ; fibres + micronutriments Premium, page Nutriments ; réglage dans « Mes paramètres »).
- Repas enregistrés : existent (« Mes repas » + « Enregistrer ce repas »). Favoris : aliments favoris par glisser « Favori » ; pas d'écran dédié dans la mini-app (liste « Favoris » seulement dans `NutritionSpaceSections`, hors mini-app).
- Idées de repas : existent (page Idées + carte).
- Plan de repas (planning de la semaine) : N'EXISTE PAS. Seul un « plan de poids » (calories + durée) existe : `WeightPlanSummaryView` / `WeightPlanAdjustmentCard` ; à vérifier où il apparaît.
- Scanner : code-barres (Open Food Facts) ET photo de plat (analyse sur l'iPhone) existent.
- Poids corporel : saisi dans « Mes informations » (pas dans la mini-app) ; courbe dans Historique (≥ 2 valeurs).
- Série de jours de suivi : N'EXISTE PAS dans la mini-app (existe dans `NutritionSpaceSections`, « Série de suivi »).
- Live Activity : aucune pour Nutrition.

## 8. Fichiers et vues
- Page : `Nutrition/NutritionApp.swift` : `NutritionAppView`, `CalorieHero`, `MacroGauge`, `MealRow` (privée), `WeekBars`. Cadre : `MiniAppScaffold.swift`, `WeekSelector.swift`, `MiniAppToFill.swift`, `MiniAppSettings.swift`, `MiniApp.swift` (`MiniRow`, `MiniStat`, `MiniSectionTitle`, `MiniActionButton`, `MiniFootnote`).
- Sous-pages : `Nutrition/NutritionPages.swift` : `NutritionMealPage`, `EntryEditor`, `NutritionNutrientsPage`, `NutritionIdeasPage`, `NutritionHistoryPage`, `NutritionSavedMealsPage`. Verrou : `Nutrition/NutrientViews.swift` : `NutrientLockRow`, `FoodNutrientSections`.
- Recherche / saisie : `Spaces/NutritionSpace.swift` : `FoodSearchView`, `FoodLogSheet`, `SavedMealLogSheet`, `CustomFoodEditor`, `ScanFrame`. Scan : `FoodScanView`, `ScanRecapView`, `CameraAccessGate`, `MealPhotoAnalysis`, `FoodModelRecognizer`. Autres : `CustomFoodsView`, `WeightPlanSummaryView`.
- Couleurs : `Shared/Theme/NutritionColors.swift`. Données : `Shared/Domains/Nutrition.swift` (`MealType`).

---
# FITNESS

## 2. Page principale, de haut en bas (`Fitness/FitnessApp.swift`, `FitnessAppView`)
Bande :
1. `WeekSelector` (futur permis ; marques fait / prévu / rattrapé).
2. `dayHero` (`MiniHero` : petit libellé majuscule, grand titre 54 pt, légende) selon le jour choisi :
   - Aujourd'hui, séance en cours : « SÉANCE EN COURS » (ou « Rattrapage en cours ») / nom / « <exercice> · série n sur m » + barre « Progression » (n/m séries).
   - Séance faite : « Séance faite » (ou « Séance rattrapée ») / nom / « n séries · n min · n kg soulevés » (+ « Rattrapage de la séance du <jour> »).
   - Prévue : « Séance du jour » / nom / « n exercices · n séries · environ n min ».
   - Repos : « Repos aujourd'hui » / « Repos » / « Prochaine séance : <nom>, demain|<jour> ».
   - Aucun programme : « Aujourd'hui » / « Ton programme » / « Crée tes séances (exercices, séries, charges, repos) et choisis leurs jours : Ardane te propose chaque jour la bonne. ».
   - Autre jour : « n séance(s) faite(s) » / noms / résumé ; « Séance rattrapée » / nom / « Faite le <date> à la place. » ou « Rattrapage en cours. » ; « Prévu » ou « Prévu, pas fait » / nom / détail ; date longue / « Repos » / « Aucune séance prévue ce jour-là. » (« Aucune séance ce jour-là. » sans programme).
Action flottante (capsule accent) : « Reprendre la séance » (`play.fill`, id `fitness-resume`) ; « Commencer » (`fitness-start`) ; « Rattraper « <nom> » d'hier » (repos, veille manquée) ; « Créer une séance » (`plus`, sans programme) ; « Rattraper la séance » (jour passé non fait) ; aucune si séance faite ou jour libre.

Feuille :
3. `MiniAppToFillSection(.fitness)`.
4. « Cette semaine » (`weekSummary` ; titre « Semaine du … » si autre semaine) : grille 2×2 `MiniStat` : « Durée » (h min), « Volume » (n kg ou lb), « Calories » (« ≈ n », « — » sans poids), « Séances » (« faites / objectif », ex. « 5 / 3 »).
5. Section du jour (`daySection`, titre « Séance du jour » ou date longue ; absente si en cours / vide / libre) : faite → lien « Voir le détail » + menu « … » (« Supprimer la séance », confirmée) ; prévue → carte d'aperçu des 4 premiers exercices (nom, « 4 × 8 · 80 kg ») + « + n autres » ; repos → menu « Faire une séance quand même » ; plusieurs faites → lignes `checkmark.seal.fill`.
6. « Programme » (`program`), carte de 4 lignes : « Programme et séances » (« Tes séances de la semaine » ou « n séance(s) »), « Séances faites » / « Toutes tes séances » (valeur = nombre), « Exercices » / « n exercices, fiches et démonstrations » (163 en capture ; Premium), « Progression » / « Charges, volume, records et évolution » (Premium). Badge Premium compact sans abonnement.
7. « Exercices » (favoris, jusqu'à 6, ligne `star.fill` + résumé) : seulement s'il y a des favoris.
8. Activité (pas), `activity` : capteur autorisé → carte anneau 64 pt (`figure.walk`, `12A4B5`, progression vs objectif de pas), « n pas », détail « objectif n · x,x km · n étage(s) » (« Aujourd'hui » si rien), ouvre la page Activité ; jamais demandé → ligne « Afficher mes pas » / « Pas, distance et étages, depuis le capteur de ton iPhone » (explication puis invite Mouvement) ; refusé ou indisponible : rien.
9. `MiniFootnote` : « Calories et volumes estimés à partir de tes séances et de ton poids : des repères, pas des mesures. »
10. Bouton « Mes paramètres ».

## 3. Segments et sous-pages
Aucun onglet ni segment dans Fitness (le sélecteur de semaine est le seul).
- **Séance** `FitnessSessionPage` (`Fitness/FitnessSession.swift`, `MiniAppScroll`, titre inline « Séance »). Sans séance active : « Choisis la séance à faire. », « Aucune séance dans ton programme : crée-en une dans Programme. », lignes `play.fill` par séance (« n exercices · environ n min »), « Séance libre » / « Ajoute les exercices au fur et à mesure » ; « Annuler la dernière série » si la séance vient de finir. En cours : voir §4.
- **Programme** `FitnessProgramPage` (`FitnessPages.swift`, `List`, titre large) : « Ma semaine » (7 lignes Lundi…Dimanche, valeur = séance en accent ou « Repos », menu de choix ; pied « Touche un jour pour lui donner une séance. Ardane te propose chaque jour celle qui est prévue. ») ; « Mes séances » (nom, exercices, « n exercices · environ n min » ; glisser = supprimer, dialogue « Supprimer cette séance du programme ? » / « Les séances déjà faites restent dans l'historique. » ; « Nouvelle séance ») ; Stepper « Objectif » « n séances / semaine » (1 à 7).
- **Séances faites** `FitnessHistoryPage` (titre large « Historique », `List` par mois) : nom + pastille « Rattrapée » + date, « n min · n séries · n kg » ; glisser « Supprimer ».
- **Détail de séance** `FitnessSessionDetailPage` (titre = nom de séance) : Date, « Séance rattrapée » / « Prévue le … », Durée, Volume ; une section par exercice (séries « 60 kg × 8 » + heure ; ⓘ fiche ou badge Premium) ; « Supprimer la séance ». Introuvable : « Séance introuvable. ».
- **Exercices** `ExerciseLibraryPage` (`ExerciseLibraryViews.swift`, titre large « Exercices », recherche « Développé, squat, dos, haltères… ») : filtres menu « Muscle », « Équipement », « Type », « Niveau », « Effacer » ; sans Premium carte « Toute la bibliothèque d'exercices » / « Démonstrations, techniques, alternatives et tes performances sur chaque exercice. Tes propres exercices restent gratuits. » ; sections « Favoris », « Récents » (mode choix), « Les plus faits », « Mes exercices » (+ « Créer un exercice »), « Par muscle » (avec compte) ; résultats « n exercice(s) » ; vide « Aucun exercice ne correspond. Essaie un autre mot ou retire un filtre. ». Glisser = « Favori ».
- **Fiche d'exercice** `ExerciseDetailView` (via `ExerciseGate`) : démo animée `ExerciseDemoView` (légende « Muscles principaux » / « secondaires »), cartes « Position de départ », « Exécution », « Points importants », « À éviter », « Alternatives » (« Variante » / « Mêmes muscles »), « Mes performances » (dernière séance, tuiles « Record » avec « 1RM ≈ », « Volume », « Fréquence » « × en 30 jours », graphique « Charge la plus lourde de chaque séance », verrou « L'évolution de tes charges sur cet exercice est dans Premium. »), bouton « Ajouter à une séance » / « Ajouter à ma séance », étoile favori, consigne de prudence.
- **Progression** `FitnessProgressPage` (titre large, Premium) : « Volume par semaine » (barres, 8 semaines, kg/lb) ; « Records » : lignes `trophy.fill` classées par lettre avec index A–Z à gauche, « +n kg depuis le début · n séances », valeur « 59,6 × 8 » (ouvre la fiche).
- **Activité** `FitnessActivityPage` (titre large « Activité », `DaySwitcher`) : tuiles « Pas » (objectif), « Distance » km, « Étages », « Calories actives » (« ~n kcal », « estimées d'après les pas, hors séance ») ; « 7 derniers jours » + « moyenne n » (barres + ligne objectif) ; états `EmptyStateView` « Tes pas » / « Autoriser », « Accès refusé » / « Ouvrir Réglages », « Pas disponible » / « Cet appareil ne compte pas les pas. ».
- Feuilles : `RoutineEditor` (`Spaces/FitnessSpace.swift` ; « Nouvelle séance », « Nom (haut du corps, jambes…) », jours, « Choisir dans la bibliothèque », « Ajouter un exercice »), `SessionExerciseForm`, `SetEditor`, `ExerciseInfoSheet`, `CustomExerciseEditor`, `AddToRoutineSheet`.

## 4. Actions principales
- Commencer : `startSession(routine)` puis page Séance (id `fitness-start`).
- Séance en cours (`live`) : en-tête nom + chrono + « n/m séries » + barre ; carte exercice : « Série n sur m » (accent), nom 22 pt, « La dernière fois : 59,6 kg × 8 » (Premium), ⓘ fiche (44 pt) ; deux réglettes « Répétitions » (− n +) et « Charge » (− n kg + ; « Corps » si 0) ; ligne de repos : décompte + pause + « Passer le repos », puis « Prêt » ; « Repos en pause · m:ss » + « Reprendre » / « Passer le repos » ; bouton « Série faite » (`checkmark.circle.fill`, id `session-set-done`) ; liens « Passer la série », « Annuler la dernière série », « Passer cet exercice » ; « La séance » (lignes exercice, état rond / lecture / coche, « 4 × 8 · 60 kg », capsules de séries faites « 60 × 8 » cliquables, « Passée » en pointillé) ; « Choisir dans la bibliothèque » (+ badge Premium), « Ajouter un exercice » ; « Terminer la séance » (dialogue « Terminer la séance ? », « Terminer et enregistrer », « Les séries faites sont enregistrées dans l'historique. ») ; « Annuler la séance » (« Annuler la séance ? Elle ne sera pas comptée. »).
- Fin de séance : retour à la page ; la séance passe dans « Séances faites » (hero « Séance faite »).
- Minuteur de repos : durée par exercice (`restSeconds`) ; notification de fin (explication proposée une fois) + haptique ; Live Activity via `WorkoutLiveActivity.sync`.
- Séance libre : avec Premium ouvre la bibliothèque, sinon `SessionExerciseForm`.

## 5. États vides (textes exacts)
- Aucun programme : hero « Ton programme » (légende ci-dessus) + bouton « Créer une séance » ; page Séance : « Aucune séance dans ton programme : crée-en une dans Programme. » ; Programme : « Crée d'abord une séance » (menu d'un jour).
- Historique : « Aucune séance pour l'instant. Commence celle du jour depuis Fitness : elle s'enregistre ici. ».
- Progression vide : « Pas encore de progression » / « Fais quelques séances : tes charges, ton volume et tes records apparaîtront ici. » ; sans Premium : « La progression est dans Premium ».
- Poids absent : tuile Calories « — » ; Activité : « ajoute ton poids dans « Mes informations » ».
- Jour sans données de pas : « Pas de données de pas pour ce jour : l'iPhone garde environ une semaine, Ardane garde ensuite chaque jour lu. ».

## 6. Premium
- Lignes « Exercices » et « Progression » de la carte Programme (badge compact) ; chaque fiche d'exercice (`ExerciseGate` : « Cet exercice est dans Premium ») ; carte « Toute la bibliothèque d'exercices » ; « Choisir dans la bibliothèque » ; « La dernière fois : … » ; courbe de charges par exercice ; page Progression (`PremiumLockCard` « La progression est dans Premium »). Offres : `PaywallContext.exerciseLibrary`, `.exercises`.
- Gratuits : suivi de séance, séries, programme, historique, « Mes exercices », pas.

## 7. Existe / n'existe pas
- Progression sportive : existe (Premium) : « Volume par semaine » (8 sem.) + records par exercice ; par exercice « Charge la plus lourde de chaque séance ». Pas de graphique de poids ni de fréquence globale dans Fitness.
- Volume hebdomadaire : existe (tuile « Volume » ; graphique dans Progression).
- Records personnels : existent (page Progression, tuile « Record » + 1RM ≈).
- Série de jours / semaines d'entraînement : N'EXISTE PAS à l'écran (`FitnessMath.weekStreak` existe dans le code, aucune vue de la mini-app ne l'affiche ; seul « Séances 5 / 3 » = objectif hebdo).
- Récupération / repos : seulement un jour « Repos » (planning vide) ; pas de suivi ni de score de récupération.
- Calories brûlées : existent en estimation (tuile « Calories » ≈ n ; « Calories actives » de la page Activité ; nécessite le poids).
- Fréquence cardiaque : N'EXISTE PAS (aucun HealthKit).
- Pas / activité : existent via CoreMotion (`StepCounter`, `CMPedometer`), PAS HealthKit : pas, distance, étages, 7 jours, objectif.
- Poids corporel : pas d'écran dans Fitness (saisi dans « Mes informations » ou la carte « Poids » de « À remplir »).
- Bibliothèque d'exercices : existe (163 en capture, Premium, démonstrations animées).
- Programmes : existent (semaine type + séances de l'utilisateur) ; programmes tout faits : à vérifier (aucun vu).
- Historique des séances : existe (par mois, détail, suppression).
- Minuteur de repos : existe (dans la séance : pause / passer / prêt).
- Live Activity : existe pour l'entraînement (`Shared/Live/WorkoutLiveActivity.swift`).
- Hydratation : N'EXISTE PAS (mini-app Eau supprimée).

## 8. Fichiers et vues
- `Fitness/FitnessApp.swift` : `FitnessAppView` (tout le §2), `FitnessPlan`, `FitnessDayContent` (privé). Cadre : `MiniAppScaffold.swift` (`MiniHero`, `MiniFloatingAction`), `WeekSelector.swift`, `MiniAppToFill.swift`, `MiniAppSettings.swift`.
- `Fitness/FitnessPages.swift` : `FitnessProgramPage`, `FitnessHistoryPage`, `FitnessSessionDetailPage`, `FitnessProgressPage`, `FitnessActivityPage`.
- `Fitness/FitnessSession.swift` : `FitnessSessionPage`, `SessionExerciseForm`, `SetEditor`. Fiche et bibliothèque : `Fitness/ExerciseLibraryViews.swift` (`ExerciseLibraryPage`, `ExerciseRowLabel`, `ExerciseInfoSheet`, `ExerciseDetailView`, `AddToRoutineSheet`, `CustomExerciseEditor`, `ExerciseGate`), `Fitness/ExerciseDemo.swift` (`ExerciseDemoView`).
- `Spaces/FitnessSpace.swift` : `RoutineEditor`. Pas : `App/Core/StepCounter.swift`. Live : `Shared/Live/WorkoutLiveActivity.swift`.
- Captures utiles : `kit2026/fr/app-fitness-s00..s10`, `app-fitness-session|progress|activity|program`, `app-nutrition-s00..s10`, `app-nutrition-meal|nutrients|ideas`, `scan-recap`.
